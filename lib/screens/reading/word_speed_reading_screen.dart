import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/reading_data.dart';
import '../../services/feedback.dart';
import '../../store/app_store.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../../widgets/common.dart';
import '../../widgets/progress_bar.dart';
import '../../widgets/quiz_common.dart';
import '../../util/num_ext.dart';

const _rounds = 15;
const _timers = {'easy': 4, 'medium': 3, 'hard': 2};

class _Q {
  final Map item; final List<String> options;
  _Q(this.item, this.options);
}

_Q _gen(int wordIndex) {
  final item = wordSpeedData[math.min(wordIndex, wordSpeedData.length - 1)] as Map;
  return _Q(item, shuffled<String>([item['english'], ...(item['distractors'] as List).cast<String>()]));
}

/// WordSpeedReadingScreen.tsx — the Hindi word flashes briefly, then pick its meaning.
class WordSpeedReadingScreen extends StatefulWidget {
  final Map<String, dynamic> params;
  const WordSpeedReadingScreen({super.key, this.params = const {}});
  @override
  State<WordSpeedReadingScreen> createState() => _WordSpeedReadingScreenState();
}

class _WordSpeedReadingScreenState extends State<WordSpeedReadingScreen> {
  int round = 0, score = 0, streak = 0;
  late _Q q = _gen(0);
  String? selected;
  bool? isCorrect;
  bool complete = false, confetti = false, wordVisible = true;
  late double timeRemaining = _timers[q.item['difficulty']]!.toDouble();
  Timer? _hide, _tick, _next;

  @override
  void initState() { super.initState(); _startRound(); }

  @override
  void dispose() { _hide?.cancel(); _tick?.cancel(); _next?.cancel(); super.dispose(); }

  int get _dur => _timers[q.item['difficulty']]!;

  void _startRound() {
    _hide?.cancel(); _tick?.cancel();
    _hide = Timer(Duration(seconds: _dur), () {
      if (!mounted) return;
      _tick?.cancel();
      setState(() => wordVisible = false);
    });
    _tick = Timer.periodic(const Duration(milliseconds: 100), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        if (timeRemaining <= 0.1) { timeRemaining = 0; t.cancel(); }
        else { timeRemaining -= 0.1; }
      });
    });
  }

  void _select(String option) {
    if (selected != null) return;
    final ok = option == q.item['english'];
    final roundAtTap = round, scoreAtTap = score;
    setState(() {
      selected = option; isCorrect = ok;
      if (ok) { score++; streak++; } else { streak = 0; }
    });
    ok ? hapticSuccess() : hapticError();
    _next = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      if (roundAtTap < _rounds - 1) {
        setState(() {
          round = roundAtTap + 1; q = _gen(round); selected = null; isCorrect = null; wordVisible = true;
          timeRemaining = _timers[(wordSpeedData[round] as Map)['difficulty']]!.toDouble();
        });
        _startRound();
      } else {
        setState(() { complete = true; if (ok && scoreAtTap + 1 >= 11) confetti = true; });
        final st = score >= 13 ? 3 : score >= 11 ? 2 : score >= 8 ? 1 : 0;
        final store = context.read<AppStore>();
        store.addPoints(score * 12);
        if (st > 0) store.addStars(st);
        final aId = widget.params['activityId'], lvl = widget.params['levelNumber'];
        if (st > 0 && aId is String && lvl is int) store.completeActivityLevel(aId, lvl);
      }
    });
  }

  void _restart() {
    setState(() {
      round = 0; q = _gen(0); selected = null; isCorrect = null; score = 0; streak = 0; complete = false; wordVisible = true;
      timeRemaining = _timers[(wordSpeedData[0] as Map)['difficulty']]!.toDouble();
    });
    _startRound();
  }

  @override
  Widget build(BuildContext context) {
    final stars = score >= 13 ? 3 : score >= 11 ? 2 : score >= 8 ? 1 : 0;
    if (complete) {
      return ScreenScaffold(child: Stack(children: [
        PlainQuizResult(
          emoji: stars >= 2 ? '🚀' : '👍', title: 'Speed Reading Complete!', stars: stars,
          scoreText: '$score / $_rounds words recognized',
          message: stars == 3 ? 'Amazing speed reader! You dominated!'
              : stars == 2 ? 'Excellent! Your reading speed is improving!'
              : stars == 1 ? 'Good progress! Keep practicing!' : 'Practice regularly to improve your speed!',
          onRetry: _restart, onDone: () => Navigator.of(context).maybePop(),
        ),
        Positioned.fill(child: Confetti(visible: confetti, onComplete: () => setState(() => confetti = false))),
      ]));
    }
    final dur = _timers[q.item['difficulty']]!;
    final w = MediaQuery.of(context).size.width;
    final cardSize = math.min(w - Sp.md * 2, 380.0);
    return ScreenScaffold(child: Column(children: [
      HeaderBar(title: 'Speed Reading', subtitle: 'Word ${round + 1} of $_rounds',
          onBack: () => Navigator.of(context).maybePop(), rightAction: PlainScore(score)),
      HsProgressBar(progress: (round + 1) / _rounds, height: 4),
      if (streak >= 2) StreakChip(streak, goldLeft: true),
      Expanded(flex: 12, child: Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: Sp.md), child: wordVisible
          ? SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: cardSize, height: cardSize, margin: const EdgeInsets.only(bottom: Sp.lg), alignment: Alignment.center,
                decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(Rad.xl2), boxShadow: softShadow(AppColors.primary)),
                child: FittedBox(fit: BoxFit.scaleDown, child: Padding(padding: const EdgeInsets.all(Sp.md),
                    child: Text(q.item['hindi'], style: Fonts.hindi(120, color: AppColors.textOnPrimary, height: 140 / 120)))),
              ),
              SizedBox(width: cardSize, child: Column(children: [
                Container(
                  width: cardSize * 0.8, height: 10,
                  decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(9999), border: Border.all(color: AppColors.border)),
                  clipBehavior: Clip.antiAlias, alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(widthFactor: (timeRemaining / dur).clampD(0.0, 1.0),
                      child: Container(decoration: BoxDecoration(gradient: toneGradient(AppColors.primary), borderRadius: BorderRadius.circular(9999)))),
                ),
                const SizedBox(height: Sp.sm),
                Text('${timeRemaining.toStringAsFixed(1)}s', style: Fonts.body(14, w: FontWeight.w800, color: AppColors.primary)),
              ])),
            ]))
          : Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.visibility_off_outlined, size: 48, color: AppColors.textMuted),
              const SizedBox(height: Sp.md),
              Text('What did you read?', style: Fonts.display(20, color: AppColors.textSecondary, w: FontWeight.w700)),
            ])))),
      Expanded(flex: 10, child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Sp.md, 0, Sp.md, Sp.lg),
        child: Column(children: [
          Text('Pick the correct meaning', textAlign: TextAlign.center, style: Fonts.body(14, color: AppColors.textSecondary)),
          const SizedBox(height: Sp.md),
          for (final opt in q.options) Padding(padding: const EdgeInsets.only(bottom: Sp.md), child: _opt(opt)),
        ]),
      )),
    ]));
  }

  Widget _opt(String option) {
    Color bg = AppColors.surface, text = AppColors.textPrimary;
    if (selected != null) {
      if (selected != option) { bg = AppColors.surface; text = AppColors.textSecondary; }
      else { bg = isCorrect == true ? AppColors.success : AppColors.error; text = AppColors.textOnPrimary; }
    }
    return GestureDetector(
      onTap: selected != null ? null : () => _select(option),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: Sp.lg, vertical: Sp.md),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Rad.xl),
            border: Border.all(color: AppColors.border), boxShadow: toyShadow(AppColors.toyShadowColor, 4)),
        child: Row(children: [
          Expanded(child: Text(option, style: Fonts.body(16, w: FontWeight.w600, color: text))),
          if (selected == option) Icon(isCorrect == true ? Icons.check_circle : Icons.cancel, size: 20,
              color: isCorrect == true ? AppColors.success : AppColors.error),
        ]),
      ),
    );
  }
}
