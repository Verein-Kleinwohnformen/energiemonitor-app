import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Vor dem Verbinden mit dem Emulator aufrufen (nur lokal, USE_EMULATOR).
/// Die produktive App ruft das nie auf.
///
/// Zwei Eigenheiten von Firebase im Browser verhindern sonst, dass sich die
/// App nach einem Neuladen wieder mit dem Auth-Emulator verbindet:
/// 1. Eine gespeicherte Anmeldung wird beim Start wiederhergestellt, bevor
///    die App auf den Emulator umschalten kann. Danach ist das Umschalten
///    nicht mehr erlaubt.
/// 2. FlutterFire merkt sich im sessionStorage, dass der Emulator schon
///    verbunden ist (gedacht fuer Hot Restart), und verbindet nicht neu.
/// Darum werden beide Spuren geloescht. Lokal meldet man sich nach jedem
/// Neuladen neu an.
Future<void> forgetStoredLogin() async {
  final storage = web.window.sessionStorage;
  for (var i = storage.length - 1; i >= 0; i--) {
    final key = storage.key(i);
    if (key != null && key.endsWith('-firebaseEmulatorOrigin')) storage.removeItem(key);
  }
  final done = Completer<void>();
  final request = web.window.indexedDB.deleteDatabase('firebaseLocalStorageDb');
  void finish(web.Event _) {
    if (!done.isCompleted) done.complete();
  }

  request.onsuccess = finish.toJS;
  request.onerror = finish.toJS;
  request.onblocked = finish.toJS;
  await done.future.timeout(const Duration(seconds: 3), onTimeout: () {});
}
