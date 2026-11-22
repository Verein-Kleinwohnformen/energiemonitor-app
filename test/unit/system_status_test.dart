import 'package:flutter_test/flutter_test.dart';
import 'package:kwf_energiemonitor/status/system_status.dart';

import '../support/test_app.dart';

void main() {
  test('Schwellen 90 min und 6 h', () {
    expect(linkStateFor(kNow.subtract(const Duration(minutes: 89)), kNow), LinkState.online);
    expect(linkStateFor(kNow.subtract(const Duration(minutes: 90)), kNow), LinkState.delayed);
    expect(linkStateFor(kNow.subtract(const Duration(hours: 6)), kNow), LinkState.delayed);
    expect(linkStateFor(kNow.subtract(const Duration(hours: 6, minutes: 1)), kNow),
        LinkState.offline);
  });

  test('alles online: Alles laeuft mit Zeit', () {
    final s = SystemStatus.fromPoints(samplePoints(), kNow);
    expect(s.overall, LinkState.online);
    expect(s.pillText, 'Alles läuft · 14:00');
    expect(s.manual.single.id, 'M2');
    expect(s.automatic.any((p) => p.id == 'M2'), isFalse);
  });

  test('schlechtester Status zaehlt', () {
    final s = SystemStatus.fromPoints([
      point('E1', kNow.subtract(const Duration(minutes: 10))),
      point('K0', kNow.subtract(const Duration(hours: 3))),
    ], kNow);
    expect(s.overall, LinkState.delayed);
    expect(s.pillText, '1 Messpunkt verzögert');
  });

  test('alles offline: seit wann', () {
    final s =
        SystemStatus.fromPoints([point('E1', kNow.subtract(const Duration(hours: 8)))], kNow);
    expect(s.pillText, 'Keine Daten seit 8 h');
  });

  test('Messpunkt ohne Daten seit 30 Tagen zaehlt nicht', () {
    final s = SystemStatus.fromPoints([
      point('E1', kNow.subtract(const Duration(minutes: 10))),
      point('D1', kNow.subtract(const Duration(days: 31))),
    ], kNow);
    expect(s.automatic.map((p) => p.id), ['E1']);
    expect(s.overall, LinkState.online);
  });

  test('ohne Daten', () {
    final s = SystemStatus.fromPoints(const [], kNow);
    expect(s.overall, isNull);
    expect(s.pillText, 'Noch keine Daten');
  });

  test('Zeit: heute, gestern, sonst Datum', () {
    expect(formatTime(DateTime(2026, 11, 21, 9, 5), kNow), '09:05');
    expect(formatTime(DateTime(2026, 11, 20, 9, 5), kNow), 'gestern 09:05');
    expect(formatTime(DateTime(2026, 11, 2, 9, 5), kNow), '2.11. 09:05');
  });
}
