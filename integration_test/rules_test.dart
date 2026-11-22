// Firestore-Rules im Emulator (Konzept Umsetzung, Abschnitt 2; Etappe 1b).
//
// Prueft Haushalt, Zugriffsverwaltung durch den Superadmin (Custom Claim im
// Login-Token), das Protokoll und dass die bestehenden Regeln gleich
// geblieben sind. Jede Regel auch mit dem Fall, der abgelehnt werden muss.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kwf_energiemonitor/admin/access.dart';

import 'harness.dart';

const kMon = 'rules-monitor';
const kOther = 'anderes-haus';
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
DocumentReference<Map<String, dynamic>> userDoc(String uid) => db.collection('users').doc(uid);

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
late String superadmin;

Future<Account> account(String uid) async =>
    Account.fromFirestore(uid, (await userDoc(uid).get()).data()!);

Future<void> prepareUsers() async {
  await EmulatorAdmin.resetAll();
  for (final m in [kMon, kOther]) {
    await EmulatorAdmin.setDoc('monitors/$m', {
      'monitor_id': m,
      'tinyhouse_name': 'Haus $m',
      'tinyhouse_location': 'Testort',
      'study_mode': m == kMon,
    });
  }
  outsider = await signInTestUser(email: 'outsider@example.test', monitorRead: [], monitorEdit: []);
  reader = await signInTestUser(email: 'reader@example.test', monitorRead: [kMon], monitorEdit: []);
  editor = await signInTestUser(
      email: 'editor@example.test', monitorRead: [kMon], monitorEdit: [kMon]);
  superadmin = await signInTestUser(
      email: 'superadmin@example.test', monitorRead: [], monitorEdit: []);
  await EmulatorAdmin.setClaims(superadmin, {'superadmin': true});
  await EmulatorAdmin.setDoc('devices/$kOther/manual/2026/data/x', {'x': 1});
}

void main() {
  setUpIntegrationReporting();
  setUpAll(() async {
    await initEmulatorFirebase();
    await prepareUsers();
  });

  group('Haushalt', () {
    testWidgets('anlegen mit Bearbeitungsrecht, nie aendern oder loeschen', (t) async {
      final uid = await as('editor@example.test');
      final ref = household(kMon).doc('2026-11-21_1');
      await expectAllowed(() => ref.set(validHousehold(uid)), 'gueltiger Eintrag');
      await expectAllowed(() => ref.get(), 'lesen mit Bearbeitungsrecht');
      await expectDenied(() => ref.update({'persons': 3}), 'aendern');
      await expectDenied(() => ref.delete(), 'loeschen');
      await expectDenied(() => ref.set(validHousehold(uid)), 'ueberschreiben');
    });

    testWidgets('ungueltige Eintraege werden abgelehnt', (t) async {
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

    testWidgets('lesen mit Leserecht, nicht anlegen; Fremde nichts', (t) async {
      final r = await as('reader@example.test');
      await expectAllowed(() => household(kMon).get(), 'lesen mit Leserecht');
      await expectDenied(
          () => household(kMon).doc('r_1').set(validHousehold(r)), 'anlegen nur mit Leserecht');
      final o = await as('outsider@example.test');
      await expectDenied(() => household(kMon).get(), 'lesen ohne Zugriff');
      await expectDenied(
          () => household(kMon).doc('o_1').set(validHousehold(o)), 'anlegen ohne Zugriff');
    });
  });

  group('Monitore', () {
    testWidgets('lesen nur mit Zugriff, Liste nur fuer Superadmin', (t) async {
      await as('editor@example.test');
      await expectAllowed(() => db.collection('monitors').doc(kMon).get(), 'eigenen Monitor');
      await expectDenied(() => db.collection('monitors').doc(kOther).get(), 'fremden Monitor');
      await expectDenied(() => db.collection('monitors').get(), 'alle Monitore auflisten');
      await expectDenied(
          () => db.collection('monitors').doc(kMon).update({'study_mode': false}),
          'Studienmodus abschalten');
      await as('superadmin@example.test');
      await expectAllowed(() => db.collection('monitors').get(), 'Superadmin listet Monitore');
      await expectDenied(
          () => db.collection('monitors').doc(kMon).update({'study_mode': false}),
          'Superadmin aendert Monitor aus der App');
    });
  });

  group('Eigenes User-Dokument', () {
    testWidgets('erlaubte Felder ja, Rechte und neue Felder nein', (t) async {
      final e = await as('editor@example.test');
      await expectAllowed(
          () => userDoc(e).update({'study_dialog_seen': FieldValue.arrayUnion([kMon])}),
          'study_dialog_seen');
      await expectAllowed(() => userDoc(e).update({'user_name': 'Edi'}), 'Name');
      await expectAllowed(() => userDoc(e).update({'email': 'editor@example.test'}),
          'E-Mail wie im Token');
      await expectDenied(() => userDoc(e).update({'email': 'chef@example.test'}),
          'fremde E-Mail eintragen');
      await expectDenied(
          () => userDoc(e).update({'monitor_read': FieldValue.arrayUnion([kOther])}),
          'monitor_read erweitern');
      await expectDenied(
          () => userDoc(e).update({'monitor_edit': FieldValue.arrayUnion([kOther])}),
          'monitor_edit erweitern');
      await expectDenied(() => userDoc(e).update({'superadmin': true}), 'superadmin-Feld');
      await expectDenied(() => userDoc(e).update({'role': 'admin'}), 'role-Feld');
      await expectDenied(() => userDoc(e).delete(), 'eigenes Dokument loeschen');
      await expectDenied(() => userDoc(reader).get(), 'fremdes User-Dokument lesen');
      await expectDenied(() => db.collection('users').get(), 'alle Konten auflisten');
    });

    testWidgets('Registrieren nur mit Sandbox und ohne Zusatzfelder', (t) async {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: 'neu@example.test', password: kPassword);
      final uid = cred.user!.uid;
      Map<String, Object?> doc([Map<String, Object?> extra = const {}]) => {
            'user_id': uid,
            'email': 'neu@example.test',
            'monitor_read': ['sandbox_monitor'],
            'monitor_edit': ['sandbox_monitor'],
            'monitor_api_keys': <String, Object?>{},
            'date_created': Timestamp.now(),
            ...extra,
          };
      await expectDenied(() => userDoc(uid).set(doc({'role': 'admin'})), 'mit Rolle');
      await expectDenied(() => userDoc(uid).set(doc({'superadmin': true})), 'mit superadmin');
      await expectDenied(() => userDoc(uid).set(doc({'email': 'chef@example.test'})),
          'mit fremder E-Mail');
      await expectDenied(
          () => userDoc(uid).set(doc({
                'monitor_read': ['sandbox_monitor', kMon]
              })),
          'mit echtem Monitor');
      await expectAllowed(() => userDoc(uid).set(doc()), 'normale Registrierung');
    });
  });

  group('Zugriffsverwaltung', () {
    testWidgets('Superadmin ordnet zu, mit Protokoll im selben Batch', (t) async {
      final s = await as('superadmin@example.test');
      await expectAllowed(() => db.collection('users').get(), 'Konten auflisten');
      final before = await account(outsider);
      final next = applyAccess(before, {kMon: Access.edit, kOther: Access.read});
      await expectAllowed(
          () => FirestoreAdmin().saveAccess(
              account: before,
              read: next.read,
              edit: next.edit,
              actorUid: s,
              actorEmail: 'superadmin@example.test'),
          'Zuordnung speichern');
      final after = await account(outsider);
      expect(after.read, [kMon, kOther]);
      expect(after.edit, [kMon]);
      final log = await db.collection('admin_log').get();
      expect(log.docs.length, 1);
      expect(log.docs.single.data()['target_uid'], outsider);
      // Die Person sieht jetzt das Haus, aber nur ueber die Zuordnung.
      await as('outsider@example.test');
      await expectAllowed(() => db.collection('monitors').doc(kOther).get(), 'neu zugeordnet');
    });

    testWidgets('ohne passenden Protokolleintrag abgelehnt', (t) async {
      final s = await as('superadmin@example.test');
      final ref = userDoc(reader);
      Map<String, Object?> change(String logId) => {
            'monitor_read': [kMon, kOther],
            'monitor_edit': <String>[],
            'access_log_id': logId,
            'access_updated_by': s,
            'access_updated_at': FieldValue.serverTimestamp(),
          };
      await expectDenied(() => ref.update(change('gibt-es-nicht')), 'ohne Protokoll');

      // Protokoll beschreibt etwas anderes als die Aenderung.
      final log = db.collection('admin_log').doc();
      final batch = db.batch()
        ..set(log, {
          'actor_uid': s,
          'target_uid': reader,
          'before_read': [kMon],
          'before_edit': <String>[],
          'after_read': [kMon],
          'after_edit': <String>[],
          'at': FieldValue.serverTimestamp(),
        })
        ..update(ref, change(log.id));
      await expectDenied(() => batch.commit(), 'Protokoll passt nicht zur Aenderung');
    });

    testWidgets('Superadmin aendert nur Lesen und Bearbeiten, Bearbeiten nie ohne Lesen',
        (t) async {
      final s = await as('superadmin@example.test');
      final before = await account(reader);
      Future<void> attempt(List<String> read, List<String> edit, Map<String, Object?> extra,
          String what) async {
        final log = db.collection('admin_log').doc();
        final batch = db.batch()
          ..set(log, {
            'actor_uid': s,
            'target_uid': reader,
            'before_read': before.read,
            'before_edit': before.edit,
            'after_read': read,
            'after_edit': edit,
            'at': FieldValue.serverTimestamp(),
          })
          ..update(userDoc(reader), {
            'monitor_read': read,
            'monitor_edit': edit,
            'access_log_id': log.id,
            'access_updated_by': s,
            'access_updated_at': FieldValue.serverTimestamp(),
            ...extra,
          });
        await expectDenied(() => batch.commit(), what);
      }

      await attempt([kMon], [kMon, kOther], {}, 'Bearbeiten ohne Lesen');
      await attempt([kMon], [], {'monitor_api_keys': {kMon: 'x'}}, 'Device-Keys setzen');
      await attempt([kMon], [], {'email': 'x@example.test'}, 'E-Mail aendern');
      await attempt([kMon], [], {'access_updated_by': 'jemand'}, 'fremder Verfasser');
      await expectDenied(() => userDoc(reader).delete(), 'Konto loeschen');
    });

    testWidgets('ohne Superadmin keine Zuordnung, auch nicht fuer sich selbst', (t) async {
      final e = await as('editor@example.test');
      final me = await account(e);
      final next = applyAccess(me, {kOther: Access.edit});
      await expectDenied(
          () => FirestoreAdmin().saveAccess(account: me, read: next.read, edit: next.edit, actorUid: e),
          'sich selbst Zugriff geben');
      await expectDenied(() => db.collection('admin_log').get(), 'Protokoll lesen');
    });

    testWidgets('Superadmin sieht keine Messdaten ohne Zuordnung', (t) async {
      await as('superadmin@example.test');
      await expectDenied(
          () => db.collection('devices').doc(kOther).collection('manual').doc('2026').collection('data').get(),
          'Eintraege eines fremden Hauses');
      await expectDenied(() => household(kMon).get(), 'Haushalt eines fremden Hauses');
    });

    testWidgets('Protokoll: nur anlegen, als man selbst, nie aendern', (t) async {
      final s = await as('superadmin@example.test');
      final log = db.collection('admin_log');
      await expectDenied(
          () => log.add({
                'actor_uid': 'jemand-anders',
                'target_uid': reader,
                'after_read': [],
                'after_edit': [],
                'at': FieldValue.serverTimestamp(),
              }),
          'Eintrag im Namen anderer');
      final existing = (await log.get()).docs.first.reference;
      await expectDenied(() => existing.update({'after_read': []}), 'Eintrag aendern');
      await expectDenied(() => existing.delete(), 'Eintrag loeschen');
      expect(s, isNotEmpty);
    });
  });

  testWidgets('bestehende Regeln: manuelle Eintraege und Telemetrie', (t) async {
    await as('editor@example.test');
    final manual =
        db.collection('devices').doc(kMon).collection('manual').doc('2026').collection('data');
    await expectAllowed(() => manual.doc('a').set({'x': 1}), 'Eintrag mit Bearbeitungsrecht');
    final telemetry =
        db.collection('devices').doc(kMon).collection('telemetry').doc('2026').collection('11');
    await expectDenied(() => telemetry.doc('t').set({'x': 1}), 'Telemetrie schreiben');
    await as('reader@example.test');
    await expectAllowed(() => manual.get(), 'Eintraege lesen mit Leserecht');
    await expectDenied(() => manual.doc('b').set({'x': 1}), 'Eintrag ohne Bearbeitungsrecht');
    // Konto nur mit Sandbox (aus dem Registrierungs-Test).
    await as('neu@example.test');
    await expectDenied(() => manual.get(), 'Eintraege lesen ohne Zugriff');
    await expectDenied(() => telemetry.get(), 'Telemetrie lesen ohne Zugriff');
  });
}
