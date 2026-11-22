import 'dart:js_interop';

@JS('hideLoadingSplash')
external void _hideLoadingSplash();

/// Ruft hideLoadingSplash() aus web/index.html auf. Fehlt die Funktion
/// (z.B. in Tests), passiert nichts.
void hideWebSplash() {
  try {
    _hideLoadingSplash();
  } catch (_) {
    // Kein Startbildschirm vorhanden.
  }
}
