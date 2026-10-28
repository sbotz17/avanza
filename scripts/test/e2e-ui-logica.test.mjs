// Test unitari OFFLINE della logica della prova UI (scripts/lib/e2e-ui-logica.mjs). Nessuna rete, nessuna dipendenza.
// Si lanciano con:  node --test scripts/test/
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import {
  PROGETTO_TEST,
  PROGETTO_PRODUZIONE,
  NUMERO_RUOLI_ATTESI,
  generaRunId,
  isRunIdValido,
  emailDiProva,
  idDellaProva,
  generaPassword,
  mascheraSegreti,
  controllaGuardie,
  sitoNormalizzato,
  puoEliminare,
  valutaBundleSito,
  valutaIntestazioniCache,
  valutaAggiornamentoSito,
  classificaConsole,
  ERRORI_VISIBILI,
  ruoliDaSorgente,
  etichettaRuolo,
  slug,
} from '../lib/e2e-ui-logica.mjs';

const CHIAVE_OK = {
  type: 'service_account',
  project_id: PROGETTO_TEST,
  private_key: '-----BEGIN PRIVATE KEY-----\nXXXX\n-----END PRIVATE KEY-----\n',
  client_email: `firebase-adminsdk@${PROGETTO_TEST}.iam.gserviceaccount.com`,
};
const SITO = `https://${PROGETTO_TEST}.web.app`;
const ENV_OK = { PROGETTO: PROGETTO_TEST, HOME: '/home/runner', GITHUB_REPOSITORY: 'sbotz17/avanza' };

// ── identificativi ──
test('generaRunId: formato riconosciuto, email unica e @example.invalid', () => {
  const id = generaRunId(1761650000000, Buffer.from([0xa3, 0xf1]));
  assert.equal(id, 'e2e-ui-1761650000000-a3f1');
  assert.ok(isRunIdValido(id));
  assert.equal(emailDiProva(id), 'e2e-ui-1761650000000-a3f1@example.invalid');
  assert.notEqual(generaRunId(1761650000000, Buffer.from([1, 2])), generaRunId(1761650000001, Buffer.from([1, 2])));
});

test('isRunIdValido rifiuta tutto cio che non e un run di prova', () => {
  for (const x of ['', null, undefined, 42, 'e2e-ui-', 'e2e-ui-1761650000000', 'e2e-ui-1761650000000-zzzz', 'xe2e-ui-1761650000000-a3f1',
    'e2e-ui-1761650000000-a3f1/../users', 'e2e-ui-1761650000000-a3f1 ', 'projects/e2e-ui-1761650000000-a3f1', 'avanza-b62d7']) {
    assert.equal(isRunIdValido(x), false, String(x));
  }
  assert.throws(() => emailDiProva('admin'));
  assert.throws(() => idDellaProva('../x'));
});

test('idDellaProva: tutti gli ID derivano dal run', () => {
  const run = 'e2e-ui-1761650000000-a3f1';
  const ids = idDellaProva(run);
  assert.equal(ids.uid, run);
  assert.equal(ids.progetto, run);
  for (const id of [...ids.task, ...ids.membri]) assert.ok(id.startsWith(`${run}-`));
  assert.equal(ids.task.length, 2);
  assert.equal(ids.membri.length, 2);
});

test('generaPassword: lunga, casuale, diversa a ogni chiamata', () => {
  const a = generaPassword();
  const b = generaPassword();
  assert.ok(a.length >= 30);
  assert.notEqual(a, b);
  assert.match(a, /^[A-Za-z0-9_-]+$/);
});

test('mascheraSegreti toglie le password dai messaggi e ignora valori corti', () => {
  assert.equal(mascheraSegreti('login con S3gretoLungo ok', ['S3gretoLungo']), 'login con *** ok');
  assert.equal(mascheraSegreti('a S3gretoLungo b S3gretoLungo', ['S3gretoLungo']), 'a *** b ***');
  assert.equal(mascheraSegreti('abc', ['a']), 'abc');
  assert.equal(mascheraSegreti(undefined, ['xxxxxxx']), '');
});

// ── guardie ──
test('guardie: caso corretto (test) passa', () => {
  const r = controllaGuardie({ env: ENV_OK, credenziali: CHIAVE_OK, sitoUrl: SITO });
  assert.deepEqual(r, { ok: true, errori: [] });
});

test('guardie: PROGETTO diverso, mancante o vuoto = rifiuto', () => {
  for (const p of [PROGETTO_PRODUZIONE, 'avanza-test', 'avanza-test-c33ef ', undefined, '']) {
    const r = controllaGuardie({ env: { ...ENV_OK, PROGETTO: p }, credenziali: CHIAVE_OK, sitoUrl: SITO });
    assert.equal(r.ok, false, String(p));
  }
});

test('guardie: chiave di servizio della produzione = rifiuto (e nessun segreto nei messaggi)', () => {
  const prod = { ...CHIAVE_OK, project_id: PROGETTO_PRODUZIONE, client_email: `x@${PROGETTO_PRODUZIONE}.iam.gserviceaccount.com` };
  const r = controllaGuardie({ env: ENV_OK, credenziali: prod, sitoUrl: SITO });
  assert.equal(r.ok, false);
  assert.ok(!JSON.stringify(r).includes('XXXX'), 'la chiave privata non deve comparire');
});

test('guardie: chiave di un progetto qualunque diverso dal test (anche non di produzione) = rifiuto', () => {
  for (const id of ['altro-progetto', 'avanza-test', `${PROGETTO_TEST}-x`, '']) {
    const r = controllaGuardie({ env: ENV_OK, credenziali: { ...CHIAVE_OK, project_id: id }, sitoUrl: SITO });
    assert.equal(r.ok, false, id);
  }
});

test('guardie: produzione nascosta in un altro campo della chiave = rifiuto', () => {
  const r = controllaGuardie({ env: ENV_OK, credenziali: { ...CHIAVE_OK, client_x509_cert_url: `https://x/${PROGETTO_PRODUZIONE}` }, sitoUrl: SITO });
  assert.equal(r.ok, false);
});

test('guardie: chiave mancante, senza chiave privata o non oggetto = rifiuto', () => {
  assert.equal(controllaGuardie({ env: ENV_OK, credenziali: null, sitoUrl: SITO }).ok, false);
  assert.equal(controllaGuardie({ env: ENV_OK, credenziali: { ...CHIAVE_OK, private_key: 'abc' }, sitoUrl: SITO }).ok, false);
  assert.equal(controllaGuardie({ env: ENV_OK, credenziali: 'testo', sitoUrl: SITO }).ok, false);
});

test('guardie: avanza-b62d7 in una variabile = rifiuto, e si stampa solo il NOME della variabile', () => {
  const r = controllaGuardie({ env: { ...ENV_OK, ALTRA: `https://${PROGETTO_PRODUZIONE}.web.app` }, credenziali: CHIAVE_OK, sitoUrl: SITO });
  assert.equal(r.ok, false);
  const testo = r.errori.join('\n');
  assert.match(testo, /ALTRA/);
  assert.ok(!testo.includes('https://'), 'il valore della variabile non deve comparire');
});

test('guardie: emulatori impostati = rifiuto', () => {
  assert.equal(controllaGuardie({ env: { ...ENV_OK, FIRESTORE_EMULATOR_HOST: 'localhost:8080' }, credenziali: CHIAVE_OK, sitoUrl: SITO }).ok, false);
  assert.equal(controllaGuardie({ env: { ...ENV_OK, FIREBASE_AUTH_EMULATOR_HOST: 'localhost:9099' }, credenziali: CHIAVE_OK, sitoUrl: SITO }).ok, false);
});

test('guardie: il sito deve essere esattamente quello di test', () => {
  const ok = (u) => controllaGuardie({ env: ENV_OK, credenziali: CHIAVE_OK, sitoUrl: u }).ok;
  assert.equal(ok(SITO), true);
  assert.equal(ok(`${SITO}/`), true);
  assert.equal(ok(`https://${PROGETTO_TEST}.firebaseapp.com`), true);
  for (const u of [`https://${PROGETTO_PRODUZIONE}.web.app`, `http://${PROGETTO_TEST}.web.app`, `https://${PROGETTO_TEST}.web.app.evil.com`,
    `https://evil.com/${PROGETTO_TEST}.web.app`, `https://user@${PROGETTO_TEST}.web.app`, `https://${PROGETTO_TEST}.web.app/x`, '', 'non un url']) {
    assert.equal(ok(u), false, u);
  }
  assert.equal(sitoNormalizzato(`${SITO}/`), SITO);
});

// ── pulizia ──
test('puoEliminare: solo documenti del run (per ID o per ownerId)', () => {
  const run = 'e2e-ui-1761650000000-a3f1';
  const altro = 'e2e-ui-1761650000001-a3f1';
  assert.equal(puoEliminare(`projects/${run}`, null, run), true);
  assert.equal(puoEliminare(`users/${run}`, {}, run), true);
  assert.equal(puoEliminare(`teamMembers/${run}-m1`, {}, run), true);
  assert.equal(puoEliminare('teamMembers/casuale123', { ownerId: run }, run), true);
  assert.equal(puoEliminare('projects/casuale123', { ownerId: run }, run), true);
  // mai altro
  assert.equal(puoEliminare('projects/casuale123', { ownerId: 'altro-utente' }, run), false);
  assert.equal(puoEliminare('projects/casuale123', null, run), false);
  assert.equal(puoEliminare(`projects/${altro}`, { ownerId: altro }, run), false, 'altro run');
  assert.equal(puoEliminare(`projects/${run}x`, {}, run), false, 'prefisso senza trattino');
  assert.equal(puoEliminare('users/casuale123', { ownerId: run }, run), false, 'gli utenti solo per ID');
  assert.equal(puoEliminare(`projects/${run}/tasks/t1`, {}, run), false, 'solo documenti di primo livello');
  assert.equal(puoEliminare(`taskCosts/${run}`, {}, run), false, 'collezione non della prova');
  assert.equal(puoEliminare('projects', {}, run), false);
  assert.equal(puoEliminare(`projects/${run}`, {}, 'projects'), false, 'run non valido');
  assert.equal(puoEliminare(`projects/${run}`, {}, ''), false);
});

// ── sito ──
test('valutaBundleSito: test ok, produzione o file piccolo = errore', () => {
  const grande = (s) => `${'x'.repeat(120000)}${s}`;
  assert.equal(valutaBundleSito(grande(PROGETTO_TEST)).ok, true);
  assert.equal(valutaBundleSito(grande('niente')).ok, false);
  assert.equal(valutaBundleSito(grande(`${PROGETTO_TEST} ${PROGETTO_PRODUZIONE}`)).ok, false);
  assert.equal(valutaBundleSito(grande(`${PROGETTO_TEST} AIzaProd`), { apiKeyProduzione: 'AIzaProd' }).ok, false);
  assert.equal(valutaBundleSito(PROGETTO_TEST).ok, false, 'troppo piccolo');
  assert.equal(valutaBundleSito(undefined).ok, false);
});

test('valutaIntestazioniCache: avvisi su cache e Cache-Control mancante', () => {
  assert.deepEqual(valutaIntestazioniCache({ 'Cache-Control': 'no-cache' }).avvisi, []);
  assert.equal(valutaIntestazioniCache({}).avvisi.length, 1);
  assert.equal(valutaIntestazioniCache({ 'cache-control': 'public, max-age=3600' }).avvisi.length, 1);
  assert.equal(valutaIntestazioniCache({ 'cache-control': 'no-cache', age: '120' }).avvisi.length, 1);
  assert.equal(valutaIntestazioniCache({ 'cache-control': 'no-cache', 'x-cache': 'HIT' }).avvisi.length, 1);
  assert.equal(valutaIntestazioniCache({ 'cache-control': 'no-cache', 'x-cache': 'MISS', age: '0' }).avvisi.length, 0);
});

test('valutaAggiornamentoSito: aggiornato, non aggiornato, sconosciuto', () => {
  assert.equal(valutaAggiornamentoSito({}).stato, 'sconosciuto');
  assert.equal(valutaAggiornamentoSito({ rilascioIso: 'boh' }).stato, 'sconosciuto');
  assert.equal(valutaAggiornamentoSito({ rilascioIso: '2026-10-28T10:00:00Z' }).stato, 'informativo');
  assert.equal(valutaAggiornamentoSito({ rilascioIso: '2026-10-28T10:00:00Z', riferimentoIso: '2026-10-28T09:00:00+00:00' }).stato, 'aggiornato');
  assert.equal(valutaAggiornamentoSito({ rilascioIso: '2026-10-28T08:00:00Z', riferimentoIso: '2026-10-28T09:00:00+00:00' }).stato, 'non_aggiornato');
  assert.equal(valutaAggiornamentoSito({ rilascioIso: '2026-10-28T10:00:00Z', riferimentoIso: 'x' }).stato, 'sconosciuto');
  // fusi orari diversi: 11:00+02:00 = 09:00Z
  assert.equal(valutaAggiornamentoSito({ rilascioIso: '2026-10-28T09:00:00Z', riferimentoIso: '2026-10-28T11:00:00+02:00' }).stato, 'aggiornato');
});

// ── console ──
test('classificaConsole: permission-denied sempre grave, altri errori da classificare', () => {
  assert.equal(classificaConsole('error', '[cloud_firestore/permission-denied] The caller does not have permission'), 'permesso');
  assert.equal(classificaConsole('warning', 'FirebaseError: Missing or insufficient permissions.'), 'permesso');
  assert.equal(classificaConsole('log', 'permission-denied'), 'permesso');
  assert.equal(classificaConsole('error', 'Uncaught TypeError: x is null'), 'errore');
  assert.equal(classificaConsole('pageerror', 'boom'), 'errore');
  assert.equal(classificaConsole('error', 'Failed to load resource: favicon.ico 404'), 'ignora');
  assert.equal(classificaConsole('log', 'tutto bene'), 'ignora');
  assert.equal(classificaConsole('warning', 'deprecated'), 'ignora');
  assert.equal(classificaConsole('error', undefined), 'errore');
});

test('ERRORI_VISIBILI riconosce gli errori che l\'app mostra davvero (testi presi dal codice) e non i testi normali', () => {
  const vede = (t) => ERRORI_VISIBILI.some((re) => re.test(t));
  for (const t of ['Errore: [cloud_firestore/permission-denied] Missing or insufficient permissions.', 'Errore nel caricamento',
    'Non riesco a leggere la chat.', 'Invio non riuscito. Riprova.', 'FirebaseError: Missing or insufficient permissions']) {
    assert.equal(vede(t), true, t);
  }
  for (const t of ['I miei progetti', 'Chiedi alla squadra', 'E2E task in corso', 'Nessun task', 'Squadra', 'Salvataggio non riuscito']) {
    assert.equal(vede(t), false, t);
  }
});

// ── ruoli ──
test('ruoliDaSorgente: legge i ruoli veri da lib/core/constants.dart (13) e le etichette', () => {
  const dart = readFileSync(new URL('../../lib/core/constants.dart', import.meta.url), 'utf8');
  const ruoli = ruoliDaSorgente(dart);
  assert.equal(ruoli.length, NUMERO_RUOLI_ATTESI, `kMemberRoles ha ${ruoli.length} voci`);
  assert.ok(ruoli.includes('dba') && ruoli.includes('marketing') && ruoli.includes('sviluppatore backend'));
  assert.equal(etichettaRuolo('sviluppatore backend'), 'Sviluppatore backend');
  assert.equal(etichettaRuolo('dba'), 'Dba');
  assert.equal(etichettaRuolo(' '), '');
});

test('ruoliDaSorgente: sorgente senza elenco = lista vuota', () => {
  assert.deepEqual(ruoliDaSorgente('const x = 1;'), []);
  assert.deepEqual(ruoliDaSorgente(undefined), []);
  assert.deepEqual(ruoliDaSorgente("const List<String> kMemberRoles = ['a', 'b c'];"), ['a', 'b c']);
});

test('slug: nomi di file sicuri', () => {
  assert.equal(slug('Chat: invio "prova e2e"'), 'chat-invio-prova-e2e');
  assert.equal(slug('../../etc/passwd'), 'etc-passwd');
  assert.equal(slug('Città'), 'citta');
  assert.equal(slug('???'), 'passo');
});
