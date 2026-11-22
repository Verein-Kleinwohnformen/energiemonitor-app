// Datenqualitaet eines Messpunkts (z.B. Wassertank D1), uebernommen aus der
// bisherigen App, und ihre Anzeige im Systemstatus.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kwf_energiemonitor/app/session.dart';
import 'package:kwf_energiemonitor/more/more_page.dart';
import 'package:kwf_energiemonitor/metering_point.dart';
import 'package:kwf_energiemonitor/status/system_status.dart';

import '../support/test_app.dart';

void main() {
  final now = kNow.millisecondsSinceEpoch;

  MeteringPoint mp(Map<String, dynamic>? quality) => MeteringPoint.fromFirestore('emon01', 'D1', {
        'first_seen': now,
        'last_seen': now - 20 * 60 * 1000,
        'sensor_types': ['apollon'],
        'value_fields': ['level_liter'],
        if (quality != null) 'data_quality': quality,
      });

  test('kein data_quality-Feld: keine Warnung', () {
    expect(mp(null).dataQuality, isNull);
    expect(mp(null).hasQualityWarningAt(kNow), isFalse);
  });

  test('degraded und aktuell: Warnung mit Anteil', () {
    final p = mp({
      'status': 'degraded',
      'tof_status': 2,
      'ok_ratio': 0.67,
      'since': now - 3600000,
      'updated_at': now,
    });
    expect(p.hasQualityWarningAt(kNow), isTrue);
    expect(p.dataQuality!.tofStatus, 2);
    expect(p.dataQuality!.describe(), contains('67 %'));
  });

  test('ok: keine Warnung', () {
    expect(mp({'status': 'ok', 'since': now, 'updated_at': now}).hasQualityWarningAt(kNow), isFalse);
  });

  test('veraltete Meldung (> 24 h): keine Warnung', () {
    final old = now - 2 * 24 * 3600000;
    expect(mp({'status': 'no_valid_data', 'since': old, 'updated_at': old}).hasQualityWarningAt(kNow),
        isFalse);
  });

  test('Systemstatus zeigt die Warnung beim Messpunkt', () {
    final s = SystemStatus.fromPoints([
      mp({'status': 'no_valid_data', 'since': now - 7200000, 'updated_at': now}),
      point('E1', kNow.subtract(const Duration(minutes: 10))),
    ], kNow);
    expect(s.qualityWarnings.map((p) => p.id), ['D1']);
    expect(s.qualityWarnings.single.quality!.describe(), startsWith('Keine gültige Messung seit'));
    expect(s.automatic.singleWhere((p) => p.id == 'E1').quality, isNull);
  });

  testWidgets('Mehr zeigt die Warnung im Systemstatus', (tester) async {
    await setPhoneSize(tester, size: const Size(390, 1200));
    await tester.pumpWidget(wrap(
      const Scaffold(body: MorePage()),
      session: AppSession.fixed(sessionData()),
      status: FakeStatus([
        mp({'status': 'degraded', 'ok_ratio': 0.67, 'since': now - 3600000, 'updated_at': now}),
        point('E1', kNow.subtract(const Duration(minutes: 10))),
      ]),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Datenqualität: Schwaches Messsignal: 67 %'), findsOneWidget);
  });
}
