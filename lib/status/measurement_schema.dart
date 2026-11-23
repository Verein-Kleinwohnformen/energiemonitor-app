// Mess-Schema nach Messkonzept v1.0 (Minergie-Modul Monitoring): welche
// Messpunkte ein Haus hat, ob Daten ankommen, und ob Heizwaerme, Warmwasser
// und Wohnklima abgedeckt sind. Reine Logik, ohne Widgets und ohne Firestore.
//
// Es gibt keine Angabe pro Haus, welche Heiz- und Warmwasserquellen es hat
// (Entscheid 23.11.2026). Die Abdeckung wird darum aus den Daten abgeleitet:
// Heizwaerme mit I2 oder Eintraegen fuer Heizen (M2), Warmwasser mit I1 oder
// Eintraegen fuer Warmwasser (M1). Eine zweite Quelle, die der Monitor nicht
// kennt, sieht die Pruefung nicht.
//
// TODO(prüfen): value_fields sammelt alle je gesehenen Felder, last_seen gibt
// es nur pro Messpunkt. Faellt unter K0 nur ein Sensor aus (z.B. die
// Netatmo), bleibt das hier unsichtbar.
import 'package:intl/intl.dart';

import '../app/services.dart';
import '../metering_point.dart';
import 'system_status.dart';

/// Gruppen wie auf der Folie "Was gemessen wird" (Messkonzept v1.0).
enum SchemaGroup {
  boundary('Energie über die Systemgrenze'),
  consumers('Verbraucher im Haus'),
  comfort('Wohnkomfort am Lieblingsort'),
  water('Wasser'),
  other('Weitere Messpunkte');

  const SchemaGroup(this.title);
  final String title;
}

/// Zustand eines Messpunkts im Schema.
enum PointCoverage {
  online('online'),
  delayed('verzögert'),
  offline('offline'),

  /// Automatischer Messpunkt, aber seit ueber 30 Tagen keine Daten.
  stale('keine Daten'),

  /// Manueller Messpunkt mit Eintraegen.
  entries('Einträge'),
  missing('nicht gemessen');

  const PointCoverage(this.word);
  final String word;

  /// Zaehlt fuer die Abdeckung (Daten in den letzten 30 Tagen oder Eintraege).
  bool get counts =>
      this == online || this == delayed || this == offline || this == entries;
}

class SchemaSlot {
  const SchemaSlot(this.id, this.group, {this.viaK0Field});
  final String id;
  final SchemaGroup group;

  /// Feld unter K0, unter dem dieser Komfort-Messpunkt heute ankommt.
  final String? viaK0Field;
}

/// Messpunkte des Messkonzepts, in der Reihenfolge der Anzeige. M0 kommt nur
/// dazu, wenn es Eintraege dafuer gibt.
const kSchemaSlots = <SchemaSlot>[
  SchemaSlot('E1', SchemaGroup.boundary),
  SchemaSlot('E2', SchemaGroup.boundary),
  SchemaSlot('E3', SchemaGroup.boundary),
  SchemaSlot('M1', SchemaGroup.boundary),
  SchemaSlot('M2', SchemaGroup.boundary),
  SchemaSlot('I1', SchemaGroup.consumers),
  SchemaSlot('I2', SchemaGroup.consumers),
  SchemaSlot('I3', SchemaGroup.consumers),
  SchemaSlot('A1', SchemaGroup.consumers),
  SchemaSlot('K1', SchemaGroup.comfort, viaK0Field: 'temperature_indoor'),
  SchemaSlot('K2', SchemaGroup.comfort, viaK0Field: 'temperature_outdoor'),
  SchemaSlot('K3', SchemaGroup.comfort, viaK0Field: 'humidity_indoor'),
  SchemaSlot('K4', SchemaGroup.comfort, viaK0Field: 'co2_indoor'),
  SchemaSlot('D1', SchemaGroup.water),
];

/// Namen im Schema. Wie im Systemstatus, aber naeher am Messkonzept.
const kSchemaLabels = <String, String>{
  'E1': 'Netzbezug',
  'E2': 'Rückspeisung',
  'E3': 'Eigenproduktion (Solar)',
  'M0': 'Gemischt (Einträge)',
  'M1': 'Warmwasser (Einträge)',
  'M2': 'Heizen (Einträge)',
  'I1': 'Warmwasser',
  'I2': 'Heizung',
  'I3': 'Kleinverbraucher',
  'A1': 'Monitor selbst',
  'K1': 'Innentemperatur',
  'K2': 'Aussentemperatur',
  'K3': 'Luftfeuchte',
  'K4': 'CO2',
  'D1': 'Wasser',
};

String schemaLabel(String id) => kSchemaLabels[id] ?? pointLabel(id);

class SchemaPoint {
  const SchemaPoint({
    required this.id,
    required this.group,
    required this.coverage,
    this.lastSeen,
    this.viaK0 = false,
  });
  final String id;
  final SchemaGroup group;
  final PointCoverage coverage;

  /// Letzte Daten (automatisch) oder letzter Eintrag (manuell).
  final DateTime? lastSeen;

  /// Kommt heute unter K0 an, nicht als eigener Messpunkt.
  final bool viaK0;

  String get label => schemaLabel(id);
  bool get isManual => id.startsWith('M');
}

enum ReqState { met, partial, missing }

class RequirementCheck {
  const RequirementCheck({
    required this.id,
    required this.title,
    required this.state,
    required this.sources,
    this.warning,
  });

  /// heat, hotWater oder climate.
  final String id;
  final String title;
  final ReqState state;

  /// Messpunkte, die die Anforderung abdecken.
  final List<String> sources;
  final String? warning;
}

class MeasurementSchema {
  const MeasurementSchema({required this.points, required this.checks});
  final List<SchemaPoint> points;
  final List<RequirementCheck> checks;

  List<RequirementCheck> get warnings => checks.where((c) => c.state != ReqState.met).toList();
  List<SchemaPoint> inGroup(SchemaGroup g) => points.where((p) => p.group == g).toList();
  SchemaPoint? point(String id) {
    for (final p in points) {
      if (p.id == id) return p;
    }
    return null;
  }
}

/// Zustand eines automatischen Messpunkts, gleiche Schwellen wie der
/// Systemstatus (90 min, 6 h, 30 Tage).
PointCoverage coverageFor(MeteringPoint? p, DateTime now) {
  if (p == null) return PointCoverage.missing;
  final lastSeen = DateTime.fromMillisecondsSinceEpoch(p.lastSeen);
  if (now.difference(lastSeen) >= kActiveWindow) return PointCoverage.stale;
  return switch (linkStateFor(lastSeen, now)) {
    LinkState.online => PointCoverage.online,
    LinkState.delayed => PointCoverage.delayed,
    LinkState.offline => PointCoverage.offline,
  };
}

/// Letzter Eintrag fuer einen manuellen Messpunkt: aus den geladenen
/// Eintraegen, sonst aus last_seen des Messpunkt-Dokuments.
DateTime? lastEntryFor(String mp, List<ManualEntry> entries, MeteringPoint? fallback) {
  DateTime? last;
  for (final e in entries) {
    if (e.energy.meteringPoint != mp) continue;
    final d = e.energy.purchaseDate;
    if (last == null || d.isAfter(last)) last = d;
  }
  if (last != null) return last;
  if (fallback != null && fallback.lastSeen > 0) {
    return DateTime.fromMillisecondsSinceEpoch(fallback.lastSeen);
  }
  return null;
}

final _dmy = DateFormat('d.M.yyyy');

MeasurementSchema evaluateSchema({
  required List<MeteringPoint> points,
  required List<ManualEntry> entries,
  required DateTime now,
}) {
  final byId = {for (final p in points) p.meteringPointId: p};
  final k0 = byId['K0'];
  final k0Fields = k0?.valueFields.toSet() ?? const <String>{};
  final out = <SchemaPoint>[];

  SchemaPoint manual(String id, SchemaGroup group) {
    final last = lastEntryFor(id, entries, byId[id]);
    return SchemaPoint(
      id: id,
      group: group,
      coverage: last == null ? PointCoverage.missing : PointCoverage.entries,
      lastSeen: last,
    );
  }

  for (final slot in kSchemaSlots) {
    if (slot.id.startsWith('M')) {
      out.add(manual(slot.id, slot.group));
      continue;
    }
    final own = byId[slot.id];
    if (own != null || slot.viaK0Field == null) {
      out.add(SchemaPoint(
        id: slot.id,
        group: slot.group,
        coverage: coverageFor(own, now),
        lastSeen: own == null ? null : DateTime.fromMillisecondsSinceEpoch(own.lastSeen),
      ));
      continue;
    }
    // Komfort-Messpunkt ueber K0: gemessen, wenn K0 das Feld je geschickt hat.
    final viaK0 = k0 != null && k0Fields.contains(slot.viaK0Field);
    out.add(SchemaPoint(
      id: slot.id,
      group: slot.group,
      coverage: viaK0 ? coverageFor(k0, now) : PointCoverage.missing,
      lastSeen: viaK0 ? DateTime.fromMillisecondsSinceEpoch(k0.lastSeen) : null,
      viaK0: viaK0,
    ));
  }

  final m0 = manual('M0', SchemaGroup.boundary);
  if (m0.coverage == PointCoverage.entries) {
    out.insert(out.indexWhere((p) => p.id == 'M2') + 1, m0);
  }

  // Unbekannte Messpunkte nicht verlieren (K0 selbst ist ueber K1 bis K4 abgebildet).
  final known = {for (final s in kSchemaSlots) s.id, 'M0', 'K0'};
  for (final p in points) {
    if (known.contains(p.meteringPointId)) continue;
    out.add(SchemaPoint(
      id: p.meteringPointId,
      group: SchemaGroup.other,
      coverage: coverageFor(p, now),
      lastSeen: DateTime.fromMillisecondsSinceEpoch(p.lastSeen),
    ));
  }

  final map = {for (final p in out) p.id: p};
  return MeasurementSchema(
    points: out,
    checks: [checkHeat(map), checkHotWater(map), checkClimate(map)],
  );
}

RequirementCheck _energyCheck({
  required Map<String, SchemaPoint> pts,
  required String id,
  required String title,
  required String meter,
  required String manualMp,
  required String manualWord,
}) {
  final sources = [
    for (final s in [meter, manualMp])
      if (pts[s]?.coverage.counts ?? false) s,
  ];
  if (sources.isNotEmpty) {
    return RequirementCheck(id: id, title: title, state: ReqState.met, sources: sources);
  }
  final staleNote = pts[meter]?.coverage == PointCoverage.stale
      ? ' ${schemaLabel(meter)} ($meter) schickt seit dem '
          '${_dmy.format(pts[meter]!.lastSeen!)} keine Daten mehr.'
      : '';
  if (pts['M0']?.coverage == PointCoverage.entries) {
    return RequirementCheck(
      id: id,
      title: title,
      state: ReqState.partial,
      sources: const ['M0'],
      warning: '$title nur teilweise: Es gibt nur gemischte Einträge (M0). Die lassen sich '
          'nicht sicher auf Heizen und Warmwasser aufteilen.$staleNote',
    );
  }
  return RequirementCheck(
    id: id,
    title: title,
    state: ReqState.missing,
    sources: const [],
    warning: '$title fehlt: Es kommen keine Daten von ${schemaLabel(meter)} ($meter), und es '
        'gibt keine Einträge für $manualWord ($manualMp).$staleNote',
  );
}

/// Heizwaerme: I2 (Strom der Heizung) oder Eintraege fuer Heizen (M2).
RequirementCheck checkHeat(Map<String, SchemaPoint> pts) => _energyCheck(
      pts: pts,
      id: 'heat',
      title: 'Heizwärme',
      meter: 'I2',
      manualMp: 'M2',
      manualWord: 'Heizen',
    );

/// Warmwasser: I1 (Strom fuers Warmwasser) oder Eintraege fuer Warmwasser (M1).
RequirementCheck checkHotWater(Map<String, SchemaPoint> pts) => _energyCheck(
      pts: pts,
      id: 'hotWater',
      title: 'Warmwasser',
      meter: 'I1',
      manualMp: 'M1',
      manualWord: 'Warmwasser',
    );

/// Wohnklima: Innentemperatur, Aussentemperatur, Luftfeuchte und CO2.
RequirementCheck checkClimate(Map<String, SchemaPoint> pts) {
  const ids = ['K1', 'K2', 'K3', 'K4'];
  final have = [for (final id in ids) if (pts[id]?.coverage.counts ?? false) id];
  final missing = [for (final id in ids) if (!have.contains(id)) id];
  if (missing.isEmpty) {
    return RequirementCheck(id: 'climate', title: 'Wohnklima', state: ReqState.met, sources: have);
  }
  final names = missing.map((id) => '${schemaLabel(id)} ($id)').join(', ');
  return RequirementCheck(
    id: 'climate',
    title: 'Wohnklima',
    state: have.isEmpty ? ReqState.missing : ReqState.partial,
    sources: have,
    warning: 'Wohnklima unvollständig: Es fehlt $names.',
  );
}
