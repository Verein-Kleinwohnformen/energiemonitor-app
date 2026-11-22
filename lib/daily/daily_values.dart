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
    this.climateSource,
    this.occupied,
    this.occupancySource,
    this.fireEvents = const [],
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
  final String? climateSource;

  /// Bewohnt (aus CO2 berechnet, nicht gemessen). null: unbekannt.
  final bool? occupied;
  final String? occupancySource;
  final List<FireEvent> fireEvents;

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
      climateSource: data['climate_source'] as String?,
      occupied: data['occupied'] as bool?,
      occupancySource: data['occupancy_source'] as String?,
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

/// Tageswerte eines Monitors fuer einen Zeitraum lesen (beide Tage inklusive).
class FirestoreDaily {
  FirestoreDaily([FirebaseFirestore? db]) : _db = db ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  Future<List<DailyValues>> load(String monitorId, DateTime from, DateTime to) async {
    final snap = await _db
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
