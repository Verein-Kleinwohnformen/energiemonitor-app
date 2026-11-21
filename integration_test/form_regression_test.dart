// Formular-Regressionstest (Konzept 04, Abschnitt 5).
//
// Gleiche Eingaben in altem und neuem Formular muessen denselben Zustand in
// Firestore ergeben: gleiches Dokument (ausser ID und created_at), gleiche
// Nachfuehrung des Vorgaenger-Eintrags, gleiche Messpunkt-Metadaten.
//
// Jeder Fall laeuft pro Formular auf einer frisch geleerten Emulator-Datenbank
// mit denselben Vorab-Eintraegen. Danach wird der ganze Zustand des
// Test-Monitors verglichen.
//
// Ausfuehren:
//   firebase emulators:exec --only firestore,auth --project demo-energiemonitor \
//     "node tool/run_web_tests.mjs integration_test/form_regression_test.dart"
import 'package:flutter_test/flutter_test.dart';
import 'package:kwf_energiemonitor/energy.dart';
import 'package:kwf_energiemonitor/legacy/energy_form_legacy.dart';
import 'package:kwf_energiemonitor/user.dart';

import 'form_drivers.dart';
import 'harness.dart';

const kMonitor = 'test-monitor';

/// Ein Vorab-Eintrag, angelegt ueber den produktiven Speicherweg.
class Seed {
  const Seed(this.type, this.mp, this.purchase, this.usage, this.added,
      this.leftover, [this.description = 'Vorab']);
  final EnergyType type;
  final String mp;
  final DateTime purchase;
  final DateTime usage;
  final double added;
  final double leftover;
  final String description;
}

class Scenario {
  const Scenario(this.name, this.input,
      {this.inputNew,
      this.seeds = const [],
      this.expectSaved = true,
      this.expectError,
      this.expectErrorNew,
      this.check});
  final String name;
  final FormInput input;

  /// Eingaben im neuen Formular, wenn sie sich bewusst unterscheiden
  /// (Vorbelegung uebernehmen, Dezimalkomma). Sonst dieselben.
  final FormInput? inputNew;

  /// Fehlermeldung im neuen Formular, wenn sie anders lautet.
  final String? expectErrorNew;
  final List<Seed> seeds;
  final bool expectSaved;

  /// Fehlermeldung, die das alte Formular zeigt (das neue zeigt dieselbe).
  final String? expectError;

  /// Zusaetzliche Pruefung der Werte, damit der Test auch ohne zweites
  /// Formular etwas aussagt.
  final void Function(List<Map<String, dynamic>> entries)? check;
}

DateTime d(int y, int m, int day) => DateTime(y, m, day);

Map<String, dynamic> entryAt(List<Map<String, dynamic>> entries, DateTime purchase) =>
    entries.singleWhere((e) =>
        (e['metadata'] as Map)['purchase_date'] == purchase.millisecondsSinceEpoch);

Map<String, dynamic> values(Map<String, dynamic> entry) =>
    Map<String, dynamic>.from(((entry['data_points'] as List).first as Map)['values'] as Map);

final scenarios = <Scenario>[
  Scenario(
    'erster Eintrag Propangas',
    FormInput(type: 'Propangas', mp: 'M1', description: 'Neue Flasche',
        added: '11.5', leftover: '0.5', purchase: d(2026, 7, 19), usage: d(2026, 9, 30)),
    check: (e) {
      final v = values(entryAt(e, d(2026, 7, 19)));
      expect(v['consumed_quantity'], 0);
      expect(v['unit'], 'kg');
    },
  ),
  Scenario(
    'zweiter Eintrag gleicher Traeger, Vorgaenger wird nachgefuehrt',
    FormInput(type: 'Propangas', mp: 'M1', description: 'Flaschenwechsel',
        added: '11.5', leftover: '0.5', purchase: d(2026, 7, 19), usage: d(2026, 10, 1)),
    seeds: [Seed(EnergyType.propane, 'M1', d(2026, 5, 1), d(2026, 7, 1), 11, 2)],
    check: (e) {
      expect(values(entryAt(e, d(2026, 7, 19)))['consumed_quantity'], 12.5);
      final prev = entryAt(e, d(2026, 5, 1))['metadata'] as Map;
      expect(prev['usage_date_provisory'], false);
      expect(prev['estimated_usage_date'], d(2026, 7, 19).millisecondsSinceEpoch);
    },
  ),
  Scenario(
    'Eintrag ueber den Jahreswechsel',
    FormInput(type: 'Holzpellets', mp: 'M2', description: 'Pellets, 1 Sack',
        added: '15', leftover: '10', purchase: d(2026, 1, 15), usage: d(2026, 3, 1)),
    seeds: [Seed(EnergyType.pellets, 'M2', d(2025, 12, 10), d(2026, 1, 31), 30, 5)],
    check: (e) {
      expect(values(entryAt(e, d(2026, 1, 15)))['consumed_quantity'], 25);
      expect((entryAt(e, d(2025, 12, 10))['metadata'] as Map)['usage_date_provisory'], false);
    },
  ),
  Scenario(
    'Holz in kg',
    FormInput(type: 'Holz', unit: 'Kg', mp: 'M2', description: 'Brennholz',
        added: '120', leftover: '20', purchase: d(2026, 10, 5), usage: d(2026, 12, 1)),
    check: (e) {
      final entry = entryAt(e, d(2026, 10, 5));
      expect((entry['metadata'] as Map)['energy_type'], 'woodKg');
      expect(values(entry)['unit'], 'kg');
    },
  ),
  Scenario(
    'Holz in Ster mit Vorgaenger',
    FormInput(type: 'Holz', unit: 'Ster', mp: 'M2', description: 'Ster Buche',
        added: '1', leftover: '0.75', purchase: d(2026, 2, 1), usage: d(2026, 4, 1)),
    seeds: [Seed(EnergyType.woodSter, 'M2', d(2025, 10, 1), d(2026, 1, 1), 2, 0.5)],
    check: (e) {
      final entry = entryAt(e, d(2026, 2, 1));
      expect((entry['metadata'] as Map)['energy_type'], 'woodSter');
      expect(values(entry)['unit'], 'Ster');
      expect(values(entry)['consumed_quantity'], 1.75);
    },
  ),
  Scenario(
    'Rest groesser als Vorrat ergibt verbraucht 0',
    FormInput(type: 'Propangas', mp: 'M1', description: 'Gewogen',
        added: '11', leftover: '20', purchase: d(2026, 8, 1), usage: d(2026, 9, 1)),
    seeds: [Seed(EnergyType.propane, 'M1', d(2026, 6, 1), d(2026, 7, 1), 11, 0)],
    check: (e) => expect(values(entryAt(e, d(2026, 8, 1)))['consumed_quantity'], 0),
  ),
  Scenario(
    'anderer Messpunkt zaehlt nicht als Vorgaenger',
    FormInput(type: 'Propangas', mp: 'M1', description: 'Kochen',
        added: '5', leftover: '1', purchase: d(2026, 8, 1), usage: d(2026, 9, 1)),
    seeds: [Seed(EnergyType.propane, 'M0', d(2026, 6, 1), d(2026, 7, 1), 11, 0)],
    check: (e) {
      expect(values(entryAt(e, d(2026, 8, 1)))['consumed_quantity'], 0);
      expect((entryAt(e, d(2026, 6, 1))['metadata'] as Map)['usage_date_provisory'], true);
    },
  ),
  Scenario(
    'Heizoel in Litern, Kauf- und Enddatum am selben Tag',
    FormInput(type: 'Heizöl', mp: 'M0', description: 'Tank',
        added: '500', leftover: '100', purchase: d(2026, 9, 1), usage: d(2026, 9, 1)),
    check: (e) => expect(values(entryAt(e, d(2026, 9, 1)))['unit'], 'Liter'),
  ),
  Scenario(
    'Vorbelegung vom letzten Mal ergibt denselben Eintrag',
    FormInput(type: 'Propangas', mp: 'M1', description: 'Flasche 11 kg',
        added: '11', leftover: '1.5', purchase: d(2026, 9, 2), usage: d(2026, 11, 1)),
    // Im neuen Formular nur Traeger, Mengen und Daten: Messpunkt und
    // Beschreibung kommen aus dem letzten Eintrag.
    inputNew: FormInput(type: 'Propangas', added: '11', leftover: '1.5',
        purchase: d(2026, 9, 2), usage: d(2026, 11, 1)),
    seeds: [Seed(EnergyType.propane, 'M1', d(2026, 6, 1), d(2026, 8, 1), 11, 0.5, 'Flasche 11 kg')],
    check: (e) => expect(values(entryAt(e, d(2026, 9, 2)))['consumed_quantity'], 10),
  ),
  Scenario(
    'Dezimalkomma im neuen Formular ergibt dieselbe Zahl',
    FormInput(type: 'Holzpellets', mp: 'M2', description: 'Sack',
        added: '11.5', leftover: '2.25', purchase: d(2026, 10, 3), usage: d(2026, 11, 3)),
    inputNew: FormInput(type: 'Holzpellets', mp: 'M2', description: 'Sack',
        added: '11,5', leftover: ' 2,25 ', purchase: d(2026, 10, 3), usage: d(2026, 11, 3)),
    check: (e) => expect(values(entryAt(e, d(2026, 10, 3)))['added_quantity'], 11.5),
  ),
  Scenario(
    'ohne Energietraeger wird nichts gespeichert',
    FormInput(mp: 'M1', description: 'x', added: '1', leftover: '0',
        purchase: d(2026, 8, 1), usage: d(2026, 9, 1)),
    expectSaved: false, expectError: 'Bitte eine Einheit wählen',
    expectErrorNew: 'Bitte einen Energieträger wählen',
  ),
  Scenario(
    'ohne Messpunkt wird nichts gespeichert',
    FormInput(type: 'Propangas', description: 'x', added: '1', leftover: '0',
        purchase: d(2026, 8, 1), usage: d(2026, 9, 1)),
    expectSaved: false, expectError: 'Bitte einen Messpunkt wählen',
  ),
  Scenario(
    'leere Beschreibung wird abgelehnt',
    FormInput(type: 'Propangas', mp: 'M1', description: '   ', added: '1', leftover: '0',
        purchase: d(2026, 8, 1), usage: d(2026, 9, 1)),
    expectSaved: false, expectError: 'Bitte eine Beschreibung eingeben',
  ),
  Scenario(
    'leere Menge wird abgelehnt',
    FormInput(type: 'Propangas', mp: 'M1', description: 'x', added: '', leftover: '0',
        purchase: d(2026, 8, 1), usage: d(2026, 9, 1)),
    expectSaved: false, expectError: 'Bitte eine Zahl eingeben',
  ),
  Scenario(
    'Text statt Zahl wird abgelehnt',
    FormInput(type: 'Propangas', mp: 'M1', description: 'x', added: 'elf', leftover: '0',
        purchase: d(2026, 8, 1), usage: d(2026, 9, 1)),
    expectSaved: false, expectError: 'Bitte eine gültige Zahl eingeben',
  ),
  Scenario(
    'Ende vor dem Kauf wird abgelehnt',
    FormInput(type: 'Propangas', mp: 'M1', description: 'x', added: '1', leftover: '0',
        purchase: d(2026, 8, 1), usage: d(2026, 7, 1)),
    expectSaved: false, expectError: 'Verbrauchsdatum muss nach dem Kaufdatum liegen',
  ),
  const Scenario(
    'ohne Datum wird nichts gespeichert',
    FormInput(type: 'Propangas', mp: 'M1', description: 'x', added: '1', leftover: '0'),
    expectSaved: false, expectError: 'Bitte ein Datum auswählen',
  ),
];

/// Die Formulare, die verglichen werden. Das neue kommt mit dem Umbau dazu.
final drivers = <FormDriver>[
  LegacyFormDriver(),
  NewFormDriver(monitorId: kMonitor),
];

Future<void> prepare(List<Seed> seeds) async {
  await EmulatorAdmin.resetAll();
  await EmulatorAdmin.setDoc('monitors/$kMonitor', {
    'monitor_id': kMonitor,
    'tinyhouse_name': 'Testhaus',
    'tinyhouse_location': 'Testort',
  });
  await signInTestUser(
      email: 'form-test@example.test',
      monitorRead: [kMonitor],
      monitorEdit: [kMonitor]);
  await AppUser().init();
  expect(AppUser().activeMonitor?.id, kMonitor);
  for (final s in seeds) {
    await Energy(
      firebaseId: '',
      typeCounter: 0,
      description: s.description,
      purchaseDate: s.purchase,
      usageDate: s.usage,
      type: s.type,
      purchaseQuantity: s.added,
      leftoverQuantity: s.leftover,
      meteringPoint: s.mp,
      usageDateProvisory: true,
      userId: AppUser().userId,
      monitorId: kMonitor,
    ).addToFirebase();
  }
}

void main() {
  setUpIntegrationReporting();

  setUpAll(initEmulatorFirebase);

  for (final scenario in scenarios) {
    testWidgets(scenario.name, (tester) async {
      final states = <String, List<String>>{};
      for (final driver in drivers) {
        await prepare(scenario.seeds);
        final uid = AppUser().userId!;
        List<String> normalized(List<String> state) => state
            .map((line) => line.replaceAll('"user_id":"$uid"', '"user_id":"<angemeldet>"'))
            .toList();
        final before = normalized(await readMonitorState(kMonitor));

        await driver.open(tester);
        final isNew = driver is NewFormDriver;
        await driver.fill(tester, isNew ? scenario.inputNew ?? scenario.input : scenario.input);
        await driver.submit(tester);

        if (scenario.expectSaved) {
          await driver.waitUntilSaved(tester);
        } else {
          await settle(tester);
          final message =
              isNew ? scenario.expectErrorNew ?? scenario.expectError! : scenario.expectError!;
          expect(find.text(message), findsWidgets,
              reason: '${driver.name}: Fehlermeldung fehlt');
          driver.expectStillOpen(tester);
        }

        // Jeder Durchlauf hat einen frischen Test-User. Die ID wird fuer den
        // Vergleich ersetzt, muss aber genau die der angemeldeten Person sein.
        final after = normalized(await readMonitorState(kMonitor));
        if (!scenario.expectSaved) {
          expect(after, before, reason: '${driver.name}: es wurde etwas gespeichert');
        } else {
          expect(after.length, greaterThan(before.length),
              reason: '${driver.name}: kein neuer Eintrag');
          expect(after.where((l) => l.contains('"user_id":"<angemeldet>"')), isNotEmpty,
              reason: '${driver.name}: Eintrag nicht mit der angemeldeten Person gespeichert');
          scenario.check?.call(await readManualEntries(kMonitor));
        }
        states[driver.name] = after;
        await driver.close(tester);
      }

      final reference = states.values.first;
      states.forEach((name, state) {
        expect(state, reference, reason: '$name weicht vom alten Formular ab');
      });
    });
  }

  testWidgets('neues Formular lehnt negative Mengen ab', (tester) async {
    await prepare(const []);
    final driver = NewFormDriver(monitorId: kMonitor);
    final before = await readMonitorState(kMonitor);
    await driver.open(tester);
    await driver.fill(
        tester,
        FormInput(type: 'Propangas', mp: 'M1', description: 'x', added: '-1',
            leftover: '0', purchase: d(2026, 8, 1), usage: d(2026, 9, 1)));
    await driver.submit(tester);
    await settle(tester);
    expect(find.text('Bitte eine Zahl ab 0 eingeben'), findsOneWidget);
    driver.expectStillOpen(tester);
    expect(await readMonitorState(kMonitor), before);
    await driver.close(tester);
  });

  // Dokumentiert das alte Verhalten, das sich bewusst aendert (Entscheid
  // 21.11.2026): Das alte Formular lehnt "11,5" ab.
  testWidgets('altes Formular lehnt Dezimalkomma ab', (tester) async {
    await prepare(const []);
    final driver = LegacyFormDriver();
    await driver.open(tester);
    await driver.fill(
        tester,
        FormInput(type: 'Propangas', mp: 'M1', description: 'x', added: '11,5',
            leftover: '0', purchase: d(2026, 8, 1), usage: d(2026, 9, 1)));
    await driver.submit(tester);
    await settle(tester);
    expect(find.text('Bitte eine gültige Zahl eingeben'), findsOneWidget);
    expect(find.byType(EnergyForm), findsOneWidget);
    await driver.close(tester);
  });
}
