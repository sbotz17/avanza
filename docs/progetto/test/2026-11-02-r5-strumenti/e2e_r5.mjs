// R-5: prova nel browser reale (build EMU=true) su emulatori locali.
import { chromium } from '/Users/andreabotti/.npm/_npx/e41f203b7505f1fb/node_modules/playwright/index.mjs';

const BASE = 'http://127.0.0.1:8099/';
const PW = 'Prova-1234-xyz';
const SHOTS = '/tmp/kb-e2e/shots';
const log = (...a) => console.log(new Date().toISOString().slice(11, 23), ...a);

const browser = await chromium.launch({ channel: 'chrome', headless: true, args: ['--no-sandbox'] });
const ctx = await browser.newContext({ viewport: { width: 900, height: 700 } });
const page = await ctx.newPage();
page.on('pageerror', (e) => log('pageerror:', String(e).slice(0, 200)));
page.on('request', (r) => {
  const u = r.url();
  if (/identitytoolkit|securetoken|9099|googleapis/.test(u)) log('REQ', r.method(), u.slice(0, 140), (r.postData() || '').slice(0, 160));
});
page.on('response', (r) => {
  const u = r.url();
  if (/identitytoolkit|securetoken|9099/.test(u)) log('RES', r.status(), u.slice(0, 120));
});
page.on('console', (m) => {
  const t = m.text();
  if (m.type() === 'error' && !/TrustedTypes|checksum|troubleshooting/i.test(t)) log('console.error:', t.slice(0, 200));
});

async function semText() {
  return page.evaluate(() =>
    [...document.querySelectorAll('flt-semantics')]
      .map((e) => e.getAttribute('aria-label') || e.textContent)
      .filter(Boolean)
      .join(' | '));
}

async function rectOf(text) {
  // Prende il nodo più piccolo (la scheda), non il contenitore che contiene tutto.
  return page.evaluate((t) => {
    const els = [...document.querySelectorAll('flt-semantics')]
      .filter((e) => (e.getAttribute('aria-label') || e.textContent || '').includes(t));
    let best = null;
    for (const e of els) {
      const r = e.getBoundingClientRect();
      const area = r.width * r.height;
      if (!best || area < best.area) best = { area, r, label: (e.getAttribute('aria-label') || '').slice(0, 60) };
    }
    if (!best) return null;
    return { left: Math.round(best.r.left), top: Math.round(best.r.top), w: Math.round(best.r.width), h: Math.round(best.r.height), label: best.label };
  }, text);
}

async function shot(name) {
  await page.screenshot({ path: `${SHOTS}/${name}.png` });
  log('screenshot', name);
}

await page.goto(BASE, { waitUntil: 'load' });
await page.waitForSelector('flt-glass-pane', { state: 'attached', timeout: 60000 });
await page.waitForTimeout(4000);
await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
await page.waitForTimeout(1500);

// Accesso con utente finto dell'emulatore
const email = page.locator('input[aria-label^="Email"]');
await email.waitFor({ timeout: 30000 });
await email.click();
await page.keyboard.insertText('admin@test.it');
await page.waitForTimeout(300);
await page.locator('input[aria-label^="Password"]').first().click();
await page.waitForTimeout(400);
await page.keyboard.insertText(PW);
await page.waitForTimeout(400);
log('valori input:', await page.evaluate(() => [...document.querySelectorAll('input')].map((e) => (e.getAttribute('aria-label') || '?') + '=' + (e.type === 'password' ? '***' + e.value.length : e.value))));
await page.getByRole('button', { name: 'Accedi', exact: true }).click();
for (let i = 0; i < 40; i++) {
  if ((await semText()).includes('Progetto Alfa')) break;
  await page.waitForTimeout(500);
}
log('home:', (await semText()).slice(0, 160));
await shot('01-home');

// Apre il progetto e passa al kanban
await page.evaluate(() => { location.hash = '#/project/p1?view=kanban'; });
await page.waitForTimeout(4000);
let t = await semText();
log('kanban?', /Task kanban numero/.test(t), t.slice(0, 220));
await shot('02-kanban');

// ---- verticale: rotella del mouse
const beforeT = await rectOf('Task kanban numero 01');
const beforeB = await rectOf('Task kanban numero 05');
await page.mouse.move(450, 400);
await page.mouse.wheel(0, 500);
await page.waitForTimeout(1500);
const afterT = await rectOf('Task kanban numero 01');
const afterB = await rectOf('Task kanban numero 05');
log('verticale: prima', beforeT, beforeB, 'dopo', afterT, afterB);
const verticalOk = beforeB && afterB && afterB.top < beforeB.top - 50;
await shot('03-kanban-scroll-verticale');

// riporta in cima per misurare il solo scorrimento orizzontale
await page.mouse.move(450, 400);
await page.mouse.wheel(0, -1200);
await page.waitForTimeout(1200);

// ---- orizzontale: trascinamento col mouse (abilitato dalla correzione)
const beforeCol = await rectOf('Da fare');
const beforeCard = await rectOf('Task kanban numero 01');
await page.mouse.move(650, 300);
await page.mouse.down();
await page.mouse.move(250, 300, { steps: 15 });
await page.mouse.up();
await page.waitForTimeout(1500);
const afterCol = await rectOf('Da fare');
const afterCard = await rectOf('Task kanban numero 01');
log('orizzontale: prima', beforeCol, beforeCard, 'dopo', afterCol, afterCard);
const horizontalOk = beforeCard && afterCard && afterCard.left < beforeCard.left - 80;
const assiIndipendenti = beforeCard && afterCard && Math.abs(afterCard.top - beforeCard.top) < 30;
await shot('04-kanban-scroll-orizzontale');

// le schede si possono ancora aprire dopo il trascinamento
const clickable = (await rectOf('Task kanban numero 05')) || afterCard;
await page.mouse.click(clickable.left + 40, clickable.top + 20);
await page.waitForTimeout(2500);
const path = await page.evaluate(() => location.hash);
log('dopo tap, percorso:', path);
const tapOk = /task\/t0[0-9]/.test(path);
await shot('05-dettaglio-task');

console.log(JSON.stringify({ verticalOk, horizontalOk, assiIndipendenti, tapOk }, null, 2));
await browser.close();
if (!verticalOk || !horizontalOk || !tapOk) process.exit(1);
