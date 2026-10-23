import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/speech_service.dart';
import '../../store/app_store.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../../widgets/common.dart';
import '../../widgets/progress_bar.dart';
import '../../widgets/quiz_common.dart';
import '../../util/num_ext.dart';

class _Sentence {
  final String hindi, english, difficulty;
  final List<String> words, scrambled;
  _Sentence(this.hindi, this.english, this.words, this.difficulty) : scrambled = shuffled(words);
}

/// Scrambled order is decided once at load (same as the RN module-level shuffle).
final List<_Sentence> _sentences = [
  _Sentence('यह मेरा घर है', 'This is my house', ['यह', 'मेरा', 'घर', 'है'], 'easy'),
  _Sentence('मुझे पानी चाहिए', 'I want water', ['मुझे', 'पानी', 'चाहिए'], 'easy'),
  _Sentence('वह स्कूल जाता है', 'He goes to school', ['वह', 'स्कूल', 'जाता', 'है'], 'easy'),
  _Sentence('आज मौसम अच्छा है', 'The weather is good today', ['आज', 'मौसम', 'अच्छा', 'है'], 'medium'),
  _Sentence('मेरा नाम अदित्य है', 'My name is Aditya', ['मेरा', 'नाम', 'अदित्य', 'है'], 'easy'),
  _Sentence('बच्चे बगीचे में खेल रहे हैं', 'Children are playing in the garden', ['बच्चे', 'बगीचे', 'में', 'खेल', 'रहे', 'हैं'], 'hard'),
  _Sentence('कृपया दरवाज़ा बंद करो', 'Please close the door', ['कृपया', 'दरवाज़ा', 'बंद', 'करो'], 'medium'),
  _Sentence('मुझे हिन्दी सीखनी है', 'I want to learn Hindi', ['मुझे', 'हिन्दी', 'सीखनी', 'है'], 'medium'),
];

/// SentenceBuildScreen.tsx
class SentenceBuildScreen extends StatefulWidget {
  final Map<String, dynamic> params;
  const SentenceBuildScreen({super.key, this.params = const {}});
  @override
  State<SentenceBuildScreen> createState() => _SentenceBuildScreenState();
}

class _SentenceBuildScreenState extends State<SentenceBuildScreen> {
  int idx = 0, score = 0;
  List<String> placed = [];
  late List<String> available = List.of(_sentences[0].scrambled);
  bool? isCorrect;
  bool confetti = false, done = false;

  _Sentence get s => _sentences[idx.clampI(0, _sentences.length - 1)];
  int get total => _sentences.length;

  void _tap(String w, int i) {
    if (isCorrect != null) return;
    setState(() { available.removeAt(i); placed.add(w); });
  }

  void _remove(int i) {
    if (isCorrect != null) return;
    setState(() { final w = placed.removeAt(i); available.add(w); });
  }

  void _check() {
    final ok = placed.join(' ') == s.words.join(' ');
    setState(() { isCorrect = ok; if (ok) score++; });
    if (ok) speakHindi(s.hindi, rate: 0.7);
  }

  void _next() {
    if (idx < total - 1) {
      setState(() { idx++; placed = []; available = List.of(_sentences[idx].scrambled); isCorrect = null; });
    } else {
      setState(() { done = true; if (score >= (total * 0.7).floor()) confetti = true; });
      final aId = widget.params['activityId'], lvl = widget.params['levelNumber'];
      if (score * 2 >= total && aId is String && lvl is int) context.read<AppStore>().completeActivityLevel(aId, lvl);
    }
  }

  void _reset() => setState(() { placed = []; available = List.of(s.scrambled); isCorrect = null; });

  void _restart() => setState(() {
        idx = 0; placed = []; available = List.of(_sentences[0].scrambled); isCorrect = null; score = 0; done = false;
      });

  @override
  Widget build(BuildContext context) {
    final good = score >= (total * 0.7).floor();
    if (done) {
      return ScreenScaffold(child: Stack(children: [
        SimpleResult(
          emoji: good ? '🎉' : '💪', title: 'Sentences Complete!', scoreText: '$score / $total correct',
          message: score >= total - 1 ? 'Outstanding! You can build Hindi sentences!'
              : good ? 'Great work! Keep practicing!' : 'Good effort! Review and try again.',
          onRetry: _restart, onDone: () => Navigator.of(context).maybePop(),
        ),
        Positioned.fill(child: Confetti(visible: confetti, onComplete: () => setState(() => confetti = false))),
      ]));
    }
    return ScreenScaffold(child: Column(children: [
      HeaderBar(title: 'Sentence Building', subtitle: '${idx + 1} of $total',
          onBack: () => Navigator.of(context).maybePop(), rightAction: ScoreBadge(score)),
      HsProgressBar(progress: (idx + 1) / total, height: 4),
      Expanded(child: screenScroll(
        padding: const EdgeInsets.all(Sp.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            key: ValueKey(idx), width: double.infinity, padding: const EdgeInsets.all(Sp.lg), margin: const EdgeInsets.only(bottom: Sp.lg),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(Rad.xl),
                border: Border.all(color: AppColors.border), boxShadow: toyShadow(AppColors.toyShadowColor, 4)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(padding: const EdgeInsets.only(bottom: Sp.sm), child: difficultyBadge(s.difficulty)),
              Padding(padding: const EdgeInsets.only(bottom: Sp.xs),
                  child: Text('Translate to Hindi:', style: Fonts.body(12, w: FontWeight.w600, color: AppColors.textSecondary))),
              Padding(padding: const EdgeInsets.only(bottom: Sp.sm), child: Text(s.english, style: Fonts.display(24, height: 32 / 24))),
              GestureDetector(
                onTap: () => speakHindi(s.hindi, rate: 0.7),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.xs),
                  decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(9999)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.volume_up_outlined, size: 16, color: AppColors.primary), const SizedBox(width: Sp.xs),
                    Text('Hear answer', style: Fonts.body(12, w: FontWeight.w700, color: AppColors.primary)),
                  ]),
                ),
              ),
            ]),
          ),
          Padding(padding: const EdgeInsets.only(bottom: Sp.lg), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.only(bottom: Sp.sm),
                child: Text('Your sentence:', style: Fonts.body(12, w: FontWeight.w600, color: AppColors.textSecondary))),
            DashedBorder(child: Container(
              width: double.infinity, constraints: const BoxConstraints(minHeight: 64), padding: const EdgeInsets.all(Sp.md),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(Rad.xl), boxShadow: softShadow(AppColors.primary)),
              child: placed.isEmpty
                  ? Opacity(opacity: 0.7, child: Text('Tap words below to build the sentence', style: Fonts.body(16, color: AppColors.textSecondary)))
                  : Wrap(spacing: Sp.sm, runSpacing: Sp.sm, children: [
                      for (int i = 0; i < placed.length; i++) _chip(placed[i], placedStyle: true, state: isCorrect, onTap: isCorrect != null ? null : () => _remove(i)),
                    ]),
            )),
          ])),
          Padding(padding: const EdgeInsets.only(bottom: Sp.lg), child: Wrap(spacing: Sp.sm, runSpacing: Sp.sm, children: [
            for (int i = 0; i < available.length; i++) _chip(available[i], onTap: () => _tap(available[i], i)),
          ])),
          if (isCorrect != null) Padding(padding: const EdgeInsets.only(bottom: Sp.md), child: Column(children: [
            Container(
              width: double.infinity, padding: const EdgeInsets.all(Sp.md),
              decoration: BoxDecoration(color: isCorrect! ? AppColors.success : AppColors.error, borderRadius: BorderRadius.circular(Rad.xl)),
              child: Row(children: [
                Icon(isCorrect! ? Icons.check_circle : Icons.cancel, size: 22, color: AppColors.textOnPrimary), const SizedBox(width: Sp.sm),
                Text(isCorrect! ? 'Correct!' : 'Not quite right', style: Fonts.body(16, w: FontWeight.w800, color: AppColors.textOnPrimary)),
              ]),
            ),
            if (!isCorrect!) Padding(padding: const EdgeInsets.only(top: Sp.sm),
                child: Text('Correct: ${s.hindi}', textAlign: TextAlign.center, style: Fonts.hindi(16, color: AppColors.textSecondary))),
          ])),
          Row(children: isCorrect == null ? [
            Expanded(child: GestureDetector(
              onTap: _reset,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: Sp.md),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(9999), border: Border.all(color: AppColors.primary, width: 2)),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.refresh, size: 18, color: AppColors.primary), const SizedBox(width: Sp.xs),
                  Text('Reset', style: Fonts.body(16, w: FontWeight.w800, color: AppColors.primary)),
                ]),
              ),
            )),
            const SizedBox(width: Sp.md),
            Expanded(flex: 2, child: GestureDetector(
              onTap: placed.isEmpty ? null : _check,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: Sp.md),
                decoration: BoxDecoration(color: placed.isEmpty ? AppColors.disabled : AppColors.primary, borderRadius: BorderRadius.circular(9999),
                    boxShadow: toyShadow(AppColors.primaryDark, 6)),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('Check', style: Fonts.body(16, w: FontWeight.w800, color: AppColors.textOnPrimary)), const SizedBox(width: Sp.sm),
                  const Icon(Icons.arrow_forward, size: 18, color: AppColors.textOnPrimary),
                ]),
              ),
            )),
          ] : [
            Expanded(child: GestureDetector(
              onTap: _next,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: Sp.md),
                decoration: BoxDecoration(gradient: toneGradient(AppColors.primary), borderRadius: BorderRadius.circular(9999), boxShadow: toyShadow(AppColors.primaryDark, 6)),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(idx < total - 1 ? 'Next Sentence' : 'See Results', style: Fonts.body(16, w: FontWeight.w800, color: AppColors.textOnPrimary)),
                  const SizedBox(width: Sp.sm),
                  const Icon(Icons.arrow_forward, size: 18, color: AppColors.textOnPrimary),
                ]),
              ),
            )),
          ]),
          const SizedBox(height: Sp.xxl * 2),
        ]),
      )),
    ]));
  }

  Widget _chip(String w, {bool placedStyle = false, bool? state, VoidCallback? onTap}) {
    Color bg = AppColors.surface, border = AppColors.border, shadow = AppColors.toyShadowColor, fg = AppColors.textPrimary;
    if (placedStyle) { bg = AppColors.primary.withOpacity(0.09); border = AppColors.primary; shadow = AppColors.primaryDark; fg = AppColors.primaryDark; }
    if (state == true) { bg = AppColors.success; border = AppColors.success; }
    if (state == false) { bg = AppColors.error; border = AppColors.error; }
    if (state != null) fg = AppColors.textOnPrimary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: Sp.sm, horizontal: Sp.lg),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(9999),
            border: Border.all(color: border, width: 1.5), boxShadow: toyShadow(shadow, 3)),
        child: Text(w, style: Fonts.hindi(20, color: fg)),
      ),
    );
  }
}
