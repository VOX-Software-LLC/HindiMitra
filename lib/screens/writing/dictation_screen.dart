import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models.dart';
import '../../services/feedback.dart';
import '../../services/speech_service.dart';
import '../../services/stroke_evaluator.dart';
import '../../store/app_store.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../../widgets/common.dart';
import '../../widgets/draw_canvas.dart';
import '../../util/num_ext.dart';

class DictationScreen extends StatefulWidget {
  final Map<String, dynamic> params;
  const DictationScreen({super.key, this.params = const {}});
  @override
  State<DictationScreen> createState() => _DictationScreenState();
}

class _DictationScreenState extends State<DictationScreen> {
  List<String> queue = [];
  int idx = 0, correct = 0;
  bool evaluated = false, sessionComplete = false;
  EvaluationResult? result;
  /// What the drawing matched best, when that isn't the dictated letter.
  String? lookedLike;
  /// Per-question outcome for the summary strip (letter id -> passed).
  final List<(String, bool)> history = [];
  final draw = DrawController();
  double size = 340;
  Timer? _speakTimer;

  double get _rate => widget.params['speed'] == 'fast' ? 1.0 : 0.8;

  List<String> _makeQueue() =>
      AppData.deck(AppData.poolIds(widget.params['pool'] as String?), (widget.params['count'] as int?) ?? 10);

  @override
  void initState() {
    super.initState();
    queue = _makeQueue();
    _speakCurrent();
  }

  @override
  void dispose() { _speakTimer?.cancel(); draw.dispose(); super.dispose(); }

  HindiLetter? get _letter => queue.isEmpty ? null : AppData.letterById(queue[min(idx, queue.length - 1)]);

  void _speakCurrent() {
    _speakTimer?.cancel();
    _speakTimer = Timer(const Duration(milliseconds: 350), () {
      if (!mounted || evaluated) return;
      final l = _letter;
      if (l != null) { speakHindi(l.character, rate: _rate); hapticLight(); }
    });
  }

  void _submit() {
    final l = _letter;
    if (draw.isEmpty || l == null) return;
    final r = evaluateStrokes(draw.strokes, l.id, size);
    final best = findBestMatchingLetter(draw.strokes, size);
    final ok = r.stars >= 2;
    setState(() {
      result = r; evaluated = true;
      lookedLike = best != null && best.letterId != l.id && best.result.accuracy > r.accuracy + 5 ? best.character : null;
      if (ok) correct++;
      history.add((l.id, ok));
    });
    draw.locked = true;
    ok ? hapticSuccess() : hapticMedium();
    final store = context.read<AppStore>();
    store.letterProgress.putIfAbsent(l.id, () => LetterProgress(letterId: l.id));
    store.recordAttempt(l.id, r.stars, accuracy: r.accuracy);
    // Say the right answer aloud so the sound and the shape go together.
    Timer(const Duration(milliseconds: 400), () { if (mounted) speakHindi(l.character, rate: 0.8); });
  }

  void _next() {
    if (idx < queue.length - 1) {
      setState(() { idx++; evaluated = false; result = null; lookedLike = null; });
      draw.locked = false; draw.clear();
      _speakCurrent();
    } else {
      setState(() => sessionComplete = true);
      final aId = widget.params['activityId'], lvl = widget.params['levelNumber'];
      if (correct / queue.length >= 0.4 && aId is String && lvl is int) context.read<AppStore>().completeActivityLevel(aId, lvl);
    }
  }

  void _retry() {
    draw.locked = false; draw.clear();
    setState(() {
      idx = 0; queue = _makeQueue(); evaluated = false; result = null; lookedLike = null;
      sessionComplete = false; correct = 0; history.clear();
    });
    _speakCurrent();
  }

  @override
  Widget build(BuildContext context) {
    size = (MediaQuery.of(context).size.width - Sp.md * 2).clampD(200.0, 350.0);
    Widget scaffold(Widget body) => Scaffold(backgroundColor: AppColors.background, body: SafeArea(bottom: false, child: body));
    if (sessionComplete) return scaffold(_complete());
    final letter = _letter;
    return scaffold(Column(children: [
      HeaderBar(title: 'Dictation Practice', subtitle: '${idx + 1}/${queue.length} letters',
          onBack: () => Navigator.of(context).maybePop()),
      Expanded(child: SingleChildScrollView(
        padding: const EdgeInsets.all(Sp.md),
        child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480), child: Column(children: [
          if (!evaluated) ...[
            ToyCard(padding: const EdgeInsets.symmetric(vertical: Sp.lg, horizontal: Sp.md), child: SizedBox(width: double.infinity, child: Column(children: [
              Text('Listen carefully, then write the letter', textAlign: TextAlign.center, style: Fonts.display(20)),
              const SizedBox(height: Sp.md),
              GestureDetector(
                onTap: () { if (letter != null) speakHindi(letter.character, rate: _rate); },
                child: Container(width: 96, height: 96,
                    decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle, boxShadow: toyShadow(AppColors.primaryDark, 6)),
                    child: const Icon(Icons.volume_up, size: 46, color: AppColors.textOnPrimary)),
              ),
              const SizedBox(height: Sp.sm),
              Text('Tap to hear again', style: Fonts.body(14, w: FontWeight.w700, color: AppColors.textSecondary)),
            ]))),
            const SizedBox(height: Sp.lg),
            SimpleCanvas(controller: draw, size: size),
            const SizedBox(height: Sp.md),
            AnimatedBuilder(animation: draw, builder: (_, __) => Row(children: [
              Expanded(child: ResultButton(label: 'Clear', icon: Icons.delete_outline, filled: false, color: AppColors.error,
                  onTap: draw.isEmpty ? null : draw.clear)),
              const SizedBox(width: Sp.md),
              Expanded(flex: 2, child: ResultButton(label: 'Submit', icon: Icons.check_circle, color: AppColors.success,
                  onTap: draw.isEmpty ? null : _submit)),
            ])),
          ] else
            PopIn(key: ValueKey('r$idx'), child: _result(letter)),
        ]))),
      )),
    ]));
  }

  Widget _result(HindiLetter? letter) {
    final r = result!;
    final ok = r.stars >= 2;
    return Column(children: [
      // The answer is always shown — big, with its sound and example word.
      Container(
        width: double.infinity, padding: const EdgeInsets.all(Sp.lg),
        decoration: BoxDecoration(
          color: (ok ? AppColors.success : AppColors.primary).withOpacity(0.08),
          borderRadius: BorderRadius.circular(Rad.xl),
          border: Border.all(color: ok ? AppColors.success : AppColors.primaryLight, width: 2)),
        child: Column(children: [
          Text('THE LETTER WAS', style: Fonts.body(12, w: FontWeight.w800, color: AppColors.textSecondary).copyWith(letterSpacing: 0.6)),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(letter?.character ?? '', style: Fonts.hindi(80, color: ok ? AppColors.success : AppColors.primaryDark, height: 1.25)),
            const SizedBox(width: Sp.md),
            SoftPill(icon: Icons.volume_up, onTap: () { if (letter != null) speakHindi(letter.character, rate: 0.8); }, size: 22),
          ]),
          Text('${letter?.romanized ?? ''}  ·  ${letter?.exampleWord ?? ''} (${letter?.exampleMeaning ?? ''})',
              textAlign: TextAlign.center, style: Fonts.body(15, w: FontWeight.w700)),
        ]),
      ),
      const SizedBox(height: Sp.md),
      Container(
        width: double.infinity, padding: const EdgeInsets.all(Sp.lg),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(Rad.xl),
            border: Border.all(color: AppColors.border), boxShadow: toyShadow(AppColors.toyShadowColor, 4)),
        child: Column(children: [
          Text(ok ? 'Great Job!' : 'Keep Trying!', style: Fonts.display(22, color: ok ? AppColors.success : AppColors.primaryDark)),
          StarRating(stars: r.stars, size: 36),
          Text('${r.accuracy}% match', style: Fonts.body(15, w: FontWeight.w800, color: AppColors.textSecondary)),
          if (lookedLike != null) Container(
            margin: const EdgeInsets.only(top: Sp.sm), padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.sm),
            decoration: BoxDecoration(color: AppColors.error.withOpacity(0.08), borderRadius: BorderRadius.circular(Rad.md)),
            child: Text.rich(TextSpan(style: Fonts.body(14, w: FontWeight.w700, color: AppColors.error), children: [
              const TextSpan(text: 'You wrote something closer to  '),
              TextSpan(text: lookedLike, style: Fonts.hindi(22, color: AppColors.error)),
            ])),
          ),
          const SizedBox(height: Sp.md),
          ScoreBreakdown(r),
        ]),
      ),
      const SizedBox(height: Sp.lg),
      ResultButton(label: idx < queue.length - 1 ? 'Next Letter' : 'Finish', icon: Icons.arrow_forward, onTap: _next),
    ]);
  }

  Widget _complete() {
    final accuracy = queue.isEmpty ? 0.0 : correct / queue.length * 100;
    final st = accuracy >= 80 ? 3 : accuracy >= 60 ? 2 : accuracy >= 40 ? 1 : 0;
    return Column(children: [
      HeaderBar(title: 'Dictation Complete', onBack: () => Navigator.of(context).maybePop()),
      Expanded(child: SessionCompleteCard(
        emoji: accuracy >= 80 ? '🎉' : accuracy >= 60 ? '👏' : '🎯',
        title: 'Session Complete!', stars: st,
        stats: [('$correct/${queue.length}', 'Correct'), ('${accuracy.round()}%', 'Accuracy')],
        // Every letter of the session, green if written correctly.
        extra: Wrap(alignment: WrapAlignment.center, spacing: 6, runSpacing: 6, children: [
          for (final (id, ok) in history) Container(
            width: 40, height: 44, alignment: Alignment.center,
            decoration: BoxDecoration(color: (ok ? AppColors.success : AppColors.error).withOpacity(0.12),
                borderRadius: BorderRadius.circular(Rad.sm), border: Border.all(color: ok ? AppColors.success : AppColors.error)),
            child: Text(AppData.letterById(id)?.character ?? '', style: Fonts.hindi(22, color: ok ? AppColors.successDark : AppColors.error)),
          ),
        ]),
        onRetry: _retry, onDone: () => Navigator.of(context).maybePop(),
      )),
    ]);
  }
}
