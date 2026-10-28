// Prova di accettazione UI VERA nel browser sul sito di TEST di Avanza (mai la produzione).
// Si lancia dal workflow "E2E UI (sito di test)" (.github/workflows/e2e-ui.yml). Guida in docs/progetto/test/e2e-ui.md.
//
// Cosa fa: crea nel progetto di TEST (Admin SDK) un utente admin di prova, un progetto con 2 task e 2 membri della squadra;
// apre il sito di test con Chromium (Playwright), fa il login, prova "Ricorda email", elenco progetti, progetto, task, chat,
// pagina Squadra e il dialogo "Aggiungi membro" (Ruolo a tendina con 13 ruoli + "Altro…"), controlla la console; poi ELIMINA
// solo i dati creati da questo giro (riconosciuti dall'ID del run).
//
// Uso:   node scripts/e2e-ui-test.mjs                 prova completa
//        node scripts/e2e-ui-test.mjs --pulisci <run>  elimina i dati di un giro (rete di sicurezza se la prova e' stata interrotta)
// Variabili: PROGETTO (deve essere avanza-test-c33ef), GOOGLE_APPLICATION_CREDENTIALS (file della chiave di TEST),
//   SITO_URL (default https://avanza-test-c33ef.web.app), E2E_TOOLS_DIR (cartella dove e' installato playwright),
//   E2E_OUT (default e2e-risultati), E2E_RIFERIMENTO_ISO (ora del commit atteso sul sito, facoltativa),
//   E2E_CONSOLE_ERRORI = errore (default) | avviso   (gli errori di console diversi da permission-denied diventano solo avvisi).
// Esito: 0 prova superata e pulizia verificata; 1 prova fallita; 2 guardie/uso; 3 pulizia incompleta.
//
// Cosa NON si legge/stampa mai: la password di prova (casuale, solo in memoria), la chiave di servizio.
import { createRequire } from 'node:module';
import { mkdirSync, readdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import * as L from './lib/e2e-ui-logica.mjs';
import * as D from './lib/e2e-ui-dati.mjs';
import { creaAiuti, escAttr } from './lib/e2e-ui-browser.mjs';

const QUI = path.dirname(fileURLToPath(import.meta.url));
const RADICE = path.resolve(QUI, '..');
const OUT = path.resolve(process.env.E2E_OUT || 'e2e-risultati');
const log = (...a) => console.log(...a);
const pausa = (ms) => new Promise((r) => setTimeout(r, ms));

// ───────────────────────────── avvio, guardie, pulizia di emergenza ─────────────────────────────

const args = process.argv.slice(2);
const modoPulisci = args[0] === '--pulisci';
const sitoUrl = process.env.SITO_URL || `https://${L.PROGETTO_TEST}.web.app`;
const fileChiave = process.env.GOOGLE_APPLICATION_CREDENTIALS;

let credenziali = null;
try {
  credenziali = fileChiave ? JSON.parse(readFileSync(fileChiave, 'utf8')) : null;
} catch {
  credenziali = null; // la guardia lo segnala; non si stampa il contenuto
}
const guardie = L.controllaGuardie({ env: process.env, credenziali, sitoUrl });
if (!guardie.ok) {
  console.error('RIFIUTO DI PARTIRE (guardie anti-produzione):');
  for (const e of guardie.errori) console.error(` - ${e}`);
  process.exit(2);
}
const SITO = L.sitoNormalizzato(sitoUrl);

// Admin SDK dalla cartella functions/ (npm ci nel workflow), come gli altri script del progetto.
const reqAdmin = createRequire(path.join(RADICE, 'functions', 'package.json'));
const { initializeApp, cert } = reqAdmin('firebase-admin/app');
const { getFirestore, Timestamp } = reqAdmin('firebase-admin/firestore');
const { getAuth } = reqAdmin('firebase-admin/auth');
initializeApp({ credential: cert(credenziali), projectId: L.PROGETTO_TEST });
const dep = { db: getFirestore(), auth: getAuth(), Timestamp };

if (modoPulisci) {
  const run = args[1];
  if (!L.isRunIdValido(run)) {
    console.error('Uso: node scripts/e2e-ui-test.mjs --pulisci e2e-ui-<13 cifre>-<4 esadecimali>');
    process.exit(2);
  }
  const es = await D.pulisciDatiDiProva(dep, run);
  log(`Pulizia di ${run}: eliminati ${es.eliminati.length}, errori ${es.errori.length}, verificata=${es.verificata}`);
  for (const e of es.errori) console.error(` - ${e}`);
  process.exit(es.verificata ? 0 : 3);
}

// ───────────────────────────── stato della prova ─────────────────────────────

const runId = L.generaRunId();
const password = L.generaPassword();
const SEGRETI = [password];
const consoleStrict = (process.env.E2E_CONSOLE_ERRORI || 'errore') !== 'avviso';
const rapporto = {
  runId,
  sito: SITO,
  progetto: L.PROGETTO_TEST,
  inizio: new Date().toISOString(),
  passi: [],
  avvisi: [],
  sitoPubblicato: {},
  console: { permessi: [], errori: [], totale: 0 },
  pulizia: null,
  esito: 'non concluso',
};
mkdirSync(OUT, { recursive: true });
// Screenshot di giri precedenti (solo esecuzioni locali: in CI la cartella e' nuova): si tolgono solo i file di questa prova.
for (const f of readdirSync(OUT)) if (/^(fallimento-.*|finale)\.png$/.test(f)) rmSync(path.join(OUT, f), { force: true });
writeFileSync(path.join(OUT, 'run-id.txt'), `${runId}\n`); // serve alla pulizia di sicurezza del workflow

const mask = (t) => L.mascheraSegreti(t, SEGRETI);
const msg = (e) => mask(String(e?.message ?? e).split('\n').slice(0, 6).join(' | ')).slice(0, 500);

let browser = null;
let page = null;
let datiCreati = false;
let nomi = null;
let dati = null;
let fase = 'Preparazione';
let fermataRichiesta = false;

class ProvaInterrotta extends Error {}

async function ripulisci() {
  if (!datiCreati) return;
  log('Pulizia dei dati di prova...');
  rapporto.pulizia = await D.pulisciDatiDiProva(dep, runId);
  datiCreati = !rapporto.pulizia.verificata;
  log(`Pulizia: eliminati ${rapporto.pulizia.eliminati.length} elementi, errori ${rapporto.pulizia.errori.length}, verificata=${rapporto.pulizia.verificata}`);
}

for (const sig of ['SIGINT', 'SIGTERM']) {
  process.on(sig, async () => {
    if (fermataRichiesta) return;
    fermataRichiesta = true;
    log(`Segnale ${sig}: interrompo e pulisco.`);
    try {
      await browser?.close();
    } catch {}
    try {
      await ripulisci();
    } catch (e) {
      console.error(`Pulizia fallita: ${msg(e)}`);
    }
    process.exit(130);
  });
}

// ───────────────────────────── aiuti per Flutter web (CanvasKit + albero semantico) ─────────────────────────────
// Dettagli e motivazioni in scripts/lib/e2e-ui-browser.mjs.
const { testo, bottone, campo, campoChat, aspetta, clicca, scrivi, valoreCampo, finoA, abilitaSemantica, leggiSchermata } = creaAiuti(() => page, { msg });

async function apri(url) {
  await page.goto(url, { waitUntil: 'load', timeout: 60000 });
  await abilitaSemantica();
}

async function controllaErroriVisibili() {
  const testi = await leggiSchermata(400);
  for (const t of testi) {
    for (const re of L.ERRORI_VISIBILI) {
      if (re.test(t)) throw new Error(`Errore visibile nell'app: "${t.slice(0, 160)}"`);
    }
  }
}

/** Aspetta che compaia `loc`, ma si ferma subito se l'app mostra un errore di lettura o di permessi (messaggio piu' chiaro di un timeout). */
async function aspettaContenuto(loc, ms, descrizione) {
  const fine = Date.now() + ms;
  while (Date.now() < fine) {
    if ((await loc.count()) > 0) return;
    await controllaErroriVisibili();
    await pausa(400);
  }
  throw new Error(`Timeout (${ms} ms) in attesa di: ${descrizione}`);
}

async function screenshot(nome) {
  try {
    if (!page) return null;
    const p = path.join(OUT, nome);
    await page.screenshot({ path: p, fullPage: false });
    return nome;
  } catch {
    return null;
  }
}

/** Un passo della prova: 2 tentativi, screenshot e diagnostica SOLO se fallisce. */
async function passo(nome, fn, { tentativi = 2, fatale = false } = {}) {
  const t0 = Date.now();
  let errore;
  for (let i = 1; i <= tentativi; i++) {
    try {
      await fn(i);
      rapporto.passi.push({ nome, esito: 'ok', tentativi: i, ms: Date.now() - t0 });
      log(`  OK     ${nome}${i > 1 ? ` (al tentativo ${i})` : ''}`);
      return true;
    } catch (e) {
      errore = e;
      log(`  ...    ${nome}: tentativo ${i}/${tentativi} non riuscito: ${msg(e)}`);
      if (i < tentativi) await pausa(1500);
    }
  }
  const n = String(rapporto.passi.length + 1).padStart(2, '0');
  const voce = {
    nome,
    esito: 'FALLITO',
    tentativi,
    ms: Date.now() - t0,
    errore: msg(errore),
    screenshot: await screenshot(`fallimento-${n}-${L.slug(nome)}.png`),
    schermata: (await leggiSchermata()).map(mask),
  };
  rapporto.passi.push(voce);
  log(`  FALLITO ${nome}: ${voce.errore}`);
  if (fatale) throw new ProvaInterrotta(nome);
  return false;
}

// ───────────────────────────── controlli sul sito pubblicato ─────────────────────────────

async function ultimoRilascioHosting() {
  try {
    const { GoogleAuth } = reqAdmin('google-auth-library');
    const client = await new GoogleAuth({ credentials: credenziali, scopes: ['https://www.googleapis.com/auth/cloud-platform'] }).getClient();
    const r = await client.request({ url: `https://firebasehosting.googleapis.com/v1beta1/sites/${L.PROGETTO_TEST}/channels/live`, timeout: 15000 });
    return r.data?.release?.releaseTime ?? r.data?.release?.version?.createTime ?? null;
  } catch {
    return null;
  }
}

async function verificaSitoPubblicato() {
  const home = await fetch(`${SITO}/`, { redirect: 'follow' });
  if (home.status !== 200) throw new Error(`Il sito di test risponde ${home.status} (atteso 200).`);
  const jsRes = await fetch(`${SITO}/main.dart.js`, { redirect: 'follow' });
  if (jsRes.status !== 200) throw new Error(`main.dart.js risponde ${jsRes.status} (atteso 200): sito non pubblicato?`);
  const js = await jsRes.text();
  let apiKeyProduzione = '';
  try {
    apiKeyProduzione = /apiKey:\s*'([^']+)'/.exec(readFileSync(path.join(RADICE, 'lib', 'firebase_options.dart'), 'utf8'))?.[1] ?? '';
  } catch {}
  const bundle = L.valutaBundleSito(js, { apiKeyProduzione });
  if (!bundle.ok) throw new Error(bundle.errori.join(' '));

  const cache = L.valutaIntestazioniCache(Object.fromEntries(jsRes.headers));
  rapporto.avvisi.push(...cache.avvisi);
  const rilascio = await ultimoRilascioHosting();
  const agg = L.valutaAggiornamentoSito({ rilascioIso: rilascio, riferimentoIso: process.env.E2E_RIFERIMENTO_ISO || '' });
  rapporto.sitoPubblicato = { dimensioneJs: js.length, ultimoRilascio: rilascio, aggiornamento: agg.stato, cacheControl: jsRes.headers.get('cache-control'), age: jsRes.headers.get('age') };
  if (agg.stato !== 'aggiornato' && agg.stato !== 'informativo') rapporto.avvisi.push(agg.messaggio);
  log(`  Sito: ${agg.messaggio}`);
  for (const a of cache.avvisi) log(`  AVVISO ${a}`);
  if (agg.stato === 'non_aggiornato') throw new Error(agg.messaggio);
}

// ───────────────────────────── la prova ─────────────────────────────

function caricaPlaywright() {
  const dir = process.env.E2E_TOOLS_DIR;
  const req = dir ? createRequire(path.join(path.resolve(dir), 'package.json')) : createRequire(import.meta.url);
  return req('playwright');
}

async function accedi({ conEmail }) {
  const email = dati.email;
  if ((await testo('I miei progetti').count()) > 0) return; // gia' dentro (secondo tentativo)
  await aspetta(campo('Email'), 30000);
  if (!conEmail) {
    // Il campo deve gia' contenere l'email (verificato dal passo "Ricorda email"); se non c'e' la si scrive, cosi' la prova prosegue
    // e il passo "Ricorda email" resta l'unico a risultare fallito.
    await clicca(campo('Email'));
    const attuale = (await valoreCampo('Email').catch(() => '')).trim();
    if (attuale !== email) conEmail = true;
  }
  if (conEmail) {
    await scrivi(campo('Email'), email);
    await finoA(async () => (await valoreCampo('Email')).trim() === email, 8000, "l'email scritta non risulta nel campo");
  }
  await scrivi(campo('Password'), password);
  await clicca(bottone('Accedi'));
  await aspetta(testo('I miei progetti'), 45000);
}

/** Chiude il menu Ruolo e il dialogo "Nuovo membro" (con "Annulla", senza salvare) finche' la pagina Squadra e' di nuovo libera. */
async function chiudiDialoghi() {
  for (let i = 0; i < 4; i++) {
    if ((await testo('Aggiungi membro').count()) > 0 && (await testo('Nuovo membro', { esatto: true }).count()) === 0) return;
    if ((await bottone('Annulla').count()) > 0) await clicca(bottone('Annulla'));
    else await page.keyboard.press('Escape');
    await pausa(600);
  }
}

async function eseguiProva() {
  const casella = () => page.getByRole('checkbox', { name: /Ricorda email/i });

  await passo(
    'Accesso con email e password (con "Ricorda email")',
    async () => {
      if ((await testo('I miei progetti').count()) === 0) {
        if ((await campo('Email').count()) === 0) await apri(`${SITO}/`);
        await aspetta(campo('Email'), 45000);
        if (!(await casella().isChecked())) {
          await clicca(casella());
          await finoA(() => casella().isChecked(), 5000, 'la casella "Ricorda email" non risulta spuntata');
        }
      }
      await accedi({ conEmail: true });
    },
    { fatale: true },
  );

  await passo('"Ricorda email": esci, riapri la pagina, il campo email e\' riempito', async () => {
    if ((await testo('I miei progetti').count()) > 0) await clicca(bottone('Esci'));
    await aspetta(campo('Email'), 20000);
    await page.reload({ waitUntil: 'load' });
    await abilitaSemantica();
    await aspetta(campo('Email'), 45000);
    // Flutter scrive nel campo reale solo quando il campo ha il focus: si clicca e poi si legge (come farebbe chi vuole modificarlo).
    await clicca(campo('Email'));
    let letto = '';
    try {
      await finoA(async () => ((letto = (await valoreCampo('Email')).trim()) === dati.email), 10000, 'il campo email non e\' riempito');
    } catch (e) {
      const salvato = await page.evaluate(() => Object.entries(localStorage).filter(([k]) => /remember/i.test(k)).map(([k]) => k)).catch(() => []);
      throw new Error(`${msg(e)} Valore letto: "${letto ? 'diverso dall\'email di prova' : 'vuoto'}". Chiavi di localStorage con "remember": ${JSON.stringify(salvato)}.`);
    }
    if (!(await casella().isChecked())) throw new Error('La casella "Ricorda email" non risulta piu\' spuntata dopo la riapertura.');
  });

  await passo(
    'Nuovo accesso (solo password, email gia\' compilata)',
    async () => {
      await accedi({ conEmail: false });
    },
    { fatale: true },
  );

  await passo('Elenco progetti: compare il progetto di prova', async () => {
    await aspettaContenuto(testo(nomi.progetto), 30000, 'il progetto di prova nell\'elenco');
    await controllaErroriVisibili();
  });

  await passo('Apertura del progetto: compaiono i 2 task', async () => {
    if ((await testo(nomi.taskInCorso).count()) === 0) await clicca(testo(nomi.progetto));
    await aspettaContenuto(testo(nomi.taskInCorso), 30000, 'il task in corso');
    await aspettaContenuto(testo(nomi.taskRilasciato), 10000, 'il task rilasciato');
    await controllaErroriVisibili();
  });

  await passo('Apertura di un task: compare la chat con la squadra', async () => {
    if ((await testo('Chiedi alla squadra').count()) === 0) await clicca(testo(nomi.taskInCorso));
    await aspettaContenuto(testo('Chiedi alla squadra'), 30000, 'la sezione "Chiedi alla squadra"');
    await controllaErroriVisibili();
  });

  await passo('Chat: invio di "prova e2e" e il messaggio compare', async () => {
    if (!(await D.trovaMessaggioChat(dep, runId, 0, L.MESSAGGIO_CHAT))) {
      await scrivi(campoChat(), L.MESSAGGIO_CHAT);
      await clicca(bottone('Invia'));
    }
    await finoA(() => D.trovaMessaggioChat(dep, runId, 0, L.MESSAGGIO_CHAT), 20000, 'il messaggio non risulta scritto in Firestore (regole o invio)');
    // Sullo schermo: l'avviso fisso mostrato dopo l'invio e il fumetto con l'autore. Il testo del messaggio non e' esposto
    // nell'albero accessibile (SelectableText): per quello vale il documento in Firestore qui sopra (autore, tipo e testo).
    await aspetta(testo('La domanda è stata inviata alla squadra'), 20000);
    await aspetta(page.locator(`[aria-label^="${escAttr(dati.email)} ·"]`), 20000);
    await controllaErroriVisibili();
  });

  // Dalla pagina del task si torna al progetto, poi Costi -> Squadra (come un utente). Se la navigazione dall'interfaccia non
  // funziona il passo FALLISCE (e' un difetto), ma i controlli successivi proseguono aprendo la pagina con l'indirizzo diretto.
  await passo('Navigazione dall\'interfaccia: progetto, Costi, Squadra', async () => {
    if ((await testo('Costi', { esatto: true }).count()) === 0) {
      await page.goBack({ waitUntil: 'load' }).catch(() => {});
      await aspetta(testo(nomi.taskInCorso), 20000);
    }
    await clicca(bottone('Costi'));
    await aspetta(testo('Costi sviluppo'), 20000);
    await clicca(bottone('Squadra'));
    await aspettaContenuto(testo(nomi.membri[0]), 20000, 'la pagina Squadra con i membri');
  });

  await passo('Squadra: i 2 membri compaiono', async () => {
    if ((await testo(nomi.membri[0]).count()) === 0) {
      rapporto.avvisi.push('Pagina Squadra aperta con l\'indirizzo diretto (#/team) perche\' la navigazione dall\'interfaccia non ha funzionato.');
      await apri(`${SITO}/#/team`);
    }
    for (const n of nomi.membri) await aspettaContenuto(testo(n), 20000, `il membro "${n}"`);
    await controllaErroriVisibili();
  });

  await passo('Aggiungi membro: Ruolo e\' un menu a tendina con 13 ruoli + "Altro…"', async () => {
    const attesi = L.ruoliDaSorgente(readFileSync(path.join(RADICE, 'lib', 'core', 'constants.dart'), 'utf8')).map(L.etichettaRuolo);
    if (attesi.length !== L.NUMERO_RUOLI_ATTESI) {
      throw new Error(`kMemberRoles ha ${attesi.length} ruoli nel codice, la prova ne attende ${L.NUMERO_RUOLI_ATTESI}: aggiornare la prova o il codice.`);
    }
    // Ripartenza pulita (secondo tentativo): chiude il menu e il dialogo eventualmente rimasti aperti, poi li riapre da capo.
    await chiudiDialoghi();
    await clicca(testo('Aggiungi membro'));
    await aspetta(testo('Nuovo membro', { esatto: true }), 15000);
    if ((await campo('Ruolo (testo libero)').count()) > 0) throw new Error('Il campo "Ruolo (testo libero)" e\' visibile subito: Ruolo non e\' un menu a tendina.');
    await clicca(testo('Scegli il ruolo'));
    const mancanti = [];
    for (const r of [...attesi, 'Altro…']) {
      try {
        await aspetta(testo(r, { esatto: true }), 6000);
      } catch {
        mancanti.push(r);
      }
    }
    if (mancanti.length > 0) throw new Error(`Voci mancanti nel menu Ruolo: ${mancanti.join(', ')}.`);
    await clicca(testo('Altro…', { esatto: true }));
    await aspetta(campo('Ruolo (testo libero)'), 10000);
  });

  await passo('Aggiungi membro: Annulla senza salvare (la squadra resta di 2 membri)', async () => {
    await chiudiDialoghi(); // clicca "Annulla" (se il menu Ruolo e' rimasto aperto lo chiude prima)
    await finoA(async () => (await testo('Nuovo membro', { esatto: true }).count()) === 0, 10000, 'il dialogo non si e\' chiuso');
    const n = await D.contaMembriDelRun(dep, runId);
    if (n !== 2) throw new Error(`Membri della squadra dopo Annulla: ${n} (attesi 2): il dialogo ha salvato qualcosa.`);
    for (const nome of nomi.membri) await aspetta(testo(nome), 10000);
  });

  await passo('Console del browser: nessun permission-denied e nessun errore', async () => {
    const c = rapporto.console;
    if (c.permessi.length > 0) throw new Error(`permission-denied in console (${c.permessi.length}): ${c.permessi.slice(0, 3).join(' || ')}`);
    if (c.errori.length > 0) {
      const testoErrori = `errori in console (${c.errori.length}): ${c.errori.slice(0, 3).join(' || ')}`;
      if (consoleStrict) throw new Error(testoErrori);
      rapporto.avvisi.push(testoErrori);
    }
  }, { tentativi: 1 });
}

function scriviRapporto() {
  const fallimenti = rapporto.passi.filter((p) => p.esito !== 'ok');
  const md = [];
  md.push(`## Prova UI sul sito di test: ${rapporto.esito}`);
  md.push('');
  md.push(`Sito: ${rapporto.sito} - progetto ${rapporto.progetto} - giro \`${rapporto.runId}\``);
  md.push('');
  md.push('| Passo | Esito | Tentativi |', '|---|---|---|');
  for (const p of rapporto.passi) md.push(`| ${p.nome} | ${p.esito} | ${p.tentativi} |`);
  for (const f of fallimenti) md.push('', `**${f.nome}**: ${f.errore}`, f.screenshot ? `Screenshot: \`${f.screenshot}\`` : '');
  if (rapporto.avvisi.length) md.push('', '### Avvisi', ...rapporto.avvisi.map((a) => `- ${a}`));
  if (rapporto.pulizia) md.push('', `### Pulizia: ${rapporto.pulizia.verificata ? 'verificata' : 'INCOMPLETA'} (eliminati ${rapporto.pulizia.eliminati.length}${rapporto.pulizia.errori.length ? `, errori: ${rapporto.pulizia.errori.join('; ')}` : ''})`);
  md.push('', 'Non provato da questa prova: vedi docs/progetto/test/e2e-ui.md.');
  writeFileSync(path.join(OUT, 'rapporto.json'), JSON.stringify(rapporto, null, 2));
  writeFileSync(path.join(OUT, 'rapporto.md'), `${md.join('\n')}\n`);
}

async function principale() {
  log(`Prova UI su ${SITO} (progetto ${L.PROGETTO_TEST}), giro ${runId}`);
  let provaOk = false;
  try {
    fase = 'Controllo del sito pubblicato';
    log(`${fase}...`);
    await verificaSitoPubblicato();

    fase = 'Creazione dei dati di prova';
    log('Creazione dei dati di prova nel progetto di TEST...');
    datiCreati = true; // prima della creazione: se si interrompe a meta' la pulizia (idempotente) toglie il parziale
    dati = await D.creaDatiDiProva(dep, { runId, password });
    nomi = dati.nomi;

    fase = 'Avvio del browser';
    const { chromium } = caricaPlaywright();
    browser = await chromium.launch({ headless: process.env.E2E_HEADED !== 'si', args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
    const contesto = await browser.newContext({ viewport: { width: 1280, height: 2000 }, locale: 'it-IT' });
    page = await contesto.newPage();
    page.setDefaultTimeout(20000);
    page.on('console', (m) => {
      const classe = L.classificaConsole(m.type(), m.text());
      rapporto.console.totale += 1;
      if (classe === 'permesso') rapporto.console.permessi.push(mask(m.text()).slice(0, 300));
      else if (classe === 'errore') rapporto.console.errori.push(mask(m.text()).slice(0, 300));
    });
    page.on('pageerror', (e) => {
      const t = mask(String(e?.message ?? e)).slice(0, 300);
      (L.classificaConsole('pageerror', t) === 'permesso' ? rapporto.console.permessi : rapporto.console.errori).push(t);
    });

    fase = 'Apertura del sito';
    log('Apertura del sito e passi della prova...');
    await apri(`${SITO}/`);
    await eseguiProva();
    await screenshot('finale.png');
    provaOk = rapporto.passi.every((p) => p.esito === 'ok');
  } catch (e) {
    if (!(e instanceof ProvaInterrotta)) {
      rapporto.passi.push({ nome: fase, esito: 'FALLITO', tentativi: 1, errore: msg(e), screenshot: await screenshot('fallimento-preparazione.png') });
      log(`  FALLITO Preparazione: ${msg(e)}`);
    } else {
      await screenshot('finale.png');
    }
  } finally {
    try {
      await browser?.close();
    } catch {}
    try {
      await ripulisci();
    } catch (e) {
      rapporto.pulizia = { eliminati: [], saltati: [], errori: [msg(e)], verificata: false };
      console.error(`Pulizia fallita: ${msg(e)}`);
    }
  }
  const pulizieOk = !datiCreati || rapporto.pulizia?.verificata === true;
  rapporto.esito = provaOk ? (pulizieOk ? 'SUPERATA' : 'SUPERATA, ma PULIZIA INCOMPLETA') : 'FALLITA';
  rapporto.fine = new Date().toISOString();
  scriviRapporto();
  log(`\nESITO: ${rapporto.esito}`);
  return provaOk ? (pulizieOk ? 0 : 3) : 1;
}

process.exit(await principale());
