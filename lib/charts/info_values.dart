// Werte fuer die Platzhalter der Infotexte und Teil 5 "Stand".
import 'package:intl/intl.dart';

import '../daily/factors.dart';
import '../daily/summary.dart';
import 'chart_basics.dart';

final _stand = DateFormat('d.M.yyyy, HH:mm');

String standText(DateTime? dataUntil) =>
    dataUntil == null ? 'Noch keine Tageswerte.' : 'Daten bis ${_stand.format(dataUntil)}.';

/// Platzhalter aller Infotexte der Uebersicht und Auswertung.
Map<String, String> infoValues(PeriodSummary s, EnergyFactors f) {
  String list(Map<String, double> m, {String suffix = ''}) => [
        if (m['electricity'] != null) 'Strom ${fmtNum(m['electricity']!, digits: 2)}$suffix',
        for (final e in m.entries)
          if (kFuelLabels[e.key] != null) '${kFuelLabels[e.key]} ${fmtNum(e.value, digits: 2)}',
      ].join(', ');
  final unknown = [for (final t in s.unknownFuels) kFuelLabels[t] ?? t];
  final pellets = s.fuels['pellets'] ?? s.fuels['woodKg'];
  final perFire = pellets != null && pellets.fires > 0 && pellets.quantity > 0
      ? fmtNum(pellets.quantity / pellets.fires, digits: 1)
      : '–';
  return {
    'messpunkte': s.points.isEmpty ? 'noch keine' : (s.points.toList()..sort()).join(', '),
    'heizwerte': f.heatingValues.isEmpty ? 'Heizwerte fehlen noch' : f.heatingValuesText(kFuelLabels),
    'personen': s.personsNow?.toString() ?? 'den',
    'gewichtung': f.weighting.isEmpty ? 'Faktoren fehlen noch' : list(f.weighting),
    'einspeisung':
        f.pvFeedInCredit == null ? 'einem noch offenen Anteil' : fmtPct(f.pvFeedInCredit!),
    'faktoren': f.primaryEnergy.isEmpty ? 'Faktoren fehlen noch' : list(f.primaryEnergy),
    'nicht_berechenbar': unknown.isEmpty ? 'Nichts' : unknown.join(', '),
    'kg_pro_feuer': perFire,
    'anzahl_feuer': '${s.fires}',
  };
}
