import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/feedback.dart';
import '../../services/speech_service.dart';
import '../../store/app_store.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../../widgets/common.dart';
import '../../widgets/progress_bar.dart';
import '../../widgets/quiz_common.dart';

class _Word {
  final String hindi, meaning;
  const _Word(this.hindi, this.meaning);
}

class _Group {
  final String id, name; final List<_Word> words;
  /// Groups in the same family are "near" (fruit vs vegetable) — used for the
  /// harder levels; easy levels always pick the odd word from a far group.
  final String family;
  const _Group(this.id, this.name, this.family, this.words);
}

const _categories = <_Group>[
  _Group('animals', 'animals', 'living', [
    _Word('शेर', 'lion'), _Word('बाघ', 'tiger'), _Word('हाथी', 'elephant'), _Word('भालू', 'bear'), _Word('बंदर', 'monkey'),
    _Word('हिरण', 'deer'), _Word('ऊँट', 'camel'), _Word('घोड़ा', 'horse'), _Word('गाय', 'cow'), _Word('बकरी', 'goat'),
  ]),
  _Group('birds', 'birds', 'living', [
    _Word('तोता', 'parrot'), _Word('मोर', 'peacock'), _Word('कबूतर', 'pigeon'), _Word('कौआ', 'crow'),
    _Word('चिड़िया', 'sparrow'), _Word('बतख', 'duck'), _Word('मैना', 'myna'), _Word('उल्लू', 'owl'),
  ]),
  _Group('fruits', 'fruits', 'food', [
    _Word('आम', 'mango'), _Word('केला', 'banana'), _Word('सेब', 'apple'), _Word('अंगूर', 'grapes'),
    _Word('संतरा', 'orange'), _Word('अनार', 'pomegranate'), _Word('पपीता', 'papaya'), _Word('अमरूद', 'guava'),
  ]),
  _Group('vegetables', 'vegetables', 'food', [
    _Word('आलू', 'potato'), _Word('गाजर', 'carrot'), _Word('गोभी', 'cauliflower'), _Word('मटर', 'peas'),
    _Word('टमाटर', 'tomato'), _Word('प्याज़', 'onion'), _Word('भिंडी', 'okra'), _Word('बैंगन', 'brinjal'),
  ]),
  _Group('colors', 'colours', 'describing', [
    _Word('लाल', 'red'), _Word('पीला', 'yellow'), _Word('नीला', 'blue'), _Word('हरा', 'green'),
    _Word('काला', 'black'), _Word('सफ़ेद', 'white'), _Word('गुलाबी', 'pink'), _Word('भूरा', 'brown'),
  ]),
  _Group('numbers', 'numbers', 'describing', [
    _Word('एक', 'one'), _Word('दो', 'two'), _Word('तीन', 'three'), _Word('चार', 'four'),
    _Word('पाँच', 'five'), _Word('छह', 'six'), _Word('सात', 'seven'), _Word('आठ', 'eight'),
  ]),
  _Group('family', 'family members', 'people', [
    _Word('माता', 'mother'), _Word('पिता', 'father'), _Word('भाई', 'brother'), _Word('बहन', 'sister'),
    _Word('दादा', 'grandfather'), _Word('दादी', 'grandmother'), _Word('चाचा', 'uncle'), _Word('नाना', "mother's father"),
  ]),
  _Group('body', 'body parts', 'people', [
    _Word('हाथ', 'hand'), _Word('पैर', 'foot'), _Word('आँख', 'eye'), _Word('नाक', 'nose'),
    _Word('कान', 'ear'), _Word('मुँह', 'mouth'), _Word('सिर', 'head'), _Word('दाँत', 'tooth'),
  ]),
  _Group('vehicles', 'vehicles', 'things', [
    _Word('बस', 'bus'), _Word('कार', 'car'), _Word('रेल', 'train'), _Word('साइकिल', 'bicycle'),
    _Word('नाव', 'boat'), _Word('जहाज़', 'ship'), _Word('ट्रक', 'truck'), _Word('स्कूटर', 'scooter'),
  ]),
  _Group('home', 'things at home', 'things', [
    _Word('कुर्सी', 'chair'), _Word('मेज़', 'table'), _Word('पलंग', 'bed'), _Word('दरवाज़ा', 'door'),
    _Word('खिड़की', 'window'), _Word('अलमारी', 'cupboard'), _Word('पंखा', 'fan'), _Word('घड़ी', 'clock'),
  ]),
];

/// Sound mode: words grouped by their first letter.
const _bySound = <_Group>[
  _Group('क', 'क', 'sound', [_Word('कमल', 'lotus'), _Word('कलम', 'pen'), _Word('कबूतर', 'pigeon'), _Word('केला', 'banana'), _Word('कान', 'ear'), _Word('कार', 'car')]),
  _Group('म', 'म', 'sound', [_Word('मोर', 'peacock'), _Word('मटर', 'peas'), _Word('मेज़', 'table'), _Word('माता', 'mother'), _Word('मछली', 'fish'), _Word('मुँह', 'mouth')]),
  _Group('ब', 'ब', 'sound', [_Word('बस', 'bus'), _Word('बतख', 'duck'), _Word('बंदर', 'monkey'), _Word('बकरी', 'goat'), _Word('बहन', 'sister'), _Word('बाघ', 'tiger')]),
  _Group('स', 'स', 'sound', [_Word('सेब', 'apple'), _Word('सात', 'seven'), _Word('साइकिल', 'bicycle'), _Word('सिर', 'head'), _Word('संतरा', 'orange'), _Word('सफ़ेद', 'white')]),
  _Group('प', 'प', 'sound', [_Word('पपीता', 'papaya'), _Word('पैर', 'foot'), _Word('पिता', 'father'), _Word('पलंग', 'bed'), _Word('पंखा', 'fan'), _Word('पीला', 'yellow')]),
  _Group('ग', 'ग', 'sound', [_Word('गाय', 'cow'), _Word('गाजर', 'carrot'), _Word('गोभी', 'cauliflower'), _Word('गुलाबी', 'pink'), _Word('गमला', 'flowerpot')]),
];

class _Q {
  final List<_Word> words; final int odd; final String category, explanation;
  const _Q(this.words, this.odd, this.category, this.explanation);
}

/// Builds a session of rounds: [groupSize]-1 words from one group plus one odd
/// word from another. No word is used twice in a session and the same group
/// never leads two rounds in a row.
List<_Q> _buildRounds(Map<String, dynamic> params, Random rng) {
  final count = (params['count'] as int?) ?? 10;
  final size = ((params['groupSize'] as int?) ?? 4).clamp(3, 5);
  final difficulty = params['difficulty'] as String? ?? 'easy';
  final sound = params['mode'] == 'phonetic';
  final near = difficulty == 'medium' || difficulty == 'hard' || difficulty == 'expert';
  final groups = sound ? _bySound : _categories;
  final used = <String>{};
  final out = <_Q>[];
  String? lastMain;
  // Groups that have led a round: each leads once before any leads again.
  final ledGroups = <String>{};

  List<_Word> fresh(_Group g) => g.words.where((w) => !used.contains(w.hindi)).toList()..shuffle(rng);

  for (int tries = 0; out.length < count && tries < count * 20; tries++) {
    var mains = groups.where((g) => g.id != lastMain && fresh(g).length >= size - 1).toList();
    if (mains.isEmpty) { used.clear(); continue; }
    final unled = mains.where((g) => !ledGroups.contains(g.id)).toList();
    if (unled.isEmpty) { ledGroups.clear(); } else { mains = unled; }
    final main = mains[rng.nextInt(mains.length)];
    var odds = groups.where((g) => g.id != main.id && fresh(g).isNotEmpty).toList();
    if (!sound) {
      final preferred = odds.where((g) => near ? g.family == main.family : g.family != main.family).toList();
      if (preferred.isNotEmpty) odds = preferred;
    }
    if (odds.isEmpty) { used.clear(); continue; }
    final oddGroup = odds[rng.nextInt(odds.length)];
    // In sound mode the odd word must not secretly start with the main letter.
    final oddPool = fresh(oddGroup).where((w) => !sound || !w.hindi.startsWith(main.id)).toList();
    if (oddPool.isEmpty) continue;
    final same = fresh(main).take(size - 1).toList();
    final odd = oddPool.first;
    final words = [...same, odd]..shuffle(rng);
    used.addAll(words.map((w) => w.hindi));
    lastMain = main.id;
    ledGroups.add(main.id);
    out.add(_Q(
      words, words.indexOf(odd),
      sound ? 'Same first sound' : 'Which one is different?',
      sound
          ? '${odd.hindi} starts with ${odd.hindi.characters.first}. The others all start with ${main.id}.'
          : '${odd.hindi} (${odd.meaning}) is one of the ${oddGroup.name}. The others are all ${main.name}: '
              '${same.map((w) => '${w.hindi} (${w.meaning})').join(', ')}.',
    ));
  }
  return out;
}

/// OddOneOutScreen.tsx
class OddOneOutScreen extends StatefulWidget {
  final Map<String, dynamic> params;
  const OddOneOutScreen({super.key, this.params = const {}});
  @override
  State<OddOneOutScreen> createState() => _OddOneOutScreenState();
}

class _OddOneOutScreenState extends State<OddOneOutScreen> {
  late List<_Q> rounds = _buildRounds(widget.params, Random());
  int round = 0, score = 0, streak = 0;
  int? selected;
  bool? isCorrect;
  bool complete = false, confetti = false;

  _Q get q => rounds[round];
  int get _total => rounds.length;

  void _select(int i) {
    if (selected != null) return;
    final ok = i == q.odd;
    setState(() {
      selected = i; isCorrect = ok;
      if (ok) { score++; streak++; } else { streak = 0; }
    });
    ok ? hapticSuccess() : hapticError();
  }

  void _next() {
    if (round < _total - 1) {
      setState(() { round++; selected = null; isCorrect = null; });
      return;
    }
    final pct = score / _total;
    final st = pct >= 0.9 ? 3 : pct >= 0.7 ? 2 : pct >= 0.5 ? 1 : 0;
    setState(() { complete = true; confetti = st >= 2; });
    final store = context.read<AppStore>();
    store.addPoints(score * 11);
    if (st > 0) store.addStars(st);
    final aId = widget.params['activityId'], lvl = widget.params['levelNumber'];
    if (st > 0 && aId is String && lvl is int) store.completeActivityLevel(aId, lvl);
  }

  void _restart() => setState(() {
        rounds = _buildRounds(widget.params, Random());
        round = 0; selected = null; isCorrect = null; score = 0; streak = 0; complete = false;
      });

  @override
  Widget build(BuildContext context) {
    if (complete) return _result();
    final accents = [Palette.light.purple, Palette.light.green, Palette.light.sky, Palette.light.pink, AppColors.primary];
    return ScreenScaffold(child: Column(children: [
      HeaderBar(title: 'Odd One Out', subtitle: 'Round ${round + 1} of $_total',
          onBack: () => Navigator.of(context).maybePop(), rightAction: ScoreBadge(score)),
      HsProgressBar(progress: (round + 1) / _total, height: 4),
      if (streak >= 2) Center(child: Container(
        margin: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.sm),
        padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.sm),
        decoration: BoxDecoration(color: AppColors.starGold.withAlpha(0x22), borderRadius: BorderRadius.circular(9999),
            border: Border.all(color: AppColors.starGold)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.local_fire_department, size: 16, color: AppColors.starGold), const SizedBox(width: Sp.sm),
          Text('$streak in a row!', style: Fonts.body(14, w: FontWeight.w800, color: AppColors.textPrimary)),
        ]),
      )),
      Expanded(child: screenScroll(
        padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.md),
        child: Column(children: [
          Center(child: Container(
            margin: const EdgeInsets.only(bottom: Sp.md),
            padding: const EdgeInsets.symmetric(horizontal: Sp.lg, vertical: Sp.sm),
            decoration: BoxDecoration(gradient: toneGradient(AppColors.primary), borderRadius: BorderRadius.circular(9999),
                boxShadow: toyShadow(AppColors.primaryDark, 4)),
            child: Text(q.category, style: Fonts.body(12, w: FontWeight.w800, color: AppColors.textOnPrimary)),
          )),
          Padding(padding: const EdgeInsets.only(bottom: Sp.lg), child: Text(
              '${q.words.length - 1} words belong together — tap the one that doesn\'t',
              textAlign: TextAlign.center, style: Fonts.display(16, color: AppColors.textPrimary, w: FontWeight.w800))),
          LayoutBuilder(builder: (context, c) {
            final w = (c.maxWidth - Sp.md) / 2;
            return Wrap(alignment: WrapAlignment.center, spacing: Sp.md, runSpacing: Sp.md, children: [
              for (int i = 0; i < q.words.length; i++) _card(i, accents[i % accents.length], w),
            ]);
          }),
          const SizedBox(height: Sp.lg),
          if (selected != null) PopIn(key: ValueKey('e$round'), child: Column(children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(Sp.md),
              decoration: BoxDecoration(
                color: (isCorrect! ? AppColors.success : AppColors.error).withAlpha(0x15),
                borderRadius: BorderRadius.circular(Rad.xl),
                border: Border.all(color: isCorrect! ? AppColors.success : AppColors.error, width: 2)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(isCorrect! ? Icons.check_circle : Icons.error, size: 20, color: isCorrect! ? AppColors.success : AppColors.error),
                  const SizedBox(width: Sp.sm),
                  Text(isCorrect! ? 'Correct!' : 'Not quite — the odd one is ${q.words[q.odd].hindi}',
                      style: Fonts.body(14, w: FontWeight.w800, color: isCorrect! ? AppColors.success : AppColors.error)),
                ]),
                const SizedBox(height: Sp.sm),
                Text(q.explanation, style: Fonts.body(15, color: AppColors.textPrimary, height: 1.4)),
              ]),
            ),
            const SizedBox(height: Sp.md),
            ResultButton(label: round < _total - 1 ? 'Next' : 'See Results', icon: Icons.arrow_forward, onTap: _next),
          ])),
          const SizedBox(height: Sp.xl),
        ]),
      )),
    ]));
  }

  Widget _card(int i, Color accent, double w) {
    final answered = selected != null;
    final isOdd = i == q.odd;
    final bg = !answered ? AppColors.surface
        : isOdd ? AppColors.success
        : selected == i ? AppColors.error : AppColors.surface;
    final border = !answered ? accent : isOdd ? AppColors.success : selected == i ? AppColors.error : AppColors.border;
    final fg = answered && (isOdd || selected == i) ? AppColors.textOnPrimary : AppColors.textPrimary;
    return GestureDetector(
      onTap: answered ? null : () { speakHindi(q.words[i].hindi, rate: 0.8); _select(i); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: w, height: 112,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Rad.xl),
            border: Border.all(color: border, width: 2), boxShadow: toyShadow(border, 4)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(q.words[i].hindi, textAlign: TextAlign.center, style: Fonts.hindi(28, color: fg, height: 1.3)),
          if (answered) Text(q.words[i].meaning, style: Fonts.body(12, w: FontWeight.w700,
              color: fg == AppColors.textOnPrimary ? fg : AppColors.textSecondary)),
        ]),
      ),
    );
  }

  Widget _result() {
    final pct = _total == 0 ? 0.0 : score / _total;
    final stars = pct >= 0.9 ? 3 : pct >= 0.7 ? 2 : pct >= 0.5 ? 1 : 0;
    return ScreenScaffold(child: Stack(children: [
      Column(children: [
        HeaderBar(title: 'Odd One Out', onBack: () => Navigator.of(context).maybePop()),
        Expanded(child: SessionCompleteCard(
          emoji: stars >= 2 ? '🧠' : '💭', title: 'Quiz Complete!', stars: stars,
          stats: [('$score/$_total', 'Correct'), ('${(pct * 100).round()}%', 'Accuracy')],
          message: stars == 3 ? 'Outstanding! You spotted every pattern!'
              : stars == 2 ? 'Great job! Your pattern spotting is strong!'
              : stars == 1 ? 'Good effort! Keep looking for what the words share.'
              : 'Try again and think about what the other words have in common.',
          doneLabel: 'Done', onRetry: _restart, onDone: () => Navigator.of(context).maybePop(),
        )),
      ]),
      Positioned.fill(child: Confetti(visible: confetti, onComplete: () => setState(() => confetti = false))),
    ]));
  }
}
