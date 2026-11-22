// Navigation und Studienmodus (Konzept Umsetzung, Abschnitt 5):
// Monitor mit Flag zeigt nur Erfassen und Mehr, Links auf Auswertung fuehren
// zurueck zu Erfassen, Admin sieht alles mit Band.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kwf_energiemonitor/app/app.dart';
import 'package:kwf_energiemonitor/app/routes.dart';
import 'package:kwf_energiemonitor/app/services.dart';
import 'package:kwf_energiemonitor/app/session.dart';
import 'package:kwf_energiemonitor/shell/app_shell.dart';

import '../support/test_app.dart';

class _RecordingBackend implements SessionBackend {
  final seen = <String>[];
  @override
  Future<SessionData?> load() async => null;
  @override
  Future<void> markStudyDialogSeen(String uid, String monitorId) async => seen.add(monitorId);
  @override
  Future<void> updateDisplayName(String name) async {}
  @override
  Future<void> signOut() async {}
}

Future<void> pumpApp(WidgetTester tester, AppSession session,
    {FakeHousehold? household}) async {
  await setPhoneSize(tester, size: const Size(390, 844));
  await tester.pumpWidget(EnergiemonitorApp(
    session: session,
    services: (child) => AppServices(
      entries: FakeEntries(),
      status: FakeStatus(),
      household: household ?? FakeHousehold(),
      clock: FixedClock(kNow),
      child: child,
    ),
  ));
  await tester.pumpAndSettle();
}

List<String> tabLabels(WidgetTester tester) => tester
    .widgetList<Text>(find.descendant(of: find.byType(KwfTabBar), matching: find.byType(Text)))
    .map((t) => t.data!)
    .toList();

void main() {
  setUpAll(loadAppFonts);

  group('Weiterleitungen', () {
    test('abgemeldet fuehrt zur Anmeldung', () {
      final s = AppSession(_RecordingBackend())..phase = SessionPhase.signedOut;
      expect(redirectFor(s, Routes.capture), Routes.login);
      expect(redirectFor(s, Routes.login), isNull);
    });

    test('Studienmodus: auswertende Seiten fuehren zu Erfassen', () {
      final s = AppSession.fixed(sessionData(study: true));
      for (final p in [
        Routes.overview,
        Routes.analysis,
        Routes.measurements,
        Routes.export,
        Routes.method,
      ]) {
        expect(redirectFor(s, p), Routes.capture, reason: p);
      }
      for (final p in [Routes.capture, Routes.more, Routes.household, Routes.study]) {
        expect(redirectFor(s, p), isNull, reason: p);
      }
      expect(homeFor(s), Routes.capture);
    });

    test('es gibt keine Rolle, die den Studienmodus aufhebt, auch Superadmin nicht', () {
      final s = AppSession.fixed(sessionData(study: true, superadmin: true));
      expect(redirectFor(s, Routes.analysis), Routes.capture);
      expect(homeFor(s), Routes.capture);
    });

    test('Verwaltung nur fuer Superadmin', () {
      expect(redirectFor(AppSession.fixed(sessionData()), Routes.admin), Routes.more);
      expect(redirectFor(AppSession.fixed(sessionData(superadmin: true)), Routes.admin), isNull);
    });

    test('normaler Modus startet in der Uebersicht', () {
      expect(homeFor(AppSession.fixed(sessionData())), Routes.overview);
    });
  });

  testWidgets('normaler Modus: vier Tabs, kein Band', (tester) async {
    await pumpApp(tester, AppSession.fixed(sessionData()));
    expect(tabLabels(tester), ['Übersicht', 'Auswertung', 'Erfassen', 'Mehr']);
    expect(find.text('Auswertungen folgen. Hier siehst du bald, wie viel Energie ihr diese '
        'Woche gebraucht habt und woher sie kam.'), findsOneWidget);
    expect(find.textContaining('Studienmodus aktiv'), findsNothing);
  });

  testWidgets('Studienmodus: nur Erfassen und Mehr, Start auf Erfassen', (tester) async {
    await pumpApp(tester, AppSession.fixed(sessionData(study: true)));
    expect(tabLabels(tester), ['Erfassen', 'Mehr']);
    expect(find.text('Erfassen'), findsWidgets);
    expect(find.text('ENERGIETRÄGER ERFASSEN'), findsOneWidget);

    await tester.tap(find.text('Mehr').last);
    await tester.pumpAndSettle();
    expect(find.text('Messwerte'), findsNothing);
    expect(find.text('Daten herunterladen'), findsNothing);
    expect(find.text('So rechnen wir'), findsNothing);
    expect(find.text('Systemstatus'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Über die Energiestudie'), 200,
        scrollable: find.byType(Scrollable).last);
    expect(find.text('Über die Energiestudie'), findsOneWidget);
    expect(find.text('Messwerte'), findsNothing);
  });

  testWidgets('Superadmin sieht in Mehr die Verwaltung, andere nicht', (tester) async {
    await pumpApp(tester, AppSession.fixed(sessionData(superadmin: true)));
    await tester.tap(find.text('Mehr').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Zugänge verwalten'), 200,
        scrollable: find.byType(Scrollable).last);
    expect(find.text('Zugänge verwalten'), findsOneWidget);

    await pumpApp(tester, AppSession.fixed(sessionData()));
    await tester.tap(find.text('Mehr').last);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(find.text('Zugänge verwalten'), findsNothing);
  });

  testWidgets('Studien-Dialog erscheint einmal', (tester) async {
    final backend = _RecordingBackend();
    final session = AppSession.fixed(sessionData(study: true, dialogSeen: false), backend: backend);
    await pumpApp(tester, session);
    expect(find.text('Dein Haus ist Teil der Energiestudie'), findsOneWidget);
    await tester.tap(find.text('VERSTANDEN'));
    await tester.pumpAndSettle();
    expect(find.text('Dein Haus ist Teil der Energiestudie'), findsNothing);
    expect(backend.seen, ['demo']);
    expect(session.needsStudyDialog, isFalse);
  });

  testWidgets('ohne Haushalt fragt die App nach Personen und Flaeche', (tester) async {
    final household = FakeHousehold([]);
    await pumpApp(tester, AppSession.fixed(sessionData()), household: household);
    expect(find.text('Wer wohnt hier?'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('household-persons')), '2');
    await tester.enterText(find.byKey(const ValueKey('household-area')), '16,5');
    await tester.tap(find.byKey(const ValueKey('household-save')));
    await tester.pumpAndSettle();
    expect(find.text('Wer wohnt hier?'), findsNothing);
    expect(household.items.single.persons, 2);
    expect(household.items.single.livingAreaM2, 16.5);
    expect(household.items.single.validFrom, DateTime(2026, 11, 21));
  });

  testWidgets('nur Leserechte: keine Frage nach dem Haushalt', (tester) async {
    await pumpApp(tester, AppSession.fixed(sessionData(canEdit: false)),
        household: FakeHousehold([]));
    expect(find.text('Wer wohnt hier?'), findsNothing);
  });

  testWidgets('Status-Pille zeigt den Stand', (tester) async {
    await pumpApp(tester, AppSession.fixed(sessionData()));
    expect(find.text('Alles läuft · 14:00'), findsOneWidget);
  });

  testWidgets('Monitor wechseln nur bei mehreren Monitoren', (tester) async {
    final session = AppSession.fixed(sessionData(monitors: [
      monitor(id: 'a', name: 'Haus A'),
      monitor(id: 'b', name: 'Haus B', study: true),
    ]));
    await pumpApp(tester, session);
    expect(find.text('Haus A'), findsOneWidget);
    await tester.tap(find.text('Haus A'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Haus B'));
    await tester.pumpAndSettle();
    expect(session.active!.id, 'b');
    // Haus B ist ein Studienmonitor: nur noch zwei Tabs.
    expect(tabLabels(tester), ['Erfassen', 'Mehr']);
  });
}
