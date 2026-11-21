import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../energy.dart';
import '../household/household.dart';
import '../metering_point.dart';
import 'services.dart';

class FirestoreManualEntries implements ManualEntriesRepository {
  FirestoreManualEntries([FirebaseFirestore? db]) : _db = db ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  @override
  Future<List<ManualEntry>> load(String monitorId, {required int currentYear}) async {
    final out = <ManualEntry>[];
    for (final year in [currentYear, currentYear - 1]) {
      final snap = await _db
          .collection('devices')
          .doc(monitorId)
          .collection('manual')
          .doc('$year')
          .collection('data')
          .get();
      for (final doc in snap.docs) {
        try {
          out.add(ManualEntry(
            Energy.fromFirebase(doc.id, doc.data()),
            storedConsumed: storedConsumedOf(doc.data()),
          ));
        } catch (e) {
          debugPrint('Eintrag ${doc.id} nicht lesbar: $e');
        }
      }
    }
    out.sort((a, b) => b.energy.purchaseDate.compareTo(a.energy.purchaseDate));
    return out;
  }

  @override
  Future<void> add(Energy energy) => energy.addToFirebase();

  @override
  Future<void> delete(ManualEntry entry) async => entry.energy.delete();
}

/// Liest `consumed_quantity` aus dem ersten Datenpunkt, wie ihn
/// Energy.addToFirebase() schreibt.
double? storedConsumedOf(Map<String, dynamic> data) {
  final points = data['data_points'];
  if (points is! List || points.isEmpty) return null;
  final values = (points.first as Map?)?['values'];
  final c = values is Map ? values['consumed_quantity'] : null;
  return c is num ? c.toDouble() : null;
}

class FirestoreStatus implements StatusRepository {
  FirestoreStatus([FirebaseFirestore? db]) : _db = db ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  final _cache = <String, ReplayStream<List<MeteringPoint>>>{};

  @override
  Stream<List<MeteringPoint>> watch(String monitorId) => _cache
      .putIfAbsent(
          monitorId,
          () => ReplayStream(_db
              .collection('devices')
              .doc(monitorId)
              .collection('metering_points')
              .snapshots()
              .map((s) => s.docs
                  .map((d) => MeteringPoint.fromFirestore(monitorId, d.id, d.data()))
                  .toList())))
      .stream;
}

class FirestoreHousehold implements HouseholdRepository {
  FirestoreHousehold({required this.uid, FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;
  final String Function() uid;

  CollectionReference<Map<String, dynamic>> _col(String monitorId) =>
      _db.collection('monitors').doc(monitorId).collection('household');

  final _cache = <String, ReplayStream<List<HouseholdEntry>>>{};

  @override
  Stream<List<HouseholdEntry>> watch(String monitorId) => _cache
      .putIfAbsent(
          monitorId,
          () => ReplayStream(_col(monitorId).snapshots().map((s) {
                final list = s.docs
                    .map((d) => HouseholdEntry.fromFirestore(d.data()))
                    .whereType<HouseholdEntry>()
                    .toList()
                  ..sort((a, b) => a.validFrom.compareTo(b.validFrom));
                return list;
              })))
      .stream;

  @override
  Future<void> add(String monitorId, HouseholdEntry entry) async {
    final now = DateTime.now();
    await _col(monitorId).doc(entry.docIdAt(now)).set(entry.toFirestore(uid: uid()));
  }
}
