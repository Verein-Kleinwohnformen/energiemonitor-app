// Logik der Seite Erfassen, ohne Widgets und ohne Firestore.
//
// Alles hier stammt nur aus den eigenen Eintraegen und zeigt keinen
// gemessenen Verbrauch. Darum ist es auch im Studienmodus sichtbar.
import 'package:intl/intl.dart';

import '../app/services.dart';
import '../util/dates.dart';
import '../energy.dart';
import 'energy_kinds.dart';

// ---------------------------------------------------------------------------
// Vorrat
// ---------------------------------------------------------------------------

/// Vorrat eines Energietraegers an einem Messpunkt, nach dem letzten Eintrag.
class Stock {
  const Stock({required this.latest, this.previous});

  final ManualEntry latest;
  final ManualEntry? previous;

  Energy get energy => latest.energy;
  EnergyKind get kind => EnergyKind.of(energy.type);
  String get meteringPoint => energy.meteringPoint;

  /// Vorrat = neu dazu + Rest des letzten Eintrags.
  double get amount => energy.purchaseQuantity + energy.leftoverQuantity;
  String get unit => energy.displayUnit;
  DateTime get date => energy.purchaseDate;
}

/// Gruppiert nach gespeichertem Typ und Messpunkt (wie die Suche nach dem
/// Vorgaenger in energy.dart). Neueste zuerst.
List<Stock> stocksOf(List<ManualEntry> entries) {
  final groups = <String, List<ManualEntry>>{};
  for (final e in entries) {
    final key = '${energyTypeToString(e.energy.type)}|${e.energy.meteringPoint}';
    groups.putIfAbsent(key, () => []).add(e);
  }
  final stocks = groups.values.map((list) {
    list.sort((a, b) => b.energy.purchaseDate.compareTo(a.energy.purchaseDate));
    return Stock(latest: list.first, previous: list.length > 1 ? list[1] : null);
  }).toList()
    ..sort((a, b) => b.date.compareTo(a.date));
  return stocks;
}

/// Hat dieser Eintrag einen Vorgaenger (gleicher Typ, gleicher Messpunkt,
/// frueheres Kaufdatum)? Ohne Vorgaenger ist "verbraucht" nicht bekannt.
bool hasPredecessor(ManualEntry entry, List<ManualEntry> all) => all.any((o) =>
    o.energy.type == entry.energy.type &&
    o.energy.meteringPoint == entry.energy.meteringPoint &&
    o.energy.purchaseDate.isBefore(entry.energy.purchaseDate));

// ---------------------------------------------------------------------------
// Erinnerung
// ---------------------------------------------------------------------------

const kReminderMinDays = 60;

class Reminder {
  const Reminder(this.stock, this.daysSince);
  final Stock stock;
  final int daysSince;

  String get text {
    final name = stock.kind.label;
    if (stock.kind == EnergyKind.propane) {
      return '$name: Der letzte Eintrag ist $daysSince Tage her. Wägst du die alte '
          'Flasche beim Wechsel, lässt sich der Verbrauch genau rechnen.';
    }
    return '$name: Der letzte Eintrag ist $daysSince Tage her. Hast du nachgefüllt? '
        'Trag es mit dem Rest ein.';
  }
}

/// Erinnerung, wenn der letzte Eintrag laenger her ist als der bisherige
/// Abstand zwischen zwei Eintraegen, mindestens aber 60 Tage. Hoechstens zwei,
/// die aeltesten zuerst.
List<Reminder> remindersFor(List<Stock> stocks, DateTime now) {
    final out = <Reminder>[];
  for (final s in stocks) {
    final since = daysBetween(s.date, now);
    var limit = kReminderMinDays;
    if (s.previous != null) {
      final gap = daysBetween(s.previous!.energy.purchaseDate, s.date);
      if (gap > limit) limit = gap;
    }
    if (since > limit) out.add(Reminder(s, since));
  }
  out.sort((a, b) => b.daysSince.compareTo(a.daysSince));
  return out.take(2).toList();
}


// ---------------------------------------------------------------------------
// Vorschlag "aufgebraucht etwa"
// ---------------------------------------------------------------------------

/// Bisheriger Verbrauch pro Tag aus den letzten zwei Eintraegen gleichen
/// Typs und Messpunkts: verbraucht (beim letzten Eintrag gespeichert) geteilt
/// durch die Tage dazwischen. null, wenn das nicht geht.
double? dailyUsage(Stock? stock) {
  if (stock == null || stock.previous == null) return null;
  final consumed = stock.latest.storedConsumed;
  final days = daysBetween(stock.previous!.energy.purchaseDate, stock.date);
  if (consumed == null || consumed <= 0 || days <= 0) return null;
  return consumed / days;
}

/// Wann die neue Menge bei bisherigem Verbrauch aufgebraucht waere.
DateTime? suggestUsageDate({
  required double? perDay,
  required DateTime purchase,
  required double? added,
  required double? leftover,
}) {
  if (perDay == null || perDay <= 0 || added == null || leftover == null) return null;
  final stock = added + leftover;
  if (stock <= 0) return null;
  final days = (stock / perDay).round();
  // Kalendertage addieren, nicht 24-h-Schritte (Zeitumstellung).
  final d = DateTime(purchase.year, purchase.month, purchase.day + days);
  if (d.year > 2100) return null;
  return d;
}

// ---------------------------------------------------------------------------
// Eingaben pruefen und in einen Eintrag uebersetzen
// ---------------------------------------------------------------------------

/// Liest eine Menge. Komma und Punkt sind erlaubt ("11,5" = "11.5"),
/// Leerzeichen am Rand werden ignoriert.
double? parseQuantity(String? text) {
  if (text == null) return null;
  final t = text.trim().replaceAll(',', '.');
  if (t.isEmpty) return null;
  return double.tryParse(t);
}

/// Pruefung einer Menge. Meldungen wie im alten Formular, dazu neu:
/// keine negativen Mengen (Entscheid 21.11.2026).
String? validateQuantity(String? text) {
  if (text == null || text.trim().isEmpty) return 'Bitte eine Zahl eingeben';
  final v = parseQuantity(text);
  if (v == null || v.isNaN || v.isInfinite) return 'Bitte eine gültige Zahl eingeben';
  if (v < 0) return 'Bitte eine Zahl ab 0 eingeben';
  return null;
}

String? validateDescription(String? text) =>
    (text == null || text.trim().isEmpty) ? 'Bitte eine Beschreibung eingeben' : null;

String? validatePurchaseDate(DateTime? d) => d == null ? 'Bitte ein Datum auswählen' : null;

String? validateUsageDate(DateTime? usage, DateTime? purchase) {
  if (usage == null) return 'Bitte ein Datum auswählen';
  if (purchase != null && usage.isBefore(purchase)) {
    return 'Verbrauchsdatum muss nach dem Kaufdatum liegen';
  }
  return null;
}

/// Werte des Formulars. Baut daraus denselben Eintrag wie das alte Formular
/// in `_addToDatabase`.
class FormValues {
  const FormValues({
    required this.kind,
    required this.unit,
    required this.meteringPoint,
    required this.description,
    required this.added,
    required this.leftover,
    required this.purchase,
    required this.usage,
  });

  final EnergyKind kind;
  final String? unit;
  final String meteringPoint;

  /// Unveraendert gespeichert, wie im alten Formular (ohne Trimmen).
  final String description;
  final double added;
  final double leftover;
  final DateTime purchase;
  final DateTime usage;

  Energy toEnergy({required String? userId, required String? monitorId}) => Energy(
        firebaseId: '',
        typeCounter: 0,
        description: description,
        purchaseDate: purchase,
        usageDate: usage,
        type: kind.typeFor(unit),
        purchaseQuantity: added,
        leftoverQuantity: leftover,
        meteringPoint: meteringPoint,
        usageDateProvisory: true,
        userId: userId ?? 'unauthenticated',
        monitorId: monitorId,
      );
}

/// Vorbelegung aus dem letzten Eintrag gleichen Traegers: Messpunkt,
/// Einheit, Beschreibung. Sichtbar und aenderbar.
class Prefill {
  const Prefill({this.meteringPoint, this.unit, this.description});
  final String? meteringPoint;
  final String? unit;
  final String? description;
}

Prefill prefillFor(EnergyKind kind, List<ManualEntry> entries, {String? meteringPoint}) {
  ManualEntry? last;
  for (final e in entries) {
    if (EnergyKind.of(e.energy.type) != kind) continue;
    if (meteringPoint != null && e.energy.meteringPoint != meteringPoint) continue;
    if (last == null || e.energy.purchaseDate.isAfter(last.energy.purchaseDate)) last = e;
  }
  if (last == null) return Prefill(meteringPoint: meteringPoint);
  return Prefill(
    meteringPoint: last.energy.meteringPoint,
    unit: EnergyKind.unitOf(last.energy.type),
    description: last.energy.description,
  );
}

// ---------------------------------------------------------------------------
// Abgleich: Vorrat nachfuehren ohne Kauf ("Nullkauf")
// ---------------------------------------------------------------------------

/// Beschreibung, mit der das Formular einen Abgleich vorbelegt.
const kReconcileDescription = 'Abgleich';

/// Vorbelegung fuer einen Abgleich. Fachlich ein normaler Eintrag mit
/// "Neu dazu" 0 und dem aktuellen Rest; alles sichtbar und aenderbar.
/// "Noch uebrig" bleibt leer: sonst wuerde unbemerkt Verbrauch 0 gespeichert.
class ReconcilePrefill {
  const ReconcilePrefill({
    required this.kind,
    required this.unit,
    required this.meteringPoint,
    required this.lastAmount,
    required this.lastDate,
  });
  final EnergyKind kind;

  /// Einheit des Vorrats ('Kg', 'Ster', 'Liter'), nicht die des letzten
  /// Eintrags des Traegers: Holz kann in kg und in Ster nebeneinander liegen.
  final String unit;
  final String meteringPoint;
  final double lastAmount;
  final DateTime lastDate;
  String get added => '0';
  String get description => kReconcileDescription;
}

ReconcilePrefill reconcilePrefillFor(Stock stock) => ReconcilePrefill(
      kind: stock.kind,
      unit: EnergyKind.unitOf(stock.energy.type),
      meteringPoint: stock.meteringPoint,
      lastAmount: stock.amount,
      lastDate: stock.date,
    );

/// Hinweis, wenn das Datum des Abgleichs nicht nach dem letzten Eintrag
/// liegt. Den Vorgaenger sucht energy.dart nur mit einem frueheren Datum;
/// am selben Tag bliebe der Verbrauch 0. Blockiert das Speichern nicht.
String? reconcileDateWarning(Stock stock, DateTime? purchase) {
  if (purchase == null || purchase.isAfter(stock.date)) return null;
  return 'Dein letzter Eintrag ist vom ${_dmy.format(stock.date)}. Ein Abgleich am selben '
      'Tag oder davor zählt nicht als neuer Stand, der Verbrauch bliebe 0. Wähl ein '
      'späteres Datum oder lösch den letzten Eintrag und trag ihn mit dem richtigen Rest neu ein.';
}

/// Vorschlag "aufgebraucht etwa" beim Abgleich: wie sonst aus dem bisherigen
/// Verbrauch. Ist der Vorrat leer (neu dazu 0, Rest 0), ist er am Tag des
/// Abgleichs aufgebraucht.
DateTime? suggestReconcileUsageDate({
  required double? perDay,
  required DateTime purchase,
  required double? added,
  required double? leftover,
}) {
  final s = suggestUsageDate(perDay: perDay, purchase: purchase, added: added, leftover: leftover);
  if (s != null) return s;
  if (added == 0 && leftover == 0) return purchase;
  return null;
}

final _dmy = DateFormat('d.M.yyyy');

/// Zahl fuer die Anzeige: 12 statt 12.0, sonst wie eingegeben mit Punkt.
String formatQuantity(double v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  final s = v.toStringAsFixed(2);
  return s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
}
