import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthServiceBase _authService;

  User? _user;
  bool _loading = false;
  // [R-3] true finché Firebase non ha emesso il primo evento authStateChanges.
  // Su Flutter web, Firebase ripristina la sessione da localStorage in modo
  // asincrono: _user è null nell'istante in cui AuthProvider viene costruito,
  // ma questo non significa che l'utente non sia autenticato — significa solo
  // che stiamo ancora aspettando la risposta di Firebase.
  bool _initializing = true;
  String? _error;

  User? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get loading => _loading;
  // [R-3] Espone lo stato di inizializzazione: true mentre Firebase sta
  // ripristinando la sessione, false dopo il primo evento authStateChanges.
  bool get isInitializing => _initializing;
  String? get error => _error;

  // [R-2] authService è iniettabile per consentire i test unitari senza Firebase.
  AuthProvider({AuthServiceBase? authService})
      : _authService = authService ?? AuthService() {
    _authService.authStateChanges.listen((user) {
      _user = user;
      _initializing = false; // [R-3] Firebase ha risposto: la sessione è nota
      notifyListeners();
    });
  }

  Future<bool> signIn(String email, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await _authService.signIn(email, password);
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _mapError(e.code);
      return false;
    } catch (_) {
      // [R-2] Qualsiasi altra eccezione (es. errore di rete non-Firebase)
      // veniva silenziata lasciando _loading = true indefinitamente.
      _error = 'Errore di accesso. Riprova.';
      return false;
    } finally {
      // Garantisce che _loading torni false in tutti i percorsi.
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
  }

  String _mapError(String code) {
    switch (code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email o password non corretti.';
      case 'too-many-requests':
        return 'Troppi tentativi. Riprova tra qualche minuto.';
      default:
        return 'Errore di accesso. Riprova.';
    }
  }
}
