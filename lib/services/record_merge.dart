import 'dart:convert';
import 'dart:math';

/// Saved-record keys that belong to the device, not the learner's progress:
/// they are never taken from another device.
const deviceOnlyKeys = {
  'themePref', 'themeId', 'soundOn', 'voice', 'leftHanded', 'difficulty', 'resultStyle', 'writingMode', 'boardStyle',
  'appLanguage', 'notifyFeatures', 'selectedLetterId', 'pinnedBadges',
};

/// Combines one learner's saved record from two devices ([local] wins on
/// device settings and profile) without losing practice from either: best
/// letter results, highest levels, every practised day, the larger counts.
/// Merging is order-free and repeatable (merging a result again changes
/// nothing), so devices that keep merging each other's records agree.
Map<String, dynamic> mergeRecords(Map<String, dynamic> local, Map<String, dynamic> remote) {
  final out = <String, dynamic>{...remote, ...local};
  int i(dynamic v) => (v as num?)?.toInt() ?? 0;
  int maxOf(String k) => max(i(local[k]), i(remote[k]));
  Map<String, dynamic> m(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
  String? later(String? a, String? b) => a == null ? b : b == null ? a : (a.compareTo(b) >= 0 ? a : b);

  for (final k in ['totalStars', 'totalPoints', 'currentStreak', 'longestStreak', 'userLevel', 'todayPracticeCount']) {
    if (local.containsKey(k) || remote.containsKey(k)) out[k] = maxOf(k);
  }
  out['lastActiveDate'] = later(local['lastActiveDate'] as String?, remote['lastActiveDate'] as String?);
  out['onboardingComplete'] = local['onboardingComplete'] == true || remote['onboardingComplete'] == true;

  Map<String, int> maxMap(String k) {
    final a = m(local[k]), b = m(remote[k]);
    return {for (final key in {...a.keys, ...b.keys}) key: max(i(a[key]), i(b[key]))};
  }
  for (final k in ['activityProgress', 'levelBestAccuracy', 'practiceSeconds', 'wordReps', 'counters']) {
    if (local.containsKey(k) || remote.containsKey(k)) out[k] = maxMap(k);
  }
  // Parent Hub day log: per day, the larger of each figure.
  if (local.containsKey('dailyLog') || remote.containsKey('dailyLog')) {
    final a = m(local['dailyLog']), b = m(remote['dailyLog']);
    out['dailyLog'] = {
      for (final day in {...a.keys, ...b.keys})
        day: {for (final k in {...m(a[day]).keys, ...m(b[day]).keys}) k: max(i(m(a[day])[k]), i(m(b[day])[k]))},
    };
  }

  List<String> union(String k) => ({...List<String>.from(local[k] ?? const []), ...List<String>.from(remote[k] ?? const [])}.toList()..sort());
  out['practicedDates'] = union('practicedDates');
  out['seenBadges'] = union('seenBadges');

  // Accuracy is a sum and a count per letter: take the side with more graded
  // writes (adding them would count shared history twice).
  final sumA = m(local['letterAccSum']), cntA = m(local['letterAccCount']);
  final sumB = m(remote['letterAccSum']), cntB = m(remote['letterAccCount']);
  final sum = <String, int>{}, cnt = <String, int>{};
  for (final k in {...cntA.keys, ...cntB.keys}) {
    final useA = i(cntA[k]) > i(cntB[k]) || (i(cntA[k]) == i(cntB[k]) && i(sumA[k]) >= i(sumB[k]));
    sum[k] = useA ? i(sumA[k]) : i(sumB[k]);
    cnt[k] = useA ? i(cntA[k]) : i(cntB[k]);
  }
  out['letterAccSum'] = sum;
  out['letterAccCount'] = cnt;

  // Word skill: from the side that practised the word more.
  final skA = m(local['wordSkill']), skB = m(remote['wordSkill']);
  final repA = m(local['wordReps']), repB = m(remote['wordReps']);
  out['wordSkill'] = {
    for (final w in {...skA.keys, ...skB.keys})
      w: !skB.containsKey(w) ? i(skA[w]) : !skA.containsKey(w) ? i(skB[w])
          : i(repA[w]) > i(repB[w]) ? i(skA[w]) : i(repB[w]) > i(repA[w]) ? i(skB[w]) : max(i(skA[w]), i(skB[w])),
  };

  // Letters: the further-along result, keeping the best stars and the latest practice.
  final lpA = m(local['letterProgress']), lpB = m(remote['letterProgress']);
  out['letterProgress'] = {
    for (final id in {...lpA.keys, ...lpB.keys}) id: _mergeLetter(m(lpA[id]), m(lpB[id])),
  };

  for (final k in deviceOnlyKeys) {
    if (local.containsKey(k)) {
      out[k] = local[k];
    } else {
      out.remove(k);
    }
  }
  return out;
}

Map<String, dynamic> _mergeLetter(Map<String, dynamic> a, Map<String, dynamic> b) {
  if (a.isEmpty) return b;
  if (b.isEmpty) return a;
  int i(dynamic v) => (v as num?)?.toInt() ?? 0;
  // Rank: mastered, then stage, then successes in the stage, then attempts.
  List<int> rank(Map<String, dynamic> p) =>
      [p['mastered'] == true ? 1 : 0, i(p['currentStage']), i(p['successfulAttempts']), i(p['attemptsInCurrentStage'])];
  int cmp(List<int> x, List<int> y) {
    for (int k = 0; k < x.length; k++) { if (x[k] != y[k]) return x[k].compareTo(y[k]); }
    return 0;
  }
  final ra = rank(a), rb = rank(b);
  final ahead = cmp(ra, rb) > 0 || (cmp(ra, rb) == 0 && (a['lastPracticedAt'] ?? '').compareTo(b['lastPracticedAt'] ?? '') >= 0) ? a : b;
  final la = a['lastPracticedAt'] as String?, lb = b['lastPracticedAt'] as String?;
  return {
    ...ahead,
    'bestStars': max(i(a['bestStars']), i(b['bestStars'])),
    'starsEarned': max(i(a['starsEarned']), i(b['starsEarned'])),
    'mastered': a['mastered'] == true || b['mastered'] == true,
    'lastPracticedAt': la == null ? lb : lb == null ? la : (la.compareTo(lb) >= 0 ? la : lb),
  };
}

/// JSON with map keys sorted, so two equal records compare equal as text.
String canonicalJson(Object? v) => json.encode(_sorted(v));

Object? _sorted(Object? v) {
  if (v is Map) {
    final keys = v.keys.map((k) => '$k').toList()..sort();
    return {for (final k in keys) k: _sorted(v[k])};
  }
  if (v is List) return v.map(_sorted).toList();
  return v;
}
