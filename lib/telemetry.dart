import 'package:intl/intl.dart';

/// Represents a single telemetry data point from Firestore
class TelemetryDataPoint {
  final int timestamp; // milliseconds since epoch
  final Map<String, double>
      values; // e.g., {"voltage": 231.5, "act_power": 15.2}
  final String meteringPoint; // e.g., "E1"
  final String sensorId; // e.g., "shelly-3em-pro"

  TelemetryDataPoint({
    required this.timestamp,
    required this.values,
    required this.meteringPoint,
    required this.sensorId,
  });

  /// Parse from a single data point within a Firestore batch document
  factory TelemetryDataPoint.fromMap(
    Map<String, dynamic> map,
    String meteringPoint,
    String sensorId,
  ) {
    final valuesMap = map['values'] as Map<String, dynamic>? ?? {};

    // Filter out null values and convert to double
    final filteredValues = <String, double>{};
    valuesMap.forEach((key, value) {
      if (value != null && value is num) {
        filteredValues[key] = value.toDouble();
      }
    });

    return TelemetryDataPoint(
      timestamp: map['timestamp'] as int,
      values: filteredValues,
      meteringPoint: meteringPoint,
      sensorId: sensorId,
    );
  }

  /// Convert timestamp to DateTime
  DateTime get dateTime => DateTime.fromMillisecondsSinceEpoch(timestamp);

  /// Format timestamp as readable date/time
  String formatDateTime({String pattern = 'dd.MM HH:mm'}) {
    return DateFormat(pattern).format(dateTime);
  }

  /// Format timestamp for chart display (short format)
  String formatForChart({bool showDate = false}) {
    if (showDate) {
      return DateFormat('dd.MM\nHH:mm').format(dateTime);
    } else {
      return DateFormat('HH:mm').format(dateTime);
    }
  }

  @override
  String toString() {
    return 'TelemetryDataPoint(timestamp: $timestamp, meteringPoint: $meteringPoint, sensorId: $sensorId, values: $values)';
  }
}

/// Represents a batch document from Firestore
class TelemetryBatch {
  final String documentId;
  final String sensorId;
  final String deviceId;
  final String meteringPoint;
  final String date;
  final int day;
  final int startTimestamp;
  final int endTimestamp;
  final List<TelemetryDataPoint> dataPoints;
  final int count;
  final String? createdAt;

  TelemetryBatch({
    required this.documentId,
    required this.sensorId,
    required this.deviceId,
    required this.meteringPoint,
    required this.date,
    required this.day,
    required this.startTimestamp,
    required this.endTimestamp,
    required this.dataPoints,
    required this.count,
    this.createdAt,
  });

  /// Parse from Firestore document
  factory TelemetryBatch.fromFirestore(
      String docId, Map<String, dynamic> data) {
    final meteringPoint = data['metering_point'] as String;
    final sensorId = data['sensor_id'] as String;

    final dataPointsList = (data['data_points'] as List<dynamic>?)
            ?.map((point) => TelemetryDataPoint.fromMap(
                  point as Map<String, dynamic>,
                  meteringPoint,
                  sensorId,
                ))
            .toList() ??
        [];

    return TelemetryBatch(
      documentId: docId,
      sensorId: sensorId,
      deviceId: data['device_id'] as String,
      meteringPoint: meteringPoint,
      date: data['date'] as String,
      day: data['day'] as int,
      startTimestamp: data['start_timestamp'] as int,
      endTimestamp: data['end_timestamp'] as int,
      dataPoints: dataPointsList,
      count: data['count'] as int,
      createdAt: data['created_at'] as String?,
    );
  }

  @override
  String toString() {
    return 'TelemetryBatch(docId: $documentId, meteringPoint: $meteringPoint, sensorId: $sensorId, date: $date, count: $count)';
  }
}
