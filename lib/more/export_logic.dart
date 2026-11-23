// Zeitraeume fuer den Download. Die API liefert hoechstens 31 Tage pro
// Anfrage (GET /export), und Cloud Run gibt hoechstens 32 MB pro Antwort
// zurueck. Ein ganzer Monat ist mit allen Sensoren schon groesser (rund 1 MB
// pro Tag), darum teilt die App in Monatshaelften (1. bis 15., 16. bis Ende).
import '../util/dates.dart';

/// Basis-URL der API. Wer selbst hostet (Variante B), aendert sie hier.
const kApiBaseUrl = 'https://energiemonitor-api-325255315766.europe-west6.run.app';

/// Hoechstens so viele Tage pro Anfrage (wie die API).
const kMaxDaysPerRequest = 31;

/// Hoechstens so viele Tage pro Datei (zweite Monatshaelfte, 16. bis 31.).
const kMaxDaysPerFile = 16;

/// Erster Tag der zweiten Monatshaelfte.
const _secondHalfStartDay = 16;

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

/// Teilt einen Zeitraum an Monatsgrenzen und in der Monatsmitte (nach dem
/// 15.). Jedes Stueck hat hoechstens 16 Tage und bleibt unter dem
/// Antwortlimit von Cloud Run.
List<DayRange> splitForDownload(DayRange range) {
  if (range.end.isBefore(range.start)) return const [];
  final out = <DayRange>[];
  var cursor = range.start;
  while (!cursor.isAfter(range.end)) {
    final pieceEnd = cursor.day < _secondHalfStartDay
        ? DateTime(cursor.year, cursor.month, _secondHalfStartDay - 1)
        : DateTime(cursor.year, cursor.month + 1, 0);
    final end = pieceEnd.isAfter(range.end) ? range.end : pieceEnd;
    out.add(DayRange(cursor, end));
    cursor = DateTime(end.year, end.month, end.day + 1);
  }
  assert(out.every((r) => r.days <= kMaxDaysPerFile));
  return out;
}
