// Erfundene, aber plausible Tageswerte fuer Widget- und Golden-Tests
// (Beispieldaten, keine Messwerte). Jahresgang mit Sonne im Sommer, Heizung
// und Pelletofen im Winter, Netatmo-Klima und einzelnen lueckenhaften Tagen.
import 'dart:math' as math;

import 'package:kwf_energiemonitor/daily/daily_values.dart';
import 'package:kwf_energiemonitor/daily/factors.dart';

double _r(double v, [int d = 3]) => (v * math.pow(10, d)).round() / math.pow(10, d);

/// Tageswerte von [from] bis [to] (inklusive). [to] ist "heute" und darum
/// unvollstaendig, wenn [partialUntil] gesetzt ist.
List<DailyValues> sampleDays(DateTime from, DateTime to,
    {DateTime? partialUntil, bool climate = true}) {
  final out = <DailyValues>[];
  for (var d = DateTime(from.year, from.month, from.day);
      !d.isAfter(to);
      d = DateTime(d.year, d.month, d.day + 1)) {
    final doy = d.difference(DateTime(d.year)).inDays;
    final i = d.difference(DateTime(2025)).inDays;
    // 1 im Januar, -1 im Juli
    final season = math.cos(2 * math.pi * (doy - 15) / 365);
    final noise = math.sin(i * 1.7);
    final pv = math.max(0.2, 2.8 - 1.8 * season + 0.8 * noise);
    final i3 = 2.1 + 0.3 * math.sin(i * 0.9);
    const a1 = 0.08;
    final i2 = season > 0.3 ? _r(1.6 * season + 0.3 * noise) : 0.0;
    final need = i2 + i3 + a1 + 0.3;
    final feed = math.max(0.0, pv - need) * 0.7;
    final grid = math.max(0.0, need - (pv - feed));
    final occupied = i % 9 != 0;
    final gappy = i % 23 == 0;
    final today = d.year == to.year && d.month == to.month && d.day == to.day;
    final partial = today && partialUntil != null;

    final tIn = 21.6 - 1.4 * season + 0.6 * noise;
    final hourlyT = [
      for (var h = 0; h < 24; h++) _r(tIn + 1.6 * math.sin((h - 9) / 24 * 2 * math.pi), 1),
    ];
    final hourlyCo2 = [
      for (var h = 0; h < 24; h++)
        occupied ? (h >= 22 || h < 7 ? 1250 + 250 * season : 700.0 + 50 * noise) : 520.0,
    ];
    final hot = season < -0.75 ? _r(2.5 - 2 * season + noise, 1) : 0.0;
    final fire = climate && season > 0.35 && occupied;
    final provisional = to.difference(d).inDays < 20;
    final pelletsKg = fire ? _r(1.1 + 0.6 * season) : 0.0;
    final propaneKg = occupied ? 0.07 : 0.0;

    out.add(DailyValues(
      date: d,
      energyKwh: {
        'E1': _r(grid),
        'E2': _r(feed),
        'E3': _r(pv),
        'I2': i2,
        'I3': _r(i3),
        'A1': a1,
      },
      availability: {
        'E1': gappy ? 0.82 : 1.0,
        'E3': gappy ? 0.82 : 1.0,
        if (climate) 'K1': 0.98,
      },
      climate: climate
          ? {
              't_in_median': _r(tIn, 1),
              't_in_p05': _r(tIn - 2, 1),
              't_in_p95': _r(tIn + 2.4, 1),
              'rh_in_median': _r(48 + 6 * season + 3 * noise, 0),
              'co2_median': _r(occupied ? 880 + 200 * season : 520, 0),
              't_out_mean': _r(10 - 9 * season, 1),
              't_out_max': _r(15 - 10 * season, 1),
              'hours_over_28': hot,
              't_in_mean_08_20': _r(tIn + 0.8, 1),
            }
          : const {},
      hourlyClimate: climate ? {'t_in': hourlyT, 'co2': hourlyCo2} : const {},
      climateSource: climate ? 'netatmo' : null,
      occupied: climate ? occupied : null,
      occupancySource: climate ? 'sensirion_scd4x' : null,
      fireEvents: fire
          ? const [FireEvent(start: '06:00', end: '10:20', riseKPerH: 6.1, weight: 4.33)]
          : const [],
      manualAlloc: {
        'pellets': FuelAllocation(
          quantity: climate ? pelletsKg : _r(0.6 * math.max(0, season)),
          unit: 'kg',
          method: climate ? 'ofensignatur' : 'gleichmaessig',
          provisional: provisional,
          incomplete: false,
          fires: fire ? 1 : 0,
          byMeteringPoint: {'M2': climate ? pelletsKg : _r(0.6 * math.max(0, season))},
        ),
        'propane': FuelAllocation(
          quantity: propaneKg,
          unit: 'kg',
          method: 'bewohnte_tage',
          provisional: provisional,
          incomplete: false,
          byMeteringPoint: {'M1': propaneKg},
        ),
      },
      manualKwhEstimated: {
        'pellets': _r((climate ? pelletsKg : 0.6 * math.max(0, season)) * 5),
        'propane': _r(propaneKg * 12.861),
      },
      partial: partial,
      dataUntil: partial ? partialUntil : DateTime(d.year, d.month, d.day, 23, 59),
    ));
  }
  return out;
}

/// Faktoren wie in /config/factors (oeffentliche Quellen), plus Vergleichswerte.
final kSampleFactors = EnergyFactors.fromMap({
  'heating_values': {
    'pellets': {'value': 5.0, 'unit': 'kWh/kg', 'source': 'LWF Merkblatt 12'},
    'propane': {'value': 12.861, 'unit': 'kWh/kg', 'source': 'BAFU Faktenblatt'},
    'woodKg': {'value': 4.235, 'unit': 'kWh/kg'},
    'woodSter': {'value': 1627.5, 'unit': 'kWh/Ster'},
  },
  'weighting_factors': {
    'electricity': 2.0,
    'pellets': 0.5,
    'woodKg': 0.5,
    'woodSter': 0.5,
    'propane': 1.0,
    'oil': 1.0,
    'pv_self_consumption_credit': 1.0,
    'pv_feed_in_credit': 0.4,
    'source': 'Minergie Produktreglement 2026.1',
  },
  'primary_energy_factors': {
    'electricity': {'total': 2.65},
    'pellets': {'total': 1.18},
    'propane': {'total': 1.22},
    'woodKg': {'total': 1.05},
    'woodSter': {'total': 1.05},
    'source': 'KBOB 2022 V9.0',
  },
  'benchmarks': {
    'target_2000w': {
      'label': '2000-Watt-Ziel',
      'value': 420,
      'method': '2000watt',
      'source': 'Zielwert, Bereich Wohnen'
    },
    'ch_today': {
      'label': 'Schweiz heute',
      'value': 1300,
      'method': '2000watt',
      'source': 'Durchschnitt, Bereich Wohnen'
    },
  },
});

class FakeDaily implements DailyRepository {
  FakeDaily(this.days);
  final List<DailyValues> days;

  @override
  Future<List<DailyValues>> load(String monitorId, DateTime from, DateTime to) async => [
        for (final d in days)
          if (!d.date.isBefore(DateTime(from.year, from.month, from.day)) &&
              !d.date.isAfter(DateTime(to.year, to.month, to.day)))
            d,
      ];
}

class FakeFactors implements FactorsRepository {
  FakeFactors([EnergyFactors? f]) : factors = f ?? kSampleFactors;
  final EnergyFactors factors;
  @override
  Future<EnergyFactors> load() async => factors;
}

