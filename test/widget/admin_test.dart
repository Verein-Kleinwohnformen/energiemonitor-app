// Verwaltung der Zugaenge (Superadmin).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kwf_energiemonitor/admin/access.dart';
import 'package:kwf_energiemonitor/admin/admin_page.dart';
import 'package:kwf_energiemonitor/app/session.dart';

import '../support/test_app.dart';

void main() {
  setUpAll(loadAppFonts);

  group('Zugriffe berechnen', () {
    const a = Account(uid: 'u', read: ['h1', 'h2'], edit: ['h1']);

    test('Reihenfolge bleibt, neue Haeuser ans Ende', () {
      final r = applyAccess(a, {'h3': Access.read, 'h1': Access.read});
      expect(r.read, ['h1', 'h2', 'h3']);
      expect(r.edit, isEmpty);
    });

    test('Bearbeiten schliesst Lesen ein, kein Zugriff entfernt beides', () {
      final r = applyAccess(a, {'h4': Access.edit, 'h1': Access.none});
      expect(r.read, ['h2', 'h4']);
      expect(r.edit, ['h4']);
    });

    test('Bearbeiten ohne Lesen in alten Daten wird geheilt', () {
      const old = Account(uid: 'u', read: [], edit: ['h1']);
      expect(applyAccess(old, const {}).read, ['h1']);
    });

    test('Aenderungen in Worten', () {
      final lines = describeChanges(
        beforeRead: const ['h1'],
        beforeEdit: const [],
        afterRead: const ['h1', 'h2'],
        afterEdit: const ['h1'],
        name: (id) => 'Haus $id',
      );
      expect(lines, ['Haus h1: Lesen → Bearbeiten', 'Haus h2: Kein Zugriff → Lesen']);
    });
  });

  testWidgets('Konten mit E-Mail, Suche, altes Konto ohne E-Mail', (tester) async {
    await setPhoneSize(tester, size: const Size(390, 900));
    await tester.pumpWidget(wrap(const AdminPage(),
        session: AppSession.fixed(sessionData(superadmin: true)), admin: FakeAdmin()));
    await tester.pumpAndSettle();
    expect(find.text('3 Konten'), findsOneWidget);
    expect(find.text('bewohner@example.test'), findsOneWidget);
    expect(find.text('neu@example.test'), findsOneWidget);
    expect(find.textContaining('Konto u-lese'), findsOneWidget);
    expect(find.textContaining('Beispielhaus (bearbeiten)'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('admin-search')), 'NEU@');
    await tester.pumpAndSettle();
    expect(find.text('bewohner@example.test'), findsNothing);
    expect(find.text('neu@example.test'), findsOneWidget);
  });

  testWidgets('Zuordnung aendern, bestaetigen, speichern', (tester) async {
    await setPhoneSize(tester, size: const Size(390, 900));
    final admin = FakeAdmin();
    await tester.pumpWidget(wrap(const AdminPage(),
        session: AppSession.fixed(sessionData(superadmin: true)), admin: admin));
    await tester.pumpAndSettle();
    await tester.tap(find.text('neu@example.test'));
    await tester.pumpAndSettle();

    // Studienhaus: Lesen, Beispielhaus: Bearbeiten, Testmonitor: kein Zugriff.
    Future<void> choose(String monitorId, String label) async {
      final seg = find.byKey(ValueKey('admin-access-$monitorId'));
      await tester.ensureVisible(seg);
      await tester.tap(find.descendant(of: seg, matching: find.text(label)));
      await tester.pumpAndSettle();
    }

    await choose('demo-studie', 'Lesen');
    await choose('demo-haus', 'Bearbeiten');
    await choose('sandbox_monitor', 'Kein Zugriff');
    await tester.ensureVisible(find.byKey(const ValueKey('admin-save')));
    await tester.tap(find.byKey(const ValueKey('admin-save')));
    await tester.pumpAndSettle();

    expect(find.text('Zugriffe ändern?'), findsOneWidget);
    expect(find.text('• Studienhaus: Kein Zugriff → Lesen'), findsOneWidget);
    expect(find.text('• Beispielhaus: Kein Zugriff → Bearbeiten'), findsOneWidget);
    expect(find.text('• Testmonitor: Bearbeiten → Kein Zugriff'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('admin-confirm')));
    await tester.pumpAndSettle();

    expect(admin.saved.single.uid, 'u-neu');
    expect(admin.saved.single.read, ['demo-studie', 'demo-haus']);
    expect(admin.saved.single.edit, ['demo-haus']);
    expect(admin.saved.single.actor, 'test-uid');
  });

  testWidgets('Protokoll zeigt Aenderungen in Worten', (tester) async {
    await setPhoneSize(tester, size: const Size(390, 900));
    await tester.pumpWidget(wrap(const AdminPage(),
        session: AppSession.fixed(sessionData(superadmin: true)), admin: FakeAdmin()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Protokoll'));
    await tester.pumpAndSettle();
    expect(find.text('Studienhaus: Kein Zugriff → Lesen'), findsOneWidget);
    expect(find.textContaining('von superadmin@example.test'), findsOneWidget);
  });

  testWidgets('ohne Superadmin keine Verwaltung', (tester) async {
    await tester.pumpWidget(wrap(const AdminPage(),
        session: AppSession.fixed(sessionData()), admin: FakeAdmin()));
    await tester.pumpAndSettle();
    expect(find.text('Nur für Superadmins.'), findsOneWidget);
  });
}
