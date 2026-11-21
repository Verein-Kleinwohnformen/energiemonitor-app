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

  /// Studienmodus: blendet alles aus, was Verbrauch zeigt. Wird vom Team in
  /// der Firebase Console gesetzt, nie in der App.
  bool studyMode;

  /// Optionaler Zusatz im Studien-Dialog, z.B. "Messjahr bis Oktober 2028".
  String? studyNote;

  EnergieMonitor({
    required this.id,
    required this.tinyhouseName,
    required this.tinyhouseLocation,
    this.studyMode = false,
    this.studyNote,
  });

  factory EnergieMonitor.fromFirebase(Map<String, dynamic> data) {
    final note = data['study_note'];
    return EnergieMonitor(
      id: data['monitor_id'],
      tinyhouseName: data['tinyhouse_name'] ?? 'Name unbekannt',
      tinyhouseLocation: data['tinyhouse_location'] ?? 'Ort unbekannt',
      studyMode: data['study_mode'] == true,
      studyNote: note is String && note.trim().isNotEmpty ? note.trim() : null,
    );
  }
}
