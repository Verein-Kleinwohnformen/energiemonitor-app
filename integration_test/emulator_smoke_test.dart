import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

void main() {
  setUpIntegrationReporting();

  testWidgets('Emulator erreichbar', (tester) async {
    await initEmulatorFirebase();
    final ref = FirebaseFirestore.instance.collection('smoke').doc('a');
    await ref.set({'x': 1});
    expect((await ref.get()).data()!['x'], 1);
  });
}
