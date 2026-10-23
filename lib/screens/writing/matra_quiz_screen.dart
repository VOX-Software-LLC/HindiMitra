import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/speech_service.dart';
import '../../store/app_store.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../../widgets/common.dart';

class _Q {
  final String consonant, targetMatra, target; final List<String> options;
  const _Q(this.consonant, this.targetMatra, this.target, this.options);
}

const _quiz = [
  _Q('क', 'ा', 'का', ['ा', 'ि', 'ू', 'े']),
  _Q('ग', 'ि', 'गि', ['ा', 'ि', 'ो', 'ै']),
  _Q('प', 'ू', 'पू', ['ु', 'ू', 'ा', 'ी']),
  _Q('म', 'े', 'मे', ['ै', 'ो', 'े', 'ा']),
  _Q('त', 'ो', 'तो', ['ो', 'ौ', 'ु', 'ी']),
  _Q('र', 'ी', 'री', ['ि', 'ा', 'ी', 'े']),
  _Q('न', 'ा', 'ना', ['ा', 'ि', 'े', 'ू']),
  _Q('स', 'ु', 'सु', ['ू', 'ा', 'ु', 'ो']),
  _Q('ल', 'ै', 'लै', ['े', 'ै', 'ी', 'ा']),
  _Q('च', 'ौ', 'चौ', ['ो', 'ा', 'ौ', 'ू']),
  _Q('ध', 'ी', 'धी', ['ी', 'ि', 'ा', 'े']),
  _Q('ब', 'ो', 'बो', ['ा', 'ो', 'ौ', 'ू']),
];

class MatraQuizScreen extends StatefulWidget {
  final Map<String, dynamic> params;
  const MatraQuizScreen({super.key, this.params = const {}});
  @override
  State<MatraQuizScreen> createState() => _MatraQuizScreenState();
}

class _MatraQuizScreenState extends State<MatraQuizScreen> with SingleTickerProviderStateMixin {
  int current = 0, score = 0;
  bool answered = false, showResults = false;
  Map<int, String> states = {};
  late final AnimationController shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
  Timer? _t;

  @override
  void dispose() { _t?.cancel(); shake.dispose(); super.dispose(); }

  Future<void> _select(String matra, int index) async {
    if (answered) return;
    final q = _quiz[current];
    setState(() => answered = true);
    final ok = matra == q.targetMatra;
    if (ok) {
      setState(() { states = {index: 'correct'}; score++; });
      await speakHindi(q.target);
      _t = Timer(const Duration(milliseconds: 1000), _next);
    } else {
      final ci = q.options.indexOf(q.targetMatra);
      setState(() => states = {index: 'incorrect', ci: 'correct'});
      shake.forward(from: 0);
      await speakHindi(q.target);
      _t = Timer(const Duration(milliseconds: 1500), _next);
    }
  }

  void _next() {
    if (!mounted) return;
    setState(() { states = {}; answered = false; });
    if (current + 1 < _quiz.length) {
      setState(() => current++);
    } else {
      setState(() => showResults = true);
      final aId = widget.params['activityId'], lvl = widget.params['levelNumber'];
      if (stars > 0 && aId is String && lvl is int) context.read<AppStore>().completeActivityLevel(aId, lvl);
    }
  }

  int get stars {
    final p = score / _quiz.length * 100;
    return p >= 90 ? 3 : p >= 70 ? 2 : p >= 50 ? 1 : 0;
  }

  void _back() {
    context.read<AppStore>().addPoints(score * 10);
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: showResults ? _results() : _quizBody()),
    );
  }

  Widget _results() {
    final pct = (score / _quiz.length * 100).round();
    return Column(children: [
      HeaderBar(title: 'Matra Quiz Results', onBack: _back),
      Expanded(child: Center(child: SingleChildScrollView(
        padding: const EdgeInsets.all(Sp.lg),
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child: PopIn(child: ToyCard(
          radius: Rad.xl2, shadow: 6, padding: const EdgeInsets.all(Sp.xl),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (int i = 0; i < 3; i++) Padding(padding: const EdgeInsets.symmetric(horizontal: Sp.sm),
                  child: Icon(i < stars ? Icons.star : Icons.star_border, size: 48,
                      color: i < stars ? AppColors.starGold : AppColors.starEmpty)),
            ]),
            const SizedBox(height: Sp.lg),
            Text('$score', style: Fonts.display(64, color: AppColors.primary)),
            Text('out of ${_quiz.length}', style: Fonts.body(16, w: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: Sp.lg),
            ClipRRect(borderRadius: BorderRadius.circular(9999), child: Container(
                height: 14, color: AppColors.border, alignment: Alignment.centerLeft,
                child: FractionallySizedBox(widthFactor: pct / 100, child: Container(color: AppColors.success)))),
            const SizedBox(height: Sp.md),
            Text('$pct%', style: Fonts.display(22)),
            const SizedBox(height: Sp.lg),
            Text(pct >= 90 ? 'Outstanding! You mastered the matras!'
                : pct >= 70 ? 'Great job! Keep practicing!'
                : pct >= 50 ? 'Good effort! More practice needed.' : 'Keep learning! Try again soon.',
                textAlign: TextAlign.center, style: Fonts.body(16, w: FontWeight.w500, color: AppColors.textSecondary)),
            const SizedBox(height: Sp.xl),
            _bigBtn('Play Again', Icons.refresh, true, () => setState(() {
              current = 0; score = 0; answered = false; showResults = false; states = {};
            })),
            const SizedBox(height: Sp.md),
            _bigBtn('Back to Menu', null, false, _back),
          ]),
        ))),
      ))),
    ]);
  }

  Widget _bigBtn(String t, IconData? icon, bool filled, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity, padding: const EdgeInsets.symmetric(vertical: Sp.md, horizontal: Sp.lg),
          decoration: BoxDecoration(color: filled ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(9999),
              border: filled ? null : Border.all(color: AppColors.primary, width: 2),
              boxShadow: filled ? toyShadow(AppColors.primaryDark, 6) : null),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (icon != null) ...[Icon(icon, size: 20, color: AppColors.surface), const SizedBox(width: Sp.sm)],
            Text(t, style: Fonts.body(16, w: FontWeight.w800, color: filled ? AppColors.textOnPrimary : AppColors.primary)),
          ]),
        ),
      );

  Widget _quizBody() {
    final q = _quiz[current];
    final progress = (current + 1) / _quiz.length;
    return Column(children: [
      HeaderBar(title: 'Matra Quiz', onBack: _back),
      Expanded(child: Center(child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.md, Sp.lg, Sp.xl),
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child: Column(children: [
          ClipRRect(borderRadius: BorderRadius.circular(9999), child: Container(
              height: 12, color: AppColors.border, alignment: Alignment.centerLeft,
              child: FractionallySizedBox(widthFactor: progress, child: Container(color: AppColors.success)))),
          const SizedBox(height: Sp.sm),
          Text('${current + 1} / ${_quiz.length}', style: Fonts.body(16, w: FontWeight.w700, color: AppColors.textSecondary)),
          const SizedBox(height: Sp.xl),
          Text('TAP TO HEAR:', style: Fonts.body(12, w: FontWeight.w800, color: AppColors.textSecondary).copyWith(letterSpacing: 1)),
          const SizedBox(height: Sp.sm),
          Container(
            padding: const EdgeInsets.all(Sp.lg),
            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(Rad.xl2),
                boxShadow: softShadow(AppColors.primary)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(q.target, style: Fonts.hindi(56, color: AppColors.textOnPrimary)),
              const SizedBox(width: Sp.lg),
              GestureDetector(
                onTap: () => speakHindi(q.target),
                child: Container(padding: const EdgeInsets.all(Sp.md),
                    decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
                    child: const Icon(Icons.volume_up, size: 24, color: AppColors.primary)),
              ),
            ]),
          ),
          const SizedBox(height: Sp.xl),
          Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.center, children: [
            Text(q.consonant, style: Fonts.hindi(72)),
            const SizedBox(width: Sp.md),
            Padding(padding: const EdgeInsets.only(top: Sp.sm), child: Text('+', style: Fonts.display(40, color: AppColors.primary))),
          ]),
          const SizedBox(height: Sp.xl),
          AnimatedBuilder(
            animation: shake,
            builder: (_, child) => Transform.translate(
                offset: Offset(shake.isAnimating ? (shake.value < 0.5 ? -10 * (1 - shake.value * 2) : 10 * ((shake.value - 0.5) * 2) * (1 - shake.value)) : 0, 0),
                child: child),
            child: Wrap(alignment: WrapAlignment.center, spacing: Sp.lg, runSpacing: Sp.lg, children: [
              for (int i = 0; i < q.options.length; i++) _option(q.options[i], i),
            ]),
          ),
          if (answered) Padding(padding: const EdgeInsets.only(top: Sp.lg), child: Text(
              states.values.contains('incorrect') ? 'Not quite right. Try again!' : 'Correct! Well done!',
              style: Fonts.body(16, w: FontWeight.w800))),
        ])),
      ))),
    ]);
  }

  Widget _option(String m, int i) {
    final st = states[i] ?? 'neutral';
    Color bg = AppColors.surface, border = AppColors.border, shadow = AppColors.toyShadowColor;
    if (st == 'correct') { bg = AppColors.success; border = AppColors.success; shadow = const Color(0xFF3A9E6C); }
    if (st == 'incorrect') { bg = Palette.light.pink; border = Palette.light.pink; shadow = const Color(0xFFC24E76); }
    return GestureDetector(
      onTap: answered ? null : () => _select(m, i),
      child: Opacity(
        opacity: 1,
        child: Container(
          width: 84, height: 84, alignment: Alignment.center,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Rad.xl),
              border: Border.all(color: border), boxShadow: toyShadow(shadow, 4)),
          child: Text(m, style: Fonts.hindi(36)),
        ),
      ),
    );
  }
}
