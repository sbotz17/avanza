import { chromium } from '/tmp/e2e/node_modules/playwright/index.mjs';
import fs from 'fs';
import path from 'path';

export const BASE = process.env.BASE || 'http://127.0.0.1:8099/';
export const SHOTS = '/tmp/claude-0/-home-user/a4a389bf-77be-5d81-ac7f-0c1bb199291a/scratchpad/e2e/shots';
const CK = '/tmp/claude-0/-home-user/a4a389bf-77be-5d81-ac7f-0c1bb199291a/scratchpad/app-emu/build/web/canvaskit/';
const FB = '/tmp/e2e/node_modules/firebase/';
const FONT = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf';

export const log = (...a) => console.log(new Date().toISOString().slice(11, 23), ...a);

export async function launch(userDataDir, viewport = { width: 1100, height: 800 }) {
  fs.mkdirSync(userDataDir, { recursive: true });
  const ctx = await chromium.launchPersistentContext(userDataDir, {
    executablePath: '/opt/pw-browsers/chromium',
    headless: true,
    viewport,
    proxy: { server: process.env.HTTPS_PROXY, bypass: 'localhost,127.0.0.1' },
    args: ['--no-sandbox'],
  });
  await ctx.route(/^https:\/\/www\.gstatic\.com\/firebasejs\/[^/]+\/(.+)$/, (route) => {
    const f = route.request().url().match(/firebasejs\/[^/]+\/(.+?)(\?.*)?$/)[1];
    const p = FB + f;
    if (!fs.existsSync(p)) return route.fulfill({ status: 404, body: 'nf' });
    route.fulfill({ status: 200, path: p, contentType: 'application/javascript', headers: { 'access-control-allow-origin': '*' } });
  });
  await ctx.route(/^https:\/\/www\.gstatic\.com\/flutter-canvaskit\/[^/]+\/(.+)$/, (route) => {
    const f = route.request().url().match(/flutter-canvaskit\/[^/]+\/(.+?)(\?.*)?$/)[1];
    const p = CK + f;
    if (!fs.existsSync(p)) return route.fulfill({ status: 404, body: 'nf' });
    const ct = f.endsWith('.wasm') ? 'application/wasm' : 'application/javascript';
    route.fulfill({ status: 200, path: p, contentType: ct, headers: { 'access-control-allow-origin': '*' } });
  });
  await ctx.route(/^https:\/\/fonts\.(gstatic|googleapis)\.com\//, (route) =>
    route.fulfill({ status: 200, path: FONT, contentType: 'font/ttf', headers: { 'access-control-allow-origin': '*' } }));
  // Il token ripristinato dopo un ricarico viene verificato dall'SDK PRIMA che useAuthEmulator sia attivo: si instradano verso l'emulatore
  // anche le chiamate ai servizi Google di accesso (solo nella prova locale; nessuna chiamata reale).
  await ctx.route(/^https:\/\/(identitytoolkit|securetoken)\.googleapis\.com\//, async (route) => {
    const req = route.request();
    const u = new URL(req.url());
    const cors = { 'access-control-allow-origin': req.headers()['origin'] || '*', 'access-control-allow-headers': '*', 'access-control-allow-methods': '*' };
    if (req.method() === 'OPTIONS') return route.fulfill({ status: 204, headers: cors });
    const r = await fetch(`http://127.0.0.1:9099/${u.host}${u.pathname}${u.search}`, { method: req.method(), headers: { 'content-type': req.headers()['content-type'] || 'application/json' }, body: req.method() === 'GET' ? undefined : req.postData() });
    route.fulfill({ status: r.status, headers: { ...cors, 'content-type': r.headers.get('content-type') || 'application/json' }, body: Buffer.from(await r.arrayBuffer()) });
  });
  const page = ctx.pages()[0] || (await ctx.newPage());
  page.on('console', (m) => { const t = m.text(); if (!/TrustedTypes|Initializing Firebase|GL Driver|google_fonts|checksum|troubleshooting|Injecting|apple-mobile|emulator/i.test(t) && t.trim()) log('console.' + m.type() + ': ' + t.slice(0, 300)); });
  page.on('pageerror', (e) => log('pageerror: ' + String(e).slice(0, 300)));
  return { ctx, page };
}

export async function openApp(page, url = BASE) {
  await page.goto(url, { waitUntil: 'load' });
  await page.waitForSelector('flt-glass-pane', { state: 'attached', timeout: 60000 });
  await page.waitForTimeout(3500);
  await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
  await page.waitForTimeout(1500);
}

export async function shot(page, name) {
  await page.screenshot({ path: path.join(SHOTS, name + '.png') });
  log('screenshot', name);
}

// testo visibile nell'albero semantico
export async function semText(page, max = 1500) {
  return page.evaluate((m) => [...document.querySelectorAll('flt-semantics')].map((e) => e.getAttribute('aria-label') || e.textContent).filter(Boolean).join(' | ').slice(0, m), max);
}
export async function hasText(page, re) {
  const t = await semText(page, 20000);
  return re.test(t);
}
export async function currentPath(page) {
  return page.evaluate(() => location.hash || location.pathname);
}

export async function fillLogin(page, email, pw) {
  const em = page.locator('input[aria-label^="Email"]');
  await em.waitFor({ timeout: 30000 });
  await em.click();
  await page.keyboard.press('Control+A');
  await page.keyboard.type(email, { delay: 10 });
  await page.waitForTimeout(300);
  await page.locator('input[aria-label^="Password"]').first().click();
  await page.waitForTimeout(500);
  await page.keyboard.press('Control+A');
  await page.keyboard.type(pw, { delay: 10 });
  await page.waitForTimeout(300);
}
export async function login(page, email, pw) {
  await fillLogin(page, email, pw);
  await page.getByRole('button', { name: 'Accedi', exact: true }).click();
}
export async function waitFor(page, re, ms = 30000) {
  const t0 = Date.now();
  while (Date.now() - t0 < ms) {
    if (await hasText(page, re)) return true;
    await page.waitForTimeout(400);
  }
  return false;
}
export async function waitPath(page, re, ms = 30000) {
  const t0 = Date.now();
  while (Date.now() - t0 < ms) {
    const p = await currentPath(page);
    if (re.test(p)) return p;
    await page.waitForTimeout(400);
  }
  return await currentPath(page);
}
