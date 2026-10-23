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
  final String target, rhyme; final List<String> options;
  _Q(this.target, this.rhyme, this.options);
}

_Q _gen(int setIndex) {
  final set = rhymeSetsData[setIndex] as Map;
  final rhymes = (set['rhymes'] as List).cast<String>();
  final non = (set['nonRhymes'] as List).cast<String>();
  final rhyme = rhymes[_rng.nextInt(rhymes.length)];
  final wrong = shuffled<String>([non[0], non[1], non[2]]);
  return _Q(set['word'], rhyme, shuffled<String>([rhyme, ...wrong.take(3)]));
}

/// RhymingWordsScreen.tsx
class RhymingWordsScreen extends StatefulWidget {
  final Map<String, dynamic> params;
  const RhymingWordsScreen({super.key, this.params = const {}});
  @override
  State<RhymingWordsScreen> createState() => _RhymingWordsScreenState();
}

class _RhymingWordsScreenState extends State<RhymingWordsScreen> {
  int round = 0, score = 0, streak = 0;
  late _Q q = _gen(0);
  String? selected, playing;
  bool? isCorrect;
  bool complete = false, confetti = false;
  Timer? _t, _pt;

  @override
  void dispose() { _t?.cancel(); _pt?.cancel(); super.dispose(); }

  void _play(String w) {
    setState(() => playing = w);
    speakHindi(w, rate: 0.6);
    _pt?.cancel();
    _pt = Timer(const Duration(milliseconds: 1500), () { if (mounted) setState(() => playing = null); });
  }

  void _select(String option) {
    if (selected != null) return;
    final ok = option == q.rhyme;
    final roundAtTap = round, scoreAtTap = score;
    setState(() {
      selected = option; isCorrect = ok;
      if (ok) { score++; streak++; } else { streak = 0; }
    });
    ok ? hapticSuccess() : hapticError();
    _t = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      if (roundAtTap < _rounds - 1) {
        setState(() { round = roundAtTap + 1; q = _gen(round); selected = null; isCorrect = null; });
      } else {
        setState(() { complete = true; if (ok && scoreAtTap + 1 >= 7) confetti = true; });
        final st = score >= 9 ? 3 : score >= 7 ? 2 : score >= 5 ? 1 : 0;
        final store = context.read<AppStore>();
        store.addPoints(score * 11);
        if (st > 0) store.addStars(st);
        final aId = widget.params['activityId'], lvl = widget.params['levelNumber'];
        if (st > 0 && aId is String && lvl is int) store.completeActivityLevel(aId, lvl);
      }
    });
  }

  void _restart() => setState(() { round = 0; q = _gen(0); selected = null; isCorrect = null; score = 0; streak = 0; complete = false; });

  @override
  Widget build(BuildContext context) {
    final stars = score >= 9 ? 3 : score >= 7 ? 2 : score >= 5 ? 1 : 0;
    if (complete) {
      return ScreenScaffold(child: Stack(children: [
        PlainQuizResult(
          emoji: stars >= 2 ? '🎵' : '👂', title: 'Rhyming Complete!', stars: stars, scoreText: '$score / $_rounds correct',
          message: stars == 3 ? 'Perfect rhymer! Excellent ear for Hindi!'
              : stars == 2 ? 'Great job! You understand Hindi rhyming!'
              : stars == 1 ? 'Good effort! Keep listening to rhymes!' : 'Practice more rhyming patterns!',
          onRetry: _restart, onDone: () => Navigator.of(context).maybePop(),
        ),
        Positioned.fill(child: Confetti(visible: confetti, onComplete: () => setState(() => confetti = false))),
      ]));
    }
    final accents = [Palette.light.purple, Palette.light.green, Palette.light.sky, Palette.light.pink];
    return ScreenScaffold(child: Column(children: [
      HeaderBar(title: 'Rhyming Words', subtitle: 'Round ${round + 1} of $_rounds',
          onBack: () => Navigator.of(context).maybePop(), rightAction: PlainScore(score)),
      HsProgressBar(progress: (round + 1) / _rounds, height: 4),
      if (streak >= 2) Container(
        margin: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.sm),
        padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.sm),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(Rad.lg),
            border: const Border(left: BorderSide(color: AppColors.starGold, width: 4))),
        child: Row(children: [
          const Icon(Icons.local_fire_department, size: 16, color: AppColors.starGold), const SizedBox(width: Sp.sm),
          Text('$streak in a row!', style: Fonts.body(14, w: FontWeight.w700, color: AppColors.textPrimary)),
        ]),
      ),
      Expanded(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.symmetric(horizontal: Sp.md), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(padding: const EdgeInsets.only(bottom: Sp.lg), child: Text('Which word rhymes with this?',
            textAlign: TextAlign.center, style: Fonts.body(16, color: AppColors.textSecondary))),
        GestureDetector(
          onTap: () => _play(q.target),
          child: Container(
            padding: const EdgeInsets.all(Sp.xl),
            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(Rad.xl2), boxShadow: softShadow(AppColors.primary)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(q.target, style: Fonts.hindi(120, color: AppColors.textOnPrimary, height: 140 / 120)),
              const SizedBox(height: Sp.md),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(playing == q.target ? Icons.volume_up : Icons.volume_off, size: 16, color: AppColors.primary),
                const SizedBox(width: Sp.xs),
                Opacity(opacity: 0.8, child: Text('Tap to hear', style: Fonts.body(12, w: FontWeight.w500, color: AppColors.textOnPrimary))),
              ]),
            ]),
          ),
        ),
      ])))),
      Padding(
        padding: const EdgeInsets.fromLTRB(Sp.md, 0, Sp.md, Sp.lg),
        child: Column(children: [
          for (int i = 0; i < q.options.length; i++) Padding(padding: const EdgeInsets.only(bottom: Sp.md), child: _card(q.options[i], accents[i % accents.length])),
        ]),
      ),
    ]));
  }

  Widget _card(String option, Color accent) {
    final isSel = selected == option;
    final showAccent = selected == null;
    Color bg = AppColors.surface, text = AppColors.textPrimary;
    if (selected != null) {
      if (!isSel) { bg = AppColors.surface; text = AppColors.textSecondary; }
      else { bg = isCorrect == true ? AppColors.success : AppColors.error; text = AppColors.textOnPrimary; }
    }
    return GestureDetector(
      onTap: selected != null ? null : () => _select(option),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Sp.lg, vertical: Sp.md),
        decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(Rad.xl),
          border: Border.all(color: showAccent ? accent : isSel ? Colors.transparent : AppColors.border, width: 2),
          boxShadow: toyShadow(showAccent ? accent : AppColors.toyShadowColor, 4)),
        child: Row(children: [
          Expanded(child: Center(child: Text(option, style: Fonts.hindi(20, color: text, height: 28 / 20)))),
          if (isSel) Icon(isCorrect == true ? Icons.check_circle : Icons.cancel, size: 24, color: isCorrect == true ? AppColors.success : AppColors.error),
          if (selected == null) Padding(padding: const EdgeInsets.only(left: Sp.md), child: GestureDetector(
            onTap: () => _play(option),
            child: Icon(playing == option ? Icons.volume_up : Icons.volume_mute_outlined, size: 20, color: AppColors.textSecondary),
          )),
        ]),
      ),
    );
  }
}
