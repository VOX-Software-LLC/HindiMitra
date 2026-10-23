import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LetterProgress {
  String letterId;
  int currentStage, starsEarned, attemptsInCurrentStage, successfulAttempts;
  bool mastered;
  String? lastPracticedAt;
  LetterProgress({
    required this.letterId, this.currentStage = 1, this.starsEarned = 0,
    this.attemptsInCurrentStage = 0, this.successfulAttempts = 0,
    this.mastered = false, this.lastPracticedAt,
  });
  Map<String, dynamic> toJson() => {
        'letterId': letterId, 'currentStage': currentStage, 'starsEarned': starsEarned,
        'attemptsInCurrentStage': attemptsInCurrentStage,
        'successfulAttempts': successfulAttempts, 'mastered': mastered,
        'lastPracticedAt': lastPracticedAt,
      };
  factory LetterProgress.fromJson(Map<String, dynamic> j) => LetterProgress(
        letterId: j['letterId'], currentStage: j['currentStage'] ?? 1,
        starsEarned: j['starsEarned'] ?? 0,
        attemptsInCurrentStage: j['attemptsInCurrentStage'] ?? 0,
        successfulAttempts: j['successfulAttempts'] ?? 0,
        mastered: j['mastered'] ?? false, lastPracticedAt: j['lastPracticedAt'],
      );
}

String _today() => DateTime.now().toUtc().toIso8601String().split('T').first;

/// Port of the Zustand `useAppStore` (persisted under key `hindi-mitra-store`).
class AppStore extends ChangeNotifier {
  static const _key = 'hindi-mitra-store';
  /// Key used before the HindiMitra rename; read once so saved progress carries over.
  static const _legacyKey = 'hindi-sikho-store';
  String userName = 'Student';
  int userLevel = 1, totalStars = 0, totalPoints = 0, currentStreak = 0, longestStreak = 0;
  String? lastActiveDate;
  Map<String, LetterProgress> letterProgress = {};
  bool isPremium = false, onboardingComplete = false;
  String? selectedLetterId, ageGroup, userRole;
  List<String> practicedDates = [];
  int dailyGoal = 3, todayPracticeCount = 0;
  Map<String, int> activityProgress = {};
  String themePref = 'system'; // system | light | dark
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
  String difficulty = 'normal'; // easy | normal | hard
  String appLanguage = 'en'; // en | hi
  String avatar = '';
  /// Per-word writing skill (0-100, moving average of graded attempts) and how
  /// many practice repetitions of each word have been completed in total.
  Map<String, int> wordSkill = {}, wordReps = {};

  SharedPreferences? _p;

  static Future<AppStore> load() async {
    final s = AppStore();
    s._p = await SharedPreferences.getInstance();
    final raw = s._p!.getString(_key) ?? s._p!.getString(_legacyKey);
    if (raw != null) {
      try {
        final j = json.decode(raw) as Map<String, dynamic>;
        s.userName = j['userName'] ?? 'Student';
        s.userLevel = j['userLevel'] ?? 1;
        s.totalStars = j['totalStars'] ?? 0;
        s.totalPoints = j['totalPoints'] ?? 0;
        s.currentStreak = j['currentStreak'] ?? 0;
        s.longestStreak = j['longestStreak'] ?? 0;
        s.lastActiveDate = j['lastActiveDate'];
        s.letterProgress = ((j['letterProgress'] ?? {}) as Map).map(
            (k, v) => MapEntry(k as String, LetterProgress.fromJson(Map<String, dynamic>.from(v))));
        s.isPremium = j['isPremium'] ?? false;
        s.selectedLetterId = j['selectedLetterId'];
        s.onboardingComplete = j['onboardingComplete'] ?? false;
        s.ageGroup = j['ageGroup'];
        s.userRole = j['userRole'];
        s.practicedDates = List<String>.from(j['practicedDates'] ?? []);
        s.dailyGoal = j['dailyGoal'] ?? 3;
        s.todayPracticeCount = j['todayPracticeCount'] ?? 0;
        s.activityProgress = Map<String, int>.from(j['activityProgress'] ?? {});
        s.themePref = j['themePref'] ?? 'system';
        s.letterAccSum = Map<String, int>.from(j['letterAccSum'] ?? {});
        s.letterAccCount = Map<String, int>.from(j['letterAccCount'] ?? {});
        s.levelBestAccuracy = Map<String, int>.from(j['levelBestAccuracy'] ?? {});
        s.practiceSeconds = Map<String, int>.from(j['practiceSeconds'] ?? {});
        s.pinnedBadges = List<String>.from(j['pinnedBadges'] ?? []);
        s.seenBadges = List<String>.from(j['seenBadges'] ?? []);
        s.soundOn = j['soundOn'] ?? true;
        s.leftHanded = j['leftHanded'] ?? false;
        s.difficulty = j['difficulty'] ?? 'normal';
        s.appLanguage = j['appLanguage'] ?? 'en';
        s.avatar = j['avatar'] ?? '';
        s.wordSkill = Map<String, int>.from(j['wordSkill'] ?? {});
        s.wordReps = Map<String, int>.from(j['wordReps'] ?? {});
      } catch (_) {}
    }
    return s;
  }

  void _save() {
    notifyListeners();
    _p?.setString(_key, json.encode({
      'userName': userName, 'userLevel': userLevel, 'totalStars': totalStars,
      'totalPoints': totalPoints, 'currentStreak': currentStreak,
      'longestStreak': longestStreak, 'lastActiveDate': lastActiveDate,
      'letterProgress': letterProgress.map((k, v) => MapEntry(k, v.toJson())),
      'isPremium': isPremium, 'selectedLetterId': selectedLetterId,
      'onboardingComplete': onboardingComplete, 'ageGroup': ageGroup,
      'userRole': userRole, 'practicedDates': practicedDates, 'dailyGoal': dailyGoal,
      'todayPracticeCount': todayPracticeCount, 'activityProgress': activityProgress,
      'themePref': themePref,
      'letterAccSum': letterAccSum, 'letterAccCount': letterAccCount,
      'levelBestAccuracy': levelBestAccuracy, 'practiceSeconds': practiceSeconds,
      'pinnedBadges': pinnedBadges, 'seenBadges': seenBadges, 'soundOn': soundOn, 'leftHanded': leftHanded,
      'difficulty': difficulty, 'appLanguage': appLanguage, 'avatar': avatar,
      'wordSkill': wordSkill, 'wordReps': wordReps,
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
  void recordAttempt(String letterId, int stars, {int? accuracy, int practicedSeconds = 0}) {
    final p = letterProgress[letterId];
    if (p == null) return;
    if (accuracy != null) {
      letterAccSum[letterId] = (letterAccSum[letterId] ?? 0) + accuracy.clamp(0, 100);
      letterAccCount[letterId] = (letterAccCount[letterId] ?? 0) + 1;
    }
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
    p.attemptsInCurrentStage = attempts;
    p.successfulAttempts = newSuccessful;
    p.mastered = mastered;
    p.lastPracticedAt = DateTime.now().toUtc().toIso8601String();
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

  void completeActivityLevel(String activityId, int level) {
    final cur = activityProgress[activityId] ?? 0;
    if (level <= cur) return;
    activityProgress[activityId] = level;
    totalStars += 3;
    _save();
  }

  void recordLevelAccuracy(String levelId, int accuracy) {
    if (accuracy <= (levelBestAccuracy[levelId] ?? -1)) return;
    levelBestAccuracy[levelId] = accuracy;
    _save();
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
  void setLeftHanded(bool v) { leftHanded = v; _save(); }
  void setDifficulty(String v) { difficulty = v; _save(); }
  void setAppLanguage(String v) { appLanguage = v; _save(); }
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

  void setUserName(String n) { userName = n; _save(); }
  void setPremium(bool v) { isPremium = v; _save(); }
  void setThemePref(String v) { themePref = v; _save(); }
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
    _save();
  }

  int get masteredCount => letterProgress.values.where((p) => p.mastered).length;
}
