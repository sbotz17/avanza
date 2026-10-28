// Logica PURA (nessuna rete, nessuna dipendenza) della prova di accettazione UI di Avanza (scripts/e2e-ui-test.mjs).
// Sta in un file a parte perche' si prova con test unitari offline (scripts/test/e2e-ui-logica.test.mjs):
// guardie contro la produzione, identificativi della prova, regole di pulizia, valutazione del sito pubblicato.
import { randomBytes } from 'node:crypto';

export const PROGETTO_TEST = 'avanza-test-c33ef';
export const PROGETTO_PRODUZIONE = 'avanza-b62d7';
export const SITI_TEST_AMMESSI = [`https://${PROGETTO_TEST}.web.app`, `https://${PROGETTO_TEST}.firebaseapp.com`];
export const PREFISSO_RUN = 'e2e-ui-';
/** Ruoli standard del menu "Ruolo" (lib/core/constants.dart, kMemberRoles): la prova ne pretende esattamente 13 piu' "Altro…". */
export const NUMERO_RUOLI_ATTESI = 13;
/** Testo di prova scritto nella chat. */
export const MESSAGGIO_CHAT = 'prova e2e';

// ───────────────────────── identificativi della prova ─────────────────────────

/** `e2e-ui-<millisecondi>-<4 cifre esadecimali>`: unico per ogni giro, riconoscibile in ogni documento. */
export function generaRunId(adesso = Date.now(), casuale = randomBytes(2)) {
  return `${PREFISSO_RUN}${adesso}-${Buffer.from(casuale).toString('hex').slice(0, 4)}`;
}

export function isRunIdValido(id) {
  return typeof id === 'string' && /^e2e-ui-\d{13}-[0-9a-f]{4}$/.test(id);
}

export function assertRunId(runId) {
  if (!isRunIdValido(runId)) throw new Error('Identificativo di prova non valido (atteso e2e-ui-<13 cifre>-<4 esadecimali>).');
}

export function emailDiProva(runId) {
  assertRunId(runId);
  return `${runId}@example.invalid`;
}

/** Tutti gli ID creati dalla prova derivano dal run: la pulizia li riconosce da qui. */
export function idDellaProva(runId) {
  assertRunId(runId);
  return {
    uid: runId,
    progetto: runId,
    task: [`${runId}-t1`, `${runId}-t2`],
    membri: [`${runId}-m1`, `${runId}-m2`],
  };
}

/** Password casuale lunga: non viene mai stampata ne' salvata. */
export function generaPassword(casuale = randomBytes(24)) {
  return Buffer.from(casuale).toString('base64url');
}

/** Toglie dai messaggi ogni valore segreto (password, chiavi) prima di stamparli o salvarli. */
export function mascheraSegreti(testo, segreti) {
  let t = String(testo ?? '');
  for (const s of segreti ?? []) {
    if (typeof s === 'string' && s.length >= 6) t = t.split(s).join('***');
  }
  return t;
}

// ───────────────────────────── guardie anti-produzione ─────────────────────────────

/**
 * Controlla, PRIMA di fare qualunque cosa, che la prova lavori solo sul progetto di TEST.
 *  - env.PROGETTO deve essere esattamente il progetto di test (se manca: rifiuto);
 *  - la chiave di servizio deve appartenere al progetto di test;
 *  - il nome della produzione non deve comparire in nessuna variabile d'ambiente ne' nella chiave (si stampa solo il NOME della variabile);
 *  - il sito deve essere esattamente quello di test;
 *  - nessun emulatore (la prova serve a provare il sito vero).
 * Ritorna { ok, errori[] }. Non stampa mai valori.
 */
export function controllaGuardie({ env = {}, credenziali = null, sitoUrl = '' } = {}) {
  const errori = [];
  if (env.PROGETTO !== PROGETTO_TEST) {
    errori.push(`PROGETTO deve essere esattamente "${PROGETTO_TEST}" (valore non accettato o mancante).`);
  }
  if (!credenziali || typeof credenziali !== 'object') {
    errori.push('Chiave di servizio di test mancante o illeggibile.');
  } else {
    if (credenziali.project_id !== PROGETTO_TEST) errori.push(`La chiave di servizio non e' quella del progetto di test (${PROGETTO_TEST}).`);
    if (typeof credenziali.private_key !== 'string' || !credenziali.private_key.includes('PRIVATE KEY')) {
      errori.push('La chiave di servizio non contiene una chiave privata valida.');
    }
    if (JSON.stringify(credenziali).includes(PROGETTO_PRODUZIONE)) errori.push('La chiave di servizio contiene il riferimento alla PRODUZIONE.');
  }
  for (const [nome, valore] of Object.entries(env)) {
    if (typeof valore === 'string' && valore.includes(PROGETTO_PRODUZIONE)) {
      errori.push(`La variabile ${nome} contiene il riferimento alla PRODUZIONE.`);
    }
  }
  for (const nome of ['FIRESTORE_EMULATOR_HOST', 'FIREBASE_AUTH_EMULATOR_HOST']) {
    if (env[nome]) errori.push(`${nome} e' impostata: la prova deve usare il progetto di test vero, non un emulatore.`);
  }
  if (!sitoNormalizzato(sitoUrl)) {
    errori.push(`Il sito deve essere esattamente uno tra: ${SITI_TEST_AMMESSI.join(', ')}.`);
  }
  return { ok: errori.length === 0, errori };
}

/** Indirizzo del sito senza barra finale se e' uno di quelli di test; altrimenti null. */
export function sitoNormalizzato(sitoUrl) {
  let u;
  try {
    u = new URL(String(sitoUrl));
  } catch {
    return null;
  }
  const base = `${u.protocol}//${u.host}`;
  const esatto = u.username === '' && u.password === '' && u.search === '' && u.hash === '' && (u.pathname === '/' || u.pathname === '');
  return esatto && SITI_TEST_AMMESSI.includes(base) ? base : null;
}

// ───────────────────────────── pulizia: cosa si puo' eliminare ─────────────────────────────

const COLLEZIONI_PULIBILI = ['users', 'projects', 'teamMembers', 'clientAccess'];

/**
 * Un documento si elimina SOLO se: e' in una collezione della prova E il suo ID e' quello del run (o inizia con "<run>-")
 * OPPURE (documento creato dall'utente di prova dall'app) il campo ownerId e' esattamente il run.
 * `percorso` = percorso del documento di primo livello ("projects/<id>"); `dati` = i suoi campi (o null).
 */
export function puoEliminare(percorso, dati, runId) {
  if (!isRunIdValido(runId) || typeof percorso !== 'string') return false;
  const parti = percorso.split('/');
  if (parti.length !== 2) return false;
  const [collezione, id] = parti;
  if (!COLLEZIONI_PULIBILI.includes(collezione)) return false;
  if (id === runId || id.startsWith(`${runId}-`)) return true;
  return collezione !== 'users' && dati != null && dati.ownerId === runId;
}

// ───────────────────────────── sito pubblicato ─────────────────────────────

/** La build pubblicata deve parlare col progetto di test e non contenere nulla della produzione (come controlla-build-ambiente.sh). */
export function valutaBundleSito(js, { apiKeyProduzione = '' } = {}) {
  const errori = [];
  const testo = typeof js === 'string' ? js : '';
  if (testo.length < 100000) errori.push(`main.dart.js troppo piccolo (${testo.length} caratteri): sito non pubblicato o pagina di errore.`);
  if (!testo.includes(PROGETTO_TEST)) errori.push(`Il sito pubblicato NON contiene la configurazione del progetto di test (${PROGETTO_TEST}).`);
  if (testo.includes(PROGETTO_PRODUZIONE)) errori.push('Il sito di TEST contiene la configurazione della PRODUZIONE: non si prova.');
  if (apiKeyProduzione && testo.includes(apiKeyProduzione)) errori.push('Il sito di TEST contiene la chiave web della PRODUZIONE: non si prova.');
  return { ok: errori.length === 0, errori };
}

/** Intestazioni HTTP che fanno pensare a una risposta vecchia o in cache. Solo avvisi (mai blocco). */
export function valutaIntestazioniCache(headers = {}) {
  const h = Object.fromEntries(Object.entries(headers).map(([k, v]) => [k.toLowerCase(), String(v)]));
  const avvisi = [];
  const cc = h['cache-control'];
  if (!cc || !/no-cache|no-store|max-age=0/i.test(cc)) {
    avvisi.push(`Cache-Control del sito = "${cc ?? 'assente'}": atteso no-cache (firebase.json). Gli utenti potrebbero vedere una versione vecchia.`);
  }
  const age = Number.parseInt(h['age'] ?? '', 10);
  const conEta = Number.isFinite(age) && age > 0;
  if (conEta) avvisi.push(`La risposta e' stata servita da una cache (Age=${age}s): la versione potrebbe non essere l'ultima.`);
  if (/hit/i.test(h['x-cache'] ?? '') && !conEta) avvisi.push(`X-Cache="${h['x-cache']}": risposta servita da una cache.`);
  return { avvisi };
}

/**
 * Il sito e' aggiornato? Confronta l'ora dell'ultimo rilascio di Hosting con l'ora del commit di riferimento
 * (solo quando il giro nasce dal deploy di staging). Se manca un dato non si puo' dire: avviso, mai errore.
 */
export function valutaAggiornamentoSito({ rilascioIso, riferimentoIso } = {}) {
  if (!rilascioIso) return { stato: 'sconosciuto', messaggio: "Ora dell'ultimo rilascio di Hosting non disponibile: aggiornamento del sito non verificato." };
  const r = Date.parse(rilascioIso);
  if (Number.isNaN(r)) return { stato: 'sconosciuto', messaggio: `Ora di rilascio non leggibile (${rilascioIso}).` };
  if (!riferimentoIso) return { stato: 'informativo', messaggio: `Ultimo rilascio di Hosting: ${rilascioIso} (nessun commit di riferimento da confrontare).` };
  const c = Date.parse(riferimentoIso);
  if (Number.isNaN(c)) return { stato: 'sconosciuto', messaggio: `Ora del commit di riferimento non leggibile (${riferimentoIso}).` };
  return r >= c
    ? { stato: 'aggiornato', messaggio: `Sito aggiornato: rilascio ${rilascioIso} non anteriore al commit ${riferimentoIso}.` }
    : { stato: 'non_aggiornato', messaggio: `SITO NON AGGIORNATO: ultimo rilascio ${rilascioIso} e' anteriore al commit ${riferimentoIso}.` };
}

// ───────────────────────────── console del browser ─────────────────────────────

/** Messaggi che non sono un difetto dell'app (richieste di icone, ecc.). Elenco volutamente corto. */
export const CONSOLE_IGNORATI = [/favicon/i, /manifest\.json/i];

/** 'permesso' = permission-denied (sempre un fallimento); 'errore' = altro errore; 'ignora'. */
export function classificaConsole(tipo, testo) {
  const t = String(testo ?? '');
  if (/permission-denied|missing or insufficient permissions/i.test(t)) return 'permesso';
  if (tipo !== 'error' && tipo !== 'pageerror') return 'ignora';
  if (CONSOLE_IGNORATI.some((re) => re.test(t))) return 'ignora';
  return 'errore';
}

/** Testo visibile nell'app che segnala un errore di lettura o di permessi. */
export const ERRORI_VISIBILI = [/permission-denied/i, /insufficient permissions/i, /Errore nel caricamento/, /Non riesco a leggere la chat/, /Invio non riuscito/, /^Errore: /];

// ───────────────────────────── ruoli dal codice dell'app ─────────────────────────────

/** Legge l'elenco kMemberRoles da lib/core/constants.dart: la prova resta allineata al codice. */
export function ruoliDaSorgente(sorgenteDart) {
  const m = /const\s+List<String>\s+kMemberRoles\s*=\s*\[([\s\S]*?)\];/.exec(String(sorgenteDart));
  if (!m) return [];
  return [...m[1].matchAll(/'([^']+)'/g)].map((x) => x[1]);
}

/** Come memberRoleLabel (lib/widgets/team_member_tile.dart): prima lettera maiuscola. */
export function etichettaRuolo(ruolo) {
  const r = String(ruolo).trim();
  return r === '' ? r : r[0].toUpperCase() + r.slice(1);
}

/** Nome di file sicuro per gli screenshot. */
export function slug(testo) {
  return (
    String(testo)
      .toLowerCase()
      .normalize('NFD')
      .replace(/[̀-ͯ]/g, '')
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-+|-+$/g, '')
      .slice(0, 50) || 'passo'
  );
}
