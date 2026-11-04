import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../data/accounts.dart';
import '../store/app_store.dart';
import 'cloud.dart';

/// A cloud step that could not finish, with a message for the parent.
class CloudError implements Exception {
  final String message;
  const CloudError(this.message);
  @override
  String toString() => message;
}

/// A parent's profile as saved in the cloud (`parents/{uid}`).
class CloudParent {
  final String uid, parentId, name, relationship, phone, email;
  const CloudParent(this.uid, this.parentId, this.name, this.relationship, this.phone, this.email);
}

/// A phone sign-in waiting for the SMS code.
class PhoneSignIn {
  final Future<User> Function(String code) confirm;
  const PhoneSignIn(this.confirm);
}

/// Parent sign-in and backing up a parent's children to Firestore:
/// - `parents/{uid}`: the parent's profile and Parent ID
/// - `parentIds/{HMP-…}`: which user holds each Parent ID (keeps them unique)
/// - `students/{HMS-…}`: a child's important information, linked parents and a summary
/// - `students/{id}/progress/current`: the child's full saved record
/// - `students/{id}/homework/{id}`: their homework
class CloudAccounts {
  static User? get user => Cloud.ready ? Cloud.auth.currentUser : null;
  static Stream<User?> get changes => Cloud.ready ? Cloud.auth.authStateChanges() : const Stream.empty();

  static void _needCloud() {
    if (!Cloud.ready) throw const CloudError('Cloud backup is not set up in this version of the app.');
  }

  // ── Sign-in ─────────────────────────────────────────────────────────────

  static Future<User> signInWithGoogle() => _run(() async {
        final p = GoogleAuthProvider()..setCustomParameters({'prompt': 'select_account'});
        final c = kIsWeb ? await Cloud.auth.signInWithPopup(p) : await Cloud.auth.signInWithProvider(p);
        return c.user!;
      });

  static Future<User> signInWithEmail(String email, String password, {bool create = false}) => _run(() async {
        final c = create
            ? await Cloud.auth.createUserWithEmailAndPassword(email: email.trim(), password: password)
            : await Cloud.auth.signInWithEmailAndPassword(email: email.trim(), password: password);
        return c.user!;
      });

  /// Sends an SMS code to [number] (international format, e.g. +91 98765 43210).
  static Future<PhoneSignIn> startPhoneSignIn(String number) => _run(() async {
        final phone = number.replaceAll(RegExp(r'[\s\-()]'), '');
        if (kIsWeb) {
          final r = await Cloud.auth.signInWithPhoneNumber(phone);
          return PhoneSignIn((code) => _run(() async => (await r.confirm(code.trim())).user!));
        }
        final sent = Completer<PhoneSignIn>();
        await Cloud.auth.verifyPhoneNumber(
          phoneNumber: phone,
          // Android can read the SMS itself and sign straight in.
          verificationCompleted: (cred) async {
            final u = (await Cloud.auth.signInWithCredential(cred)).user!;
            if (!sent.isCompleted) sent.complete(PhoneSignIn((_) async => u));
          },
          verificationFailed: (e) { if (!sent.isCompleted) sent.completeError(CloudError(_message(e))); },
          codeSent: (id, _) => sent.complete(PhoneSignIn((code) => _run(() async => (await Cloud.auth.signInWithCredential(
              PhoneAuthProvider.credential(verificationId: id, smsCode: code.trim()))).user!))),
          codeAutoRetrievalTimeout: (_) {},
        );
        return sent.future;
      });

  static Future<void> signOut() async {
    if (Cloud.ready) await Cloud.auth.signOut();
  }

  // ── Parent profile ──────────────────────────────────────────────────────

  static DocumentReference<Map<String, dynamic>> _parentDoc(String uid) => Cloud.db.collection('parents').doc(uid);
  static DocumentReference<Map<String, dynamic>> studentDoc(String id) => Cloud.db.collection('students').doc(id);

  /// The signed-in user's saved parent profile, or null for a new account.
  static Future<CloudParent?> fetchParent() => _run(() async {
        final u = user;
        if (u == null) throw const CloudError('Please sign in first.');
        final d = await _parentDoc(u.uid).get(const GetOptions(source: Source.server)).timeout(_wait);
        if (!d.exists) return null;
        final j = d.data()!;
        return CloudParent(u.uid, j['parentId'] ?? '', j['name'] ?? '', j['relationship'] ?? 'Parent',
            j['phone'] ?? '', j['email'] ?? '');
      });

  /// Connects local parent [parentId] to the signed-in account and backs up
  /// their children. If the account already has a Parent ID (from another
  /// device), the local parent takes it; if [parentId] is taken by someone
  /// else, the parent gets a new one. Returns the parent's final ID.
  static Future<String> connectParent(AppStore s, String parentId) => _run(() async {
        final u = user;
        if (u == null) throw const CloudError('Please sign in first.');
        var id = parentId;
        final existing = await fetchParent();
        if (existing != null && existing.parentId.isNotEmpty) {
          if (existing.parentId != id) s.renameParentId(id, existing.parentId);
          id = existing.parentId;
        } else {
          id = await _claimParentId(s, id, u.uid);
        }
        s.setParentCloud(id, u.uid);
        await backup(s, id);
        return id;
      });

  /// Reserves [id] for [uid] in `parentIds`, renaming the parent locally
  /// when another account already holds it.
  static Future<String> _claimParentId(AppStore s, String id, String uid) async {
    for (int tries = 0; tries < 5; tries++) {
      final ref = Cloud.db.collection('parentIds').doc(id);
      final ok = await Cloud.db.runTransaction((t) async {
        final d = await t.get(ref);
        if (d.exists) return d.data()?['uid'] == uid;
        t.set(ref, {'uid': uid, 'createdAt': FieldValue.serverTimestamp()});
        return true;
      }).timeout(_wait);
      if (ok) return id;
      final fresh = AccountIds.generate(AccountIds.parent, taken: s.takenIds);
      s.renameParentId(id, fresh);
      id = fresh;
    }
    throw const CloudError('Could not reserve a Parent ID. Please try again.');
  }

  /// Uploads the parent's profile and every linked child (information,
  /// full progress and homework). Children whose Student ID is already used
  /// by another family get a new ID first. Returns how many were backed up.
  static Future<int> backup(AppStore s, String parentId) => _run(() async {
        final u = user;
        final pa = s.parentById(parentId);
        if (u == null || pa == null) throw const CloudError('Please sign in first.');
        final batch = Cloud.db.batch();
        final kids = s.childrenOf(parentId);
        for (final kid in kids) {
          var id = kid.id;
          bool? mine;
          for (int tries = 0; tries < 5 && mine == null; tries++) {
            mine = await _ownership(id, u.uid);
            if (mine == null) {
              final fresh = AccountIds.generate(AccountIds.student, taken: s.takenIds);
              s.renameStudentId(id, fresh);
              id = fresh;
            }
          }
          if (mine == null) throw const CloudError('Could not reserve a Student ID. Please try again.');
          final st = s.studentById(id)!;
          final r = s.recordOf(id);
          final ref = studentDoc(id);
          batch.set(ref, {
            // Notes (allergies, needs…) stay on the device until parents can choose to share them.
            ...st.toJson()..remove('notes'),
            if (!mine) 'ownerUid': u.uid,
            'parentUids': FieldValue.arrayUnion([u.uid]),
            // Shown in Important information on the child's own device.
            'guardians': {pa.id: _guardian(pa)},
            'summary': {
              'totalStars': r.totalStars, 'totalPoints': r.totalPoints, 'currentStreak': r.currentStreak,
              'mastered': r.mastered, 'activeThisWeek': r.activeThisWeek, 'lastActiveDate': r.lastActiveDate,
              'averageAccuracy': r.averageAccuracy,
            },
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          // As a JSON string: record keys (letter ids, Hindi words) are not all valid field names.
          batch.set(ref.collection('progress').doc('current'),
              {'data': json.encode(s.rawRecordOf(id)), 'updatedAt': FieldValue.serverTimestamp()});
          for (final h in s.homeworkFor(id)) {
            batch.set(ref.collection('homework').doc(h.id), h.toJson());
          }
        }
        batch.set(_parentDoc(u.uid), {
          'parentId': parentId, 'name': pa.name, 'relationship': pa.relationship, 'phone': pa.phone,
          'email': pa.email, 'createdAt': pa.createdAt,
          // Added to, not replaced: other devices may hold other children.
          'studentIds': FieldValue.arrayUnion([for (final k in s.childrenOf(parentId)) k.id]),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        try {
          await batch.commit().timeout(const Duration(seconds: 15));
        } on TimeoutException {
          // Firestore keeps the writes and sends them once back online.
          throw const CloudError('No connection. Your backup is saved and will upload when you are back online.');
        }
        s.markBackedUp(parentId);
        return kids.length;
      });

  static Map<String, dynamic> _guardian(ParentAccount p) =>
      {'name': p.name, 'relationship': p.relationship, 'phone': p.phone, 'email': p.email};

  // ── Pairing and invites ─────────────────────────────────────────────────

  static const codeLife = Duration(minutes: 10);
  static DocumentReference<Map<String, dynamic>> _code(String code) => Cloud.db.collection('pairCodes').doc(code);

  /// A one-time code for [studentId]: `device` pairs a child's own device,
  /// `parent` invites another parent. Valid for [codeLife].
  static Future<(String, DateTime)> createCode(String studentId, String kind) => _run(() async {
        final u = user;
        if (u == null) throw const CloudError('Please sign in first.');
        final code = AccountIds.pairCode();
        final expires = DateTime.now().add(codeLife);
        await _code(code).set({
          'studentId': studentId, 'kind': kind, 'createdBy': u.uid, 'used': false,
          'expiresAt': Timestamp.fromDate(expires), 'createdAt': FieldValue.serverTimestamp(),
        }).timeout(_wait);
        return (code, expires);
      });

  /// Fires once when [code] has been used (to tell the parent it worked).
  static Stream<bool> codeUsed(String code) =>
      _code(code).snapshots().map((d) => d.data()?['used'] == true).where((u) => u).take(1);

  static Future<void> cancelCode(String code) async {
    try { await _code(code).delete(); } catch (_) {}
  }

  /// Reads a code someone typed and checks it is live and of [kind].
  static Future<String> _studentForCode(String code, String kind) async {
    final d = await _code(code).get(const GetOptions(source: Source.server)).timeout(_wait);
    final j = d.data();
    if (j == null || j['kind'] != kind) throw const CloudError('That code is not right. Check it and try again.');
    if (j['used'] == true) throw const CloudError('That code was already used. Ask for a new one.');
    if ((j['expiresAt'] as Timestamp).toDate().isBefore(DateTime.now())) {
      throw const CloudError('That code has expired. Ask for a new one.');
    }
    return j['studentId'] as String;
  }

  /// Pairs this device to the child a parent's code is for: signs in this
  /// device (no account needed), joins the child's record and brings their
  /// progress here. Returns the child's Student ID.
  static Future<String> joinAsDevice(AppStore s, String rawCode, String deviceName) => _run(() async {
        final code = AccountIds.normalizePairCode(rawCode);
        if (code == null) throw const CloudError('A pairing code has 8 letters and numbers, like K7M2-9XQD.');
        var u = Cloud.auth.currentUser;
        if (u != null && !u.isAnonymous) {
          throw const CloudError('A parent is signed in on this device, so it already syncs. Use parent control instead.');
        }
        u ??= (await Cloud.auth.signInAnonymously().timeout(_wait)).user!;
        final studentId = await _studentForCode(code, 'device');
        final uid = u.uid;
        await Cloud.db.runTransaction((t) async {
          t.update(studentDoc(studentId), {
            'deviceUids': FieldValue.arrayUnion([uid]),
            'devices.$uid': {'name': deviceName, 'pairedAt': DateTime.now().toUtc().toIso8601String()},
            'pairCode': code, 'updatedAt': FieldValue.serverTimestamp(),
          });
          t.update(_code(code), {'used': true, 'usedBy': uid});
        }).timeout(_wait);
        final d = await studentDoc(studentId).get(const GetOptions(source: Source.server)).timeout(_wait);
        final p = await studentDoc(studentId).collection('progress').doc('current')
            .get(const GetOptions(source: Source.server)).timeout(_wait);
        final data = d.data() ?? {};
        Map<String, dynamic> record = {};
        try { record = json.decode(p.data()?['data'] ?? '{}') as Map<String, dynamic>; } catch (_) {}
        s.addPairedStudent(studentId, StudentAccount.fromJson({...data, 'id': studentId}).cloudInfo(),
            List<String>.from(data['parentIds'] ?? const []), record,
            guardians: data['guardians'] is Map ? Map<String, dynamic>.from(data['guardians']) : null);
        return studentId;
      });

  /// The signed-in parent ([parentId]) joins a child's record with another
  /// parent's invite code. Returns the child's Student ID.
  static Future<String> joinAsParent(AppStore s, String rawCode, String parentId) => _run(() async {
        final code = AccountIds.normalizePairCode(rawCode);
        if (code == null) throw const CloudError('An invite code has 8 letters and numbers, like K7M2-9XQD.');
        final u = user;
        final pa = s.parentById(parentId);
        if (u == null || u.isAnonymous || pa == null) throw const CloudError('Please sign in first.');
        final studentId = await _studentForCode(code, 'parent');
        await Cloud.db.runTransaction((t) async {
          t.update(studentDoc(studentId), {
            'parentUids': FieldValue.arrayUnion([u.uid]),
            'parentIds': FieldValue.arrayUnion([parentId]),
            'guardians.$parentId': _guardian(pa),
            'pairCode': code, 'updatedAt': FieldValue.serverTimestamp(),
          });
          t.update(_code(code), {'used': true, 'usedBy': u.uid});
        }).timeout(_wait);
        await _parentDoc(u.uid).set({'studentIds': FieldValue.arrayUnion([studentId])}, SetOptions(merge: true));
        // The child arrives through sync as a read-only copy.
        return studentId;
      });

  /// Unpairs one of a child's devices; it stops syncing at once.
  static Future<void> removeDevice(String studentId, String deviceUid) => _run(() async {
        await studentDoc(studentId).update({
          'deviceUids': FieldValue.arrayRemove([deviceUid]),
          'devices.$deviceUid': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        }).timeout(_wait);
      });

  /// Stops the signed-in parent ([parentId]) following child [studentId] in
  /// the cloud. The child's record stays for their other parents.
  static Future<void> unlinkParent(String studentId, String parentId) => _run(() async {
        final u = user;
        if (u == null) return;
        await studentDoc(studentId).update({
          'parentUids': FieldValue.arrayRemove([u.uid]),
          'parentIds': FieldValue.arrayRemove([parentId]),
          'updatedAt': FieldValue.serverTimestamp(),
        }).timeout(const Duration(seconds: 15));
        await _parentDoc(u.uid).set({'studentIds': FieldValue.arrayRemove([studentId])}, SetOptions(merge: true));
      });

  /// Deletes a child's cloud record (progress and homework too). Only the
  /// parent who first backed them up can; for anyone else it just unlinks.
  static Future<void> deleteStudent(String studentId, String parentId) => _run(() async {
        final u = user;
        if (u == null) return;
        final ref = studentDoc(studentId);
        final d = await ref.get(const GetOptions(source: Source.server)).timeout(_wait);
        if (!d.exists) return;
        if (d.data()?['ownerUid'] != u.uid) return unlinkParent(studentId, parentId);
        // Records first: their rules check the child's document.
        final hw = await ref.collection('homework').get(const GetOptions(source: Source.server)).timeout(_wait);
        final batch = Cloud.db.batch();
        for (final h in hw.docs) { batch.delete(h.reference); }
        batch.delete(ref.collection('progress').doc('current'));
        await batch.commit().timeout(const Duration(seconds: 15));
        await ref.delete().timeout(const Duration(seconds: 15));
        await _parentDoc(u.uid).set({'studentIds': FieldValue.arrayRemove([studentId])}, SetOptions(merge: true));
      });

  /// Whether `students/{id}` belongs to [uid]'s family: true (theirs),
  /// false (free to create) or null (another family's).
  static Future<bool?> _ownership(String id, String uid) async {
    try {
      final d = await studentDoc(id).get(const GetOptions(source: Source.server)).timeout(_wait);
      if (!d.exists) return false;
      return (d.data()?['parentUids'] as List?)?.contains(uid) == true ? true : null;
    } on FirebaseException catch (e) {
      // The rules hide other families' records.
      if (e.code == 'permission-denied') return null;
      rethrow;
    }
  }

  // ── Errors ──────────────────────────────────────────────────────────────

  static const _wait = Duration(seconds: 12);

  static Future<T> _run<T>(Future<T> Function() f) async {
    _needCloud();
    try {
      return await f();
    } on CloudError {
      rethrow;
    } on TimeoutException {
      throw const CloudError('No connection. Check the internet and try again.');
    } on FirebaseException catch (e) {
      throw CloudError(_message(e));
    }
  }

  static String _message(FirebaseException e) => switch (e.code) {
        'invalid-email' => 'That email address is not valid.',
        'user-not-found' || 'wrong-password' || 'invalid-credential' => 'Wrong email or password.',
        'email-already-in-use' => 'An account with this email already exists. Sign in instead.',
        'weak-password' => 'Use a password of at least 6 characters.',
        'invalid-phone-number' => 'That phone number is not valid. Start with the country code, e.g. +91.',
        'invalid-verification-code' => 'That code is not right. Check the SMS and try again.',
        'too-many-requests' => 'Too many tries. Please wait a few minutes.',
        'popup-closed-by-user' || 'cancelled-popup-request' || 'web-context-canceled' => 'Sign-in was cancelled.',
        'popup-blocked' => 'The browser blocked the sign-in window. Allow pop-ups and try again.',
        'network-request-failed' || 'unavailable' => 'No connection. Check the internet and try again.',
        'permission-denied' => 'The cloud refused this change.',
        _ => e.message ?? 'Something went wrong (${e.code}).',
      };
}
