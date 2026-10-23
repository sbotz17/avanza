import 'package:shared_preferences/shared_preferences.dart';

/// [T-11] Ricorda l'email dell'ultimo accesso su questo dispositivo.
///
/// Si salva SOLO l'email (mai la password) nello spazio locale del browser.
/// Se lo spazio locale non è disponibile (navigazione privata, dati del sito
/// bloccati) tutte le operazioni falliscono in silenzio: l'accesso funziona
/// comunque, semplicemente l'email non viene ricordata.
class RememberEmailService {
  /// Chiave nello spazio locale. Il valore è l'email, nient'altro.
  static const storageKey = 'remembered_email';

  /// Email salvata, oppure null se non c'è (o è vuota).
  Future<String?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString(storageKey)?.trim();
      return (value == null || value.isEmpty) ? null : value;
    } catch (_) {
      return null;
    }
  }

  Future<void> save(String email) async {
    final clean = email.trim();
    if (clean.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(storageKey, clean);
    } catch (_) {}
  }

  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(storageKey);
    } catch (_) {}
  }

  /// Applica la scelta dell'utente: casella spuntata = salva, tolta = cancella.
  Future<void> apply({required bool remember, required String email}) =>
      remember ? save(email) : clear();
}
