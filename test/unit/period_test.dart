import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kwf_energiemonitor/daily/period.dart';

void main() {
  setUpAll(() => initializeDateFormatting('de'));
  final today = DateTime(2026, 11, 21, 14, 30); // Samstag

  test('Woche: Montag bis Sonntag, bis heute', () {
    final p = Period.of(RangeKind.week, today, today: today);
    expect(p.start, DateTime(2026, 11, 16));
    expect(p.end, DateTime(2026, 11, 22));
    expect(p.until, DateTime(2026, 11, 21));
    expect(p.dayCount, 6);
    expect(p.isCurrent, isTrue);
    expect(p.hasNext, isFalse);
    expect(p.label, 'KW 47 · 16.11. bis 22.11.2026');
    final prev = p.previous();
    expect(prev.start, DateTime(2026, 11, 9));
    expect(prev.dayCount, 7);
    expect(prev.hasNext, isTrue);
    expect(prev.next(), p);
  });

  test('Woche ueber die Zeitumstellung hat 7 Tage', () {
    final p = Period.of(RangeKind.week, DateTime(2026, 10, 25), today: today);
    expect(p.start, DateTime(2026, 10, 19));
    expect(p.days, hasLength(7));
    expect(p.days.last, DateTime(2026, 10, 25));
  });

  test('Monat', () {
    final p = Period.of(RangeKind.month, today, today: today);
    expect((p.start, p.end, p.dayCount), (DateTime(2026, 11), DateTime(2026, 11, 30), 21));
    expect(p.label, 'November 2026');
    expect(p.previous().start, DateTime(2026, 10));
    expect(p.previous().dayCount, 31);
    expect(Period.of(RangeKind.month, DateTime(2026, 2, 3), today: today).end,
        DateTime(2026, 2, 28));
  });

  test('Saison: Heizsaison Oktober bis Maerz, Sommer April bis September', () {
    final p = Period.of(RangeKind.season, today, today: today);
    expect((p.start, p.end), (DateTime(2026, 10), DateTime(2027, 3, 31)));
    expect(p.label, 'Heizsaison 2026/27');
    final summer = p.previous();
    expect((summer.start, summer.end), (DateTime(2026, 4), DateTime(2026, 9, 30)));
    expect(summer.label, 'Sommer 2026');
    expect(summer.previous().start, DateTime(2025, 10));
    final winter = Period.of(RangeKind.season, DateTime(2027, 2, 1), today: DateTime(2027, 2, 1));
    expect(winter.start, DateTime(2026, 10));
  });

  test('Jahr: 12 ganze Monate bis und mit dem laufenden', () {
    final p = Period.of(RangeKind.year, today, today: today);
    expect((p.start, p.end), (DateTime(2025, 12), DateTime(2026, 11, 30)));
    expect(p.label, 'Dez. 2025 bis Nov. 2026');
    expect(p.hasNext, isFalse);
    final prev = p.previous();
    expect((prev.start, prev.end), (DateTime(2024, 12), DateTime(2025, 11, 30)));
    expect(prev.next(), p);
  });

  test('ISO-Woche am Jahreswechsel', () {
    expect(Period.of(RangeKind.week, DateTime(2027, 1, 1), today: DateTime(2027, 1, 3)).label,
        startsWith('KW 53'));
    expect(Period.of(RangeKind.week, DateTime(2026, 1, 1), today: today).label,
        startsWith('KW 1 '));
  });

  test('Letzte 7 Tage: heute rechts, auch am Montag sieben Tage', () {
    final monday = DateTime(2026, 11, 23, 8);
    final p = Period.lastDays(monday);
    expect((p.start, p.end, p.until), (DateTime(2026, 11, 17), DateTime(2026, 11, 23), DateTime(2026, 11, 23)));
    expect(p.days, hasLength(7));
    expect(p.isCurrent, isTrue);
    expect(p.label, '17.11. bis 23.11.2026');
    expect(Period.lastDays(DateTime(2026, 10, 27)).days.first, DateTime(2026, 10, 21));
  });
}
