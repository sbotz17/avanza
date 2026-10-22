import 'package:firebase_auth/firebase_auth.dart';

// [R-2] Interfaccia astratta estratta per consentire l'iniezione di stub
// nei test unitari senza richiedere Firebase.initializeApp().
abstract class AuthServiceBase {
  Stream<User?> get authStateChanges;
  User? get currentUser;
  bool get isLoggedIn;
  Future<UserCredential> signIn(String email, String password);
  Future<void> signOut();
  Future<UserCredential> createAccount(String email, String password);
}

class AuthService extends AuthServiceBase {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  @override
  User? get currentUser => _auth.currentUser;

  @override
  bool get isLoggedIn => _auth.currentUser != null;

  @override
  Future<UserCredential> signIn(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<UserCredential> createAccount(String email, String password) =>
      _auth.createUserWithEmailAndPassword(email: email, password: password);
}
