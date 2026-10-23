import 'dart:async';
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

/// FillBlankScreen.tsx — pick the word that completes the sentence.
class FillBlankScreen extends StatefulWidget {
  final Map<String, dynamic> params;
  const FillBlankScreen({super.key, this.params = const {}});
  @override
  State<FillBlankScreen> createState() => _FillBlankScreenState();
}

class _FillBlankScreenState extends State<FillBlankScreen> {
  int idx = 0, correctAnswers = 0;
  Map<String, String> status = {};
  String? selected;
  ({int score, int total, int stars})? results;
  bool confetti = false;
  Timer? _t;

  int get total => fillBlankData.length;
  Map get ex => fillBlankData[idx.clampI(0, total - 1)] as Map;

  @override
  void dispose() { _t?.cancel(); super.dispose(); }

  void _press(String option) {
    if (selected != null) return;
    final correctAtTap = correctAnswers; // the original's timeout closure sees this (pre-increment) value
    final idxAtTap = idx;
    setState(() => selected = option);
    final ok = option == ex['blank'];
    if (ok) {
      setState(() { status = {option: 'correct'}; correctAnswers++; confetti = true; });
      speakHindi(ex['sentence']);
      _t = Timer(const Duration(milliseconds: 1500), () => _advance(correctAtTap, idxAtTap));
    } else {
      setState(() => status = {option: 'incorrect', ex['blank']: 'correct-answer'});
      _t = Timer(const Duration(milliseconds: 2000), () => _advance(correctAtTap, idxAtTap));
    }
  }

  void _advance(int correctSeen, int idxSeen) {
    if (!mounted) return;
    setState(() {
      confetti = false; selected = null; status = {};
      if (idxSeen < total - 1) { idx = idxSeen + 1; }
      else { results = (score: correctSeen, total: total, stars: (correctSeen / total * 5).ceil()); }
    });
    final aId = widget.params['activityId'], lvl = widget.params['levelNumber'];
    if (results != null && correctSeen * 2 >= total && aId is String && lvl is int) context.read<AppStore>().completeActivityLevel(aId, lvl);
  }

  void _playAgain() => setState(() { idx = 0; status = {}; selected = null; correctAnswers = 0; results = null; });

  @override
  Widget build(BuildContext context) {
    final accents = [Palette.light.purple, Palette.light.green, Palette.light.sky, Palette.light.pink];
    if (results != null) {
      final r = results!;
      return ScreenScaffold(child: Column(children: [
        HeaderBar(title: 'Results', onBack: () => Navigator.of(context).maybePop()),
        Expanded(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(Sp.md), child: Container(
          width: double.infinity, padding: const EdgeInsets.all(Sp.xl),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(Rad.xl2),
              border: Border.all(color: AppColors.border), boxShadow: softShadow(AppColors.primary)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Excellent Work!', textAlign: TextAlign.center, style: Fonts.display(32)),
            const SizedBox(height: Sp.lg),
            Text('${r.score}', style: Fonts.display(64, color: AppColors.primary, height: 1.2)),
            Padding(padding: const EdgeInsets.only(top: Sp.xs, bottom: Sp.lg),
                child: Text('out of ${r.total}', style: Fonts.body(16, w: FontWeight.w500, color: AppColors.textSecondary))),
            Padding(padding: const EdgeInsets.only(bottom: Sp.xl), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (int i = 0; i < 5; i++) Padding(padding: const EdgeInsets.symmetric(horizontal: Sp.xs + 4),
                  child: Icon(i < r.stars ? Icons.star : Icons.star_border, size: 40, color: AppColors.starGold)),
            ])),
            GestureDetector(
              onTap: _playAgain,
              child: Container(
                width: double.infinity, padding: const EdgeInsets.symmetric(vertical: Sp.md),
                decoration: BoxDecoration(gradient: toneGradient(AppColors.primary), borderRadius: BorderRadius.circular(9999), boxShadow: toyShadow(AppColors.primaryDark, 6)),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.play_arrow, size: 20, color: Colors.white), const SizedBox(width: Sp.sm),
                  Text('Play Again', style: Fonts.body(18, w: FontWeight.w800, color: AppColors.textOnPrimary)),
                ]),
              ),
            ),
          ]),
        )))),
      ]));
    }

    final parts = (ex['sentence'] as String).split('___');
    return ScreenScaffold(child: Stack(children: [
      Column(children: [
        HeaderBar(title: 'Fill in the Blank', onBack: () => Navigator.of(context).maybePop()),
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.lg),
          child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: Column(children: [
            ClipRRect(borderRadius: BorderRadius.circular(9999), child: Container(
                height: 10, color: AppColors.border, alignment: Alignment.centerLeft,
                child: FractionallySizedBox(widthFactor: (idx + 1) / total,
                    child: Container(decoration: BoxDecoration(gradient: toneGradient(AppColors.success), borderRadius: BorderRadius.circular(9999)))))),
            const SizedBox(height: Sp.md),
            Padding(padding: const EdgeInsets.only(bottom: Sp.lg),
                child: Text('${idx + 1} of $total', style: Fonts.body(14, w: FontWeight.w700, color: AppColors.textSecondary))),
            Padding(padding: const EdgeInsets.only(bottom: Sp.md), child: Text(ex['english'], textAlign: TextAlign.center,
                style: Fonts.body(14, w: FontWeight.w500, color: AppColors.textSecondary).copyWith(fontStyle: FontStyle.italic))),
            Container(
              key: ValueKey(idx), width: double.infinity, padding: const EdgeInsets.all(Sp.lg), margin: const EdgeInsets.only(bottom: Sp.lg),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(Rad.xl2),
                  border: Border.all(color: AppColors.border), boxShadow: toyShadow(AppColors.toyShadowColor, 6)),
              child: Column(children: [
                Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  for (int i = 0; i < parts.length; i++) ...[
                    Text(parts[i], style: Fonts.hindi(26, color: AppColors.textPrimary, height: 36 / 26)),
                    if (i < parts.length - 1) _blank(),
                  ],
                ]),
                if (selected != null) Padding(padding: const EdgeInsets.only(top: Sp.md), child: GestureDetector(
                  onTap: () => speakHindi(ex['sentence']),
                  child: Container(padding: const EdgeInsets.all(Sp.sm),
                      decoration: BoxDecoration(color: AppColors.background, shape: BoxShape.circle, border: Border.all(color: AppColors.border)),
                      child: const Icon(Icons.volume_up, size: 24, color: AppColors.primary)),
                )),
              ]),
            ),
            Wrap(spacing: Sp.sm, runSpacing: Sp.sm, alignment: WrapAlignment.center, children: [
              for (int i = 0; i < (ex['options'] as List).length; i++) _option((ex['options'] as List)[i] as String, accents[i % accents.length]),
            ]),
          ]))),
        )),
      ]),
      Positioned.fill(child: Confetti(visible: confetti, onComplete: () => setState(() => confetti = false))),
    ]));
  }

  Widget _blank() => Container(
        constraints: const BoxConstraints(minWidth: 90), height: 44,
        margin: const EdgeInsets.symmetric(horizontal: Sp.xs), padding: const EdgeInsets.symmetric(horizontal: Sp.sm),
        alignment: Alignment.center,
        decoration: selected != null
            ? BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(Rad.lg), boxShadow: toyShadow(AppColors.toyShadowColor, 4))
            : const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.primary, width: 3))),
        child: selected == null ? null : Text(selected!, style: Fonts.hindi(20, color: AppColors.textOnPrimary)),
      );

  Widget _option(String option, Color accent) {
    final st = status[option] ?? 'default';
    final neutral = st == 'default';
    Color bg = AppColors.surface, border = AppColors.primary, fg = AppColors.textPrimary;
    List<BoxShadow>? shadow;
    if (neutral) { bg = accent; border = accent; fg = AppColors.textOnPrimary; shadow = toyShadow(AppColors.toyShadowColor, 4); }
    if (st == 'correct' || st == 'correct-answer') { bg = AppColors.success; border = AppColors.success; fg = AppColors.textOnPrimary; }
    if (st == 'incorrect') { bg = AppColors.error; border = AppColors.error; fg = AppColors.textOnPrimary; }
    return GestureDetector(
      onTap: selected != null ? null : () => _press(option),
      child: Container(
        constraints: const BoxConstraints(minWidth: 84),
        padding: const EdgeInsets.symmetric(horizontal: Sp.lg, vertical: Sp.md),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(9999), border: Border.all(color: border, width: 2), boxShadow: shadow),
        child: Text(option, style: Fonts.hindi(20, color: fg)),
      ),
    );
  }
}
