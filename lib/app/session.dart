// Zustand der angemeldeten Person: Monitore, aktiver Monitor, Rechte,
// Studienmodus. Quelle fuer Navigation und Kopfzeile.
//
// Zugriff auf Haeuser gibt es nur ueber monitor_read und monitor_edit im
// User-Dokument. Es gibt keine Rolle, die alle Haeuser sieht. Superadmins
// (Custom Claim "superadmin" im Login-Token) verwalten diese Zuordnungen,
// sehen aber selbst nur die Haeuser, die ihnen zugeordnet sind.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../monitor.dart';
import '../user.dart';

enum SessionPhase { loading, signedOut, ready }

/// Was die App ueber die angemeldete Person weiss.
class SessionData {
  const SessionData({
    required this.uid,
    this.email,
    this.displayName,
    required this.monitors,
    required this.editableIds,
    this.isSuperadmin = false,
    this.studyDialogSeen = const {},
  });

  final String uid;
  final String? email;
  final String? displayName;
  final List<EnergieMonitor> monitors;
  final Set<String> editableIds;

  /// Darf Zugriffe verwalten (Custom Claim im Login-Token). Sieht dadurch
  /// keine zusaetzlichen Haeuser.
  final bool isSuperadmin;
  final Set<String> studyDialogSeen;

  SessionData copyWith({Set<String>? studyDialogSeen}) => SessionData(
        uid: uid,
        email: email,
        displayName: displayName,
        monitors: monitors,
        editableIds: editableIds,
        isSuperadmin: isSuperadmin,
        studyDialogSeen: studyDialogSeen ?? this.studyDialogSeen,
      );
}

/// Laedt und speichert die Daten der Session (Firestore oder Testdaten).
abstract class SessionBackend {
  /// null, wenn niemand angemeldet ist.
  Future<SessionData?> load();
  Future<void> markStudyDialogSeen(String uid, String monitorId);
  Future<void> updateDisplayName(String name);
  Future<void> signOut();
}

class AppSession extends ChangeNotifier {
  AppSession(this._backend);

  /// Fuer Tests und Golden-Bilder: fertige Session ohne Backend-Aufruf.
  AppSession.fixed(SessionData data, {String? activeId, SessionBackend? backend})
      : _backend = backend ?? _NoopBackend() {
    _apply(data, activeId: activeId);
  }

  final SessionBackend _backend;

  SessionPhase phase = SessionPhase.loading;
  SessionData? _data;
  String? _activeId;
  Object? loadError;

  SessionData? get data => _data;
  String? get uid => _data?.uid;
  String? get email => _data?.email;
  String? get displayName => _data?.displayName;
  List<EnergieMonitor> get monitors => _data?.monitors ?? const [];
  bool get hasMultipleMonitors => monitors.length > 1;
  bool get isSuperadmin => _data?.isSuperadmin ?? false;

  EnergieMonitor? get active {
    if (monitors.isEmpty) return null;
    return monitors.firstWhere((m) => m.id == _activeId, orElse: () => monitors.first);
  }

  bool get canEdit => active != null && (_data?.editableIds.contains(active!.id) ?? false);

  /// Der aktive Monitor laeuft im Studienmodus.
  bool get studyModeActive => active?.studyMode ?? false;

  /// Auswertende Ansichten ausblenden. Gilt fuer alle, auch fuer das Team.
  bool get hideAnalysis => studyModeActive;

  /// Studien-Dialog beim ersten Oeffnen eines Studienmonitors.
  bool get needsStudyDialog =>
      studyModeActive && !(_data?.studyDialogSeen.contains(active!.id) ?? true);

  Future<void> load() async {
    phase = SessionPhase.loading;
    loadError = null;
    notifyListeners();
    try {
      final d = await _backend.load();
      if (d == null) {
        _data = null;
        phase = SessionPhase.signedOut;
      } else {
        _apply(d, activeId: _activeId);
      }
    } catch (e) {
      loadError = e;
      _data = null;
      phase = SessionPhase.signedOut;
    }
    notifyListeners();
  }

  void _apply(SessionData d, {String? activeId}) {
    _data = d;
    _activeId = d.monitors.any((m) => m.id == activeId)
        ? activeId
        : (d.monitors.isEmpty ? null : d.monitors.first.id);
    phase = SessionPhase.ready;
  }

  void selectMonitor(String id) {
    if (_activeId == id) return;
    _activeId = id;
    notifyListeners();
  }

  Future<void> markStudyDialogSeen() async {
    final d = _data;
    final m = active;
    if (d == null || m == null) return;
    _data = d.copyWith(studyDialogSeen: {...d.studyDialogSeen, m.id});
    notifyListeners();
    try {
      await _backend.markStudyDialogSeen(d.uid, m.id);
    } catch (e) {
      debugPrint('Studien-Dialog nicht gespeichert: $e');
    }
  }

  Future<void> updateDisplayName(String name) async {
    await _backend.updateDisplayName(name);
    await load();
  }

  Future<void> signOut() async {
    await _backend.signOut();
    _data = null;
    _activeId = null;
    phase = SessionPhase.signedOut;
    notifyListeners();
  }
}

class _NoopBackend implements SessionBackend {
  @override
  Future<SessionData?> load() async => null;
  @override
  Future<void> markStudyDialogSeen(String uid, String monitorId) async {}
  @override
  Future<void> updateDisplayName(String name) async {}
  @override
  Future<void> signOut() async {}
}

/// Firebase: Login aus FirebaseAuth, Rechte aus /users/{uid}, Monitore aus
/// /monitors, Superadmin aus dem Custom Claim im Login-Token.
class FirebaseSessionBackend implements SessionBackend {
  FirebaseSessionBackend({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  @override
  Future<SessionData?> load() async {
    // Im Browser stellt Firebase Auth die Anmeldung asynchron wieder her.
    await FirebaseAuth.instance.authStateChanges().first;
    final user = AppUser();
    await user.init();
    if (!user.isLoggedIn) return null;
    final uid = user.userId!;

    final userDoc = await _db.collection('users').doc(uid).get();
    final data = userDoc.data() ?? const <String, dynamic>{};
    await _syncEmail(uid, data);
    final seen = <String>{
      ...((data['study_dialog_seen'] as List?) ?? const []).map((e) => '$e'),
    };

    return SessionData(
      uid: uid,
      email: user.email,
      displayName: user.nickname,
      monitors: List.of(user.monitorRead),
      editableIds: user.monitorEditIdList.toSet(),
      isSuperadmin: await _readSuperadminClaim(),
      studyDialogSeen: seen,
    );
  }

  /// Die Verwaltung listet Konten mit E-Mail. Die E-Mail steht darum auch
  /// im User-Dokument; die Rules erlauben nur die E-Mail aus dem Login-Token.
  Future<void> _syncEmail(String uid, Map<String, dynamic> data) async {
    final tokenEmail = FirebaseAuth.instance.currentUser?.email;
    if (tokenEmail == null || data.isEmpty || data['email'] == tokenEmail) return;
    try {
      await _db.collection('users').doc(uid).update({'email': tokenEmail});
    } catch (e) {
      debugPrint('E-Mail im User-Dokument nicht nachgefuehrt: $e');
    }
  }

  /// Superadmin steht als Custom Claim im Login-Token. Er wird nur mit dem
  /// Admin SDK gesetzt (tool/admin/), nie aus der App.
  Future<bool> _readSuperadminClaim() async {
    try {
      final result = await FirebaseAuth.instance.currentUser?.getIdTokenResult(true);
      return result?.claims?['superadmin'] == true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> markStudyDialogSeen(String uid, String monitorId) =>
      _db.collection('users').doc(uid).update({
        'study_dialog_seen': FieldValue.arrayUnion([monitorId]),
      });

  @override
  Future<void> updateDisplayName(String name) async {
    final error = await AppUser().updateNickname(name);
    if (error != null) throw Exception(error);
  }

  @override
  Future<void> signOut() => AppUser().signOut();
}
