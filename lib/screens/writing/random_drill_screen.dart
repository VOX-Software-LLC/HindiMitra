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

class RandomDrillScreen extends StatefulWidget {
  final Map<String, dynamic> params;
  const RandomDrillScreen({super.key, this.params = const {}});
  @override
  State<RandomDrillScreen> createState() => _RandomDrillScreenState();
}

class _RandomDrillScreenState extends State<RandomDrillScreen> {
  List<String> queue = [];
  int idx = 0, correctCount = 0, accSum = 0;
  bool evaluated = false, complete = false;
  EvaluationResult? result;
  String? lookedLike;
  final draw = DrawController();
  double size = 350;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => queue = _makeQueue()); });
  }

  /// The level's pool dealt like cards: every letter once before any repeats,
  /// never the same letter twice in a row. "weakest" = the 8 letters with the
  /// lowest accuracy so far.
  List<String> _makeQueue() {
    final pool = widget.params['pool'] as String?;
    final count = (widget.params['count'] as int?) ?? 20;
    final ids = pool == 'weakest'
        ? context.read<AppStore>().weakestLetters(AppData.poolIds('all')).take(8).toList()
        : AppData.poolIds(pool);
    return AppData.deck(ids, count);
  }

  @override
  void dispose() { draw.dispose(); super.dispose(); }

  void _submit() {
    if (draw.isEmpty || queue.isEmpty) return;
    final id = queue[min(idx, queue.length - 1)];
    final r = evaluateStrokes(draw.strokes, id, size);
    final best = r.stars >= 2 ? null : findBestMatchingLetter(draw.strokes, size);
    setState(() {
      result = r; evaluated = true; accSum += r.accuracy;
      lookedLike = best != null && best.letterId != id && best.result.accuracy > r.accuracy ? best.character : null;
      if (r.stars >= 2) correctCount++;
    });
    draw.locked = true;
    r.stars >= 2 ? hapticSuccess() : hapticMedium();
    final store = context.read<AppStore>();
    store.letterProgress.putIfAbsent(id, () => LetterProgress(letterId: id));
    store.recordAttempt(id, r.stars, accuracy: r.accuracy);
  }

  void _next() {
    if (idx < queue.length - 1) {
      setState(() { idx++; evaluated = false; result = null; lookedLike = null; });
      draw.locked = false; draw.clear();
    } else {
      setState(() => complete = true);
      final aId = widget.params['activityId'], lvl = widget.params['levelNumber'];
      if (correctCount / queue.length >= 0.4 && aId is String && lvl is int) context.read<AppStore>().completeActivityLevel(aId, lvl);
    }
  }

  void _retry() {
    draw.locked = false; draw.clear();
    setState(() {
      idx = 0; correctCount = 0; accSum = 0; evaluated = false; result = null; complete = false; queue = _makeQueue();
    });
  }

  @override
  Widget build(BuildContext context) {
    size = (MediaQuery.of(context).size.width - Sp.md * 2).clampD(200.0, 350.0);
    Widget scaffold(Widget body) => Scaffold(backgroundColor: AppColors.background, body: SafeArea(bottom: false, child: body));
    if (queue.isEmpty) {
      return scaffold(Column(children: [
        HeaderBar(title: 'Random Drill', onBack: () => Navigator.of(context).maybePop()),
        const Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.primary))),
      ]));
    }
    if (complete) {
      final accuracy = correctCount / queue.length * 100;
      final avg = (accSum / queue.length).round();
      final st = accuracy >= 80 ? 3 : accuracy >= 60 ? 2 : accuracy >= 40 ? 1 : 0;
      return scaffold(Column(children: [
        HeaderBar(title: 'Drill Complete', onBack: () => Navigator.of(context).maybePop()),
        Expanded(child: SessionCompleteCard(
          emoji: accuracy >= 80 ? '🏆' : accuracy >= 60 ? '🎉' : accuracy >= 40 ? '👏' : '🎯',
          title: 'Drill Complete!', stars: st,
          stats: [('$correctCount/${queue.length}', 'Correct'), ('${accuracy.round()}%', 'Passed'), ('$avg%', 'Avg match')],
          message: accuracy >= 80 ? 'Excellent work! You mastered this drill!'
              : accuracy >= 60 ? 'Great effort! Keep practicing!' : 'Good try! Practice makes perfect.',
          retryLabel: 'Drill Again', onRetry: _retry, onDone: () => Navigator.of(context).maybePop(),
        )),
      ]));
    }

    final letter = AppData.letterById(queue[min(idx, queue.length - 1)]);
    return scaffold(Column(children: [
      HeaderBar(title: 'Random Drill', subtitle: '${idx + 1}/${queue.length} letters',
          onBack: () => Navigator.of(context).maybePop()),
      Container(
        padding: const EdgeInsets.all(Sp.md),
        decoration: BoxDecoration(color: AppColors.surface, boxShadow: toyShadow(AppColors.toyShadowColor, 3)),
        child: Column(children: [
          ClipRRect(borderRadius: BorderRadius.circular(9999), child: LinearProgressIndicator(
              value: (idx + (evaluated ? 1 : 0)) / queue.length, minHeight: 10,
              backgroundColor: AppColors.border, color: AppColors.success)),
          const SizedBox(height: Sp.sm),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('✓ $correctCount correct', style: Fonts.body(12, w: FontWeight.w700, color: AppColors.textSecondary)),
            Text('${queue.length - idx - 1} remaining', style: Fonts.body(12, w: FontWeight.w700, color: AppColors.textSecondary)),
          ]),
        ]),
      ),
      Expanded(child: SingleChildScrollView(
        padding: const EdgeInsets.all(Sp.md),
        child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480),
            child: evaluated ? PopIn(key: ValueKey('r$idx'), child: _result(letter)) : _drawing(letter))),
      )),
    ]));
  }

  Widget _drawing(HindiLetter? letter) => Column(children: [
        ToyCard(padding: const EdgeInsets.all(Sp.md), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('Write:', style: Fonts.body(16, w: FontWeight.w700, color: AppColors.textSecondary)),
          const SizedBox(width: Sp.md),
          Text(letter?.character ?? '', style: Fonts.hindi(64, color: AppColors.primary, height: 1.2)),
          const SizedBox(width: Sp.md),
          SoftPill(icon: Icons.volume_up, onTap: () { if (letter != null) speakHindi(letter.character, rate: 0.8); }, size: 20),
        ])),
        const SizedBox(height: Sp.md),
        SimpleCanvas(controller: draw, size: size, radius: Rad.lg),
        const SizedBox(height: Sp.md),
        AnimatedBuilder(animation: draw, builder: (_, __) {
          final empty = draw.isEmpty;
          return Row(children: [
            Expanded(child: ResultButton(label: 'Undo', icon: Icons.undo, filled: false, onTap: empty ? null : draw.undo)),
            const SizedBox(width: Sp.sm),
            Expanded(child: ResultButton(label: 'Clear', icon: Icons.delete_outline, filled: false, color: AppColors.error,
                onTap: empty ? null : draw.clear)),
            const SizedBox(width: Sp.sm),
            Expanded(child: ResultButton(label: 'Submit', icon: Icons.check_circle, color: AppColors.success,
                onTap: empty ? null : _submit)),
          ]);
        }),
      ]);

  Widget _result(HindiLetter? letter) {
    final r = result!;
    final ok = r.stars >= 2;
    return Column(children: [
      Container(
        width: double.infinity, padding: const EdgeInsets.all(Sp.lg),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(Rad.xl),
            border: Border.all(color: ok ? AppColors.success : AppColors.border, width: 2),
            boxShadow: toyShadow(AppColors.toyShadowColor, 4)),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(letter?.character ?? '', style: Fonts.hindi(48, color: AppColors.primary, height: 1.2)),
            const SizedBox(width: Sp.md),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(ok ? 'Correct!' : 'Not quite', style: Fonts.display(22, color: ok ? AppColors.success : AppColors.primaryDark)),
              Text('${r.accuracy}% match', style: Fonts.body(15, w: FontWeight.w800, color: AppColors.textSecondary)),
            ]),
          ]),
          StarRating(stars: r.stars, size: 36),
          if (lookedLike != null) Padding(
            padding: const EdgeInsets.only(top: Sp.sm),
            child: Text('Your writing looks more like $lookedLike', style: Fonts.body(14, w: FontWeight.w700, color: AppColors.error)),
          ),
          const SizedBox(height: Sp.md),
          ScoreBreakdown(r),
          if (getActionableTip(r, queue[idx]) case final tip?) Padding(
            padding: const EdgeInsets.only(top: Sp.sm),
            child: Text(tip, textAlign: TextAlign.center, style: Fonts.body(13, w: FontWeight.w600, color: AppColors.textSecondary)),
          ),
        ]),
      ),
      const SizedBox(height: Sp.lg),
      ResultButton(label: idx < queue.length - 1 ? 'Next Letter' : 'Finish Drill', icon: Icons.arrow_forward, onTap: _next),
    ]);
  }
}
