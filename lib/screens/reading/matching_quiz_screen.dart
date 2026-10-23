import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models.dart';
import '../../services/feedback.dart';
import '../../services/speech_service.dart';
import '../../store/app_store.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../../widgets/common.dart';
import '../../widgets/progress_bar.dart';
import '../../widgets/quiz_common.dart';

const _total = 10;

class _Accent {
  final Color fg, shadow;
  const _Accent(this.fg, this.shadow);
}

final _accents = [
  const _Accent(AppColors.primary, Color(0xFFB57140)),
  _Accent(Palette.light.purple, const Color(0xFF4A32A6)),
  _Accent(Palette.light.green, const Color(0xFF2E9163)),
  _Accent(Palette.light.sky, const Color(0xFF2E7FAB)),
];

class _Q {
  final HindiLetter letter; final List<HindiLetter> options;
  _Q(this.letter, this.options);
}

_Q _gen() {
  final s = shuffled(AppData.allLetters);
  final correct = s[0];
  return _Q(correct, shuffled([correct, ...s.sublist(1, 4)]));
}

/// MatchingQuizScreen.tsx — pick the right romanization for a letter.
class MatchingQuizScreen extends StatefulWidget {
  final Map<String, dynamic> params;
  const MatchingQuizScreen({super.key, this.params = const {}});
  @override
  State<MatchingQuizScreen> createState() => _MatchingQuizScreenState();
}

class _MatchingQuizScreenState extends State<MatchingQuizScreen> {
  late final List<_Q> questions = List.generate(_total, (_) => _gen());
  int cur = 0, score = 0, streak = 0;
  String? selected;
  bool? isCorrect;
  bool complete = false, confetti = false;
  Timer? _t;

  @override
  void dispose() { _t?.cancel(); super.dispose(); }

  void _select(String id) {
    if (selected != null) return;
    final q = questions[cur];
    final ok = id == q.letter.id;
    setState(() {
      selected = id; isCorrect = ok;
      if (ok) { score++; streak++; } else { streak = 0; }
    });
    ok ? hapticSuccess() : hapticError();
    _t = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() {
        if (cur < _total - 1) { cur++; selected = null; isCorrect = null; }
        else { complete = true; if (score >= 7) confetti = true; }
      });
      final aId = widget.params['activityId'], lvl = widget.params['levelNumber'];
      if (complete && score >= 5 && aId is String && lvl is int) context.read<AppStore>().completeActivityLevel(aId, lvl);
    });
  }

  void _restart() => setState(() { cur = 0; selected = null; isCorrect = null; score = 0; streak = 0; complete = false; });

  @override
  Widget build(BuildContext context) {
    final stars = score >= 9 ? 3 : score >= 7 ? 2 : score >= 5 ? 1 : 0;
    if (complete) {
      return ScreenScaffold(child: Stack(children: [
        QuizResultCard(
          emoji: stars >= 2 ? '🎉' : '💪', title: 'Quiz Complete!', stars: stars,
          scoreText: '$score / $_total correct',
          message: stars == 3 ? 'Outstanding! You know these letters!'
              : stars == 2 ? 'Great work! Keep practicing!'
              : stars == 1 ? 'Good effort! Review the flashcards and try again.' : "Keep studying — you'll get there!",
          onRetry: _restart, onDone: () => Navigator.of(context).maybePop(),
        ),
        Positioned.fill(child: Confetti(visible: confetti, onComplete: () => setState(() => confetti = false))),
      ]));
    }
    final q = questions[cur];
    return ScreenScaffold(child: Column(children: [
      HeaderBar(title: 'Letter Quiz', subtitle: 'Question ${cur + 1} of $_total',
          onBack: () => Navigator.of(context).maybePop(), rightAction: ScoreBadge(score)),
      HsProgressBar(progress: (cur + 1) / _total, height: 4),
      if (streak >= 2) StreakBar(streak),
      Expanded(child: SingleChildScrollView(child: Column(children: [
        Padding(padding: const EdgeInsets.symmetric(vertical: Sp.lg), child: Column(children: [
          Text('What letter is this?', style: Fonts.body(16, w: FontWeight.w700, color: AppColors.textSecondary)),
          const SizedBox(height: Sp.md),
          Container(
            key: ValueKey(cur), width: 176, height: 176, alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(Rad.xl2),
                border: Border.all(color: AppColors.border), boxShadow: softShadow(AppColors.primary)),
            child: Text(q.letter.character, style: Fonts.hindi(100, color: AppColors.textPrimary, height: 1.2)),
          ),
          const SizedBox(height: Sp.md),
          HearButton(onTap: () => speakHindi(q.letter.character, rate: 0.6)),
        ])),
        Padding(padding: const EdgeInsets.symmetric(horizontal: Sp.lg), child: Column(children: [
          for (int i = 0; i < q.options.length; i++) Padding(
            padding: const EdgeInsets.only(bottom: Sp.md),
            child: _option(q, q.options[i], _accents[i % _accents.length]),
          ),
        ])),
        if (selected != null)
          FeedbackRow(correct: isCorrect == true, text: isCorrect == true ? 'Correct!' : 'It\'s "${q.letter.romanized}"'),
        const SizedBox(height: Sp.lg),
      ]))),
    ]));
  }

  Widget _option(_Q q, HindiLetter opt, _Accent a) {
    final isSel = selected == opt.id, isAns = opt.id == q.letter.id;
    Color bg = AppColors.surface, border = a.fg, text = AppColors.textPrimary, shadow = a.shadow;
    if (selected != null) {
      if (isAns) { bg = AppColors.success.withOpacity(0.125); border = AppColors.success; text = AppColors.success; shadow = const Color(0xFF2E9163); }
      else if (isSel && isCorrect != true) { bg = AppColors.error.withOpacity(0.125); border = AppColors.error; text = AppColors.error; shadow = const Color(0xFFA32E1F); }
      else { bg = AppColors.surface; border = AppColors.border; text = AppColors.textSecondary; shadow = const Color(0xFFB57140); }
    }
    return GestureDetector(
      onTap: selected != null ? null : () => _select(opt.id),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: Sp.md, horizontal: Sp.lg),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Rad.xl),
            border: Border.all(color: border, width: 2), boxShadow: toyShadow(shadow, 4)),
        child: Row(children: [
          Expanded(child: Text(opt.romanized, style: Fonts.body(18, w: FontWeight.w800, color: text))),
          Opacity(opacity: 0.7, child: Text('"${opt.pronunciation}"', style: Fonts.body(14, w: FontWeight.w500, color: text))),
          if (selected != null && isAns) const Padding(padding: EdgeInsets.only(left: Sp.sm), child: Icon(Icons.check_circle, size: 22, color: AppColors.success)),
          if (isSel && isCorrect != true && selected != null) const Padding(padding: EdgeInsets.only(left: Sp.sm), child: Icon(Icons.cancel, size: 22, color: AppColors.error)),
        ]),
      ),
    );
  }
}
