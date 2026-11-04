import 'dart:math';

/// Account IDs: a kind prefix and 8 characters in two groups, e.g.
/// `HMS-4F7K-29QX` for a student and `HMP-B3DR-7M0C` for a parent. The
/// characters are Crockford base 32 (no I, L, O or U, so an ID read aloud or
/// copied by hand is not mistaken), and the last one is a check character,
/// so a mistyped ID is caught before it is looked up.
class AccountIds {
  static const _alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
  static const student = 'HMS', parent = 'HMP';
  static final _rng = Random.secure();

  static String generate(String prefix, {Set<String> taken = const {}}) {
    while (true) {
      final body = [for (int i = 0; i < 7; i++) _alphabet[_rng.nextInt(32)]].join();
      final id = '$prefix-${body.substring(0, 4)}-${body.substring(4)}${_check(body)}';
      if (!taken.contains(id)) return id;
    }
  }

  static String _check(String body) {
    var sum = 0;
    for (int i = 0; i < body.length; i++) { sum += _alphabet.indexOf(body[i]) * (i + 1); }
    return _alphabet[sum % 32];
  }

  /// A pairing or invite code: 8 random characters, shown as `XXXX-XXXX`.
  static String pairCode() {
    final c = [for (int i = 0; i < 8; i++) _alphabet[_rng.nextInt(32)]].join();
    return '${c.substring(0, 4)}-${c.substring(4)}';
  }

  /// A typed pairing code tidied to `XXXX-XXXX`, or null if it can't be one.
  static String? normalizePairCode(String raw) {
    final s = raw.toUpperCase().replaceAll(RegExp(r'[\s\-_.]'), '')
        .replaceAll('O', '0').replaceAll('I', '1').replaceAll('L', '1');
    if (s.length != 8 || s.split('').any((c) => !_alphabet.contains(c))) return null;
    return '${s.substring(0, 4)}-${s.substring(4)}';
  }

  /// [raw] tidied into the standard `XXX-XXXX-XXXX` form (case, spaces,
  /// missing dashes and the look-alikes O→0 and I/L→1), or null when it is
  /// not a valid [prefix] ID.
  static String? normalize(String raw, String prefix) {
    var s = raw.toUpperCase().replaceAll(RegExp(r'[\s\-_.]'), '');
    if (s.startsWith(prefix)) s = s.substring(prefix.length);
    s = s.replaceAll('O', '0').replaceAll('I', '1').replaceAll('L', '1');
    if (s.length != 8 || s.split('').any((c) => !_alphabet.contains(c))) return null;
    final body = s.substring(0, 7);
    if (_check(body) != s[7]) return null;
    return '$prefix-${s.substring(0, 4)}-${s.substring(4)}';
  }
}

/// A learner's login code: 6 characters, letters and numbers, that opens
/// their profile. Any letter A-Z and digit 0-9 can be typed. Generated codes
/// read like a word and a number (`KAT-482`): consonant, vowel, consonant,
/// then three digits, and never use look-alikes (0/O, 1/I/L), so a code
/// read aloud or copied by a child is not mistaken.
class StudentCodes {
  static const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static const digits = '0123456789';
  /// Digits used in generated codes (no 0 or 1).
  static const _safeDigits = '23456789';
  static const length = 6;
  static const _consonants = 'BDFGHJKMNPRSTVZ', _vowels = 'AEU';
  // Three-letter words a generated code should not spell.
  static const _blocked = {'FUK', 'SEX', 'DUM', 'FAT', 'BUM', 'PUP', 'NUT', 'GUN', 'DED', 'HAT'};
  static final _rng = Random.secure();

  static String generate({Set<String> taken = const {}}) {
    String pick(String from) => from[_rng.nextInt(from.length)];
    while (true) {
      final word = '${pick(_consonants)}${pick(_vowels)}${pick(_consonants)}';
      if (_blocked.contains(word)) continue;
      final code = '$word${pick(_safeDigits)}${pick(_safeDigits)}${pick(_safeDigits)}';
      if (!taken.contains(code)) return code;
    }
  }

  /// [raw] in capitals without spaces or dashes.
  static String normalize(String raw) => raw.toUpperCase().replaceAll(RegExp(r'[\s\-_.]'), '');

  /// Why [code] (normalized) cannot be a login code, or null if it can.
  static String? problem(String code) {
    if (code.length != length) return 'length';
    if (code.split('').any((c) => !letters.contains(c) && !digits.contains(c))) return 'chars';
    if (!code.split('').any(letters.contains) || !code.split('').any(digits.contains)) return 'mix';
    return null;
  }

  /// `KAT482` → `KAT-482`, easier to read.
  static String format(String code) => code.length == 6 ? '${code.substring(0, 3)}-${code.substring(3)}' : code;
}

/// PIN fingerprint for the parent lock. It only keeps the PIN out of plain
/// sight in local storage: anyone who can read the device's app data can
/// still reset the app, so it is a child lock, not account security.
String hashPin(String pin, String salt) {
  int h1 = 5381, h2 = 52711;
  for (final c in '$salt:$pin'.codeUnits) {
    h1 = (h1 * 33 + c) & 0x7fffffff;
    h2 = (h2 * 31 + c) & 0x7fffffff;
  }
  return '${h1.toRadixString(16)}${h2.toRadixString(16)}';
}

String _now() => DateTime.now().toUtc().toIso8601String();

enum PinCheck { ok, wrong, locked }

/// Why a parent's 6-character PIN [raw] cannot be used: not 6 letters and
/// numbers (`length`, `chars`, `mix`), too few different characters
/// (`same`, like AAA222) or a straight run (`sequence`, like ABC234), or
/// null if it is fine.
String? weakParentPin(String raw) {
  final code = StudentCodes.normalize(raw);
  final problem = StudentCodes.problem(code);
  if (problem != null) return problem;
  if (code.split('').toSet().length < 3) return 'same';
  bool run(List<int> c) => c.length >= 2 &&
      (List.generate(c.length - 1, (i) => c[i + 1] - c[i]).every((d) => d == 1) ||
          List.generate(c.length - 1, (i) => c[i + 1] - c[i]).every((d) => d == -1));
  final letters = [for (final u in code.codeUnits) if (u >= 65) u];
  final digits = [for (final u in code.codeUnits) if (u < 65) u];
  if ((letters.length < 2 || run(letters)) && (digits.length < 2 || run(digits))) return 'sequence';
  return null;
}

/// One learner on this device. Their progress is saved separately, under
/// their [id]; this is the identity and the record's important information.
class StudentAccount {
  final String id;
  String name, avatar, createdAt;
  /// Linked parents / guardians (their [ParentAccount.id]s), main one first.
  List<String> parentIds;
  String dateOfBirth, grade, school, city, emergencyContact, notes;
  /// A child who learns on another device: a read-only copy of their cloud
  /// record, kept so a parent can follow them from their own phone.
  bool remote;
  /// This device was paired to the child with a parent's code: it syncs
  /// their progress without a parent signed in.
  bool paired;
  /// The child's paired devices (Firebase uid → {name, pairedAt}), for parents.
  Map<String, dynamic> devices;
  /// 6-character code that opens this learner's profile ([StudentCodes]).
  /// Kept readable on this device so a parent can tell a child their code.
  String loginCode;
  StudentAccount({required this.id, this.name = 'Student', this.avatar = '', String? createdAt,
      List<String>? parentIds, this.dateOfBirth = '', this.grade = '', this.school = '', this.city = '',
      this.emergencyContact = '', this.notes = '', this.remote = false, this.paired = false,
      Map<String, dynamic>? devices, this.loginCode = ''})
      : createdAt = createdAt ?? _now(), parentIds = parentIds ?? [], devices = devices ?? {};

  /// The details shared through the cloud (notes stay on the device).
  static const cloudInfoKeys = ['name', 'avatar', 'dateOfBirth', 'grade', 'school', 'city', 'emergencyContact'];
  Map<String, dynamic> cloudInfo() {
    final j = toJson();
    return {for (final k in cloudInfoKeys) k: j[k]};
  }

  Map<String, dynamic> toJson() => {
        'id': id, 'name': name, 'avatar': avatar, 'createdAt': createdAt, 'parentIds': parentIds,
        'dateOfBirth': dateOfBirth, 'grade': grade, 'school': school, 'city': city,
        'emergencyContact': emergencyContact, 'notes': notes, if (remote) 'remote': true,
        if (paired) 'paired': true, if (devices.isNotEmpty) 'devices': devices,
        if (loginCode.isNotEmpty) 'loginCode': loginCode,
      };
  factory StudentAccount.fromJson(Map<String, dynamic> j) => StudentAccount(
        id: j['id'], name: j['name'] ?? 'Student', avatar: j['avatar'] ?? '', createdAt: j['createdAt'],
        parentIds: List<String>.from(j['parentIds'] ?? const []),
        dateOfBirth: j['dateOfBirth'] ?? '', grade: j['grade'] ?? '', school: j['school'] ?? '',
        city: j['city'] ?? '', emergencyContact: j['emergencyContact'] ?? '', notes: j['notes'] ?? '',
        remote: j['remote'] ?? false, paired: j['paired'] ?? false,
        devices: j['devices'] is Map ? Map<String, dynamic>.from(j['devices']) : null,
        loginCode: j['loginCode'] ?? '',
      );
}

/// A parent or guardian. Parent mode (records, homework, editing a child's
/// information) opens with their PIN.
class ParentAccount {
  final String id;
  String name, relationship, phone, email, createdAt;
  String pinHash;
  /// Salt of [pinHash]: the ID the parent had when the PIN was set, so the
  /// PIN keeps working if the ID changes (e.g. when signing in to the cloud).
  final String pinSalt;
  /// Characters in the PIN: 6 (letters and numbers), or 4 for a digits-only
  /// PIN set before 6-character PINs, which is replaced at the next unlock.
  int pinLength;
  /// Firebase user this parent signed in as ('' = not signed in on this
  /// device), and when their children were last backed up to the cloud.
  String cloudUid;
  String? lastBackupAt;
  ParentAccount({required this.id, required this.name, this.relationship = 'Parent', this.phone = '',
      this.email = '', String? createdAt, this.pinHash = '', this.cloudUid = '', this.lastBackupAt, String? pinSalt,
      this.pinLength = 6})
      : createdAt = createdAt ?? _now(), pinSalt = pinSalt ?? id;

  /// A parent known only from a child's cloud record (on the child's own
  /// device): their name and contact, but no PIN here, so no parent control.
  bool get contactOnly => pinHash.isEmpty;

  /// An old 4-digit PIN that should be replaced by a 6-character one.
  bool get legacyPin => pinHash.isNotEmpty && pinLength < 6;
  // Letters are compared in capitals, without spaces or dashes.
  bool checkPin(String pin) => pinHash.isNotEmpty && hashPin(StudentCodes.normalize(pin), pinSalt) == pinHash;
  void setPin(String pin) {
    final p = StudentCodes.normalize(pin);
    pinHash = hashPin(p, pinSalt);
    pinLength = p.length;
  }

  Map<String, dynamic> toJson() => {
        'id': id, 'name': name, 'relationship': relationship, 'phone': phone, 'email': email,
        'createdAt': createdAt, 'pinHash': pinHash, 'pinSalt': pinSalt, 'pinLength': pinLength, 'cloudUid': cloudUid,
        'lastBackupAt': lastBackupAt,
      };
  factory ParentAccount.fromJson(Map<String, dynamic> j) => ParentAccount(
        id: j['id'], name: j['name'] ?? '', relationship: j['relationship'] ?? 'Parent', phone: j['phone'] ?? '',
        email: j['email'] ?? '', createdAt: j['createdAt'], pinHash: j['pinHash'] ?? '',
        cloudUid: j['cloudUid'] ?? '', lastBackupAt: j['lastBackupAt'], pinSalt: j['pinSalt'] ?? j['id'],
        // Saved before 6-character PINs: a 4-digit PIN.
        pinLength: j['pinLength'] ?? 4,
      );
}

/// What a homework asks for.
/// - `level`: pass level [Homework.level] of activity [Homework.target]
///   [Homework.goal] times.
/// - `letter`: [Homework.goal] good writes (2★ or more) of letter [Homework.target].
/// - `practice`: [Homework.goal] graded writes of anything.
enum HomeworkKind { level, letter, practice }

/// One try at a homework: when, how well (accuracy 0-100 when the activity
/// grades it, stars when it gives them), and, for a letter write, the
/// child's strokes normalised to 0-1, so a parent can see the work.
class HomeworkAttempt {
  final String at;
  final int? accuracy;
  final int stars, seconds;
  final bool counted;
  final List<List<double>> strokes; // each stroke: x0,y0,x1,y1,...
  const HomeworkAttempt({required this.at, this.accuracy, this.stars = 0, this.seconds = 0, this.counted = true,
      this.strokes = const []});
  Map<String, dynamic> toJson() => {
        'at': at, 'accuracy': accuracy, 'stars': stars, 'seconds': seconds, 'counted': counted,
        if (strokes.isNotEmpty) 'strokes': strokes,
      };
  factory HomeworkAttempt.fromJson(Map<String, dynamic> j) => HomeworkAttempt(
        at: j['at'] ?? '', accuracy: j['accuracy'], stars: j['stars'] ?? 0, seconds: j['seconds'] ?? 0,
        counted: j['counted'] ?? true,
        strokes: [for (final s in (j['strokes'] as List? ?? const [])) [for (final v in s as List) (v as num).toDouble()]],
      );
}

/// A message from a parent on a homework (praise, a tip), with optional
/// bonus stars that were added to the child's total.
class ParentNote {
  final String at, by, text;
  final int stars;
  const ParentNote({required this.at, required this.by, required this.text, this.stars = 0});
  Map<String, dynamic> toJson() => {'at': at, 'by': by, 'text': text, 'stars': stars};
  factory ParentNote.fromJson(Map<String, dynamic> j) =>
      ParentNote(at: j['at'] ?? '', by: j['by'] ?? '', text: j['text'] ?? '', stars: j['stars'] ?? 0);
}

enum HomeworkStatus { assigned, inProgress, completed, overdue }

class Homework {
  final String id, studentId, assignedBy, createdAt;
  final HomeworkKind kind;
  String title, target, note;
  String? dueDate; // yyyy-mm-dd
  int goal, level;
  int progress;
  String? completedAt;
  /// Parent Hub category (writing, reading, matras, listening, quiz, speaking)
  /// and difficulty (easy, normal, hard).
  String category, difficulty;
  List<HomeworkAttempt> attempts;
  List<ParentNote> feedback;
  Homework({required this.id, required this.studentId, required this.assignedBy, required this.kind,
      required this.title, this.target = '', this.note = '', this.dueDate, this.goal = 1, this.level = 0,
      this.progress = 0, this.completedAt, String? createdAt, this.category = '', this.difficulty = 'normal',
      List<HomeworkAttempt>? attempts, List<ParentNote>? feedback})
      : createdAt = createdAt ?? _now(), attempts = attempts ?? [], feedback = feedback ?? [];

  bool get done => completedAt != null;
  bool get overdue {
    if (done || dueDate == null) return false;
    return dueDate!.compareTo(DateTime.now().toIso8601String().split('T').first) < 0;
  }

  HomeworkStatus get status => done ? HomeworkStatus.completed : overdue ? HomeworkStatus.overdue
      : attempts.isEmpty && progress == 0 ? HomeworkStatus.assigned : HomeworkStatus.inProgress;
  double get fraction => goal <= 0 ? 0 : (progress / goal).clamp(0.0, 1.0);
  int get secondsSpent => attempts.fold(0, (a, b) => a + b.seconds);
  /// Average accuracy of graded attempts, or null when none was graded.
  int? get accuracy {
    final g = attempts.where((a) => a.accuracy != null).toList();
    return g.isEmpty ? null : (g.fold<int>(0, (a, b) => a + b.accuracy!) / g.length).round();
  }

  Map<String, dynamic> toJson() => {
        'id': id, 'studentId': studentId, 'assignedBy': assignedBy, 'createdAt': createdAt, 'kind': kind.name,
        'title': title, 'target': target, 'note': note, 'dueDate': dueDate, 'goal': goal, 'level': level,
        'progress': progress, 'completedAt': completedAt, 'category': category, 'difficulty': difficulty,
        'attempts': [for (final a in attempts) a.toJson()], 'feedback': [for (final f in feedback) f.toJson()],
      };
  factory Homework.fromJson(Map<String, dynamic> j) => Homework(
        id: j['id'], studentId: j['studentId'], assignedBy: j['assignedBy'] ?? '', createdAt: j['createdAt'],
        kind: HomeworkKind.values.firstWhere((k) => k.name == j['kind'], orElse: () => HomeworkKind.practice),
        title: j['title'] ?? '', target: j['target'] ?? '', note: j['note'] ?? '', dueDate: j['dueDate'],
        goal: j['goal'] ?? 1, level: j['level'] ?? 0, progress: j['progress'] ?? 0, completedAt: j['completedAt'],
        category: j['category'] ?? '', difficulty: j['difficulty'] ?? 'normal',
        attempts: [for (final a in (j['attempts'] as List? ?? const [])) HomeworkAttempt.fromJson(Map<String, dynamic>.from(a))],
        feedback: [for (final f in (j['feedback'] as List? ?? const [])) ParentNote.fromJson(Map<String, dynamic>.from(f))],
      );
}

/// A goal a parent sets for a child: reach [target] of [metric] (counted
/// from [baseline], the child's figure when it was set) by [deadline], for
/// a reward. Metrics: writes, reads, speaks, days, stars.
class Challenge {
  final String id, studentId, parentId, createdAt;
  String title, description, category, metric, message, reward, badgeEmoji;
  String? deadline; // yyyy-mm-dd
  int target, baseline, rewardStars, progress;
  String? completedAt;
  Challenge({required this.id, required this.studentId, required this.parentId, required this.title,
      this.description = '', required this.category, required this.metric, required this.target, this.baseline = 0,
      this.deadline, this.reward = 'stars', this.rewardStars = 10, this.badgeEmoji = '🏅', this.message = '',
      this.progress = 0, this.completedAt, String? createdAt})
      : createdAt = createdAt ?? _now();

  bool get done => completedAt != null;
  bool get expired {
    if (done || deadline == null) return false;
    return deadline!.compareTo(DateTime.now().toIso8601String().split('T').first) < 0;
  }
  double get fraction => target <= 0 ? 0 : (progress / target).clamp(0.0, 1.0);

  Map<String, dynamic> toJson() => {
        'id': id, 'studentId': studentId, 'parentId': parentId, 'createdAt': createdAt, 'title': title,
        'description': description, 'category': category, 'metric': metric, 'target': target, 'baseline': baseline,
        'deadline': deadline, 'reward': reward, 'rewardStars': rewardStars, 'badgeEmoji': badgeEmoji,
        'message': message, 'progress': progress, 'completedAt': completedAt,
      };
  factory Challenge.fromJson(Map<String, dynamic> j) => Challenge(
        id: j['id'], studentId: j['studentId'], parentId: j['parentId'] ?? '', createdAt: j['createdAt'],
        title: j['title'] ?? '', description: j['description'] ?? '', category: j['category'] ?? 'daily',
        metric: j['metric'] ?? 'days', target: j['target'] ?? 1, baseline: j['baseline'] ?? 0, deadline: j['deadline'],
        reward: j['reward'] ?? 'stars', rewardStars: j['rewardStars'] ?? 10, badgeEmoji: j['badgeEmoji'] ?? '🏅',
        message: j['message'] ?? '', progress: j['progress'] ?? 0, completedAt: j['completedAt'],
      );
}

/// A learner's progress figures, read from their saved record (so a parent
/// can see every child without switching profiles).
class StudentRecord {
  final int totalStars, totalPoints, currentStreak, longestStreak, mastered, lettersStarted, daysPracticed,
      activeThisWeek, todayCount, dailyGoal;
  final int? averageAccuracy;
  final String? lastActiveDate;
  final Map<String, int> activityProgress;
  final List<String> weakLetters;
  final bool onboarded;
  const StudentRecord({this.totalStars = 0, this.totalPoints = 0, this.currentStreak = 0, this.longestStreak = 0,
      this.mastered = 0, this.lettersStarted = 0, this.daysPracticed = 0, this.activeThisWeek = 0,
      this.todayCount = 0, this.dailyGoal = 3, this.averageAccuracy, this.lastActiveDate,
      this.activityProgress = const {}, this.weakLetters = const [], this.onboarded = false});

  factory StudentRecord.fromJson(Map<String, dynamic> j) {
    final lp = (j['letterProgress'] as Map? ?? {}).values.map((v) => v as Map).toList();
    final dates = List<String>.from(j['practicedDates'] ?? const []);
    final now = DateTime.now();
    final week = {for (int i = 0; i < 7; i++) now.subtract(Duration(days: i)).toUtc().toIso8601String().split('T').first};
    final sum = Map<String, int>.from(j['letterAccSum'] ?? {}), count = Map<String, int>.from(j['letterAccCount'] ?? {});
    final n = count.values.fold<int>(0, (a, b) => a + b);
    final avg = <String, int>{
      for (final e in count.entries) if (e.value > 0) e.key: ((sum[e.key] ?? 0) / e.value).round(),
    };
    final weak = (avg.entries.where((e) => e.value < 60).toList()..sort((a, b) => a.value.compareTo(b.value)))
        .map((e) => e.key).take(5).toList();
    return StudentRecord(
      totalStars: j['totalStars'] ?? 0, totalPoints: j['totalPoints'] ?? 0,
      currentStreak: j['currentStreak'] ?? 0, longestStreak: j['longestStreak'] ?? 0,
      mastered: lp.where((p) => p['mastered'] == true).length, lettersStarted: lp.length,
      daysPracticed: dates.length, activeThisWeek: dates.where(week.contains).length,
      todayCount: j['todayPracticeCount'] ?? 0, dailyGoal: j['dailyGoal'] ?? 3,
      averageAccuracy: n == 0 ? null : (sum.values.fold<int>(0, (a, b) => a + b) / n).round(),
      lastActiveDate: dates.isEmpty ? j['lastActiveDate'] : (dates.toList()..sort()).last,
      activityProgress: Map<String, int>.from(j['activityProgress'] ?? {}),
      weakLetters: weak, onboarded: j['onboardingComplete'] ?? false,
    );
  }
}
