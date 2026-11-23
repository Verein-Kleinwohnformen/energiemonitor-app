// Erfassen: Eintrag aendern und Messpunkt-Tags, durch die ganze App bedient.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kwf_energiemonitor/app/app.dart';
import 'package:kwf_energiemonitor/app/services.dart';
import 'package:kwf_energiemonitor/app/session.dart';
import 'package:kwf_energiemonitor/capture/capture_logic.dart';
import 'package:kwf_energiemonitor/capture/energy_form_page.dart';
import 'package:kwf_energiemonitor/energy.dart';

import '../support/test_app.dart';

Future<FakeEntries> pumpCapture(WidgetTester tester, {bool canEdit = true}) async {
  await setPhoneSize(tester, size: const Size(390, 844));
  final entries = FakeEntries();
  await tester.pumpWidget(EnergiemonitorApp(
    session: AppSession.fixed(sessionData(study: true, canEdit: canEdit)),
    services: (child) => AppServices(
      entries: entries,
      status: FakeStatus(),
      household: FakeHousehold(),
      clock: FixedClock(kNow),
      child: child,
    ),
  ));
  await tester.pumpAndSettle();
  return entries;
}

Finder pageScroll() => find.byType(Scrollable).first;

Finder field(String key) =>
    find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(EditableText));

void main() {
  setUpAll(loadAppFonts);

  test('nur der juengste Eintrag eines Vorrats laesst sich aendern', () {
    final all = sampleEntries();
    final latest = [for (final e in all) if (isLatestOfStock(e, all)) e.energy.purchaseDate];
    expect(latest, [DateTime(2026, 10, 1), DateTime(2026, 7, 19)]);
  });

  testWidgets('Messpunkt als Tag auf Vorrat und Eintraegen', (tester) async {
    await pumpCapture(tester);
    expect(find.byKey(const ValueKey('mp-tag-M1')), findsWidgets);
    expect(find.byKey(const ValueKey('mp-tag-M2')), findsWidgets);
    expect(find.text('M1 Warmwasser'), findsWidgets);
    expect(find.text('M2 Heizwärme'), findsWidgets);
  });

  testWidgets('Eintrag aendern: vorbelegt, gespeichert als Ersatz', (tester) async {
    final entries = await pumpCapture(tester);
    final edit = find.byTooltip('Eintrag ändern');
    await tester.scrollUntilVisible(edit.first, 200, scrollable: pageScroll());
    expect(edit, findsNWidgets(2));
    final propane = entries.items.firstWhere((e) => e.energy.type == EnergyType.propane);
    final key = find.byKey(ValueKey('entry-edit-${propane.energy.firebaseId}'));
    // Mitte des Bildschirms, nicht unter der Tab-Leiste.
    await Scrollable.ensureVisible(tester.element(key), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(key);
    await tester.pumpAndSettle();

    expect(find.text('Eintrag ändern'), findsOneWidget);
    final scroll = find
        .descendant(of: find.byType(EnergyFormPage), matching: find.byType(Scrollable))
        .first;
    await tester.scrollUntilVisible(find.byKey(const ValueKey('form-leftover')), 150,
        scrollable: scroll);
    await tester.pumpAndSettle();
    expect(tester.widget<EditableText>(field('form-added')).controller.text, '11.5');
    expect(tester.widget<EditableText>(field('form-leftover')).controller.text, '12');
    expect(tester.widget<EditableText>(field('form-description')).controller.text,
        'Neue Flasche');

    await tester.enterText(field('form-leftover'), '10');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const ValueKey('form-save')), 150,
        scrollable: scroll);
    await tester.tap(find.byKey(const ValueKey('form-save')));
    await tester.pumpAndSettle();

    final (old, updated) = entries.replaced.single;
    expect(identical(old, propane), isTrue);
    expect(updated.leftoverQuantity, 10);
    expect(updated.purchaseQuantity, 11.5);
    expect(updated.type, EnergyType.propane);
    expect(updated.meteringPoint, 'M1');
    expect(updated.purchaseDate, DateTime(2026, 7, 19));
    expect(updated.description, 'Neue Flasche');
    expect(find.textContaining('Geändert: Propangas'), findsOneWidget);
  });

  testWidgets('nur Lesen: kein Aendern', (tester) async {
    await pumpCapture(tester, canEdit: false);
    expect(find.byTooltip('Eintrag ändern'), findsNothing);
  });

  test('FormStart.edit nimmt Traeger und Messpunkt vom Eintrag', () {
    final e = sampleEntries()[1];
    final s = FormStart.edit(entries: sampleEntries(), entry: e);
    expect((s.isEdit, s.isReconcile, s.meteringPoint), (true, false, 'M1'));
  });
}
