// Abgleich auf der Seite Erfassen und Mess-Schema unter Mehr, durch die
// ganze App bedient.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kwf_energiemonitor/app/app.dart';
import 'package:kwf_energiemonitor/app/services.dart';
import 'package:kwf_energiemonitor/app/session.dart';
import 'package:kwf_energiemonitor/capture/energy_form_page.dart';
import 'package:kwf_energiemonitor/energy.dart';
import 'package:kwf_energiemonitor/more/schema_page.dart';

import '../support/test_app.dart';

Future<FakeEntries> pumpApp(WidgetTester tester, SessionData data,
    {FakeStatus? status}) async {
  await setPhoneSize(tester, size: const Size(390, 844));
  final entries = FakeEntries();
  await tester.pumpWidget(EnergiemonitorApp(
    session: AppSession.fixed(data),
    services: (child) => AppServices(
      entries: entries,
      status: status ?? FakeStatus(),
      household: FakeHousehold(),
      clock: FixedClock(kNow),
      child: child,
    ),
  ));
  await tester.pumpAndSettle();
  return entries;
}

/// Die Liste des Formulars (Textfelder haben eigene Scrollables).
final formScroll =
    find.descendant(of: find.byType(EnergyFormPage), matching: find.byType(Scrollable)).first;

Finder textField(String key) =>
    find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(EditableText));

void main() {
  setUpAll(loadAppFonts);

  for (final study in [false, true]) {
    testWidgets('Abgleich: vorbelegt, aenderbar, gespeichert als Nullkauf (Studie: $study)',
        (tester) async {
      final entries = await pumpApp(tester, sessionData(study: study));
      if (!study) {
        await tester.tap(find.text('Erfassen').last);
        await tester.pumpAndSettle();
      }
      final link = find.byKey(const ValueKey('stock-reconcile-propane-M1'));
      await tester.ensureVisible(link);
      await tester.tap(link);
      await tester.pumpAndSettle();

      expect(find.text('Vorrat abgleichen'), findsOneWidget);
      await tester.scrollUntilVisible(find.byKey(const ValueKey('form-purchase')), 150,
        scrollable: formScroll);
      await tester.pumpAndSettle();
      expect(find.textContaining('Abgeglichen am', findRichText: true), findsWidgets);
      expect(tester.widget<EditableText>(textField('form-added')).controller.text, '0');
      expect(tester.widget<EditableText>(textField('form-description')).controller.text,
          'Abgleich');
      expect(tester.widget<EditableText>(textField('form-leftover')).controller.text, '');

      await tester.enterText(textField('form-leftover'), '4,5');
      await tester.enterText(textField('form-description'), 'Abgleich, gewogen');
      await tester.pumpAndSettle();
      // Ohne Verbrauch pro Tag gibt es keinen Vorschlag: Datum waehlen.
      await tester.scrollUntilVisible(find.byKey(const ValueKey('form-usage')), 150,
        scrollable: formScroll);
      await tester.tap(find.byKey(const ValueKey('form-usage')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('form-save')));
      await tester.pumpAndSettle();

      final saved = entries.added.single;
      expect(saved.purchaseQuantity, 0);
      expect(saved.leftoverQuantity, 4.5);
      expect(saved.type, EnergyType.propane);
      expect(saved.meteringPoint, 'M1');
      expect(saved.description, 'Abgleich, gewogen');
      expect(find.textContaining('Abgleich Propangas: noch 4.5 kg.'), findsOneWidget);
    });
  }

  testWidgets('Abgleich am Tag des letzten Eintrags zeigt den Hinweis', (tester) async {
    await pumpApp(tester, sessionData(study: true));
    final link = find.byKey(const ValueKey('stock-reconcile-pellets-M2'));
    await tester.ensureVisible(link);
    await tester.tap(link);
    await tester.pumpAndSettle();
    expect(find.textContaining('Ein Abgleich am selben Tag'), findsNothing);
    // Datum auf den Tag des letzten Eintrags (1.10.2026) setzen.
    await tester.scrollUntilVisible(find.byKey(const ValueKey('form-purchase')), 150,
        scrollable: formScroll);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('form-purchase')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit_outlined).last);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.descendant(of: find.byType(Dialog), matching: find.byType(TextField)).last,
        '01.10.2026');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const ValueKey('form-usage')), 150,
        scrollable: formScroll);
    await tester.pumpAndSettle();
    expect(find.textContaining('Ein Abgleich am selben Tag'), findsOneWidget);
  });

  testWidgets('nur Lesen: kein Abgleichen', (tester) async {
    await pumpApp(tester, sessionData(study: true, canEdit: false));
    expect(find.text('Abgleichen'), findsNothing);
    expect(find.text('Nachfüllen'), findsNothing);
  });

  for (final study in [false, true]) {
    testWidgets('Mess-Schema ueber Mehr erreichbar, ohne Messwerte (Studie: $study)',
        (tester) async {
      await pumpApp(tester, sessionData(study: study));
      await tester.tap(find.text('Mehr').last);
      await tester.pumpAndSettle();
      final row = find.text('Mess-Schema');
      await tester.scrollUntilVisible(row, 200, scrollable: find.byType(Scrollable).last);
      await tester.tap(row);
      await tester.pumpAndSettle();

      expect(find.text('Dein Mess-Schema'), findsOneWidget);
      expect(find.textContaining('Wohnklima unvollständig'), findsOneWidget);
      expect(find.text('ENERGIE ÜBER DIE SYSTEMGRENZE'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('WASSER'), 200,
          scrollable: find
              .descendant(of: find.byType(SchemaView), matching: find.byType(Scrollable))
              .first);
      expect(find.text('VERBRAUCHER IM HAUS'), findsOneWidget);
      // Nie ein Messwert mit Einheit.
      for (final unit in ['kWh', '°C', 'ppm', ' W ']) {
        expect(find.textContaining(unit), findsNothing, reason: unit);
      }
    });
  }
}
