import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:hindi_mitra/data/accounts.dart';
import 'package:hindi_mitra/store/app_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('account IDs', () {
    test('are well formed, unique and carry a working check character', () {
      final ids = {for (int i = 0; i < 500; i++) AccountIds.generate(AccountIds.student)};
      expect(ids.length, 500);
      for (final id in ids) {
        expect(id, matches(RegExp(r'^HMS-[0-9A-HJKMNP-TV-Z]{4}-[0-9A-HJKMNP-TV-Z]{4}$')));
        expect(AccountIds.normalize(id, AccountIds.student), id);
      }
      expect(AccountIds.generate(AccountIds.parent), startsWith('HMP-'));
    });

    test('typed IDs are tidied, and typos are caught', () {
      final id = AccountIds.generate(AccountIds.student);
      final bare = id.substring(4).replaceAll('-', '').toLowerCase();
      expect(AccountIds.normalize(' $bare ', AccountIds.student), id);
      expect(AccountIds.normalize(id.replaceAll('-', ' '), AccountIds.student), id);
      // Change one character: the check character no longer matches.
      final c = id[5];
      final typo = id.replaceRange(5, 6, c == '7' ? '8' : '7');
      expect(AccountIds.normalize(typo, AccountIds.student), isNull);
      expect(AccountIds.normalize(id, AccountIds.parent), isNull);
      expect(AccountIds.normalize('HMS-1234', AccountIds.student), isNull);
    });
  });

  test('progress saved before accounts becomes the first learner', () async {
    SharedPreferences.setMockInitialValues({
      'hindi-mitra-store': json.encode({'userName': 'Asha', 'totalStars': 42, 'onboardingComplete': true, 'isPremium': true}),
    });
    final s = await AppStore.load();
    expect(s.students, hasLength(1));
    expect(s.student!.name, 'Asha');
    expect(s.totalStars, 42);
    expect(s.isPremium, isTrue);
    // And it is saved under the learner's own ID from now on.
    final again = await AppStore.load();
    expect(again.activeStudentId, s.activeStudentId);
    expect(again.totalStars, 42);
  });

  test('each learner keeps their own progress', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await AppStore.load();
    s.completeOnboarding('Asha', 'kid-7-10', 'student');
    s.addStars(10);
    final asha = s.activeStudentId;
    final ravi = s.addStudent('Ravi', ageGroup: 'kid-4-6');
    s.switchStudent(ravi.id);
    expect(s.userName, 'Ravi');
    expect(s.totalStars, 0);
    expect(s.onboardingComplete, isTrue);
    s.addStars(3);
    s.switchStudent(asha);
    expect(s.userName, 'Asha');
    expect(s.totalStars, 10);
    expect(s.recordOf(ravi.id).totalStars, 3);

    final reloaded = await AppStore.load();
    expect(reloaded.students.map((x) => x.name), ['Asha', 'Ravi']);
    expect(reloaded.activeStudentId, asha);
  });

  test('parents: PIN, linking several children, and the student keeps the parent IDs', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await AppStore.load();
    final kid1 = s.activeStudentId;
    final kid2 = s.addStudent('Meera').id;
    final mum = s.createParent(name: 'Sunita', pin: '1234', relationship: 'Mother', phone: '+91 98765 43210');
    final dad = s.createParent(name: 'Raj', pin: '4321', relationship: 'Father');
    expect(mum.id, startsWith('HMP-'));
    expect(mum.checkPin('1234'), isTrue);
    expect(mum.checkPin('0000'), isFalse);
    expect(mum.pinHash, isNot(contains('1234')));

    s.linkParent(kid1, mum.id);
    s.linkParent(kid2, mum.id);
    s.linkParent(kid1, dad.id);
    s.linkParent(kid1, mum.id); // twice is a no-op
    expect(s.childrenOf(mum.id).map((x) => x.id), [kid1, kid2]);
    expect(s.studentById(kid1)!.parentIds, [mum.id, dad.id]);
    expect(s.parentsOf(kid1).map((p) => p.name), ['Sunita', 'Raj']);

    s.updateStudentInfo(kid1, grade: 'Class 3', school: 'DPS', emergencyContact: 'Sunita 98765');
    s.unlinkParent(kid1, dad.id);
    final reloaded = await AppStore.load();
    final k = reloaded.studentById(kid1)!;
    expect(k.parentIds, [mum.id]);
    expect(k.grade, 'Class 3');
    expect(reloaded.parentById(mum.id)!.checkPin('1234'), isTrue);
  });

  test('homework moves forward as the learner practises', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await AppStore.load();
    final kid = s.activeStudentId;
    final mum = s.createParent(name: 'Sunita', pin: '1234');
    Homework hw(String id, HomeworkKind kind, {String target = '', int goal = 1, int level = 0}) => Homework(
        id: id, studentId: kid, assignedBy: mum.id, kind: kind, title: id, target: target, goal: goal, level: level);
    s.assignHomework(hw('letter', HomeworkKind.letter, target: 'ka', goal: 2));
    s.assignHomework(hw('practice', HomeworkKind.practice, goal: 3));
    s.assignHomework(hw('level', HomeworkKind.level, target: 'matra-practice', level: 2));
    Homework byId(String id) => s.homework.firstWhere((h) => h.id == id);

    s.selectLetter('ka');
    s.recordAttempt('ka', 1); // too few stars for the letter homework
    s.recordAttempt('ka', 3);
    s.recordWordAttempt('कमल', 80);
    expect(byId('letter').progress, 1);
    expect(byId('practice').done, isTrue);
    final points = s.totalPoints;
    s.recordAttempt('ka', 2);
    expect(byId('letter').done, isTrue);
    expect(s.totalPoints, greaterThanOrEqualTo(points + 20));

    s.completeActivityLevel('matra-practice', 1);
    expect(byId('level').done, isFalse);
    s.completeActivityLevel('matra-practice', 2);
    expect(byId('level').done, isTrue);

    // A level passed before it was assigned counts only when passed again.
    s.assignHomework(hw('old', HomeworkKind.level, target: 'matra-practice', level: 1));
    expect(byId('old').done, isFalse);
    s.completeActivityLevel('matra-practice', 1);
    expect(byId('old').done, isTrue);
    // Other learners' homework is untouched.
    final other = s.addStudent('Meera');
    s.assignHomework(Homework(id: 'm', studentId: other.id, assignedBy: mum.id, kind: HomeworkKind.practice, title: 'm', goal: 1));
    s.recordWordAttempt('घर', 90);
    expect(byId('m').progress, 0);
    expect(s.homeworkFor(kid).first.done, isTrue);
  });

  test('cloud link: renaming IDs keeps links, progress and homework', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await AppStore.load();
    final kid = s.activeStudentId;
    s.addStars(7);
    final mum = s.createParent(name: 'Sunita', pin: '1234');
    s.linkParent(kid, mum.id);
    s.assignHomework(Homework(id: 'h', studentId: kid, assignedBy: mum.id, kind: HomeworkKind.practice, title: 'h', goal: 2));

    final newKid = AccountIds.generate(AccountIds.student);
    s.renameStudentId(kid, newKid);
    expect(s.activeStudentId, newKid);
    expect(s.studentById(kid), isNull);
    expect(s.recordOf(newKid).totalStars, 7);
    expect(s.homeworkFor(newKid), hasLength(1));

    final newMum = AccountIds.generate(AccountIds.parent);
    s.renameParentId(mum.id, newMum);
    expect(s.studentById(newKid)!.parentIds, [newMum]);
    expect(s.homework.single.assignedBy, newMum);
    expect(s.parentById(newMum)!.checkPin('1234'), isTrue, reason: 'the PIN survives the new ID');

    s.setParentCloud(newMum, 'uid-1');
    s.markBackedUp(newMum);
    final reloaded = await AppStore.load();
    expect(reloaded.parentById(newMum)!.cloudUid, 'uid-1');
    expect(reloaded.parentById(newMum)!.lastBackupAt, isNotNull);
    expect(reloaded.totalStars, 7);
  });

  test('a parent signing in on a new device keeps their Parent ID', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await AppStore.load();
    final id = AccountIds.generate(AccountIds.parent);
    final p = s.restoreParent(id: id, uid: 'uid-9', name: 'Raj', pin: '2468', relationship: 'Father');
    expect(p.id, id);
    expect(p.cloudUid, 'uid-9');
    expect(p.checkPin('2468'), isTrue);
    expect(s.parents, hasLength(1));
  });

  test('cloud copies: a parent follows a child who learns on another device', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await AppStore.load();
    final me = s.activeStudentId;
    final mum = s.createParent(name: 'Sunita', pin: '1234');
    final kid = AccountIds.generate(AccountIds.student);

    expect(s.upsertCloudStudent(kid, {'name': 'Kabir', 'grade': 'Class 2'}, [mum.id]), isTrue);
    final copy = s.studentById(kid)!;
    expect(copy.remote, isTrue);
    expect(s.learners.map((x) => x.id), [me], reason: 'copies are not learners on this device');
    expect(s.childrenOf(mum.id).map((x) => x.id), [kid]);
    s.switchStudent(kid);
    expect(s.activeStudentId, me, reason: 'a copy cannot be switched to');

    s.replaceRecord(kid, {'userName': 'Kabir', 'totalStars': 12, 'activityProgress': {'dictation': 2}});
    expect(s.recordOf(kid).totalStars, 12);
    expect(s.upsertCloudStudent(kid, {'name': 'Kabir', 'grade': 'Class 2'}, [mum.id]), isFalse, reason: 'nothing changed');
    s.upsertCloudStudent(kid, {'name': 'Kabir', 'grade': 'Class 3'}, [mum.id, 'HMP-OTHER']);
    expect(s.studentById(kid)!.grade, 'Class 3');
    expect(s.studentById(kid)!.parentIds, [mum.id, 'HMP-OTHER']);

    final reloaded = await AppStore.load();
    expect(reloaded.activeStudentId, me);
    expect(reloaded.studentById(kid)!.remote, isTrue);
    reloaded.removeCloudCopy(kid);
    expect(reloaded.studentById(kid), isNull);
  });

  test('details changed in the cloud reach the active learner', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await AppStore.load();
    s.completeOnboarding('Asha', 'kid-7-10', 'student');
    s.addStars(5);
    s.upsertCloudStudent(s.activeStudentId, {'name': 'Asha Rao', 'school': 'DPS'}, []);
    expect(s.userName, 'Asha Rao');
    expect(s.student!.school, 'DPS');
    expect(s.student!.remote, isFalse);
    s.replaceRecord(s.activeStudentId, {...s.rawRecordOf(s.activeStudentId), 'totalStars': 9});
    expect(s.totalStars, 9);
  });

  test('pairing a fresh device to a child brings their record and parents', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await AppStore.load();
    final blank = s.activeStudentId; // a fresh install, not set up yet
    expect(s.onboardingComplete, isFalse);
    final kid = AccountIds.generate(AccountIds.student), mum = AccountIds.generate(AccountIds.parent);

    s.addPairedStudent(kid, {'name': 'Aarav', 'grade': 'Class 3'}, [mum],
        {'userName': 'Aarav', 'totalStars': 70, 'activityProgress': {'matra-practice': 3}},
        guardians: {mum: {'name': 'Sunita', 'relationship': 'Mother', 'phone': '+91 98765 43210', 'email': ''}});
    expect(s.activeStudentId, kid);
    expect(s.onboardingComplete, isTrue);
    expect(s.totalStars, 70);
    expect(s.student!.paired, isTrue);
    expect(s.studentById(blank), isNull, reason: 'the blank learner from the fresh install is removed');
    // The parent shows in Important information but has no PIN here.
    final p = s.parentsOf(kid).single;
    expect(p.name, 'Sunita');
    expect(p.contactOnly, isTrue);
    expect(p.checkPin('0000'), isFalse);

    s.upsertCloudStudent(kid, {'name': 'Aarav'}, [mum], devices: {'uid-1': {'name': 'Tablet'}});
    expect(s.student!.devices.keys, ['uid-1']);

    s.markUnpaired(kid);
    final reloaded = await AppStore.load();
    expect(reloaded.student!.paired, isFalse);
    expect(reloaded.totalStars, 70, reason: 'progress stays on the device');
  });

  test('pairing codes are tidied like IDs', () {
    final c = AccountIds.pairCode();
    expect(c, matches(RegExp(r'^[0-9A-HJKMNP-TV-Z]{4}-[0-9A-HJKMNP-TV-Z]{4}$')));
    expect(AccountIds.normalizePairCode(c.replaceAll('-', ' ').toLowerCase()), c);
    expect(AccountIds.normalizePairCode('k7m2 9xqo'), 'K7M2-9XQ0');
    expect(AccountIds.normalizePairCode('123'), isNull);
  });

  test('parent hub: attempts, feedback, challenges and per-child data', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await AppStore.load();
    final kid = s.activeStudentId;
    final mum = s.createParent(name: 'Sunita', pin: '1234');
    s.selectLetter('ka');
    s.assignHomework(Homework(id: 'w', studentId: kid, assignedBy: mum.id, kind: HomeworkKind.letter, title: 'w',
        target: 'ka', goal: 2, category: 'writing'));
    s.recordAttempt('ka', 1, accuracy: 40, strokes: const [[0.1, 0.1, 0.5, 0.5]]);
    s.recordAttempt('ka', 3, accuracy: 90);
    final w = s.homeworkById('w')!;
    expect(w.attempts.length, 2);
    expect(w.attempts.first.counted, isFalse);
    expect(w.attempts.first.strokes, isNotEmpty);
    expect(w.accuracy, 65);
    expect(w.status, HomeworkStatus.inProgress);

    // A parent's cheer with bonus stars reaches the child.
    final before = s.totalStars;
    s.addHomeworkFeedback('w', ParentNote(at: '2026-01-01', by: mum.id, text: 'Shabaash!', stars: 5));
    expect(s.totalStars, before + 5);

    // Extending an overdue deadline counts from today.
    s.updateHomework('w', dueDate: '2000-01-01');
    expect(s.homeworkById('w')!.overdue, isTrue);
    s.extendHomework('w', 2);
    expect(s.homeworkById('w')!.overdue, isFalse);

    // A challenge counts from when it was set and pays its stars once.
    s.addChallenge(Challenge(id: 'c', studentId: kid, parentId: mum.id, title: 'Write 2', category: 'writing',
        metric: 'writes', target: 2, rewardStars: 10));
    s.recordAttempt('ka', 2, accuracy: 70);
    expect(s.challenges.first.progress, 1);
    final stars = s.totalStars;
    s.recordAttempt('ka', 2, accuracy: 70);
    expect(s.challenges.first.done, isTrue);
    expect(s.totalStars, stars + 2 + 10);
    s.recordAttempt('ka', 2, accuracy: 70);
    expect(s.totalStars, stars + 4 + 10);

    // Another child's figures come from their own record, and stars awarded
    // to them do not touch the active learner.
    final meera = s.addStudent('Meera');
    s.awardStars(meera.id, 7);
    expect(s.viewOf(meera.id).totalStars, 7);
    expect(s.viewOf(meera.id).counters['writes'], isNull);
    expect(s.totalStars, stars + 4 + 10);
    s.updateStudentProfile(meera.id, name: 'Meera P', avatar: '🦁', grade: 'Class 2');
    expect(s.studentById(meera.id)!.name, 'Meera P');
    expect(s.viewOf(meera.id).userName, 'Meera P');
    expect(s.userName, isNot('Meera P'));

    // Reassigning makes a fresh copy for the other child.
    final copy = s.reassignHomework('w', studentId: meera.id, parentId: mum.id)!;
    expect(copy.attempts, isEmpty);
    expect(s.homeworkFor(meera.id).single.id, copy.id);

    // The daily log feeds reports.
    final today = DateTime.now().toUtc().toIso8601String().split('T').first;
    expect(s.dailyLog[today]!['wn'], 5);
  });

  test('parent PIN: 6 letters and numbers, not easy, not anyone else\'s', () async {
    for (final p in ['AAA222', 'ABC234', 'ZYX987', 'STARRY', '258963', 'AB2345', 'STAR5']) {
      expect(weakParentPin(p), isNotNull, reason: p);
    }
    for (final p in ['STAR58', 'mum-427', 'KAP968', 'B7Q2ZD']) {
      expect(weakParentPin(p), isNull, reason: p);
    }
    SharedPreferences.setMockInitialValues({});
    final s = await AppStore.load();
    final dad = s.createParent(name: 'Raj', pin: 'STAR58');
    expect(dad.legacyPin, isFalse);
    // Small letters and a dash are fine when unlocking.
    expect(s.checkParentPin(dad.id, 'star-58'), PinCheck.ok);
    // A child's code or another parent's PIN cannot be a parent's PIN.
    expect(s.parentPinProblem(s.student!.loginCode), 'taken');
    expect(s.parentPinProblem('STAR58'), 'taken');
    expect(s.parentPinProblem('STAR58', parentId: dad.id), isNull);
    expect(s.parentPinProblem('MUM427'), isNull);
  });

  test('parent PIN: an old 4-digit PIN still opens until it is replaced', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await AppStore.load();
    final mum = s.createParent(name: 'Sunita', pin: '2468');
    // Saved before 6-character PINs: no pinLength in the record.
    final old = ParentAccount.fromJson({...mum.toJson()}..remove('pinLength'));
    expect(old.legacyPin, isTrue);
    expect(old.checkPin('2468'), isTrue);
    s.updateParent(mum.id, pin: 'MUM427');
    expect(s.parentById(mum.id)!.legacyPin, isFalse);
    expect(s.checkParentPin(mum.id, '2468'), PinCheck.wrong);
    expect(s.checkParentPin(mum.id, 'MUM427'), PinCheck.ok);
    final again = await AppStore.load();
    expect(again.parentById(mum.id)!.pinLength, 6);
  });

  test('parent PIN: wrong PINs lock it, for longer each time, and it survives a restart', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await AppStore.load();
    final mum = s.createParent(name: 'Sunita', pin: '2468');
    final t0 = DateTime(2026, 1, 1, 10);
    for (int i = 1; i < AppStore.pinFreeTries; i++) {
      expect(s.checkParentPin(mum.id, '0000', now: t0), PinCheck.wrong);
    }
    expect(s.checkParentPin(mum.id, '0000', now: t0), PinCheck.locked);
    // Even the right PIN is refused while locked.
    expect(s.checkParentPin(mum.id, '2468', now: t0.add(const Duration(seconds: 10))), PinCheck.locked);
    // The lock is saved: a reloaded store still has it.
    final again = await AppStore.load();
    expect(again.pinLockedUntil(mum.id, now: t0.add(const Duration(seconds: 10))), isNotNull);
    // After 30 seconds another wrong PIN locks for 60.
    final t1 = t0.add(const Duration(seconds: 31));
    expect(s.checkParentPin(mum.id, '0000', now: t1), PinCheck.locked);
    expect(s.pinLockedUntil(mum.id, now: t1.add(const Duration(seconds: 45))), isNotNull);
    // Once the wait is over, the right PIN works and clears the count.
    final t2 = t1.add(const Duration(minutes: 2));
    expect(s.checkParentPin(mum.id, '2468', now: t2), PinCheck.ok);
    expect(s.pinFailures(mum.id), 0);
    // Setting a new PIN clears a lock too.
    for (int i = 0; i < AppStore.pinFreeTries; i++) { s.checkParentPin(mum.id, '0000', now: t2); }
    s.updateParent(mum.id, pin: '7391');
    expect(s.checkParentPin(mum.id, '7391', now: t2), PinCheck.ok);
  });

  test('learner codes: 6 easy characters, unique, checked and changeable', () async {
    final seen = <String>{};
    for (int i = 0; i < 300; i++) {
      final c = StudentCodes.generate(taken: seen);
      expect(StudentCodes.problem(c), isNull, reason: c);
      expect(RegExp(r'^[A-Z]{3}[2-9]{3}$').hasMatch(c), isTrue, reason: c);
      expect(c.contains(RegExp('[01IOL]')), isFalse);
      expect(seen.add(c), isTrue);
    }
    expect(StudentCodes.format('KAT482'), 'KAT-482');
    expect(StudentCodes.normalize(' kat-482 '), 'KAT482');
    expect(StudentCodes.problem('KATKAT'), 'mix');
    expect(StudentCodes.problem('KAT48'), 'length');
    expect(StudentCodes.problem('KAT402'), isNull); // every letter and digit can be typed
    expect(StudentCodes.problem('KAT4#2'), 'chars');

    SharedPreferences.setMockInitialValues({});
    final s = await AppStore.load();
    final meera = s.addStudent('Meera');
    final aarav = s.student!;
    expect(aarav.loginCode, isNotEmpty);
    expect(meera.loginCode, isNotEmpty);
    expect(meera.loginCode, isNot(aarav.loginCode));
    // Typed in small letters with a dash still works.
    expect(s.checkStudentCode(meera.id, StudentCodes.format(meera.loginCode).toLowerCase()), PinCheck.ok);
    expect(s.checkStudentCode(meera.id, aarav.loginCode), PinCheck.wrong);
    // A code another child has is refused; a free one is kept.
    expect(s.setStudentCode(meera.id, aarav.loginCode), 'taken');
    expect(s.setStudentCode(meera.id, 'mee-777'), isNull);
    expect(s.studentById(meera.id)!.loginCode, 'MEE777');
    final fresh = s.newStudentCode(meera.id);
    expect(fresh, isNot('MEE777'));
    // Codes survive a reload, and learners saved before codes existed get one.
    final again = await AppStore.load();
    expect(again.studentById(meera.id)!.loginCode, fresh);
    // Too many wrong codes lock the profile for a while.
    final t = DateTime(2026, 1, 1);
    for (int i = 0; i < AppStore.pinFreeTries; i++) { s.checkStudentCode(meera.id, 'ZZZ999', now: t); }
    expect(s.checkStudentCode(meera.id, fresh, now: t), PinCheck.locked);
  });

  test('remember me, stay unlocked and last user are saved', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await AppStore.load();
    final kid = s.activeStudentId;
    final mum = s.createParent(name: 'Sunita', pin: 'STAR58');
    s.setRemembered(kid, true);
    s.keepParentUnlocked(mum.id, 15);
    s.markLastUser(kid);
    final again = await AppStore.load();
    expect(again.isRemembered(kid), isTrue);
    expect(again.parentStillUnlocked(mum.id), isTrue);
    expect(again.parentStillUnlocked(mum.id, now: DateTime.now().add(const Duration(minutes: 16))), isFalse);
    expect(again.lastUserId, kid);
    // Locking ends it; a new code or PIN forgets the old trust.
    s.keepParentUnlocked(mum.id, 0);
    expect(s.parentStillUnlocked(mum.id), isFalse);
    s.newStudentCode(kid);
    expect(s.isRemembered(kid), isFalse);
  });
}
