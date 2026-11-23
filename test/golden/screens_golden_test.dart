// Bildschirme der App als Golden-Bilder, mit Beispieldaten. Dienen als
// Referenz fuer das Layout und fallen auf, wenn sich etwas ungewollt aendert.
//
// Nur unter Linux (kGoldenFiles). Neu erzeugen wie in erfassen_golden_test.dart.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kwf_energiemonitor/admin/admin_page.dart';
import 'package:kwf_energiemonitor/app/app.dart';
import 'package:kwf_energiemonitor/app/services.dart';
import 'package:kwf_energiemonitor/app/session.dart';
import 'package:kwf_energiemonitor/capture/energy_form_page.dart';

import '../support/test_app.dart';

Future<void> _app(WidgetTester tester, SessionData data,
    {String? goTo, bool daily = false, double height = 844}) async {
  await setPhoneSize(tester, size: Size(390, height));
  await tester.pumpWidget(EnergiemonitorApp(
    session: AppSession.fixed(data),
    services: (child) => AppServices(
      entries: FakeEntries(),
      status: FakeStatus(),
      household: FakeHousehold(),
      daily: daily
          ? FakeDaily(sampleDays(DateTime(2025, 11, 1), kNow, partialUntil: kNow))
          : const NoDaily(),
      factors: FakeFactors(),
      clock: FixedClock(kNow),
      child: child,
    ),
  ));
  await tester.pumpAndSettle();
  if (goTo != null) {
    await tester.tap(find.text(goTo).last);
    await tester.pumpAndSettle();
  }
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('App normal: Uebersicht', skip: !kGoldenFiles, (tester) async {
    await _app(tester, sessionData(), daily: true, height: 1400);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/app_uebersicht.png'));
  });

  testWidgets('App normal: Auswertung Jahr', skip: !kGoldenFiles, (tester) async {
    await _app(tester, sessionData(), daily: true, height: 3600, goTo: 'Auswertung');
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('goldens/app_auswertung_jahr.png'));
  });

  testWidgets('App normal: Auswertung Woche', skip: !kGoldenFiles, (tester) async {
    await _app(tester, sessionData(), daily: true, height: 3600, goTo: 'Auswertung');
    await tester.tap(find.text('WOCHE'));
    await tester.pumpAndSettle();
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('goldens/app_auswertung_woche.png'));
  });

  testWidgets('App normal: Erfassen', skip: !kGoldenFiles, (tester) async {
    await _app(tester, sessionData(), goTo: 'Erfassen');
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/app_erfassen.png'));
  });

  testWidgets('App Studienmodus: Erfassen', skip: !kGoldenFiles, (tester) async {
    await _app(tester, sessionData(study: true));
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('goldens/app_studie_erfassen.png'));
  });

  testWidgets('App normal: Mehr', skip: !kGoldenFiles, (tester) async {
    await _app(tester, sessionData(), goTo: 'Mehr');
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/app_mehr.png'));
  });

  testWidgets('App Studienmodus: Mehr', skip: !kGoldenFiles, (tester) async {
    await _app(tester, sessionData(study: true), goTo: 'Mehr');
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/app_studie_mehr.png'));
  });

  testWidgets('Verwaltung: Konten', skip: !kGoldenFiles, (tester) async {
    await setPhoneSize(tester, size: const Size(390, 844));
    await tester.pumpWidget(wrap(const AdminPage(),
        session: AppSession.fixed(sessionData(superadmin: true)), admin: FakeAdmin()));
    await tester.pumpAndSettle();
    await expectLater(find.byType(AdminPage), matchesGoldenFile('goldens/verwaltung_konten.png'));
  });

  testWidgets('Verwaltung: Zuordnung eines Kontos', skip: !kGoldenFiles, (tester) async {
    await setPhoneSize(tester, size: const Size(390, 844));
    await tester.pumpWidget(wrap(const AdminPage(),
        session: AppSession.fixed(sessionData(superadmin: true)), admin: FakeAdmin()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('bewohner@example.test'));
    await tester.pumpAndSettle();
    await expectLater(
        find.byType(AccountAccessPage), matchesGoldenFile('goldens/verwaltung_zuordnung.png'));
  });

  testWidgets('Formular mit Vorbelegung', skip: !kGoldenFiles, (tester) async {
    await setPhoneSize(tester, size: const Size(390, 1160));
    await tester.pumpWidget(wrap(
      EnergyFormPage(start: FormStart(entries: sampleEntries())),
      session: AppSession.fixed(sessionData()),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('form-type-pellets')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).at(0), '15');
    await tester.enterText(find.byType(EditableText).at(1), '3');
    await tester.pumpAndSettle();
    await expectLater(find.byType(EnergyFormPage), matchesGoldenFile('goldens/formular.png'));
  });
}
