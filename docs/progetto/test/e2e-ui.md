# Prova UI vera nel browser sul sito di TEST (`e2e-ui`)

Una prova automatica di accettazione che apre il **sito di test pubblicato** (https://avanza-test-c33ef.web.app, progetto Firebase `avanza-test-c33ef`)
con un browser vero (Chromium, pilotato da Playwright) e ripete i passi che farebbe un amministratore. Serve a verificare ogni rilascio senza che
Andrea debba provare nulla a mano. **Non tocca mai la produzione** (`avanza-b62d7`): lo script rifiuta di partire se qualcosa non e' di test.

Ramo di sviluppo: `test/e2e-ui-avanza`. Workflow: `.github/workflows/e2e-ui.yml` ("E2E UI (sito di test)"). Script: `scripts/e2e-ui-test.mjs`.

## Cosa prova

Prima di aprire il browser lo script crea, con l'Admin SDK e la chiave di TEST, **dati di prova con ID che iniziano con `e2e-ui-<ora>-<4 cifre>`**:
un utente (email `e2e-ui-...@example.invalid`, password casuale mai stampata ne' salvata) con `users/{uid}.role = 'admin'`, un progetto intestato a lui con 2 task
(uno "In corso", uno "Rilasciato") e 2 membri della squadra. Poi, nel browser:

| # | Passo | Cosa deve succedere |
|---|---|---|
| 0 | Controllo del sito pubblicato (prima di creare dati) | Risponde 200; `main.dart.js` contiene `avanza-test-c33ef` e NON `avanza-b62d7` ne' la chiave web di produzione; avvisi se la risposta sembra in cache o non e' l'ultima versione |
| 1 | Accesso con email e password, con "Ricorda email" spuntata | Si arriva a "I miei progetti" |
| 2 | "Ricorda email": esci, ricarica la pagina | Il campo Email e' riempito con l'email di prova e la casella e' ancora spuntata |
| 3 | Nuovo accesso (solo password) | Si arriva a "I miei progetti" |
| 4 | Elenco progetti | Compare il progetto di prova (nessun errore di lettura) |
| 5 | Apertura del progetto | Compaiono i 2 task |
| 6 | Apertura del task in corso | Compare "Chiedi alla squadra" (la chat) |
| 7 | Chat: invio di `prova e2e` | Il messaggio risulta scritto in Firestore (autore, tipo, testo: quindi le regole lo accettano), compare l'avviso "La domanda e' stata inviata alla squadra" e il fumetto con l'autore |
| 8 | Navigazione progetto -> Costi -> Squadra | Si arriva alla pagina Squadra con i pulsanti dell'interfaccia (se non funziona il passo fallisce, poi la prova prosegue con l'indirizzo `#/team`) |
| 9 | Squadra | Compaiono i 2 membri |
| 10 | "Aggiungi membro" | Ruolo e' un menu a tendina (il campo di testo libero non e' visibile subito) con **13 ruoli + "Altro…"**; scegliendo "Altro…" compare "Ruolo (testo libero)". L'elenco dei 13 ruoli e' letto da `lib/core/constants.dart` (`kMemberRoles`): se il numero cambia, la prova fallisce e va aggiornata |
| 11 | Annulla | Il dialogo si chiude senza salvare: i membri restano 2 (controllato anche in Firestore) |
| 12 | Console del browser | Nessun `permission-denied` / "Missing or insufficient permissions"; nessun altro errore di console (tranne `favicon` e `manifest.json`). Con `E2E_CONSOLE_ERRORI=avviso` gli errori diversi da permission-denied diventano solo avvisi |

Ogni passo ha **2 tentativi**. Se un passo fallisce: screenshot `fallimento-NN-<passo>.png` e l'elenco dei testi visibili a schermo nel rapporto. Alla fine sempre `finale.png`
e `rapporto.json` / `rapporto.md` (riepilogo anche nel "Summary" del workflow). Tutto e' nell'artifact `e2e-ui-risultati` (14 giorni).

## Pulizia

A fine prova, anche se la prova fallisce o viene interrotta (SIGINT/SIGTERM), lo script elimina **solo** cio' che appartiene al giro: progetto di prova con task, chat e costi,
i membri, il profilo `users/{uid}` e l'utente in Auth. Un documento si elimina solo se il suo ID e' quello del giro (o inizia con `<giro>-`) oppure, se l'ha creato l'utente di prova
dall'app, ha `ownerId` uguale al giro (`puoEliminare`, provata con test). Poi **verifica** che non sia rimasto nulla. Se la pulizia e' incompleta l'esito e' "SUPERATA, ma PULIZIA
INCOMPLETA" (exit 3). In piu' il workflow ha un passo finale di sicurezza (`node scripts/e2e-ui-test.mjs --pulisci <giro>`) per il caso in cui lo script venga ucciso di colpo.
Residui di giri vecchi (processo terminato con SIGKILL): `node scripts/e2e-ui-test.mjs --pulisci e2e-ui-<13 cifre>-<4 esadecimali>` (stesse guardie).

## Guardie (lo script rifiuta di partire, exit 2)

- `PROGETTO` deve essere esattamente `avanza-test-c33ef` (il workflow usa la variabile `PROGETTO_FIREBASE_TEST`, con questo valore come predefinito);
- la chiave di servizio (file in `GOOGLE_APPLICATION_CREDENTIALS`) deve avere `project_id` = `avanza-test-c33ef` e non contenere `avanza-b62d7`;
- `avanza-b62d7` non deve comparire in nessuna variabile d'ambiente (si stampa solo il NOME della variabile, mai il valore);
- il sito deve essere esattamente `https://avanza-test-c33ef.web.app` o `.firebaseapp.com`;
- nessun emulatore impostato (la prova serve a provare il sito vero);
- il workflow, prima, esegue `.claude/scripts/salvavita-test.sh` (riusato) e si ferma con `BLOCCO_SQUADRA` = `ATTIVO` o `BLOCCO-SQUADRA.md` attivo.
Nessun segreto in output: la password esiste solo in memoria e viene mascherata nei messaggi; la chiave e' scritta su file con permessi 600 e rimossa a fine giro.

## Come si lancia

- **A mano**: Actions -> "E2E UI (sito di test)" -> Run workflow (qualunque ramo che contenga il file).
- **Automatico**: a ogni push su un ramo `test/e2e-ui**`; e, **solo quando `e2e-ui.yml` sara' anche su `main`**, dopo ogni "Deploy Avanza Web" riuscito di `staging`
  (GitHub esegue i `workflow_run` solo dal ramo principale). In quel caso prova lo stesso commit appena pubblicato e segnala "SITO NON AGGIORNATO" se l'ultimo rilascio di Hosting
  e' anteriore al commit (fallimento) o avvisi se non riesce a leggerlo.
- **In locale** (con una chiave di test e Playwright installato): `PROGETTO=avanza-test-c33ef GOOGLE_APPLICATION_CREDENTIALS=<file> E2E_TOOLS_DIR=<cartella con playwright> node scripts/e2e-ui-test.mjs`.
- **Test unitari** (offline, 23 test; il 24-esimo, sugli emulatori, e' saltato senza emulatori): `node --test scripts/test/*.test.mjs`. Prova di creazione/pulizia sugli emulatori (serve Java):
  `firebase emulators:exec --only firestore,auth --project demo-avanza "node --test scripts/test/e2e-ui-dati.emulatore.test.mjs"`.

Playwright (`playwright@1.56.1`) e Chromium si installano in una cartella temporanea del runner: **nessuna dipendenza viene aggiunta al progetto**.

## Cosa NON prova

- Non prova la **produzione** (mai) ne' l'app mobile (non esiste).
- Non prova il ruolo **cliente** (registrazione, codice progetto, vista cliente), la creazione/modifica di progetti, task, costi e ore, la registrazione di un nuovo membro (si annulla), l'eliminazione.
- Non prova il **webhook GitHub** (c'e' `e2e-webhook.yml`) ne' le Cloud Functions.
- Il **testo** del messaggio di chat non e' leggibile nell'albero accessibile di Flutter (e' un `SelectableText`): lo si verifica nel documento in Firestore, non a schermo.
- Non prova tema scuro/chiaro, schermi piccoli (viewport fisso 1280x2000), altri browser (solo Chromium), ne' l'accessibilita' in senso stretto.
- Lo stato "Cache" del sito e' solo **segnalato** dalle intestazioni (Cache-Control, Age, X-Cache): non e' una garanzia.
- Gli unici errori di console tollerati sono `favicon` e `manifest.json`; il primo giro reale potrebbe mostrare altri messaggi benigni da mettere nell'elenco (`CONSOLE_IGNORATI`).

## Limiti noti della prova stessa

- Dipende dalla struttura accessibile (`flt-semantics`, `aria-label`) che Flutter produce: verificata su **Flutter 3.47.8** (stable al 28/10/2026). Un cambio importante di Flutter puo' richiedere di aggiornare i selettori
  (aiuti in `scripts/lib/e2e-ui-browser.mjs`). La scrittura nei campi e' verificata (Flutter a volte perde caratteri se si scrive in fretta) e ritentata.
- `--pwa-strategy` e' dichiarato deprecato da Flutter 3.47 (compare un avviso nella build): da tenere d'occhio in `deploy.yml` / `rilascio-produzione.yml`.

## Esito atteso

Exit 0 = SUPERATA e pulizia verificata; 1 = prova fallita (dettagli nel rapporto); 2 = guardie o uso sbagliato; 3 = pulizia incompleta.
