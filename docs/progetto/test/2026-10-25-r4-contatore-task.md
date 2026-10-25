# Test indipendente R-4 — modificare un progetto azzera il contatore dei codici T-N

- Data: 2026-10-25
- Tester: `tester` (verifica indipendente, senza fidarsi del resoconto dello sviluppatore)
- Ramo provato: `origin/fix/R-4-T-19-contatore-task`, commit `32c501e` (base `origin/staging` = `36c2515`)
- Ramo del report: `test/R-4-report` (solo report, un test nuovo e una riga di catalogo; nessuna PR)
- Strumenti: Flutter 3.47.8 stable (Dart 3.13.7) scaricato in una cartella temporanea; Node 22. `pubspec.lock` NON committato (riportato com'era).
- Ambiente: solo repository locale. Nessun accesso a Firestore reale, ne' a produzione, ne' al browser.

## Esito: SUPERATO

Nessun difetto bloccante o alto. Due osservazioni (una di processo con rischio concreto, vedi O-1) e tre note minori. Dettaglio sotto.

## 1. Criteri / punti richiesti

| # | Criterio | Come l'ho verificato | Esito | Evidenza |
|---|----------|----------------------|-------|----------|
| 1a | Il bug esiste sul codice di staging | Copia di `origin/staging` (`git archive`) in cartella temporanea; test di riproduzione che usa solo l'API vecchia (`copyWith`, `toMap`) | OK (bug riprodotto) | `flutter test test/repro_r4_test.dart` su staging: 2 test falliti, `Expected: <7> Actual: <1>` |
| 1b | Il bug esiste FINO alla scrittura su Firestore (non solo nel modello) | Nuovo test del tester `test/firestore_service_update_project_test.dart`: piattaforma Firestore finta che registra le `update` ricevute da `FirestoreService.updateProject` | OK (bug riprodotto) | Su staging il test fallisce: l'`update` contiene `name, description, githubUrl, clientCode, ownerId, nextTaskNumber, createdAt, updatedAt`, con `nextTaskNumber` = 1 per un progetto che valeva 7 |
| 1c | Sul ramo la correzione funziona | Stessi test sul ramo | OK | Sul ramo la stessa `update` contiene solo `name, description, githubUrl, updatedAt` (3/3 test del servizio verdi, 6/6 di `project_counter_test.dart`) |
| 2 | `flutter analyze` e `flutter test` | Eseguiti sul ramo (prima di aggiungere il mio test) | OK | `flutter test`: `00:27 +87: All tests passed!` (87 attesi). `flutter analyze`: 6 issues, tutte `info` preesistenti (3 `deprecated_member_use` in `edit_task_page.dart` 321/369/425, 3 in `test/auth_provider_test.dart` 86/133/136). Con il mio test: 90 test verdi, sempre 6 info |
| 3 | Altre scritture su `projects/{id}` che possano azzerare contatore o altri campi sensibili | Ricerca `set/update/create/delete/recursiveDelete/toMap` in `lib/`, `scripts/`, `functions/src/`, `.github/` e lettura di ogni punto | OK (nessuna puo' azzerare) | Tabella al punto 3 sotto |
| 4 | Calcolo del massimo T-N di `stato` nei casi limite | Estratto il codice REALE della funzione `stato` dal file e lanciato con un db finto: 16 casi | OK (16/16 come atteso) | Tabella al punto 4 sotto. Lo stesso banco di prova sul `registra-ore.mjs` di staging fallisce 16/16 (la riga non esiste): il banco distingue |
| 5 | Mutazioni fermate dai test (>= 3) | 6 mutazioni sul ramo, `flutter test` completo per ciascuna, file ripristinati e confrontati | OK con riserva (vedi D-1) | Tabella al punto 5 sotto |
| 6a | Modifiche ai modelli oltre il necessario | Lettura del diff `origin/staging...origin/fix/R-4-T-19-contatore-task` | OK | `project.dart`: +1 riga in `copyWith`, +1 metodo `editableFields()`. Nessun altro modello toccato |
| 6b | Nessuna modifica a regole, indici, funzioni, CI, dipendenze | `git diff --stat` limitato a `firestore.rules firestore.indexes.json functions .github pubspec.yaml pubspec.lock` | OK | Output vuoto |
| 6c | Catalogo / diario / ritorni / registro decisioni coerenti | Lettura | OK con osservazione | Catalogo: riga `Project` aggiornata con `editableFields` e il test. Diario e ritorni descrivono correttamente causa, correzione, 6 test, 87 verdi. Registro decisioni dichiara la zona protetta. Vedi O-1 (codice T-19) e N-2 |
| 6d | Classificazione come correzione o sviluppo | `python3 .claude/scripts/classifica-modifica.py origin/staging <json> .claude/zone-protette.json` con ramo `fix/R-4-T-19-contatore-task`, etichetta `tipo:correzione`, titolo con R-4 | OK (coerente con il registro) | `MOTIVO: tocca zone protette: scripts/registra-ore.mjs` / `TIPO=sviluppo` |

## 2. Esecuzioni

Comandi (eseguiti da me, non copiati dal resoconto):

```
flutter pub get
flutter analyze            -> 6 issues found (tutte info preesistenti)
flutter test               -> +87: All tests passed!   (ramo, senza il mio test)
flutter test               -> +90: All tests passed!   (ramo, con il mio test: +3)
flutter analyze            -> 6 issues found           (il mio test non aggiunge avvisi)
node --check scripts/registra-ore.mjs -> SYNTAX_OK
```

Riproduzione su staging (copia pulita di `origin/staging`, con aggiunto solo `test/repro_r4_test.dart`):

```
R-4 repro: copyWith conserva il contatore                         [E] Expected: <7> Actual: <1>
R-4 repro: la mappa scritta da updateProject (staging: toMap) ... [E] Expected: <7> Actual: <1>
```

Il test del servizio (mio) sul codice di staging:

```
Expected: not contains 'nextTaskNumber'
  Actual: ['name','description','githubUrl','clientCode','ownerId','nextTaskNumber','createdAt','updatedAt']
```

## 3. Tutte le scritture sui documenti `projects/{id}`

| Dove | Scrittura | Puo' azzerare `nextTaskNumber`? |
|------|-----------|--------------------------------|
| `lib/services/firestore_service.dart` `createProject` | `batch.set(ref, project.toMap())` su `doc()` nuovo con contatore 1 | No: documento appena creato (id nuovo) |
| `firestore_service.dart` `updateProject` | `update({...editableFields(), updatedAt})` | No dopo la correzione (prima SI: era il bug) |
| `firestore_service.dart` `createTask` (transazione) | `txn.update(projectRef, {nextTaskNumber: currentNext + 1, updatedAt})` | No: incrementa, legge nella stessa transazione |
| `firestore_service.dart` `updateTask` | `update({'updatedAt'})` sul progetto | No |
| `firestore_service.dart` `deleteProject` | batch delete | Cancella il progetto (comportamento voluto, non azzera) |
| `lib/pages/admin/edit_project_page.dart` (2 punti) | chiamano `updateProject(existing.copyWith(...))` | No dopo la correzione |
| `scripts/registra-ore.mjs` `importaTask` | transazione: legge `nextTaskNumber`, `tx.update(project.ref, {nextTaskNumber: n + 1})` | No (ma vedi N-1: se il contatore e' gia' indietro, assegna codici duplicati) |
| `scripts/registra-ore.mjs` `creaProgetto` | `batch.set` su `doc()` nuovo con `buildProjectData` (contatore 1) | No: documento nuovo |
| `scripts/registra-ore.mjs` `eliminaProva` | `recursiveDelete` del solo progetto di prova per nome esatto | No |
| `scripts/registra-ore.mjs` `migra` | scrive solo `clientAccess`, `taskCosts`, `users`; sui task `FieldValue.delete()` di costi | No: non scrive sul documento progetto |
| `scripts/e2e-webhook.mjs` | `taskRef.set(...)` e `delete()` su un task (`taskNumber: 9999`) | No: non tocca il progetto (ma vedi N-3 per `stato`) |
| `functions/src/lib/projectCreator.ts` | `tx.set(projectRef, buildProjectData(...))` SOLO se `project.exists` e' falso (controllo nella stessa transazione); id deterministico `gh_<repoId>` | No su progetti esistenti |
| `functions/src/lib/projectLink.ts` | `tx.update(projectRef, {githubRepoId, githubUrl, githubUrlPrecedente})` | No |
| `functions/src/lib/projectLink.ts` `applyRepositoryAction` | `tx.update(ref, {githubArchived|githubDeleted})` | No |
| `functions/src/lib/firestoreWriter.ts` (webhook) | `tx.update(taskRef, ...)` solo sul task | No |
| `lib/` altrove | nessun altro `.set/.update/.add` sul progetto | -- |

Campi sensibili (`clientCode`, `ownerId`, `createdAt`): l'unico scrittore che li sovrascriveva era il vecchio `updateProject` (via `toMap()`); ora non li scrive piu' (provato dal test del servizio). Nessun altro punto li riscrive su un progetto esistente.

Rimane aperto un solo "rischio residuo di difesa in profondita'" (non e' un difetto di questa correzione): le regole di `firestore.rules` consentono all'admin proprietario `update` senza limiti sui campi, quindi un client vecchio/modificato potrebbe ancora scrivere un contatore sbagliato. Le regole sono zona protetta e non fanno parte della correzione; segnalato solo come idea per uno sviluppo futuro.

## 4. Calcolo del massimo T-N in `stato` (codice reale, db finto, sola lettura)

Banco: `/tmp/claude-0/-home-user/a4a389bf-77be-5d81-ac7f-0c1bb199291a/scratchpad/stato-harness.mjs` (estrae `async function stato()` dal file e lo esegue con un db finto che non ha `set/update`: una scrittura lancerebbe errore).

| Caso | Atteso | Esito |
|------|--------|-------|
| nessun task, contatore 1 / assente | ok | OK |
| T-1..T-5, contatore 6 | ok | OK |
| T-1..T-5, contatore 5 (uguale al massimo) | ATTENZIONE | OK |
| T-1..T-5, contatore 1 (azzerato) | ATTENZIONE | OK |
| T-1..T-5, contatore assente | ATTENZIONE | OK |
| task vecchi senza codice (`taskNumber` 0, niente `taskCode`), contatore 1 | ok | OK |
| `taskCode` "T-abc" (senza numero), "T-" vuoto | ignorati, ok | OK |
| solo `taskCode` (taskNumber 0): T-3 con contatore 3 / 4 | ATTENZIONE / ok | OK |
| task di prova E2E (`T-9001`, `taskNumber` 9999) presente, contatore 12 | ATTENZIONE (falso allarme transitorio) | OK (comportamento atteso, vedi N-3) |
| dopo la pulizia del task di prova | ok | OK |
| "t-5" minuscolo; "T-1.5"; `taskNumber` in stringa "5" | non riconosciuto / non intero / numero | OK |

Tutti e 16 i casi danno l'esito atteso. `node --check` dello script: sintassi OK.

## 5. Mutazioni (script `.../scratchpad/mut.sh`, ripristino dei file verificato con `diff`)

| Mutazione | Fermata da | Esito |
|-----------|-----------|-------|
| M1 togliere `nextTaskNumber` da `copyWith` | `project_counter_test.dart` (2 test) | Fermata |
| M2 rimettere `project.toMap()` in `updateProject` | SOLO il mio `firestore_service_update_project_test.dart` (2 test). I 6 test dello sviluppatore + gli altri 81 restano VERDI (provato: 87/87 verdi con la mutazione) | Fermata solo dal mio test, vedi D-1 |
| M3 `editableFields` con `clientCode` in piu' | `project_counter_test.dart` (2) + mio test (2) | Fermata |
| M4 `editableFields` con `nextTaskNumber` in piu' | `project_counter_test.dart` (3) + mio test (2) | Fermata |
| M5 `copyWith` con `nextTaskNumber: 1` fisso | `project_counter_test.dart` (2) | Fermata |
| M6 `updateProject` aggiunge `'nextTaskNumber': 1` | SOLO il mio test (2) | Fermata solo dal mio test |

## 6. Difetti e osservazioni

### D-1 — Copertura: il test non copre che `updateProject` usi davvero `editableFields()` (gravita' BASSA, risolta dal tester)
- Descrizione: i 6 test dello sviluppatore provano `copyWith` e `editableFields()`, ma nessuno prova che `FirestoreService.updateProject` scriva SOLO quella mappa. Lo sviluppatore lo dichiara ("verificato dalla lettura del diff").
- Riproduzione: in `lib/services/firestore_service.dart` sostituire `...project.editableFields(),` con `...project.toMap(),`: `flutter test` resta 87/87 verde, e il bug torna.
- Rimedio gia' applicato dal tester: `test/firestore_service_update_project_test.dart` (3 test, nessuna dipendenza nuova; `FirebaseFirestorePlatform.instance` sostituita con una finta). Fallisce su staging e su M2/M3/M4/M6, passa sul ramo. Lo sviluppatore (`risolutore-bug`) puo' includerlo nella pull request invece di tenerlo solo nel mio ramo.
- Sviluppatore competente: `risolutore-bug` (includere il test). Non blocca.

### O-1 — Il codice T-19 e' gia' usato da un altro task (gravita' MEDIA, processo / dati)
- Il ramo si chiama `fix/R-4-T-19-contatore-task`, ma `T-19` e' il codice della funzionalita' "pagina Squadra" (diario 24/10: `feature/T-19-squadra-ruolo`, rami `fix/T-19-squadra`, `test/T-19-report`, registro decisioni "T-19"). Il webhook GitHub aggiorna i task cercando il codice nel nome del ramo: un ramo con `T-19` puo' muovere di stato il task sbagliato (quello della Squadra) invece del task di R-4.
- Possibile segno di un'istanza reale del bug stesso (due task con lo stesso T-19 nel progetto Avanza). Non verificabile da qui (nessun accesso ai dati reali).
- Azione richiesta al Coordinatore: lanciare l'azione di sola lettura `stato` (ora arricchita da questa correzione) per il progetto Avanza e controllare quanti task hanno `T-19` e se il contatore e' indietro; poi rinominare/rietichettare il ramo e la PR con il codice corretto. Se i contatori reali risultano azzerati, la correzione dei dati e' una decisione con Andrea (backup, elenco record, prova su copia), come gia' scritto in `ritorni.md`.
- Competente: Coordinatore (registro task in Avanza).

### Note minori (nessun rinvio obbligatorio)
- N-1: la correzione non ripara contatori GIA' azzerati sui dati reali (dichiarato dallo sviluppatore); `importaTask` e `createTask` non controllano che il codice non esista gia': se il contatore e' indietro assegnano codici duplicati. Fuori dal perimetro di R-4.
- N-2: il diario scrive `fix/R-4-contatore-task` come nome del ramo, mentre il ramo pubblicato e' `fix/R-4-T-19-contatore-task`; vecchio nome locale esistente. Solo documentazione.
- N-3: `stato` mostra il "massimo T-N" calcolato dal `taskNumber` quando presente: il task temporaneo del test E2E (`T-9xxx`, `taskNumber` 9999) fa comparire "T-9999" e un ATTENZIONE finche' esiste (nei secondi del test). Non e' un errore: serve solo saperlo se `stato` viene lanciato durante `e2e-webhook.yml`.
- N-4: `docs/database.md` non menziona che la modifica del progetto da app scrive solo nome/descrizione/githubUrl. Opzionale (redattore).

## 7. Riuso, duplicati e catalogo
- `editableFields()` e' un metodo nuovo su `Project`, registrato nel catalogo (riga `Project`). Nessun duplicato: non esisteva un altro elenco dei campi modificabili; `toMap()` resta per la creazione.
- Nessun widget, query o regola nuova. Il mio test e' stato aggiunto alla stessa riga del catalogo.

## 8. Cosa NON ho potuto provare
- Firestore reale (nemmeno l'emulatore): la `update` e' verificata fino alla piattaforma Firestore finta, non fino al server. Le regole le ho solo lette: `allow update: if signedIn() && resource.data.ownerId == request.auth.uid` non guarda i campi scritti, quindi una `update` con meno campi e' ammessa; non l'ho eseguita sull'emulatore.
- Browser / interfaccia reale: non ho aperto `edit_project_page.dart` ne' salvato un progetto da app (nessun accesso al sito, Firebase non configurato localmente). La catena modifica -> copyWith -> updateProject e' provata a livello di codice con test, non con clic.
- Esecuzione reale dell'azione `stato` del workflow (richiede credenziali e dati reali): provato solo `node --check` e la funzione in isolamento. Non so quindi se i contatori reali sono gia' azzerati.
- `functions/` (`npm run build`, `npm test`): non rieseguiti, perche' il diff non tocca `functions/` (nessuna regressione attesa); non verificato.
- Transazione concorrente `createTask` contro `updateProject` su Firestore reale (corsa tra salvataggi): la correzione elimina la causa (non si scrive piu' il contatore) ma non l'ho simulata.
- Il test `e2e-webhook.yml` e `verifica-sito.yml`: non lanciati (questa modifica non cambia regole o funzioni).

## 9. File del tester
- `/home/user/avanza/.claude/worktrees/agent-a18a9825ac4202e91/test/firestore_service_update_project_test.dart` (nuovo)
- `/home/user/avanza/.claude/worktrees/agent-a18a9825ac4202e91/docs/progetto/catalogo.md` (una riga: nome del test)
- Questo report.
