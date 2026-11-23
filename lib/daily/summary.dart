// Zusammenfassung der Tageswerte ueber einen Zeitraum fuer Uebersicht und
// Auswertung. Rein und ohne Firestore, damit jede Zahl im Test von Hand
// nachgerechnet werden kann. Die App rechnet hier nichts aus Rohdaten, sie
// fasst nur die Tagesdokumente der API zusammen (CLAUDE.md).
//
// Formeln: docs/konzept/04_datenmodell.md, Abschnitt "Umsetzung Etappe 3".
import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../household/household.dart';
import '../theme/kwf_tokens.dart';
import 'daily_values.dart';
import 'factors.dart';
import 'period.dart';

/// Energietraeger in der festen Reihenfolge des Design Systems.
enum Carrier {
  solar('Sonne', KwfColors.dataSolar, false),
  grid('Netz', KwfColors.dataNetz, false),
  gas('Gas', KwfColors.dataGas, true),
  wood('Holz/Pellets', KwfColors.dataHolz, true),
  // TODO(prüfen): Farbe fuer Heizoel mit dem Design System klaeren (wie Erfassen).
  oil('Heizöl', KwfColors.textSekundaer, true);

  const Carrier(this.label, this.color, this.isFuel);
  final String label;
  final Color color;

  /// Brennstoff aus den Eintraegen, also geschaetzt.
  final bool isFuel;

  /// Traeger eines Brennstoffs aus `manual_alloc`. Diesel und Benzin zaehlen
  /// im Bereich Wohnen nicht (Konzept 05_infotexte.md, 2.3): null.
  static Carrier? ofFuel(String type) => switch (type) {
        'propane' => Carrier.gas,
        'pellets' || 'woodKg' || 'woodSter' => Carrier.wood,
        'oil' => Carrier.oil,
        _ => null,
      };
}

/// Namen der Brennstoffe fuer Texte.
const kFuelLabels = {
  'pellets': 'Pellets',
  'woodKg': 'Holz (kg)',
  'woodSter': 'Holz (Ster)',
  'propane': 'Propan',
  'oil': 'Heizöl',
};

/// Grenzen fuer das Wohnklima (Entscheid 23.11.2026: behaglich 20 bis 26 °C).
abstract final class Comfort {
  static const tMin = 20.0;
  static const tMax = 26.0;
  static const rhMin = 30.0;
  static const rhMax = 60.0;
  static const rhBad = 65.0;
  static const co2Good = 1000.0;
  static const co2Mid = 1400.0;
}

/// Ein Brennstoff ueber den Zeitraum.
class FuelSum {
  FuelSum(this.type);
  final String type;
  double quantity = 0;
  String unit = '';

  /// kWh mit Heizwert; null, wenn ein Heizwert fehlt.
  double? kwh = 0;
  bool provisional = false;
  bool incomplete = false;

  /// Tage mit `quantity: null` (noch nicht schaetzbar).
  int unknownDays = 0;
  int fires = 0;
  final methods = <String>{};

  /// kWh pro Messpunkt (M0, M1, M2).
  final byMp = <String, double>{};

  /// Ohne Klimasensor verteilt: nicht als Tagesbalken zeigen.
  bool get evenlySpread => methods.length == 1 && methods.first == 'gleichmaessig';
}

/// Ein Tag fuer Balken: kWh pro Traeger.
class DayEnergy {
  DayEnergy(this.date);
  final DateTime date;
  final kwh = <Carrier, double>{};
  final estimated = <Carrier>{};
  bool gappy = false;
  bool partial = false;
  double heatElectric = 0;
  double heatFuel = 0;
  double heatSolar = 0;

  double get total => kwh.values.fold(0.0, (a, b) => a + b);
}

/// Werte eines Monats (Auswertung Saison und Jahr).
class MonthEnergy {
  MonthEnergy(this.month);
  final DateTime month;
  final kwh = <Carrier, double>{};
  final estimated = <Carrier>{};
  double heatElectric = 0;
  double heatFuel = 0;
  double heatSolar = 0;
  int days = 0;

  double get total => kwh.values.fold(0.0, (a, b) => a + b);
}

class PeriodSummary {
  PeriodSummary._(this.period);

  final Period period;

  // Datenlage
  int daysWithData = 0;
  int gappyDays = 0;
  DateTime? dataUntil;

  /// Tage ohne Dokument zwischen Beginn und heute.
  int get missingDays => period.dayCount - daysWithData;

  // Strom in kWh
  double gridKwh = 0; // E1
  double feedInKwh = 0; // E2
  double pvKwh = 0; // E3
  double pvSelfKwh = 0; // E3 - E2, pro Tag mindestens 0
  double heatElectricKwh = 0; // I2
  double heatSolarKwh = 0;
  bool hasPv = false;

  /// Gemessene Strom-Messpunkte im Zeitraum (E1, E3, I2, ...).
  final points = <String>{};

  // Brennstoffe
  final fuels = <String, FuelSum>{};

  // Personen
  double personHours = 0;

  /// Tage mit Daten, aber ohne Personen im Haushalt. Sie zaehlen nicht fuer
  /// die Werte pro Person (weder Energie noch Stunden).
  int daysWithoutPersons = 0;
  bool get householdMissing => daysWithoutPersons > 0;
  int? personsNow;

  /// Endenergie der Tage mit Personen (Grundlage fuer kWh pro Person).
  double _kwhWithPersons = 0;

  // Kennzahlen
  double? minergieKwh;
  double? minergieWithPvKwh;
  double? pe2000Kwh;

  // Klima und Belegung
  int occupiedDays = 0;
  int unknownOccupancyDays = 0;
  int climateDays = 0;
  double? tInMedian;
  double? tInP05;
  double? tInP95;
  double? rhMedian;
  double? co2Median;
  double? comfortHoursShare;
  int comfortHours = 0;
  double hoursOver28 = 0;
  (DateTime, double)? hottestWeek;
  final scatter = <(double, double)>[];

  /// CO2-Median pro Wochentag (0 = Montag) und Stunde; null ohne Daten.
  List<List<double?>> co2Heatmap = List.generate(7, (_) => List.filled(24, null));
  int co2Days = 0;

  // Reihen
  final days = <DayEnergy>[];
  final months = <MonthEnergy>[];

  /// Endenergie Wohnen: Netz + Sonne selbst genutzt + Brennstoffe mit Heizwert.
  double get fuelKwh => fuels.values
      .where((f) => Carrier.ofFuel(f.type) != null)
      .fold(0.0, (a, f) => a + (f.kwh ?? 0));
  double get totalKwh => gridKwh + pvSelfKwh + fuelKwh;

  /// Anteil der Sonne am Strom (selbst genutzt geteilt durch Sonne plus Netz).
  double? get autarky {
    final supply = gridKwh + pvSelfKwh;
    return supply > 0 ? pvSelfKwh / supply : null;
  }

  /// Anteil des Solarstroms, der im Haus blieb.
  double? get selfConsumption => pvKwh > 0 ? pvSelfKwh / pvKwh : null;

  /// Brennstoffe, fuer die es erst einen Eintrag gibt (Menge noch unbekannt).
  List<String> get unknownFuels => [
        for (final f in fuels.values)
          if (f.unknownDays > 0 && f.quantity == 0) f.type,
      ];

  bool get fuelEstimated => fuels.values.any((f) => f.quantity > 0 || f.unknownDays > 0);

  double? _watts(double? kwh) =>
      kwh == null || personHours <= 0 ? null : kwh * 1000 / personHours;

  /// Watt Dauerleistung pro Person nach Minergie-Gewichtung.
  double? get wattsMinergie => _watts(minergieKwh);
  double? get wattsMinergieWithPv => _watts(minergieWithPvKwh);

  /// Watt pro Person nach 2000-Watt-Methodik (Primaerenergie KBOB).
  double? get watts2000 => _watts(pe2000Kwh);

  /// kWh Endenergie pro Person und Tag.
  double? get kwhPerPersonDay => personHours > 0 ? _kwhWithPersons / (personHours / 24) : null;

  Map<Carrier, double> get kwhByCarrier {
    final m = <Carrier, double>{};
    if (pvSelfKwh > 0) m[Carrier.solar] = pvSelfKwh;
    if (gridKwh > 0) m[Carrier.grid] = gridKwh;
    for (final f in fuels.values) {
      final c = Carrier.ofFuel(f.type);
      if (c != null && (f.kwh ?? 0) > 0) m[c] = (m[c] ?? 0) + f.kwh!;
    }
    return {for (final c in Carrier.values) if (m[c] != null) c: m[c]!};
  }

  double get heatFuelKwh => days.fold(0.0, (a, d) => a + d.heatFuel);
  int get fires => fuels.values.fold(0, (a, f) => a + f.fires);

  static PeriodSummary of({
    required Period period,
    required List<DailyValues> days,
    required List<HouseholdEntry> household,
    required EnergyFactors factors,
    DateTime? now,
  }) {
    final s = PeriodSummary._(period);
    final inRange = [
      for (final d in days)
        if (period.contains(d.date)) d,
    ]..sort((a, b) => a.date.compareTo(b.date));
    final monthMap = <DateTime, MonthEnergy>{};
    final tHours = <double>[];
    final co2Cells = List.generate(7, (_) => List.generate(24, (_) => <double>[]));
    final weekMeans = <DateTime, double>{};
    // Minergie: Strom mit g gewichtet, Eigenverbrauch und Einspeisung
    // gutgeschrieben. 2000 Watt: Netz und Brennstoffe mal Primaerenergie.
    // Nur Tage mit Personen zaehlen.
    final gEl = factors.weighting['electricity'];
    final peEl = factors.primaryEnergy['electricity'];
    final selfCredit = factors.pvSelfConsumptionCredit ?? 0;
    final feedCredit = factors.pvFeedInCredit ?? 0;
    var minergie = 0.0;
    var minergieWithPv = 0.0;
    var pe = 0.0;
    var weightingOk = gEl != null;
    var peOk = peEl != null;
    var anyPersons = false;

    for (final d in inRange) {
      s.daysWithData++;
      if (d.dataUntil != null &&
          (s.dataUntil == null || d.dataUntil!.isAfter(s.dataUntil!))) {
        s.dataUntil = d.dataUntil;
      }
      final e1 = d.energyKwh['E1'] ?? 0;
      final e2 = d.energyKwh['E2'] ?? 0;
      final e3 = d.energyKwh['E3'] ?? 0;
      final pvSelf = math.max(0.0, e3 - e2);
      final i2 = d.energyKwh['I2'] ?? 0;
      final gappy = ['E1', 'E3'].any((k) => (d.availability[k] ?? 1) < 0.9);
      if (gappy) s.gappyDays++;
      s.gridKwh += e1;
      s.feedInKwh += e2;
      s.pvKwh += e3;
      s.pvSelfKwh += pvSelf;
      if (d.energyKwh.containsKey('E3')) s.hasPv = true;
      s.points.addAll(d.energyKwh.keys);
      final dayAutarky = (e1 + pvSelf) > 0 ? pvSelf / (e1 + pvSelf) : 0.0;
      s.heatElectricKwh += i2;
      s.heatSolarKwh += i2 * dayAutarky;

      final day = DayEnergy(d.date)
        ..gappy = gappy
        ..partial = d.partial
        ..heatElectric = i2
        ..heatSolar = i2 * dayAutarky;
      if (pvSelf > 0) day.kwh[Carrier.solar] = pvSelf;
      if (e1 > 0) day.kwh[Carrier.grid] = e1;

      // Brennstoffe
      var gFuel = 0.0;
      var peFuel = 0.0;
      var fuelDay = 0.0;
      d.manualAlloc.forEach((type, a) {
        final f = s.fuels.putIfAbsent(type, () => FuelSum(type));
        f.unit = a.unit;
        f.methods.add(a.method);
        f.provisional |= a.provisional;
        f.incomplete |= a.incomplete;
        f.fires += a.fires ?? 0;
        if (a.quantity == null) {
          f.unknownDays++;
          return;
        }
        f.quantity += a.quantity!;
        final hv = factors.heatingValues[type];
        final kwh = d.manualKwhEstimated[type] ?? (hv == null ? null : a.quantity! * hv);
        if (kwh == null) {
          f.kwh = null;
        } else if (f.kwh != null) {
          f.kwh = f.kwh! + kwh;
        }
        if (hv != null) {
          a.byMeteringPoint.forEach((mp, q) {
            if (q != null) f.byMp[mp] = (f.byMp[mp] ?? 0) + q * hv;
          });
        }
        final c = Carrier.ofFuel(type);
        if (c == null || kwh == null) return;
        day.kwh[c] = (day.kwh[c] ?? 0) + kwh;
        day.estimated.add(c);
        fuelDay += kwh;
        if (hv != null) day.heatFuel += (a.byMeteringPoint['M2'] ?? 0) * hv;
        final g = factors.weighting[type];
        if (g == null) {
          weightingOk = false;
        } else {
          gFuel += g * kwh;
        }
        final p = factors.primaryEnergy[type];
        if (p == null) {
          peOk = false;
        } else {
          peFuel += p * kwh;
        }
      });

      // Personen-Stunden: heute nur bis zum letzten Messwert.
      final persons = householdAt(household, d.date)?.persons;
      if (persons == null || persons <= 0) {
        s.daysWithoutPersons++;
      } else {
        var hours = 24.0;
        if (d.partial && d.dataUntil != null) {
          hours = d.dataUntil!.difference(d.date).inMinutes / 60;
          hours = hours.clamp(0, 24).toDouble();
        }
        s.personHours += persons * hours;
        anyPersons = true;
        s._kwhWithPersons += e1 + pvSelf + fuelDay;
        if (gEl != null) {
          minergieWithPv += gEl * (e1 + pvSelf) + gFuel;
          minergie += gEl * (e1 + pvSelf) -
              gEl * pvSelf * selfCredit -
              gEl * e2 * feedCredit +
              gFuel;
        }
        if (peEl != null) pe += peEl * e1 + peFuel;
      }

      s.days.add(day);
      final mk = DateTime(d.date.year, d.date.month);
      final m = monthMap.putIfAbsent(mk, () => MonthEnergy(mk));
      m.days++;
      day.kwh.forEach((c, v) => m.kwh[c] = (m.kwh[c] ?? 0) + v);
      m.estimated.addAll(day.estimated);
      m.heatElectric += day.heatElectric;
      m.heatFuel += day.heatFuel;
      m.heatSolar += day.heatSolar;

      // Klima und Belegung
      if (d.occupied == true) s.occupiedDays++;
      if (d.occupied == null) s.unknownOccupancyDays++;
      final tMed = d.climate['t_in_median'];
      if (tMed != null) {
        s.climateDays++;
        final rh = d.climate['rh_in_median'];
        if (rh != null) s.scatter.add((tMed, rh));
      }
      s.hoursOver28 += d.climate['hours_over_28'] ?? 0;
      final t0820 = d.climate['t_in_mean_08_20'];
      if (t0820 != null) weekMeans[d.date] = t0820;
      final co2 = d.hourlyClimate['co2'];
      if (co2 != null && co2.any((v) => v != null)) {
        s.co2Days++;
        for (var h = 0; h < 24 && h < co2.length; h++) {
          if (co2[h] != null) co2Cells[d.date.weekday - 1][h].add(co2[h]!);
        }
      }
    }

    // Personen heute
    s.personsNow = householdAt(household, period.until)?.persons;

    // TODO(prüfen): Untergrenze 0 und Gutschrift der Einspeisung mit dem Label-Team.
    if (weightingOk && anyPersons) {
      s.minergieWithPvKwh = minergieWithPv;
      s.minergieKwh = math.max(0.0, minergie);
    }
    if (peOk && anyPersons) s.pe2000Kwh = pe;

    // Klima: an bewohnten Tagen, sonst an allen Tagen mit Klima.
    final climateDays = inRange.where((d) => d.climate['t_in_median'] != null).toList();
    final occ = climateDays.where((d) => d.occupied == true).toList();
    final base = occ.isNotEmpty ? occ : climateDays;
    s.tInMedian = median([for (final d in base) d.climate['t_in_median']!]);
    s.rhMedian = median([for (final d in base) ?d.climate['rh_in_median']]);
    s.co2Median = median([for (final d in base) ?d.climate['co2_median']]);
    for (final d in base) {
      for (final v in d.hourlyClimate['t_in'] ?? const <double?>[]) {
        if (v != null) tHours.add(v);
      }
    }
    if (tHours.isNotEmpty) {
      tHours.sort();
      s.tInP05 = percentile(tHours, 0.05);
      s.tInP95 = percentile(tHours, 0.95);
      s.comfortHours = tHours.where((t) => t >= Comfort.tMin && t <= Comfort.tMax).length;
      s.comfortHoursShare = s.comfortHours / tHours.length;
    }

    // Heisseste Woche: hoechstes Mittel von 7 aufeinanderfolgenden Tagen.
    for (final start in weekMeans.keys) {
      final vals = <double>[];
      for (var i = 0; i < 7; i++) {
        final v = weekMeans[DateTime(start.year, start.month, start.day + i)];
        if (v == null) break;
        vals.add(v);
      }
      if (vals.length < 7) continue;
      final mean = vals.reduce((a, b) => a + b) / 7;
      if (s.hottestWeek == null || mean > s.hottestWeek!.$2) s.hottestWeek = (start, mean);
    }

    s.co2Heatmap = [
      for (final row in co2Cells) [for (final cell in row) median(cell)],
    ];
    final ms = monthMap.keys.toList()..sort();
    s.months.addAll([for (final k in ms) monthMap[k]!]);
    return s;
  }
}

double? median(List<double> values) {
  if (values.isEmpty) return null;
  final v = [...values]..sort();
  final mid = v.length ~/ 2;
  return v.length.isOdd ? v[mid] : (v[mid - 1] + v[mid]) / 2;
}

/// Perzentil mit linearer Interpolation, [sorted] aufsteigend.
double percentile(List<double> sorted, double p) {
  if (sorted.length == 1) return sorted.first;
  final pos = p * (sorted.length - 1);
  final lo = pos.floor();
  final hi = pos.ceil();
  return sorted[lo] + (sorted[hi] - sorted[lo]) * (pos - lo);
}

/// Status eines Klimawerts, immer mit Wort (Farbe nie allein).
enum ComfortLevel { good, mid, bad }

ComfortLevel temperatureLevel(double t) =>
    t >= Comfort.tMin && t <= Comfort.tMax ? ComfortLevel.good : ComfortLevel.mid;

ComfortLevel humidityLevel(double rh) => rh > Comfort.rhBad
    ? ComfortLevel.bad
    : (rh >= Comfort.rhMin && rh <= Comfort.rhMax ? ComfortLevel.good : ComfortLevel.mid);

ComfortLevel co2Level(double ppm) => ppm < Comfort.co2Good
    ? ComfortLevel.good
    : (ppm <= Comfort.co2Mid ? ComfortLevel.mid : ComfortLevel.bad);
