# Audit completa di Avanza prima della PRIMA promozione staging -> main

- **Data**: 28/10/2026 (ora italiana, sera). **Tester**: agente `tester` (indipendente: ho rieseguito tutto, senza fidarmi dei resoconti).
- **Ramo dell'audit**: `docs/audit-completa-2026-10-28`, partito da `origin/staging` `9c4a2da`. Durante l'audit `staging` e avanzato a `8c096d5` (PR #34): la differenza con `9c4a2da` e di 10 file di sola documentazione (`.claude/skills/*`, `AGENTS.md`, `DECISIONI.md`, `docs/progetto/registro-decisioni.md`), nessun codice, regola o workflow. Il codice provato e quindi quello che sta per uscire. La pull request di promozione e la **#27** (aperta, `mergeable_state: clean`, 93 commit, 208 file, etichetta `tipo:sviluppo`).
- **Scopo**: gate prima della prima promozione, adattato ad Avanza da `.claude/skills/squadra-audit/SKILL.md` (le ondate di Closer non valgono: ondate di Avanza = accesso, progetti/task, squadra/costi, GitHub/funzioni, rilascio).
- Strumenti e script riproducibili: `docs/progetto/test/2026-10-28-audit-strumenti/` (leggi il suo `README.md`). Nessuna modifica al codice dell'applicazione.
- Copia datata di questo file: `docs/progetto/test/audit-2026-10-28.md`.

## ESITO

| # | Area | Esito | In una riga |
|---|---|---|---|
| 1 | Accesso e ruoli | **SUPERATA** (prova a dati finti su emulatori, app e regole vere) | 26/26 prove nel browser, 137/137 prove delle regole, 10/10 mutazioni individuate |
| 2 | Progetti e task (contatore T-N, chat) | **SUPERATA** (stessa prova) | 14/14 prove nel browser, chat e contatore T-N (R-4) verificati |
| 3 | Squadra e costi | **SUPERATA** (stessa prova) | 6/6 prove nel browser + 3 prove sul cliente (smartphone), costi mai visibili al cliente |
| 4 | Collegamento GitHub e funzioni | **SUPERATA a livello di codice, emulatore e regole**; la parte con GitHub, Secret Manager e permessi IAM reali **non e verificabile da qui** | 326/326 test (anche sull'emulatore Firestore), regole delle due collezioni nuove: tutto negato |
| 5 | Rilascio | **BLOCCATA** (azioni di Andrea, non difetti del codice) | i controlli si fermano come devono, ma backup con prova di ripristino IDENTICO, variabili, ambiente `produzione` e tag di ritorno non sono verificabili/presenti |

**FALLITA: nessuna area.** Il gate NON e chiuso: l'area 5 e BLOCCATA e, secondo la regola dell'audit, un'area BLOCCATA impedisce il rilascio. Nessun difetto bloccante o alto nel codice.

## Prove automatiche (una volta per blocco)

| Prova | Comando | Risultato |
|---|---|---|
| Analisi Flutter (stable 3.47.8 / Dart 3.13.7, scaricato in cartella temporanea) | `flutter pub get`, `flutter analyze --no-fatal-infos` | 0 errori, **6 info** preesistenti (3 in `lib/pages/admin/edit_task_page.dart`, 3 in `test/auth_provider_test.dart`) |
| Test Flutter | `flutter test` | **90/90** verdi |
| Build web di produzione | `flutter build web --release --base-href / --pwa-strategy=none` | riuscita; `controlla-build-ambiente.sh prod build/web` OK (contiene `avanza-b62d7`, nessuna traccia di `avanza-test`); `flutter_service_worker.js` vuoto |
| Funzioni | `npm ci`, `npm run build`, `npm test` in `functions/` | build OK, **326/326** test (12 suite) |
| Funzioni sull'emulatore Firestore | `firebase emulators:exec --only firestore --project demo-avanza "npm --prefix functions test"` | **326/326** |
| Regole | `python3 .claude/scripts/controlla-regole.py` | REGOLE OK |
| Workflow | `actionlint` su tutti i 12 file di `.github/workflows/` | nessun avviso |
| Script di shell | `shellcheck .claude/scripts/*.sh scripts/*.sh`, `bash -n`, `node --check scripts/registra-ore.mjs`, `py_compile` | solo note "info" (SC2015, SC2329: funzioni chiamate per nome), nessun errore |
| Promozione con `gh` finto | `bash .claude/scripts/prova-promozione.sh` | **57/57** casi |
| CI di GitHub sull'head di staging `8c096d5` (lettura API) | `gh api .../actions/runs` | `ci` (Analyze, Test, Build web, Build Functions) verde; `Deploy Avanza Web` push: **deploy-test completo verde** (hosting, regole e indici, funzione sul progetto di test); `promozione` e `avvisi` verdi |

`pubspec.lock` modificato da `flutter pub get` e stato ripristinato: nessun file tracciato modificato.

## Area 1 - ACCESSO e ruoli

**Come ho provato.** Build dell'app vera del ramo (`--dart-define=APP_ENV=test`) in una **copia fuori dal repository**, con le sole due righe che collegano l'app agli emulatori Auth e Firestore (`useAuthEmulator`/`useFirestoreEmulator`), servita in locale e pilotata con Chromium/Playwright (accessibilita attiva), con le `firestore.rules` di staging caricate nell'emulatore e dati finti (2 admin, 3 clienti, 3 progetti, task, costi, ore, squadra, chat). Account di prova: solo nell'emulatore.

| Prova (id nello script `t1_access.mjs`) | Esito |
|---|---|
| A1 link diretto a `/project/p1/edit` senza sessione porta a `/login?from=...` | OK |
| A2 password errata: resta su login con "Email o password non corretti." | OK |
| A3 login admin: torna alla pagina richiesta (`from`) | OK |
| A4 home admin: vede i suoi 2 progetti, NON quello di un altro admin | OK |
| A5 ricarica pagina (F5) da loggato: sessione ripristinata, nessun ritorno al login | OK |
| A6 admin su `#/client-home` riportato a `/home` | OK |
| A7 "Esci" porta al login; "Ricorda email" salva solo l'email in `localStorage` (mai la password) | OK |
| A8 dopo "Esci", `#/team` porta al login | OK |
| C1-C2 cliente collegato: va a `/client-home`, vede solo il suo progetto | OK |
| C3 cliente su `#/home`, `#/team`, `#/project/p1/edit`, `#/project/p1/costs`, `#/project/p1/task/t1/edit`, `#/project/p1/task/new/edit`: riportato a `/client-home` (6 percorsi) | OK |
| C4-C6 cliente apre progetto e task suoi: vede task e note, **nessun** costo, ore, tariffa, squadra, chat | OK |
| C7-C8 cliente apre un progetto non suo (di un altro admin, o dello stesso admin ma non collegato): non vede nulla di riservato | OK (vedi osservazione B-3) |
| N1 primo accesso di un utente senza `users/{uid}`: l'app lo crea come `client` (smartphone 390 px) | OK |
| N2-N4 cliente senza progetti: codice inesistente ("Nessun progetto trovato con questo codice."), codice troppo corto ("Il codice e di 6 caratteri."), codice giusto in minuscolo: collega solo quel progetto | OK |
| R1 registrazione nuovo cliente: finisce su `/client-home` con ruolo `client` | OK |

**Regole Firestore `users` e `clientAccess` (e tutte le altre)**: 137 prove con 5 attori (anonimo, admin proprietario, altro admin, cliente collegato, cliente non collegato) sull'emulatore, `rules_audit.py`: **137/137 come atteso** (24 consentite, 113 negate, tutte con HTTP 403 delle regole). In particolare: nessuna auto-promozione (creare il proprio profilo con `role=admin`, o cambiarlo, e rifiutato); `clientAccess` leggibile per ID ma mai elencabile; collegamento al progetto valido solo con il codice giusto e solo nel proprio profilo.
**Test delle prove (mutazioni)**: 10 regole rotte di proposito (chat aperta in lettura, limite 2000 tolto, update/delete consentiti, `authorUid` non controllato, `kind` libero, `taskCosts` e `timeEntries` letti dal cliente, auto-promozione, `githubRepos` aperto, `teamMembers` aperto): **tutte individuate** (da 1 a 4 prove rosse ciascuna).

**Residui area 1**: l'accesso con Auth reale del progetto di test e il sito di test pubblicato non sono stati aperti (non raggiungibili da qui: vedi "Cosa NON ho verificato").

## Area 2 - PROGETTI e TASK (kanban, dettaglio, contatore T-N, chat)

Prove nel browser (`t2_progetti_squadra.mjs`, admin A) e sulle regole:

| Prova | Esito |
|---|---|
| P1-P3 progetto: kanban con T-1 "In corso", T-2 "In test / QA", task validato e rilasciato; cambio a "Vista lista" e ritorno; clic su un task apre il dettaglio | OK |
| P4 dettaglio di un task non completato (admin): sezione "Chiedi alla squadra", riquadro "Stato attuale", messaggio storico della squadra | OK |
| P5 invio di una domanda: salvata con `from=admin`, `kind=domanda`, `authorUid`=admin, `createdAt` del server; appare il testo fisso "ti risponde al prossimo giro di lavoro" | OK |
| P6 domanda di 2100 caratteri: la UI la rifiuta ("massimo 2000 caratteri"), nessun messaggio salvato | OK |
| P7-P8 task validato o rilasciato: nessuna chat; task in test/QA: chat presente | OK |
| P9-P10 **contatore T-N**: dal contatore 3, due task creati da UI sono T-3 e T-4, contatore = 5; creato anche il documento costi | OK |
| P11 **R-4**: modificare nome del progetto da UI lascia invariati `nextTaskNumber`, codice cliente e proprietario | OK |
| P12-P13 dopo la modifica il task successivo e T-5 (nessun numero riusato), nessun T-N duplicato nel progetto | OK |
| P14 nuovo progetto da UI: proprietario = admin, contatore = 1, codice cliente di 6 caratteri, `clientAccess` collegato | OK |
| Chat lato squadra: `registra-ore.mjs` azioni `domande` (elenca, testo stampato come DATO NON FIDATO) e `rispondi` (vuoto e 2001 caratteri rifiutati, task inesistente rifiutato, risposta scritta come `squadra/risposta`, poi 0 domande aperte) sull'emulatore (`t5_script.mjs`) | OK |
| Regole sottocollezione `chat` (solo admin + proprietario; domanda 1..2000; `from=admin`, `kind=domanda`, `authorUid`=utente, `createdAt == request.time`; nessun campo in piu; nessun update/delete; clienti mai) | 26 prove, tutte come atteso; 5 mutazioni specifiche individuate |

**Compatibilita (ordine di pubblicazione)**: con le regole **vecchie** di `main` e l'app nuova (caso "rilascio fatto, regole non ancora pubblicate"), `t4_oldrules.mjs`: elenco progetti, dettaglio task e pagina costi funzionano; la chat mostra "Non riesco a leggere la chat." e l'invio fallisce con "non riuscito. Riprova." (nessun dato scritto). Con l'app **vecchia** (build di `main`) e le regole **nuove** (`t6_oldapp.mjs`, 9/9): admin e cliente funzionano, la vecchia app crea task con codice e contatore corretti, nessuna richiesta verso servizi reali.

## Area 3 - SQUADRA e COSTI

| Prova | Esito |
|---|---|
| S1 pagina Squadra: solo i membri del proprio admin, NON quelli di un altro admin | OK |
| S2 menu Ruolo a tendina: 13 ruoli standard + "Altro..." | OK |
| S3 nuovo membro salvato: ruolo, costo "42,5" (virgola decimale), tariffa, `ownerId` = admin, attivo | OK |
| S4 pagina costi (admin): ore, costi, produttivita | OK |
| S5-S6 "Registra ore" 2,5: le ore reali del task passano da 4 a 6,5, nasce la voce nel registro, il report in pagina si aggiorna | OK |
| X1 cliente (smartphone 390 px) su progetto e 2 task: **nessun** costo, ore, tariffa, euro, membro della squadra, chat | OK |
| Regole `taskCosts`, `timeEntries`, `teamMembers`: cliente collegato, cliente non collegato, altro admin e anonimo negati in lettura, scrittura ed elenco; 3 mutazioni individuate | OK |

## Area 4 - COLLEGAMENTO GITHUB e FUNZIONI

- **Test**: 326/326 in memoria e sull'emulatore (webhook con firma a due segreti, creazione progetto spenta di default, proprietario coerente, tetto giornaliero, approvazioni solo da `OWNER/MEMBER/COLLABORATOR`, nessun task creato, replay, segreto disabilitato = assente).
- **Lettura del codice**: `authenticate.ts` prova prima il segreto storico, poi (solo se esiste) quello della App, confronto a tempo costante, senza firma non consulta nemmeno Secret Manager; `linkConfig.ts` restituisce "spento" se manca anche un solo campo; `eventRouter.ts` limita le approvazioni; il gestore (`githubWebhook.ts`) intercetta ogni errore e risponde 500 senza dettagli.
- **Regole di `githubRepos` e `githubCollegamento`**: **nessuna regola scritta = tutto negato** (le scrive solo l'Admin SDK). Provato sull'emulatore con anonimo, cliente e admin: lettura, scrittura, cancellazione ed elenco di `githubRepos/*` e `githubCollegamento/*` e di una collezione inventata: **tutti negati** (anche all'admin, voluto). Mutazione "regola aperta in lettura" individuata.
- **Script di amministrazione**: azioni `domande`/`rispondi` provate (area 2); azioni `collegamento` provate dal tester di T-20 (report `2026-10-25-t20-fase1.md`), non rifatte da me.

**Non verificabile da qui**: GitHub reale, GitHub App, Secret Manager e permessi IAM del secondo segreto di produzione, workflow `e2e-webhook.yml` (si lancia solo dopo il rilascio, vedi area 5). Rischio da guardare (media, non provato): se il service account della funzione non puo leggere `GITHUB_APP_WEBHOOK_SECRET` e Secret Manager risponde "permesso negato" (e non "non trovato"), una richiesta con firma sbagliata darebbe 500 invece di 401: le richieste vere (firma storica) continuerebbero a funzionare, ma lo smoke test del rilascio (che si aspetta 401) fallirebbe. Controllo semplice per Andrea/guardiano: `gcloud secrets get-iam-policy` o il ruolo del service account.

## Area 5 - RILASCIO (BLOCCATA)

**Verificato per lettura e con prove locali** (`rilascio-produzione.yml`, `promozione.yml`, `setup-firestore.yml`, `deploy.yml`, `ci.yml`, script in `.claude/scripts/`):

| Controllo | Come | Esito |
|---|---|---|
| Parte da `main` anche con la prima unione manuale | `rilascio-produzione.yml` ha `on: push: branches: [main]`; la versione del file usata e quella del commit di unione (che la contiene); `deploy.yml` e `promozione.yml` partono solo da `staging`; simulazione di unione in un clone: albero di `main` = albero di `staging` (`main` e antenato di `staging`) | OK |
| Prerequisiti si fermano prima di toccare la produzione | `prereq.sh`, 6 scenari: nessun segreto, chiave non JSON, chiave del progetto di TEST, `PRODUZIONE_CONTROLLI_COMPLETI=true` senza bucket: **tutti fermano (rc=1)**; chiave giusta: passa | OK |
| Controlli completi (backup, prova di ripristino IDENTICO, confronto dati) | solo con `PRODUZIONE_CONTROLLI_COMPLETI=true`; **se la variabile non e `true` il rilascio parte comunque, solo con un avviso giallo** | **NON verificabile / non attivo** (vedi blocchi) |
| "Si rilascia la testa attuale di main" e "stesso contenuto gia provato su staging" | letto; `verifica-da-staging.sh` eseguito contro l'API vera di GitHub sul merge simulato: "contenuto identico al commit di staging `8c096d5`, deploy di test con sito, regole e funzione riusciti (esecuzione 40771804512)"; fallisce chiuso se non trova il commit | OK |
| La build di produzione non contiene la configurazione di test | `controlla-build-ambiente.sh prod` sulla build vera: OK | OK |
| Classificazione | `classifica-rilascio.sh` nel clone: `tipo=sviluppo`, `regole_cambiate=si`, base = commit precedente di `main` (nessun tag); senza tocco umano (`SVILUPPI_RICHIEDONO_APPROVAZIONE` assente = `no`) | OK |
| Smoke test (sito, cache, funzione, login) | eseguito contro una build di TEST servita in locale (controllo negativo): fallisce su configurazione di produzione assente e su intestazioni di cache; "nessun service worker" passa. **Non eseguito contro la produzione vera** (non va toccata) | OK come controllo negativo |
| Tag `ultimo-rilascio-ok` assente => ritorno non disponibile | passo "RITORNO 1" estratto ed eseguito: `ok=no`, "ritorno automatico non disponibile"; il job poi avvisa "ritorno NON riuscito o non disponibile" | OK (ma vedi blocco 2) |
| Ritorno automatico con tag presente | letto (build della versione precedente, Hosting, funzione, smoke, avviso) | non eseguibile qui |
| Regole e indici: il rilascio NON li pubblica | passo "Avviso se cambiano regole o indici"; Setup Firestore da `main`, con `verifica-da-staging.sh` e backup se il bucket c'e | OK (letto) |
| Protezione dei rami | `gh api .../rules/branches`: `main` = niente cancellazione, niente push forzato, solo pull request; `staging` = in piu controlli obbligatori `controlli, zone-protette, regole, nessun-segreto, blocco` (come da README-CI) | OK |
| Stato della promozione automatica | PR #27 aperta e pulita; il job `pr` e stato eseguito sull'ultimo push di staging, quindi **`SQUADRA_CI_ATTIVA` e `si`** (dedotto, non letto); il job `unione` non parte da solo finche `promozione.yml` nuovo non e su `main`; con regole diverse comunque non unisce | informativo (blocco 4) |

**Perche BLOCCATA (cose che solo Andrea o la CI possono fare/confermare; passi in fondo):**
1. **Backup e prova di ripristino IDENTICO non verificabili**: non posso leggere le variabili GitHub (`BUCKET_BACKUP_FIRESTORE`, `PRODUZIONE_CONTROLLI_COMPLETI`: HTTP 403 dal proxy) ne usare il bucket. Il piano `configurazioni-da-fare.md` sez. 7 punto 1 pretende il backup verificato PRIMA del salto: senza, il rilascio parte senza backup (solo avviso) e Setup Firestore pubblica le regole nuove senza backup (avviso).
2. **Nessun tag `ultimo-rilascio-ok`** (verificato: il repository non ha tag): al primo rilascio, se lo smoke test fallisce dopo il deploy, **non c'e ritorno automatico** e il nuovo sito resta pubblicato (arriva solo l'avviso). Il tag va creato prima sul commit che oggi e in produzione.
3. **Ambiente GitHub `produzione` e variabili non leggibili** (403): non posso confermare ne la restrizione al ramo `main` ne il revisore temporaneo previsto per il primo salto (sez. 7 punto 3).
4. **La promozione automatica e gia accesa** (`SQUADRA_CI_ATTIVA=si`, dedotto) mentre il piano (sez. 7 punti 4 e 6) la vuole spenta fino al primo rilascio riuscito: appena `main` avra il nuovo `promozione.yml`, ogni push su `staging` (anche solo documentazione, come #34) puo far partire `unione` e un secondo rilascio in coda. Non e un difetto del codice, ma e una decisione da prendere prima di unire.
5. **Regole Firestore da pubblicare dopo il rilascio** (Setup Firestore da `main`): finche non lo si fa la chat dell'admin non funziona (degrada in modo pulito, provato). Il resto dell'app no ne ha bisogno.

## Diff staging -> main (92 commit, 207 file all'inizio; ora 93 commit, 208 file con #34)

- 175 file aggiunti, 33 modificati, **nessuno cancellato**. Per cartella: `docs/progetto` 40, `functions/src` 31 (codice + test), `.claude/*` 66 (script 18, comandi 14, agenti 13, skills 10, modelli 5, hook, impostazioni, zone protette), `.opencode/*` 28, `.github/workflows` 12 (+ `README-CI.md`, `CODEOWNERS.esempio`), `lib/` 12, `test/` 6, `scripts/` 2, radice: `AGENTS.md`, `CLAUDE.md`, `opencode.jsonc`, `pubspec.yaml` (+`shared_preferences`), `.firebaserc` (alias `prod`/`test`), `.gitignore`, `firestore.rules`.
- **Segreti**: scansione delle righe aggiunte (chiavi private, token GitHub/Slack/AWS/OpenAI, service account JSON): nessuno. Unici valori "tipo chiave": le chiavi web di Firebase `AIza...` (pubbliche per natura; quella nuova e `lib/firebase_options_test.dart`, del progetto di test, che nella build di produzione NON finisce: verificato) e segreti finti nei test.
- **File di debug / compilati**: nessun `functions/lib` tracciato (`functions/.gitignore: /lib/`), nessun `node_modules`, `.log`, `.env`, `.local`, `backup-ok.json`, `__pycache__`; `.claude/worktrees` non e tracciato, ma **non e nemmeno in `.gitignore`** (osservazione B-2).
- **Regole Firestore diverse da `main`: ESATTAMENTE una aggiunta**, 20 righe: `match /chat/{messageId}` dentro `projects/{projectId}/tasks/{taskId}` (lettura solo `isAdmin() && isProjectOwner`; creazione solo domande dell'admin con campi, `authorUid`, testo 1..2000, `createdAt == request.time`; update/delete vietati). **Le due collezioni di T-20 (`githubRepos`, `githubCollegamento`) NON hanno regole**: restano chiuse per assenza di regola (default negato), scritte solo dall'Admin SDK. `firestore.indexes.json` e `firebase.json` **invariati** (l'indice `projects: ownerId + updatedAt` che serve alla home c'e). Tutte le regole esistenti sono identiche a `main`.
- **Duplicati / catalogo**: i 15 oggetti nuovi del backend (`functions/src/lib/*`) e i 4 nuovi dell'app (`chat_message`, `task_chat`, `team_member_tile`, `remember_email`) sono tutti in `catalogo.md`; nessun duplicato evitabile trovato.

## Difetti e osservazioni (da aprire nel flusso ritorni; nessuno blocca)

| Id | Gravita | Descrizione | Riproduzione | Competente |
|---|---|---|---|---|
| B-1 | bassa | `pubspec.lock` tracciato e non allineato a `pubspec.yaml`: manca `shared_preferences` (T-11); `flutter pub get` cambia 17 dipendenze. La CI risolve da sola (nessun errore), ma le build non sono riproducibili | `grep shared_preferences pubspec.lock` (nessun risultato) | sviluppatore-frontend |
| B-2 | bassa | `.claude/worktrees/` non e in `.gitignore`: un `git add -A` dal checkout principale lo includerebbe | `git check-ignore -v .claude/worktrees` (vuoto) | Coordinatore (impostazioni della squadra) |
| B-3 | bassa (preesistente, file non toccati dal diff) | Un cliente che apre `#/project/<id>` di un progetto non collegato vede la pagina "Progetto / Vista kanban / Nessun task disponibile" invece di un messaggio di accesso negato; nella console del browser compare l'errore interno dell'SDK Firestore `ID: ca9 / b815` (osservato nella prova su emulatore). Nessuna fuga di dati | accedere come cliente e aprire `#/project/pB` | designer-frontend / sviluppatore-frontend |
| B-4 | bassa | Un payload GitHub **firmato ma malformato** (es. `pull_request` senza `pull_request`) fa lanciare un'eccezione, risposta 500 e GitHub ritenta; i test lo documentano ("ECCEZIONE"). Il payload vero arriva sempre da GitHub e coerente | `functions/src/test/avversario-t20-head2.test.ts` (righe 64-77) | sviluppatore-backend |

**Da decidere con Andrea (non sono bug):**
- **O-1** Le note `[gh]` dei task (commit, branch, PR, "approvata da <login GitHub>", "approvazione di <login> non considerata") sono leggibili dai clienti collegati (le regole lo consentono: i task sono leggibili dai clienti). Cosi i clienti vedono i nomi utente GitHub della squadra e i messaggi dei commit. Preesistente (T-20 aggiunge solo la nota "non collaboratore"). E coerente con "il cliente non vede la squadra"?
- **O-2** R-4: se in produzione i contatori `nextTaskNumber` dei progetti reali sono gia stati azzerati da modifiche passate, i nuovi task rischiano codici T-N duplicati; la correzione dei dati e una modifica ai dati reali (backup, prova su copia, Andrea). Non verificabile da qui (non leggo la produzione).
- **O-3** Hardening, non nuovo: `clientAccess/{codice}` e leggibile per ID da qualsiasi utente registrato e il codice e di 6 caratteri da un alfabeto di 32 simboli (~1 miliardo di combinazioni) senza limite di richieste ne App Check: chi ha un account potrebbe tentare codici. Il collegamento da' accesso in sola lettura a stato e dettaglio dei task di quel progetto.

## Cosa NON ho verificato (dichiarato)

- Il **sito di test pubblicato** (`avanza-test-c33ef`: hosting, Auth reale, indici reali): non raggiungibile da questa rete (403 dal proxy). Al suo posto: app vera + regole vere su emulatori, con dati finti. Non provati: login con l'Auth reale, composite index sul database reale (il file c'e e il deploy di test e riuscito), intestazioni di cache dell'hosting, funzione `githubWebhook` di test (GET/POST).
- GitHub reale (webhook, App, E2E `e2e-webhook.yml`), Secret Manager e IAM (area 4); variabili, segreti, ambienti e protezioni oltre ai ruleset (area 5); il bucket dei backup e `backup-giornaliero.yml`; qualsiasi azione su `avanza-b62d7` (nessun accesso: da mandato).
- Browser diversi da Chromium, dispositivi reali (solo viewport 390 px e 1100 px, tema chiaro), Safari/Firefox, modalita privata.
- Il ritorno automatico con il tag presente (letto, mai eseguito); la reale esecuzione dei passi con `gcloud`/`firebase deploy`.
- Carico e concorrenza oltre ai test dell'emulatore.

## Incidente di prova dichiarato (onesta)

Nella prima esecuzione della prova nel browser il collegamento agli emulatori non era attivo (la definizione `EMU=1` non e un booleano valido: serve `EMU=true`). In quei pochi minuti il browser di prova ha inviato alcune richieste di accesso con **credenziali finte** e letture non autenticate (respinte) al **progetto di TEST** `avanza-test-c33ef` (Auth e Firestore reali), mai alla produzione, senza creare account ne scrivere dati. Corretto subito (build con `EMU=true`; da allora una guardia nella prova su app vecchia verifica che nessuna richiesta esca verso servizi reali: 0). Lo segnalo al Coordinatore perche lo annoti nel registro decisioni.

## Passi per Andrea (lista breve, nell'ordine)

Per sbloccare l'area 5 (nessuno richiede di toccare il codice):
1. **Backup**: in GitHub *Settings -> Variables* controlla `BUCKET_BACKUP_FIRESTORE`; lancia a mano *Actions -> backup-giornaliero -> Run workflow* e verifica che finisca con "IDENTICO"; poi imposta `PRODUZIONE_CONTROLLI_COMPLETI` = `true`. Se il bucket non esiste, e una decisione tua: senza, il primo salto parte senza backup.
2. **Tag di ritorno**: dopo aver controllato che `4e66a0e` sia cio che e oggi in produzione, crea il tag `ultimo-rilascio-ok` su quel commit (`gh api repos/sbotz17/avanza/git/refs -f ref=refs/tags/ultimo-rilascio-ok -f sha=4e66a0edf46809a8ea4c4f9860e7dfa252e10fca`).
3. **Promozione automatica**: valuta di mettere `SQUADRA_CI_ATTIVA` = `no` fino al primo rilascio riuscito (e `si` dopo), come da piano sez. 7.
4. **Ambiente `produzione`** (*Settings -> Environments*): limitato al ramo `main`, con te come revisore **solo per questo primo salto** (poi si toglie).
5. **Unione**: unisci la PR #27 con "Create a merge commit" (mai squash), poi approva l'ambiente `produzione` e segui il rilascio.
6. **Subito dopo**: *Actions -> Setup Firestore -> Run workflow* da `main` (pubblica regole e indici, con backup se c'e il bucket); poi *e2e-webhook* e *verifica-sito*. Controlla il secondo segreto: `GITHUB_APP_WEBHOOK_SECRET` o e assente, o il service account della funzione lo puo leggere.

Conferma facoltativa sul sito di test reale (non bloccante per l'audit, che si e fatta a dati finti): 1) entra come admin, ricarica la pagina con F5 e resta dentro; 2) apri un task non completato, scrivi una domanda in "Chiedi alla squadra" e vedila comparire; 3) in "Squadra" aggiungi un membro scegliendo il ruolo dal menu; 4) crea un task e controlla che il codice T-N sia il successivo senza ripartire da 1 dopo aver rinominato il progetto; 5) entra con un account cliente (registrato dalla pagina di accesso + codice progetto): vedi solo quel progetto, nessun costo, nessuna chat, e se incolli `#/team` nell'indirizzo torni alla tua pagina.

## Per il validatore

Rieseguibili senza dati reali: `rules_audit.py`, `mutate.py`, `e2e/*.mjs`, `prereq.sh`, `ritorno1.sh` (vedi `README.md` della cartella strumenti). Ogni esito qui sopra con "OK" ha un'uscita di comando che ho letto; ogni cosa non provata e scritta come non verificata.
