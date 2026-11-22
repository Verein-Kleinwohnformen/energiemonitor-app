import 'package:flutter_test/flutter_test.dart';
import 'package:kwf_energiemonitor/capture/capture_logic.dart';
import 'package:kwf_energiemonitor/capture/energy_kinds.dart';
import 'package:kwf_energiemonitor/energy.dart';

import '../support/test_app.dart';

void main() {
  group('Mengen', () {
    test('Komma und Punkt ergeben dieselbe Zahl', () {
      expect(parseQuantity('11,5'), 11.5);
      expect(parseQuantity('11.5'), 11.5);
      expect(parseQuantity(' 2,25 '), 2.25);
      expect(parseQuantity(''), isNull);
      expect(parseQuantity('elf'), isNull);
    });

    test('Meldungen wie im alten Formular, dazu keine negativen Mengen', () {
      expect(validateQuantity(''), 'Bitte eine Zahl eingeben');
      expect(validateQuantity('   '), 'Bitte eine Zahl eingeben');
      expect(validateQuantity('elf'), 'Bitte eine gültige Zahl eingeben');
      expect(validateQuantity('NaN'), 'Bitte eine gültige Zahl eingeben');
      expect(validateQuantity('-1'), 'Bitte eine Zahl ab 0 eingeben');
      expect(validateQuantity('0'), isNull);
      expect(validateQuantity('11,5'), isNull);
    });

    test('Beschreibung und Daten wie im alten Formular', () {
      expect(validateDescription('  '), 'Bitte eine Beschreibung eingeben');
      expect(validateDescription('x'), isNull);
      expect(validatePurchaseDate(null), 'Bitte ein Datum auswählen');
      expect(validateUsageDate(null, DateTime(2026)), 'Bitte ein Datum auswählen');
      expect(validateUsageDate(DateTime(2026, 1, 1), DateTime(2026, 1, 2)),
          'Verbrauchsdatum muss nach dem Kaufdatum liegen');
      expect(validateUsageDate(DateTime(2026, 1, 2), DateTime(2026, 1, 2)), isNull);
    });
  });

  group('Eintrag wie im alten Formular', () {
    FormValues values(EnergyKind kind, String? unit) => FormValues(
          kind: kind,
          unit: unit,
          meteringPoint: 'M2',
          description: ' mit Leerzeichen ',
          added: 1,
          leftover: 0.5,
          purchase: DateTime(2026, 2, 1),
          usage: DateTime(2026, 3, 1),
        );

    test('Holz in Ster wird woodSter, sonst woodKg', () {
      expect(values(EnergyKind.wood, 'Ster').toEnergy(userId: 'u', monitorId: 'm').type,
          EnergyType.woodSter);
      expect(values(EnergyKind.wood, 'Kg').toEnergy(userId: 'u', monitorId: 'm').type,
          EnergyType.woodKg);
      expect(values(EnergyKind.wood, null).toEnergy(userId: 'u', monitorId: 'm').type,
          EnergyType.woodKg);
    });

    test('alle Felder wie _addToDatabase im alten Formular', () {
      final e = values(EnergyKind.propane, 'Kg').toEnergy(userId: null, monitorId: 'm');
      expect(e.firebaseId, '');
      expect(e.typeCounter, 0);
      expect(e.description, ' mit Leerzeichen ', reason: 'altes Formular trimmt nicht');
      expect(e.usageDateProvisory, isTrue);
      expect(e.userId, 'unauthenticated');
      expect(e.monitorId, 'm');
      expect(e.type, EnergyType.propane);
      expect(e.displayUnit, 'kg');
    });

    test('jeder Traeger hat dieselben Einheiten wie im alten Formular', () {
      expect(EnergyKind.wood.units, ['Kg', 'Ster']);
      expect(EnergyKind.pellets.units, ['Kg']);
      expect(EnergyKind.propane.units, ['Kg']);
      for (final k in [EnergyKind.oil, EnergyKind.diesel, EnergyKind.gasoline]) {
        expect(k.units, ['Liter']);
      }
      expect(kMeteringChoices.map((c) => c.code), ['M1', 'M2', 'M0']);
    });
  });

  group('Vorrat', () {
    test('pro Typ und Messpunkt, neueste zuerst, Vorrat = neu + Rest', () {
      final stocks = stocksOf(sampleEntries());
      expect(stocks.length, 2);
      expect(stocks.first.kind, EnergyKind.pellets);
      expect(stocks.first.amount, 35);
      expect(stocks.first.previous, isNotNull);
      expect(stocks[1].kind, EnergyKind.propane);
      expect(stocks[1].amount, 23.5);
    });

    test('Holz in kg und in Ster sind getrennte Vorraete', () {
      final stocks = stocksOf([
        entry(EnergyType.woodKg, 'M2', DateTime(2026, 1, 1), 100, 0, 'a'),
        entry(EnergyType.woodSter, 'M2', DateTime(2026, 2, 1), 1, 0, 'b'),
      ]);
      expect(stocks.length, 2);
    });

    test('verbraucht nur mit Vorgaenger', () {
      final all = sampleEntries();
      expect(hasPredecessor(all[0], all), isTrue);
      expect(hasPredecessor(all[1], all), isFalse);
      expect(hasPredecessor(all[2], all), isFalse);
    });
  });

  group('Erinnerung', () {
    test('Propangas nach 125 Tagen, mit Hinweis zum Waegen', () {
      final r = remindersFor(stocksOf(sampleEntries()), kNow);
      expect(r.length, 1);
      expect(r.single.daysSince, 125);
      expect(r.single.text, startsWith('Propangas: Der letzte Eintrag ist 125 Tage her.'));
    });

    test('nicht vor 60 Tagen', () {
      final r = remindersFor(
          stocksOf([
            entry(EnergyType.pellets, 'M2', kNow.subtract(const Duration(days: 59)), 1, 0, 'x')
          ]),
          kNow);
      expect(r, isEmpty);
    });

    test('nicht vor dem bisherigen Abstand', () {
      final r = remindersFor(
          stocksOf([
            entry(EnergyType.pellets, 'M2', DateTime(2026, 7, 1), 1, 0, 'x'),
            entry(EnergyType.pellets, 'M2', DateTime(2026, 1, 1), 1, 0, 'x'),
          ]),
          kNow);
      // Abstand 181 Tage, seit dem letzten 143 Tage: noch keine Erinnerung.
      expect(r, isEmpty);
    });
  });

  group('Vorschlag aufgebraucht etwa', () {
    test('aus dem bisherigen Verbrauch pro Tag', () {
      final stock = stocksOf(sampleEntries()).first; // 12 kg in 205 Tagen (10.3. bis 1.10., ueber die Zeitumstellung)
      final perDay = dailyUsage(stock)!;
      expect(perDay, closeTo(12 / 205, 1e-9));
      final d = suggestUsageDate(
          perDay: perDay, purchase: DateTime(2026, 11, 21), added: 15, leftover: 3);
      expect(d, DateTime(2026, 11, 21 + (18 / perDay).round()));
    });

    test('ohne zwei Eintraege kein Vorschlag', () {
      final stock = stocksOf(sampleEntries())[1];
      expect(dailyUsage(stock), isNull);
      expect(suggestUsageDate(perDay: null, purchase: kNow, added: 1, leftover: 1), isNull);
    });
  });

  test('Vorbelegung aus dem letzten Eintrag gleichen Traegers', () {
    final p = prefillFor(EnergyKind.pellets, sampleEntries());
    expect(p.meteringPoint, 'M2');
    expect(p.unit, 'Kg');
    expect(p.description, 'Pellets Landi, 2 Säcke');
    final none = prefillFor(EnergyKind.oil, sampleEntries());
    expect(none.meteringPoint, isNull);
    expect(none.description, isNull);
  });

  test('Zahlen ohne unnoetige Nachkommastellen', () {
    expect(formatQuantity(12), '12');
    expect(formatQuantity(11.5), '11.5');
    expect(formatQuantity(0.75), '0.75');
  });
}
