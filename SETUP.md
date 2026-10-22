# Avanza — Configurazione Firebase

## Prerequisiti

- Flutter SDK ≥ 3.24
- Dart SDK ≥ 3.5
- Account Firebase (console.firebase.google.com)
- Node.js (per Firebase CLI)

---

## 1. Installa Firebase CLI e FlutterFire CLI

```bash
npm install -g firebase-tools
dart pub global activate flutterfire_cli
```

## 2. Login Firebase

```bash
firebase login
```

## 3. Crea il progetto Firebase

1. Vai su [console.firebase.google.com](https://console.firebase.google.com)
2. Crea un nuovo progetto (es. `avanza-app`)
3. Attiva **Authentication** → Email/Password
4. Attiva **Firestore Database** → Production mode

## 4. Configura FlutterFire

Dalla root del progetto:

```bash
flutterfire configure
```

- Seleziona il progetto Firebase creato
- Seleziona piattaforme: **web**, **android**, **ios**
- Questo genera automaticamente `lib/firebase_options.dart`

## 5. Configura Android

Scarica `google-services.json` da Firebase Console
(Impostazioni progetto → App Android) e mettilo in:

```
android/app/google-services.json
```

Verifica che `android/app/build.gradle` contenga:
```gradle
apply plugin: 'com.google.gms.google-services'
```

## 6. Configura iOS

Scarica `GoogleService-Info.plist` da Firebase Console
(Impostazioni progetto → App iOS) e mettilo in:

```
ios/Runner/GoogleService-Info.plist
```

## 7. Configura Web

Nessuna azione manuale — FlutterFire lo gestisce in `firebase_options.dart`.

## 8. Deploy Firestore Rules

```bash
firebase deploy --only firestore:rules
```

Il file `firestore.rules` nella root contiene le regole di sicurezza.

## 9. Crea il primo account admin

In Firebase Console → Authentication → Users → Add user

Oppure implementa una pagina di registrazione admin (non inclusa per sicurezza).

## 10. Avvia l'app

```bash
flutter pub get
flutter run -d chrome        # Web
flutter run -d emulator-...  # Android
flutter run -d iPhone...     # iOS
```

---

## Struttura dati Firestore

```
/projects/{projectId}
  name, description, githubUrl, clientCode, ownerId, createdAt, updatedAt

/projects/{projectId}/tasks/{taskId}
  title, description, clientRequest, status, phases[], notes[],
  estimatedHours, actualHours, hourlyRate, order, createdAt, updatedAt
```

## Come condividere un progetto con un cliente

1. Apri il progetto in Avanza (vista admin)
2. Tap **Modifica progetto** → copia il **codice cliente** a 6 caratteri
3. Invia il codice al cliente
4. Il cliente apre l'app → "Accedi con codice progetto" → inserisce il codice

## Integrazione multi-progetto (Claude Code / OpenCode)

Ogni progetto in Avanza può avere un **GitHub URL**. 
Quando crei o modifichi un progetto, inserisci l'URL del repository GitHub 
(es. `https://github.com/owner/repo`). Questo URL viene mostrato nella vista 
admin come riferimento, ma non sincronizza automaticamente i dati — i task 
vengono gestiti manualmente in Avanza.

**Workflow consigliato:**
- Crea un progetto Avanza per ogni repository che gestisci
- Aggiungi i task corrispondenti alle feature in sviluppo
- Aggiorna lo stato delle fasi man mano che il lavoro avanza
- Condividi il codice cliente con il committente per la trasparenza
