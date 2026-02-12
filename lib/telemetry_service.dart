import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kwf_energiemonitor/telemetry.dart';

/// Service for fetching telemetry data from Firestore
class TelemetryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetches telemetry data from Firestore
  /// Path: /devices/{deviceId}/telemetry/{year}/{month}/{uuid}
  ///
  /// Parameters:
  /// - deviceId: The device/monitor ID
  /// - meteringPoint: Filter by metering point (e.g., "E1")
  /// - sensorId: Filter by sensor ID (e.g., "shelly-3em-pro")
  /// - startDate: Start date (inclusive)
  /// - endDate: End date (inclusive)
  ///
  /// Returns a flat list of all data points sorted by timestamp
  Future<List<TelemetryDataPoint>> fetchTelemetryData({
    required String deviceId,
    required String meteringPoint,
    required String sensorId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      // Extract year/month ranges to query
      final queryParams = _buildQueryParams(startDate, endDate);

      final List<TelemetryDataPoint> allDataPoints = [];

      // Query each year/month combination
      for (final param in queryParams) {
        final year = param['year'] as int;
        final month = param['month'] as int;
        final startDay = param['startDay'] as int;
        final endDay = param['endDay'] as int;

        final monthStr = month.toString().padLeft(2, '0');

        // Query Firestore with filters
        final snapshot = await _firestore
            .collection('devices')
            .doc(deviceId)
            .collection('telemetry')
            .doc(year.toString())
            .collection(monthStr)
            .where('metering_point', isEqualTo: meteringPoint)
            .where('sensor_id', isEqualTo: sensorId)
            .where('day', isGreaterThanOrEqualTo: startDay)
            .where('day', isLessThanOrEqualTo: endDay)
            .get();

        // Extract data points from batch documents
        for (var doc in snapshot.docs) {
          final batch = TelemetryBatch.fromFirestore(doc.id, doc.data());

          // Filter data points by exact timestamp range
          final filteredPoints = batch.dataPoints.where((point) {
            return point.timestamp >= startDate.millisecondsSinceEpoch &&
                point.timestamp <= endDate.millisecondsSinceEpoch;
          }).toList();

          allDataPoints.addAll(filteredPoints);
        }
      }

      // Sort by timestamp (ascending)
      allDataPoints.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      return allDataPoints;
    } catch (e) {
      print('Error fetching telemetry data: $e');
      rethrow;
    }
  }

  /// Builds query parameters for year/month/day ranges
  /// Returns a list of maps with year, month, startDay, endDay
  List<Map<String, int>> _buildQueryParams(
      DateTime startDate, DateTime endDate) {
    final List<Map<String, int>> params = [];

    DateTime current = DateTime(startDate.year, startDate.month, 1);
    final end = DateTime(endDate.year, endDate.month, 1);

    while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
      final isStartMonth =
          current.year == startDate.year && current.month == startDate.month;
      final isEndMonth =
          current.year == endDate.year && current.month == endDate.month;

      final startDay = isStartMonth ? startDate.day : 1;
      final endDay = isEndMonth
          ? endDate.day
          : DateTime(current.year, current.month + 1, 0).day;

      params.add({
        'year': current.year,
        'month': current.month,
        'startDay': startDay,
        'endDay': endDay,
      });

      // Move to next month
      current = DateTime(current.year, current.month + 1, 1);
    }

    return params;
  }

  /// Get all available value fields from a list of data points
  Set<String> extractValueFields(List<TelemetryDataPoint> dataPoints) {
    final Set<String> fields = {};
    for (final point in dataPoints) {
      fields.addAll(point.values.keys);
    }
    return fields;
  }

  /// Calculate min/max values for a specific field
  Map<String, double> calculateMinMax(
    List<TelemetryDataPoint> dataPoints,
    String field,
  ) {
    if (dataPoints.isEmpty) {
      return {'min': 0, 'max': 0};
    }

    double? min;
    double? max;

    for (final point in dataPoints) {
      final value = point.values[field];
      if (value != null) {
        min = min == null ? value : (value < min ? value : min);
        max = max == null ? value : (value > max ? value : max);
      }
    }

    return {
      'min': min ?? 0,
      'max': max ?? 0,
    };
  }
}
