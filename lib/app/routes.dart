// Pfade der App. Im Studienmodus fuehren Links auf auswertende Seiten zurueck
// zu Erfassen (Konzept Umsetzung, Abschnitt 5, Studienmodus).
abstract final class Routes {
  static const login = '/anmelden';
  static const overview = '/uebersicht';
  static const analysis = '/auswertung';
  static const capture = '/erfassen';
  static const captureForm = '/erfassen/neu';
  static const more = '/mehr';
  static const systemStatus = '/mehr/systemstatus';
  static const monitorSwitch = '/mehr/monitor';
  static const household = '/mehr/haushalt';
  static const measurements = '/mehr/messwerte';
  static const export = '/mehr/download';
  static const study = '/mehr/energiestudie';
  static const about = '/mehr/ueber';
  static const method = '/mehr/so-rechnen-wir';
  static const onboarding = '/willkommen';
  static const admin = '/verwaltung';

  /// Seiten, die im Studienmodus nicht erscheinen, weil sie Verbrauch zeigen.
  static const hiddenInStudy = [overview, analysis, measurements, export, method];

  static bool isHiddenInStudy(String location) =>
      hiddenInStudy.any((p) => location == p || location.startsWith('$p/'));
}
