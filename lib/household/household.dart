// Haushalt: Personen und Wohnflaeche eines Monitors, mit Verlauf.
//
// Pfad /monitors/{monitorId}/household/{id}. Eintraege werden nur angelegt,
// nie geaendert oder geloescht. Eine Aenderung ist ein neuer Eintrag mit
// "gueltig ab", damit fuer die Studie nachvollziehbar bleibt, wann sich der
// Haushalt geaendert hat.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class HouseholdEntry {
  const HouseholdEntry({
    required this.validFrom,
    required this.persons,
    this.livingAreaM2,
    this.labelWPerPerson,
    this.updatedBy,
    this.updatedAt,
  });

  /// Kalendertag (Lokalzeit), ab dem die Angaben gelten.
  final DateTime validFrom;
  final int persons;
  final double? livingAreaM2;
  final double? labelWPerPerson;
  final String? updatedBy;
  final DateTime? updatedAt;

  String get validFromKey => DateFormat('yyyy-MM-dd').format(validFrom);

  /// Dokument-ID: Datum plus Zeitpunkt der Erfassung. So ist auch eine
  /// Korrektur am selben Tag ein neuer Eintrag und kein Ueberschreiben.
  String docIdAt(DateTime createdAt) => '${validFromKey}_${createdAt.millisecondsSinceEpoch}';

  Map<String, Object?> toFirestore({required String uid}) => {
        'valid_from': validFromKey,
        'persons': persons,
        if (livingAreaM2 != null) 'living_area_m2': livingAreaM2,
        if (labelWPerPerson != null) 'label_w_per_person': labelWPerPerson,
        'updated_by': uid,
        'updated_at': FieldValue.serverTimestamp(),
      };

  static HouseholdEntry? fromFirestore(Map<String, dynamic> data) {
    final from = DateTime.tryParse('${data['valid_from']}');
    final persons = data['persons'];
    if (from == null || persons is! num) return null;
    final at = data['updated_at'];
    return HouseholdEntry(
      validFrom: DateTime(from.year, from.month, from.day),
      persons: persons.toInt(),
      livingAreaM2: (data['living_area_m2'] as num?)?.toDouble(),
      labelWPerPerson: (data['label_w_per_person'] as num?)?.toDouble(),
      updatedBy: data['updated_by'] as String?,
      updatedAt: at is Timestamp ? at.toDate() : null,
    );
  }

  /// Kurzfassung fuer Listen: "2 Personen, 16 m², Label 90 W".
  String get summary {
    final parts = <String>[persons == 1 ? '1 Person' : '$persons Personen'];
    if (livingAreaM2 != null) parts.add('${_num(livingAreaM2!)} m²');
    if (labelWPerPerson != null) parts.add('Label ${_num(labelWPerPerson!)} W');
    return parts.join(', ');
  }
}

String _num(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

/// Der Eintrag, der an [day] gilt: der juengste mit valid_from <= day.
/// Bei gleichem Datum gewinnt der zuletzt erfasste.
HouseholdEntry? householdAt(List<HouseholdEntry> entries, DateTime day) {
  final d = DateTime(day.year, day.month, day.day);
  HouseholdEntry? best;
  for (final e in entries) {
    if (e.validFrom.isAfter(d)) continue;
    if (best == null ||
        e.validFrom.isAfter(best.validFrom) ||
        (e.validFrom == best.validFrom &&
            (e.updatedAt ?? DateTime(0)).isAfter(best.updatedAt ?? DateTime(0)))) {
      best = e;
    }
  }
  return best;
}
