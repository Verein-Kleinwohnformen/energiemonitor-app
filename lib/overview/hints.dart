// Hinweise auf der Uebersicht: hoechstens zwei, nur wenn etwas zu tun ist
// (Konzept 01_navigation_ux.md, 5.1, Punkt 4). Rein und getestet.
import '../app/services.dart';
import '../capture/capture_logic.dart';
import '../charts/chart_basics.dart';
import '../daily/daily_values.dart';
import '../daily/period.dart';

enum HintTarget { capture, schema, none }

class OverviewHint {
  const OverviewHint(this.text, {this.target = HintTarget.none, this.action});
  final String text;
  final HintTarget target;
  final String? action;
}

/// Tage ohne Eintrag, ab denen ein Vorrat erwaehnt wird.
/// TODO(prüfen): Schwelle mit dem Team (Konzept nennt "64 Tage" als Beispiel).
const kStaleStockDays = 60;

/// Aussentemperatur, ab der der Sensor vermutlich in der Sonne steht.
const kOutdoorImplausible = 40.0;

/// CO2 in der Nacht, ab dem Lueften empfohlen wird.
const kNightCo2 = 2000.0;

List<OverviewHint> overviewHints({
  required List<ManualEntry> entries,
  required List<DailyValues> days,
  required DateTime now,
}) {
  final hints = <OverviewHint>[];
  final today = dayOf(now);

  // Vorrat lange nicht nachgefuehrt, aeltester zuerst.
  final stale = [
    for (final s in stocksOf(entries))
      if (today.difference(dayOf(s.date)).inDays > kStaleStockDays) s,
  ]..sort((a, b) => a.date.compareTo(b.date));
  if (stale.isNotEmpty) {
    final s = stale.first;
    final n = today.difference(dayOf(s.date)).inDays;
    hints.add(OverviewHint(
      'Seit $n Tagen kein Eintrag für ${s.kind.label}. Noch etwas da? Mit einem Abgleich '
      'wird die Schätzung genauer.',
      target: HintTarget.capture,
      action: 'Zu Erfassen',
    ));
  }

  final recent = [...days]..sort((a, b) => b.date.compareTo(a.date));
  final week = recent.where((d) => today.difference(d.date).inDays < 7);

  // Aussensensor unplausibel warm.
  final hot = week
      .map((d) => d.climate['t_out_max'])
      .whereType<double>()
      .where((t) => t > kOutdoorImplausible);
  if (hot.isNotEmpty) {
    final t = hot.reduce((a, b) => a > b ? a : b);
    hints.add(OverviewHint(
      'Der Aussensensor meldet ${fmtNum(t, digits: 0)} °C. Steht er in der Sonne?',
      target: HintTarget.schema,
      action: 'Zum Mess-Schema',
    ));
  }

  // CO2 in der letzten Nacht (0 bis 6 Uhr des juengsten Tages mit Werten).
  for (final d in recent) {
    final co2 = d.hourlyClimate['co2'];
    if (co2 == null) continue;
    final night = [for (var h = 0; h < 6 && h < co2.length; h++) ?co2[h]];
    if (night.isEmpty) continue;
    if (today.difference(d.date).inDays <= 1) {
      final max = night.reduce((a, b) => a > b ? a : b);
      if (max > kNightCo2) {
        hints.add(OverviewHint(
            'Letzte Nacht stieg das CO2 bis ${fmtNum(max, digits: 0)} ppm. Lüften lohnt sich.'));
      }
    }
    break;
  }

  return hints.take(2).toList();
}
