import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/reading_data.dart';
import '../../services/speech_service.dart';
import '../../store/app_store.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../../widgets/common.dart';
import '../../widgets/quiz_common.dart';
import '../../util/num_ext.dart';

class _Placed {
  final String letter; final int originalIndex;
  _Placed(this.letter, this.originalIndex);
}

/// WordBuilderScreen.tsx — assemble syllables into the word.
class WordBuilderScreen extends StatefulWidget {
  final Map<String, dynamic> params;
  const WordBuilderScreen({super.key, this.params = const {}});
  @override
  State<WordBuilderScreen> createState() => _WordBuilderScreenState();
}

class _WordBuilderScreenState extends State<WordBuilderScreen> with SingleTickerProviderStateMixin {
  int wordIdx = 0, score = 0, hints = 2, correctAnswers = 0;
  List<_Placed?> placed = [];
  List<String> available = [];
  bool showResults = false, confetti = false;
  String? feedback;
  final List<Timer> _timers = [];
  late final AnimationController _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));

  int get total => wordBuilderData.length;
  Map get word => wordBuilderData[wordIdx.clampI(0, total - 1)] as Map;
  List<String> get letters => (word['letters'] as List).cast<String>();

  @override
  void initState() { super.initState(); _init(); }

  @override
  void dispose() { for (final t in _timers) { t.cancel(); } _shake.dispose(); super.dispose(); }

  void _later(int ms, VoidCallback f) => _timers.add(Timer(Duration(milliseconds: ms), () { if (mounted) f(); }));

  void _init() {
    placed = List<_Placed?>.filled(letters.length, null);
    available = shuffled(letters);
    feedback = null;
  }

  void _tap(String letter, int index) {
    if (feedback != null) return;
    final isPlaced = placed.any((p) => p != null && p.letter == letter && p.originalIndex == index);
    if (isPlaced) {
      setState(() {
        placed = placed.map((p) => p != null && p.letter == letter && p.originalIndex == index ? null : p).toList();
        available = [...available, letter];
      });
    } else {
      final empty = placed.indexWhere((p) => p == null);
      if (empty != -1) {
        final np = List<_Placed?>.from(placed);
        np[empty] = _Placed(letter, index);
        setState(() {
          placed = np;
          available = available.where((l) => l != letter).toList();
        });
        if (empty == placed.length - 1) _check(np);
      }
    }
  }

  void _check(List<_Placed?> pl) {
    final built = pl.map((p) => p?.letter ?? '').join();
    final correct = letters.join();
    if (built == correct) {
      setState(() { feedback = 'correct'; confetti = true; });
      speakHindi(word['word']);
      final idxAtCheck = wordIdx;
      _later(1500, () {
        setState(() {
          confetti = false;
          if (idxAtCheck == total - 1) {
            score++; correctAnswers++; showResults = true;
          } else {
            score++; correctAnswers++; wordIdx = idxAtCheck + 1; _init();
          }
          feedback = null;
        });
        final aId = widget.params['activityId'], lvl = widget.params['levelNumber'];
        if (showResults && aId is String && lvl is int) context.read<AppStore>().completeActivityLevel(aId, lvl);
      });
    } else {
      setState(() => feedback = 'incorrect');
      _shake.forward(from: 0);
      _later(1000, () => setState(() {
            placed = List<_Placed?>.filled(letters.length, null);
            available = shuffled(letters);
            feedback = null;
          }));
    }
  }

  void _hint() {
    if (hints == 0) return;
    for (int i = 0; i < placed.length; i++) {
      if (placed[i] == null) {
        final letter = letters[i];
        final np = List<_Placed?>.from(placed);
        np[i] = _Placed(letter, i);
        setState(() {
          placed = np;
          available = available.where((l) => l != letter).toList();
          hints--;
        });
        if (i == placed.length - 1) _check(np);
        break;
      }
    }
  }

  void _playAgain() => setState(() {
        wordIdx = 0; score = 0; hints = 2; correctAnswers = 0; showResults = false; confetti = false; _init();
      });

  @override
  Widget build(BuildContext context) {
    if (showResults) return _results();
    final progress = (wordIdx + 1) / total;
    return ScreenScaffold(child: Stack(children: [
      Column(children: [
        HeaderBar(title: 'Word Builder', onBack: () => Navigator.of(context).maybePop()),
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.md, Sp.lg, Sp.lg),
          child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child: Column(children: [
            Padding(padding: const EdgeInsets.only(bottom: Sp.lg), child: Column(children: [
              ClipRRect(borderRadius: BorderRadius.circular(9999), child: Container(
                  height: 10, color: AppColors.border, alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(widthFactor: progress, child: Container(color: AppColors.success)))),
              const SizedBox(height: Sp.sm),
              Text('${wordIdx + 1} / $total', style: Fonts.body(12, w: FontWeight.w700, color: AppColors.textSecondary)),
            ])),
            Padding(padding: const EdgeInsets.only(bottom: Sp.lg),
                child: Text(word['meaning'], textAlign: TextAlign.center, style: Fonts.display(24, color: AppColors.textPrimary))),
            Container(
              width: double.infinity, margin: const EdgeInsets.only(bottom: Sp.xl),
              padding: const EdgeInsets.symmetric(vertical: Sp.lg, horizontal: Sp.md),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(Rad.xl),
                  border: Border.all(color: AppColors.border), boxShadow: softShadow(AppColors.primary)),
              child: AnimatedBuilder(
                animation: _shake,
                builder: (_, child) {
                  final dx = feedback == 'incorrect' ? math.sin(_shake.value * math.pi * 3) * 10 * (1 - _shake.value) : 0.0;
                  return Transform.translate(offset: Offset(dx, 0), child: child);
                },
                child: Wrap(spacing: Sp.md, runSpacing: Sp.md, alignment: WrapAlignment.center, children: [
                  for (int i = 0; i < placed.length; i++) _slot(placed[i]),
                ]),
              ),
            ),
            if (feedback == 'incorrect')
              Padding(padding: const EdgeInsets.only(bottom: Sp.md),
                  child: Text('Try again!', textAlign: TextAlign.center, style: Fonts.body(14, w: FontWeight.w700, color: AppColors.error))),
            Padding(padding: const EdgeInsets.only(bottom: Sp.lg), child: GestureDetector(
              onTap: (hints == 0 || feedback != null) ? null : _hint,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: Sp.sm, horizontal: Sp.lg),
                decoration: BoxDecoration(
                  color: hints > 0 ? AppColors.surface : AppColors.border, borderRadius: BorderRadius.circular(9999),
                  border: Border.all(color: hints > 0 ? AppColors.primary : AppColors.border, width: 2),
                  boxShadow: hints > 0 ? toyShadow(AppColors.toyShadowColor, 3) : null),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.lightbulb, size: 18, color: hints > 0 ? AppColors.primary : AppColors.textSecondary),
                  const SizedBox(width: Sp.xs),
                  Text('Hint ($hints)', style: Fonts.body(14, w: FontWeight.w700, color: hints > 0 ? AppColors.primary : AppColors.textSecondary)),
                ]),
              ),
            )),
            Padding(padding: const EdgeInsets.only(bottom: Sp.lg), child: Wrap(spacing: Sp.md, runSpacing: Sp.md, alignment: WrapAlignment.center, children: [
              for (int i = 0; i < available.length; i++) _pill(available[i], i),
            ])),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.star, size: 24, color: AppColors.starGold), const SizedBox(width: Sp.sm),
              Text('$score', style: Fonts.display(22, color: AppColors.textPrimary)),
            ]),
          ]))),
        )),
      ]),
      Positioned.fill(child: Confetti(visible: confetti, onComplete: () => setState(() => confetti = false))),
    ]));
  }

  Widget _slot(_Placed? p) => DashedBorder(
        radius: Rad.lg, color: p != null ? Colors.transparent : AppColors.primaryLight,
        child: Container(
          width: 60, height: 68, alignment: Alignment.center,
          decoration: BoxDecoration(color: p != null ? AppColors.primary : AppColors.background, borderRadius: BorderRadius.circular(Rad.lg),
              boxShadow: p != null ? toyShadow(AppColors.primaryDark, 4) : null),
          child: p == null ? null : GestureDetector(
            onTap: () => _tap(p.letter, p.originalIndex),
            child: Text(p.letter, style: Fonts.hindi(32, color: AppColors.textOnPrimary)),
          ),
        ),
      );

  Widget _pill(String letter, int index) {
    final isPlaced = placed.any((p) => p != null && p.letter == letter);
    return GestureDetector(
      onTap: (feedback != null || isPlaced) ? null : () => _tap(letter, index),
      child: Container(
        width: 60, height: 60, alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isPlaced ? AppColors.border : AppColors.surface, shape: BoxShape.circle,
          border: Border.all(color: isPlaced ? AppColors.border : AppColors.primaryLight, width: 2),
          boxShadow: !isPlaced ? toyShadow(AppColors.toyShadowColor, 4) : null),
        child: Text(letter, style: Fonts.hindi(30, color: isPlaced ? AppColors.textSecondary : AppColors.textPrimary)),
      ),
    );
  }

  Widget _results() {
    final starRating = (correctAnswers / total * 5).round();
    return ScreenScaffold(child: Column(children: [
      HeaderBar(title: 'Results', onBack: () => Navigator.of(context).maybePop()),
      Expanded(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(Sp.lg), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 160, height: 160, margin: const EdgeInsets.only(bottom: Sp.xl),
          decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle, boxShadow: softShadow(AppColors.primary)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('$correctAnswers/$total', style: Fonts.display(48, color: AppColors.textOnPrimary)),
            const SizedBox(height: Sp.xs),
            Text('Correct', style: Fonts.body(14, w: FontWeight.w600, color: AppColors.textOnPrimary)),
          ]),
        ),
        Padding(padding: const EdgeInsets.only(bottom: Sp.xl), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (int i = 0; i < 5; i++) Padding(padding: const EdgeInsets.symmetric(horizontal: Sp.sm),
              child: Icon(i < starRating ? Icons.star : Icons.star_border, size: 40, color: AppColors.starGold)),
        ])),
        GestureDetector(
          onTap: _playAgain,
          child: Container(
            margin: const EdgeInsets.only(top: Sp.lg, bottom: Sp.md),
            padding: const EdgeInsets.symmetric(vertical: Sp.md, horizontal: Sp.xl),
            decoration: BoxDecoration(gradient: toneGradient(AppColors.primary), borderRadius: BorderRadius.circular(9999), boxShadow: toyShadow(AppColors.primaryDark, 6)),
            child: Text('Play Again', textAlign: TextAlign.center, style: Fonts.body(16, w: FontWeight.w800, color: AppColors.textOnPrimary)),
          ),
        ),
        GestureDetector(
          onTap: () => Navigator.of(context).maybePop(),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: Sp.md, horizontal: Sp.xl),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(9999), border: Border.all(color: AppColors.primary, width: 2)),
            child: Text('Back to Menu', textAlign: TextAlign.center, style: Fonts.body(16, w: FontWeight.w700, color: AppColors.primary)),
          ),
        ),
      ])))),
    ]));
  }
}
