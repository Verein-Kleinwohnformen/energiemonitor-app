import 'package:cloud_firestore/cloud_firestore.dart';

Future<EnergieMonitor?> fetchMonitor(String monitorId) async {
  try {
    final monitorDoc = await FirebaseFirestore.instance
        .collection('monitors')
        .doc(monitorId)
        .get();

    if (monitorDoc.exists) {
      // Retrieve the data as a Map
      Map<String, dynamic> monitorData =
          monitorDoc.data() as Map<String, dynamic>;
      final emon = EnergieMonitor.fromFirebase(monitorData);

      return emon;
    }
  } on Exception catch (e) {
    print(e);
  }
  return null;
}

class EnergieMonitor {
  String id;
  String tinyhouseName;
  String tinyhouseLocation;

  EnergieMonitor({
    required this.id,
    required this.tinyhouseName,
    required this.tinyhouseLocation,
  });

  factory EnergieMonitor.fromFirebase(Map<String, dynamic> data) {
    return EnergieMonitor(
      id: data['monitor_id'],
      tinyhouseName: data['tinyhouse_name'] ?? 'Name unbekannt',
      tinyhouseLocation: data['tinyhouse_location'] ?? 'Ort unbekannt',
    );
  }
}
