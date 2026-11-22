// Hilfen fuer Widget- und Golden-Tests: Testdaten (Beispieldaten), Dienste
// ohne Firestore, Schriften laden.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kwf_energiemonitor/app/services.dart';
import 'package:kwf_energiemonitor/app/session.dart';
import 'package:kwf_energiemonitor/app/session_scope.dart';
import 'package:kwf_energiemonitor/energy.dart';
import 'package:kwf_energiemonitor/household/household.dart';
import 'package:kwf_energiemonitor/metering_point.dart';
import 'package:kwf_energiemonitor/monitor.dart';
import 'package:kwf_energiemonitor/theme/kwf_theme.dart';

/// Fester Zeitpunkt fuer alle Tests (Beispieldaten).
final kNow = DateTime(2026, 11, 21, 14, 30);

ManualEntry entry(EnergyType type, String mp, DateTime purchase, double added,
    double leftover, String description,
    {double? consumed, DateTime? usage}) {
  return ManualEntry(
    Energy(
      firebaseId: '${purchase.millisecondsSinceEpoch}-$mp-${energyTypeToString(type)}',
      typeCounter: 0,
      description: description,
      purchaseDate: purchase,
      usageDate: usage ?? purchase.add(const Duration(days: 60)),
      type: type,
      purchaseQuantity: added,
      leftoverQuantity: leftover,
      meteringPoint: mp,
      monitorId: 'demo',
    ),
    storedConsumed: consumed ?? 0,
  );
}

/// Beispieldaten wie im Mockup Erfassen.
List<ManualEntry> sampleEntries() => [
      entry(EnergyType.pellets, 'M2', DateTime(2026, 10, 1), 30, 5, 'Pellets Landi, 2 Säcke',
          consumed: 12),
      entry(EnergyType.propane, 'M1', DateTime(2026, 7, 19), 11.5, 12, 'Neue Flasche'),
      entry(EnergyType.pellets, 'M2', DateTime(2026, 3, 10), 15, 2, 'Restposten vom Winter'),
    ];

class FakeEntries implements ManualEntriesRepository {
  FakeEntries([List<ManualEntry>? initial]) : items = initial ?? sampleEntries();
  final List<ManualEntry> items;
  final added = <Energy>[];

  @override
  Future<List<ManualEntry>> load(String monitorId, {required int currentYear}) async =>
      List.of(items)..sort((a, b) => b.energy.purchaseDate.compareTo(a.energy.purchaseDate));

  @override
  Future<void> add(Energy energy) async {
    added.add(energy);
    items.add(ManualEntry(energy));
  }

  @override
  Future<void> delete(ManualEntry entry) async => items.remove(entry);
}

MeteringPoint point(String id, DateTime lastSeen, {List<String> sensors = const []}) =>
    MeteringPoint(
      deviceId: 'demo',
      meteringPointId: id,
      firstSeen: 0,
      lastSeen: lastSeen.millisecondsSinceEpoch,
      sensorTypes: sensors,
      valueFields: const [],
    );

List<MeteringPoint> samplePoints() => [
      point('E1', kNow.subtract(const Duration(minutes: 30)), sensors: ['victron']),
      point('E3', kNow.subtract(const Duration(minutes: 30)), sensors: ['victron']),
      point('I2', kNow.subtract(const Duration(minutes: 30)), sensors: ['shelly-3em-pro']),
      point('K0', kNow.subtract(const Duration(minutes: 32)), sensors: ['netatmo']),
      point('M2', DateTime(2026, 10, 1)),
    ];

class FakeStatus implements StatusRepository {
  FakeStatus([List<MeteringPoint>? points]) : points = points ?? samplePoints();
  final List<MeteringPoint> points;
  @override
  Stream<List<MeteringPoint>> watch(String monitorId) => Stream.value(points);
}

class FakeHousehold implements HouseholdRepository {
  FakeHousehold([List<HouseholdEntry>? initial])
      : items = initial ??
            [HouseholdEntry(validFrom: DateTime(2026, 2, 1), persons: 2, livingAreaM2: 16)];
  final List<HouseholdEntry> items;
  final _changes = StreamController<List<HouseholdEntry>>.broadcast();

  @override
  Stream<List<HouseholdEntry>> watch(String monitorId) async* {
    yield List.of(items);
    yield* _changes.stream;
  }

  @override
  Future<void> add(String monitorId, HouseholdEntry entry) async {
    items.add(entry);
    _changes.add(List.of(items));
  }
}

EnergieMonitor monitor({String id = 'demo', String name = 'Testhaus', bool study = false}) =>
    EnergieMonitor(
      id: id,
      tinyhouseName: name,
      tinyhouseLocation: 'Testort',
      studyMode: study,
    );

SessionData sessionData({
  bool study = false,
  bool admin = false,
  bool canEdit = true,
  bool dialogSeen = true,
  List<EnergieMonitor>? monitors,
}) {
  final ms = monitors ?? [monitor(study: study)];
  return SessionData(
    uid: 'test-uid',
    email: 'person@example.test',
    displayName: 'Test',
    monitors: ms,
    editableIds: canEdit ? ms.map((m) => m.id).toSet() : {},
    isAdmin: admin,
    studyDialogSeen: dialogSeen ? ms.map((m) => m.id).toSet() : {},
  );
}

/// Baut ein Widget mit Theme, Session und Diensten wie in der App.
Widget wrap(
  Widget child, {
  required AppSession session,
  ManualEntriesRepository? entries,
  StatusRepository? status,
  HouseholdRepository? household,
}) {
  return SessionScope(
    session: session,
    child: AppServices(
      entries: entries ?? FakeEntries(),
      status: status ?? FakeStatus(),
      household: household ?? FakeHousehold(),
      clock: FixedClock(kNow),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildKwfTheme(),
        locale: const Locale('de', 'CH'),
        supportedLocales: const [Locale('de', 'CH')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: child,
      ),
    ),
  );
}

bool _fontsLoaded = false;

/// Laedt Inter und die Material-Icons, damit Golden-Bilder echten Text zeigen.
Future<void> loadAppFonts() async {
  if (_fontsLoaded) return;
  final inter = FontLoader('Inter')..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
  await inter.load();
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) {
    final icons = File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (icons.existsSync()) {
      final loader = FontLoader('MaterialIcons')
        ..addFont(Future.value(ByteData.view(icons.readAsBytesSync().buffer)));
      await loader.load();
    }
  }
  _fontsLoaded = true;
}

/// Handygroesse wie in den Mockups.
Future<void> setPhoneSize(WidgetTester tester, {Size size = const Size(390, 1100)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}
