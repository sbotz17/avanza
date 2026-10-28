# Strumenti dell'audit-completa del 28/10/2026

Tutto gira su **emulatori locali** (Firestore e Auth, progetto finto), con dati finti. Nessun servizio reale, nessuna chiave, nessun dato di produzione.
I percorsi nei file sono quelli della sessione di prova (cartella temporanea e worktree): vanno adattati in cima a ogni file se si ripete la prova altrove.

| File | A cosa serve |
|---|---|
| `firebase-emulatori.json` | Configurazione degli emulatori (Auth 9099, Firestore 8080) con le `firestore.rules` del ramo. Avvio: `firebase emulators:start --only auth,firestore --project avanza-test-c33ef` dalla cartella che contiene questo file rinominato `firebase.json`. |
| `rules_audit.py` | 137 prove delle regole di Firestore (anonimo, admin proprietario, altro admin, cliente collegato, cliente non collegato) su users, clientAccess, progetti, task, chat, taskCosts, timeEntries, teamMembers, githubRepos, githubCollegamento. Uso: `firebase emulators:exec --only firestore --project demo-avanza "python3 rules_audit.py"`. |
| `mutate.py` | 10 mutazioni delle regole: ognuna deve far diventare rossa `rules_audit.py` (verifica che la prova sappia davvero fallire). |
| `e2e/` | Prova dell'**app vera** (build web con `--dart-define=APP_ENV=test --dart-define=EMU=true`, dove `EMU=true` e' una modifica SOLO della copia di prova di `lib/main.dart` che collega l'app agli emulatori: `useAuthEmulator` e `useFirestoreEmulator`; il codice del repository non e' stato toccato) pilotata con Playwright/Chromium. `seed.mjs` crea dati finti; `t1_access.mjs` (accesso e ruoli), `t2_progetti_squadra.mjs` (progetti, task, chat, squadra, costi), `t3_codice.mjs` (collegamento con codice), `t4_oldrules.mjs` (app nuova con le regole vecchie di `main`), `t5_script.mjs` (azioni `domande` e `rispondi` dello script). |
| `prereq.sh`, `ritorno1.sh` | Prova del passo "Prerequisiti" e del passo "RITORNO 1" del rilascio con scenari finti. |

Limite noto della prova nel browser: i token dell'emulatore non sono firmati; per far ripristinare la sessione dopo il ricarico, le chiamate ai servizi di accesso Google sono instradate verso l'emulatore (`common.mjs`).
