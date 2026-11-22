import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kwf_energiemonitor/app/version.dart';
import 'package:kwf_energiemonitor/household/household.dart';
import 'package:kwf_energiemonitor/info/info_texts.dart';

void main() {
  test('jedes Info-Overlay hat alle Teile', () {
    for (final t in InfoTexts.all) {
      expect(t.title.trim(), isNotEmpty);
      expect(t.what.trim(), isNotEmpty, reason: t.title);
      expect(t.source.trim(), isNotEmpty, reason: t.title);
      expect(t.method.trim(), isNotEmpty, reason: t.title);
      expect(t.certainty.trim(), isNotEmpty, reason: t.title);
    }
  });

  test('Platzhalter werden ersetzt', () {
    final t = InfoTexts.measurements
        .fill({'sensor': 'Netatmo', 'mp': 'K0', 'feld': 'co2_indoor'});
    expect(t.placeholders, isEmpty);
    expect(t.source, 'Netatmo, Messpunkt K0, Feld co2_indoor.');
  });

  test('Belegung sagt, dass sie berechnet ist', () {
    expect(InfoTexts.occupancy.note, contains('nicht gemessen'));
  });

  test('Schweizer Rechtschreibung und keine Heizwerte im Code', () {
    final heatingValue = RegExp(r'\d+(\.\d+)? kWh/kg');
    // Nur Code des Neukonzepts; aeltere Dateien bleiben, wie sie sind.
    const dirs = ['app', 'analysis', 'auth', 'capture', 'household', 'info', 'more',
        'overview', 'platform', 'shell', 'status', 'study', 'theme', 'util'];
    final files = dirs.expand((d) => Directory('lib/$d').listSync(recursive: true)).whereType<File>();
    for (final f in files) {
      if (!f.path.endsWith('.dart')) continue;
      final text = f.readAsStringSync();
      expect(text.contains('ß'), isFalse, reason: '${f.path} enthält ein scharfes S');
      expect(heatingValue.hasMatch(text), isFalse,
          reason: '${f.path}: Heizwerte gehören nach /config/factors');
    }
  });

  test('Version in pubspec und App gleich', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final v = RegExp(r'^version: ([^+\s]+)', multiLine: true).firstMatch(pubspec)!.group(1);
    expect(v, kAppVersion);
  });

  test('Haushalt: gueltiger Eintrag und Kurzfassung', () {
    final entries = [
      HouseholdEntry(
          validFrom: DateTime(2026, 2, 1), persons: 2, livingAreaM2: 16, labelWPerPerson: 90),
      HouseholdEntry(validFrom: DateTime(2026, 9, 1), persons: 3, livingAreaM2: 28),
    ];
    expect(householdAt(entries, DateTime(2026, 1, 1)), isNull);
    expect(householdAt(entries, DateTime(2026, 5, 1))!.summary, '2 Personen, 16 m², Label 90 W');
    expect(householdAt(entries, DateTime(2026, 9, 1))!.persons, 3);
  });
}
