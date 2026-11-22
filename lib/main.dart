import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'admin/access.dart';
import 'app/app.dart';
import 'app/firestore_services.dart';
import 'app/services.dart';
import 'app/session.dart';
import 'firebase_options.dart';
import 'platform/emulator_reset.dart';

/// Lokal gegen den Firebase-Emulator laufen:
///   flutter run -d chrome --dart-define=USE_EMULATOR=true
/// Dann verbindet sich die App mit dem Demo-Projekt und nie mit der
/// produktiven Datenbank. Testdaten: node tool/seed_emulator.mjs
/// Lokal meldet man sich nach jedem Neuladen neu an (siehe emulator_reset).
const kUseEmulator = bool.fromEnvironment('USE_EMULATOR');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  await initializeDateFormatting('de_CH');
  await initializeDateFormatting('de');

  if (kUseEmulator) {
    await forgetStoredLogin();
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'demo-api-key',
        appId: '1:1234567890:web:demo',
        messagingSenderId: '1234567890',
        projectId: 'demo-energiemonitor',
      ),
    );
    FirebaseFirestore.instance.useFirestoreEmulator('127.0.0.1', 8080);
    await FirebaseAuth.instance.useAuthEmulator('127.0.0.1', 9099);
  } else {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }

  final session = AppSession(FirebaseSessionBackend());
  final entries = FirestoreManualEntries();
  final status = FirestoreStatus();
  final household = FirestoreHousehold(uid: () => session.uid ?? 'unbekannt');
  // Bei Abmelden in einem anderen Tab die Session neu laden.
  FirebaseAuth.instance.authStateChanges().skip(1).listen((_) => session.load());
  session.load();

  runApp(EnergiemonitorApp(
    session: session,
    services: (child) => AppServices(
      entries: entries,
      status: status,
      household: household,
      admin: FirestoreAdmin(),
      child: child,
    ),
  ));
}
