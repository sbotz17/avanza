// PLACEHOLDER — questo file deve essere generato con 'flutterfire configure'
//
// SETUP INSTRUCTIONS:
// 1. Install FlutterFire CLI:  dart pub global activate flutterfire_cli
// 2. Login to Firebase:        firebase login
// 3. Configure project:        flutterfire configure
//    - Seleziona o crea il progetto Firebase
//    - Seleziona piattaforme: web, android, ios
//    - Questo sovrascriverà questo file con la configurazione reale
//
// 4. Per Android: scarica 'google-services.json' da Firebase Console
//    e mettilo in 'android/app/'
// 5. Per iOS: scarica 'GoogleService-Info.plist' da Firebase Console
//    e mettilo in 'ios/Runner/'
//
// Se provi a compilare senza configurare Firebase, vedrai un errore qui sotto.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    throw UnsupportedError(
      'Firebase non configurato. Esegui "flutterfire configure" '
      'per generare questo file con le credenziali reali del tuo progetto Firebase. '
      'Vedi SETUP.md per le istruzioni complete.',
    );
  }
}
