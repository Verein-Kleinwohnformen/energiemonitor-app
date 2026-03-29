import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum EnergyType { woodSter, woodKg, propane, pellets, oil, diesel, gasoline }

String energyTypeToString(EnergyType energyType) {
  return energyType.toString().split('.').last;
}

EnergyType energyTypeFromString(String type) {
  switch (type) {
    case 'woodSter':
      return EnergyType.woodSter;
    case 'woodKg':
      return EnergyType.woodKg;
    case 'propane':
      return EnergyType.propane;
    case 'pellets':
      return EnergyType.pellets;
    case 'oil':
      return EnergyType.oil;
    case 'diesel':
      return EnergyType.diesel;
    case 'gasoline':
      return EnergyType.gasoline;
    default:
      throw Exception("Unknown energy type: ${type}");
  }
}

class EnergyCollection {
  List<Energy> energyCol = [];

  EnergyCollection.fromSnapshot(snapshot) {
    energyCol = snapshot.data!.docs
        .map((doc) =>
            Energy.fromFirebase(doc.id, doc.data() as Map<String, dynamic>))
        .toList()
        .cast<Energy>();
    energyCol.sort((a, b) => b.purchaseDate.compareTo(a.purchaseDate));
  }

  // Create from multiple snapshots (for querying multiple years)
  EnergyCollection.fromMultipleSnapshots(List<dynamic> snapshots) {
    for (var snapshot in snapshots) {
      if (snapshot.docs.isNotEmpty) {
        energyCol.addAll(snapshot.docs
            .map((doc) =>
                Energy.fromFirebase(doc.id, doc.data() as Map<String, dynamic>))
            .toList()
            .cast<Energy>());
      }
    }
    energyCol.sort((a, b) => b.purchaseDate.compareTo(a.purchaseDate));
  }

  // Empty constructor for initialization
  EnergyCollection.empty();

  int get length => energyCol.length;

  addNew(
      {required EnergyType type,
      required String description,
      required double purchaseQuantity,
      required double leftoverQuantity,
      required String meteringPoint,
      String? userId,
      String? monitorId}) {
    Energy newEntry = Energy(
        firebaseId: '',
        typeCounter: 0,
        description: description,
        purchaseDate: DateTime.now(),
        usageDate: DateTime.now(),
        type: type,
        purchaseQuantity: purchaseQuantity,
        leftoverQuantity: leftoverQuantity,
        meteringPoint: meteringPoint,
        usageDateProvisory: true,
        userId: userId,
        monitorId: monitorId);

    // Store on firebase
    newEntry.addToFirebase();

    // Add to list
    energyCol.add(newEntry);
    // Sort the list again
    energyCol.sort((a, b) => b.purchaseDate.compareTo(a.purchaseDate));
  }
}

class Energy {
  String firebaseId;
  int typeCounter;
  String description;
  DateTime purchaseDate;
  DateTime usageDate;
  EnergyType type;
  double purchaseQuantity;
  double leftoverQuantity;
  String meteringPoint; // M0, M1, M2
  bool usageDateProvisory;
  String? userId;
  String? monitorId;

  // Default constructor with optional parameters and initialization
  Energy({
    required this.firebaseId,
    required this.typeCounter,
    required this.description,
    required this.purchaseDate,
    required this.usageDate,
    required this.type,
    required this.purchaseQuantity,
    required this.leftoverQuantity,
    required this.meteringPoint,
    this.usageDateProvisory = true,
    this.userId,
    this.monitorId,
  });

  String get imageString {
    switch (type) {
      case EnergyType.diesel:
        return 'assets/diesel.png';
      case EnergyType.woodSter:
        return 'assets/wood.png';
      case EnergyType.woodKg:
        return 'assets/wood.png';
      case EnergyType.gasoline:
        return 'assets/benzin.png';
      case EnergyType.oil:
        return 'assets/oil.png';
      case EnergyType.pellets:
        return 'assets/pellets.png';
      case EnergyType.propane:
        return 'assets/propane.png';
    }
  }

  String get displayUnit {
    switch (type) {
      case EnergyType.diesel:
        return 'Liter';
      case EnergyType.woodSter:
        return 'Ster';
      case EnergyType.woodKg:
        return 'kg';
      case EnergyType.gasoline:
        return 'Liter';
      case EnergyType.oil:
        return 'Liter';
      case EnergyType.pellets:
        return 'kg';
      case EnergyType.propane:
        return 'kg';
    }
  }

  double get consumedQuantity {
    // This getter returns a naive value (purchaseQuantity - leftoverQuantity) for
    // display/fallback purposes only. The correct persisted value is computed in
    // addToFirebase() using the previous entry's total stock.
    return purchaseQuantity - leftoverQuantity;
  }

  String get meteringPointDescription {
    switch (meteringPoint) {
      case 'M0':
        return 'Gemischt';
      case 'M1':
        return 'Warmwasser';
      case 'M2':
        return 'Heizwärme';
      default:
        return meteringPoint;
    }
  }

  String get formattedDescription {
    switch (type) {
      case EnergyType.diesel:
        return 'Diesel';
      case EnergyType.woodSter:
        return 'Holz';
      case EnergyType.woodKg:
        return 'Holz';
      case EnergyType.gasoline:
        return 'Benzin';
      case EnergyType.oil:
        return 'Heizöl';
      case EnergyType.pellets:
        return 'Pellets';
      case EnergyType.propane:
        return 'Propangas';
    }
  }

// Factory constructor to create an Energy instance from Firebase data
  factory Energy.fromFirebase(String id, Map<String, dynamic> data) {
    // Handle both old and new format
    final metadata = data['metadata'] as Map<String, dynamic>? ?? {};

    // Extract values from data_points array if present (new format)
    final dataPoints = data['data_points'] as List<dynamic>? ?? [];
    final firstPoint =
        dataPoints.isNotEmpty ? dataPoints[0] as Map<String, dynamic> : {};
    final values = firstPoint['values'] as Map<String, dynamic>? ?? {};

    // Get timestamps
    final purchaseTimestamp = metadata['purchase_date'] ??
        data['start_timestamp'] ??
        data['timestamp'];
    final usageTimestamp = metadata['estimated_usage_date'] ??
        data['end_timestamp'] ??
        data['timestamp'];

    return Energy(
      firebaseId: id,
      typeCounter: data['type_counter'] ?? 0,
      description: metadata['description'] ?? data['description'] ?? '',
      purchaseDate: purchaseTimestamp is Timestamp
          ? purchaseTimestamp.toDate()
          : DateTime.fromMillisecondsSinceEpoch(purchaseTimestamp as int),
      usageDate: usageTimestamp is Timestamp
          ? usageTimestamp.toDate()
          : DateTime.fromMillisecondsSinceEpoch(usageTimestamp as int),
      type: energyTypeFromString(
          metadata['energy_type'] ?? data['type'] ?? 'woodKg'),
      purchaseQuantity:
          (values['added_quantity'] ?? data['added_quantity'] ?? 0).toDouble(),
      leftoverQuantity:
          (values['leftover_quantity'] ?? data['leftover_quantity'] ?? 0)
              .toDouble(),
      meteringPoint: data['metering_point'] ?? 'M0',
      usageDateProvisory: metadata['usage_date_provisory'] ??
          data['usage_date_provisory'] ??
          true,
      userId: metadata['user_id'] ?? data['user_id'],
      monitorId: data['device_id'] ?? data['monitor_id'],
    );
  }

  delete() async {
    if (monitorId == null) return;

    final year = purchaseDate.year;
    await FirebaseFirestore.instance
        .collection('devices')
        .doc(monitorId)
        .collection('manual')
        .doc(year.toString())
        .collection('data')
        .doc(firebaseId)
        .delete();
  }

  Future<void> addToFirebase() async {
    if (monitorId == null) {
      throw Exception('Monitor ID is required');
    }

    final db = FirebaseFirestore.instance;
    final year = purchaseDate.year;

    // Generate UUID for document ID
    final uuid = _generateUuid();

    // Calculate timestamps in milliseconds
    final purchaseTimestamp = purchaseDate.millisecondsSinceEpoch;
    final usageTimestamp = usageDate.millisecondsSinceEpoch;
    final createdAt = DateTime.now().toUtc().toIso8601String();

    // Create document structure matching API format
    final documentData = {
      'sensor_id': 'app_form',
      'device_id': monitorId,
      'metering_point': meteringPoint,
      'date': purchaseDate.toIso8601String().split('T')[0],
      'day': purchaseDate.day,
      'year': year,
      'start_timestamp': purchaseTimestamp,
      'end_timestamp': purchaseTimestamp,
      'data_points': [
        {
          'timestamp': purchaseTimestamp,
          'values': {
            'added_quantity': purchaseQuantity,
            'leftover_quantity': leftoverQuantity,
            'consumed_quantity': await _computeConsumedQuantity(
                db, monitorId!, meteringPoint, type),
            'unit': displayUnit,
          }
        }
      ],
      'count': 1,
      'created_at': createdAt,
      'metadata': {
        'description': description,
        'purchase_date': purchaseTimestamp,
        'estimated_usage_date': usageTimestamp,
        'usage_date_provisory': usageDateProvisory,
        'user_id': userId,
        'energy_type': energyTypeToString(type),
      }
    };

    // Write to Firestore: /devices/{device_id}/manual/{year}/{uuid}
    // year is a COLLECTION, uuid is a DOCUMENT
    await db
        .collection('devices')
        .doc(monitorId)
        .collection('manual')
        .doc(year.toString())
        .collection('data')
        .doc(uuid)
        .set(documentData);

    // Update firebaseId for this instance
    firebaseId = uuid;

    // Update metering point metadata
    await _updateMeteringPointMetadata(
        db, monitorId!, meteringPoint, purchaseTimestamp);

    // Update previous entry's estimated usage date
    await _updatePreviousEntryUsageDate(db, monitorId!, meteringPoint, type);
  }

  /// Computes how much was consumed from the previous entry's stock until now.
  /// Formula: prevEntry.addedQuantity + prevEntry.leftoverQuantity - currentEntry.leftoverQuantity
  /// Returns 0 if no previous entry exists.
  Future<double> _computeConsumedQuantity(FirebaseFirestore db, String deviceId,
      String meteringPoint, EnergyType energyType) async {
    final currentYear = purchaseDate.year;

    for (final year in [currentYear, currentYear - 1]) {
      final snapshot = await db
          .collection('devices')
          .doc(deviceId)
          .collection('manual')
          .doc(year.toString())
          .collection('data')
          .get();

      _TelemetryCandidate? best;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final metadata = data['metadata'] as Map<String, dynamic>? ?? {};
        if (data['metering_point'] != meteringPoint) continue;
        if (metadata['energy_type'] != energyTypeToString(energyType)) continue;

        final ts = metadata['purchase_date'] as int?;
        if (ts == null) continue;
        final entryDate = DateTime.fromMillisecondsSinceEpoch(ts);
        if (!entryDate.isBefore(purchaseDate)) continue;

        // Pick the most recent entry before the current one
        if (best == null || ts > best.timestamp) {
          final dataPoints = data['data_points'] as List<dynamic>? ?? [];
          final firstPoint = dataPoints.isNotEmpty
              ? dataPoints[0] as Map<String, dynamic>
              : <String, dynamic>{};
          final values = firstPoint['values'] as Map<String, dynamic>? ?? {};
          final prevAdded =
              (values['added_quantity'] ?? 0).toDouble() as double;
          final prevLeftover =
              (values['leftover_quantity'] ?? 0).toDouble() as double;
          best = _TelemetryCandidate(ts, prevAdded + prevLeftover);
        }
      }

      if (best != null) {
        final consumed = best.prevTotal - leftoverQuantity;
        return consumed < 0 ? 0 : consumed;
      }
    }

    // No previous entry — nothing consumed yet
    return 0;
  }

  String _generateUuid() {
    // Simple UUID v4 generation (you might want to use a package like 'uuid')
    final random = DateTime.now().microsecondsSinceEpoch;
    return '$random-${meteringPoint}-${energyTypeToString(type)}';
  }

  Future<void> _updateMeteringPointMetadata(FirebaseFirestore db,
      String deviceId, String meteringPoint, int timestamp) async {
    final mpRef = db
        .collection('devices')
        .doc(deviceId)
        .collection('metering_points')
        .doc(meteringPoint);

    final mpDoc = await mpRef.get();

    if (mpDoc.exists) {
      // Update existing metering point
      await mpRef.update({
        'last_seen': timestamp,
        'sensor_types': FieldValue.arrayUnion(['app_form']),
      });
    } else {
      // Create new metering point metadata
      await mpRef.set({
        'metering_point': meteringPoint,
        'device_id': deviceId,
        'sensor_types': ['app_form'],
        'first_seen': timestamp,
        'last_seen': timestamp,
        'value_fields': [
          'added_quantity',
          'leftover_quantity',
          'consumed_quantity',
          'unit'
        ],
        'description': meteringPointDescription,
      });
    }
  }

  Future<void> _updatePreviousEntryUsageDate(FirebaseFirestore db,
      String deviceId, String meteringPoint, EnergyType energyType) async {
    // Find the previous entry with same metering point and energy type
    // that is provisory and occurred before this entry

    // Query the current year and previous year
    final currentYear = purchaseDate.year;
    final previousYear = currentYear - 1;

    for (final year in [currentYear, previousYear]) {
      final snapshot = await db
          .collection('devices')
          .doc(deviceId)
          .collection('manual')
          .doc(year.toString())
          .collection('data')
          .get();

      // Find matching entries
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final metadata = data['metadata'] as Map<String, dynamic>? ?? {};

        // Check if this entry matches our criteria
        if (data['metering_point'] == meteringPoint &&
            metadata['energy_type'] == energyTypeToString(energyType) &&
            metadata['usage_date_provisory'] == true) {
          final entryPurchaseTimestamp = metadata['purchase_date'] as int;
          final entryPurchaseDate =
              DateTime.fromMillisecondsSinceEpoch(entryPurchaseTimestamp);

          // Check if this entry is before our current entry
          if (entryPurchaseDate.isBefore(purchaseDate)) {
            // Calculate the actual usage date
            final actualUsageDate = purchaseDate;
            final actualUsageTimestamp = actualUsageDate.millisecondsSinceEpoch;

            // Update the previous entry's estimated_usage_date to actual
            await db
                .collection('devices')
                .doc(deviceId)
                .collection('manual')
                .doc(year.toString())
                .collection('data')
                .doc(doc.id)
                .update({
              'metadata.estimated_usage_date': actualUsageTimestamp,
              'metadata.usage_date_provisory': false,
            });

            // We found and updated the previous entry, so we're done
            return;
          }
        }
      }
    }
  }

  // toString method for a readable format
  @override
  String toString() {
    final dateFormatter = DateFormat('yyyy-MM-dd');
    return 'Energy(counter: $typeCounter, description: "$description", purchaseDate: ${dateFormatter.format(purchaseDate)}, usageDate: ${dateFormatter.format(usageDate)}, type: $type, purchaseQuantity: $purchaseQuantity, leftoverQuantity: $leftoverQuantity)';
  }
}

/// Lightweight helper used by [Energy._computeConsumedQuantity].
class _TelemetryCandidate {
  final int timestamp;
  final double
      prevTotal; // addedQuantity + leftoverQuantity of the previous entry

  _TelemetryCandidate(this.timestamp, this.prevTotal);
}
