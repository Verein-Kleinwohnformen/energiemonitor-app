// Golden-Test Erfassen (Konzept Umsetzung, Abschnitt 5): Die Seite Erfassen
// muss im normalen Modus und im Studienmodus pixelgleich sein.
//
// Gerendert wird, was auf der Seite steht: Kopfzeile und Inhalt. Die
// Tab-Leiste unterscheidet sich bewusst (4 oder 2 Tabs) und gehoert nicht dazu.
//
// Neu erzeugen: flutter test --update-goldens test/golden
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kwf_energiemonitor/app/session.dart';
import 'package:kwf_energiemonitor/capture/capture_page.dart';
import 'package:kwf_energiemonitor/shell/app_header.dart';

import '../support/test_app.dart';

const _boundary = ValueKey('erfassen');

Widget _page(AppSession session, {FakeEntries? entries}) => wrap(
      const Scaffold(
        body: RepaintBoundary(
          key: _boundary,
          child: Column(
            children: [AppHeader(), Expanded(child: CapturePage())],
          ),
        ),
      ),
      session: session,
      entries: entries,
    );

Future<Uint8List> _pixels(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_boundary));
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return data!.buffer.asUint8List();
  });
  return bytes!;
}

void main() {
  setUpAll(loadAppFonts);

  final modes = <String, SessionData Function()>{
    'normaler Modus': () => sessionData(),
    'Studienmodus': () => sessionData(study: true),
    'Studienmodus, Superadmin': () => sessionData(study: true, superadmin: true),
  };

  testWidgets('Erfassen ist in allen Modi pixelgleich', (tester) async {
    await setPhoneSize(tester);
    final images = <String, Uint8List>{};
    for (final mode in modes.entries) {
      await tester.pumpWidget(_page(AppSession.fixed(mode.value())));
      await tester.pumpAndSettle();
      // Jeder Modus gegen dieselbe Golden-Datei.
      await expectLater(find.byKey(_boundary), matchesGoldenFile('goldens/erfassen.png'));
      images[mode.key] = await _pixels(tester);
      await tester.pumpWidget(const SizedBox());
    }
    final reference = images['normaler Modus']!;
    images.forEach((mode, pixels) {
      expect(pixels, reference, reason: 'Erfassen sieht im $mode anders aus');
    });
  });

  testWidgets('nur Leserechte: kein Knopf, Hinweis wie bisher', (tester) async {
    await setPhoneSize(tester);
    for (final study in [false, true]) {
      await tester.pumpWidget(_page(AppSession.fixed(sessionData(canEdit: false, study: study))));
      await tester.pumpAndSettle();
      expect(find.text('ENERGIETRÄGER ERFASSEN'), findsNothing);
      expect(find.text('Du kannst bei diesem Monitor keine Daten hinzufügen.'), findsOneWidget);
      await expectLater(find.byKey(_boundary), matchesGoldenFile('goldens/erfassen_nur_lesen.png'));
    }
  });

  testWidgets('ohne Einträge', (tester) async {
    await setPhoneSize(tester);
    await tester.pumpWidget(_page(AppSession.fixed(sessionData()), entries: FakeEntries([])));
    await tester.pumpAndSettle();
    expect(find.textContaining('Noch keine Einträge'), findsOneWidget);
    await expectLater(find.byKey(_boundary), matchesGoldenFile('goldens/erfassen_leer.png'));
  });
}
