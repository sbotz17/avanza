# Test T-11 "Ricorda email su questo dispositivo" — verifica del malfunzionamento segnalato sul sito di test

**Data**: 2026-10-23
**Tester**: Claude (agente `tester`)
**Ramo**: `claude/epic-galileo-e9a406` (uguale a `staging`, commit `0b4b9a9`)
**Segnalazione**: Andrea dice che sul sito di test, dopo aver spuntato la casella, essere uscito e aver ricaricato, l'email non compare nella pagina di accesso.

## Esito

**Il malfunzionamento NON è riproducibile con la build di test costruita dal codice del ramo.** In tutte le prove nel browser l'email viene salvata, ricordata e precompilata; il codice non ha il difetto sospettato (scrittura dopo lo smontaggio della pagina). Nessuna correzione al codice dell'applicazione è stata necessaria né applicata. Ho aggiunto 3 test di regressione che coprono proprio il percorso "accesso riuscito, pagina già smontata dal router", prima non coperto.

Causa non trovata nel codice. Le spiegazioni ancora possibili, che da qui NON si possono verificare, sono in fondo ("Non verificato" e "Ipotesi").

## Come ho provato (prova end-to-end vera)

1. Flutter: lo stable installato in `/opt/flutter` (Dart 3.5.4) è troppo vecchio per il progetto (`intl >=0.20.3` richiede Dart ^3.9; `flutter pub get` fallisce). Ho scaricato Flutter stable 3.47.8 (Dart 3.13.7, lo stesso usato dalla CI con `channel: stable`) in una cartella temporanea fuori dal repository.
2. Build come il test: `flutter build web --release --pwa-strategy=none --dart-define=APP_ENV=test`.
   - Controllo progetto: `grep -c avanza-test-c33ef build/web/main.dart.js` = 1; `grep -c avanza-b62d7 build/web/main.dart.js` = 0; nessun file di `build/web` contiene `avanza-b62d7`. Nessun accesso alla produzione.
3. Server statico locale (`python3 -m http.server 8099`) e Chromium (Playwright, cartella temporanea `/tmp/e2e`, fuori dal repository), con profilo persistente (stesso profilo per "chiudi e riapri il browser").
4. Il Chromium raggiunge davvero Firebase Auth e Firestore del progetto di test (identitytoolkit e firestore). Poiché `gstatic.com` non è raggiungibile dalla rete di prova, le sole librerie Firebase JS 11.9.1 (la versione richiesta da `firebase_core_web`) e CanvasKit si servono da file locali (npm `firebase@11.9.1` e `build/web/canvaskit`) e il font di sistema DejaVu sostituisce Roboto: cambia solo l'aspetto dei caratteri, non la logica dell'app.
5. Utenti: creati con la registrazione dell'app SOLO sul progetto di test (due utenti usa-e-getta `tester-t11-…@example.com`, ruolo cliente). La password casuale lunga è rimasta in un file temporaneo `/tmp` fuori dal repository, cancellato a fine prova; non compare in nessun file del repository né in questo report. Gli account di prova restano nel progetto di test (non ho strumenti per cancellarli: sono clienti senza progetti collegati).
6. Gli script di prova (`/tmp/e2e/*.mjs`) e gli screenshot (`/tmp/e2e/shots/`) sono fuori dal repository.

## Scenari e risultati

La verifica del contenuto del campo email è fatta con screenshot (l'etichetta "Email" resta in alto e il testo è visibile) e con `localStorage`; il valore letto dal DOM semantico di Flutter non è affidabile (risulta sempre vuoto anche quando lo screenshot mostra l'email), quindi non l'ho usato come prova.

| # | Scenario | Esito | Evidenza |
|---|---|---|---|
| S1 | Accesso con casella NON spuntata, poi Esci | OK: campo vuoto, casella non spuntata, `localStorage` senza `flutter.remembered_email` | `shots/02-login-dopo-esci-senza-ricorda.png` |
| (a) | Accesso con casella spuntata, Esci, pagina di accesso | OK: email precompilata, casella spuntata | `shots/05-a-login-dopo-esci-con-ricorda.png` |
| (b) | Come (a) e poi ricarica completa della pagina | OK: email precompilata, casella spuntata | `shots/06-b-login-dopo-reload.png` |
| (b2) | Come (a), chiusura e riapertura del browser con lo stesso profilo | OK: email precompilata e casella spuntata; `localStorage` conserva `flutter.remembered_email` | `shots/07-b2-login-dopo-riapertura-browser.png` |
| (c) | Casella tolta (cancella subito la chiave), accesso, Esci, ricarica | OK: campo vuoto, casella non spuntata, `localStorage` vuoto di `remembered_email` | `shots/13-c-login-dopo-esci-non-spuntata.png`, `shots/14-c-login-dopo-reload.png` |
| (d) | Cosa viene scritto in `localStorage`; ricarica da loggato | Chiave `flutter.remembered_email` con valore `"<email>"` (JSON stringa, come fa `shared_preferences_web`); nessuna password. Alla ricarica da loggato la pagina di accesso NON compare: è la sessione persistente voluta (`Persistence.LOCAL`) e il router porta direttamente alla home cliente | `shots/11-d-reload-da-loggato.png` |
| V1 | Invio con il tasto Invio nel campo password, casella spuntata | OK: salvata e precompilata dopo Esci | `shots/15-v1-login-dopo-invio.png` |
| V3 | REGISTRAZIONE (modalità "Registrati") con casella spuntata, smartphone 390x780 | OK: chiave scritta subito, email precompilata dopo Esci e dopo ricarica | `shots/20..23-reg-*-mobile.png` |
| V5 | Ordine degli eventi: scrittura della chiave contro scomparsa della pagina di accesso (campionamento ogni 5 ms) | La chiave è scritta a ~590 ms dal click su Accedi; la pagina di accesso scompare a ~1300 ms (attende la lettura del ruolo da Firestore). In altre prove la chiave compare a ~290 ms | log della prova |
| V2 | Accesso senza casella, Esci, spunto la casella e scrivo l'email SENZA premere Accedi, ricarico | Non viene salvato nulla (campo vuoto, casella non spuntata). È il comportamento voluto dai requisiti ("dopo un accesso riuscito"), ma da fuori sembra che la casella "non funzioni" | `shots/30-v2-spunta-senza-accedere-reload.png` |

### Sul sospetto "il salvataggio avviene dopo lo smontaggio della pagina"

- Nel browser l'ordine è: scrittura (290-590 ms) e poi smontaggio (~1300 ms), perché `signIn` ritorna prima che il router cambi pagina (il router aspetta la lettura del ruolo da Firestore).
- Anche nel caso inverso il salvataggio funzionerebbe: dopo `await auth.signIn(...)` il codice usa solo `_rememberService` e `_remember`, campi dello `State` che restano leggibili dopo `dispose()`, e `SharedPreferences.getInstance()` non dipende dal `BuildContext`. Non c'è un controllo `mounted` prima del salvataggio. Lo dimostra il nuovo test di widget (sotto), dove la pagina viene smontata mentre l'accesso è ancora in corso e l'email viene comunque salvata.
- `SharedPreferences` su web scrive davvero la chiave: verificato in `localStorage` (`flutter.remembered_email`).

## Test automatici

| Comando | Esito |
|---|---|
| `flutter analyze` (Flutter 3.47.8) | 6 "info" già presenti (3 in `edit_task_page.dart`, 3 in `test/auth_provider_test.dart`); nessun nuovo problema |
| `flutter test` | 37/37 verdi (erano 34; +3 miei) |
| `flutter test test/remember_email_test.dart` | 13/13 verdi |
| `flutter build web --release --pwa-strategy=none --dart-define=APP_ENV=test` | riuscita |
| `npm run build` / `npm test` in `functions/` | non eseguiti (la modifica non tocca le funzioni) |

Test aggiunti in `test/remember_email_test.dart` (gruppo "LoginPage - ricorda email"):
1. accesso riuscito con casella spuntata: l'email viene salvata (senza spazi, mai la password) anche se la pagina di accesso è già stata smontata dal router mentre l'accesso è in corso;
2. accesso riuscito con casella NON spuntata: non salva nulla;
3. accesso riuscito dopo aver tolto la casella: l'email salvata prima risulta cancellata.
Prima mancava il caso "accesso riuscito" (c'era solo "accesso fallito").

## Difetti e osservazioni

Nessun difetto bloccante/alto/medio riprodotto. Osservazioni:

1. **(bassa) `pubspec.lock` non allineato a `pubspec.yaml`** (già noto nel diario): non contiene `shared_preferences` (dipendenza introdotta da T-11) e `flutter pub get` con Flutter 3.47.8 lo modifica (+123 righe). Le CI usano `flutter pub get`, quindi le build funzionano, ma la build non è riproducibile dal lockfile. Competente: sviluppatore-frontend (rigenerare e committare `pubspec.lock`, zona protetta: va in un nuovo sviluppo o decisione di Andrea). Nel mio lavoro ho annullato la modifica con `git checkout pubspec.lock`: non è nel commit.
2. **(bassa, UX) La casella agisce solo dopo un accesso riuscito**: se si spunta la casella e si ricarica senza premere Accedi (scenario V2) non si salva nulla. È conforme ai requisiti ("dopo un accesso riuscito"), non è un difetto del codice; chi prova la funzione in quel modo conclude che non funziona. Se Andrea lo vuole diverso, è una modifica di comportamento (nuovo sviluppo).
3. **(info) L'ambiente di prova ha Flutter vecchio in `/opt/flutter`** (3.5.4): non compila il progetto. Va usato lo stable corrente (come in CI).

## Ipotesi sul problema visto da Andrea (non verificate)

In ordine di probabilità, da chiedere/controllare con Andrea:
1. **Ha provato senza fare un accesso riuscito dopo aver spuntato la casella** (vedi V2), per esempio era già dentro con la sessione persistente di prima, ha fatto Esci, ha spuntato la casella e ha ricaricato. Oppure, con la sessione persistente, "uscito e ricaricato" lo ha riportato direttamente nell'app senza mai mostrare la pagina di accesso (scenario (d)).
2. **Il sito di test serve una versione senza T-11 o una versione in cache**: la casella però c'è, quindi la versione ha T-11. Da verificare l'ultimo deploy di `deploy.yml` sul ramo `staging` e l'hash del `main.dart.js` pubblicato.
3. **Browser/dispositivo diverso dal Chromium provato** (Safari/iOS, Firefox, modalità privata, "blocca i dati dei siti"): lì `localStorage` può essere bloccato o cancellato; l'app in quel caso fallisce in silenzio per progetto (`remember_email.dart` ignora gli errori). Non provato.
4. **Accesso come admin** (Andrea): non ho credenziali admin e il ruolo si assegna solo da script. L'admin dopo l'accesso va a `/home` e fa Esci con `await auth.signOut(); context.go('/login')`: dal codice non emerge nulla che tocchi lo spazio locale, ma non l'ho provato.

## Non verificato

- Il sito pubblicato (`avanza-test-c33ef.web.app`): non raggiungibile dalla rete di prova (403 dal proxy). Non so quale build vi sia pubblicata.
- Browser diversi da Chromium (Firefox, Safari, mobile reale), modalità privata, estensioni, gestori di password/autofill del browser di Andrea.
- Accesso con un account admin.
- Le build di CI (`deploy.yml`): provate solo in locale con Flutter 3.47.8 (stable corrente) e con il lockfile ricalcolato da `flutter pub get`.

## File toccati

- `test/remember_email_test.dart` (3 test aggiunti, 1 stub di test).
- Questo report.
- Nessuna modifica a `lib/`, `.github/`, `.claude/`, `firestore.rules`, `pubspec.lock`; nessuna credenziale.

## Esito

**Malfunzionamento NON riprodotto; funzionalità T-11 SUPERATA nella prova end-to-end sul build di test locale** (con le limitazioni sopra). Nessun difetto da rimandare agli sviluppatori oltre alle osservazioni 1 e 2. Per chiudere il caso serve sapere il passo esatto fatto da Andrea e il browser usato, oppure verificare il sito pubblicato dalla CI (`verifica-sito.yml`).
