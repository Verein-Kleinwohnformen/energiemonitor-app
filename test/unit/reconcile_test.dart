// Abgleich ("Nullkauf"): Vorbelegung, Hinweis bei gleichem Tag, Vorschlag
// "aufgebraucht etwa" und Bestaetigung.
import 'package:flutter_test/flutter_test.dart';
import 'package:kwf_energiemonitor/app/services.dart';
import 'package:kwf_energiemonitor/capture/capture_logic.dart';
import 'package:kwf_energiemonitor/capture/energy_form_page.dart';
import 'package:kwf_energiemonitor/capture/energy_kinds.dart';
import 'package:kwf_energiemonitor/energy.dart';

import '../support/test_app.dart';

Stock stockOf(List<ManualEntry> entries, EnergyType type, String mp) =>
    stocksOf(entries).firstWhere((s) => s.energy.type == type && s.meteringPoint == mp);

void main() {
  test('Vorbelegung: neu dazu 0, Beschreibung Abgleich, Traeger und Messpunkt vom Vorrat', () {
    final s = stockOf(sampleEntries(), EnergyType.propane, 'M1');
    final r = reconcilePrefillFor(s);
    expect(r.added, '0');
    expect(r.description, 'Abgleich');
    expect(r.kind, EnergyKind.propane);
    expect(r.meteringPoint, 'M1');
    expect(r.unit, 'Kg');
    expect(r.lastAmount, 23.5);
  });

  test('Holz in Ster: Einheit vom Vorrat, auch wenn es Holz in kg gibt', () {
    final entries = [
      entry(EnergyType.woodSter, 'M2', DateTime(2026, 9, 1), 2, 0.5, 'Ster'),
      entry(EnergyType.woodKg, 'M2', DateTime(2026, 10, 1), 100, 10, 'kg'),
    ];
    final r = reconcilePrefillFor(stockOf(entries, EnergyType.woodSter, 'M2'));
    expect(r.unit, 'Ster');
    expect(r.kind.typeFor(r.unit), EnergyType.woodSter);
  });

  test('Hinweis, wenn der Abgleich nicht nach dem letzten Eintrag liegt', () {
    final s = stockOf(sampleEntries(), EnergyType.pellets, 'M2'); // letzter 1.10.2026
    expect(reconcileDateWarning(s, DateTime(2026, 10, 1)), contains('1.10.2026'));
    expect(reconcileDateWarning(s, DateTime(2026, 9, 30)), isNotNull);
    expect(reconcileDateWarning(s, DateTime(2026, 10, 2)), isNull);
    expect(reconcileDateWarning(s, null), isNull);
  });

  test('Vorschlag aufgebraucht etwa: aus dem Verbrauch, bei leerem Vorrat der Tag selbst', () {
    final purchase = DateTime(2026, 11, 21);
    expect(
        suggestReconcileUsageDate(perDay: 0.5, purchase: purchase, added: 0, leftover: 5),
        DateTime(2026, 12, 1));
    expect(suggestReconcileUsageDate(perDay: null, purchase: purchase, added: 0, leftover: 0),
        purchase);
    expect(suggestReconcileUsageDate(perDay: null, purchase: purchase, added: 0, leftover: 3),
        isNull);
  });

  test('FormStart.reconcile traegt den Vorrat, ein leerer Start nicht', () {
    final s = stockOf(sampleEntries(), EnergyType.propane, 'M1');
    final start = FormStart.reconcile(entries: sampleEntries(), stock: s);
    expect(start.isReconcile, isTrue);
    expect(start.kind, EnergyKind.propane);
    expect(start.meteringPoint, 'M1');
    expect(const FormStart().isReconcile, isFalse);
  });

  test('Bestaetigung nach dem Abgleich', () {
    final previous = entry(EnergyType.propane, 'M1', DateTime(2026, 7, 19), 11.5, 0.5, 'Flasche');
    final saved = entry(EnergyType.propane, 'M1', DateTime(2026, 11, 21), 0, 4.5, 'Abgleich',
        consumed: 7.5);
    final values = FormValues(
      kind: EnergyKind.propane,
      unit: 'Kg',
      meteringPoint: 'M1',
      description: 'Abgleich',
      added: 0,
      leftover: 4.5,
      purchase: DateTime(2026, 11, 21),
      usage: DateTime(2026, 12, 20),
    );
    final text = FormResult(values, reconcile: true).summary([saved, previous]);
    expect(text, 'Abgleich Propangas: noch 4.5 kg. Seit dem letzten Eintrag verbraucht: 7.5 kg.');
    expect(FormResult(values).summary([saved, previous]), startsWith('Propangas, 0 kg, Rest 4.5 kg.'));
  });
}
