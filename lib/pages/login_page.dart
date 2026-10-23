import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/remember_email.dart';
import '../core/constants.dart';

/// Accesso unico: email e password. Dopo l'accesso l'app mostra le pagine in
/// base al ruolo (admin: tutto; cliente: solo i progetti collegati).
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _rememberService = RememberEmailService();
  bool _obscure = true;
  bool _register = false;
  // [T-11] "Ricorda email su questo dispositivo": si salva SOLO l'email, mai la password.
  bool _remember = false;

  @override
  void initState() {
    super.initState();
    _loadRememberedEmail();
  }

  Future<void> _loadRememberedEmail() async {
    final saved = await _rememberService.load();
    if (!mounted || saved == null) return;
    // Non sovrascrive ciò che l'utente ha già iniziato a scrivere.
    if (_emailCtrl.text.isEmpty) _emailCtrl.text = saved;
    setState(() => _remember = true);
  }

  Future<void> _onRememberChanged(bool? value) async {
    final remember = value ?? false;
    setState(() => _remember = remember);
    // Se la casella viene tolta, il valore salvato si cancella subito.
    if (!remember) await _rememberService.clear();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  // Dopo l'accesso non si naviga a mano: il router reagisce al cambio di
  // sessione e porta ogni ruolo alla sua pagina.
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final email = _emailCtrl.text.trim();
    final ok = _register
        ? await auth.register(email, _passCtrl.text)
        : await auth.signIn(email, _passCtrl.text);
    // L'email si salva solo dopo un accesso riuscito (mai la password).
    if (ok) await _rememberService.apply(remember: _remember, email: email);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = context.watch<AuthProvider>();
    final fg2 = isDark ? kFg2Dark : kFg2Light;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Column(
                  children: [
                    Image.asset(
                      'assets/images/logo.png',
                      width: 80,
                      height: 80,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Avanza',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _register
                          ? 'Crea il tuo account cliente'
                          : 'Accedi con la tua email',
                      style: TextStyle(fontSize: 14, color: fg2),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Inserisci la tua email' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passCtrl,
                        obscureText: _obscure,
                        autofillHints: [
                          _register
                              ? AutofillHints.newPassword
                              : AutofillHints.password,
                        ],
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outlined),
                          suffixIcon: IconButton(
                            icon: Icon(_obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Inserisci la password' : null,
                        onFieldSubmitted: (_) => _register ? null : _submit(),
                      ),
                      if (_register) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _confirmCtrl,
                          obscureText: _obscure,
                          decoration: const InputDecoration(
                            labelText: 'Ripeti la password',
                            prefixIcon: Icon(Icons.lock_outlined),
                          ),
                          validator: (v) => v != _passCtrl.text
                              ? 'Le due password non coincidono'
                              : null,
                          onFieldSubmitted: (_) => _submit(),
                        ),
                      ],
                      if (auth.error != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          auth.error!,
                          style: TextStyle(
                            color: isDark ? kBlockedColorDark : kBlockedColor,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 4),
                      CheckboxListTile(
                        value: _remember,
                        onChanged: auth.loading ? null : _onRememberChanged,
                        title: const Text(
                          'Ricorda email su questo dispositivo',
                          style: TextStyle(fontSize: 13),
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: auth.loading ? null : _submit,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor:
                              isDark ? kActiveColorDark : kActiveColor,
                        ),
                        child: auth.loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _register ? 'Crea account' : 'Accedi',
                                style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w600),
                              ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: auth.loading
                      ? null
                      : () => setState(() => _register = !_register),
                  child: Text(
                    _register
                        ? 'Hai già un account? Accedi'
                        : 'Sei un cliente e non hai un account? Registrati',
                  ),
                ),
                if (_register)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Dopo la registrazione inserisci il codice progetto che ti '
                      'ha dato il tuo referente: resterà collegato al tuo account.',
                      style: TextStyle(fontSize: 12, color: fg2),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
