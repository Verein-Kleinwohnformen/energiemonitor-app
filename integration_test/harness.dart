// Gemeinsamer Rahmen fuer Integrationstests gegen den Firebase-Emulator.
//
// Die Tests laufen in einer echten Flutter-Web-App (flutter run -d web-server),
// gesteuert von tool/run_web_tests.mjs. Die Projekt-ID beginnt mit "demo-",
// damit sich die App nur mit dem Emulator verbinden kann und nie mit einem
// echten Firebase-Projekt.
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/common.dart';
import 'package:integration_test/integration_test.dart';

const kDemoProjectId = 'demo-energiemonitor';
const kResultMarker = 'INTEGRATION_RESULT ';
// Eigene Ports fuer Tests (firebase.test.json), damit ein laufender
// Dev-Emulator auf 8080/9099 nicht stoert.
const kFirestoreHost = '127.0.0.1:8180';
const kAuthHost = '127.0.0.1:9199';

bool _initialized = false;

/// Startet Firebase gegen den lokalen Emulator.
Future<void> initEmulatorFirebase() async {
  if (_initialized) return;
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: 'demo-api-key',
      appId: '1:1234567890:web:demo',
      messagingSenderId: '1234567890',
      projectId: kDemoProjectId,
    ),
  );
  FirebaseFirestore.instance.useFirestoreEmulator('127.0.0.1', 8180);
  await FirebaseAuth.instance.useAuthEmulator('127.0.0.1', 9199);
  _initialized = true;
}

/// Bindet den Integrationstest-Rahmen ein und meldet am Ende das Ergebnis
/// als eine Zeile in der Browser-Konsole, die das Node-Skript auswertet.
IntegrationTestWidgetsFlutterBinding setUpIntegrationReporting() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  tearDownAll(() {
    final results = <String, String>{};
    binding.results.forEach((name, result) {
      results[name] =
          result is Failure ? 'failure: ${result.details}' : 'success';
    });
    // ignore: avoid_print
    print('$kResultMarker${jsonEncode(results)}');
  });
  return binding;
}

/// Zugriff auf den Emulator an den Rules vorbei ("Bearer owner").
/// Nur fuer Testvorbereitung: Datenbank leeren, User- und Monitor-Dokumente
/// anlegen, die eine App selbst nie schreiben darf.
class EmulatorAdmin {
  static const _owner = {'Authorization': 'Bearer owner'};
  static String get _docsBase =>
      'http://$kFirestoreHost/v1/projects/$kDemoProjectId/databases/(default)/documents';

  static Future<void> resetAll() async {
    await FirebaseAuth.instance.signOut();
    final fs = await http.delete(Uri.parse(
        'http://$kFirestoreHost/emulator/v1/projects/$kDemoProjectId/databases/(default)/documents'));
    final au = await http.delete(Uri.parse(
        'http://$kAuthHost/emulator/v1/projects/$kDemoProjectId/accounts'));
    if (fs.statusCode != 200 || au.statusCode != 200) {
      throw StateError('Emulator-Reset fehlgeschlagen: ${fs.statusCode} / ${au.statusCode}');
    }
  }

  /// Schreibt ein Dokument mit Owner-Rechten. [path] ohne fuehrenden Slash.
  static Future<void> setDoc(String path, Map<String, Object?> data) async {
    final res = await http.patch(
      Uri.parse('$_docsBase/$path'),
      headers: {..._owner, 'Content-Type': 'application/json'},
      body: jsonEncode({'fields': data.map((k, v) => MapEntry(k, _toValue(v)))}),
    );
    if (res.statusCode != 200) {
      throw StateError('setDoc $path: ${res.statusCode} ${res.body}');
    }
  }

  /// Setzt Custom Claims eines Kontos im Auth-Emulator (wie das Admin SDK).
  static Future<void> setClaims(String uid, Map<String, Object?> claims) async {
    final res = await http.post(
      Uri.parse('http://$kAuthHost/identitytoolkit.googleapis.com/v1/projects/$kDemoProjectId/accounts:update'),
      headers: {..._owner, 'Content-Type': 'application/json'},
      body: jsonEncode({'localId': uid, 'customAttributes': jsonEncode(claims)}),
    );
    if (res.statusCode != 200) {
      throw StateError('setClaims $uid: ${res.statusCode} ${res.body}');
    }
  }

  static Map<String, Object?> _toValue(Object? v) {
    if (v == null) return {'nullValue': null};
    if (v is bool) return {'booleanValue': v};
    if (v is int) return {'integerValue': '$v'};
    if (v is double) return {'doubleValue': v};
    if (v is String) return {'stringValue': v};
    if (v is List) return {'arrayValue': {'values': v.map(_toValue).toList()}};
    if (v is Map) {
      return {
        'mapValue': {
          'fields': v.map((k, val) => MapEntry(k as String, _toValue(val)))
        }
      };
    }
    throw ArgumentError('Typ nicht unterstuetzt: ${v.runtimeType}');
  }
}

/// Legt einen Test-User im Auth-Emulator an und meldet ihn an.
/// Die Zugangsdaten gelten nur im Emulator.
Future<String> signInTestUser({
  required String email,
  required List<String> monitorRead,
  required List<String> monitorEdit,
}) async {
  final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email, password: 'emulator-only-123');
  final uid = cred.user!.uid;
  await EmulatorAdmin.setDoc('users/$uid', {
    'user_id': uid,
    'email': email,
    'monitor_read': monitorRead,
    'monitor_edit': monitorEdit,
    'monitor_api_keys': <String, Object?>{},
  });
  return uid;
}

/// Pumpt, bis [condition] erfuellt ist (echte Zeit, Firestore antwortet asynchron).
Future<void> pumpUntil(WidgetTester tester, bool Function() condition,
    {Duration timeout = const Duration(seconds: 20),
    String what = 'Bedingung'}) async {
  final end = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(end)) {
      throw TestFailure('Zeitlimit: $what');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Wartet echte Zeit ab, ohne Frames zu verpassen.
Future<void> settle(WidgetTester tester,
    [Duration d = const Duration(milliseconds: 600)]) async {
  final end = DateTime.now().add(d);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Liest den ganzen Zustand eines Monitors (manuelle Eintraege und
/// Messpunkt-Metadaten) und macht ihn vergleichbar: ohne Dokument-ID und
/// ohne `created_at`, sortiert.
Future<List<String>> readMonitorState(String deviceId,
    {List<int> years = const [2024, 2025, 2026, 2027]}) async {
  final db = FirebaseFirestore.instance;
  final out = <String>[];
  for (final year in years) {
    final snap = await db
        .collection('devices')
        .doc(deviceId)
        .collection('manual')
        .doc('$year')
        .collection('data')
        .get();
    for (final doc in snap.docs) {
      final data = Map<String, dynamic>.from(doc.data())..remove('created_at');
      out.add('manual/$year ${_canonical(data)}');
    }
  }
  final mps = await db
      .collection('devices')
      .doc(deviceId)
      .collection('metering_points')
      .get();
  for (final doc in mps.docs) {
    out.add('metering_points/${doc.id} ${_canonical(doc.data())}');
  }
  out.sort();
  return out;
}

String _canonical(Object? v) {
  if (v is Map) {
    final keys = v.keys.map((k) => '$k').toList()..sort();
    return '{${keys.map((k) => '"$k":${_canonical(v[k])}').join(',')}}';
  }
  if (v is List) return '[${v.map(_canonical).join(',')}]';
  return jsonEncode(v);
}

/// Kleines Hilfs-Widget: startet eine Seite per Navigator, damit ein
/// Formular wie in der App mit pop() zurueckkehren kann.
class RouteHost extends StatelessWidget {
  const RouteHost({super.key, required this.builder});
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        key: const ValueKey('route-host-open'),
        onTap: () =>
            Navigator.of(context).push(PageRouteBuilder(
          pageBuilder: (c, _, __) => builder(c),
        )),
        child: const SizedBox(width: 200, height: 60, child: Text('Formular oeffnen')),
      ),
    );
  }
}

/// Alle manuellen Eintraege eines Monitors als rohe Dokumente.
Future<List<Map<String, dynamic>>> readManualEntries(String deviceId,
    {List<int> years = const [2024, 2025, 2026, 2027]}) async {
  final db = FirebaseFirestore.instance;
  final out = <Map<String, dynamic>>[];
  for (final year in years) {
    final snap = await db
        .collection('devices')
        .doc(deviceId)
        .collection('manual')
        .doc('$year')
        .collection('data')
        .get();
    out.addAll(snap.docs.map((d) => d.data()));
  }
  return out;
}
