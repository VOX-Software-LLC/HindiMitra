import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/accounts.dart';
import '../data/models.dart' show unlockAll;
import '../data/parent_hub.dart' show categoryOfActivity, categoryCounter;
import '../l10n.dart';
import '../theme/themes.dart';

class LetterProgress {
  String letterId;
  int currentStage, starsEarned, attemptsInCurrentStage, successfulAttempts;
  /// Best result on this letter (0-3 stars). This, not the stage, is what
  /// the level and section star counts add up.
  int bestStars;
  bool mastered;
  String? lastPracticedAt;
  LetterProgress({
    required this.letterId, this.currentStage = 1, this.starsEarned = 0,
    this.attemptsInCurrentStage = 0, this.successfulAttempts = 0, this.bestStars = 0,
    this.mastered = false, this.lastPracticedAt,
  });
  Map<String, dynamic> toJson() => {
        'letterId': letterId, 'currentStage': currentStage, 'starsEarned': starsEarned,
        'attemptsInCurrentStage': attemptsInCurrentStage,
        'successfulAttempts': successfulAttempts, 'bestStars': bestStars, 'mastered': mastered,
        'lastPracticedAt': lastPracticedAt,
      };
  factory LetterProgress.fromJson(Map<String, dynamic> j) => LetterProgress(
        letterId: j['letterId'], currentStage: j['currentStage'] ?? 1,
        starsEarned: j['starsEarned'] ?? 0,
        attemptsInCurrentStage: j['attemptsInCurrentStage'] ?? 0,
        successfulAttempts: j['successfulAttempts'] ?? 0,
        bestStars: j['bestStars'] ?? _bestStarsFromHistory(j),
        mastered: j['mastered'] ?? false, lastPracticedAt: j['lastPracticedAt'],
      );

  /// For progress saved before [bestStars] existed: a mastered letter had a
  /// 2★+ write from memory, a later stage or any success means a 2★ write,
  /// and any stars at all mean at least 1★.
  static int _bestStarsFromHistory(Map<String, dynamic> j) {
    if (j['mastered'] == true) return 3;
    if ((j['currentStage'] ?? 1) > 1 || (j['successfulAttempts'] ?? 0) > 0) return 2;
    return (j['starsEarned'] ?? 0) > 0 ? 1 : 0;
  }
}

String _today() => DateTime.now().toUtc().toIso8601String().split('T').first;

/// Port of the Zustand `useAppStore` (persisted under key `hindi-mitra-store`).
class AppStore extends ChangeNotifier {
  static const _key = 'hindi-mitra-store';
  /// Key used before the HindiMitra rename; read once so saved progress carries over.
  static const _legacyKey = 'hindi-sikho-store';
  /// Learners, parents and homework on this device. Each learner's progress
  /// (the fields below) is saved under [_studentKey]; the store holds the
  /// active learner's.
  static const _accountsKey = 'hindi-mitra-accounts';
  static String _studentKey(String id) => 'hindi-mitra-student:$id';
  List<StudentAccount> students = [];
  List<ParentAccount> parents = [];
  List<Homework> homework = [];
  List<Challenge> challenges = [];
  /// Wrong parent PINs per parent: `fails` in a row and `until` (ISO time)
  /// the PIN is locked. Saved, so closing the app does not reset it.
  Map<String, Map<String, dynamic>> pinGuard = {};
  /// Learners who chose "Remember me on this phone": their code is not
  /// asked for again on this device until a parent turns it off.
  List<String> rememberedStudents = [];
  /// Parent id → when (ISO) their "stay unlocked" ends: until then the
  /// Parent Hub opens without the PIN on this device.
  Map<String, String> parentUnlockedUntil = {};
  /// Who used the app last (a learner or parent id), shown first on the chooser.
  String lastUserId = '';
  String activeStudentId = '';
  String userName = 'Student';
  int userLevel = 1, totalStars = 0, totalPoints = 0, currentStreak = 0, longestStreak = 0;
  String? lastActiveDate;
  Map<String, LetterProgress> letterProgress = {};
  bool _premium = false, onboardingComplete = false;
  bool get isPremium => unlockAll || _premium;
  String? selectedLetterId, ageGroup, userRole;
  List<String> practicedDates = [];
  int dailyGoal = 3, todayPracticeCount = 0;
  Map<String, int> activityProgress = {};
  String themePref = 'system'; // legacy: system | light | dark
  String themeId = 'sunny'; // one of AppThemes.all
  String hindiName = ''; // the user's name in Devanagari, as they corrected it ('' = automatic)
  List<String> notifyFeatures = []; // upcoming features the user asked to hear about
  /// Per-letter accuracy (0-100) of every graded attempt: sum + count.
  Map<String, int> letterAccSum = {}, letterAccCount = {};
  /// Best accuracy % reached per writing level id.
  Map<String, int> levelBestAccuracy = {};
  /// Seconds practised per UTC day (yyyy-mm-dd) — weekly chart on Profile.
  Map<String, int> practiceSeconds = {};
  /// Up to 3 badge ids pinned to the Profile showcase.
  List<String> pinnedBadges = [];
  /// Earned badges the child has already seen unlock (so the reveal plays once).
  List<String> seenBadges = [];
  bool soundOn = true, leftHanded = false;
  /// Recorded voice for letters: 'female' or 'male'.
  String voice = 'female';
  String difficulty = 'normal'; // easy | normal | hard
  /// Result card layout after a write: 'detailed' (every criterion and how
  /// the score adds up) or 'compact' (score, stars and the top tip).
  String resultStyle = 'detailed';
  /// 'guided' = the tracing guide fades over 10 writes; 'independent' = no
  /// tracing guide at all (a small model to look at, for confident writers).
  String writingMode = 'guided';
  /// Writing board ruling: 'copybook' (header + base line), 'grid' or 'plain'.
  String boardStyle = 'copybook';
  String appLanguage = 'en'; // en | hi
  String avatar = '';
  /// Per-word writing skill (0-100, moving average of graded attempts) and how
  /// many practice repetitions of each word have been completed in total.
  Map<String, int> wordSkill = {}, wordReps = {};
  /// Running totals the Parent Hub measures challenges against: graded
  /// `writes`, passed `levels`, and passes per category (`reads`, `matras`,
  /// `listens`, `quizzes`, `speaks`).
  Map<String, int> counters = {};
  /// Per UTC day (yyyy-mm-dd): `n` practices, `sec` seconds in activities,
  /// `ws`/`wn` writing accuracy sum/count, `lv` levels passed and `c:<category>`
  /// passes per category, for the Parent Hub's charts and reports.
  Map<String, Map<String, int>> dailyLog = {};

  SharedPreferences? _p;

  static Future<AppStore> load() async {
    final s = AppStore();
    final p = s._p = await SharedPreferences.getInstance();
    final reg = p.getString(_accountsKey);
    Map<String, dynamic>? blob;
    if (reg != null) {
      try {
        final r = json.decode(reg) as Map<String, dynamic>;
        s.students = [for (final e in (r['students'] as List? ?? [])) StudentAccount.fromJson(Map<String, dynamic>.from(e))];
        s.parents = [for (final e in (r['parents'] as List? ?? [])) ParentAccount.fromJson(Map<String, dynamic>.from(e))];
        s.homework = [for (final e in (r['homework'] as List? ?? [])) Homework.fromJson(Map<String, dynamic>.from(e))];
        s.challenges = [for (final e in (r['challenges'] as List? ?? [])) Challenge.fromJson(Map<String, dynamic>.from(e))];
        s.pinGuard = ((r['pinGuard'] ?? {}) as Map).map((k, v) => MapEntry(k as String, Map<String, dynamic>.from(v as Map)));
        s.rememberedStudents = List<String>.from(r['rememberedStudents'] ?? const []);
        s.parentUnlockedUntil = Map<String, String>.from(r['parentUnlockedUntil'] ?? const {});
        s.lastUserId = r['lastUserId'] ?? '';
        s.activeStudentId = r['activeStudentId'] ?? '';
        s._premium = r['premium'] ?? false;
      } catch (_) {}
    }
    if (s.students.isEmpty) {
      // First run, or progress saved before accounts: it becomes the first learner.
      s.students = [StudentAccount(id: AccountIds.generate(AccountIds.student))];
      s.activeStudentId = s.students.first.id;
      final raw = p.getString(_key) ?? p.getString(_legacyKey);
      if (raw != null) {
        try {
          blob = json.decode(raw) as Map<String, dynamic>;
          s._premium = blob['isPremium'] ?? false;
        } catch (_) {}
      }
    } else {
      if (s.studentById(s.activeStudentId)?.remote ?? true) {
        s.activeStudentId = (s.students.where((x) => !x.remote).firstOrNull ?? s.students.first).id;
      }
      final raw = p.getString(_studentKey(s.activeStudentId));
      if (raw != null) {
        try { blob = json.decode(raw) as Map<String, dynamic>; } catch (_) {}
      }
    }
    if (blob != null) s._apply(blob);
    s._save();
    return s;
  }

  /// Loads one learner's saved progress into the store (missing values take
  /// their defaults, so a new learner starts clean).
  void _apply(Map<String, dynamic> j) {
    try {
      userName = j['userName'] ?? 'Student';
      userLevel = j['userLevel'] ?? 1;
      totalStars = j['totalStars'] ?? 0;
      totalPoints = j['totalPoints'] ?? 0;
      currentStreak = j['currentStreak'] ?? 0;
      longestStreak = j['longestStreak'] ?? 0;
      lastActiveDate = j['lastActiveDate'];
      letterProgress = ((j['letterProgress'] ?? {}) as Map).map(
          (k, v) => MapEntry(k as String, LetterProgress.fromJson(Map<String, dynamic>.from(v))));
      selectedLetterId = j['selectedLetterId'];
      onboardingComplete = j['onboardingComplete'] ?? false;
      ageGroup = j['ageGroup'];
      userRole = j['userRole'];
      practicedDates = List<String>.from(j['practicedDates'] ?? []);
      dailyGoal = j['dailyGoal'] ?? 3;
      todayPracticeCount = j['todayPracticeCount'] ?? 0;
      activityProgress = Map<String, int>.from(j['activityProgress'] ?? {});
      themePref = j['themePref'] ?? 'system';
      themeId = j['themeId'] ?? (themePref == 'dark' ? 'night' : 'sunny');
      hindiName = j['hindiName'] ?? '';
      notifyFeatures = List<String>.from(j['notifyFeatures'] ?? const []);
      letterAccSum = Map<String, int>.from(j['letterAccSum'] ?? {});
      letterAccCount = Map<String, int>.from(j['letterAccCount'] ?? {});
      levelBestAccuracy = Map<String, int>.from(j['levelBestAccuracy'] ?? {});
      practiceSeconds = Map<String, int>.from(j['practiceSeconds'] ?? {});
      pinnedBadges = List<String>.from(j['pinnedBadges'] ?? []);
      seenBadges = List<String>.from(j['seenBadges'] ?? []);
      soundOn = j['soundOn'] ?? true;
      voice = j['voice'] ?? 'female';
      leftHanded = j['leftHanded'] ?? false;
      difficulty = j['difficulty'] ?? 'normal';
      resultStyle = j['resultStyle'] ?? 'detailed';
      writingMode = j['writingMode'] ?? 'guided';
      boardStyle = j['boardStyle'] ?? 'copybook';
      appLanguage = j['appLanguage'] ?? 'en';
      avatar = j['avatar'] ?? '';
      wordSkill = Map<String, int>.from(j['wordSkill'] ?? {});
      wordReps = Map<String, int>.from(j['wordReps'] ?? {});
      counters = Map<String, int>.from(j['counters'] ?? {});
      dailyLog = ((j['dailyLog'] ?? {}) as Map).map((k, v) => MapEntry(k as String, Map<String, int>.from(v as Map)));
    } catch (_) {}
  }

  Map<String, dynamic> _record() => {
        'userName': userName, 'userLevel': userLevel, 'totalStars': totalStars,
        'totalPoints': totalPoints, 'currentStreak': currentStreak,
        'longestStreak': longestStreak, 'lastActiveDate': lastActiveDate,
        'letterProgress': letterProgress.map((k, v) => MapEntry(k, v.toJson())),
        'selectedLetterId': selectedLetterId,
        'onboardingComplete': onboardingComplete, 'ageGroup': ageGroup,
        'userRole': userRole, 'practicedDates': practicedDates, 'dailyGoal': dailyGoal,
        'todayPracticeCount': todayPracticeCount, 'activityProgress': activityProgress,
        'themePref': themePref, 'themeId': themeId, 'hindiName': hindiName, 'notifyFeatures': notifyFeatures,
        'letterAccSum': letterAccSum, 'letterAccCount': letterAccCount,
        'levelBestAccuracy': levelBestAccuracy, 'practiceSeconds': practiceSeconds,
        'pinnedBadges': pinnedBadges, 'seenBadges': seenBadges, 'soundOn': soundOn, 'voice': voice, 'leftHanded': leftHanded,
        'difficulty': difficulty, 'resultStyle': resultStyle, 'writingMode': writingMode, 'boardStyle': boardStyle,
        'appLanguage': appLanguage, 'avatar': avatar,
        'wordSkill': wordSkill, 'wordReps': wordReps, 'counters': counters, 'dailyLog': dailyLog,
      };

  void _save() {
    _checkChallenges();
    notifyListeners();
    final st = student;
    if (st != null) {
      st.name = userName;
      st.avatar = avatar;
      _p?.setString(_studentKey(st.id), json.encode(_record()));
    }
    _saveAccounts();
  }

  void _saveAccounts() {
    _ensureCodes();
    _p?.setString(_accountsKey, json.encode({
      'version': 1, 'activeStudentId': activeStudentId, 'premium': _premium,
      'students': [for (final x in students) x.toJson()],
      'parents': [for (final x in parents) x.toJson()],
      'homework': [for (final x in homework) x.toJson()],
      'challenges': [for (final x in challenges) x.toJson()],
      'pinGuard': pinGuard,
      'rememberedStudents': rememberedStudents, 'parentUnlockedUntil': parentUnlockedUntil, 'lastUserId': lastUserId,
    }));
  }

  void selectLetter(String id) {
    letterProgress.putIfAbsent(id, () => LetterProgress(letterId: id));
    selectedLetterId = id;
    _save();
  }

  void initializeLetterProgress(String id) {
    letterProgress[id] = LetterProgress(letterId: id);
    _save();
  }

  /// Mastery rule (same as RN): stages 1-3 need 3 successful (>=2 star) attempts
  /// to advance; stage 4 needs a single success to master.
  void recordAttempt(String letterId, int stars, {int? accuracy, int practicedSeconds = 0,
      List<List<double>> strokes = const []}) {
    final p = letterProgress[letterId];
    if (p == null) return;
    if (accuracy != null) {
      letterAccSum[letterId] = (letterAccSum[letterId] ?? 0) + accuracy.clamp(0, 100);
      letterAccCount[letterId] = (letterAccCount[letterId] ?? 0) + 1;
      _log('ws', accuracy.clamp(0, 100));
      _log('wn');
    }
    _log('n');
    _log('c:writing');
    counters['writes'] = (counters['writes'] ?? 0) + 1;
    if (practicedSeconds > 0) {
      final d = _today();
      practiceSeconds[d] = (practiceSeconds[d] ?? 0) + practicedSeconds;
    }
    final success = stars >= 2;
    int newSuccessful = success ? p.successfulAttempts + 1 : p.successfulAttempts;
    int newStage = p.currentStage;
    bool mastered = p.mastered;
    int attempts = p.attemptsInCurrentStage + 1;
    if (p.currentStage == 4) {
      if (success) mastered = true;
    } else if (newSuccessful >= 3) {
      newStage = p.currentStage + 1;
      attempts = 0;
      newSuccessful = 0;
    }
    final today = _today();
    totalStars += stars;
    totalPoints += stars * 10 * p.currentStage;
    todayPracticeCount += 1;
    if (!practicedDates.contains(today)) practicedDates.add(today);
    p.currentStage = newStage;
    p.starsEarned += stars;
    if (stars > p.bestStars) p.bestStars = stars.clamp(0, 3);
    p.attemptsInCurrentStage = attempts;
    p.successfulAttempts = newSuccessful;
    p.mastered = mastered;
    p.lastPracticedAt = DateTime.now().toUtc().toIso8601String();
    _homeworkEvent(graded: true, letterId: letterId, stars: stars, accuracy: accuracy,
        seconds: practicedSeconds, strokes: strokes);
    _save();
  }

  /// Records one graded write of [word]. Skill is a moving average weighted
  /// toward recent attempts, so improving quickly lowers [wordRepsNeeded].
  void recordWordAttempt(String word, int accuracy, {bool countsAsRep = true}) {
    final prev = wordSkill[word];
    wordSkill[word] = prev == null ? accuracy : (prev * 0.6 + accuracy * 0.4).round();
    if (countsAsRep) wordReps[word] = (wordReps[word] ?? 0) + 1;
    final today = _today();
    todayPracticeCount += 1;
    if (!practicedDates.contains(today)) practicedDates.add(today);
    _log('n');
    _log('ws', accuracy.clamp(0, 100));
    _log('wn');
    counters['writes'] = (counters['writes'] ?? 0) + 1;
    _homeworkEvent(graded: true, accuracy: accuracy);
    _save();
  }

  /// How many good writes of [word] a session asks for: 5 for a new or weak
  /// word, down to 1 once it is written reliably well.
  int wordRepsNeeded(String word) {
    final s = wordSkill[word];
    if (s == null || s < 50) return 5;
    if (s < 65) return 4;
    if (s < 80) return 3;
    if (s < 90) return 2;
    return 1;
  }

  /// Letter ids ordered weakest first (lowest average accuracy, then least practiced).
  List<String> weakestLetters(List<String> ids) {
    final sorted = [...ids]..sort((a, b) {
        final aa = letterAccuracy(a) ?? 101, bb = letterAccuracy(b) ?? 101;
        if (aa != bb) return aa.compareTo(bb);
        return (letterAccCount[a] ?? 0).compareTo(letterAccCount[b] ?? 0);
      });
    return sorted;
  }

  void addPoints(int pts) { totalPoints += pts; _save(); }

  void addStars(int n) { totalStars += n; _save(); }

  void updateStreak() {
    final today = _today();
    if (lastActiveDate == today) return;
    final y = DateTime.now().toUtc().subtract(const Duration(days: 1)).toIso8601String().split('T').first;
    final ns = lastActiveDate == y ? currentStreak + 1 : 1;
    currentStreak = ns;
    longestStreak = ns > longestStreak ? ns : longestStreak;
    lastActiveDate = today;
    _save();
  }

  void recordDailyPractice() {
    final today = _today();
    todayPracticeCount += 1;
    if (!practicedDates.contains(today)) practicedDates.add(today);
    _save();
  }

  /// A passed level. Every pass counts towards homework, challenges and the
  /// Parent Hub; only a new best level adds stars.
  void completeActivityLevel(String activityId, int level) {
    final cat = categoryOfActivity(activityId);
    _log('n');
    _log('lv');
    _log('c:$cat');
    counters['levels'] = (counters['levels'] ?? 0) + 1;
    final key = categoryCounter[cat];
    if (key != null) counters[key] = (counters[key] ?? 0) + 1;
    final today = _today();
    if (!practicedDates.contains(today)) practicedDates.add(today);
    _homeworkEvent(activityId: activityId, level: level);
    final cur = activityProgress[activityId] ?? 0;
    if (level > cur) {
      activityProgress[activityId] = level;
      totalStars += 3;
    }
    _save();
  }

  void recordLevelAccuracy(String levelId, int accuracy) {
    // The level pass logged just before this gets its score.
    final last = _lastLevelAttempt;
    if (last != null && last.$2 < last.$1.attempts.length && last.$1.attempts[last.$2].accuracy == null) {
      final a = last.$1.attempts[last.$2];
      last.$1.attempts[last.$2] = HomeworkAttempt(at: a.at, accuracy: accuracy, stars: a.stars, seconds: a.seconds,
          counted: a.counted);
    }
    _lastLevelAttempt = null;
    if (accuracy > (levelBestAccuracy[levelId] ?? -1)) levelBestAccuracy[levelId] = accuracy;
    _save();
  }

  /// Adds [v] to today's [key] in [dailyLog].
  void _log(String key, [int v = 1]) {
    final d = dailyLog.putIfAbsent(_today(), () => {});
    d[key] = (d[key] ?? 0) + v;
  }

  /// Time spent in an activity screen (logged when the child leaves it).
  /// Saved without notifying listeners: nothing on screen shows it live, and
  /// a rebuild of every tab while the back animation runs makes it stutter.
  void addPracticeTime(int seconds) {
    if (seconds <= 0) return;
    _log('sec', seconds.clamp(0, 1800));
    _memo.clear();
    final st = student;
    if (st != null) _p?.setString(_studentKey(st.id), json.encode(_record()));
  }

  void togglePinnedBadge(String id) {
    if (pinnedBadges.contains(id)) {
      pinnedBadges = [...pinnedBadges]..remove(id);
    } else {
      pinnedBadges = [...pinnedBadges, id];
      if (pinnedBadges.length > 3) pinnedBadges = pinnedBadges.sublist(pinnedBadges.length - 3);
    }
    _save();
  }

  void markBadgesSeen(Iterable<String> ids) {
    final add = ids.where((i) => !seenBadges.contains(i)).toList();
    if (add.isEmpty) return;
    seenBadges = [...seenBadges, ...add];
    _save();
  }

  void setSoundOn(bool v) { soundOn = v; _save(); }
  void setVoice(String v) { voice = v; _save(); }
  void setLeftHanded(bool v) { leftHanded = v; _save(); }
  void setDifficulty(String v) { difficulty = v; _save(); }
  void setResultStyle(String v) { resultStyle = v; _save(); }
  void setWritingMode(String v) { writingMode = v; _save(); }
  void setBoardStyle(String v) { boardStyle = v; _save(); }
  void setAppLanguage(String v) { appLanguage = v; AppLang.apply(v); _save(); }
  void setAvatar(String v) { avatar = v; _save(); }

  /// Average accuracy (0-100) of one letter, or null if never graded.
  int? letterAccuracy(String id) {
    final c = letterAccCount[id] ?? 0;
    return c == 0 ? null : ((letterAccSum[id] ?? 0) / c).round();
  }

  /// Average accuracy across all graded attempts, or null if none yet.
  int? get averageAccuracy {
    final c = letterAccCount.values.fold<int>(0, (a, b) => a + b);
    if (c == 0) return null;
    return (letterAccSum.values.fold<int>(0, (a, b) => a + b) / c).round();
  }

  /// Days in a row (ending today or yesterday) with at least one practice.
  int get practiceStreakDays {
    final set = practicedDates.toSet();
    var d = DateTime.now().toUtc();
    String key(DateTime x) => x.toIso8601String().split('T').first;
    if (!set.contains(key(d))) d = d.subtract(const Duration(days: 1));
    int n = 0;
    while (set.contains(key(d))) { n++; d = d.subtract(const Duration(days: 1)); }
    return n;
  }

  void setUserName(String n) {
    // A corrected Hindi spelling belongs to the old name.
    if (n != userName) hindiName = '';
    userName = n;
    _save();
  }
  void setPremium(bool v) { _premium = v; _save(); }
  void setThemePref(String v) { themePref = v; _save(); }
  void setThemeId(String v) { themeId = v; AppThemes.apply(v); _save(); }
  void setHindiName(String v) { hindiName = v.trim(); _save(); }
  void toggleNotifyFeature(String id) {
    notifyFeatures.contains(id) ? notifyFeatures.remove(id) : notifyFeatures.add(id);
    _save();
  }
  void setDailyGoal(int v) { dailyGoal = v; _save(); }

  void completeOnboarding(String name, String? age, String? role, {int? goal}) {
    userName = name; ageGroup = age; userRole = role ?? 'student';
    if (goal != null) dailyGoal = goal;
    onboardingComplete = true;
    _save();
  }

  void resetAll() {
    userName = 'Student'; userLevel = 1; totalStars = 0; totalPoints = 0;
    currentStreak = 0; longestStreak = 0; lastActiveDate = null;
    letterProgress = {}; selectedLetterId = null; practicedDates = [];
    todayPracticeCount = 0; activityProgress = {}; onboardingComplete = false;
    letterAccSum = {}; letterAccCount = {}; levelBestAccuracy = {}; wordSkill = {}; wordReps = {}; practiceSeconds = {}; pinnedBadges = []; seenBadges = [];
    counters = {}; dailyLog = {};
    _save();
  }

  int get masteredCount => letterProgress.values.where((p) => p.mastered).length;

  // ── Learners ──────────────────────────────────────────────────────────

  StudentAccount? get student => studentById(activeStudentId);
  /// Learners who use this device (not cloud copies of children elsewhere).
  List<StudentAccount> get learners => students.where((s) => !s.remote).toList();
  StudentAccount? studentById(String id) => students.where((s) => s.id == id).firstOrNull;
  ParentAccount? parentById(String id) => parents.where((p) => p.id == id).firstOrNull;
  Set<String> get _takenIds => {...students.map((s) => s.id), ...parents.map((p) => p.id)};

  /// Adds a learner (already onboarded, so they go straight to Home) and
  /// returns them; [parentId] links them to that parent. The new learner
  /// keeps this device's theme, language and sound settings.
  StudentAccount addStudent(String name, {String? ageGroup, String? parentId}) {
    final st = StudentAccount(id: AccountIds.generate(AccountIds.student, taken: _takenIds), name: name.trim(),
        parentIds: [if (parentId != null) parentId]);
    students = [...students, st];
    _p?.setString(_studentKey(st.id), json.encode({
      'userName': name.trim(), 'ageGroup': ageGroup, 'userRole': 'student', 'onboardingComplete': true,
      'themeId': themeId, 'appLanguage': appLanguage, 'soundOn': soundOn, 'voice': voice,
    }));
    _save();
    return st;
  }

  /// Makes [id] the active learner: their saved progress replaces this one's.
  void switchStudent(String id) {
    if (id == activeStudentId || (studentById(id)?.remote ?? true)) return;
    _save();
    Map<String, dynamic> j = {};
    try { j = json.decode(_p?.getString(_studentKey(id)) ?? '{}') as Map<String, dynamic>; } catch (_) {}
    activeStudentId = id;
    _apply(j);
    AppThemes.apply(themeId);
    AppLang.apply(appLanguage);
    _save();
  }

  /// Deletes a learner and their progress from this device (not the active one).
  void removeStudent(String id) {
    if (id == activeStudentId) return;
    students = students.where((s) => s.id != id).toList();
    homework = homework.where((h) => h.studentId != id).toList();
    challenges = challenges.where((c) => c.studentId != id).toList();
    _p?.remove(_studentKey(id));
    _save();
  }

  /// A learner's saved record as stored (for backing up to the cloud).
  Map<String, dynamic> rawRecordOf(String id) {
    if (id == activeStudentId) return _record();
    try {
      return json.decode(_p?.getString(_studentKey(id)) ?? '{}') as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  /// Replaces a learner's saved record (after merging in the cloud copy).
  void replaceRecord(String id, Map<String, dynamic> record) {
    if (studentById(id) == null) return;
    if (id == activeStudentId) {
      _apply(record);
      _save();
    } else {
      _p?.setString(_studentKey(id), json.encode(record));
      notifyListeners();
    }
  }

  /// Takes in a child's details from their cloud record (`students/{id}`):
  /// updates a learner on this device, or adds a read-only copy of a child
  /// who learns elsewhere. Returns whether anything changed.
  bool upsertCloudStudent(String id, Map<String, dynamic> info, List<String> parentIds,
      {Map<String, dynamic>? devices, Map<String, dynamic>? guardians}) {
    if (guardians != null) _upsertGuardians(guardians);
    if (devices != null) {
      final st = studentById(id);
      if (st != null && json.encode(st.devices) != json.encode(devices)) {
        st.devices = Map<String, dynamic>.from(devices);
        _save();
      }
    }
    final st = studentById(id);
    if (st == null) {
      students = [...students, StudentAccount.fromJson({...info, 'id': id, 'parentIds': parentIds, 'remote': true})];
      _save();
      return true;
    }
    final before = canonicalInfo(st);
    final links = {...st.parentIds, ...parentIds}.toList();
    final merged = StudentAccount.fromJson({...st.toJson(), ...info, 'parentIds': links});
    if (canonicalInfo(merged) == before && links.length == st.parentIds.length) return false;
    students = [for (final s in students) s.id == id ? merged : s];
    // The learner's name also lives in their progress record.
    if (id == activeStudentId && merged.name != userName) {
      hindiName = '';
      userName = merged.name;
    }
    _save();
    return true;
  }

  /// Contact details of parents named in a child's cloud record, kept on
  /// this device without a PIN (they show in Important information).
  void _upsertGuardians(Map<String, dynamic> guardians) {
    var changed = false;
    for (final e in guardians.entries) {
      final g = e.value is Map ? Map<String, dynamic>.from(e.value) : <String, dynamic>{};
      final p = parentById(e.key);
      if (p == null) {
        parents = [...parents, ParentAccount(id: e.key, name: g['name'] ?? 'Parent', relationship: g['relationship'] ?? 'Parent',
            phone: g['phone'] ?? '', email: g['email'] ?? '')];
        changed = true;
      } else if (p.contactOnly && (p.name != g['name'] || p.phone != g['phone'] || p.email != g['email'])) {
        p.name = g['name'] ?? p.name;
        p.relationship = g['relationship'] ?? p.relationship;
        p.phone = g['phone'] ?? '';
        p.email = g['email'] ?? '';
        changed = true;
      }
    }
    if (changed) _save();
  }

  /// Adds the child this device was just paired to, with their cloud record,
  /// and makes them the active learner. A blank learner left from a fresh
  /// install is removed.
  void addPairedStudent(String id, Map<String, dynamic> info, List<String> parentIds, Map<String, dynamic> record,
      {Map<String, dynamic>? guardians}) {
    if (guardians != null) _upsertGuardians(guardians);
    final existing = studentById(id);
    final st = StudentAccount.fromJson({...?existing?.toJson(), ...info, 'id': id, 'parentIds': parentIds,
        'remote': false, 'paired': true});
    students = existing == null ? [...students, st] : [for (final s in students) s.id == id ? st : s];
    _p?.setString(_studentKey(id), json.encode({...record, 'onboardingComplete': true}));
    final blank = student;
    switchStudent(id);
    if (blank != null && blank.id != id && !blank.paired && blank.parentIds.isEmpty) {
      final r = recordOf(blank.id);
      if (!r.onboarded || (r.totalStars == 0 && r.daysPracticed == 0)) removeStudent(blank.id);
    }
    _save();
  }

  /// This device's pairing to [id] was removed by a parent: progress stays
  /// here but no longer syncs.
  void markUnpaired(String id) {
    final st = studentById(id);
    if (st == null || !st.paired) return;
    st.paired = false;
    _save();
  }

  /// A learner's shared details as text, to tell when they changed.
  static String canonicalInfo(StudentAccount s) => json.encode(s.cloudInfo());

  /// Removes the read-only copy of a child who learns on another device.
  void removeCloudCopy(String id) {
    if (!(studentById(id)?.remote ?? false)) return;
    students = students.where((s) => s.id != id).toList();
    _p?.remove(_studentKey(id));
    _save();
  }

  /// A learner's progress figures, read from their saved record.
  StudentRecord recordOf(String id) => memo('record:$id', () {
        if (id == activeStudentId) return StudentRecord.fromJson(_record());
        try {
          return StudentRecord.fromJson(json.decode(_p?.getString(_studentKey(id)) ?? '{}') as Map<String, dynamic>);
        } catch (_) {
          return const StudentRecord();
        }
      });

  /// Figures worked out from the saved data (a child's record, their Parent
  /// Hub insights), kept until the store next changes, so screens that
  /// rebuild often do not parse and count everything again each time.
  final Map<String, Object?> _memo = {};
  T memo<T>(String key, T Function() build) => _memo.containsKey(key) ? _memo[key] as T : (_memo[key] = build());

  @override
  void notifyListeners() {
    _memo.clear();
    super.notifyListeners();
  }

  void updateStudentInfo(String id, {String? dateOfBirth, String? grade, String? school, String? city,
      String? emergencyContact, String? notes}) {
    final st = studentById(id);
    if (st == null) return;
    if (dateOfBirth != null) st.dateOfBirth = dateOfBirth.trim();
    if (grade != null) st.grade = grade.trim();
    if (school != null) st.school = school.trim();
    if (city != null) st.city = city.trim();
    if (emergencyContact != null) st.emergencyContact = emergencyContact.trim();
    if (notes != null) st.notes = notes.trim();
    _save();
  }

  // ── Learner login codes ───────────────────────────────────────────────

  Set<String> get _takenCodes => {for (final x in students) if (x.loginCode.isNotEmpty) x.loginCode};

  /// Every learner gets a code (also learners saved before codes existed).
  void _ensureCodes() {
    for (final x in students) {
      if (x.loginCode.isEmpty) x.loginCode = StudentCodes.generate(taken: _takenCodes);
    }
  }

  /// Checks a learner's code. Like the parent PIN, five wrong codes in a row
  /// lock it for a while.
  PinCheck checkStudentCode(String id, String code, {DateTime? now}) {
    final st = studentById(id);
    if (st == null) return PinCheck.wrong;
    final t = now ?? DateTime.now();
    if (pinLockedUntil(id, now: t) != null) return PinCheck.locked;
    if (StudentCodes.normalize(code) == st.loginCode) {
      if (pinGuard.remove(id) != null) _saveAccounts();
      return PinCheck.ok;
    }
    return _pinFailed(id, t);
  }

  bool isRemembered(String id) => rememberedStudents.contains(id);

  /// Turns "Remember me on this phone" on or off for learner [id].
  void setRemembered(String id, bool on) {
    if (on == isRemembered(id)) return;
    rememberedStudents = on ? [...rememberedStudents, id] : rememberedStudents.where((x) => x != id).toList();
    _saveAccounts();
    notifyListeners();
  }

  /// Notes who is using the app now (shown first on the chooser next time).
  void markLastUser(String id) {
    if (lastUserId == id) return;
    lastUserId = id;
    _saveAccounts();
  }

  /// Whether parent [id] chose to stay unlocked and that time has not ended.
  bool parentStillUnlocked(String id, {DateTime? now}) {
    final until = DateTime.tryParse(parentUnlockedUntil[id] ?? '');
    return until != null && until.isAfter(now ?? DateTime.now());
  }

  /// Keeps parent [id] unlocked on this device for [minutes] (0 locks now).
  void keepParentUnlocked(String id, int minutes) {
    if (minutes <= 0) {
      if (parentUnlockedUntil.remove(id) == null) return;
    } else {
      parentUnlockedUntil[id] = DateTime.now().add(Duration(minutes: minutes)).toUtc().toIso8601String();
    }
    _saveAccounts();
    notifyListeners();
  }

  /// Sets learner [id]'s code. Returns why it cannot be used (`length`,
  /// `chars`, `mix` or `taken`), or null when it was set.
  String? setStudentCode(String id, String raw) {
    final st = studentById(id);
    if (st == null) return 'missing';
    final code = StudentCodes.normalize(raw);
    final problem = StudentCodes.problem(code);
    if (problem != null) return problem;
    if (students.any((x) => x.id != id && x.loginCode == code)) return 'taken';
    st.loginCode = code;
    pinGuard.remove(id);
    rememberedStudents = rememberedStudents.where((x) => x != id).toList();
    _save();
    return null;
  }

  /// Gives learner [id] a new generated code and returns it.
  String newStudentCode(String id) {
    final st = studentById(id)!;
    st.loginCode = StudentCodes.generate(taken: _takenCodes);
    pinGuard.remove(id);
    rememberedStudents = rememberedStudents.where((x) => x != id).toList();
    _save();
    return st.loginCode;
  }

  // ── Parents ───────────────────────────────────────────────────────────

  ParentAccount createParent({required String name, required String pin, String relationship = 'Parent',
      String phone = '', String email = ''}) {
    final pa = ParentAccount(id: AccountIds.generate(AccountIds.parent, taken: _takenIds), name: name.trim(),
        relationship: relationship, phone: phone.trim(), email: email.trim());
    pa.setPin(pin);
    parents = [...parents, pa];
    _save();
    return pa;
  }

  /// Checks a parent's PIN. Five wrong PINs in a row lock it for 30
  /// seconds, and each further wrong PIN doubles the wait (up to 15 minutes).
  PinCheck checkParentPin(String id, String pin, {DateTime? now}) {
    final p = parentById(id);
    if (p == null || p.contactOnly) return PinCheck.wrong;
    final t = now ?? DateTime.now();
    if (pinLockedUntil(id, now: t) != null) return PinCheck.locked;
    if (p.checkPin(pin)) {
      if (pinGuard.remove(id) != null) _saveAccounts();
      return PinCheck.ok;
    }
    return _pinFailed(id, t);
  }

  /// Counts a wrong PIN or code for [id] and locks it after too many.
  PinCheck _pinFailed(String id, DateTime t) {
    final fails = pinFailures(id) + 1;
    final g = <String, dynamic>{'fails': fails};
    if (fails >= pinFreeTries) {
      final secs = (30 * (1 << (fails - pinFreeTries).clamp(0, 5))).clamp(30, 900);
      g['until'] = t.add(Duration(seconds: secs)).toUtc().toIso8601String();
    }
    pinGuard[id] = g;
    _saveAccounts();
    notifyListeners();
    return g['until'] != null ? PinCheck.locked : PinCheck.wrong;
  }

  /// Why [raw] cannot be [parentId]'s new PIN: too easy ([weakParentPin]),
  /// or `taken` because a child's login code or another parent's PIN is the
  /// same. Null when it can be used.
  String? parentPinProblem(String raw, {String? parentId}) {
    final weak = weakParentPin(raw);
    if (weak != null) return weak;
    final code = StudentCodes.normalize(raw);
    if (students.any((x) => x.loginCode == code)) return 'taken';
    if (parents.any((p) => p.id != parentId && p.checkPin(code))) return 'taken';
    return null;
  }

  /// Wrong PINs allowed before the PIN locks.
  static const pinFreeTries = 5;
  int pinFailures(String id) => (pinGuard[id]?['fails'] as int?) ?? 0;
  DateTime? pinLockedUntil(String id, {DateTime? now}) {
    final until = DateTime.tryParse(pinGuard[id]?['until'] as String? ?? '');
    return until != null && until.isAfter(now ?? DateTime.now()) ? until : null;
  }

  void updateParent(String id, {String? name, String? relationship, String? phone, String? email, String? pin}) {
    final pa = parentById(id);
    if (pa == null) return;
    if (name != null && name.trim().isNotEmpty) pa.name = name.trim();
    if (relationship != null) pa.relationship = relationship;
    if (phone != null) pa.phone = phone.trim();
    if (email != null) pa.email = email.trim();
    if (pin != null) {
      pa.setPin(pin);
      pinGuard.remove(id);
      parentUnlockedUntil.remove(id);
    }
    _save();
  }

  /// Adds a parent who already has a cloud account (signing in on a new
  /// device): they keep their Parent ID and set a PIN for this device.
  ParentAccount restoreParent({required String id, required String uid, required String name, required String pin,
      String relationship = 'Parent', String phone = '', String email = ''}) {
    final pa = parentById(id) ?? ParentAccount(id: id, name: name, relationship: relationship, phone: phone, email: email);
    pa.setPin(pin);
    pa.cloudUid = uid;
    if (parentById(id) == null) parents = [...parents, pa];
    _save();
    return pa;
  }

  /// Records that [parentId] signed in as cloud user [uid] ('' = signed out).
  void setParentCloud(String parentId, String uid) {
    final pa = parentById(parentId);
    if (pa == null) return;
    pa.cloudUid = uid;
    if (uid.isEmpty) pa.lastBackupAt = null;
    _save();
  }

  void markBackedUp(String parentId) {
    parentById(parentId)?.lastBackupAt = DateTime.now().toUtc().toIso8601String();
    _save();
  }

  /// Gives a parent a new ID everywhere (their cloud account already has
  /// one, or the ID is taken in the cloud). Returns the parent.
  ParentAccount? renameParentId(String oldId, String newId) {
    final old = parentById(oldId);
    if (old == null || oldId == newId) return old;
    final pa = ParentAccount.fromJson({...old.toJson(), 'id': newId});
    parents = [for (final p in parents) p.id == oldId ? pa : p];
    for (final st in students) {
      st.parentIds = [for (final p in st.parentIds) p == oldId ? newId : p];
    }
    homework = [for (final h in homework) h.assignedBy == oldId ? Homework.fromJson({...h.toJson(), 'assignedBy': newId}) : h];
    _save();
    return pa;
  }

  /// Gives a learner a new ID everywhere (theirs is already taken in the cloud).
  void renameStudentId(String oldId, String newId) {
    final old = studentById(oldId);
    if (old == null || oldId == newId) return;
    final raw = rawRecordOf(oldId);
    students = [for (final s in students) s.id == oldId ? StudentAccount.fromJson({...s.toJson(), 'id': newId}) : s];
    homework = [for (final h in homework) h.studentId == oldId ? Homework.fromJson({...h.toJson(), 'studentId': newId}) : h];
    challenges = [for (final c in challenges) c.studentId == oldId ? Challenge.fromJson({...c.toJson(), 'studentId': newId}) : c];
    if (activeStudentId == oldId) activeStudentId = newId;
    _p?.setString(_studentKey(newId), json.encode(raw));
    _p?.remove(_studentKey(oldId));
    _save();
  }

  /// IDs in use on this device (a new ID must avoid them).
  Set<String> get takenIds => _takenIds;

  List<ParentAccount> parentsOf(String studentId) =>
      (studentById(studentId)?.parentIds ?? const <String>[]).map(parentById).whereType<ParentAccount>().toList();
  List<StudentAccount> childrenOf(String parentId) => students.where((s) => s.parentIds.contains(parentId)).toList();

  void linkParent(String studentId, String parentId) {
    final st = studentById(studentId);
    if (st == null || parentById(parentId) == null || st.parentIds.contains(parentId)) return;
    st.parentIds = [...st.parentIds, parentId];
    _save();
  }

  void unlinkParent(String studentId, String parentId) {
    final st = studentById(studentId);
    if (st == null) return;
    st.parentIds = st.parentIds.where((p) => p != parentId).toList();
    _save();
  }

  // ── Homework ──────────────────────────────────────────────────────────

  /// Homework for [studentId]: open first (soonest due), then done (newest).
  List<Homework> homeworkFor(String studentId) {
    final list = homework.where((h) => h.studentId == studentId).toList();
    list.sort((a, b) {
      if (a.done != b.done) return a.done ? 1 : -1;
      if (a.done) return b.completedAt!.compareTo(a.completedAt!);
      return (a.dueDate ?? '9999').compareTo(b.dueDate ?? '9999');
    });
    return list;
  }

  void assignHomework(Homework h) {
    homework = [...homework, h];
    _save();
  }

  void removeHomework(String id) {
    homework = homework.where((h) => h.id != id).toList();
    _save();
  }

  Homework? homeworkById(String id) => homework.where((h) => h.id == id).firstOrNull;

  /// Changes a homework's settings; lowering the goal to what is done finishes it.
  void updateHomework(String id, {String? title, String? note, String? dueDate, bool clearDue = false, int? goal,
      String? difficulty}) {
    final h = homeworkById(id);
    if (h == null) return;
    if (title != null) h.title = title;
    if (note != null) h.note = note.trim();
    if (clearDue) {
      h.dueDate = null;
    } else if (dueDate != null) {
      h.dueDate = dueDate;
    }
    if (goal != null) h.goal = goal.clamp(1, 99);
    if (difficulty != null) h.difficulty = difficulty;
    if (!h.done && h.progress >= h.goal) h.completedAt = DateTime.now().toUtc().toIso8601String();
    _save();
  }

  /// Moves a homework's due date [days] later (from today when it is overdue).
  void extendHomework(String id, int days) {
    final h = homeworkById(id);
    if (h == null) return;
    final now = DateTime.now();
    final base = h.dueDate == null ? now : DateTime.tryParse(h.dueDate!) ?? now;
    final from = base.isBefore(DateTime(now.year, now.month, now.day)) ? now : base;
    h.dueDate = from.add(Duration(days: days)).toIso8601String().split('T').first;
    _save();
  }

  /// A fresh copy of homework [id] (no attempts) for [studentId], due in [dueDays].
  Homework? reassignHomework(String id, {required String studentId, required String parentId, int? dueDays}) {
    final h = homeworkById(id);
    if (h == null) return null;
    final copy = Homework.fromJson({
      ...h.toJson(), 'id': newRecordId('hw'), 'studentId': studentId, 'assignedBy': parentId,
      'createdAt': DateTime.now().toUtc().toIso8601String(), 'progress': 0, 'completedAt': null,
      'attempts': const [], 'feedback': const [],
      'dueDate': dueDays == null ? h.dueDate : DateTime.now().add(Duration(days: dueDays)).toIso8601String().split('T').first,
    });
    assignHomework(copy);
    return copy;
  }

  /// A parent's message on a homework; its bonus stars go to the child.
  void addHomeworkFeedback(String id, ParentNote note) {
    final h = homeworkById(id);
    if (h == null) return;
    h.feedback = [...h.feedback, note];
    if (note.stars > 0) awardStars(h.studentId, note.stars);
    _save();
  }

  /// When the active learner opened each homework (to time their attempts).
  final Map<String, DateTime> _homeworkOpened = {};
  void beginHomework(String id) => _homeworkOpened[id] = DateTime.now();
  /// The level homework attempt just logged, so [recordLevelAccuracy] can score it.
  (Homework, int)? _lastLevelAttempt;

  /// Logs an attempt on every open homework of the active learner that this
  /// event belongs to: a [graded] write (of [letterId] for [stars]) or a
  /// pass of [level] of [activityId]. Finishing a homework is worth 20 points.
  void _homeworkEvent({bool graded = false, String? letterId, int stars = 0, int? accuracy, int seconds = 0,
      String? activityId, int? level, List<List<double>> strokes = const []}) {
    final now = DateTime.now();
    for (final h in homework) {
      if (h.studentId != activeStudentId || h.done) continue;
      final (relevant, counted) = switch (h.kind) {
        HomeworkKind.level => (activityId == h.target && level != null && level >= h.level, true),
        HomeworkKind.letter => (letterId != null && letterId == h.target, stars >= 2),
        HomeworkKind.practice => (graded, true),
      };
      if (!relevant) continue;
      final opened = _homeworkOpened[h.id];
      final secs = seconds > 0 ? seconds : opened == null ? 0 : now.difference(opened).inSeconds.clamp(5, 900);
      _homeworkOpened[h.id] = now;
      var list = [...h.attempts, HomeworkAttempt(at: now.toUtc().toIso8601String(), accuracy: accuracy, stars: stars,
          seconds: secs, counted: counted, strokes: h.kind == HomeworkKind.letter ? strokes : const [])];
      // Keep the last 30 attempts, with drawings for the last 8.
      if (list.length > 30) list = list.sublist(list.length - 30);
      for (int i = 0; i < list.length - 8; i++) {
        final a = list[i];
        if (a.strokes.isNotEmpty) {
          list[i] = HomeworkAttempt(at: a.at, accuracy: a.accuracy, stars: a.stars, seconds: a.seconds, counted: a.counted);
        }
      }
      h.attempts = list;
      if (h.kind == HomeworkKind.level) _lastLevelAttempt = (h, list.length - 1);
      if (counted) h.progress++;
      if (h.progress >= h.goal) {
        h.completedAt = now.toUtc().toIso8601String();
        totalPoints += 20;
      }
    }
  }

  // ── Stars, snapshots and profiles ─────────────────────────────────────

  /// Gives [n] stars to a learner (a parent's bonus or a challenge reward).
  void awardStars(String studentId, int n) {
    if (n <= 0) return;
    if (studentId == activeStudentId) {
      totalStars += n;
      _save();
      return;
    }
    final raw = rawRecordOf(studentId);
    raw['totalStars'] = (raw['totalStars'] as int? ?? 0) + n;
    _p?.setString(_studentKey(studentId), json.encode(raw));
    notifyListeners();
  }

  /// A read-only store holding one learner's saved progress, so every
  /// figure and getter works for any child without switching to them.
  /// Never call a method that changes it.
  AppStore viewOf(String id) {
    if (id == activeStudentId) return this;
    return memo('view:$id', () => AppStore()
      .._apply(rawRecordOf(id))
      ..activeStudentId = id);
  }

  /// Renames a learner or changes their avatar, age group or class.
  void updateStudentProfile(String id, {String? name, String? avatar, String? ageGroup, String? grade}) {
    final st = studentById(id);
    if (st == null) return;
    if (grade != null) st.grade = grade.trim();
    if (id == activeStudentId) {
      if (name != null && name.trim().isNotEmpty) setUserName(name.trim());
      if (avatar != null) this.avatar = avatar;
      if (ageGroup != null) this.ageGroup = ageGroup;
      _save();
      return;
    }
    final raw = rawRecordOf(id);
    if (name != null && name.trim().isNotEmpty) {
      st.name = name.trim();
      raw['userName'] = name.trim();
      raw['hindiName'] = '';
    }
    if (avatar != null) { st.avatar = avatar; raw['avatar'] = avatar; }
    if (ageGroup != null) raw['ageGroup'] = ageGroup;
    _p?.setString(_studentKey(id), json.encode(raw));
    _save();
  }

  // ── Challenges ────────────────────────────────────────────────────────

  /// A learner's current figure for a challenge [metric].
  static int metricValue(AppStore v, String metric) => switch (metric) {
        'days' => v.practicedDates.length,
        'stars' => v.totalStars,
        _ => v.counters[metric] ?? 0,
      };

  List<Challenge> challengesFor(String studentId) {
    final list = challenges.where((c) => c.studentId == studentId).toList();
    list.sort((a, b) {
      if (a.done != b.done) return a.done ? 1 : -1;
      return b.createdAt.compareTo(a.createdAt);
    });
    return list;
  }

  /// Sets a challenge, counting from the child's figures now.
  void addChallenge(Challenge c) {
    c.baseline = metricValue(viewOf(c.studentId), c.metric);
    c.progress = 0;
    challenges = [...challenges, c];
    _save();
  }

  void removeChallenge(String id) {
    challenges = challenges.where((c) => c.id != id).toList();
    _save();
  }

  /// Updates the active learner's open challenges; a finished one pays its stars.
  void _checkChallenges() {
    for (final c in challenges) {
      if (c.studentId != activeStudentId || c.done || c.expired) continue;
      c.progress = (metricValue(this, c.metric) - c.baseline).clamp(0, c.target);
      if (c.progress >= c.target) {
        c.completedAt = DateTime.now().toUtc().toIso8601String();
        if (c.reward == 'stars') totalStars += c.rewardStars;
      }
    }
  }
}

/// A unique id for a homework or challenge, e.g. `hw-lq3k2-9f1a`.
String newRecordId(String prefix) =>
    '$prefix-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-${(DateTime.now().hashCode & 0xfffff).toRadixString(36)}';
