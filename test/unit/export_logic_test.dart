import 'package:flutter_test/flutter_test.dart';
import 'package:kwf_energiemonitor/more/export_logic.dart';

void main() {
  test('letzter Monat, auch ueber den Jahreswechsel', () {
    expect(lastMonth(DateTime(2026, 11, 21)),
        DayRange(DateTime(2026, 10, 1), DateTime(2026, 10, 31)));
    expect(lastMonth(DateTime(2027, 1, 5)),
        DayRange(DateTime(2026, 12, 1), DateTime(2026, 12, 31)));
  });

  test('laufender Monat endet gestern', () {
    expect(calendarMonth(2026, 11, DateTime(2026, 11, 21)),
        DayRange(DateTime(2026, 11, 1), DateTime(2026, 11, 20)));
    expect(calendarMonth(2026, 2, DateTime(2026, 11, 21)),
        DayRange(DateTime(2026, 2, 1), DateTime(2026, 2, 28)));
  });

  test('sechs Monate ergeben sechs Dateien, keine laenger als 31 Tage', () {
    final parts = splitIntoMonths(DayRange(DateTime(2026, 4, 1), DateTime(2026, 9, 30)));
    expect(parts.length, 6);
    expect(parts.first, DayRange(DateTime(2026, 4, 1), DateTime(2026, 4, 30)));
    expect(parts.last, DayRange(DateTime(2026, 9, 1), DateTime(2026, 9, 30)));
    expect(parts.every((p) => p.days <= kMaxDaysPerRequest), isTrue);
  });

  test('angebrochene Monate am Anfang und Ende, lueckenlos', () {
    final parts = splitIntoMonths(DayRange(DateTime(2026, 3, 15), DateTime(2026, 5, 3)));
    expect(parts, [
      DayRange(DateTime(2026, 3, 15), DateTime(2026, 3, 31)),
      DayRange(DateTime(2026, 4, 1), DateTime(2026, 4, 30)),
      DayRange(DateTime(2026, 5, 1), DateTime(2026, 5, 3)),
    ]);
    expect(parts.first.days, 17);
  });

  test('ein Tag ergibt eine Datei', () {
    expect(splitIntoMonths(DayRange(DateTime(2026, 6, 1), DateTime(2026, 6, 1))).length, 1);
  });
}
