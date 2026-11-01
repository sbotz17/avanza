import 'package:intl/intl.dart';

/// Formattazione unica di date e orari nell'app (italiano, 24 ore).
/// Un task vecchio può non avere `createdAt`/`updatedAt`: in quel caso il
/// modello usa una data sentinella e qui si mostra "data non disponibile"
/// invece di una data inventata.
class AppDate {
  static final DateFormat _dateTime = DateFormat('dd/MM/yyyy HH:mm');
  static final DateFormat _date = DateFormat('dd/MM/yyyy');
  static final DateFormat _shortDateTime = DateFormat('dd/MM HH:mm');

  /// Data e ora complete (dd/MM/yyyy HH:mm) oppure "data non disponibile".
  static String dateTime(DateTime value) =>
      value.year < 2000 ? 'data non disponibile' : _dateTime.format(value);

  /// Solo la data (dd/MM/yyyy) oppure "data non disponibile".
  static String date(DateTime value) =>
      value.year < 2000 ? 'data non disponibile' : _date.format(value);

  /// Forma compatta per le card strette (kanban): dd/MM HH:mm.
  static String shortDateTime(DateTime value) =>
      value.year < 2000 ? 'data non disp.' : _shortDateTime.format(value);
}
