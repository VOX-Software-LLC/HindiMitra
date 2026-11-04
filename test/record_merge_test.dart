import 'package:flutter_test/flutter_test.dart';
import 'package:hindi_mitra/services/record_merge.dart';

Map<String, dynamic> _letter(int stage, int best, {bool mastered = false, int ok = 0, String at = '2026-10-01'}) => {
      'letterId': 'x', 'currentStage': stage, 'bestStars': best, 'starsEarned': best * 3, 'mastered': mastered,
      'successfulAttempts': ok, 'attemptsInCurrentStage': ok, 'lastPracticedAt': at,
    };

void main() {
  // The same learner practised on a tablet and on a phone.
  final tablet = <String, dynamic>{
    'userName': 'Aarav', 'totalStars': 40, 'totalPoints': 300, 'currentStreak': 2, 'longestStreak': 5,
    'lastActiveDate': '2026-10-29', 'onboardingComplete': true, 'themeId': 'sunny', 'soundOn': true,
    'practicedDates': ['2026-10-27', '2026-10-29'], 'activityProgress': {'matra-practice': 3, 'dictation': 1},
    'letterProgress': {'ka': _letter(3, 2, ok: 1, at: '2026-10-29'), 'a': _letter(4, 3, mastered: true)},
    'letterAccSum': {'ka': 300}, 'letterAccCount': {'ka': 4},
    'wordSkill': {'घर': 70}, 'wordReps': {'घर': 2}, 'practiceSeconds': {'2026-10-29': 120},
    'seenBadges': ['first'],
  };
  final phone = <String, dynamic>{
    'userName': 'Aarav S', 'totalStars': 55, 'totalPoints': 250, 'currentStreak': 3, 'longestStreak': 3,
    'lastActiveDate': '2026-10-30', 'onboardingComplete': true, 'themeId': 'night', 'soundOn': false,
    'practicedDates': ['2026-10-28', '2026-10-30'], 'activityProgress': {'matra-practice': 2, 'word-writing': 4},
    'letterProgress': {'ka': _letter(2, 3, ok: 2, at: '2026-10-30'), 'kha': _letter(1, 1)},
    'letterAccSum': {'ka': 150, 'kha': 40}, 'letterAccCount': {'ka': 2, 'kha': 1},
    'wordSkill': {'घर': 90, 'कमल': 60}, 'wordReps': {'घर': 5, 'कमल': 1}, 'practiceSeconds': {'2026-10-30': 60},
    'seenBadges': ['streak3'],
  };

  test('no practice from either device is lost', () {
    final m = mergeRecords(tablet, phone);
    expect(m['totalStars'], 55);
    expect(m['totalPoints'], 300);
    expect(m['longestStreak'], 5);
    expect(m['lastActiveDate'], '2026-10-30');
    expect(m['practicedDates'], ['2026-10-27', '2026-10-28', '2026-10-29', '2026-10-30']);
    expect(m['activityProgress'], {'matra-practice': 3, 'dictation': 1, 'word-writing': 4});
    expect(m['practiceSeconds'], {'2026-10-29': 120, '2026-10-30': 60});
    expect(m['seenBadges'], ['first', 'streak3']);
    // Letters: the further-along stage, the best stars from either side.
    final ka = m['letterProgress']['ka'];
    expect(ka['currentStage'], 3);
    expect(ka['bestStars'], 3);
    expect(ka['lastPracticedAt'], '2026-10-30');
    expect(m['letterProgress']['a']['mastered'], isTrue);
    expect(m['letterProgress'].keys, containsAll(['ka', 'a', 'kha']));
    // Accuracy from the side with more graded writes; word skill from the side that practised more.
    expect(m['letterAccCount'], {'ka': 4, 'kha': 1});
    expect(m['letterAccSum'], {'ka': 300, 'kha': 40});
    expect(m['wordSkill'], {'घर': 90, 'कमल': 60});
  });

  test('device settings and the profile stay as they are on this device', () {
    final m = mergeRecords(tablet, phone);
    expect(m['themeId'], 'sunny');
    expect(m['soundOn'], isTrue);
    expect(m['userName'], 'Aarav');
    final other = mergeRecords(phone, tablet);
    expect(other['themeId'], 'night');
  });

  test('merging is order-free and repeatable, so devices agree', () {
    String progressOf(Map<String, dynamic> r) =>
        canonicalJson({...r}..removeWhere((k, _) => deviceOnlyKeys.contains(k) || k == 'userName'));
    final ab = mergeRecords(tablet, phone), ba = mergeRecords(phone, tablet);
    expect(progressOf(ab), progressOf(ba));
    expect(canonicalJson(mergeRecords(ab, ab)), canonicalJson(ab));
    expect(canonicalJson(mergeRecords(ab, phone)), canonicalJson(ab));
    expect(canonicalJson(mergeRecords(ab, tablet)), canonicalJson(ab));
  });

  test('merging with an empty record keeps everything', () {
    expect(canonicalJson(mergeRecords(tablet, {})), canonicalJson(mergeRecords(tablet, tablet)));
    expect(mergeRecords({}, phone)['totalStars'], 55);
  });

  test('canonical JSON ignores key order', () {
    expect(canonicalJson({'b': 1, 'a': {'d': 2, 'c': 3}}), canonicalJson({'a': {'c': 3, 'd': 2}, 'b': 1}));
  });

  test('parent hub counters and day log keep the larger figures from both devices', () {
    final a = {'counters': {'writes': 10, 'reads': 2}, 'dailyLog': {'2026-10-01': {'n': 3, 'sec': 60}}};
    final b = {'counters': {'writes': 7, 'speaks': 4}, 'dailyLog': {'2026-10-01': {'n': 5}, '2026-10-02': {'n': 1}}};
    final m = mergeRecords(a, b);
    expect(m['counters'], {'writes': 10, 'reads': 2, 'speaks': 4});
    expect(m['dailyLog'], {'2026-10-01': {'n': 5, 'sec': 60}, '2026-10-02': {'n': 1}});
    expect(mergeRecords(m, b)['dailyLog'], m['dailyLog']);
  });
}
