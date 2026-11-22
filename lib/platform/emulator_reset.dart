// Nur fuer den lokalen Emulator-Betrieb (--dart-define=USE_EMULATOR=true).
export 'emulator_reset_stub.dart' if (dart.library.js_interop) 'emulator_reset_web.dart';
