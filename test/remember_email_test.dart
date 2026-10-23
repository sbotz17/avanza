// Test T-11: "Ricorda email su questo dispositivo" (servizio + pagina di accesso).
// Non serve Firebase: l'autenticazione è uno stub e lo spazio locale è simulato.
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:avanza/pages/login_page.dart';
// Alias per evitare il conflitto con AuthProvider di firebase_auth.
import 'package:avanza/providers/auth_provider.dart' as app;
import 'package:avanza/services/auth_service.dart';
import 'package:avanza/services/remember_email.dart';

class _FailingAuthService implements AuthServiceBase {
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
      throw FirebaseAuthException(code: 'weak-password');
  @override
  Future<UserCredential> signIn(String email, String password) =>
      throw FirebaseAuthException(code: 'wrong-password');
}

void main() {
  group('RememberEmailService', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('load restituisce null se non c\'è nulla di salvato', () async {
      expect(await RememberEmailService().load(), isNull);
    });

    test('save poi load restituisce l\'email (senza spazi)', () async {
      final s = RememberEmailService();
      await s.save('  mario@esempio.it ');
      expect(await s.load(), 'mario@esempio.it');
    });

    test('save ignora un\'email vuota', () async {
      final s = RememberEmailService();
      await s.save('   ');
      expect(await s.load(), isNull);
    });

    test('clear cancella il valore salvato', () async {
      final s = RememberEmailService();
      await s.save('mario@esempio.it');
      await s.clear();
      expect(await s.load(), isNull);
    });

    test('apply con remember=true salva, con remember=false cancella', () async {
      final s = RememberEmailService();
      await s.apply(remember: true, email: 'a@b.it');
      expect(await s.load(), 'a@b.it');
      await s.apply(remember: false, email: 'a@b.it');
      expect(await s.load(), isNull);
    });

    test('nello spazio locale c\'è solo la chiave dell\'email', () async {
      await RememberEmailService().save('a@b.it');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), {RememberEmailService.storageKey});
    });
  });

  group('LoginPage - ricorda email', () {
    Future<void> pumpLogin(WidgetTester tester) async {
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ChangeNotifierProvider<app.AuthProvider>(
          create: (_) => app.AuthProvider(authService: _FailingAuthService()),
          child: const MaterialApp(home: LoginPage()),
        ),
      );
      await tester.pumpAndSettle();
    }

    String emailText(WidgetTester tester) =>
        tester.widget<EditableText>(find.byType(EditableText).first).controller.text;

    bool checked(WidgetTester tester) =>
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value!;

    testWidgets('senza email salvata: campo vuoto e casella non spuntata',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await pumpLogin(tester);
      expect(emailText(tester), '');
      expect(checked(tester), isFalse);
      expect(find.text('Ricorda email su questo dispositivo'), findsOneWidget);
    });

    testWidgets('con email salvata: precompilata e casella spuntata',
        (tester) async {
      SharedPreferences.setMockInitialValues(
          {RememberEmailService.storageKey: 'mario@esempio.it'});
      await pumpLogin(tester);
      expect(emailText(tester), 'mario@esempio.it');
      expect(checked(tester), isTrue);
    });

    testWidgets('togliere la casella cancella l\'email salvata', (tester) async {
      SharedPreferences.setMockInitialValues(
          {RememberEmailService.storageKey: 'mario@esempio.it'});
      await pumpLogin(tester);
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      expect(checked(tester), isFalse);
      expect(await RememberEmailService().load(), isNull);
    });

    testWidgets('accesso fallito: non salva né email né password',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await pumpLogin(tester);
      await tester.tap(find.byType(CheckboxListTile));
      await tester.enterText(find.byType(TextFormField).at(0), 'mario@esempio.it');
      await tester.enterText(find.byType(TextFormField).at(1), 'segretissima');
      await tester.tap(find.widgetWithText(FilledButton, 'Accedi'));
      await tester.pumpAndSettle();
      expect(find.text('Email o password non corretti.'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), isEmpty);
    });
  });
}
