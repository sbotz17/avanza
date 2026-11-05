# Strumenti della prova R-5 (2/11/2026)

Script usati per la prova nel browser con **emulatori Firebase locali** e dati finti. Nessun servizio
reale, nessuna credenziale di produzione.

| File | A cosa serve |
|---|---|
| `seed_r5.mjs` | Crea l'utente `admin@test.it` (password `Prova-1234-xyz`), il progetto «Progetto Alfa» e 24 task finti sull'emulatore. |
| `e2e_r5.mjs` | Apre l'app con Chrome headless (Playwright), accede, apre il kanban, prova scorrimento verticale, scorrimento orizzontale col mouse e apertura di una scheda; salva screenshot. |

## Come si ripete (percorsi da adattare)

1. Copia di prova del repository (il `main.dart` del repo **non** si tocca): `git worktree add --detach /tmp/kb-e2e fix/kanban-scorrimento`.
2. In quella copia, in `lib/main.dart`, dopo `setPersistence`:
   ```dart
   if (_appEnv == 'test' && const bool.fromEnvironment('EMU')) {
     await FirebaseAuth.instance.useAuthEmulator('127.0.0.1', 9099);
     FirebaseFirestore.instance.useFirestoreEmulator('127.0.0.1', 8080);
   }
   ```
3. Nella copia, aggiungi a `firebase.json`:
   ```json
   "emulators": {"auth": {"port": 9099}, "firestore": {"port": 8080}, "ui": {"enabled": false}, "singleProjectMode": true}
   ```
4. Emulatori (richiede Java; su questa macchina `JAVA_HOME=/opt/homebrew/opt/openjdk`):
   `firebase emulators:start --only auth,firestore --project avanza-test-c33ef`
5. Build: `flutter build web --release --dart-define=APP_ENV=test --dart-define=EMU=true`
6. Servi `build/web` su `http://127.0.0.1:8099` (`python3 -m http.server 8099`), poi
   `PROJ=avanza-test-c33ef node seed_r5.mjs` e `node e2e_r5.mjs`.
7. Il percorso di Playwright in `e2e_r5.mjs` è assoluto (`/Users/andreabotti/.npm/_npx/...`): va aggiornato
   con `node -e "console.log(require.resolve('playwright'))"` o con `npx playwright`.

Nota: `assiIndipendenti` nel risultato può essere `false` per un ritardo dell'albero semantico di Flutter
web; la posizione reale va letta dagli screenshot.
