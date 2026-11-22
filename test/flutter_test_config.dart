// Gilt fuer alle Tests unter test/.
//
// Golden-Dateien werden nur unter Linux verglichen (siehe kGoldenFiles in
// test/support/test_app.dart); Abweichungen bis 0.5 % werden toleriert.
// Dass Erfassen im normalen und im Studienmodus gleich aussieht, prueft der
// Golden-Test zusaetzlich exakt, Bild gegen Bild im selben Lauf.
import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:flutter_test/flutter_test.dart';

const kGoldenTolerance = 0.005;

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final current = goldenFileComparator;
  if (current is LocalFileComparator) {
    goldenFileComparator = _TolerantComparator(Uri.parse('${current.basedir}test.dart'));
  }
  await testMain();
}

class _TolerantComparator extends LocalFileComparator {
  _TolerantComparator(super.testFile);

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(imageBytes, await getGoldenBytes(golden));
    if (result.passed || result.diffPercent <= kGoldenTolerance) {
      result.dispose();
      return true;
    }
    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}
