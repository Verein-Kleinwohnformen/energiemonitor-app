// Zusammenfassung ueber einen Zeitraum, jede Zahl von Hand nachgerechnet.
// Faktoren sind Beispielwerte, nicht die produktiven.
import 'package:flutter_test/flutter_test.dart';
import 'package:kwf_energiemonitor/daily/daily_values.dart';
import 'package:kwf_energiemonitor/daily/factors.dart';
import 'package:kwf_energiemonitor/daily/period.dart';
import 'package:kwf_energiemonitor/daily/summary.dart';
import 'package:kwf_energiemonitor/household/household.dart';

final factors = EnergyFactors.fromMap({
  'heating_values': {
    'pellets': {'value': 5.0, 'unit': 'kWh/kg', 'source': 'Beispiel'},
    'propane': {'value': 12.0, 'unit': 'kWh/kg'},
  },
  'weighting_factors': {
    'electricity': 2.0,
    'pellets': 0.5,
    'propane': 1.0,
    'pv_self_consumption_credit': 1.0,
    'pv_feed_in_credit': 0.4,
  },
  'primary_energy_factors': {
    'electricity': {'total': 2.5},
    'pellets': {'total': 1.2},
    'propane': {'total': 1.2},
  },
  'benchmarks': {
    'ch': {'label': 'Schweiz heute', 'value': 1300, 'method': '2000watt'},
    'target': {'label': '2000-Watt-Ziel', 'value': 420, 'method': '2000watt'},
  },
});

DailyValues day(DateTime d,
    {Map<String, double> e = const {},
    Map<String, double> avail = const {},
    Map<String, double?> climate = const {},
    Map<String, List<double?>> hourly = const {},
    bool? occupied,
    Map<String, FuelAllocation> fuel = const {},
    Map<String, double> fuelKwh = const {},
    bool partial = false,
    DateTime? until}) =>
    DailyValues(
      date: d,
      energyKwh: e,
      availability: avail,
      climate: climate,
      hourlyClimate: hourly,
      occupied: occupied,
      manualAlloc: fuel,
      manualKwhEstimated: fuelKwh,
      partial: partial,
      dataUntil: until,
    );

FuelAllocation pellets(double? kg, {bool provisional = false, String mp = 'M2', int fires = 1}) =>
    FuelAllocation(
      quantity: kg,
      unit: 'kg',
      method: 'ofensignatur',
      provisional: provisional,
      incomplete: false,
      fires: fires,
      byMeteringPoint: {mp: kg},
    );

void main() {
  final today = DateTime(2026, 11, 21);
  final week = Period.of(RangeKind.week, DateTime(2026, 11, 9), today: today);
  final two = [HouseholdEntry(validFrom: DateTime(2026, 1, 1), persons: 2)];

  test('Strom, Eigenversorgung und Watt pro Person', () {
    final days = [
      // Mo: Netz 4, Sonne 3, davon 1 eingespeist -> selbst 2
      day(DateTime(2026, 11, 9), e: {'E1': 4, 'E2': 1, 'E3': 3, 'I2': 2, 'I3': 1}),
      // Di: nur Sonne
      day(DateTime(2026, 11, 10), e: {'E1': 0, 'E3': 2, 'I3': 2}),
      // ausserhalb
      day(DateTime(2026, 11, 16), e: {'E1': 100}),
    ];
    final s = PeriodSummary.of(period: week, days: days, household: two, factors: factors);
    expect(s.daysWithData, 2);
    expect(s.missingDays, 5);
    expect((s.gridKwh, s.feedInKwh, s.pvKwh, s.pvSelfKwh), (4.0, 1.0, 5.0, 4.0));
    expect(s.totalKwh, 8);
    expect(s.autarky, 0.5);
    expect(s.selfConsumption, 0.8);
    // Heizen: I2 2 kWh am Montag, Eigenversorgung Montag 2 / 6 = 1/3
    expect(s.heatElectricKwh, 2);
    expect(s.heatSolarKwh, closeTo(2 / 3, 1e-9));
    // 2 Personen x 48 h = 96 Personen-Stunden
    expect(s.personHours, 96);
    // Minergie: 2*(4+4) - 2*4*1.0 - 2*1*0.4 = 16 - 8 - 0.8 = 7.2 kWh
    expect(s.minergieKwh, closeTo(7.2, 1e-9));
    expect(s.wattsMinergie, closeTo(7200 / 96, 1e-9));
    // mit Solarstrom: 2*8 = 16 kWh
    expect(s.wattsMinergieWithPv, closeTo(16000 / 96, 1e-9));
    // 2000 Watt: Netz 4 * 2.5 = 10 kWh
    expect(s.watts2000, closeTo(10000 / 96, 1e-9));
    expect(s.kwhPerPersonDay, closeTo(8 / 4, 1e-9));
    expect(s.kwhByCarrier, {Carrier.solar: 4.0, Carrier.grid: 4.0});
  });

  test('Brennstoffe mit Heizwert, Gewichtung und Messpunkt', () {
    final days = [
      day(DateTime(2026, 11, 9),
          e: {'E1': 1},
          fuel: {'pellets': pellets(2)},
          fuelKwh: {'pellets': 10}),
      day(DateTime(2026, 11, 10),
          e: {'E1': 1},
          fuel: {
            'pellets': pellets(1, provisional: true),
            'propane': const FuelAllocation(
                quantity: 0.5,
                unit: 'kg',
                method: 'bewohnte_tage',
                provisional: true,
                incomplete: true,
                byMeteringPoint: {'M1': 0.5, 'M0': null}),
            'diesel': const FuelAllocation(
                quantity: 3, unit: 'Liter', method: 'gleichmaessig', provisional: false,
                incomplete: false),
          },
          fuelKwh: {'pellets': 5, 'propane': 6, 'diesel': 30}),
    ];
    final s = PeriodSummary.of(period: week, days: days, household: two, factors: factors);
    final p = s.fuels['pellets']!;
    expect((p.quantity, p.kwh, p.provisional, p.fires), (3.0, 15.0, true, 2));
    expect(p.byMp, {'M2': 15.0});
    expect(s.fuels['propane']!.byMp, {'M1': 6.0});
    expect(s.fuels['propane']!.incomplete, isTrue);
    // Diesel zaehlt nicht zum Wohnen
    expect(s.fuelKwh, 21);
    expect(s.totalKwh, 23);
    expect(s.heatFuelKwh, 15);
    expect(s.days[1].estimated, {Carrier.wood, Carrier.gas});
    // Minergie: 2*2 + 0.5*15 + 1*6 = 17.5
    expect(s.minergieKwh, closeTo(17.5, 1e-9));
    // 2000 Watt: 2*2.5 + 1.2*15 + 1.2*6 = 30.2
    expect(s.pe2000Kwh, closeTo(30.2, 1e-9));
    expect(s.kwhByCarrier, {Carrier.grid: 2.0, Carrier.gas: 6.0, Carrier.wood: 15.0});
  });

  test('Brennstoff noch nicht schaetzbar und fehlender Faktor', () {
    final days = [
      day(DateTime(2026, 11, 9), e: {'E1': 1}, fuel: {'pellets': pellets(null, fires: 2)}),
    ];
    final s = PeriodSummary.of(period: week, days: days, household: two, factors: factors);
    expect(s.unknownFuels, ['pellets']);
    expect(s.fuels['pellets']!.fires, 2);
    expect(s.fuelKwh, 0);

    final noFactors =
        PeriodSummary.of(period: week, days: days, household: two, factors: EnergyFactors.empty);
    expect(noFactors.wattsMinergie, isNull);
    expect(noFactors.watts2000, isNull);
    expect(noFactors.totalKwh, 1);
  });

  test('Personenwechsel mitten im Zeitraum und heute nur bis zum letzten Wert', () {
    final hh = [
      HouseholdEntry(validFrom: DateTime(2026, 1, 1), persons: 2),
      HouseholdEntry(validFrom: DateTime(2026, 11, 10), persons: 3),
    ];
    final p = Period.of(RangeKind.week, today, today: today);
    final days = [
      day(DateTime(2026, 11, 9), e: {'E1': 1}),
      day(DateTime(2026, 11, 16), e: {'E1': 1}),
      day(DateTime(2026, 11, 21),
          e: {'E1': 1}, partial: true, until: DateTime(2026, 11, 21, 12)),
    ];
    final s = PeriodSummary.of(period: p, days: days, household: hh, factors: factors);
    // 16.11. 3 x 24 + 21.11. 3 x 12 = 108
    expect(s.personHours, 108);
    expect(s.personsNow, 3);
    final none = PeriodSummary.of(period: p, days: days, household: const [], factors: factors);
    expect(none.householdMissing, isTrue);
    expect(none.wattsMinergie, isNull);
    expect(none.kwhPerPersonDay, isNull);

    // Vor dem ersten Haushalt-Eintrag gilt dieser auch rueckwirkend.
    final late = [HouseholdEntry(validFrom: DateTime(2026, 11, 17), persons: 1)];
    final week2 = [
      day(DateTime(2026, 11, 16), e: {'E1': 10}),
      day(DateTime(2026, 11, 17), e: {'E1': 2}),
    ];
    final part = PeriodSummary.of(
        period: Period.of(RangeKind.week, DateTime(2026, 11, 16), today: DateTime(2026, 11, 18)),
        days: week2,
        household: late,
        factors: factors);
    expect(part.daysWithoutPersons, 0);
    expect(part.daysPersonsAssumed, 1);
    expect(part.personHours, 48);
    expect(part.kwhPerPersonDay, 6);
    expect(part.wattsMinergie, closeTo(2 * 12 * 1000 / 48, 1e-9));
    expect(part.totalKwh, 12);
  });

  test('Klima, Komfortstunden, Belegung, Heatmap', () {
    List<double?> hours(double v) => List.filled(24, v);
    final days = [
      day(DateTime(2026, 11, 9),
          climate: {'t_in_median': 21, 'rh_in_median': 50, 'co2_median': 900, 'hours_over_28': 1},
          hourly: {'t_in': hours(21), 'co2': hours(800)},
          occupied: true),
      day(DateTime(2026, 11, 10),
          climate: {'t_in_median': 27, 'rh_in_median': 40, 'co2_median': 1200, 'hours_over_28': 2},
          hourly: {'t_in': hours(27), 'co2': hours(1200)},
          occupied: true),
      day(DateTime(2026, 11, 11),
          climate: {'t_in_median': 15, 'rh_in_median': 70, 'co2_median': 500},
          hourly: {'t_in': hours(15)},
          occupied: false),
      day(DateTime(2026, 11, 12), e: {'E1': 1}),
    ];
    final s = PeriodSummary.of(period: week, days: days, household: two, factors: factors);
    expect((s.occupiedDays, s.unknownOccupancyDays, s.climateDays), (2, 1, 3));
    // nur bewohnte Tage
    expect(s.tInMedian, 24);
    expect(s.rhMedian, 45);
    expect(s.co2Median, 1050);
    expect(s.comfortHoursShare, 0.5);
    expect(s.hoursOver28, 3);
    expect(s.scatter, hasLength(3));
    expect(s.co2Heatmap[0][0], 800);
    expect(s.co2Heatmap[1][23], 1200);
    expect(s.co2Heatmap[2][0], isNull);
    expect(s.co2Days, 2);
  });

  test('Heisseste Woche braucht 7 Tage am Stueck', () {
    final m = Period.of(RangeKind.month, DateTime(2026, 7), today: today);
    final days = [
      for (var i = 1; i <= 20; i++)
        day(DateTime(2026, 7, i), climate: {'t_in_mean_08_20': i == 4 ? null : 20.0 + i}),
    ];
    final s = PeriodSummary.of(period: m, days: days, household: two, factors: factors);
    expect(s.hottestWeek!.$1, DateTime(2026, 7, 14));
    expect(s.hottestWeek!.$2, closeTo(37, 1e-9));
  });

  test('Lueckenhafte Tage zaehlen, werden aber ausgewiesen', () {
    final days = [
      day(DateTime(2026, 11, 9), e: {'E1': 1}, avail: {'E1': 0.82, 'E3': 0.82}),
      day(DateTime(2026, 11, 10), e: {'E1': 1}, avail: {'E1': 1}),
    ];
    final s = PeriodSummary.of(period: week, days: days, household: two, factors: factors);
    expect((s.gappyDays, s.gridKwh, s.days.first.gappy), (1, 2.0, true));
  });

  test('Monate fuer die Jahresansicht', () {
    final y = Period.of(RangeKind.year, today, today: today);
    final days = [
      day(DateTime(2026, 10, 31), e: {'E1': 1, 'E3': 2}),
      day(DateTime(2026, 11, 1), e: {'E1': 3}),
      day(DateTime(2026, 11, 2), e: {'E1': 1, 'I2': 1}),
    ];
    final s = PeriodSummary.of(period: y, days: days, household: two, factors: factors);
    expect(s.months.map((m) => m.month), [DateTime(2026, 10), DateTime(2026, 11)]);
    expect(s.months.last.kwh[Carrier.grid], 4);
    expect(s.months.last.heatElectric, 1);
    expect(s.months.first.total, 3);
  });

  test('Faktoren lesen', () {
    expect(factors.heatingValues['pellets'], 5);
    expect(factors.weighting.containsKey('pv_feed_in_credit'), isFalse);
    expect(factors.pvFeedInCredit, 0.4);
    expect(factors.benchmarks.map((b) => b.watts), [420, 1300]);
    expect(factors.heatingValuesText(kFuelLabels), 'Pellets 5 kWh/kg, Propan 12 kWh/kg');
    expect(EnergyFactors.fromMap(null).heatingValues, isEmpty);
  });

  test('Klimastatus', () {
    expect(temperatureLevel(25.9), ComfortLevel.good);
    expect(temperatureLevel(26.5), ComfortLevel.mid);
    expect(humidityLevel(66), ComfortLevel.bad);
    expect(co2Level(1500), ComfortLevel.bad);
    expect(co2Level(1100), ComfortLevel.mid);
  });
}
