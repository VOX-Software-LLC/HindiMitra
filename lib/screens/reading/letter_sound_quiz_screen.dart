import 'dart:async';
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
import '../../util/num_ext.dart';

const _total = 10;

class _Q {
  final String letter, correct; final List<String> options;
  _Q(this.letter, this.correct, this.options);
}

_Q _gen() {
  final q = shuffled(letterSoundData).first as Map;
  return _Q(q['letter'], q['correct'], shuffled<String>((q['options'] as List).cast<String>()));
}

/// LetterSoundQuizScreen.tsx — hear each option (device TTS), then pick the right sound.
class LetterSoundQuizScreen extends StatefulWidget {
  final Map<String, dynamic> params;
  const LetterSoundQuizScreen({super.key, this.params = const {}});
  @override
  State<LetterSoundQuizScreen> createState() => _LetterSoundQuizScreenState();
}

class _LetterSoundQuizScreenState extends State<LetterSoundQuizScreen> {
  late final List<_Q> questions = List.generate(_total, (_) => _gen());
  int cur = 0, score = 0, streak = 0;
  String? selected;
  bool? isCorrect;
  bool complete = false, confetti = false;
  Timer? _t;

  @override
  void dispose() { _t?.cancel(); super.dispose(); }

  void _select(String option) {
    if (selected != null) return;
    final q = questions[cur];
    final ok = option == q.correct;
    final idxAtTap = cur;
    setState(() {
      selected = option; isCorrect = ok;
      if (ok) { score++; streak++; } else { streak = 0; }
    });
    ok ? hapticSuccess() : hapticError();
    _t = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      if (idxAtTap < _total - 1) {
        setState(() { cur = idxAtTap + 1; selected = null; isCorrect = null; });
      } else {
        setState(() { complete = true; if (score >= 7) confetti = true; });
        final st = score >= 9 ? 3 : score >= 7 ? 2 : score >= 5 ? 1 : 0;
        final store = context.read<AppStore>();
        store.addPoints(score * 10);
        if (st > 0) store.addStars(st);
        final aId = widget.params['activityId'], lvl = widget.params['levelNumber'];
        if (st > 0 && aId is String && lvl is int) store.completeActivityLevel(aId, lvl);
      }
    });
  }

  void _restart() => setState(() { cur = 0; selected = null; isCorrect = null; score = 0; streak = 0; complete = false; });

  @override
  Widget build(BuildContext context) {
    final stars = score >= 9 ? 3 : score >= 7 ? 2 : score >= 5 ? 1 : 0;
    if (complete) {
      return ScreenScaffold(child: Stack(children: [
        Center(child: SingleChildScrollView(padding: const EdgeInsets.symmetric(horizontal: Sp.lg), child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(stars >= 2 ? '🎉' : '💪', style: const TextStyle(fontSize: 80)),
          const SizedBox(height: Sp.md),
          Text('Quiz Complete!', textAlign: TextAlign.center, style: Fonts.display(24)),
          const SizedBox(height: Sp.md),
          StarRating(stars: stars, size: 48),
          Padding(padding: const EdgeInsets.symmetric(vertical: Sp.md),
              child: Text('$score / $_total correct', style: Fonts.display(20, color: AppColors.primary, w: FontWeight.w700))),
          Padding(padding: const EdgeInsets.only(bottom: Sp.lg), child: Text(
              stars == 3 ? 'Outstanding! Your pronunciation is perfect!'
                  : stars == 2 ? "Great work! You're getting great at these sounds!"
                  : stars == 1 ? 'Good effort! Keep practicing the sounds.' : "Keep listening and practicing — you'll master these!",
              textAlign: TextAlign.center, style: Fonts.body(16, color: AppColors.textSecondary, height: 24 / 16))),
          const SizedBox(height: Sp.lg),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Flexible(child: GestureDetector(
              onTap: _restart,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: Sp.md, horizontal: Sp.lg),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(9999), border: Border.all(color: AppColors.primary, width: 2)),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.refresh, size: 18, color: AppColors.primary), const SizedBox(width: Sp.sm),
                  Text('Try Again', style: Fonts.body(16, w: FontWeight.w800, color: AppColors.primary)),
                ]),
              ),
            )),
            const SizedBox(width: Sp.md),
            Flexible(child: GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: Sp.md, horizontal: Sp.xl),
                decoration: BoxDecoration(gradient: toneGradient(AppColors.primary), borderRadius: BorderRadius.circular(9999), boxShadow: toyShadow(AppColors.primaryDark, 6)),
                child: Text('Done', style: Fonts.body(16, w: FontWeight.w800, color: AppColors.textOnPrimary)),
              ),
            )),
          ]),
        ]))),
        Positioned.fill(child: Confetti(visible: confetti, onComplete: () => setState(() => confetti = false))),
      ]));
    }

    final q = questions[cur];
    final w = MediaQuery.of(context).size.width;
    final cardSize = (w - Sp.xl * 2).clampD(0.0, 280.0);
    return ScreenScaffold(child: Column(children: [
      HeaderBar(title: 'Sound Quiz', subtitle: 'Question ${cur + 1} of $_total', onBack: () => Navigator.of(context).maybePop(),
          rightAction: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.check_circle, size: 14, color: AppColors.success), const SizedBox(width: Sp.xs),
            Text('$score', style: Fonts.body(14, w: FontWeight.w700, color: AppColors.success)),
          ])),
      HsProgressBar(progress: (cur + 1) / _total, height: 4),
      if (streak >= 2) Container(
        margin: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.sm),
        padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.sm),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(9999),
            border: Border.all(color: AppColors.border), boxShadow: toyShadow(AppColors.toyShadowColor, 3)),
        child: Row(children: [
          const Icon(Icons.local_fire_department, size: 16, color: AppColors.starGold), const SizedBox(width: Sp.sm),
          Text('$streak in a row!', style: Fonts.body(14, w: FontWeight.w700, color: AppColors.textPrimary)),
        ]),
      ),
      Expanded(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.symmetric(horizontal: Sp.md), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(padding: const EdgeInsets.only(bottom: Sp.md),
            child: Text('What sound does this letter make?', textAlign: TextAlign.center, style: Fonts.body(14, color: AppColors.textSecondary, height: 20 / 14))),
        Container(
          key: ValueKey(cur), width: cardSize, height: cardSize, alignment: Alignment.center,
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(Rad.xl2),
              border: Border.all(color: AppColors.primary, width: 2), boxShadow: softShadow(AppColors.primary)),
          child: Text(q.letter, style: Fonts.hindi(120, color: AppColors.textPrimary, height: 140 / 120)),
        ),
      ])))),
      Padding(
        padding: const EdgeInsets.fromLTRB(Sp.md, 0, Sp.md, Sp.lg),
        child: Column(children: [
          Padding(padding: const EdgeInsets.only(bottom: Sp.sm),
              child: Text('Tap to hear each option, then pick the right one', textAlign: TextAlign.center,
                  style: Fonts.body(14, color: AppColors.textSecondary, height: 20 / 14))),
          for (final opt in q.options) Padding(padding: const EdgeInsets.only(bottom: Sp.md), child: _option(q, opt)),
        ]),
      ),
    ]));
  }

  Widget _option(_Q q, String option) {
    final isSel = selected == option;
    final bool? correctState = isCorrect != null && option == q.correct ? true : isCorrect != null && option == selected ? false : null;
    final disabled = selected != null;
    Color bg() {
      if (!isSel) return AppColors.surface;
      if (correctState == true) return AppColors.success;
      if (correctState == false) return AppColors.error;
      return AppColors.primary;
    }
    final textColor = isSel ? AppColors.textOnPrimary : AppColors.textPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.md),
      decoration: BoxDecoration(color: bg(), borderRadius: BorderRadius.circular(Rad.xl),
          border: Border.all(color: isSel ? bg() : AppColors.border), boxShadow: toyShadow(AppColors.toyShadowColor, 4)),
      child: Row(children: [
        Expanded(child: GestureDetector(
          onTap: (disabled || isSel) ? null : () => speakDevice(option, rate: 0.8),
          behavior: HitTestBehavior.opaque,
          child: Row(children: [
            Container(width: 36, height: 36,
                decoration: BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle, boxShadow: toyShadow(AppColors.primaryDark, 3)),
                child: const Icon(Icons.volume_up, size: 20, color: AppColors.textOnPrimary)),
            const SizedBox(width: Sp.sm),
            Text('Play sound', style: Fonts.body(14, w: FontWeight.w700, color: AppColors.primary)),
          ]),
        )),
        GestureDetector(
          onTap: disabled ? null : () => _select(option),
          child: Container(
            constraints: const BoxConstraints(minWidth: 60),
            padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.sm),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: isSel ? textColor : Colors.transparent, borderRadius: BorderRadius.circular(9999)),
            child: isSel
                ? Icon(correctState == true ? Icons.check : Icons.close, size: 24, color: correctState == true ? AppColors.success : AppColors.error)
                : Text(option, style: Fonts.body(16, w: FontWeight.w800, color: textColor)),
          ),
        ),
      ]),
    );
  }
}
