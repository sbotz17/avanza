// Configurazione web del progetto Firebase di TEST (avanza-test-c33ef).
// Valori pubblici (identificano il progetto, non danno accesso): la sicurezza sta nelle regole Firestore.
// Si usa solo con --dart-define=APP_ENV=test (deploy.yml, ramo staging e anteprime).
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class TestFirebaseOptions {
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDrbseTaaz5aHOujeQLaO3NvOWk-5scw1Q',
    appId: '1:441647521749:web:322452997f3753dd47675c',
    messagingSenderId: '441647521749',
    projectId: 'avanza-test-c33ef',
    authDomain: 'avanza-test-c33ef.firebaseapp.com',
    storageBucket: 'avanza-test-c33ef.firebasestorage.app',
  );
}
