// Bedienung der Formulare fuer den Regressionstest.
//
// Jeder Treiber fuellt "sein" Formular mit denselben fachlichen Eingaben,
// so wie ein Mensch es tun wuerde: antippen, tippen, Datum waehlen, speichern.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:kwf_energiemonitor/app/firestore_services.dart';
import 'package:kwf_energiemonitor/app/services.dart';
import 'package:kwf_energiemonitor/app/session.dart';
import 'package:kwf_energiemonitor/app/session_scope.dart';
import 'package:kwf_energiemonitor/capture/capture_logic.dart';
import 'package:kwf_energiemonitor/capture/energy_form_page.dart';
import 'package:kwf_energiemonitor/energy.dart';
import 'package:kwf_energiemonitor/capture/energy_kinds.dart';
import 'package:kwf_energiemonitor/legacy/energy_form_legacy.dart';
import 'package:kwf_energiemonitor/theme/kwf_theme.dart';
import 'package:kwf_energiemonitor/user.dart';

import 'harness.dart';

/// Fachliche Eingaben, unabhaengig vom Layout.
class FormInput {
  const FormInput({
    this.type,
    this.unit,
    this.mp,
    this.description,
    this.added,
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

  /// null = nicht anfassen (Vorbelegung des neuen Formulars uebernehmen).
  final String? description;

  /// null = nicht anfassen (Vorbelegung beim Abgleich im neuen Formular).
  final String? added;
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
        find.widgetWithText(TextFormField, 'Beschreibung'), input.description!);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Hinzugefügte Menge'), input.added!);
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


/// Das neue Formular (lib/capture/energy_form_page.dart), eingebettet wie in
/// der App: Session, Dienste, deutsche Datumswaehler.
class NewFormDriver implements FormDriver {
  NewFormDriver({required this.monitorId});
  final String monitorId;

  /// Wenn gesetzt, oeffnet sich das Formular als Abgleich dieses Vorrats
  /// (Knopf "Abgleichen" auf der Vorrat-Karte).
  ({EnergyType type, String mp})? reconcile;

  @override
  String get name => 'neues Formular';

  static EnergyKind _kind(String label) =>
      EnergyKind.values.firstWhere((k) => k.label == label);

  @override
  Future<void> open(WidgetTester tester) async {
    final user = AppUser();
    final session = AppSession.fixed(SessionData(
      uid: user.userId!,
      email: user.email,
      monitors: List.of(user.monitorRead),
      editableIds: user.monitorEditIdList.toSet(),
    ));
    final entriesRepo = FirestoreManualEntries();
    final entries = await entriesRepo.load(monitorId, currentYear: DateTime.now().year);
    // Die Vorbelegung braucht auch Eintraege aus den Jahren der Testfaelle.
    final older = await entriesRepo.load(monitorId, currentYear: 2026);
    final all = {for (final e in [...entries, ...older]) e.energy.firebaseId: e}.values.toList();

    await tester.pumpWidget(SessionScope(
      session: session,
      child: AppServices(
        entries: entriesRepo,
        status: FirestoreStatus(),
        household: FirestoreHousehold(uid: () => user.userId!),
        child: MaterialApp(
          theme: buildKwfTheme(),
          locale: const Locale('de', 'CH'),
          supportedLocales: const [Locale('de', 'CH')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Scaffold(
            body: RouteHost(
              builder: (_) => EnergyFormPage(start: _start(all)),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.byKey(const ValueKey('route-host-open')));
    await pumpUntil(tester, () => find.byType(EnergyFormPage).evaluate().isNotEmpty,
        what: 'neues Formular offen');
    await settle(tester);
  }

  FormStart _start(List<ManualEntry> all) {
    final r = reconcile;
    if (r == null) return FormStart(entries: all);
    final stock = stocksOf(all)
        .firstWhere((s) => s.energy.type == r.type && s.meteringPoint == r.mp);
    return FormStart.reconcile(entries: all, stock: stock);
  }

  Future<void> _tapKey(WidgetTester tester, String key) async {
    final f = find.byKey(ValueKey(key));
    await tester.ensureVisible(f);
    await settle(tester, const Duration(milliseconds: 150));
    await tester.tap(f);
    await settle(tester, const Duration(milliseconds: 250));
  }

  Future<void> _enter(WidgetTester tester, String key, String text) async {
    final f = find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(EditableText));
    await tester.ensureVisible(f);
    await tester.enterText(f, text);
    await settle(tester, const Duration(milliseconds: 150));
  }

  Future<void> _pickDate(WidgetTester tester, String key, DateTime date) async {
    await _tapKey(tester, key);
    final toInput = find.byWidgetPredicate((w) =>
        w is Icon && (w.icon == Icons.edit_outlined || w.icon == Icons.edit));
    await tester.tap(toInput.last);
    await settle(tester);
    final input =
        find.descendant(of: find.byType(Dialog), matching: find.byType(TextField));
    await tester.enterText(input.last, DateFormat('dd.MM.yyyy').format(date));
    await settle(tester, const Duration(milliseconds: 200));
    await tester.tap(find.text('OK').last);
    await settle(tester);
  }

  @override
  Future<void> fill(WidgetTester tester, FormInput input) async {
    if (input.type != null) await _tapKey(tester, 'form-type-${_kind(input.type!).name}');
    if (input.unit == 'Ster') await _tapKey(tester, 'form-unit-Ster');
    if (input.unit == 'Kg' && input.type == 'Holz') await _tapKey(tester, 'form-unit-Kg');
    if (input.mp != null) await _tapKey(tester, 'form-mp-${input.mp}');
    if (input.added != null) await _enter(tester, 'form-added', input.added!);
    await _enter(tester, 'form-leftover', input.leftover);
    if (input.purchase != null) await _pickDate(tester, 'form-purchase', input.purchase!);
    if (input.usage != null) await _pickDate(tester, 'form-usage', input.usage!);
    if (input.description != null) {
      await _enter(tester, 'form-description', input.description!);
    }
  }

  @override
  Future<void> submit(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('form-save')));
    await tester.pump();
  }

  @override
  Future<void> waitUntilSaved(WidgetTester tester) async {
    await pumpUntil(tester, () => find.byType(EnergyFormPage).evaluate().isEmpty,
        what: 'neues Formular gespeichert und geschlossen');
    await settle(tester);
  }

  @override
  void expectStillOpen(WidgetTester tester) {
    expect(find.byType(EnergyFormPage), findsOneWidget);
  }

  @override
  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await settle(tester, const Duration(milliseconds: 200));
  }
}
