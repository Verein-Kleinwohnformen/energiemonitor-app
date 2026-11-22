// Zugriffsverwaltung: Konten, Zuordnung zu Haeusern, Protokoll.
//
// Zugriff gibt es nur ueber monitor_read (lesen) und monitor_edit
// (bearbeiten) im User-Dokument. Bearbeiten schliesst Lesen ein. Aendern
// darf das nur ein Superadmin (Custom Claim), und jede Aenderung schreibt
// einen Protokolleintrag im selben Batch (die Rules verlangen das).
import 'package:cloud_firestore/cloud_firestore.dart';

import '../monitor.dart';

enum Access {
  none('Kein Zugriff'),
  read('Lesen'),
  edit('Bearbeiten');

  const Access(this.label);
  final String label;
}

class Account {
  const Account({
    required this.uid,
    this.email,
    this.name,
    this.read = const [],
    this.edit = const [],
    this.createdAt,
  });

  final String uid;
  final String? email;
  final String? name;
  final List<String> read;
  final List<String> edit;
  final DateTime? createdAt;

  Access accessTo(String monitorId) {
    if (edit.contains(monitorId)) return Access.edit;
    if (read.contains(monitorId)) return Access.read;
    return Access.none;
  }

  /// Fuer Listen: E-Mail, sonst Name, sonst gekuerzte ID.
  String get label => email ?? name ?? 'Konto ${uid.substring(0, uid.length.clamp(0, 6))}…';

  static Account fromFirestore(String uid, Map<String, dynamic> d) {
    List<String> list(Object? v) => v is List ? v.map((e) => '$e').toList() : const [];
    final created = d['date_created'];
    return Account(
      uid: uid,
      email: d['email'] is String ? d['email'] as String : null,
      name: d['user_name'] is String ? d['user_name'] as String : null,
      read: list(d['monitor_read']),
      edit: list(d['monitor_edit']),
      createdAt: created is Timestamp ? created.toDate() : null,
    );
  }
}

/// Neue Listen fuer Lesen und Bearbeiten. Die bisherige Reihenfolge bleibt
/// (der erste Monitor ist der Start-Monitor der Person), neue kommen ans Ende.
({List<String> read, List<String> edit}) applyAccess(
    Account account, Map<String, Access> changes) {
  final read = [...account.read];
  final edit = [...account.edit];
  changes.forEach((id, access) {
    final wantRead = access != Access.none;
    final wantEdit = access == Access.edit;
    if (wantRead && !read.contains(id)) read.add(id);
    if (!wantRead) read.remove(id);
    if (wantEdit && !edit.contains(id)) edit.add(id);
    if (!wantEdit) edit.remove(id);
  });
  // Bearbeiten ohne Lesen gibt es nicht (Rules pruefen das ebenfalls).
  for (final id in edit) {
    if (!read.contains(id)) read.add(id);
  }
  return (read: read, edit: edit);
}

/// Aenderungen in Worten, fuer Bestaetigung und Protokoll.
List<String> describeChanges({
  required List<String> beforeRead,
  required List<String> beforeEdit,
  required List<String> afterRead,
  required List<String> afterEdit,
  required String Function(String monitorId) name,
}) {
  Access level(List<String> r, List<String> e, String id) =>
      e.contains(id) ? Access.edit : (r.contains(id) ? Access.read : Access.none);
  final ids = {...beforeRead, ...beforeEdit, ...afterRead, ...afterEdit};
  final out = <String>[];
  for (final id in ids) {
    final before = level(beforeRead, beforeEdit, id);
    final after = level(afterRead, afterEdit, id);
    if (before == after) continue;
    out.add('${name(id)}: ${before.label} → ${after.label}');
  }
  return out;
}

class AccessLogEntry {
  const AccessLogEntry({
    required this.actorUid,
    this.actorEmail,
    required this.targetUid,
    this.targetEmail,
    required this.beforeRead,
    required this.beforeEdit,
    required this.afterRead,
    required this.afterEdit,
    this.at,
  });

  final String actorUid;
  final String? actorEmail;
  final String targetUid;
  final String? targetEmail;
  final List<String> beforeRead;
  final List<String> beforeEdit;
  final List<String> afterRead;
  final List<String> afterEdit;
  final DateTime? at;

  static AccessLogEntry fromFirestore(Map<String, dynamic> d) {
    List<String> list(Object? v) => v is List ? v.map((e) => '$e').toList() : const [];
    final at = d['at'];
    return AccessLogEntry(
      actorUid: '${d['actor_uid']}',
      actorEmail: d['actor_email'] as String?,
      targetUid: '${d['target_uid']}',
      targetEmail: d['target_email'] as String?,
      beforeRead: list(d['before_read']),
      beforeEdit: list(d['before_edit']),
      afterRead: list(d['after_read']),
      afterEdit: list(d['after_edit']),
      at: at is Timestamp ? at.toDate() : null,
    );
  }
}

abstract class AdminRepository {
  Stream<List<Account>> watchAccounts();
  Stream<List<EnergieMonitor>> watchMonitors();
  Stream<List<AccessLogEntry>> watchLog({int limit = 50});

  /// Speichert neue Zugriffe und den Protokolleintrag in einem Batch.
  Future<void> saveAccess({
    required Account account,
    required List<String> read,
    required List<String> edit,
    required String actorUid,
    String? actorEmail,
  });
}

class FirestoreAdmin implements AdminRepository {
  FirestoreAdmin([FirebaseFirestore? db]) : _db = db ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  @override
  Stream<List<Account>> watchAccounts() => _db.collection('users').snapshots().map((s) =>
      s.docs.map((d) => Account.fromFirestore(d.id, d.data())).toList()
        ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase())));

  @override
  Stream<List<EnergieMonitor>> watchMonitors() =>
      _db.collection('monitors').snapshots().map((s) => s.docs
          .map((d) {
            final data = {...d.data()};
            data['monitor_id'] ??= d.id;
            return EnergieMonitor.fromFirebase(data);
          })
          .toList()
        ..sort((a, b) => a.tinyhouseName.compareTo(b.tinyhouseName)));

  @override
  Stream<List<AccessLogEntry>> watchLog({int limit = 50}) => _db
      .collection('admin_log')
      .orderBy('at', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => s.docs.map((d) => AccessLogEntry.fromFirestore(d.data())).toList());

  @override
  Future<void> saveAccess({
    required Account account,
    required List<String> read,
    required List<String> edit,
    required String actorUid,
    String? actorEmail,
  }) async {
    final log = _db.collection('admin_log').doc();
    final batch = _db.batch()
      ..set(log, {
        'actor_uid': actorUid,
        if (actorEmail != null) 'actor_email': actorEmail,
        'target_uid': account.uid,
        if (account.email != null) 'target_email': account.email,
        'before_read': account.read,
        'before_edit': account.edit,
        'after_read': read,
        'after_edit': edit,
        'at': FieldValue.serverTimestamp(),
      })
      ..update(_db.collection('users').doc(account.uid), {
        'monitor_read': read,
        'monitor_edit': edit,
        'access_log_id': log.id,
        'access_updated_by': actorUid,
        'access_updated_at': FieldValue.serverTimestamp(),
      });
    await batch.commit();
  }
}
