// Systemstatus: kommen Daten an? Reine Logik, ohne Firestore.
//
// Schwellen nach Konzept (Navigation und UX, 5.5; Daten und Widgets, 3.7):
// online, wenn die letzten Daten juenger als 90 min sind (Upload stuendlich
// plus Reserve), verzoegert bis 6 h, danach offline. Automatische Messpunkte
// ohne Daten in den letzten 30 Tagen zaehlen nicht mit, damit ein abgebauter
// Sensor nicht ewig rot leuchtet.
//
// Einschraenkung: last_seen gibt es nur pro Messpunkt. Unter K0 laufen
// mehrere Sensoren, ein Ausfall nur der Netatmo bleibt hier unsichtbar.
// TODO(prüfen): Schwellen an upload_interval_min koppeln, sobald es das Feld gibt.
import 'package:intl/intl.dart';

import '../metering_point.dart';

enum LinkState { online, delayed, offline }

const kOnlineLimit = Duration(minutes: 90);
const kDelayedLimit = Duration(hours: 6);
const kActiveWindow = Duration(days: 30);

LinkState linkStateFor(DateTime lastSeen, DateTime now) {
  final age = now.difference(lastSeen);
  if (age < kOnlineLimit) return LinkState.online;
  if (age <= kDelayedLimit) return LinkState.delayed;
  return LinkState.offline;
}

String linkStateWord(LinkState s) => switch (s) {
      LinkState.online => 'online',
      LinkState.delayed => 'verzögert',
      LinkState.offline => 'offline',
    };

/// Klartext fuer Bewohnende. Das Kuerzel steht klein daneben.
const kPointLabels = <String, String>{
  'E1': 'Netzbezug',
  'E2': 'Rückspeisung',
  'E3': 'Solarstrom',
  'A1': 'Monitor selbst',
  'I1': 'Warmwasser',
  'I2': 'Heizung',
  'I3': 'Kleinverbraucher',
  'D1': 'Wasser',
  'K0': 'Wohnklima',
  'K1': 'Innentemperatur',
  'K2': 'Aussentemperatur',
  'K3': 'Luftfeuchte',
  'K4': 'CO2',
  'M0': 'Gemischt',
  'M1': 'Warmwasser',
  'M2': 'Heizen',
};

String pointLabel(String id) => kPointLabels[id] ?? 'Messpunkt $id';

class PointStatus {
  const PointStatus({required this.id, required this.lastSeen, required this.state});
  final String id;
  final DateTime lastSeen;

  /// null bei manuellen Messpunkten (M0 bis M2): die haben keine Ampel.
  final LinkState? state;

  bool get isManual => state == null;
  String get label => pointLabel(id);
}

class SystemStatus {
  SystemStatus._(this.automatic, this.manual, this.now);

  factory SystemStatus.fromPoints(Iterable<MeteringPoint> points, DateTime now) {
    final automatic = <PointStatus>[];
    final manual = <PointStatus>[];
    for (final p in points) {
      final lastSeen = DateTime.fromMillisecondsSinceEpoch(p.lastSeen);
      if (p.meteringPointId.startsWith('M')) {
        manual.add(PointStatus(id: p.meteringPointId, lastSeen: lastSeen, state: null));
      } else if (now.difference(lastSeen) < kActiveWindow) {
        automatic.add(PointStatus(
            id: p.meteringPointId, lastSeen: lastSeen, state: linkStateFor(lastSeen, now)));
      }
    }
    return SystemStatus._(automatic, manual, now);
  }

  final List<PointStatus> automatic;
  final List<PointStatus> manual;
  final DateTime now;

  bool get hasData => automatic.isNotEmpty;

  /// Schlechtester Status aller automatischen Messpunkte.
  LinkState? get overall {
    if (automatic.isEmpty) return null;
    return automatic.map((p) => p.state!).reduce((a, b) => a.index >= b.index ? a : b);
  }

  /// Juengster Zeitpunkt aller automatischen Messpunkte.
  DateTime? get latest => automatic.isEmpty
      ? null
      : automatic.map((p) => p.lastSeen).reduce((a, b) => a.isAfter(b) ? a : b);

  int count(LinkState s) => automatic.where((p) => p.state == s).length;

  /// Kurztext fuer die Pille in der Kopfzeile.
  String get pillText {
    final o = overall;
    if (o == null) return 'Noch keine Daten';
    switch (o) {
      case LinkState.online:
        // Online heisst juenger als 90 min: die Uhrzeit genuegt, auch kurz
        // nach Mitternacht (kurz, damit der Hausname Platz hat).
        return 'Alles läuft · ${DateFormat('HH:mm').format(latest!)}';
      case LinkState.delayed:
        final n = count(LinkState.delayed);
        return n == 1 ? '1 Messpunkt verzögert' : '$n Messpunkte verzögert';
      case LinkState.offline:
        final n = count(LinkState.offline);
        if (n == automatic.length) {
          return 'Keine Daten seit ${_hoursSince(latest!)} h';
        }
        return n == 1 ? '1 Messpunkt offline' : '$n Messpunkte offline';
    }
  }

  /// Satz oben im Systemstatus.
  String get headline {
    final o = overall;
    if (o == null) return 'Noch keine Daten angekommen';
    return switch (o) {
      LinkState.online => 'Alles läuft',
      LinkState.delayed =>
        count(LinkState.delayed) == 1 ? 'Ein Messpunkt ist verzögert' : 'Messpunkte sind verzögert',
      LinkState.offline => count(LinkState.offline) == automatic.length
          ? 'Keine Daten seit ${_hoursSince(latest!)} Stunden'
          : 'Ein Teil der Messpunkte ist offline',
    };
  }

  String get explanation {
    final o = overall;
    if (o == null) {
      return 'Sobald dein Monitor zum ersten Mal Daten schickt, siehst du sie hier.';
    }
    return switch (o) {
      LinkState.online => 'Letzte Daten ${formatTime(latest!, now)}. Der Monitor schickt '
          'einmal pro Stunde neue Werte.',
      LinkState.delayed => 'Meist holt der Monitor das selbst nach. Bleibt es über '
          '6 Stunden, melde dich.',
      LinkState.offline => 'Prüfe Strom und Internet beim Monitor. Wenn das nicht hilft, '
          'melde dich.',
    };
  }

  int _hoursSince(DateTime t) => now.difference(t).inHours;
}

/// "14:00" fuer heute, "gestern 14:00", sonst "19.11. 14:00".
String formatTime(DateTime t, DateTime now) {
  final time = DateFormat('HH:mm').format(t);
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(t.year, t.month, t.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return time;
  if (diff == 1) return 'gestern $time';
  return '${DateFormat('d.M.').format(t)} $time';
}
