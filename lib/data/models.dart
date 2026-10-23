import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;

class HindiLetter {
  final String id, character, romanized, pronunciation, exampleWord, exampleMeaning, group;
  final int strokeCount, order;
  final bool isFree;
  HindiLetter.fromJson(Map<String, dynamic> j)
      : id = j['id'], character = j['character'], romanized = j['romanized'],
        pronunciation = j['pronunciation'], exampleWord = j['exampleWord'],
        exampleMeaning = j['exampleMeaning'], group = j['group'],
        strokeCount = j['strokeCount'], order = j['order'], isFree = j['isFree'];
  bool get isVowel => group == 'vowel';
}

class Matra {
  final String id, symbol, vowelBase, romanized, name, pronunciation;
  Matra.fromJson(Map<String, dynamic> j)
      : id = j['id'], symbol = j['symbol'], vowelBase = j['vowelBase'],
        romanized = j['romanized'], name = j['name'], pronunciation = j['pronunciation'];
}

class MatraCombination {
  final String id, consonant, matra, combined, romanized;
  MatraCombination(this.id, this.consonant, this.matra, this.combined, this.romanized);
}

class LevelDef {
  final String id, name, hindiName, emoji, description;
  final int level, requiredStars;
  final Map<String, dynamic> params;
  final List<String> letterIds;
  final String? bonusType;
  final int? timeLimit;
  LevelDef.fromJson(Map<String, dynamic> j)
      : id = j['id'], name = j['name'], hindiName = j['hindiName'],
        emoji = j['emoji'], description = j['description'],
        level = j['level'], requiredStars = j['requiredStars'],
        params = Map<String, dynamic>.from(j['params'] ?? {}),
        letterIds = List<String>.from(j['letterIds'] ?? const []),
        bonusType = j['bonusType'], timeLimit = j['timeLimit'];
}

class ActivityDef {
  final String id, title, hindiTitle, icon, color, screen;
  final String? iconEmoji;
  final bool isPremium;
  final List<LevelDef> levels;
  ActivityDef.fromJson(Map<String, dynamic> j)
      : id = j['id'], title = j['title'], hindiTitle = j['hindiTitle'],
        icon = j['icon'] ?? '', iconEmoji = j['iconEmoji'], color = j['color'] ?? '#EE9A4C',
        screen = j['screen'], isPremium = j['isPremium'] ?? false,
        levels = (j['levels'] as List).map((e) => LevelDef.fromJson(e)).toList();
}

class Pt {
  final double x, y;
  const Pt(this.x, this.y);
}

class StrokeTemplate {
  final String letterId, character;
  final List<List<Pt>> strokes;
  StrokeTemplate.fromJson(Map<String, dynamic> j)
      : letterId = j['letterId'], character = j['character'],
        strokes = (j['strokes'] as List)
            .map((s) => (s as List).map((p) => Pt((p['x'] as num).toDouble(), (p['y'] as num).toDouble())).toList())
            .toList();
}

/// Loads and exposes all bundled JSON data (converted 1:1 from the TS sources).
class AppData {
  static late List<HindiLetter> vowels, consonants, allLetters;
  static late List<Matra> matras;
  static late Map<String, List<Map<String, String>>> matraExamples;
  static late List<ActivityDef> writingActivities, readingActivities;
  static late List<LevelDef> vowelLevels, consonantLevels;
  static late Map<String, StrokeTemplate> strokeTemplates;
  static late Set<String> audioIds;
  static Map<String, String> audioTextToId = {};
  static final Random rng = Random();

  static Future<dynamic> _j(String n) async =>
      json.decode(await rootBundle.loadString('assets/data/$n.json'));

  static Future<void> load() async {
    final l = await _j('letters');
    vowels = (l['vowels'] as List).map((e) => HindiLetter.fromJson(e)).toList();
    consonants = (l['consonants'] as List).map((e) => HindiLetter.fromJson(e)).toList();
    allLetters = [...vowels, ...consonants];
    final m = await _j('matras');
    matras = (m['matras'] as List).map((e) => Matra.fromJson(e)).toList();
    matraExamples = (m['examples'] as Map).map((k, v) => MapEntry(
        k as String, (v as List).map((e) => Map<String, String>.from(e)).toList()));
    writingActivities = (await _j('activities') as List).map((e) => ActivityDef.fromJson(e)).toList();
    readingActivities = (await _j('reading_activities') as List).map((e) => ActivityDef.fromJson(e)).toList();
    final w = await _j('writing_levels');
    vowelLevels = (w['vowels'] as List).map((e) => LevelDef.fromJson(e)).toList();
    consonantLevels = (w['consonants'] as List).map((e) => LevelDef.fromJson(e)).toList();
    final st = await _j('stroke_templates') as Map;
    strokeTemplates = st.map((k, v) => MapEntry(k as String, StrokeTemplate.fromJson(v)));
    final ac = await _j('audio_catalog') as List;
    audioIds = ac.map((e) => e['id'] as String).toSet();
    audioTextToId = {for (final e in ac) (e['text'] as String): (e['id'] as String)};
  }

  static HindiLetter? letterById(String id) {
    for (final l in allLetters) { if (l.id == id) return l; }
    return null;
  }

  static HindiLetter? nextLetter(String id) {
    final i = allLetters.indexWhere((l) => l.id == id);
    if (i < 0 || i >= allLetters.length - 1) return null;
    return allLetters[i + 1];
  }

  static const _baseCons = ['क', 'ग', 'च', 'त', 'प', 'म', 'र', 'ल', 'स', 'न'];
  static const _baseRom = ['k', 'g', 'ch', 't', 'p', 'm', 'r', 'l', 's', 'n'];

  static List<MatraCombination> combinationsFor(String matraId) {
    final m = matras.where((x) => x.id == matraId);
    if (m.isEmpty) return [];
    final matra = m.first;
    return [
      for (int i = 0; i < _baseCons.length; i++)
        MatraCombination('$matraId-${_baseRom[i]}', _baseCons[i], matra.symbol,
            _baseCons[i] + matra.symbol, _baseRom[i] + matra.romanized)
    ];
  }

  // ── Letter pools for practice levels (the `pool` param in activities.json) ──
  static const _pools = <String, List<String>>{
    'vowels_basic': ['v01', 'v02', 'v03', 'v04', 'v05', 'v06'],
    'consonants_easy': ['c01', 'c03', 'c08', 'c16', 'c20', 'c21', 'c23', 'c25', 'c27', 'c28', 'c32', 'c33'],
    'consonants_hard': ['c04', 'c05', 'c07', 'c09', 'c10', 'c12', 'c14', 'c15', 'c17', 'c19', 'c24', 'c31', 'c34', 'c35', 'c36'],
    'ka_group': ['c01', 'c02', 'c03', 'c04', 'c05'],
    'confusing_pairs': ['c23', 'c21', 'c25', 'c24', 'c19', 'c04', 'c02', 'c27', 'c13', 'c18', 'c11', 'c16'],
  };

  /// Letter ids for a level's pool name; unknown / missing pools mean all letters.
  static List<String> poolIds(String? pool) {
    switch (pool) {
      case 'vowels': return [for (final l in vowels) l.id];
      case 'mixed':
      case 'mixed_easy': return [..._pools['vowels_basic']!, ..._pools['consonants_easy']!];
      default: return _pools[pool] ?? [for (final l in allLetters) l.id];
    }
  }

  /// [count] items drawn from [pool] like dealing cards: every item appears
  /// once before any repeats, and the same item never shows up twice in a row.
  static List<T> deck<T>(List<T> pool, int count) {
    if (pool.isEmpty) return [];
    final out = <T>[];
    while (out.length < count) {
      final round = [...pool]..shuffle(rng);
      if (out.isNotEmpty && round.length > 1 && round.first == out.last) {
        round.add(round.removeAt(0));
      }
      out.addAll(round);
    }
    return out.sublist(0, count);
  }

  // ── Level helpers (ports of writingLevels.ts / activityLevels.ts) ──
  static ({int earned, int total, bool completed}) levelStars(
      List<String> ids, Map<String, dynamic> progress) {
    int earned = 0; bool all = true;
    for (final id in ids) {
      final p = progress[id];
      if (p != null) {
        final st = (p.currentStage as int);
        earned += min(st, 3);
        if (st < 1) all = false;
      } else { all = false; }
    }
    return (earned: earned, total: ids.length * 3, completed: all && ids.isNotEmpty);
  }

  static int sectionStars(List<LevelDef> levels, Map<String, dynamic> progress) {
    int t = 0;
    for (final l in levels) { t += levelStars(l.letterIds, progress).earned; }
    return t;
  }

  static bool isLevelUnlocked(LevelDef lvl, List<LevelDef> all, Map<String, dynamic> progress) {
    if (lvl.requiredStars == 0) return true;
    return sectionStars(all, progress) >= lvl.requiredStars;
  }

  static ({bool unlocked, bool completed, int stars}) activityLevelState(
      String activityId, int levelIndex, Map<String, int> completed) {
    final h = completed[activityId] ?? 0;
    final unlocked = levelIndex == 0 || h >= levelIndex;
    final done = h > levelIndex;
    final stars = done ? 3 : (h == levelIndex ? 2 : 0);
    return (unlocked: unlocked, completed: done, stars: stars);
  }
}
