// ONDATE 2 e 3 - PROGETTI/TASK/CHAT e SQUADRA/COSTI (app vera + emulatori, regole di staging, dati finti)
import { launch, openApp, shot, semText, hasText, waitFor, waitPath, currentPath, login, log } from './common.mjs';
import { readDoc, listDocs, seed } from './emu.mjs';
import fs from 'fs';
const ids = JSON.parse(fs.readFileSync(new URL('./ids.json', import.meta.url)));
const R = [];
const rec = (id, ok, detail = '') => { R.push({ id, ok, detail }); log(ok ? 'OK ' : 'KO ', id, '|', String(detail).replace(/\s+/g, ' ').slice(0, 260)); };
const base = '/tmp/claude-0/-home-user/a4a389bf-77be-5d81-ac7f-0c1bb199291a/scratchpad/e2e/';
const PW = ids.PW;
const goHash = async (page, h, ms = 3500) => { await page.evaluate((x) => { location.hash = x; }, h); await page.waitForTimeout(ms); };
const type = async (page, sel, text, { clear = true } = {}) => { const l = page.locator(sel).first(); await l.click(); await page.waitForTimeout(250); if (clear) await page.keyboard.press('Control+A'); await page.keyboard.insertText(text); await page.waitForTimeout(250); };
const now = new Date('2026-10-28T10:00:00Z');

// task di prova per stati "completati"
await seed('projects/p1/tasks/t3', { title: 'Task validato', description: '', clientRequest: '', status: 'validated', phases: [], notes: [], order: 2, taskCode: 'T-90', taskNumber: 90, createdAt: now, updatedAt: now });
await seed('projects/p1/tasks/t4', { title: 'Task rilasciato', description: '', clientRequest: '', status: 'released', phases: [], notes: [], order: 3, taskCode: 'T-91', taskNumber: 91, createdAt: now, updatedAt: now });

fs.rmSync(base + 'prof-adm2', { recursive: true, force: true });
let { ctx, page } = await launch(base + 'prof-adm2');
await openApp(page);
await login(page, 'admin@test.it', PW);
await waitPath(page, /^#\/home$/, 25000);

// ---------------- ONDATA 2
await goHash(page, '#/project/p1');
let t = await semText(page, 6000);
rec('P1 progetto: kanban con T-1 (In corso) e T-2 (In test / QA); T-90/T-91 presenti', /T-1/.test(t) && /T-2/.test(t) && /In test \/ QA/.test(t) && /In corso/.test(t) && /Task validato/.test(t), t.slice(0, 200));
await shot(page, 'p1-kanban-admin');
await page.getByRole('button', { name: 'Vista kanban' }).click(); await page.waitForTimeout(1500);
t = await semText(page, 3000);
rec('P2 pulsante cambia in "Vista lista" e la lista mostra i task', /Vista lista/.test(t) && /Accesso cliente/.test(t), t.slice(0, 160));
await shot(page, 'p2-lista-admin');
// apre il task con un clic
await page.getByText('Accesso cliente').first().click().catch(async () => { await page.locator('flt-semantics', { hasText: 'Accesso cliente' }).first().click(); });
await page.waitForTimeout(3000);
let p = await currentPath(page);
rec('P3 clic su un task apre il dettaglio', /project\/p1\/task\/t1/.test(p), p);
// chat
t = await semText(page, 8000);
const tareas = await page.evaluate(() => [...document.querySelectorAll('textarea')].map((e) => e.value + '|' + e.getAttribute('aria-label')));
rec('P4 dettaglio task non completato (admin): chat con riquadro "Stato attuale" e messaggio storico della squadra', /Chiedi alla squadra/.test(t) && /Stato attuale/.test(t) && JSON.stringify(tareas).includes('Squadra · 28/10 10:00'), JSON.stringify(tareas).slice(0, 200));
await shot(page, 'p4-chat-admin');
// invia domanda
const before = (await listDocs('projects/p1/tasks/t1/chat')).length;
await type(page, 'textarea[aria-label^="Chiedi alla squadra"]', 'Come va il task T-1? (prova audit)');
await page.getByRole('button', { name: 'Invia', exact: true }).click(); await page.waitForTimeout(3000);
let chat = await listDocs('projects/p1/tasks/t1/chat');
const nuova = chat.find((c) => c.text && c.text.startsWith('Come va il task T-1'));
t = await semText(page, 8000);
rec('P5 invio domanda: salvata con from=admin, kind=domanda, authorUid=admin, createdAt del server; testo fisso di conferma in UI', !!nuova && nuova.from === 'admin' && nuova.kind === 'domanda' && nuova.authorUid === ids.adminA && typeof nuova.createdAt === 'string' && chat.length === before + 1 && /ti risponde al prossimo giro/.test(t), JSON.stringify(nuova) + ' | conferma UI: ' + /ti risponde al prossimo giro/.test(t));
await shot(page, 'p5-chat-inviata');
// domanda troppo lunga (2100) : non deve creare alcun messaggio
const n1 = (await listDocs('projects/p1/tasks/t1/chat')).length;
await type(page, 'textarea[aria-label^="Chiedi alla squadra"]', 'x'.repeat(2100));
await page.getByRole('button', { name: 'Invia', exact: true }).click(); await page.waitForTimeout(3000);
const n2 = (await listDocs('projects/p1/tasks/t1/chat')).length;
t = await semText(page, 8000);
rec('P6 domanda di 2100 caratteri: rifiutata (nessun messaggio salvato)', n2 === n1, `messaggi prima=${n1} dopo=${n2}; UI: ${(t.match(/(2000|troppo lung|più lungo|massimo)[^|]{0,80}/i) || [''])[0]}`);
await shot(page, 'p6-chat-lunga');
// task validato / rilasciato: nessuna chat
await goHash(page, '#/project/p1/task/t3'); t = await semText(page, 6000);
const v1 = /Task validato/.test(t) && !/Chiedi alla squadra/.test(t);
await goHash(page, '#/project/p1/task/t4'); t = await semText(page, 6000);
const v2 = /Task rilasciato/.test(t) && !/Chiedi alla squadra/.test(t);
rec('P7 task validato e rilasciato: nessuna chat', v1 && v2, `validato=${v1} rilasciato=${v2}`);
// task in test/QA: chat presente
await goHash(page, '#/project/p1/task/t2'); t = await semText(page, 6000);
rec('P8 task in test/QA (non completato): chat presente', /Chiedi alla squadra/.test(t), '');

// contatore T-N: il progetto parte da nextTaskNumber=3
const creaTask = async (titolo) => {
  await goHash(page, '#/project/p1/task/new/edit', 3000);
  await type(page, 'input[aria-label^="Titolo"]', titolo);
  await type(page, 'input[aria-label^="Ore stimate"]', '5');
  await type(page, 'input[aria-label^="Tariffa"]', '70');
  await page.getByRole('button', { name: 'Crea task', exact: true }).click();
  await page.waitForTimeout(3500);
};
await creaTask('Task nuovo uno');
await creaTask('Task nuovo due');
let tasks = await listDocs('projects/p1/tasks');
let t1n = tasks.find((x) => x.title === 'Task nuovo uno'), t2n = tasks.find((x) => x.title === 'Task nuovo due');
let proj = await readDoc('projects/p1');
rec('P9 due task creati da UI: T-3 e T-4, contatore progetto = 5', t1n && t2n && t1n.taskCode === 'T-3' && t2n.taskCode === 'T-4' && proj.nextTaskNumber === 5, JSON.stringify({ a: t1n && t1n.taskCode, b: t2n && t2n.taskCode, next: proj.nextTaskNumber }));
const costs = await readDoc(`projects/p1/taskCosts/${t1n.id}`);
rec('P10 creato anche il documento costi del task (ore stimate 5, tariffa 70)', costs && costs.estimatedHours === 5 && costs.hourlyRate === 70, JSON.stringify(costs));
// modifica progetto: il contatore NON deve cambiare (R-4)
await goHash(page, '#/project/p1/edit', 3500);
await type(page, 'input[aria-label^="Nome progetto"]', 'Progetto Alfa 2');
await page.getByRole('button', { name: 'Salva modifiche', exact: true }).click(); await page.waitForTimeout(3500);
proj = await readDoc('projects/p1');
rec('P11 modifica progetto (R-4): nome cambiato, contatore, codice cliente e proprietario invariati', proj.name === 'Progetto Alfa 2' && proj.nextTaskNumber === 5 && proj.clientCode === 'ABC234' && proj.ownerId === ids.adminA, JSON.stringify({ n: proj.name, next: proj.nextTaskNumber, code: proj.clientCode }));
await creaTask('Task nuovo tre');
tasks = await listDocs('projects/p1/tasks');
const t3n = tasks.find((x) => x.title === 'Task nuovo tre'); proj = await readDoc('projects/p1');
rec('P12 dopo la modifica del progetto il task successivo e T-5 (nessun numero riusato)', t3n && t3n.taskCode === 'T-5' && proj.nextTaskNumber === 6, JSON.stringify({ c: t3n && t3n.taskCode, next: proj.nextTaskNumber }));
const codici = tasks.map((x) => x.taskCode); rec('P13 nessun codice T-N duplicato nel progetto', new Set(codici).size === codici.length, codici.join(','));
// nuovo progetto da UI
await goHash(page, '#/home', 3500);
await page.getByRole('button', { name: /Nuovo progetto/ }).first().click(); await page.waitForTimeout(1500);
await type(page, 'input[aria-label^="Nome progetto"]', 'Progetto Nuovo UI');
await page.getByRole('button', { name: 'Crea progetto', exact: true }).click(); await page.waitForTimeout(3500);
const projs = await listDocs('projects'); const np = projs.find((x) => x.name === 'Progetto Nuovo UI');
const acc = np && await readDoc(`clientAccess/${np.clientCode}`);
rec('P14 nuovo progetto da UI: proprietario=admin, contatore=1, codice cliente di 6 caratteri con clientAccess collegato', np && np.ownerId === ids.adminA && np.nextTaskNumber === 1 && /^[A-Z2-9]{6}$/.test(np.clientCode) && acc && acc.projectId === np.id && acc.ownerId === ids.adminA, JSON.stringify({ np: np && [np.ownerId === ids.adminA, np.nextTaskNumber, np.clientCode], acc }));
await shot(page, 'p14-nuovo-progetto');

// ---------------- ONDATA 3: SQUADRA E COSTI
await goHash(page, '#/team', 3500);
t = await semText(page, 4000);
rec('S1 pagina Squadra: solo i membri del proprio admin (Mario Rossi), NON "Agente Segreto" di un altro admin', /Mario Rossi/.test(t) && !/Agente Segreto/.test(t), t.slice(0, 150));
await page.getByRole('button', { name: /Aggiungi membro/ }).click(); await page.waitForTimeout(1200);
await type(page, 'input[aria-label^="Nome"]', 'Giulia Validatrice');
await page.getByRole('button', { name: /^Ruolo/ }).click(); await page.waitForTimeout(1000);
const voci = await page.evaluate(() => [...document.querySelectorAll('[role=menuitem],[role=option]')].map((e) => (e.getAttribute('aria-label') || e.textContent || '').trim()));
rec('S2 menu Ruolo a tendina: 13 ruoli standard + "Altro…"', voci.length >= 14 && voci.some((v) => /validatore/i.test(v)) && voci.some((v) => /Altro/.test(v)), JSON.stringify(voci));
await shot(page, 's2-menu-ruolo');
await page.getByRole('menuitem', { name: 'Validatore', exact: true }).click();
await page.waitForTimeout(800);
await type(page, 'input[aria-label^="Costo orario"]', '42,5');
await type(page, 'input[aria-label^="Tariffa di vendita"]', '80');
await page.getByRole('button', { name: 'Salva', exact: true }).click(); await page.waitForTimeout(3000);
const team = await listDocs('teamMembers'); const gm = team.find((m) => m.name === 'Giulia Validatrice');
rec('S3 nuovo membro salvato: ruolo=validatore, costo 42,5 (virgola decimale), vendita 80, ownerId=admin, attivo', gm && gm.role === 'validatore' && gm.costRate === 42.5 && gm.billRate === 80 && gm.ownerId === ids.adminA && gm.active === true, JSON.stringify(gm));
await shot(page, 's3-squadra');
// registra ore dalla pagina costi
await goHash(page, '#/project/p1/costs', 4000);
t = await semText(page, 6000);
rec('S4 pagina costi (admin): ore, costi e produttivita visibili', /Ore stimate/.test(t) && /Costo reale/.test(t) && /produttività/i.test(t), t.slice(0, 160));
await shot(page, 's4-costi-admin');
const act0 = (await readDoc('projects/p1/taskCosts/t1')).actualHours;
await page.getByRole('button', { name: /Registra ore/ }).first().click(); await page.waitForTimeout(1200);
await type(page, 'input[aria-label^="Ore"]', '2,5');
await page.getByRole('button', { name: 'Registra', exact: true }).click(); await page.waitForTimeout(3000);
const act1 = (await readDoc('projects/p1/taskCosts/t1')).actualHours;
const ent = await listDocs('projects/p1/timeEntries');
rec('S5 registra 2,5 ore: ore reali del task aumentano di 2,5 e nasce una voce nel registro', Math.abs(act1 - act0 - 2.5) < 1e-9 && ent.length === 2, `prima=${act0} dopo=${act1} voci=${ent.length}`);
// report ore
t = await semText(page, 6000);
rec('S6 report ore aggiornato in pagina (Mario Rossi, 6,5h)', /Mario Rossi/.test(t) && /6[.,]5h/.test(t), (t.match(/Mario Rossi[^|]{0,80}/) || [''])[0]);
await shot(page, 's6-report-ore');
await ctx.close();

// ---------------- Cliente: costi / squadra mai visibili (UI + lettura diretta)
fs.rmSync(base + 'prof-cli3', { recursive: true, force: true });
({ ctx, page } = await launch(base + 'prof-cli3', { width: 390, height: 780 }));
await openApp(page);
await login(page, 'cliente1@test.it', PW);
await waitPath(page, /client-home/, 25000);
for (const h of ['#/project/p1', '#/project/p1/task/t1', '#/project/p1/task/t2']) {
  await goHash(page, h, 4000);
  t = await semText(page, 9000);
  rec(`X1 cliente (smartphone) su ${h}: nessun costo, ore, tariffa, squadra, chat`, !/(Costi|costo|Tariff|€|Ore reali|Ore stimate|Registra ore|Mario Rossi|Giulia|Chiedi alla squadra|Messaggio riservato|Modifica)/i.test(t.replace(/Costo stimato/g, 'X')) , t.slice(0, 200));
}
await shot(page, 'x1-cliente-mobile-task');
await ctx.close();

fs.writeFileSync(base + 'risultati-ondate23.json', JSON.stringify(R, null, 1));
console.log('\nTOTALE', R.length, 'KO', R.filter((r) => !r.ok).length);
