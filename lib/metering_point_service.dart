import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kwf_energiemonitor/metering_point.dart';

/// Service für Zugriff auf Firestore
class MeteringPointService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Lädt alle Messpunkte für ein Device (Monitor)
  /// Pfad: devices/{deviceId}/metering_points
  Future<List<MeteringPoint>> fetchMeteringPoints(String deviceId) async {
    try {
      final snapshot = await _firestore
          .collection('devices')
          .doc(deviceId)
          .collection('metering_points')
          .get();

      if (snapshot.docs.isEmpty) {
        return [];
      }

      final List<MeteringPoint> meteringPoints = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final meteringPoint =
            MeteringPoint.fromFirestore(deviceId, doc.id, data);

        // Manuelle Messpunkte (M-Prefix) immer anzeigen
        // Andere Messpunkte nur wenn in den letzten 30 Tagen aktiv
        if (meteringPoint.meteringPointId.startsWith('M') ||
            meteringPoint.isActive) {
          meteringPoints.add(meteringPoint);
        }
      }

      // Sortiere nach Messpunkt-ID (E1, E2, E3, I1, I2, I3, ...)
      meteringPoints.sort((a, b) =>
          _compareMeteringPointIds(a.meteringPointId, b.meteringPointId));

      return meteringPoints;
    } catch (e) {
      print('Error fetching metering points: $e');
      return [];
    }
  }

  /// Vergleicht Messpunkt-IDs für Sortierung
  /// E1 < E2 < E3 < I1 < I2 < I3 < M1 < M2 < D1 < K0 < K1 < K2 < K3 < K4 < A1 < NA
  int _compareMeteringPointIds(String a, String b) {
    // Extrahiere Prefix (Buchstabe) und Nummer
    final aMatch = RegExp(r'^([A-Z]+)(\d*)$').firstMatch(a);
    final bMatch = RegExp(r'^([A-Z]+)(\d*)$').firstMatch(b);

    if (aMatch == null || bMatch == null) {
      return a.compareTo(b);
    }

    final aPrefix = aMatch.group(1) ?? '';
    final bPrefix = bMatch.group(1) ?? '';
    final aNumber = int.tryParse(aMatch.group(2) ?? '0') ?? 0;
    final bNumber = int.tryParse(bMatch.group(2) ?? '0') ?? 0;

    // Erst nach Prefix sortieren
    if (aPrefix != bPrefix) {
      // Definiere Reihenfolge: E, I, M, D, K, A, NA
      const prefixOrder = ['E', 'I', 'M', 'D', 'K', 'A', 'NA'];
      final aIndex = prefixOrder.indexOf(aPrefix);
      final bIndex = prefixOrder.indexOf(bPrefix);

      if (aIndex != -1 && bIndex != -1) {
        return aIndex.compareTo(bIndex);
      }
      return aPrefix.compareTo(bPrefix);
    }

    // Dann nach Nummer sortieren
    return aNumber.compareTo(bNumber);
  }

  /// Stream für Echtzeit-Updates der Messpunkte
  Stream<List<MeteringPoint>> streamMeteringPoints(String deviceId) {
    return _firestore
        .collection('devices')
        .doc(deviceId)
        .collection('metering_points')
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) {
        return <MeteringPoint>[];
      }

      final List<MeteringPoint> meteringPoints = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final meteringPoint =
            MeteringPoint.fromFirestore(deviceId, doc.id, data);

        // Manuelle Messpunkte (M-Prefix) immer anzeigen
        // Andere Messpunkte nur wenn in den letzten 30 Tagen aktiv
        if (meteringPoint.meteringPointId.startsWith('M') ||
            meteringPoint.isActive) {
          meteringPoints.add(meteringPoint);
        }
      }

      // Sortiere nach Messpunkt-ID
      meteringPoints.sort((a, b) =>
          _compareMeteringPointIds(a.meteringPointId, b.meteringPointId));

      return meteringPoints;
    });
  }
}
