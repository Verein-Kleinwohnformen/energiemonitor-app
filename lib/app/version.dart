/// Version fuer "Impressum und Version". Mit `version:` in pubspec.yaml
/// zusammen nachfuehren. Ein Test prueft, dass beide gleich sind.
const kAppVersion = '2.0.0';

/// Kanal des Builds, z.B. "v2" fuer eine Testversion:
/// flutter build web --dart-define=APP_CHANNEL=v2
const kAppChannel = String.fromEnvironment('APP_CHANNEL');
