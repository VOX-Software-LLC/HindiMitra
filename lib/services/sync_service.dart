import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../data/accounts.dart';
import '../store/app_store.dart';
import 'cloud.dart';
import 'cloud_accounts.dart';
import 'crash_reporter.dart';
import 'record_merge.dart';

enum SyncState { off, syncing, synced, offline, error }

class SyncStatus {
  final SyncState state;
  final DateTime? lastSync;
  final String? message;
  const SyncStatus(this.state, {this.lastSync, this.message});
}

/// Keeps learners' records in step with the cloud while a parent is signed
/// in on this device:
/// - every change to a child's progress is merged with the cloud copy and
///   uploaded a few seconds later ([mergeRecords] never loses practice);
/// - changes made on other devices arrive live and are merged in;
/// - children who learn on other devices appear as read-only copies, so a
///   parent can follow them from their own phone;
/// - edits to a child's details travel both ways;
/// - children added on this device are backed up automatically.
/// Firestore queues writes while offline and sends them when back online.
class SyncService {
  static final status = ValueNotifier(const SyncStatus(SyncState.off));

  static AppStore? _s;
  static String? _uid;
  static StreamSubscription<User?>? _authSub;
  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _studentsSub;
  static final _progressSubs = <String, StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>{};
  /// Latest cloud record per child, and the text of what the cloud holds
  /// (pushed or received) so unchanged records are not sent again.
  static final _remote = <String, Map<String, dynamic>>{};
  static final _cloudText = <String, String>{};
  /// Child details as last seen in or sent to the cloud.
  static final _cloudInfo = <String, String>{};
  /// Children in the cloud (from the server, not the cache), null until known.
  static Set<String>? _cloudIds;
  static Timer? _debounce;
  static bool _pushing = false, _backingUp = false;
  static DateTime? _lastSync;

  static Duration debounce = const Duration(seconds: 3);

  static void start(AppStore s) {
    if (!Cloud.ready || _s != null) return;
    _s = s;
    s.addListener(_onLocalChange);
    _authSub = Cloud.auth.authStateChanges().listen(_onUser);
  }

  /// Stops syncing (tests, or before the store is replaced).
  static void stop() {
    _authSub?.cancel();
    _authSub = null;
    _detach();
    _s?.removeListener(_onLocalChange);
    _s = null;
    _uid = null;
    _set(SyncState.off);
  }

  /// Uploads pending changes now (e.g. "Back up now").
  static Future<void> syncNow() async {
    _debounce?.cancel();
    await _push();
  }

  static void _set(SyncState st, [String? message]) =>
      status.value = SyncStatus(st, lastSync: _lastSync, message: message);

  static void _onUser(User? u) {
    _detach();
    _uid = u?.uid;
    if (u == null) {
      // Signed out: copies of children from the cloud leave this device.
      final s = _s;
      if (s != null) {
        for (final st in [...s.students]) { if (st.remote) s.removeCloudCopy(st.id); }
      }
      _set(SyncState.off);
      return;
    }
    _attachIfReady();
  }

  /// Starts listening once a parent on this device is connected to the
  /// signed-in account (signing in alone, e.g. halfway through sign-up,
  /// brings nothing down).
  static void _attachIfReady() {
    final s = _s, uid = _uid;
    if (s == null || uid == null || _studentsSub != null) return;
    if (_deviceMode ? !s.students.any((x) => x.paired) : _myParentIds.isEmpty) return;
    _set(SyncState.syncing);
    _studentsSub = Cloud.db.collection('students').where(_deviceMode ? 'deviceUids' : 'parentUids', arrayContains: uid)
        .snapshots(includeMetadataChanges: true).listen(_onStudents, onError: _onError);
  }

  /// Signed in as a child's paired device (no parent account).
  static bool get _deviceMode => Cloud.auth.currentUser?.isAnonymous ?? false;

  static void _detach() {
    _studentsSub?.cancel();
    _studentsSub = null;
    for (final sub in _progressSubs.values) { sub.cancel(); }
    _progressSubs.clear();
    _remote.clear();
    _cloudText.clear();
    _cloudInfo.clear();
    _cloudIds = null;
  }

  /// Parents on this device who are the signed-in account.
  static Set<String> get _myParentIds => {for (final p in _s!.parents) if (p.cloudUid == _uid) p.id};

  /// Whether a learner on this device belongs to the signed-in family.
  static bool _syncs(StudentAccount st) =>
      _deviceMode ? st.paired : st.remote || st.parentIds.any(_myParentIds.contains);

  // ── Cloud → device ──────────────────────────────────────────────────────

  static void _onStudents(QuerySnapshot<Map<String, dynamic>> snap) {
    final s = _s;
    if (s == null) return;
    for (final d in snap.docs) {
      final data = d.data();
      final info = StudentAccount.fromJson({...data, 'id': d.id}).cloudInfo();
      final infoText = json.encode(info);
      final links = List<String>.from(data['parentIds'] ?? const []);
      final local = s.studentById(d.id);
      // A paired device only follows the children paired to it.
      if (_deviceMode && !(local?.paired ?? false)) continue;
      final devices = data['devices'] is Map ? Map<String, dynamic>.from(data['devices']) : <String, dynamic>{};
      final guardians = data['guardians'] is Map ? Map<String, dynamic>.from(data['guardians']) : null;
      if (local == null || _cloudInfo[d.id] != infoText) {
        // New in the cloud, or its details were changed on another device.
        s.upsertCloudStudent(d.id, info, links, devices: devices, guardians: guardians);
        _cloudInfo[d.id] = infoText;
      } else {
        // Parents or devices added or removed elsewhere.
        s.upsertCloudStudent(d.id, local.cloudInfo(), links, devices: devices, guardians: guardians);
      }
      _progressSubs.putIfAbsent(d.id, () => d.reference.collection('progress').doc('current')
          .snapshots().listen((p) => _onProgress(d.id, p), onError: _onError));
    }
    if (snap.metadata.isFromCache) return;
    final ids = {for (final d in snap.docs) d.id};
    _cloudIds = ids;
    for (final st in [...s.students]) {
      if (ids.contains(st.id)) continue;
      if (st.remote) {
        // A copy of a child no longer linked to this parent.
        _progressSubs.remove(st.id)?.cancel();
        s.removeCloudCopy(st.id);
      } else if (_deviceMode && st.paired) {
        // A parent removed this device: progress stays here, syncing stops.
        _progressSubs.remove(st.id)?.cancel();
        s.markUnpaired(st.id);
      }
    }
    _markSynced();
    _schedule();
  }

  static void _onProgress(String id, DocumentSnapshot<Map<String, dynamic>> snap) {
    final s = _s;
    if (s == null || !snap.exists || snap.metadata.hasPendingWrites) return;
    Map<String, dynamic> remote;
    try {
      remote = json.decode(snap.data()?['data'] ?? '{}') as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    _remote[id] = remote;
    _cloudText[id] = canonicalJson(remote);
    final st = s.studentById(id);
    if (st == null) return;
    final local = s.rawRecordOf(id);
    if (st.remote) {
      // A copy: the cloud is the truth.
      if (canonicalJson(local) != _cloudText[id]) s.replaceRecord(id, remote);
      return;
    }
    final merged = mergeRecords(local, remote);
    if (canonicalJson(merged) != canonicalJson(local)) s.replaceRecord(id, merged);
    if (canonicalJson(merged) != _cloudText[id]) _schedule();
  }

  // ── Device → cloud ──────────────────────────────────────────────────────

  static void _onLocalChange() {
    if (_uid == null) return;
    if (_studentsSub == null) {
      _attachIfReady();
      return;
    }
    _schedule();
  }

  static void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(debounce, () => unawaited(_push()));
  }

  static Future<void> _push() async {
    final s = _s, uid = _uid, cloudIds = _cloudIds;
    if (s == null || uid == null || cloudIds == null || _pushing) return;
    _pushing = true;
    try {
      final batch = Cloud.db.batch();
      var writes = 0;
      final missing = <StudentAccount>[];
      for (final st in s.students.where(_syncs)) {
        if (!cloudIds.contains(st.id)) {
          if (!st.remote) missing.add(st);
          continue;
        }
        final ref = CloudAccounts.studentDoc(st.id);
        // Details edited on this device (parents only; a child's device can't change them).
        final info = AppStore.canonicalInfo(st);
        if (!_deviceMode && _cloudInfo[st.id] != null && _cloudInfo[st.id] != info) {
          batch.set(ref, {...st.cloudInfo(), 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
          _cloudInfo[st.id] = info;
          writes++;
        }
        if (st.remote) continue;
        // Progress: what this device has, merged with the cloud copy.
        final local = s.rawRecordOf(st.id);
        final merged = _remote[st.id] == null ? local : mergeRecords(local, _remote[st.id]!);
        final text = canonicalJson(merged);
        if (text == _cloudText[st.id]) continue;
        final r = StudentRecord.fromJson(merged);
        batch.set(ref.collection('progress').doc('current'),
            {'data': json.encode(merged), 'updatedAt': FieldValue.serverTimestamp()});
        batch.set(ref, {
          'summary': {
            'totalStars': r.totalStars, 'totalPoints': r.totalPoints, 'currentStreak': r.currentStreak,
            'mastered': r.mastered, 'activeThisWeek': r.activeThisWeek, 'lastActiveDate': r.lastActiveDate,
            'averageAccuracy': r.averageAccuracy,
          },
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        _remote[st.id] = merged;
        _cloudText[st.id] = text;
        writes++;
      }
      if (writes > 0) {
        _set(SyncState.syncing);
        try {
          await batch.commit().timeout(const Duration(seconds: 15));
        } on TimeoutException {
          // Queued by Firestore; sent when the connection returns.
          _set(SyncState.offline);
          return;
        }
      }
      if (missing.isNotEmpty && !_deviceMode) await _backUpNew();
      _markSynced();
    } on FirebaseException catch (e, st) {
      CrashReporter.record(e, st, reason: 'sync push');
      _set(e.code == 'unavailable' ? SyncState.offline : SyncState.error, e.message);
    } finally {
      _pushing = false;
    }
  }

  /// Children added on this device since the last backup.
  static Future<void> _backUpNew() async {
    final s = _s;
    if (s == null || _backingUp) return;
    _backingUp = true;
    try {
      for (final pid in _myParentIds) {
        await CloudAccounts.backup(s, pid);
      }
    } on CloudError catch (e) {
      _set(SyncState.offline, e.message);
    } finally {
      _backingUp = false;
    }
  }

  static void _markSynced() {
    if (_debounce?.isActive ?? false) return;
    _lastSync = DateTime.now();
    _set(SyncState.synced);
  }

  static void _onError(Object e, StackTrace st) {
    debugPrint('Sync: $e');
    if (e is FirebaseException && e.code == 'permission-denied') {
      _set(SyncState.error, 'The cloud refused access.');
    } else {
      _set(SyncState.offline);
    }
  }
}
