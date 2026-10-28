// ONDATA 1 - ACCESSO E RUOLI (app vera + Auth/Firestore EMULATORI, regole di staging, dati finti)
import { launch, openApp, shot, semText, hasText, waitFor, waitPath, currentPath, login, fillLogin, log } from './common.mjs';
import { readDoc, listDocs } from './emu.mjs';
import fs from 'fs';
const ids = JSON.parse(fs.readFileSync(new URL('./ids.json', import.meta.url)));
const R = [];
const rec = (id, ok, detail = '') => { R.push({ id, ok, detail }); log(ok ? 'OK ' : 'KO ', id, '|', detail); };
const base = '/tmp/claude-0/-home-user/a4a389bf-77be-5d81-ac7f-0c1bb199291a/scratchpad/e2e/';
const PW = ids.PW;
const goHash = async (page, h) => { await page.evaluate((x) => { location.hash = x; }, h); await page.waitForTimeout(2500); };

// ---------- ADMIN
fs.rmSync(base + 'prof-adm', { recursive: true, force: true });
let { ctx, page } = await launch(base + 'prof-adm');
// 1. link diretto a pagina admin senza sessione -> login con from
await openApp(page, 'http://127.0.0.1:8099/#/project/p1/edit');
let p = await waitPath(page, /login/, 15000);
rec('A1 deep link /project/p1/edit senza sessione -> /login?from=', /login/.test(p) && /from=/.test(p), p);
// 2. password sbagliata
await login(page, 'admin@test.it', 'password-sbagliata');
await page.waitForTimeout(3500);
let t = await semText(page, 3000);
rec('A2 password errata: resta su login con messaggio', /login/.test(await currentPath(page)) && /(non corretti|errat|non valid|Errore di accesso)/i.test(t.replace(/Password/g, '')), (await currentPath(page)) + ' | ' + t.slice(-260));
await shot(page, 'a2-pwd-errata');
// 3. login corretto con "ricorda email"
await fillLogin(page, 'admin@test.it', PW);
const cb = page.locator('[role="checkbox"]');
if ((await cb.getAttribute('aria-checked')) !== 'true') await cb.click();
await page.getByRole('button', { name: 'Accedi', exact: true }).click();
p = await waitPath(page, /^#\/(project\/p1\/edit|home)/, 25000);
rec('A3 login admin: torna alla pagina richiesta (from=/project/p1/edit)', /^#\/project\/p1\/edit/.test(p), p);
await page.waitForTimeout(2500);
await shot(page, 'a3-admin-dopo-login');
// vai alla home
await goHash(page, '#/home');
await waitFor(page, /Progetto Alfa/, 20000);
t = await semText(page, 5000);
rec('A4 home admin: vede Progetto Alfa e Beta, NON Progetto Segreto (altro admin)', /Progetto Alfa/.test(t) && /Progetto Beta/.test(t) && !/Progetto Segreto/.test(t), t.slice(0, 220));
await shot(page, 'a4-home-admin');
// 5. reload -> sessione ripristinata
await page.reload({ waitUntil: 'load' });
await page.waitForSelector('flt-glass-pane', { state: 'attached' });
await page.waitForTimeout(6000);
p = await currentPath(page);
rec('A5 ricarica pagina da loggato: nessun ritorno al login (sessione ripristinata)', !/login/.test(p), p);
// 6. admin su /client-home -> /home
await goHash(page, '#/client-home');
p = await currentPath(page);
rec('A6 admin su #/client-home viene riportato a /home', /home/.test(p) && !/client-home/.test(p), p);
// 7. logout, poi email ricordata
await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
await page.getByRole('button', { name: 'Esci', exact: true }).click();
p = await waitPath(page, /login/, 15000);
await page.waitForTimeout(2000);
const ls = await page.evaluate(() => Object.fromEntries(Object.entries(localStorage).filter(([k]) => !k.startsWith('firebase:'))));
rec('A7 Esci porta al login; email ricordata in localStorage (mai la password)', /login/.test(p) && JSON.stringify(ls).includes('admin@test.it') && !JSON.stringify(ls).includes(PW), p + ' ' + JSON.stringify(ls));
await shot(page, 'a7-login-dopo-esci');
// dopo logout accesso diretto a pagina admin -> login
await goHash(page, '#/team');
p = await currentPath(page);
rec('A8 dopo Esci, #/team porta al login', /login/.test(p), p);
await ctx.close();

// ---------- CLIENTE COLLEGATO
fs.rmSync(base + 'prof-cli', { recursive: true, force: true });
({ ctx, page } = await launch(base + 'prof-cli'));
await openApp(page);
await login(page, 'cliente1@test.it', PW);
p = await waitPath(page, /client-home/, 25000);
rec('C1 cliente collegato: dopo il login va a /client-home', /client-home/.test(p), p);
await waitFor(page, /Progetto Alfa/, 20000);
t = await semText(page, 5000);
rec('C2 cliente vede solo Progetto Alfa (non Beta, non Segreto)', /Progetto Alfa/.test(t) && !/Progetto Beta/.test(t) && !/Progetto Segreto/.test(t), t.slice(0, 200));
await shot(page, 'c2-client-home');
for (const route of ['#/home', '#/team', '#/project/p1/edit', '#/project/p1/costs', '#/project/p1/task/t1/edit', '#/project/p1/task/new/edit']) {
  await goHash(page, route);
  p = await currentPath(page);
  rec(`C3 cliente su ${route} viene riportato a /client-home`, /client-home/.test(p), p);
}
// progetto collegato: visibile, senza costi
await goHash(page, '#/project/p1');
await waitFor(page, /Accesso cliente/, 20000);
t = await semText(page, 8000);
rec('C4 cliente apre #/project/p1: vede i task (T-1, T-2)', /Accesso cliente/.test(t) && /Report mensile/.test(t) && /T-1/.test(t), t.slice(0, 300));
rec('C5 pagina progetto cliente: nessun costo/ore/tariffa/squadra', !/(Costi|costo|tariff|€|Ore reali|Registra ore|Squadra|Mario Rossi|77|Modifica)/i.test(t.replace(/Accesso cliente/g, '')), t.slice(0, 400));
await shot(page, 'c4-progetto-cliente');
await goHash(page, '#/project/p1/task/t1');
await waitFor(page, /Accesso cliente/, 20000);
t = await semText(page, 8000);
rec('C6 dettaglio task cliente: nessuna chat, nessun messaggio riservato, nessun costo', !/(Chiedi alla squadra|Messaggio riservato|Stato attuale|costo|tariff|Registra ore|Mario Rossi)/i.test(t), t.slice(0, 500));
await shot(page, 'c6-task-cliente');
// progetto NON collegato
await goHash(page, '#/project/pB');
await page.waitForTimeout(4000);
t = await semText(page, 8000);
rec('C7 cliente apre #/project/pB (non suo): non vede Progetto Segreto né Task segreto', !/(Progetto Segreto|Task segreto|Di un altro admin)/.test(t), t.slice(0, 300));
await shot(page, 'c7-progetto-non-collegato');
await goHash(page, '#/project/p2');
await page.waitForTimeout(4000);
t = await semText(page, 8000);
rec('C8 cliente apre #/project/p2 (non collegato, di admin A): non vede Progetto Beta', !/(Secondo progetto)/.test(t), t.slice(0, 300));
await ctx.close();

// ---------- CLIENTE NON COLLEGATO (senza documento users): primo accesso
fs.rmSync(base + 'prof-cli2', { recursive: true, force: true });
({ ctx, page } = await launch(base + 'prof-cli2', { width: 390, height: 780 }));
await openApp(page);
const before = await readDoc(`users/${ids.cli2}`);
await login(page, 'cliente2@test.it', PW);
p = await waitPath(page, /client-home/, 25000);
const after = await readDoc(`users/${ids.cli2}`);
rec('N1 primo accesso senza users/{uid}: l\'app lo crea come client e porta a /client-home (smartphone 390px)', before === null && after && after.role === 'client' && /client-home/.test(p), JSON.stringify({ before, after: after && after.role, p }));
await page.waitForTimeout(2000);
t = await semText(page, 3000);
rec('N2 cliente senza progetti: non vede nessun progetto', !/(Progetto Alfa|Progetto Beta|Progetto Segreto)/.test(t), t.slice(0, 200));
await shot(page, 'n2-cliente-senza-progetti-mobile');
// codice sbagliato
const code = page.locator('input[aria-label^="Codice progetto"]');
await code.click(); await page.keyboard.type('ZZZZZZ', { delay: 20 });
await page.getByRole('button', { name: 'Collega', exact: true }).click();
await page.waitForTimeout(3000);
t = await semText(page, 3000);
rec('N3 codice progetto inesistente: messaggio di errore, nessun collegamento', /(non esiste|non valido|non trovato|Codice)/i.test(t.replace(/Codice progetto/g, '')) && (await listDocs(`users/${ids.cli2}/clientProjects`)).length === 0, t.slice(0, 300));
await shot(page, 'n3-codice-sbagliato');
// codice giusto
await code.click(); await page.keyboard.press('Control+A'); await page.keyboard.type('abc234', { delay: 20 });
await page.getByRole('button', { name: 'Collega', exact: true }).click();
await waitFor(page, /Progetto Alfa/, 15000);
t = await semText(page, 5000);
const links = await listDocs(`users/${ids.cli2}/clientProjects`);
rec('N4 codice giusto (minuscolo): collega Progetto Alfa, solo quello', /Progetto Alfa/.test(t) && !/Progetto Beta/.test(t) && links.length === 1 && links[0].id === 'p1', JSON.stringify(links.map((l) => l.id)) + t.slice(0, 100));
await shot(page, 'n4-collegato-mobile');
await ctx.close();

// ---------- REGISTRAZIONE
fs.rmSync(base + 'prof-reg', { recursive: true, force: true });
({ ctx, page } = await launch(base + 'prof-reg', { width: 390, height: 780 }));
await openApp(page);
await page.getByRole('button', { name: /Registrati/ }).click();
await page.waitForTimeout(1200);
await fillLogin(page, 'nuovo@test.it', PW);
await page.locator('input[aria-label^="Ripeti"]').click(); await page.waitForTimeout(500);
await page.keyboard.type(PW, { delay: 10 });
await page.getByRole('button', { name: 'Crea account', exact: true }).click();
p = await waitPath(page, /client-home/, 25000);
await page.waitForTimeout(1500);
const nuovi = await (await fetch('http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:lookup?key=fake', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ email: ['nuovo@test.it'] }) })).json().catch(() => ({}));
const docs = await listDocs('users');
const nuovoDoc = docs.find((d) => d.email === 'nuovo@test.it');
rec('R1 registrazione nuovo cliente: finisce in /client-home con ruolo client', /client-home/.test(p) && nuovoDoc && nuovoDoc.role === 'client', p + ' ' + JSON.stringify(nuovoDoc && nuovoDoc.role));
await shot(page, 'r1-registrazione-mobile');
await ctx.close();

fs.writeFileSync(base + 'risultati-ondata1.json', JSON.stringify(R, null, 1));
console.log('\nTOTALE', R.length, 'KO', R.filter((r) => !r.ok).length);
