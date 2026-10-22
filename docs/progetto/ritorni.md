# Registro ritorni — Avanza

---

### R-1 — Icona aggiornata non visibile nel browser

- Data: 2026-10-22
- Esito verifica: non_riproducibile
- Prova della verifica: Il commit `c8dd3f9` ha aggiornato `web/favicon.png` e i file in `web/icons/` (Icon-192.png, Icon-512.png, Icon-maskable-192.png, Icon-maskable-512.png). Il deploy CI del commit è completato con successo (run #39800072514, 2026-10-22T14:56:00Z). `web/index.html` referenzia correttamente `favicon.png` e `icons/Icon-192.png`; `web/manifest.json` referenzia correttamente tutti i file in `icons/`. Nessun problema strutturale rilevato nel codice o nel deploy.
- Gravità: bassa
- Area: web / icone browser
- Descrizione: Andrea riferisce di non vedere la nuova icona nel browser su https://avanza-b62d7.web.app.
- Atteso: la nuova icona del logo app appare come favicon nel tab del browser e come icona PWA.
- Passi per riprodurre: 1. Aprire https://avanza-b62d7.web.app in una finestra del browser con cache pulita (modalità incognito). 2. Verificare il favicon nel tab del browser.
- Origine: Andrea
- Ambiente di segnalazione: produzione
- Urgente (corsia hotfix): no
- Stato: NON RIPRODUCIBILE
- Note / storico:
  - 2026-10-22: I file icona sono presenti nel repository e il CI li ha deployati con successo. Il comportamento è conforme a quanto previsto dal codice. La mancata visualizzazione dell'icona è con alta probabilità dovuta alla cache del browser (i favicon vengono memorizzati in cache aggressivamente dai browser). Azione consigliata ad Andrea: aprire https://avanza-b62d7.web.app in una finestra in modalità incognito. Se il problema persiste anche in incognito, riaprire la segnalazione con i dettagli del browser e la schermata del tab.

---

### R-3 — Logout al refresh della pagina (Flutter web)

- Data: 2026-10-22
- Esito verifica: confermato
- Gravità: alta (gli utenti vengono slogati a ogni F5 e devono reinserire le credenziali)
- Area: autenticazione / routing web
- Descrizione: Aggiornare la pagina su Flutter web (F5 o reload del browser) causa il logout invece di ripristinare la sessione autenticata.
- Atteso: dopo il refresh la sessione viene ripristinata da localStorage e l'utente rimane autenticato e sulla stessa pagina.
- Passi per riprodurre: 1. Fare login su https://avanza-b62d7.web.app. 2. Premere F5. 3. L'app reindirizza a `/login` invece di ripristinare la sessione.
- Origine: Andrea
- Ambiente di segnalazione: produzione
- Urgente (corsia hotfix): no
- Causa: `AuthProvider` non aveva un flag `_initializing`. Su Flutter web, Firebase ripristina la sessione da `localStorage` in modo asincrono: nell'istante subito dopo il refresh, `_user` è `null` e `isLoggedIn = false`, anche per un utente autenticato. `HomePage.build()` vedeva `isLoggedIn == false` e schedulava immediatamente `context.go('/login')` via `addPostFrameCallback`, prima che Firebase potesse emettere il primo evento `authStateChanges` con l'utente ripristinato.
- Correzione: (1) `AuthProvider`: aggiunto `_initializing = true` (diventa `false` al primo evento `authStateChanges`); aggiunto getter `isInitializing`. (2) `HomePage`: aggiunto controllo `if (auth.isInitializing)` prima del redirect a `/login` — mostra solo lo spinner mentre Firebase carica, senza fare redirect.
- File toccati: `lib/providers/auth_provider.dart`, `lib/pages/home_page.dart`, `test/auth_provider_test.dart` (3 nuovi test)
- Stato: PRONTO PER RILASCIO
- Note / storico:
  - 2026-10-22: Confermato per analisi statica del codice. Causa individuata in `AuthProvider` (mancanza del flag `_initializing`) e `HomePage` (redirect immediato senza aspettare Firebase). Fix applicato su `claude/epic-galileo-e9a406`. 12 test totali (7 unitari + 5 widget): tutti verdi.
  - 2026-10-22: APPROVATO dal validatore (commit `7782d40`). Correzione minimale confermata; nessuna zona protetta toccata. Report: `docs/progetto/test/test-R3-isInitializing-20261022.md`.

---

### R-2 — Spinner di caricamento infinito

- Data: 2026-10-22
- Esito verifica: confermato
- Prova della verifica: Due cause individuate per analisi statica del codice: (1) `AuthProvider.signIn()` catturava solo `FirebaseAuthException`; qualsiasi altra eccezione (errore di rete, `PlatformException`, ecc.) lasciava `_loading = true` per sempre — spinner del pulsante login mai rimosso. (2) `HomePage` era `StatelessWidget` con `FirestoreService()` creato in `build()`: ogni chiamata a `AuthProvider.notifyListeners()` (es. aggiornamento token Firebase) causava un nuovo `Stream` nel `StreamBuilder`, che resettava a `ConnectionState.waiting` mostrando di nuovo lo spinner.
- Gravità: alta (blocca l'uso dell'app in caso di errore di rete)
- Area: autenticazione / homepage
- Descrizione: Lo spinner di caricamento non si ferma mai, sia all'accesso sia dopo aver salvato un nuovo progetto.
- Atteso: lo spinner si ferma dopo il login (riuscito o fallito) e la lista progetti si carica stabilmente.
- Passi per riprodurre: 1. Aprire https://avanza-b62d7.web.app. 2. Inserire le credenziali. 3. Se l'accesso va a buon fine ma si verifica un errore di rete non-Firebase, il pulsante rimane con lo spinner. 4. Sulla homepage, ogni notifica di AuthProvider (es. refresh del token ogni ora) mostra di nuovo lo spinner.
- Origine: Andrea
- Ambiente di segnalazione: produzione
- Urgente (corsia hotfix): no
- Causa: (1) `lib/providers/auth_provider.dart`: mancava un `catch` generale in `signIn()`, `_loading` restava `true` su eccezioni non-Firebase. (2) `lib/pages/home_page.dart`: `FirestoreService()` e lo stream creati dentro `build()` di uno `StatelessWidget` — ogni rebuild per notifica `AuthProvider` generava un nuovo stream e uno spinner.
- Correzione: (1) Aggiunto `catch (_)` + `finally` in `signIn()` per garantire `_loading = false` in tutti i percorsi. Estratta interfaccia `AuthServiceBase` in `auth_service.dart` per testabilità (iniettabile). `AuthProvider` accetta ora `AuthServiceBase?` nel costruttore. (2) `HomePage` convertito in `StatefulWidget`; `FirestoreService` e stream creati una volta in `didChangeDependencies()`.
- File toccati: `lib/providers/auth_provider.dart`, `lib/services/auth_service.dart`, `lib/pages/home_page.dart`, `test/auth_provider_test.dart` (nuovo)
- Stato: PRONTO PER RILASCIO
- Note / storico:
  - 2026-10-22: Prima ricezione — segnalazione generica "il software non funziona per niente". Richiesti dettagli ad Andrea.
  - 2026-10-22: Andrea fornisce dettaglio: "spinner di caricamento non si ferma mai, sia all'accesso sia dopo aver salvato un nuovo progetto." Classificato come confermato. Corretto su `claude/epic-galileo-e9a406` con 4 test unitari (tutti verdi).
