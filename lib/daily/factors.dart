// Faktoren aus /config/factors: Heizwerte, Gewichtung nach Minergie,
// Primaerenergie nach KBOB und Vergleichswerte. Das Team pflegt sie in der
// Firebase Console. Im Code steht keine Zahl: fehlt ein Faktor, fehlt der Wert,
// der ihn braucht (CLAUDE.md, Regel Faktoren).
import 'package:cloud_firestore/cloud_firestore.dart';

/// Ein Vergleichswert fuer Watt pro Person, z.B. das 2000-Watt-Ziel.
class Benchmark {
  const Benchmark({required this.label, required this.watts, required this.method, this.source});

  final String label;
  final double watts;

  /// `minergie` oder `2000watt`: mit welcher Methode der Wert vergleichbar ist.
  final String method;
  final String? source;
}

class EnergyFactors {
  const EnergyFactors({
    this.heatingValues = const {},
    this.heatingUnits = const {},
    this.heatingSource,
    this.weighting = const {},
    this.pvSelfConsumptionCredit,
    this.pvFeedInCredit,
    this.weightingSource,
    this.primaryEnergy = const {},
    this.primarySource,
    this.benchmarks = const [],
    this.updatedAt,
  });

  /// Energietraeger (pellets, propane, woodKg, ...) -> kWh pro Einheit des Formulars.
  final Map<String, double> heatingValues;
  final Map<String, String> heatingUnits;
  final String? heatingSource;

  /// Gewichtungsfaktor g nach Minergie pro Traeger, inkl. `electricity`.
  final Map<String, double> weighting;
  final double? pvSelfConsumptionCredit;
  final double? pvFeedInCredit;
  final String? weightingSource;

  /// Primaerenergiefaktor gesamt (KBOB) pro Traeger, inkl. `electricity`.
  final Map<String, double> primaryEnergy;
  final String? primarySource;
  final List<Benchmark> benchmarks;
  final String? updatedAt;

  static const empty = EnergyFactors();

  static EnergyFactors fromMap(Map<String, dynamic>? data) {
    if (data == null) return empty;
    final hv = <String, double>{};
    final hu = <String, String>{};
    String? hvSource;
    _entries(data['heating_values']).forEach((k, v) {
      if (v is Map && v['value'] is num) {
        hv[k] = (v['value'] as num).toDouble();
        hu[k] = '${v['unit'] ?? ''}';
        hvSource ??= v['source'] as String?;
      }
    });

    final w = <String, double>{};
    final wf = _entries(data['weighting_factors']);
    wf.forEach((k, v) {
      if (v is num && !k.startsWith('pv_')) w[k] = v.toDouble();
    });

    final pe = <String, double>{};
    final pef = _entries(data['primary_energy_factors']);
    pef.forEach((k, v) {
      if (v is Map && v['total'] is num) pe[k] = (v['total'] as num).toDouble();
    });

    final bm = <Benchmark>[
      for (final v in _entries(data['benchmarks']).values)
        if (v is Map && v['value'] is num && v['label'] is String)
          Benchmark(
            label: v['label'] as String,
            watts: (v['value'] as num).toDouble(),
            method: '${v['method'] ?? '2000watt'}',
            source: v['source'] as String?,
          ),
    ]..sort((a, b) => a.watts.compareTo(b.watts));

    return EnergyFactors(
      heatingValues: hv,
      heatingUnits: hu,
      heatingSource: hvSource,
      weighting: w,
      pvSelfConsumptionCredit: (wf['pv_self_consumption_credit'] as num?)?.toDouble(),
      pvFeedInCredit: (wf['pv_feed_in_credit'] as num?)?.toDouble(),
      weightingSource: wf['source'] as String?,
      primaryEnergy: pe,
      primarySource: pef['source'] as String?,
      benchmarks: bm,
      updatedAt: data['updated_at'] as String?,
    );
  }

  /// Heizwerte fuer Texte, je "Name Wert Einheit", mit Komma getrennt.
  String heatingValuesText(Map<String, String> labels) => [
        for (final e in heatingValues.entries)
          if (labels[e.key] != null)
            '${labels[e.key]} ${_fmt(e.value)} ${heatingUnits[e.key] ?? ''}'.trim(),
      ].join(', ');
}

Map<String, Object?> _entries(Object? raw) =>
    raw is Map ? {for (final e in raw.entries) '${e.key}': e.value} : const {};

String _fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : '$v';

abstract class FactorsRepository {
  Future<EnergyFactors> load();
}

/// /config/factors einmal pro App-Start lesen.
class FirestoreFactors implements FactorsRepository {
  FirestoreFactors([FirebaseFirestore? db]) : _db = db ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;
  Future<EnergyFactors>? _cached;

  @override
  Future<EnergyFactors> load() => _cached ??= _db
      .collection('config')
      .doc('factors')
      .get()
      .then((s) => EnergyFactors.fromMap(s.data()))
      .catchError((Object _) {
        _cached = null;
        return EnergyFactors.empty;
      });
}
