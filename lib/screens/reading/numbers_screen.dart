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

/// NumbersScreen.tsx — Hindi numerals 0–20 with a 1–10 quiz.
/// Behaviours kept from the original: quiz options reshuffle on every state
/// change, and the quiz stays on question 10 after it is answered.
class NumbersScreen extends StatefulWidget {
  final Map<String, dynamic> params;
  const NumbersScreen({super.key, this.params = const {}});
  @override
  State<NumbersScreen> createState() => _NumbersScreenState();
}

class _NumbersScreenState extends State<NumbersScreen> {
  bool quizMode = false;
  Map? selectedNum;
  late final List quizItems = shuffled(hindiNumbersData.sublist(1, 11));
  int quizIndex = 0, quizScore = 0;
  int? quizAnswer;
  int _version = 0, _optVersion = -1;
  List<int> _options = [];
  Timer? _t;

  @override
  void dispose() { _t?.cancel(); super.dispose(); }

  List<int> _optionsFor(int correct) {
    if (_optVersion != _version) {
      final wrongs = shuffled(hindiNumbersData.where((n) => n['english'] != correct && n['english'] >= 1 && n['english'] <= 10))
          .take(3).map<int>((n) => n['english'] as int).toList();
      _options = shuffled<int>([correct, ...wrongs]);
      _optVersion = _version;
    }
    return _options;
  }

  void _answer(int a) {
    if (quizAnswer != null) return;
    final idxAtTap = quizIndex;
    final item = quizItems[quizIndex] as Map;
    setState(() {
      _version++;
      quizAnswer = a;
      if (a == item['english']) quizScore++;
    });
    if (a == item['english']) speakHindi(item['hindiWord'], rate: 0.6);
    _t = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      if (idxAtTap < quizItems.length - 1) setState(() { _version++; quizIndex = idxAtTap + 1; quizAnswer = null; });
      final aId = widget.params['activityId'], lvl = widget.params['levelNumber'];
      if (idxAtTap == quizItems.length - 1 && quizScore * 2 >= quizItems.length && aId is String && lvl is int) {
        context.read<AppStore>().completeActivityLevel(aId, lvl);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(child: Column(children: [
      HeaderBar(title: 'Hindi Numbers', subtitle: 'हिन्दी अंक', onBack: () => Navigator.of(context).maybePop()),
      Container(
        margin: const EdgeInsets.fromLTRB(Sp.md, 0, Sp.md, Sp.md), padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(9999), border: Border.all(color: AppColors.border)),
        child: Row(children: [
          Expanded(child: _modeBtn('Learn', Icons.grid_view, !quizMode, () => setState(() => quizMode = false))),
          const SizedBox(width: 4),
          Expanded(child: _modeBtn('Quiz', Icons.help_outline, quizMode, () => setState(() => quizMode = true))),
        ]),
      ),
      Expanded(child: quizMode ? _quiz() : _grid()),
    ]));
  }

  Widget _modeBtn(String label, IconData ic, bool active, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: Sp.sm),
          decoration: BoxDecoration(color: active ? AppColors.primary : null, borderRadius: BorderRadius.circular(9999),
              boxShadow: active ? toyShadow(AppColors.primaryDark, 4) : null),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(ic, size: 16, color: active ? AppColors.textOnPrimary : AppColors.textSecondary), const SizedBox(width: Sp.xs),
            Text(label, style: Fonts.body(14, w: active ? FontWeight.w800 : FontWeight.w700, color: active ? AppColors.textOnPrimary : AppColors.textSecondary)),
          ]),
        ),
      );

  Widget _grid() {
    final accents = <(Color, Color)>[
      (Palette.light.purple, AppColors.textOnPrimary), (Palette.light.green, AppColors.textOnPrimary),
      (Palette.light.sky, AppColors.textOnPrimary), (Palette.light.pink, AppColors.textOnPrimary),
      (Palette.light.sunny, Palette.light.sunnyForeground),
    ];
    return screenScroll(
      padding: const EdgeInsets.all(Sp.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (selectedNum != null) Container(
          width: double.infinity, margin: const EdgeInsets.only(bottom: Sp.md), padding: const EdgeInsets.all(Sp.lg),
          decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(Rad.xl2), boxShadow: softShadow(AppColors.primary)),
          child: Row(children: [
            Text(selectedNum!['digit'], style: Fonts.hindi(48, color: AppColors.textOnPrimary, height: 56 / 48)),
            const SizedBox(width: Sp.md),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(selectedNum!['hindiWord'], style: Fonts.hindi(22, color: AppColors.textOnPrimary, height: 30 / 22)),
              Opacity(opacity: 0.85, child: Text(selectedNum!['romanized'], style: Fonts.body(12, w: FontWeight.w500, color: AppColors.textOnPrimary))),
              Text('= ${selectedNum!['english']}', style: Fonts.body(16, w: FontWeight.w800, color: AppColors.textOnPrimary)),
            ])),
            const SizedBox(width: Sp.md),
            GestureDetector(
              onTap: () => speakHindi(selectedNum!['hindiWord'], rate: 0.5),
              child: Container(width: 48, height: 48,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.22), shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.35))),
                  child: const Icon(Icons.volume_up, size: 22, color: AppColors.textOnPrimary)),
            ),
          ]),
        ),
        Wrap(spacing: Sp.sm, runSpacing: Sp.sm, children: [
          for (int i = 0; i < hindiNumbersData.length; i++) _tile(hindiNumbersData[i] as Map, accents[i % accents.length]),
        ]),
        const SizedBox(height: Sp.xxl * 2),
      ]),
    );
  }

  Widget _tile(Map num, (Color, Color) accent) {
    final active = selectedNum != null && selectedNum!['english'] == num['english'];
    return GestureDetector(
      onTap: () {
        setState(() => selectedNum = num);
        speakHindi(num['hindiWord'], rate: 0.6);
      },
      child: Container(
        width: 72, height: 80, alignment: Alignment.center,
        decoration: BoxDecoration(color: accent.$1, borderRadius: BorderRadius.circular(Rad.xl),
            border: Border.all(color: active ? AppColors.textPrimary : accent.$1, width: active ? 2 : 1),
            boxShadow: toyShadow(AppColors.toyShadowColor, 4)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(num['digit'], style: Fonts.hindi(28, color: accent.$2, height: 34 / 28)),
          Opacity(opacity: 0.85, child: Text('${num['english']}', style: Fonts.body(12, w: FontWeight.w800, color: accent.$2))),
        ]),
      ),
    );
  }

  Widget _quiz() {
    if (quizIndex >= quizItems.length) {
      return Center(child: Padding(padding: const EdgeInsets.all(Sp.xl), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(quizScore >= 8 ? '🎉' : '💪', style: const TextStyle(fontSize: 56)),
        const SizedBox(height: Sp.md),
        Text('Numbers Quiz Done!', style: Fonts.display(24, w: FontWeight.w400)),
        const SizedBox(height: Sp.sm),
        Text('$quizScore/${quizItems.length} correct', style: Fonts.display(20, color: AppColors.primaryDark, w: FontWeight.w700)),
        const SizedBox(height: Sp.xl),
        GestureDetector(
          onTap: () => setState(() { quizIndex = 0; quizAnswer = null; quizScore = 0; }),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: Sp.xl, vertical: Sp.md),
            decoration: BoxDecoration(gradient: toneGradient(AppColors.primary), borderRadius: BorderRadius.circular(9999), boxShadow: toyShadow(AppColors.primaryDark, 6)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.refresh, size: 18, color: AppColors.textOnPrimary), const SizedBox(width: Sp.sm),
              Text('Try Again', style: Fonts.body(16, w: FontWeight.w800, color: AppColors.textOnPrimary)),
            ]),
          ),
        ),
      ])));
    }
    final item = quizItems[quizIndex] as Map;
    final correct = item['english'] as int;
    final options = _optionsFor(correct);
    return Center(child: SingleChildScrollView(padding: const EdgeInsets.all(Sp.md), child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Container(
        key: ValueKey(quizIndex), width: double.infinity, padding: const EdgeInsets.all(Sp.xl),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(Rad.xl2),
            border: Border.all(color: AppColors.border), boxShadow: toyShadow(AppColors.toyShadowColor, 6)),
        child: Column(children: [
          Text('Question ${quizIndex + 1}/${quizItems.length}', style: Fonts.body(12, w: FontWeight.w700, color: AppColors.textSecondary)),
          const SizedBox(height: Sp.md),
          Text('What number is this?', style: Fonts.body(16, color: AppColors.textSecondary)),
          const SizedBox(height: Sp.sm),
          Text(item['digit'], style: Fonts.hindi(72, color: AppColors.primaryDark, height: 82 / 72)),
          Padding(padding: const EdgeInsets.only(bottom: Sp.xl), child: Text(item['hindiWord'], style: Fonts.hindi(26, color: AppColors.textPrimary, height: 34 / 26))),
          Wrap(spacing: Sp.md, runSpacing: Sp.md, alignment: WrapAlignment.center, children: [
            for (final opt in options) _quizOpt(opt, correct),
          ]),
        ]),
      ),
    )));
  }

  Widget _quizOpt(int opt, int correct) {
    Color bg = AppColors.surface, border = AppColors.border;
    if (quizAnswer != null) {
      if (opt == correct) { bg = AppColors.success.withOpacity(0.125); border = AppColors.success; }
      else if (quizAnswer == opt) { bg = AppColors.error.withOpacity(0.125); border = AppColors.error; }
    }
    return GestureDetector(
      onTap: quizAnswer != null ? null : () => _answer(opt),
      child: Container(
        width: 70, height: 70, alignment: Alignment.center,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Rad.xl),
            border: Border.all(color: border, width: 2), boxShadow: toyShadow(AppColors.toyShadowColor, 3)),
        child: Text('$opt', style: Fonts.display(24, color: AppColors.textPrimary)),
      ),
    );
  }
}
