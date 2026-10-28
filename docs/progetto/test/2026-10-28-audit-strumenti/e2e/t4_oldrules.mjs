// COMPATIBILITA: app nuova (staging) con le regole VECCHIE di main (caso "rilascio fatto, regole non ancora pubblicate")
import { launch, openApp, shot, semText, waitPath, currentPath, login, log } from './common.mjs';
import { listDocs } from './emu.mjs';
import fs from 'fs';
const ids = JSON.parse(fs.readFileSync(new URL('./ids.json', import.meta.url)));
const base = '/tmp/claude-0/-home-user/a4a389bf-77be-5d81-ac7f-0c1bb199291a/scratchpad/e2e/';
fs.rmSync(base + 'prof-old', { recursive: true, force: true });
const { ctx, page } = await launch(base + 'prof-old');
await openApp(page);
await login(page, 'admin@test.it', ids.PW);
await waitPath(page, /^#\/home$/, 25000);
const go = async (h, ms = 4500) => { await page.evaluate((x) => { location.hash = x; }, h); await page.waitForTimeout(ms); };
await go('#/project/p1');
let t = await semText(page, 5000);
console.log('RES project page:', /T-1/.test(t) && /Accesso cliente/.test(t) ? 'OK elenco task visibile' : 'KO ' + t.slice(0, 150));
await go('#/project/p1/task/t1', 5500);
t = await semText(page, 9000);
console.log('RES task detail: titolo/fasi visibili =', /Fasi di sviluppo/.test(t) && /Analisi/.test(t), '| chat titolo =', /Chiedi alla squadra/.test(t), '| errore in pagina =', (t.match(/(permission|Errore|insufficient|autorizzazion)[^|]{0,100}/i) || ['nessuno'])[0]);
await shot(page, 'old-task-detail');
// prova a inviare una domanda
const ta = page.locator('textarea[aria-label^="Chiedi alla squadra"]').first();
if (await ta.count()) {
  await ta.click(); await page.keyboard.insertText('domanda con regole vecchie');
  await page.getByRole('button', { name: 'Invia', exact: true }).click(); await page.waitForTimeout(3500);
  t = await semText(page, 9000);
  console.log('RES invio con regole vecchie: messaggi salvati =', (await listDocs('projects/p1/tasks/t1/chat')).length, '| UI =', (t.match(/(permission|Errore|non riuscit|insufficient|impossibile)[^|]{0,120}/i) || ['nessun messaggio di errore'])[0]);
  await shot(page, 'old-chat-invio');
}
// il resto dell'app funziona: creazione task e costi
await go('#/project/p1/costs', 4000);
t = await semText(page, 5000);
console.log('RES costi admin con regole vecchie:', /Ore stimate/.test(t) ? 'OK' : 'KO');
await ctx.close();
