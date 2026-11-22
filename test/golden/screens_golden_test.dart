// Bildschirme der App als Golden-Bilder, mit Beispieldaten. Dienen als
// Referenz fuer das Layout und fallen auf, wenn sich etwas ungewollt aendert.
//
// Nur unter Linux (kGoldenFiles). Neu erzeugen wie in erfassen_golden_test.dart.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kwf_energiemonitor/app/app.dart';
import 'package:kwf_energiemonitor/app/services.dart';
import 'package:kwf_energiemonitor/app/session.dart';
import 'package:kwf_energiemonitor/capture/energy_form_page.dart';

import '../support/test_app.dart';

Future<void> _app(WidgetTester tester, SessionData data, {String? goTo}) async {
  await setPhoneSize(tester, size: const Size(390, 844));
  await tester.pumpWidget(EnergiemonitorApp(
    session: AppSession.fixed(data),
    services: (child) => AppServices(
      entries: FakeEntries(),
      status: FakeStatus(),
      household: FakeHousehold(),
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

  testWidgets('App Admin im Studienmodus: Uebersicht', skip: !kGoldenFiles, (tester) async {
    await _app(tester, sessionData(study: true, admin: true));
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('goldens/app_admin_uebersicht.png'));
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
