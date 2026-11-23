// Uebersicht und Auswertung (Etappe 3) durch die ganze App bedient, mit
// erfundenen Tageswerten (Beispieldaten).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kwf_energiemonitor/app/app.dart';
import 'package:kwf_energiemonitor/app/services.dart';
import 'package:kwf_energiemonitor/app/session.dart';
import 'package:kwf_energiemonitor/daily/daily_values.dart';
import 'package:kwf_energiemonitor/household/household.dart';
import 'package:kwf_energiemonitor/info/info_overlay.dart';

import '../support/test_app.dart';

Future<void> pumpApp(WidgetTester tester,
    {SessionData? data, FakeHousehold? household, List<DailyValues>? days}) async {
  await setPhoneSize(tester, size: const Size(390, 844));
  await tester.pumpWidget(EnergiemonitorApp(
    session: AppSession.fixed(data ?? sessionData()),
    services: (child) => AppServices(
      entries: FakeEntries(),
      status: FakeStatus(),
      household: household ?? FakeHousehold(),
      daily: FakeDaily(days ?? sampleDays(DateTime(2025, 11, 1), kNow, partialUntil: kNow)),
      factors: FakeFactors(),
      clock: FixedClock(kNow),
      child: child,
    ),
  ));
  await tester.pumpAndSettle();
}

Finder pageScroll() => find.byType(Scrollable).first;

Future<void> openAnalysis(WidgetTester tester) async {
  await tester.tap(find.text('Auswertung').last);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('Uebersicht: Satz der Woche, Kacheln, Tagesbalken, Link', (tester) async {
    await pumpApp(tester);
    expect(find.text('DIESE WOCHE'), findsOneWidget);
    expect(find.textContaining('Diese Woche habt ihr'), findsOneWidget);
    expect(find.textContaining('davon von der Sonne'), findsOneWidget);
    expect(find.text('Verbrauch pro Person und Tag'), findsOneWidget);
    expect(find.text('Eigenversorgung Strom'), findsOneWidget);
    expect(find.text('Wohnklima innen'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Zur Auswertung'), 200, scrollable: pageScroll());
    expect(find.text('Wofür ging die Energie drauf?'), findsOneWidget);
    await tester.tap(find.text('Zur Auswertung'));
    await tester.pumpAndSettle();
    expect(find.text('Wie viel pro Person?'), findsOneWidget);
  });

  testWidgets('Uebersicht: Info-Overlay ohne offene Platzhalter', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byType(InfoButton).first);
    await tester.pumpAndSettle();
    expect(find.text('Verbrauch pro Person'), findsWidgets);
    expect(find.textContaining('{'), findsNothing);
    expect(find.textContaining('Pellets 5 kWh/kg'), findsOneWidget);
  });

  testWidgets('Uebersicht ohne Tageswerte', (tester) async {
    await pumpApp(tester, days: const []);
    expect(find.textContaining('Die ersten Tageswerte kommen'), findsOneWidget);
  });

  testWidgets('Auswertung: Jahr als Standard, Umschalter blaettert', (tester) async {
    await pumpApp(tester);
    await openAnalysis(tester);
    expect(find.textContaining('Dez. 2025 bis Nov. 2026'), findsOneWidget);
    expect(find.text('Nach Minergie'.toUpperCase()), findsNothing);
    expect(find.text('Nach Minergie'), findsOneWidget);
    expect(find.text('Nach 2000 Watt'), findsOneWidget);
    expect(find.text('2000-Watt-Ziel'), findsOneWidget);
    expect(find.text('Schweiz heute'), findsOneWidget);
    expect(find.text('Euer Haus'), findsNWidgets(2));

    await tester.tap(find.text('WOCHE'));
    await tester.pumpAndSettle();
    expect(find.textContaining('KW 47'), findsOneWidget);
    expect(find.textContaining('Kurze Zeiträume schwanken stark'), findsOneWidget);
    final next = find.byKey(const ValueKey('range-next'));
    expect(tester.widget<IconButton>(next).onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey('range-prev')));
    await tester.pumpAndSettle();
    expect(find.textContaining('KW 46'), findsOneWidget);
    expect(tester.widget<IconButton>(next).onPressed, isNotNull);

    await tester.tap(find.text('SAISON'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Heizsaison 2026/27'), findsOneWidget);
  });

  testWidgets('Auswertung: alle Abschnitte, Heatmap ab vier Wochen', (tester) async {
    await pumpApp(tester);
    await openAnalysis(tester);
    for (final title in [
      'Woher kommt die Energie?',
      'Monat für Monat',
      'Heizen',
      'Wie behaglich war es?',
      'Wann wart ihr zu Hause?',
      'So rechnen wir',
    ]) {
      await tester.scrollUntilVisible(find.text(title), 300, scrollable: pageScroll());
      expect(find.text(title), findsOneWidget, reason: title);
    }
    expect(find.textContaining('Tagen bewohnt'), findsOneWidget);
    expect(find.byKey(const ValueKey('co2-cell-0-0')), findsOneWidget);
    expect(find.textContaining('nicht gemessen'), findsWidgets);
  });

  testWidgets('Auswertung: Schalter mit Solarstrom', (tester) async {
    await pumpApp(tester);
    await openAnalysis(tester);
    await tester.scrollUntilVisible(find.byKey(const ValueKey('with-pv')), 200,
        scrollable: pageScroll());
    expect(find.text('nach Minergie, berechnet'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('with-pv')));
    await tester.pumpAndSettle();
    expect(find.text('nach Minergie, mit Solarstrom'), findsOneWidget);
  });

  testWidgets('Auswertung: Personen erst spaeter erfasst, ohne Klimasensor', (tester) async {
    final days = sampleDays(DateTime(2026, 9, 1), kNow, partialUntil: kNow, climate: false);
    await pumpApp(tester,
        household: FakeHousehold([HouseholdEntry(validFrom: DateTime(2026, 11, 1), persons: 2)]),
        days: days);
    await openAnalysis(tester);
    // Saison (keine 12 Monate Daten), Oktober ohne Personen
    expect(find.textContaining('Heizsaison 2026/27'), findsOneWidget);
    expect(find.textContaining('Für 31 Tage fehlen Personen'), findsOneWidget);
    await tester.scrollUntilVisible(find.textContaining('keinen Klimasensor'), 300,
        scrollable: pageScroll());
    expect(find.text('Wie behaglich war es?'), findsNothing);
    expect(find.textContaining('Verteilung auf Tage nicht möglich'), findsWidgets);
  });

  testWidgets('Studienmodus: keine Uebersicht, keine Auswertung', (tester) async {
    await pumpApp(tester, data: sessionData(study: true));
    expect(find.text('Übersicht'), findsNothing);
    expect(find.text('Auswertung'), findsNothing);
    expect(find.textContaining('kWh'), findsNothing);
    expect(find.textContaining('Watt'), findsNothing);
  });
}
