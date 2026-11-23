// Mess-Schema: Zustand pro Messpunkt und Pruefung von Heizwaerme,
// Warmwasser und Wohnklima.
import 'package:flutter_test/flutter_test.dart';
import 'package:kwf_energiemonitor/app/routes.dart';
import 'package:kwf_energiemonitor/energy.dart';
import 'package:kwf_energiemonitor/status/measurement_schema.dart';

import '../support/test_app.dart';

const kClimateFields = ['temperature_indoor', 'temperature_outdoor', 'humidity_indoor', 'co2_indoor'];

DateTime ago(Duration d) => kNow.subtract(d);

void main() {
  test('Beispielhaus: Heizung ueber I2, Warmwasser ueber Eintraege M1, Klima fehlt', () {
    final s = evaluateSchema(points: samplePoints(), entries: sampleEntries(), now: kNow);
    final heat = s.checks.firstWhere((c) => c.id == 'heat');
    expect(heat.state, ReqState.met);
    expect(heat.sources, containsAll(['I2', 'M2']));
    final hotWater = s.checks.firstWhere((c) => c.id == 'hotWater');
    expect(hotWater.state, ReqState.met);
    expect(hotWater.sources, ['M1']);
    final climate = s.checks.firstWhere((c) => c.id == 'climate');
    expect(climate.state, ReqState.missing);
    expect(climate.warning, contains('Innentemperatur (K1)'));
    expect(s.point('E1')!.coverage, PointCoverage.online);
    expect(s.point('E2')!.coverage, PointCoverage.missing);
    expect(s.point('M1')!.coverage, PointCoverage.entries);
    expect(s.point('M1')!.lastSeen, DateTime(2026, 7, 19));
  });

  test('Klima ueber K0-Felder; fehlt nur ein Feld, nennt die Warnung nur dieses', () {
    final s = evaluateSchema(points: [
      point('K0', ago(const Duration(minutes: 20)),
          fields: ['temperature_indoor', 'humidity_indoor', 'co2_indoor']),
    ], entries: const [], now: kNow);
    final climate = s.checks.firstWhere((c) => c.id == 'climate');
    expect(climate.state, ReqState.partial);
    expect(climate.warning, 'Wohnklima unvollständig: Es fehlt Aussentemperatur (K2).');
    expect(s.point('K1')!.viaK0, isTrue);
    expect(s.point('K1')!.coverage, PointCoverage.online);
    expect(s.point('K2')!.coverage, PointCoverage.missing);
  });

  test('alle Anforderungen erfuellt: keine Warnung', () {
    final s = evaluateSchema(points: [
      point('I1', ago(const Duration(minutes: 10))),
      point('I2', ago(const Duration(hours: 3))),
      point('K0', ago(const Duration(minutes: 20)), fields: kClimateFields),
    ], entries: const [], now: kNow);
    expect(s.warnings, isEmpty);
    expect(s.point('I2')!.coverage, PointCoverage.delayed);
  });

  test('eigener Messpunkt K1 zaehlt auch ohne K0', () {
    final s = evaluateSchema(points: [point('K1', ago(const Duration(minutes: 5)))],
        entries: const [], now: kNow);
    expect(s.point('K1')!.coverage, PointCoverage.online);
    expect(s.point('K1')!.viaK0, isFalse);
  });

  test('I2 seit ueber 30 Tagen ohne Daten zaehlt nicht, mit eigenem Hinweis', () {
    final s = evaluateSchema(points: [point('I2', DateTime(2026, 9, 1))],
        entries: const [], now: kNow);
    expect(s.point('I2')!.coverage, PointCoverage.stale);
    final heat = s.checks.firstWhere((c) => c.id == 'heat');
    expect(heat.state, ReqState.missing);
    expect(heat.warning, contains('seit dem 1.9.2026 keine Daten'));
  });

  test('nur gemischte Eintraege (M0): teilweise, M0 erscheint im Schema', () {
    final s = evaluateSchema(points: const [], entries: [
      entry(EnergyType.propane, 'M0', DateTime(2026, 10, 1), 11, 1, 'Flasche'),
    ], now: kNow);
    expect(s.checks.firstWhere((c) => c.id == 'heat').state, ReqState.partial);
    expect(s.checks.firstWhere((c) => c.id == 'hotWater').state, ReqState.partial);
    expect(s.point('M0')!.coverage, PointCoverage.entries);
    final ids = s.inGroup(SchemaGroup.boundary).map((p) => p.id).toList();
    expect(ids.indexOf('M0'), ids.indexOf('M2') + 1);
  });

  test('ohne Eintraege kein M0; unbekannte Messpunkte unter Weitere', () {
    final s = evaluateSchema(points: [point('X9', ago(const Duration(minutes: 5)))],
        entries: const [], now: kNow);
    expect(s.point('M0'), isNull);
    expect(s.inGroup(SchemaGroup.other).single.id, 'X9');
  });

  test('manueller Messpunkt ohne geladene Eintraege: last_seen des Dokuments', () {
    final s = evaluateSchema(points: [point('M2', DateTime(2025, 12, 1))],
        entries: const [], now: kNow);
    expect(s.point('M2')!.coverage, PointCoverage.entries);
    expect(s.point('M2')!.lastSeen, DateTime(2025, 12, 1));
  });

  test('Mess-Schema bleibt im Studienmodus sichtbar', () {
    expect(Routes.isHiddenInStudy(Routes.measurementSchema), isFalse);
  });
}
