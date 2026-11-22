// Startbildschirm: Aufbau, Bewegung der Balken, ruhig bei reduzierter Bewegung.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kwf_energiemonitor/shell/app_icon.dart';
import 'package:kwf_energiemonitor/shell/splash_view.dart';

import '../support/test_app.dart';

Widget _host({bool reduceMotion = false}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: const Size(390, 844), disableAnimations: reduceMotion),
        child: const SplashView(),
      ),
    );

void main() {
  setUpAll(loadAppFonts);

  test('Balken schwingen zwischen voller und 45 % Hoehe', () {
    expect(AppIconPainter.barFactor(0), 1.0);
    expect(AppIconPainter.barFactor(0.5), closeTo(0.45, 1e-9));
    expect(AppIconPainter.barFactor(1.0), 1.0);
    for (var p = 0.0; p < 1; p += 0.05) {
      final f = AppIconPainter.barFactor(p);
      expect(f, inInclusiveRange(0.45, 1.0));
    }
  });

  testWidgets('Name, Zeile und Icon, Balken bewegen sich', (tester) async {
    await setPhoneSize(tester, size: const Size(390, 844));
    await tester.pumpWidget(_host());
    expect(find.text('Energiemonitor'), findsOneWidget);
    expect(find.text('Energie und Raumklima\ndeiner Kleinwohnform'), findsOneWidget);
    final icon = find.byType(KwfAppIcon);
    expect(icon, findsOneWidget);
    AppIconPainter painter() => tester
        .widget<CustomPaint>(find.descendant(of: icon, matching: find.byType(CustomPaint)))
        .painter! as AppIconPainter;
    final first = painter().phase;
    await tester.pump(const Duration(milliseconds: 400));
    expect(painter().phase, isNot(first));
    expect(painter().animated, isTrue);
  });

  testWidgets('bei reduzierter Bewegung steht alles still', (tester) async {
    await setPhoneSize(tester, size: const Size(390, 844));
    await tester.pumpWidget(_host(reduceMotion: true));
    await tester.pump(const Duration(milliseconds: 400));
    final p = tester
        .widget<CustomPaint>(
            find.descendant(of: find.byType(KwfAppIcon), matching: find.byType(CustomPaint)))
        .painter! as AppIconPainter;
    expect(p.animated, isFalse);
    expect(tester.hasRunningAnimations, isFalse);
  });
}
