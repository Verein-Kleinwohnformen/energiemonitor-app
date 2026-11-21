@TestOn('browser')
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Emulator erreichbar', () async {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'demo-key',
        appId: '1:1:web:1',
        messagingSenderId: '1',
        projectId: 'demo-energiemonitor',
      ),
    );
    FirebaseFirestore.instance.useFirestoreEmulator('127.0.0.1', 8080);
    await FirebaseFirestore.instance.collection('smoke').doc('a').set({'x': 1});
    final d = await FirebaseFirestore.instance.collection('smoke').doc('a').get();
    expect(d.data()!['x'], 1);
  });
}
