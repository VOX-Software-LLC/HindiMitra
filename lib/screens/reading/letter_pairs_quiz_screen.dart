import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/reading_data.dart';
import '../../services/feedback.dart';
import '../../services/speech_service.dart';
import '../../store/app_store.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../../widgets/common.dart';
import '../../widgets/progress_bar.dart';
import '../../widgets/quiz_common.dart';

const _rounds = 10;
final _rng = Random();

class _Q {
  final List<String> pair, hints; final int correctIndex;
  _Q(this.pair, this.hints, this.correctIndex);
}

_Q _gen() {
  final p = letterPairsData[_rng.nextInt(letterPairsData.length)] as Map;
  return _Q((p['pair'] as List).cast<String>(), (p['hints'] as List).cast<String>(), _rng.nextDouble() > 0.5 ? 0 : 1);
}

/// LetterPairsQuizScreen.tsx — aspirated vs non-aspirated letter listening quiz.
class LetterPairsQuizScreen extends StatefulWidget {
  final Map<String, dynamic> params;
  const LetterPairsQuizScreen({super.key, this.params = const {}});
  @override
  State<LetterPairsQuizScreen> createState() => _LetterPairsQuizScreenState();
}

class _LetterPairsQuizScreenState extends State<LetterPairsQuizScreen> {
  int round = 0, score = 0, streak = 0;
  late _Q q = _gen();
  int? selected;
  bool? isCorrect;
  bool complete = false, confetti = false, playing = false;
  Timer? _playT, _t;

  @override
  void dispose() { _playT?.cancel(); _t?.cancel(); super.dispose(); }

  void _play() {
    if (playing) return;
    setState(() => playing = true);
    speakHindi(q.pair[q.correctIndex], rate: 0.6);
    _playT?.cancel();
    _playT = Timer(const Duration(seconds: 2), () { if (mounted) setState(() => playing = false); });
  }

  void _select(int i) {
    if (selected != null) return;
    final ok = i == q.correctIndex;
    final roundAtTap = round, scoreAtTap = score;
    setState(() {
      selected = i; isCorrect = ok;
      if (ok) { score++; streak++; } else { streak = 0; }
    });
    ok ? hapticSuccess() : hapticError();
    _t = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      if (roundAtTap < _rounds - 1) {
        setState(() { round = roundAtTap + 1; q = _gen(); selected = null; isCorrect = null; });
      } else {
        setState(() { complete = true; if (ok && scoreAtTap + 1 >= 7) confetti = true; });
        final st = score >= 9 ? 3 : score >= 7 ? 2 : score >= 5 ? 1 : 0;
        final store = context.read<AppStore>();
        store.addPoints(score * 10);
        if (st > 0) store.addStars(st);
        final aId = widget.params['activityId'], lvl = widget.params['levelNumber'];
        if (st > 0 && aId is String && lvl is int) store.completeActivityLevel(aId, lvl);
      }
    });
  }

  void _restart() => setState(() { round = 0; q = _gen(); selected = null; isCorrect = null; score = 0; streak = 0; complete = false; });

  @override
  Widget build(BuildContext context) {
    final stars = score >= 9 ? 3 : score >= 7 ? 2 : score >= 5 ? 1 : 0;
    if (complete) {
      return ScreenScaffold(child: Stack(children: [
        PlainQuizResult(
          emoji: stars >= 2 ? '🎉' : '💪', stars: stars, scoreText: '$score / $_rounds correct',
          message: stars == 3 ? 'Perfect! Your ear is finely tuned!'
              : stars == 2 ? 'Great job! Aspirated letters are tricky!'
              : stars == 1 ? 'Good start! Keep listening closely!' : 'Practice makes perfect. Try again!',
          onRetry: _restart, onDone: () => Navigator.of(context).maybePop(),
        ),
        Positioned.fill(child: Confetti(visible: confetti, onComplete: () => setState(() => confetti = false))),
      ]));
    }
    return ScreenScaffold(child: Column(children: [
      HeaderBar(title: 'Letter Pairs Quiz', subtitle: 'Round ${round + 1} of $_rounds',
          onBack: () => Navigator.of(context).maybePop(), rightAction: PlainScore(score)),
      HsProgressBar(progress: (round + 1) / _rounds, height: 4),
      if (streak >= 2) StreakChip(streak, goldLeft: true),
      Expanded(child: Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: Sp.md), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(padding: const EdgeInsets.only(bottom: Sp.lg), child: Text('Listen to the letter and pick which one you heard',
            textAlign: TextAlign.center, style: Fonts.body(16, w: FontWeight.w500, color: AppColors.textSecondary))),
        GestureDetector(
          onTap: (playing || selected != null) ? null : _play,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: Sp.xl, vertical: Sp.lg),
            decoration: BoxDecoration(color: playing ? AppColors.primaryDark : AppColors.primary, borderRadius: BorderRadius.circular(9999),
                boxShadow: toyShadow(AppColors.primaryDark, 6)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              playing
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textOnPrimary))
                  : const Icon(Icons.volume_up, size: 24, color: AppColors.textOnPrimary),
              const SizedBox(width: Sp.md),
              Text(playing ? 'Playing...' : 'Tap to Hear', style: Fonts.body(16, w: FontWeight.w800, color: AppColors.textOnPrimary)),
            ]),
          ),
        ),
      ])))),
      Padding(
        padding: const EdgeInsets.fromLTRB(Sp.md, 0, Sp.md, Sp.lg),
        child: Column(children: [
          for (int i = 0; i < q.pair.length; i++) Padding(padding: const EdgeInsets.only(bottom: Sp.md), child: _card(i)),
        ]),
      ),
    ]));
  }

  Widget _card(int idx) {
    Color bg = AppColors.surface, text = AppColors.textPrimary;
    if (selected != null) {
      if (selected != idx) { bg = AppColors.surface; text = AppColors.textSecondary; }
      else { bg = isCorrect == true ? AppColors.success : AppColors.error; text = AppColors.textOnPrimary; }
    }
    return GestureDetector(
      onTap: selected != null ? null : () => _select(idx),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Sp.lg, vertical: Sp.lg),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Rad.xl),
            border: Border.all(color: AppColors.border), boxShadow: toyShadow(AppColors.toyShadowColor, 4)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(q.pair[idx], style: Fonts.hindi(48, color: text, height: 140 / 120 * 1.0)),
          const SizedBox(width: Sp.md),
          Text(q.hints[idx], style: Fonts.body(12, w: FontWeight.w500, color: text).copyWith(fontStyle: FontStyle.italic)),
          const Spacer(),
          if (selected == idx) Icon(isCorrect == true ? Icons.check_circle : Icons.cancel, size: 24,
              color: isCorrect == true ? AppColors.success : AppColors.error),
        ]),
      ),
    );
  }
}
