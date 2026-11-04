import 'package:flutter_test/flutter_test.dart';
import 'package:hindi_mitra/data/models.dart';
import 'package:hindi_mitra/store/app_store.dart';

LevelDef _level(String id, List<String> ids, int required) =>
    LevelDef.fromJson({'id': id, 'level': 1, 'name': id, 'hindiName': id, 'emoji': '', 'description': '',
      'letterIds': ids, 'requiredStars': required});

void main() {
  test('opening a letter adds no stars', () {
    final p = {'v01': LetterProgress(letterId: 'v01'), 'v02': LetterProgress(letterId: 'v02')};
    final s = AppData.levelStars(['v01', 'v02'], p);
    expect(s.earned, 0);
    expect(s.completed, isFalse);
  });

  test('a level counts each letter\'s best stars, capped at 3', () {
    final p = {
      'v01': LetterProgress(letterId: 'v01', bestStars: 2),
      'v02': LetterProgress(letterId: 'v02', bestStars: 3),
    };
    final s = AppData.levelStars(['v01', 'v02'], p);
    expect(s.earned, 5);
    expect(s.total, 6);
    expect(s.completed, isTrue);
  });

  test('a level is completed only when every letter has a 2-star write', () {
    final p = {
      'v01': LetterProgress(letterId: 'v01', bestStars: 3),
      'v02': LetterProgress(letterId: 'v02', bestStars: 1),
    };
    expect(AppData.levelStars(['v01', 'v02'], p).completed, isFalse);
  });

  test('a failed attempt adds no stars; a better one raises the best', () {
    final store = AppStore();
    store.letterProgress['v01'] = LetterProgress(letterId: 'v01');
    store.recordAttempt('v01', 0, accuracy: 16);
    expect(store.letterProgress['v01']!.bestStars, 0);
    store.recordAttempt('v01', 2, accuracy: 75);
    store.recordAttempt('v01', 1, accuracy: 55);
    expect(store.letterProgress['v01']!.bestStars, 2);
  });

  test('saved progress from before best stars is converted sensibly', () {
    LetterProgress f(Map<String, dynamic> j) => LetterProgress.fromJson({'letterId': 'v01', ...j});
    expect(f({'currentStage': 1, 'starsEarned': 0}).bestStars, 0);
    expect(f({'currentStage': 1, 'starsEarned': 1}).bestStars, 1);
    expect(f({'currentStage': 2, 'starsEarned': 7}).bestStars, 2);
    expect(f({'currentStage': 4, 'mastered': true}).bestStars, 3);
    expect(f({'bestStars': 1, 'currentStage': 3}).bestStars, 1);
  });

  test('stars unlock the next level; a finished level stays open', () {
    final l1 = _level('a', ['v01', 'v02'], 0), l2 = _level('b', ['v03'], 4);
    final opened = {'v01': LetterProgress(letterId: 'v01'), 'v02': LetterProgress(letterId: 'v02')};
    final earned = {
      'v01': LetterProgress(letterId: 'v01', bestStars: 2),
      'v02': LetterProgress(letterId: 'v02', bestStars: 2),
    };
    expect(AppData.sectionStars([l1, l2], opened), 0);
    expect(AppData.sectionStars([l1, l2], earned), 4);
    // Locking only applies while the build doesn't unlock everything.
    if (!unlockAll) expect(AppData.isLevelUnlocked(l2, [l1, l2], opened), isFalse);
    expect(AppData.isLevelUnlocked(l2, [l1, l2], earned), isTrue);
    expect(AppData.isLevelUnlocked(l2, [l1, l2], opened, played: {'b': 80}), isTrue);
  });
}
