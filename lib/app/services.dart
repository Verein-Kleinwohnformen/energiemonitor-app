// Datenzugriff der App hinter kleinen Schnittstellen, damit Seiten mit
// Testdaten gerendert werden koennen (Golden-Tests) und die Firestore-Logik
// an einer Stelle liegt.
//
// Das Speichern eines Formulareintrags laeuft weiterhin ausschliesslich ueber
// Energy.addToFirebase() in energy.dart (unveraendert, Studiendaten).
import 'dart:async';

import 'package:flutter/widgets.dart';

import '../admin/access.dart';
import '../daily/daily_values.dart';
import '../daily/factors.dart';
import '../energy.dart';
import '../household/household.dart';
import '../metering_point.dart';

/// Ein manueller Eintrag mit dem beim Speichern berechneten Verbrauch.
class ManualEntry {
  const ManualEntry(this.energy, {this.storedConsumed});

  final Energy energy;

  /// `consumed_quantity` aus dem Firestore-Dokument. Wurde beim Speichern
  /// aus dem Vorgaenger berechnet. null bei sehr alten Dokumenten.
  final double? storedConsumed;
}

abstract class ManualEntriesRepository {
  /// Eintraege des aktuellen und des letzten Jahres, neueste zuerst.
  Future<List<ManualEntry>> load(String monitorId, {required int currentYear});

  /// Speichert ueber Energy.addToFirebase().
  Future<void> add(Energy energy);

  Future<void> delete(ManualEntry entry);

  /// Aendert einen Eintrag: loescht [old] und speichert [updated] neu ueber
  /// Energy.addToFirebase(), damit `consumed_quantity` und die Nachfuehrung
  /// des Vorgaengers genau wie bei einem neuen Eintrag gerechnet werden.
  Future<void> replace(ManualEntry old, Energy updated);
}

abstract class StatusRepository {
  Stream<List<MeteringPoint>> watch(String monitorId);
}

abstract class HouseholdRepository {
  /// Alle Eintraege, aeltester zuerst.
  Stream<List<HouseholdEntry>> watch(String monitorId);

  Future<void> add(String monitorId, HouseholdEntry entry);
}

abstract class Clock {
  DateTime now();
}

class SystemClock implements Clock {
  const SystemClock();
  @override
  DateTime now() => DateTime.now();
}

class FixedClock implements Clock {
  const FixedClock(this.value);
  final DateTime value;
  @override
  DateTime now() => value;
}

/// Stellt die Dienste im Widget-Baum bereit.
class AppServices extends InheritedWidget {
  const AppServices({
    super.key,
    required this.entries,
    required this.status,
    required this.household,
    this.daily = const NoDaily(),
    this.factors = const NoFactors(),
    this.admin,
    this.clock = const SystemClock(),
    required super.child,
  });

  final ManualEntriesRepository entries;
  final StatusRepository status;
  final HouseholdRepository household;

  /// Tageswerte (Etappe 2) und Faktoren fuer Uebersicht und Auswertung.
  final DailyRepository daily;
  final FactorsRepository factors;

  /// Zugriffsverwaltung, nur fuer Superadmins genutzt.
  final AdminRepository? admin;
  final Clock clock;

  static AppServices of(BuildContext context) {
    final s = context.dependOnInheritedWidgetOfExactType<AppServices>();
    assert(s != null, 'AppServices fehlt im Widget-Baum');
    return s!;
  }

  @override
  bool updateShouldNotify(AppServices old) =>
      entries != old.entries ||
      status != old.status ||
      household != old.household ||
      daily != old.daily ||
      factors != old.factors ||
      admin != old.admin ||
      clock != old.clock;
}

/// Ohne Tageswerte (Tests, die sie nicht brauchen).
class NoDaily implements DailyRepository {
  const NoDaily();
  @override
  Future<List<DailyValues>> load(String monitorId, DateTime from, DateTime to) async => const [];
}

class NoFactors implements FactorsRepository {
  const NoFactors();
  @override
  Future<EnergyFactors> load() async => EnergyFactors.empty;
}

/// Teilt einen Stream unter mehreren Zuhoerern und gibt neuen Zuhoerern den
/// letzten Wert sofort mit (Status-Pille und Systemstatus lesen dasselbe).
class ReplayStream<T> {
  ReplayStream(Stream<T> source) {
    _sub = source.listen((v) {
      _last = v;
      _hasLast = true;
      _controller.add(v);
    }, onError: _controller.addError);
  }

  final _controller = StreamController<T>.broadcast();
  late final StreamSubscription<T> _sub;
  T? _last;
  bool _hasLast = false;

  Stream<T> get stream async* {
    if (_hasLast) yield _last as T;
    yield* _controller.stream;
  }

  Future<void> close() async {
    await _sub.cancel();
    await _controller.close();
  }
}
