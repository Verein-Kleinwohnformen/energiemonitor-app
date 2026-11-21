// Bedienung der Formulare fuer den Regressionstest.
//
// Jeder Treiber fuellt "sein" Formular mit denselben fachlichen Eingaben,
// so wie ein Mensch es tun wuerde: antippen, tippen, Datum waehlen, speichern.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:kwf_energiemonitor/legacy/energy_form_legacy.dart';

import 'harness.dart';

/// Fachliche Eingaben, unabhaengig vom Layout.
class FormInput {
  const FormInput({
    this.type,
    this.unit,
    this.mp,
    required this.description,
    required this.added,
    required this.leftover,
    this.purchase,
    this.usage,
  });

  /// Beschriftung wie im alten Formular: Benzin, Diesel, Heizöl,
  /// Holzpellets, Propangas, Holz.
  final String? type;

  /// Nur bei Holz: 'Kg' oder 'Ster'. null = Standard des Formulars.
  final String? unit;

  /// 'M0', 'M1' oder 'M2'.
  final String? mp;
  final String description;
  final String added;
  final String leftover;
  final DateTime? purchase;
  final DateTime? usage;
}

abstract class FormDriver {
  String get name;
  Future<void> open(WidgetTester tester);
  Future<void> fill(WidgetTester tester, FormInput input);
  Future<void> submit(WidgetTester tester);
  Future<void> waitUntilSaved(WidgetTester tester);
  void expectStillOpen(WidgetTester tester);
  Future<void> close(WidgetTester tester);
}

/// Das Formular vor dem Neukonzept, unveraendert in lib/legacy/.
class LegacyFormDriver implements FormDriver {
  @override
  String get name => 'altes Formular';

  static const _mpLabels = {
    'M0': 'M0 - Gemischt',
    'M1': 'M1 - Warmwasser',
    'M2': 'M2 - Heizwärme',
  };

  @override
  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: RouteHost(builder: (_) => const EnergyForm())),
    ));
    await tester.tap(find.byKey(const ValueKey('route-host-open')));
    await pumpUntil(tester, () => find.byType(EnergyForm).evaluate().isNotEmpty,
        what: 'altes Formular offen');
    await settle(tester);
  }

  Future<void> _pickFromDropdown(WidgetTester tester, int index, String label) async {
    final dropdown = find.byType(DropdownButtonFormField<String>).at(index);
    await tester.ensureVisible(dropdown);
    await tester.tap(dropdown);
    await settle(tester);
    await tester.tap(find.text(label).last);
    await settle(tester);
  }

  Future<void> _pickDate(WidgetTester tester, String fieldLabel, DateTime date) async {
    final field = find.widgetWithText(TextFormField, fieldLabel);
    await tester.ensureVisible(field);
    await tester.tap(field);
    await settle(tester);
    final toInput = find.byWidgetPredicate((w) =>
        w is Icon && (w.icon == Icons.edit_outlined || w.icon == Icons.edit));
    await tester.tap(toInput.last);
    await settle(tester);
    final input = find.descendant(
        of: find.byType(Dialog), matching: find.byType(TextField));
    await tester.enterText(input.last, DateFormat('MM/dd/yyyy').format(date));
    await settle(tester, const Duration(milliseconds: 200));
    await tester.tap(find.text('OK').last);
    await settle(tester);
  }

  @override
  Future<void> fill(WidgetTester tester, FormInput input) async {
    if (input.type != null) {
      await tester.tap(find.text(input.type!).first);
      await settle(tester, const Duration(milliseconds: 200));
    }
    if (input.mp != null) {
      await _pickFromDropdown(tester, 0, _mpLabels[input.mp]!);
    }
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Beschreibung'), input.description);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Hinzugefügte Menge'), input.added);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Übrige Menge'), input.leftover);
    if (input.unit != null && input.unit != 'Kg') {
      // Beide Einheiten-Felder teilen sich denselben Wert.
      await _pickFromDropdown(tester, 1, input.unit!);
    }
    if (input.purchase != null) {
      await _pickDate(tester, 'Kaufdatum eingeben', input.purchase!);
    }
    if (input.usage != null) {
      await _pickDate(tester, 'Verbrauchsdatum eingeben', input.usage!);
    }
  }

  @override
  Future<void> submit(WidgetTester tester) async {
    final button = find.text('Hinzufügen');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
  }

  @override
  Future<void> waitUntilSaved(WidgetTester tester) async {
    await pumpUntil(tester, () => find.byType(EnergyForm).evaluate().isEmpty,
        what: 'altes Formular gespeichert und geschlossen');
    await settle(tester);
  }

  @override
  void expectStillOpen(WidgetTester tester) {
    expect(find.byType(EnergyForm), findsOneWidget);
  }

  @override
  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await settle(tester, const Duration(milliseconds: 200));
  }
}
