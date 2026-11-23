// Zeitraeume der Auswertung: Woche, Monat, Saison bis jetzt, Jahr
// (Konzept 01_navigation_ux.md, 5.2). Tage sind Kalendertage in Lokalzeit,
// gebaut mit DateTime(j, m, t), damit die Zeitumstellung nichts verschiebt.
import 'package:intl/intl.dart';

enum RangeKind {
  week('Woche'),
  month('Monat'),
  season('Saison'),
  year('Jahr');

  const RangeKind(this.label);
  final String label;
}

DateTime dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

class Period {
  Period._(this.kind, this.start, this.end, DateTime today) : today = dayOf(today);

  final RangeKind kind;

  /// Erster Tag (inklusive).
  final DateTime start;

  /// Letzter Tag des ganzen Zeitraums (inklusive), kann in der Zukunft liegen.
  final DateTime end;
  final DateTime today;

  /// Zeitraum, der [anchor] enthaelt.
  factory Period.of(RangeKind kind, DateTime anchor, {required DateTime today}) {
    final a = dayOf(anchor);
    switch (kind) {
      case RangeKind.week:
        final s = DateTime(a.year, a.month, a.day - (a.weekday - 1));
        return Period._(kind, s, DateTime(s.year, s.month, s.day + 6), today);
      case RangeKind.month:
        return Period._(kind, DateTime(a.year, a.month), DateTime(a.year, a.month + 1, 0), today);
      case RangeKind.season:
        // TODO(prüfen): Grenzen der Saison mit der HSLU (wie Langzeittest April bis September).
        if (a.month >= 4 && a.month <= 9) {
          return Period._(kind, DateTime(a.year, 4), DateTime(a.year, 9, 30), today);
        }
        final y = a.month >= 10 ? a.year : a.year - 1;
        return Period._(kind, DateTime(y, 10), DateTime(y + 1, 3, 31), today);
      case RangeKind.year:
        // 12 ganze Monate bis und mit dem Monat von [anchor].
        return Period._(
            kind, DateTime(a.year, a.month - 11), DateTime(a.year, a.month + 1, 0), today);
    }
  }

  /// Letzter Tag mit moeglichen Daten: Ende, hoechstens heute.
  DateTime get until => end.isAfter(today) ? today : end;

  bool get isCurrent => !today.isBefore(start) && !today.isAfter(end);

  /// Anzahl Tage von [start] bis [until].
  int get dayCount => until.isBefore(start) ? 0 : _daysBetween(start, until) + 1;

  /// Alle Tage von [start] bis [until].
  List<DateTime> get days => [
        for (var i = 0; i < dayCount; i++) DateTime(start.year, start.month, start.day + i),
      ];

  bool contains(DateTime day) {
    final d = dayOf(day);
    return !d.isBefore(start) && !d.isAfter(until);
  }

  Period previous() => kind == RangeKind.year
      ? Period.of(kind, DateTime(start.year, start.month - 1), today: today)
      : Period.of(kind, DateTime(start.year, start.month, start.day - 1), today: today);

  Period next() => kind == RangeKind.year
      ? Period.of(kind, DateTime(end.year, end.month + 12), today: today)
      : Period.of(kind, DateTime(end.year, end.month, end.day + 1), today: today);

  /// Der naechste Zeitraum laege nicht ganz in der Zukunft.
  bool get hasNext => !next().start.isAfter(today);

  /// Beschriftung im Umschalter.
  String get label {
    final dm = DateFormat('d.M.');
    final dmy = DateFormat('d.M.yyyy');
    switch (kind) {
      case RangeKind.week:
        final kw = _isoWeek(start);
        return 'KW $kw · ${dm.format(start)} bis ${dmy.format(end)}';
      case RangeKind.month:
        return DateFormat('MMMM yyyy', 'de').format(start);
      case RangeKind.season:
        return start.month == 4
            ? 'Sommer ${start.year}'
            : 'Heizsaison ${start.year}/${(start.year + 1) % 100}';
      case RangeKind.year:
        final my = DateFormat('MMM yyyy', 'de');
        return '${my.format(start)} bis ${my.format(end)}';
    }
  }

  /// "bis jetzt" fuer laufende Zeitraeume, sonst leer.
  String get untilText => isCurrent ? 'bis heute' : '';

  @override
  bool operator ==(Object other) =>
      other is Period && other.kind == kind && other.start == start && other.today == today;

  @override
  int get hashCode => Object.hash(kind, start, today);
}

int _daysBetween(DateTime a, DateTime b) =>
    DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

int _isoWeek(DateTime d) {
  final thursday = DateTime(d.year, d.month, d.day - (d.weekday - 1) + 3);
  final firstThursday = DateTime(thursday.year, 1, 4);
  final firstMonday =
      DateTime(firstThursday.year, 1, 4 - (firstThursday.weekday - 1));
  return _daysBetween(firstMonday, thursday) ~/ 7 + 1;
}
