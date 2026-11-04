import 'package:flutter/material.dart';
import '../store/app_store.dart';
import 'accounts.dart';
import 'models.dart';

/// Parent Hub data: activity categories, skill bands and every figure the
/// hub shows for one child, worked out from that child's own saved record
/// (an [AppStore.viewOf] snapshot), so children never mix.

class HubCategory {
  final String id, label, hindi, emoji, blurb;
  final IconData icon;
  final Color color;
  const HubCategory(this.id, this.label, this.hindi, this.emoji, this.blurb, this.icon, this.color);
}

const hubCategories = [
  HubCategory('writing', 'Writing', 'लिखना', '✍️', 'Letters, words and drills', Icons.edit_rounded, Color(0xFFFF7043)),
  HubCategory('reading', 'Reading', 'पढ़ना', '📖', 'Words, stories and sentences', Icons.menu_book_rounded, Color(0xFF4EC58A)),
  HubCategory('matras', 'Matras', 'मात्रा', '🔤', 'Vowel signs on letters', Icons.text_fields_rounded, Color(0xFF6E4EDF)),
  HubCategory('listening', 'Listening', 'सुनना', '🎧', 'Hear it, pick or write it', Icons.headphones_rounded, Color(0xFF4FB2E6)),
  HubCategory('quiz', 'Quiz', 'खेल', '🧩', 'Matching and quick games', Icons.extension_rounded, Color(0xFFF26E97)),
  HubCategory('speaking', 'Speaking', 'बोलना', '🎤', 'Say it out loud', Icons.mic_rounded, Color(0xFFEE9A4C)),
];

HubCategory hubCategory(String id) => hubCategories.firstWhere((c) => c.id == id, orElse: () => hubCategories.first);

const _activityCategory = {
  'word-writing': 'writing', 'speed-challenge': 'writing', 'letter-comparison': 'writing', 'random-drill': 'writing',
  'conjunct-practice': 'writing',
  'matra-practice': 'matras', 'matra-quiz': 'matras',
  'dictation': 'listening', 'letter-sound': 'listening', 'rhyming': 'listening',
  'letter-quiz': 'quiz', 'letter-pairs': 'quiz', 'odd-one-out': 'quiz', 'picture-match': 'quiz', 'fill-blank': 'quiz',
  'numbers': 'quiz',
  'pronunciation': 'speaking',
};

/// The Parent Hub category of an activity (reading when not listed).
String categoryOfActivity(String activityId) => _activityCategory[activityId] ?? 'reading';

/// Counter (in [AppStore.counters]) a category's level passes add to.
const categoryCounter = {
  'reading': 'reads', 'matras': 'matras', 'listening': 'listens', 'quiz': 'quizzes', 'speaking': 'speaks',
};

List<ActivityDef> activitiesIn(String category) => [...AppData.writingActivities, ...AppData.readingActivities]
    .where((a) => categoryOfActivity(a.id) == category).toList();

ActivityDef? hubActivity(String id) =>
    [...AppData.writingActivities, ...AppData.readingActivities].where((a) => a.id == id).firstOrNull;

/// How well a skill is going.
enum SkillBand { excellent, good, needsPractice, notStarted }

SkillBand bandOf(int? accuracy) => accuracy == null ? SkillBand.notStarted
    : accuracy >= 85 ? SkillBand.excellent : accuracy >= 65 ? SkillBand.good : SkillBand.needsPractice;

extension SkillBandUi on SkillBand {
  String get label => const ['Excellent', 'Good', 'Needs practice', 'Not started'][index];
  String get hindi => const ['बहुत बढ़िया', 'अच्छा', 'अभ्यास चाहिए', 'शुरू नहीं'][index];
  Color get color => const [Color(0xFF2E9163), Color(0xFF4FB2E6), Color(0xFFE8452F), Color(0xFFA89A82)][index];
  IconData get icon => const [Icons.workspace_premium_rounded, Icons.thumb_up_alt_rounded,
      Icons.priority_high_rounded, Icons.radio_button_unchecked_rounded][index];
}

/// Challenge kinds a parent can set, with the figure each one counts.
class ChallengeKind {
  final String id, label, emoji, metric, unit;
  final List<int> targets;
  const ChallengeKind(this.id, this.label, this.emoji, this.metric, this.unit, this.targets);
}

const challengeKinds = [
  ChallengeKind('writing', 'Writing', '✍️', 'writes', 'graded writes', [10, 25, 50, 100]),
  ChallengeKind('reading', 'Reading', '📖', 'reads', 'reading levels passed', [3, 5, 10, 20]),
  ChallengeKind('speaking', 'Speaking', '🎤', 'speaks', 'speaking rounds passed', [3, 5, 10]),
  ChallengeKind('daily', 'Daily practice', '📅', 'days', 'days of practice', [3, 5, 7, 14, 30]),
];

ChallengeKind challengeKind(String id) => challengeKinds.firstWhere((k) => k.id == id, orElse: () => challengeKinds.last);

/// One day of a child's practice.
class DayStat {
  final DateTime date;
  final int practices, seconds, levels;
  final int? accuracy;
  const DayStat(this.date, this.practices, this.seconds, this.levels, this.accuracy);
  bool get active => practices > 0 || seconds > 0;
}

/// Totals over a stretch of days.
class PeriodStat {
  final int practices, seconds, levels, activeDays, days, lettersMastered, homeworkDone;
  final int? accuracy;
  final Map<String, int> byCategory;
  const PeriodStat({this.practices = 0, this.seconds = 0, this.levels = 0, this.activeDays = 0, this.days = 1,
      this.lettersMastered = 0, this.homeworkDone = 0, this.accuracy, this.byCategory = const {}});
  double get consistency => days == 0 ? 0 : activeDays / days;
}

/// A weak spot found in the record, with the activity that helps.
class WeakArea {
  final String title, reason, category;
  final String? letterId, activityId;
  const WeakArea(this.title, this.reason, this.category, {this.letterId, this.activityId});
}

String dayKey(DateTime d) => d.toUtc().toIso8601String().split('T').first;

/// Everything the Parent Hub shows about one child.
class ChildInsights {
  final StudentAccount student;
  final AppStore v;
  final List<Homework> homework;
  final List<Challenge> challenges;
  ChildInsights._(this.student, this.v, this.homework, this.challenges);

  /// One child's insights, worked out once per store change and shared by
  /// every widget that shows them; the figures below are computed on first use.
  factory ChildInsights.of(AppStore s, String studentId) => s.memo('insights:$studentId', () => ChildInsights._(
      s.studentById(studentId)!, s.viewOf(studentId), s.homeworkFor(studentId), s.challengesFor(studentId)));

  final Map<String, Object?> _cache = {};
  /// Computes [build] once for these insights (for figures worked out elsewhere).
  T once<T>(String key, T Function() build) => _once(key, build);
  T _once<T>(String key, T Function() build) => _cache.containsKey(key) ? _cache[key] as T : (_cache[key] = build());

  int get totalLetters => AppData.allLetters.length;
  int get mastered => v.masteredCount;
  int get stars => v.totalStars;
  int get streak => v.practiceStreakDays;
  int? get writingAccuracy => v.averageAccuracy;
  int? letterAccuracy(String id) => v.letterAccuracy(id);
  SkillBand letterBand(String id) {
    final acc = v.letterAccuracy(id);
    if (acc == null && v.letterProgress[id]?.mastered == true) return SkillBand.excellent;
    return bandOf(acc);
  }

  bool get started => v.practicedDates.isNotEmpty || v.totalStars > 0;
  String? get lastActive => v.practicedDates.isEmpty ? v.lastActiveDate : (v.practicedDates.toList()..sort()).last;
  bool get activeToday => v.practicedDates.contains(dayKey(DateTime.now()));

  /// Share of a category's levels passed (0-100), or null if it has none.
  int? categoryProgress(String category) => _once('cat:$category', () {
    final acts = activitiesIn(category);
    final total = acts.fold<int>(0, (a, b) => a + b.levels.length);
    if (total == 0) return null;
    final done = acts.fold<int>(0, (a, b) => a + (v.activityProgress[b.id] ?? 0).clamp(0, b.levels.length));
    return (done * 100 / total).round();
  });

  /// Reading performance: how far through the reading activities, 0-100.
  int get readingScore => categoryProgress('reading') ?? 0;
  int get readingLevels => activitiesIn('reading').fold(0, (a, b) => a + (v.activityProgress[b.id] ?? 0));

  /// Overall progress: letters mastered and levels passed across all activities.
  late final int overallProgress = _overallProgress();
  int _overallProgress() {
    final acts = [...AppData.writingActivities, ...AppData.readingActivities];
    final total = acts.fold<int>(0, (a, b) => a + b.levels.length);
    final done = acts.fold<int>(0, (a, b) => a + (v.activityProgress[b.id] ?? 0).clamp(0, b.levels.length));
    final letters = totalLetters == 0 ? 0.0 : mastered / totalLetters;
    final levels = total == 0 ? 0.0 : done / total;
    return ((letters * 0.5 + levels * 0.5) * 100).round();
  }

  /// Word recognition: average skill over written words, and how many.
  (int?, int) get wordSkill {
    final w = v.wordSkill.values.toList();
    return (w.isEmpty ? null : (w.fold<int>(0, (a, b) => a + b) / w.length).round(), w.length);
  }

  /// Per matra: best accuracy over matra-practice levels that use it (null
  /// when none was played) and whether a matra quiz with it was passed.
  late final Map<String, (int?, bool)> matraPerformance = _matraPerformance();
  Map<String, (int?, bool)> _matraPerformance() {
    final practice = hubActivity('matra-practice')?.levels ?? const <LevelDef>[];
    final quiz = hubActivity('matra-quiz')?.levels ?? const <LevelDef>[];
    final quizDone = v.activityProgress['matra-quiz'] ?? 0;
    // A level's matras: a list of keys, or 'all'.
    bool uses(LevelDef l, String key) {
      final m = l.params['matras'];
      return m == 'all' || (m is List && m.contains(key));
    }
    final out = <String, (int?, bool)>{};
    for (final m in AppData.matras) {
      final key = m.id.replaceAll('-matra', '');
      final accs = [
        for (final l in practice)
          if (uses(l, key) && v.levelBestAccuracy[l.id] != null)
            v.levelBestAccuracy[l.id]!,
      ];
      final passed = quiz.any((l) => l.level <= quizDone && uses(l, key));
      out[m.id] = (accs.isEmpty ? null : (accs.fold<int>(0, (a, b) => a + b) / accs.length).round(), passed);
    }
    return out;
  }

  SkillBand matraBand((int?, bool) p) => p.$1 != null ? bandOf(p.$1) : p.$2 ? SkillBand.good : SkillBand.notStarted;

  /// Letters written with 85%+ on average, best first.
  late final List<String> strongLetters = _strongLetters();
  List<String> _strongLetters() {
    final l = [for (final x in AppData.allLetters) if ((v.letterAccuracy(x.id) ?? 0) >= 85) x.id];
    l.sort((a, b) => v.letterAccuracy(b)!.compareTo(v.letterAccuracy(a)!));
    return l;
  }

  /// Letters below 65% on average, weakest first.
  late final List<String> weakLetters = _weakLetters();
  List<String> _weakLetters() {
    final l = [for (final x in AppData.allLetters) if (v.letterAccuracy(x.id) != null && v.letterAccuracy(x.id)! < 65) x.id];
    l.sort((a, b) => v.letterAccuracy(a)!.compareTo(v.letterAccuracy(b)!));
    return l;
  }

  /// Weak areas, most important first, each with an activity to fix it.
  late final List<WeakArea> weakAreas = _weakAreas();
  List<WeakArea> _weakAreas() {
    final out = <WeakArea>[];
    for (final id in weakLetters.take(3)) {
      final ch = AppData.letterById(id)?.character ?? id;
      out.add(WeakArea('Writing $ch', 'Average accuracy ${v.letterAccuracy(id)}%', 'writing', letterId: id));
    }
    final matras = matraPerformance.entries.where((e) => e.value.$1 != null && e.value.$1! < 65).toList();
    if (matras.isNotEmpty) {
      final m = AppData.matras.firstWhere((x) => x.id == matras.first.key);
      out.add(WeakArea('Matra ${m.symbol}', 'Best score ${matras.first.value.$1}%', 'matras', activityId: 'matra-practice'));
    }
    final (ws, wn) = wordSkill;
    if (ws != null && ws < 65 && wn >= 3) {
      out.add(WeakArea('Word writing', 'Words average $ws%', 'writing', activityId: 'word-writing'));
    }
    if (started && readingLevels == 0) {
      out.add(const WeakArea('Reading', 'No reading levels passed yet', 'reading', activityId: 'word-reading'));
    }
    final week = period(7);
    if (started && week.activeDays <= 2) {
      out.add(WeakArea('Regular practice', 'Practised ${week.activeDays} of the last 7 days', 'writing',
          activityId: 'random-drill'));
    }
    if ((v.counters['speaks'] ?? 0) == 0 && started) {
      out.add(const WeakArea('Speaking', 'Has not tried speaking yet', 'speaking', activityId: 'pronunciation'));
    }
    return out;
  }

  DayStat day(DateTime d) {
    final k = dayKey(d);
    final log = v.dailyLog[k] ?? const <String, int>{};
    final practiced = v.practicedDates.contains(k);
    final n = log['n'] ?? (practiced ? 1 : 0);
    final sec = log['sec'] ?? v.practiceSeconds[k] ?? 0;
    final wn = log['wn'] ?? 0;
    return DayStat(DateTime.utc(d.year, d.month, d.day), n, sec, log['lv'] ?? 0,
        wn == 0 ? null : ((log['ws'] ?? 0) / wn).round());
  }

  /// The last [n] days, oldest first.
  List<DayStat> lastDays(int n, {int offset = 0}) => _once('days:$n:$offset', () {
        final now = DateTime.now();
        return [for (int i = n - 1 + offset; i >= offset; i--) day(now.subtract(Duration(days: i)))];
      });

  /// Totals over the [days] days ending [offset] days ago ([days] = 0: all time).
  PeriodStat period(int days, {int offset = 0}) => _once('period:$days:$offset', () => _period(days, offset));
  PeriodStat _period(int days, int offset) {
    final now = DateTime.now();
    Iterable<String> keys;
    int span;
    if (days == 0) {
      keys = {...v.dailyLog.keys, ...v.practicedDates};
      final first = keys.isEmpty ? null : (keys.toList()..sort()).first;
      span = first == null ? 1 : now.difference(DateTime.parse(first)).inDays + 1;
    } else {
      keys = [for (int i = offset; i < offset + days; i++) dayKey(now.subtract(Duration(days: i)))];
      span = days;
    }
    final set = keys.toSet();
    int n = 0, sec = 0, lv = 0, ws = 0, wn = 0, active = 0;
    final cats = <String, int>{};
    for (final k in set) {
      final log = v.dailyLog[k] ?? const <String, int>{};
      final practiced = v.practicedDates.contains(k);
      n += log['n'] ?? (practiced ? 1 : 0);
      sec += log['sec'] ?? v.practiceSeconds[k] ?? 0;
      lv += log['lv'] ?? 0;
      ws += log['ws'] ?? 0;
      wn += log['wn'] ?? 0;
      if (practiced || (log['n'] ?? 0) > 0) active++;
      for (final e in log.entries) {
        if (e.key.startsWith('c:')) cats[e.key.substring(2)] = (cats[e.key.substring(2)] ?? 0) + e.value;
      }
    }
    bool inSet(String? iso) => iso != null && set.contains(iso.split('T').first);
    return PeriodStat(
      practices: n, seconds: sec, levels: lv, activeDays: active, days: span,
      accuracy: wn == 0 ? null : (ws / wn).round(), byCategory: cats,
      lettersMastered: days == 0 ? mastered : v.letterProgress.values.where((p) => p.mastered && inSet(p.lastPracticedAt)).length,
      homeworkDone: homework.where((h) => h.done && (days == 0 || inSet(h.completedAt))).length,
    );
  }
}

/// "12 min" / "1 h 5 min" from seconds.
String formatDuration(int seconds) {
  final m = (seconds / 60).round();
  if (m < 60) return '$m min';
  return '${m ~/ 60} h ${m % 60} min';
}

/// "+12%" / "−3%" / "same": change from [before] to [now].
String changeLabel(num now, num before, {bool percent = false}) {
  final d = now - before;
  if (d == 0) return 'same';
  final v = percent ? '${d.abs().round()} pts' : '${d.abs().round()}';
  return d > 0 ? '+$v' : '−$v';
}
