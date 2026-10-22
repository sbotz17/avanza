// Test per R-2 e R-3.
// I test R-2 usano uno stub di AuthService senza Firebase.
// I test R-3 (isInitializing) usano una piattaforma Firebase fake per test 3.
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
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
    if (_throwOnSignIn != null) throw _throwOnSignIn;
    throw UnimplementedError('signIn non implementato nello stub');
  }
}

// ─── Stub per R-3 (test 1 e 2): stream controllabile senza Firebase ──────────

/// Implementa AuthServiceBase con uno StreamController<User?> che può
/// emettere eventi controllati dai test, senza richiedere Firebase.
class _FakeAuthService implements AuthServiceBase {
  final _controller = StreamController<User?>();

  @override
  Stream<User?> get authStateChanges => _controller.stream;

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
  Future<UserCredential> signIn(String email, String password) =>
      throw UnimplementedError();

  void emit(User? user) => _controller.add(user);
  void dispose() => _controller.close();
}

// ─── Fake piattaforma Firebase per R-3 test 3 ────────────────────────────────

/// Fake di MultiFactorPlatform: si limita a chiamare super(auth).
/// Estendendo la classe concreta il token PlatformInterface viene
/// registrato correttamente — non è necessario MockPlatformInterfaceMixin.
class _TestMultiFactorPlatform extends MultiFactorPlatform {
  _TestMultiFactorPlatform(FirebaseAuthPlatform auth) : super(auth);
}

/// Fake di UserPlatform costruita a partire da dati Pigeon minimi.
/// L'estensione con super(...) registra il token corretto:
/// UserPlatform.verify() passerà senza errori.
class _TestUserPlatform extends UserPlatform {
  _TestUserPlatform(FirebaseAuthPlatform auth)
      : super(
          auth,
          _TestMultiFactorPlatform(auth),
          PigeonUserDetails(
            userInfo: PigeonUserInfo(
              uid: 'test-user-uid',
              isAnonymous: true,
              isEmailVerified: false,
            ),
            providerData: <Map<Object?, Object?>>[], // lista vuota, nessun provider
          ),
        );
}

/// Fake di FirebaseAuthPlatform con StreamController<UserPlatform?> controllabile.
/// delegateFor/setInitialValues ritornano this, così FirebaseAuth usa questa
/// istanza come delegate (lazy init di _delegatePackingProperty).
class _TestFirebaseAuthPlatform extends FirebaseAuthPlatform {
  final _ctrl = StreamController<UserPlatform?>.broadcast();

  _TestFirebaseAuthPlatform() : super();

  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  FirebaseAuthPlatform setInitialValues({
    PigeonUserDetails? currentUser,
    String? languageCode,
  }) =>
      this;

  @override
  UserPlatform? currentUser;

  @override
  Stream<UserPlatform?> authStateChanges() => _ctrl.stream;

  @override
  Stream<UserPlatform?> idTokenChanges() => Stream<UserPlatform?>.empty();

  @override
  Stream<UserPlatform?> userChanges() => Stream<UserPlatform?>.empty();

  void emitUser(UserPlatform? user) => _ctrl.add(user);
  void close() => _ctrl.close();
}

// ─────────────────────────────────────────────────────────────────────────────

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

  // ── R-3: isInitializing — logout al refresh della pagina ─────────────────
  // Test 1 e 2 usano _FakeAuthService (nessun Firebase).
  // Test 3 usa _TestFirebaseAuthPlatform per ottenere un User reale tramite
  // il meccanismo interno di FirebaseAuth._pipeStreamChanges, l'unico modo
  // per creare un'istanza di User (costruttore privato User._).
  group('AuthProvider.isInitializing — R-3', () {
    setUpAll(() async {
      // Necessario per usare i mock dei canali Pigeon di Firebase Core.
      TestWidgetsFlutterBinding.ensureInitialized();
      setupFirebaseCoreMocks();
      await Firebase.initializeApp();
    });

    late _FakeAuthService fakeAuth;
    late app.AuthProvider provider;

    setUp(() {
      fakeAuth = _FakeAuthService();
      provider = app.AuthProvider(authService: fakeAuth);
    });

    tearDown(() => fakeAuth.dispose());

    test('isInitializing è true all\'avvio prima del primo evento authStateChanges',
        () {
      // Prima che qualsiasi evento arrivi dallo stream, il flag deve essere true.
      expect(provider.isInitializing, isTrue);
    });

    test(
        'isInitializing diventa false e isLoggedIn false '
        'dopo authStateChanges con utente null', () async {
      fakeAuth.emit(null); // simula Firebase che risponde "nessun utente"
      await Future.microtask(() {}); // lascia propagare l'evento
      expect(provider.isInitializing, isFalse);
      expect(provider.isLoggedIn, isFalse);
    });

    test(
        'isInitializing diventa false e isLoggedIn true '
        'dopo authStateChanges con utente', () async {
      // Per questo test usiamo la piattaforma Firebase fake così FirebaseAuth
      // crea internamente un User._() reale avvolto attorno a _TestUserPlatform.
      final fakePlatform = _TestFirebaseAuthPlatform();
      FirebaseAuthPlatform.instance = fakePlatform;

      final authService = AuthService();
      final testProvider = app.AuthProvider(authService: authService);

      // Emetti uno UserPlatform fake: FirebaseAuth._pipeStreamChanges lo avvolge
      // in un User reale (costruttore privato) e lo passa al listener di AuthProvider.
      fakePlatform.emitUser(_TestUserPlatform(fakePlatform));
      await Future.microtask(() {}); // lascia propagare l'evento

      expect(testProvider.isInitializing, isFalse);
      expect(testProvider.isLoggedIn, isTrue);

      fakePlatform.close();
    });
  });
}
