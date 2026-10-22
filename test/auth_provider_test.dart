// Test per R-2: spinner infinito al caricamento.
// Firebase non è inizializzato — si usa uno stub di AuthService.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
// Alias per evitare conflitto di nome con AuthProvider di firebase_auth_platform_interface.
import 'package:avanza/providers/auth_provider.dart' as app;
import 'package:avanza/services/auth_service.dart';

// Stub che implementa AuthServiceBase senza chiamare Firebase.
// Evita "No Firebase App '[DEFAULT]' has been created" nei test unitari.
class _StubAuthService implements AuthServiceBase {
  // Object? per coprire sia Exception sia Error (es. StateError).
  final Object? _throwOnSignIn;

  _StubAuthService({Object? throwOnSignIn})
      : _throwOnSignIn = throwOnSignIn;

  @override
  Stream<User?> get authStateChanges => const Stream.empty();

  @override
  User? get currentUser => null;

  @override
  bool get isLoggedIn => false;

  @override
  Future<void> signOut() async {}

  @override
  Future<UserCredential> createAccount(String email, String password) =>
      throw UnimplementedError();

  @override
  Future<UserCredential> signIn(String email, String password) async {
    // ignore: only_throw_errors
    if (_throwOnSignIn != null) throw _throwOnSignIn!;
    throw UnimplementedError('signIn non implementato nello stub');
  }
}

void main() {
  group('AuthProvider.signIn — R-2', () {
    test(
        'loading torna false dopo una FirebaseAuthException '
        '(comportamento già presente — verifica regressione)', () async {
      final stub = _StubAuthService(
        throwOnSignIn: FirebaseAuthException(code: 'wrong-password'),
      );
      final provider = app.AuthProvider(authService: stub);

      expect(provider.loading, isFalse);
      await provider.signIn('test@example.com', 'bad-password');
      // Dopo l'eccezione Firebase, loading deve essere false.
      expect(provider.loading, isFalse);
      expect(provider.error, isNotNull);
    });

    test(
        'loading torna false dopo un\'eccezione generica non-Firebase '
        '(era il bug R-2: _loading restava true indefinitamente)', () async {
      final stub = _StubAuthService(
        throwOnSignIn: Exception('network error'),
      );
      final provider = app.AuthProvider(authService: stub);

      expect(provider.loading, isFalse);
      final result = await provider.signIn('test@example.com', 'password');

      // Prima della correzione: loading restava true e lo spinner non si fermava.
      expect(provider.loading, isFalse,
          reason: 'lo spinner deve fermarsi dopo qualsiasi eccezione');
      expect(result, isFalse);
      expect(provider.error, isNotNull);
    });

    test('loading torna false dopo un\'eccezione di tipo Error', () async {
      final stub = _StubAuthService(
        // StateError è un Error, non un Exception — ancora più inaspettato.
        throwOnSignIn: StateError('unexpected state'),
      );
      final provider = app.AuthProvider(authService: stub);

      await provider.signIn('test@example.com', 'password');
      expect(provider.loading, isFalse);
    });

    test('loading è false all\'avvio (stato iniziale corretto)', () {
      final stub = _StubAuthService();
      final provider = app.AuthProvider(authService: stub);
      expect(provider.loading, isFalse);
      expect(provider.error, isNull);
      expect(provider.isLoggedIn, isFalse);
    });
  });
}
