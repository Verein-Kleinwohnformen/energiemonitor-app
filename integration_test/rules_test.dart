// Firestore-Rules im Emulator (Konzept Umsetzung, Abschnitt 2).
//
// Prueft die neuen Regeln (Haushalt, Rollen) und dass die bestehenden
// Regeln gleich geblieben sind (manuelle Eintraege, Telemetrie, Monitore,
// User-Dokumente). Jede Regel auch mit dem Fall, der abgelehnt werden muss.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

const kMon = 'rules-monitor';
const kPassword = 'emulator-only-123';

Future<void> expectDenied(Future<Object?> Function() action, String what) async {
  try {
    await action();
  } on FirebaseException catch (e) {
    expect(e.code, 'permission-denied', reason: what);
    return;
  }
  fail('Nicht abgelehnt: $what');
}

Future<void> expectAllowed(Future<Object?> Function() action, String what) async {
  try {
    await action();
  } on FirebaseException catch (e) {
    fail('Abgelehnt (${e.code}): $what');
  }
}

Future<String> as(String email) async {
  await FirebaseAuth.instance.signOut();
  final c = await FirebaseAuth.instance
      .signInWithEmailAndPassword(email: email, password: kPassword);
  return c.user!.uid;
}

final db = FirebaseFirestore.instance;
CollectionReference<Map<String, dynamic>> household(String m) =>
    db.collection('monitors').doc(m).collection('household');

Map<String, Object?> validHousehold(String uid) => {
      'valid_from': '2026-11-21',
      'persons': 2,
      'living_area_m2': 16.5,
      'updated_by': uid,
      'updated_at': FieldValue.serverTimestamp(),
    };

late String editor;
late String reader;
late String outsider;

Future<void> prepareUsers() async {
  await EmulatorAdmin.resetAll();
  await EmulatorAdmin.setDoc('monitors/$kMon', {
    'monitor_id': kMon,
    'tinyhouse_name': 'Rules-Haus',
    'tinyhouse_location': 'Testort',
    'study_mode': true,
  });
  outsider = await signInTestUser(
      email: 'outsider@example.test', monitorRead: [], monitorEdit: []);
  reader = await signInTestUser(
      email: 'reader@example.test', monitorRead: [kMon], monitorEdit: []);
  editor = await signInTestUser(
      email: 'editor@example.test', monitorRead: [kMon], monitorEdit: [kMon]);
  await EmulatorAdmin.setDoc('roles/$reader', {'admin': true});
}

void main() {
  setUpIntegrationReporting();
  setUpAll(() async {
    await initEmulatorFirebase();
    await prepareUsers();
  });

  testWidgets('Haushalt: anlegen mit Bearbeitungsrecht, nie aendern oder loeschen', (t) async {
    final uid = await as('editor@example.test');
    final ref = household(kMon).doc('2026-11-21_1');
    await expectAllowed(() => ref.set(validHousehold(uid)), 'gueltiger Eintrag');
    await expectAllowed(() => ref.get(), 'lesen mit Bearbeitungsrecht');
    await expectDenied(() => ref.update({'persons': 3}), 'aendern');
    await expectDenied(() => ref.delete(), 'loeschen');
    await expectDenied(() => ref.set(validHousehold(uid)), 'ueberschreiben');
  });

  testWidgets('Haushalt: ungueltige Eintraege werden abgelehnt', (t) async {
    final uid = await as('editor@example.test');
    var i = 10;
    Future<void> bad(Map<String, Object?> change, String what) => expectDenied(
        () => household(kMon).doc('bad_${i++}').set({...validHousehold(uid), ...change}), what);
    await bad({'persons': 0}, 'null Personen');
    await bad({'persons': 2.5}, 'halbe Person');
    await bad({'persons': '2'}, 'Personen als Text');
    await bad({'valid_from': '21.11.2026'}, 'Datum im falschen Format');
    await bad({'living_area_m2': -1}, 'negative Flaeche');
    await bad({'updated_by': 'jemand-anders'}, 'fremde updated_by');
    await bad({'updated_at': Timestamp.fromDate(DateTime(2020))}, 'Zeit vom Geraet');
    await bad({'study_mode': false}, 'zusaetzliches Feld');
  });

  testWidgets('Haushalt: Lesen mit Leserecht, nicht anlegen; Fremde nichts', (t) async {
    final r = await as('reader@example.test');
    await expectAllowed(() => household(kMon).get(), 'lesen mit Leserecht');
    await expectDenied(
        () => household(kMon).doc('r_1').set(validHousehold(r)), 'anlegen nur mit Leserecht');
    final o = await as('outsider@example.test');
    await expectDenied(() => household(kMon).get(), 'lesen ohne Zugriff');
    await expectDenied(() => household(kMon).doc('o_1').set(validHousehold(o)), 'anlegen ohne Zugriff');
  });

  testWidgets('Monitor: Studienmodus nicht abschaltbar', (t) async {
    await as('editor@example.test');
    final ref = db.collection('monitors').doc(kMon);
    await expectAllowed(() => ref.get(), 'Monitor lesen');
    await expectDenied(() => ref.update({'study_mode': false}), 'study_mode aendern');
    await expectDenied(() => ref.set({'monitor_id': 'x'}), 'Monitor ueberschreiben');
  });

  testWidgets('Rollen: nur die eigene lesen, nie schreiben', (t) async {
    final r = await as('reader@example.test');
    await expectAllowed(() => db.collection('roles').doc(r).get(), 'eigene Rolle lesen');
    await expectDenied(() => db.collection('roles').doc(r).set({'admin': false}), 'eigene Rolle schreiben');
    final e = await as('editor@example.test');
    await expectDenied(() => db.collection('roles').doc(reader).get(), 'fremde Rolle lesen');
    await expectDenied(() => db.collection('roles').doc(e).set({'admin': true}), 'sich zum Admin machen');
  });

  testWidgets('User: Studien-Dialog speichern ja, Rechte aendern nein', (t) async {
    final e = await as('editor@example.test');
    final ref = db.collection('users').doc(e);
    await expectAllowed(
        () => ref.update({
              'study_dialog_seen': FieldValue.arrayUnion([kMon])
            }),
        'study_dialog_seen');
    await expectDenied(
        () => ref.update({
              'monitor_read': FieldValue.arrayUnion(['fremd'])
            }),
        'monitor_read erweitern');
    await expectDenied(
        () => ref.update({
              'monitor_edit': FieldValue.arrayUnion(['fremd'])
            }),
        'monitor_edit erweitern');
    await expectDenied(() => db.collection('users').doc(reader).get(), 'fremdes User-Dokument');
  });

  testWidgets('bestehende Regeln: manuelle Eintraege und Telemetrie', (t) async {
    await as('editor@example.test');
    final manual = db.collection('devices').doc(kMon).collection('manual').doc('2026').collection('data');
    await expectAllowed(() => manual.doc('a').set({'x': 1}), 'Eintrag mit Bearbeitungsrecht');
    final telemetry = db.collection('devices').doc(kMon).collection('telemetry').doc('2026').collection('11');
    await expectDenied(() => telemetry.doc('t').set({'x': 1}), 'Telemetrie schreiben');
    await as('reader@example.test');
    await expectAllowed(() => manual.get(), 'Eintraege lesen mit Leserecht');
    await expectDenied(() => manual.doc('b').set({'x': 1}), 'Eintrag ohne Bearbeitungsrecht');
    await as('outsider@example.test');
    await expectDenied(() => manual.get(), 'Eintraege lesen ohne Zugriff');
    await expectDenied(() => telemetry.get(), 'Telemetrie lesen ohne Zugriff');
  });
}
