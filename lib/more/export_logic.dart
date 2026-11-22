// Zeitraeume fuer den Download. Die API liefert hoechstens 31 Tage pro
// Anfrage (GET /export). Laengere Zeitraeume teilt die App in Monatsstuecke.
import '../util/dates.dart';

/// Basis-URL der API. Wer selbst hostet (Variante B), aendert sie hier.
const kApiBaseUrl = 'https://energiemonitor-api-325255315766.europe-west6.run.app';

/// Hoechstens so viele Tage pro Anfrage (wie die API).
const kMaxDaysPerRequest = 31;

/// Ein Zeitraum aus ganzen Kalendertagen, beide Enden eingeschlossen.
class DayRange {
  DayRange(DateTime start, DateTime end)
      : start = DateTime(start.year, start.month, start.day),
        end = DateTime(end.year, end.month, end.day);

  final DateTime start;
  final DateTime end;

  int get days => daysBetween(start, end) + 1;

  @override
  bool operator ==(Object other) =>
      other is DayRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'DayRange($start – $end)';
}

/// Letzter abgeschlossener Kalendermonat.
DayRange lastMonth(DateTime now) {
  // Tag 0 = letzter Tag des Vormonats, ohne 24-h-Rechnung (Zeitumstellung).
  final lastPrev = DateTime(now.year, now.month, 0);
  return DayRange(DateTime(lastPrev.year, lastPrev.month, 1), lastPrev);
}

/// Ein ganzer Kalendermonat; der laufende Monat endet gestern.
DayRange calendarMonth(int year, int month, DateTime now) {
  final first = DateTime(year, month, 1);
  var last = DateTime(year, month + 1, 0);
  final yesterday = DateTime(now.year, now.month, now.day - 1);
  if (last.isAfter(yesterday)) last = yesterday;
  return DayRange(first, last);
}

/// Teilt einen Zeitraum an den Monatsgrenzen. Jedes Stueck hat hoechstens
/// 31 Tage und passt damit in eine Anfrage.
List<DayRange> splitIntoMonths(DayRange range) {
  if (range.end.isBefore(range.start)) return const [];
  final out = <DayRange>[];
  var cursor = range.start;
  while (!cursor.isAfter(range.end)) {
    final monthEnd = DateTime(cursor.year, cursor.month + 1, 0);
    final end = monthEnd.isAfter(range.end) ? range.end : monthEnd;
    out.add(DayRange(cursor, end));
    cursor = DateTime(end.year, end.month, end.day + 1);
  }
  assert(out.every((r) => r.days <= kMaxDaysPerRequest));
  return out;
}
