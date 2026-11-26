import 'package:flutter_test/flutter_test.dart';
import 'package:kwf_energiemonitor/daily/daily_values.dart';

void main() {
  // Ausschnitt eines Dokuments, wie es die energiemonitor-api schreibt (Beispieldaten).
  final doc = <String, dynamic>{
    'date': '2026-05-15',
    'timezone': 'Europe/Zurich',
    'energy_kwh': {'E1': 0.0, 'E3': 3.4, 'I2': 0, 'I3': 2.3},
    'energy_sensor': {'E1': 'victron'},
    'hourly_kwh': {
      'E3': [0, 0, 0, 0, 0, 0.05, 0.2, 0.4, 0.5, 0.6, 0.5, 0.4, 0.3, 0.2, 0.15, 0.1, 0, 0, 0, 0, 0, 0, 0, 0]
    },
    'availability': {'E1': 1.0, 'K1': 0.98},
    'climate': {'t_in_median': 21.4, 'co2_max': 1420, 'hours_over_28': 0, 't_out_mean': null},
    'climate_source': 'netatmo',
    'hourly_climate': {
      'co2': [for (var h = 0; h < 24; h++) h == 3 ? null : 600 + h],
      't_in': [for (var h = 0; h < 24; h++) 20.5],
    },
    'co2_peak': 1420,
    'co2_rise': 610,
    'fire_source': 'netatmo',
    'computed_at': '2026-05-16T01:30:00+00:00',
    'occupied': true,
    'occupancy_source': 'sensirion_scd4x',
    'fire_events': [
      {'start': '20:20', 'end': '03:00', 'start_ts': 1, 'end_ts': 2, 'rise_k_per_h': 8.6, 'weight': 6.67}
    ],
    'manual_alloc': {
      'pellets': {
        'quantity': 2.079,
        'unit': 'kg',
        'method': 'ofensignatur',
        'provisional': false,
        'incomplete': false,
        'fires': 1,
        'by_metering_point': {'M2': 2.079}
      },
      'propane': {
        'quantity': null,
        'unit': 'kg',
        'method': 'bewohnte_tage',
        'provisional': true,
        'incomplete': true,
        'by_metering_point': {'M1': null}
      },
    },
    'manual_kwh_estimated': {'pellets': 9.98},
    'partial': false,
    'data_until': 1778882390000,
    'version': 1,
  };

  test('Tagesdokument lesen', () {
    final d = DailyValues.fromFirestore('2026-05-15', doc)!;
    expect(d.date, DateTime(2026, 5, 15));
    expect(d.energyKwh, {'E1': 0.0, 'E3': 3.4, 'I2': 0.0, 'I3': 2.3});
    expect(d.hourlyKwh['E3'], hasLength(24));
    expect(d.availability['K1'], 0.98);
    expect(d.climate['co2_max'], 1420);
    expect(d.climate.containsKey('t_out_mean'), isTrue);
    expect(d.climate['t_out_mean'], isNull);
    expect(d.occupied, isTrue);
    expect(d.hourlyClimate['co2']![3], isNull);
    expect(d.hourlyClimate['co2']![4], 604);
    expect(d.hourlyClimate['t_in'], hasLength(24));
    expect((d.co2Peak, d.co2Rise, d.fireSource), (1420, 610, 'netatmo'));
    expect(d.energySensor, {'E1': 'victron'});
    expect(d.computedAt, DateTime.utc(2026, 5, 16, 1, 30));
    expect(d.fireEvents.single.start, '20:20');
    expect(d.fireEvents.single.weight, 6.67);
    final p = d.manualAlloc['pellets']!;
    expect((p.quantity, p.method, p.provisional, p.fires), (2.079, 'ofensignatur', false, 1));
    final g = d.manualAlloc['propane']!;
    expect(g.quantity, isNull);
    expect(g.incomplete, isTrue);
    expect(g.byMeteringPoint, {'M1': null});
    expect(d.manualKwhEstimated['pellets'], 9.98);
    expect(d.dataUntil, DateTime.fromMillisecondsSinceEpoch(1778882390000));
    expect(d.version, 1);
  });

  test('leeres oder kaputtes Dokument', () {
    final d = DailyValues.fromFirestore('2026-05-16', {})!;
    expect(d.date, DateTime(2026, 5, 16));
    expect(d.energyKwh, isEmpty);
    expect(d.occupied, isNull);
    expect(DailyValues.fromFirestore('kein-datum', {}), isNull);
    expect(DailyValues.keyOf(DateTime(2026, 1, 2)), '2026-01-02');
  });

  group('DailyDayCache', () {
    DailyValues day(DateTime d) => DailyValues.fromFirestore(DailyValues.keyOf(d), const {})!;

    test('liest nur fehlende Tage, auch Tage ohne Dokument zaehlen als gelesen', () async {
      final calls = <(DateTime, DateTime)>[];
      var clock = DateTime(2026, 11, 26, 12);
      final cache = DailyDayCache((id, from, to) async {
        calls.add((from, to));
        return [
          for (var d = from; !d.isAfter(to); d = DateTime(d.year, d.month, d.day + 1))
            if (d.day != 22) day(d), // am 22. gibt es kein Dokument
        ];
      }, now: () => clock);

      final week = await cache.load('m', DateTime(2026, 11, 20), DateTime(2026, 11, 26));
      expect(week, hasLength(6));
      expect(calls, [(DateTime(2026, 11, 20), DateTime(2026, 11, 26))]);

      // Monat: nur 1. bis 19. fehlt
      final month = await cache.load('m', DateTime(2026, 11, 1), DateTime(2026, 11, 26));
      expect(month, hasLength(25));
      expect(calls.last, (DateTime(2026, 11, 1), DateTime(2026, 11, 19)));

      // Woche nochmals: nichts lesen
      await cache.load('m', DateTime(2026, 11, 20), DateTime(2026, 11, 26));
      expect(calls, hasLength(2));

      // Nach 10 Minuten wieder lesen
      clock = clock.add(const Duration(minutes: 11));
      await cache.load('m', DateTime(2026, 11, 24), DateTime(2026, 11, 26));
      expect(calls.last, (DateTime(2026, 11, 24), DateTime(2026, 11, 26)));
    });

    test('gleichzeitige Abfragen lesen nicht doppelt', () async {
      var n = 0;
      final cache = DailyDayCache((id, from, to) async {
        n++;
        await Future<void>.delayed(const Duration(milliseconds: 5));
        return [day(from)];
      });
      await Future.wait([
        cache.load('m', DateTime(2026, 11, 26), DateTime(2026, 11, 26)),
        cache.load('m', DateTime(2026, 11, 26), DateTime(2026, 11, 26)),
      ]);
      expect(n, 1);
    });
  });
}
