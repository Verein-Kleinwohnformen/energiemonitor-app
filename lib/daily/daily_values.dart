// Tageswerte aus /devices/{monitorId}/daily/{YYYY-MM-DD} (Etappe 2).
//
// Die energiemonitor-api rechnet sie aus den Rohdaten (POST /aggregate),
// stuendlich fuer heute und nachts fuer die letzten Tage. Die App rechnet
// nichts aus Rohdaten, sie liest nur diese Dokumente. Aufbau:
// docs/konzept/04_datenmodell.md, Abschnitt "Umsetzung Etappe 2".
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Wie ein Brennstoffwert eines Tages entstanden ist.
class FuelAllocation {
  const FuelAllocation({
    required this.quantity,
    required this.unit,
    required this.method,
    required this.provisional,
    required this.incomplete,
    this.fires,
    this.byMeteringPoint = const {},
  });

  /// Menge in der Einheit des Formulars. null: noch nicht schaetzbar (zum
  /// Beispiel Feuer erkannt, aber noch kein abgeschlossener Zeitraum).
  final double? quantity;
  final String unit;

  /// ofensignatur, heizgradtage, bewohnte_tage oder gleichmaessig.
  final String method;

  /// true: geschaetzt im laufenden Zeitraum, wird mit dem naechsten Eintrag ersetzt.
  final bool provisional;

  /// true: ein Teil (Messpunkt) ist noch nicht schaetzbar und fehlt in quantity.
  final bool incomplete;

  /// Erkannte Feuer an diesem Tag (nur bei der Ofensignatur).
  final int? fires;
  final Map<String, double?> byMeteringPoint;

  static FuelAllocation? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final byMp = <String, double?>{};
    final mp = raw['by_metering_point'];
    if (mp is Map) {
      mp.forEach((k, v) => byMp['$k'] = _num(v));
    }
    return FuelAllocation(
      quantity: _num(raw['quantity']),
      unit: '${raw['unit'] ?? ''}',
      method: '${raw['method'] ?? ''}',
      provisional: raw['provisional'] == true,
      incomplete: raw['incomplete'] == true,
      fires: (raw['fires'] as num?)?.toInt(),
      byMeteringPoint: byMp,
    );
  }
}

/// Ein erkanntes Feuer (Ofensignatur). Zeiten in Lokalzeit, "HH:MM".
class FireEvent {
  const FireEvent({required this.start, required this.end, required this.riseKPerH, required this.weight});
  final String start;
  final String end;
  final double riseKPerH;

  /// Brenndauer in Stunden als Naeherung, Gewicht fuer die Verteilung.
  final double weight;

  static FireEvent? fromMap(Object? raw) {
    if (raw is! Map) return null;
    return FireEvent(
      start: '${raw['start'] ?? ''}',
      end: '${raw['end'] ?? ''}',
      riseKPerH: _num(raw['rise_k_per_h']) ?? 0,
      weight: _num(raw['weight']) ?? 0,
    );
  }
}

class DailyValues {
  const DailyValues({
    required this.date,
    this.energyKwh = const {},
    this.hourlyKwh = const {},
    this.availability = const {},
    this.climate = const {},
    this.hourlyClimate = const {},
    this.climateSource,
    this.occupied,
    this.occupancySource,
    this.co2Peak,
    this.co2Rise,
    this.fireEvents = const [],
    this.fireSource,
    this.energySensor = const {},
    this.computedAt,
    this.manualAlloc = const {},
    this.manualKwhEstimated = const {},
    this.partial = false,
    this.dataUntil,
    this.version = 0,
  });

  /// Kalendertag in Lokalzeit (Europe/Zurich).
  final DateTime date;

  /// Strom pro Messpunkt (E1, E2, E3, A1, I1, I2, I3), gemessen.
  final Map<String, double> energyKwh;

  /// Strom pro Messpunkt und Stunde auf der Uhr (24 Werte).
  final Map<String, List<double>> hourlyKwh;

  /// Anteil des Tages mit Daten, 0 bis 1, pro Messpunkt (K1 bis K4 fuer Klima).
  final Map<String, double> availability;

  /// Klimawerte, z.B. t_in_median, co2_max, t_out_mean, hours_over_28.
  final Map<String, double?> climate;

  /// Median pro Stunde auf der Uhr (24 Werte, null ohne Daten) fuer `t_in`
  /// und `co2`. Grundlage der Heatmap und der Komfortstunden.
  final Map<String, List<double?>> hourlyClimate;
  final String? climateSource;

  /// Bewohnt (aus CO2 berechnet, nicht gemessen). null: unbekannt.
  final bool? occupied;
  final String? occupancySource;

  /// Hoechstwert CO2 des Tages (Rohwert) und Anstieg ueber dem 10. Perzentil.
  final double? co2Peak;
  final double? co2Rise;
  final List<FireEvent> fireEvents;

  /// Sensor der Ofensignatur (netatmo, sensirion) oder null.
  final String? fireSource;

  /// Welcher Sensor pro Messpunkt gezaehlt wurde.
  final Map<String, String> energySensor;
  final DateTime? computedAt;

  /// Brennstoffe nach Energietraeger (pellets, propane, woodKg, ...), geschaetzt.
  final Map<String, FuelAllocation> manualAlloc;

  /// Brennstoffe in kWh (Menge mal Heizwert aus /config/factors).
  final Map<String, double> manualKwhEstimated;

  /// true: der Tag ist noch nicht vorbei (heute).
  final bool partial;

  /// Zeitpunkt des letzten Messwerts des Tages.
  final DateTime? dataUntil;
  final int version;

  static final _key = DateFormat('yyyy-MM-dd');

  /// Dokument-ID eines Tages.
  static String keyOf(DateTime day) => _key.format(day);

  static DailyValues? fromFirestore(String id, Map<String, dynamic> data) {
    final d = DateTime.tryParse('${data['date'] ?? id}');
    if (d == null) return null;
    final until = data['data_until'];
    return DailyValues(
      date: DateTime(d.year, d.month, d.day),
      energyKwh: _numMap(data['energy_kwh']),
      hourlyKwh: {
        for (final e in ((data['hourly_kwh'] as Map?) ?? const {}).entries)
          '${e.key}': [for (final v in (e.value as List? ?? const [])) _num(v) ?? 0],
      },
      availability: _numMap(data['availability']),
      climate: {
        for (final e in ((data['climate'] as Map?) ?? const {}).entries) '${e.key}': _num(e.value),
      },
      hourlyClimate: {
        for (final e in ((data['hourly_climate'] as Map?) ?? const {}).entries)
          '${e.key}': [for (final v in (e.value as List? ?? const [])) _num(v)],
      },
      climateSource: data['climate_source'] as String?,
      occupied: data['occupied'] as bool?,
      occupancySource: data['occupancy_source'] as String?,
      co2Peak: _num(data['co2_peak']),
      co2Rise: _num(data['co2_rise']),
      fireSource: data['fire_source'] as String?,
      energySensor: {
        for (final e in ((data['energy_sensor'] as Map?) ?? const {}).entries)
          '${e.key}': '${e.value}',
      },
      computedAt: switch (data['computed_at']) {
        Timestamp t => t.toDate(),
        String s => DateTime.tryParse(s),
        _ => null,
      },
      fireEvents: [
        for (final f in (data['fire_events'] as List? ?? const [])) ?FireEvent.fromMap(f),
      ],
      manualAlloc: {
        for (final e in ((data['manual_alloc'] as Map?) ?? const {}).entries)
          if (FuelAllocation.fromMap(e.value) case final a?) '${e.key}': a,
      },
      manualKwhEstimated: _numMap(data['manual_kwh_estimated']),
      partial: data['partial'] == true,
      dataUntil: until is num ? DateTime.fromMillisecondsSinceEpoch(until.toInt()) : null,
      version: (data['version'] as num?)?.toInt() ?? 0,
    );
  }
}

double? _num(Object? v) => v is num ? v.toDouble() : null;

Map<String, double> _numMap(Object? raw) => {
      if (raw is Map)
        for (final e in raw.entries)
          if (e.value is num) '${e.key}': (e.value as num).toDouble(),
    };

/// Tageswerte eines Monitors fuer einen Zeitraum (beide Tage inklusive),
/// aeltester zuerst.
abstract class DailyRepository {
  Future<List<DailyValues>> load(String monitorId, DateTime from, DateTime to);
}

/// Liest aus Firestore und behaelt jeden Tag 10 Minuten. Die API rechnet
/// stuendlich, oefter lesen bringt nichts. Der Zwischenspeicher gilt pro Tag,
/// nicht pro Zeitraum: Wer in der Auswertung zwischen Woche, Monat und Jahr
/// wechselt, liest nur die Tage, die noch fehlen (jeder Tag ist ein Lesevorgang).
class FirestoreDaily implements DailyRepository {
  FirestoreDaily([FirebaseFirestore? db])
      : _cache = DailyDayCache((id, from, to) => _read(db ?? FirebaseFirestore.instance, id, from, to));

  final DailyDayCache _cache;

  @override
  Future<List<DailyValues>> load(String monitorId, DateTime from, DateTime to) =>
      _cache.load(monitorId, from, to);

  static Future<List<DailyValues>> _read(
      FirebaseFirestore db, String monitorId, DateTime from, DateTime to) async {
    final snap = await db
        .collection('devices')
        .doc(monitorId)
        .collection('daily')
        .orderBy(FieldPath.documentId)
        .startAt([DailyValues.keyOf(from)])
        .endAt([DailyValues.keyOf(to)])
        .get();
    return [
      for (final doc in snap.docs) ?DailyValues.fromFirestore(doc.id, doc.data()),
    ];
  }
}

typedef DailyFetch = Future<List<DailyValues>> Function(String monitorId, DateTime from, DateTime to);

/// Zwischenspeicher pro Tag. Fehlende oder abgelaufene Tage werden in einer
/// Abfrage vom ersten bis zum letzten fehlenden Tag gelesen. Auch Tage ohne
/// Dokument gelten als gelesen.
class DailyDayCache {
  DailyDayCache(this._fetch, {this.keep = const Duration(minutes: 10), DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final DailyFetch _fetch;
  final Duration keep;
  final DateTime Function() _now;
  final _days = <String, Map<String, (DateTime, DailyValues?)>>{};
  final _busy = <String, Future<void>>{};

  Future<List<DailyValues>> load(String monitorId, DateTime from, DateTime to) async {
    // Nacheinander pro Monitor, damit zwei Seiten denselben Tag nicht doppelt lesen.
    while (_busy[monitorId] != null) {
      await _busy[monitorId];
    }
    final days = _days.putIfAbsent(monitorId, () => {});
    final wanted = [
      for (var d = DateTime(from.year, from.month, from.day);
          !d.isAfter(to);
          d = DateTime(d.year, d.month, d.day + 1))
        d,
    ];
    final now = _now();
    final missing = [
      for (final d in wanted)
        if (!_fresh(days[DailyValues.keyOf(d)], now)) d,
    ];
    if (missing.isNotEmpty) {
      final job = _fetch(monitorId, missing.first, missing.last).then((list) {
        final byKey = {for (final v in list) DailyValues.keyOf(v.date): v};
        for (var d = missing.first; !d.isAfter(missing.last); d = DateTime(d.year, d.month, d.day + 1)) {
          final k = DailyValues.keyOf(d);
          days[k] = (now, byKey[k]);
        }
      });
      _busy[monitorId] = job;
      try {
        await job;
      } finally {
        _busy.remove(monitorId);
      }
    }
    return [
      for (final d in wanted) ?days[DailyValues.keyOf(d)]?.$2,
    ];
  }

  bool _fresh((DateTime, DailyValues?)? hit, DateTime now) =>
      hit != null && now.difference(hit.$1) < keep;
}
