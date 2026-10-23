import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models.dart';
import '../../services/feedback.dart';
import '../../services/stroke_evaluator.dart';
import '../../store/app_store.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../../widgets/common.dart';
import '../../widgets/draw_canvas.dart';
import '../../widgets/toy_button.dart';
import '../../util/num_ext.dart';

class SpeedChallengeScreen extends StatefulWidget {
  final Map<String, dynamic> params;
  const SpeedChallengeScreen({super.key, this.params = const {}});
  @override
  State<SpeedChallengeScreen> createState() => _SpeedChallengeScreenState();
}

class _SpeedChallengeScreenState extends State<SpeedChallengeScreen> {
  late final int _duration = (widget.params['timeLimit'] as int?) ?? 60;
  late int timeRemaining = _duration;
  int idx = 0, correct = 0, total = 0, earned = 0;
  List<String> queue = [];
  bool active = false, complete = false, confetti = false;
  /// Last answer's verdict, flashed briefly over the canvas (null = none).
  bool? flash;
  Timer? _flashTimer;
  final draw = DrawController();
  Timer? _timer;
  double size = 340;

  @override
  void initState() {
    super.initState();
    queue = _makeQueue();
  }

  /// Letters from the level's pool, dealt without repeats (each letter once
  /// before any comes back, never the same one twice in a row).
  List<String> _makeQueue() {
    final count = (widget.params['count'] as int?) ?? 15;
    // Enough letters to keep going until the clock runs out.
    return AppData.deck(AppData.poolIds(widget.params['pool'] as String?), count < 15 ? 15 : count);
  }

  @override
  void dispose() { _timer?.cancel(); _flashTimer?.cancel(); draw.dispose(); super.dispose(); }

  void _start() {
    if (queue.isEmpty) return;
    setState(() { active = true; timeRemaining = _duration; });
    draw.locked = false;
    hapticLight();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (timeRemaining <= 1) {
        t.cancel();
        setState(() => timeRemaining = 0);
        _finish();
      } else {
        setState(() => timeRemaining--);
      }
    });
  }

  Future<void> _submit() async {
    if (draw.isEmpty || queue.isEmpty || !active) return;
    final id = queue[min(idx, queue.length - 1)];
    final result = await gradeWriting(draw.strokes, id, size);
    if (!mounted) return;
    final ok = result.stars >= 2;
    setState(() { total++; if (ok) correct++; flash = ok; });
    _flashTimer?.cancel();
    _flashTimer = Timer(const Duration(milliseconds: 600), () { if (mounted) setState(() => flash = null); });
    ok ? hapticSuccess() : hapticLight();
    _advance();
  }

  void _skip() {
    if (!active) return;
    setState(() => total++);
    _advance();
  }

  void _advance() {
    draw.clear();
    if (idx < queue.length - 1) {
      setState(() => idx++);
    } else {
      _finish();
    }
  }

  void _finish() {
    _timer?.cancel();
    final acc = total == 0 ? 0.0 : correct / total * 100;
    int stars = 0;
    if (acc >= 80 && correct >= 3) { stars = 3; } else if (acc >= 60) { stars = 2; } else if (acc >= 40) { stars = 1; }
    setState(() { active = false; complete = true; earned = stars; confetti = stars == 3; });
    final aId = widget.params['activityId'], lvl = widget.params['levelNumber'];
    if (stars > 0 && aId is String && lvl is int) context.read<AppStore>().completeActivityLevel(aId, lvl);
  }

  void _retry() {
    _timer?.cancel();
    draw.clear();
    setState(() {
      queue = _makeQueue(); idx = 0; correct = 0; total = 0; earned = 0; complete = false; timeRemaining = _duration; active = false;
    });
  }

  Color get _timerColor => timeRemaining > _duration / 2 ? AppColors.success : timeRemaining > 10 ? AppColors.starGold : Palette.light.pink;

  @override
  Widget build(BuildContext context) {
    size = (MediaQuery.of(context).size.width - Sp.md * 2).clampD(200.0, 350.0);
    if (queue.isEmpty && !complete) {
      return Scaffold(backgroundColor: AppColors.background, body: SafeArea(child: Column(children: [
        HeaderBar(title: 'Speed Challenge', onBack: () => Navigator.of(context).maybePop()),
        Expanded(child: Center(child: Text('Loading...', style: Fonts.display(20, w: FontWeight.w700, color: AppColors.textSecondary)))),
      ])));
    }
    final letter = queue.isEmpty ? null : AppData.letterById(queue[min(idx, queue.length - 1)]);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Stack(children: [
          Column(children: [
            HeaderBar(
              title: 'Speed Challenge', subtitle: '${idx + 1}/${queue.length} letters',
              onBack: () { if (!active) Navigator.of(context).maybePop(); },
              rightAction: Container(
                constraints: const BoxConstraints(minWidth: 60), padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: 6),
                decoration: BoxDecoration(color: _timerColor, borderRadius: BorderRadius.circular(9999),
                    boxShadow: toyShadow(AppColors.toyShadowColor, 4)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.timer_outlined, size: 18, color: AppColors.textOnPrimary),
                  const SizedBox(width: 4),
                  Text('${timeRemaining}s', maxLines: 1, softWrap: false,
                      style: Fonts.body(18, w: FontWeight.w800, color: AppColors.textOnPrimary)),
                ]),
              ),
            ),
            Expanded(child: !active && !complete ? _start_() : complete ? _complete() : _challenge(letter)),
          ]),
          Positioned.fill(child: Confetti(visible: confetti, onComplete: () => setState(() => confetti = false))),
        ]),
      ),
    );
  }

  Widget _start_() => Center(child: SingleChildScrollView(padding: const EdgeInsets.symmetric(horizontal: Sp.lg),
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480), child: Container(
          padding: const EdgeInsets.all(Sp.xl),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(Rad.xl2),
              border: Border.all(color: AppColors.border), boxShadow: softShadow(AppColors.primary)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.flash_on, size: 64, color: AppColors.primary),
            const SizedBox(height: Sp.md),
            Text('Speed Challenge', style: Fonts.display(24)),
            const SizedBox(height: Sp.sm),
            Text('Write as many letters correctly as you can in $_duration seconds!', textAlign: TextAlign.center,
                style: Fonts.body(16, color: AppColors.textSecondary)),
            const SizedBox(height: Sp.lg),
            for (final t in ['A fresh mix of letters — no repeats until all are used', '$_duration seconds on the clock', 'Earn stars based on accuracy'])
              Padding(padding: const EdgeInsets.only(bottom: Sp.md), child: Row(children: [
                const Icon(Icons.check_circle, size: 20, color: AppColors.success), const SizedBox(width: Sp.sm),
                Expanded(child: Text(t, style: Fonts.body(16, color: AppColors.textSecondary))),
              ])),
            const SizedBox(height: Sp.sm),
            ToyButton(label: 'Start Challenge', size: ToySize.lg, fullWidth: true, onPressed: _start,
                trailing: const Icon(Icons.arrow_forward, size: 20, color: AppColors.textOnPrimary)),
          ]),
        ))));

  Widget _complete() => SessionCompleteCard(
        emoji: earned == 3 ? '🏆' : earned == 2 ? '⭐' : earned == 1 ? '💪' : '🎯',
        title: 'Challenge Complete!', stars: earned,
        stats: [('$correct/$total', 'Correct'), ('${total > 0 ? (correct / total * 100).round() : 0}%', 'Accuracy'),
            ('${_duration - timeRemaining}s', 'Time')],
        onRetry: _retry, onDone: () => Navigator.of(context).maybePop(),
      );

  Widget _challenge(HindiLetter? letter) => Center(child: SingleChildScrollView(
        padding: const EdgeInsets.all(Sp.md),
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480), child: Column(children: [
          ToyCard(padding: const EdgeInsets.symmetric(vertical: Sp.lg), child: SizedBox(width: double.infinity,
              child: Center(child: Text(letter?.character ?? '', style: Fonts.hindi(72, color: AppColors.primary))))),
          const SizedBox(height: Sp.md),
          Padding(padding: const EdgeInsets.symmetric(horizontal: Sp.xs), child: ClipRRect(borderRadius: BorderRadius.circular(9999),
              child: Container(height: 14, color: AppColors.border, alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(widthFactor: timeRemaining / _duration, child: Container(color: _timerColor))))),
          const SizedBox(height: Sp.md),
          Container(
            width: size, height: size,
            decoration: BoxDecoration(color: AppColors.canvasBackground, borderRadius: BorderRadius.circular(Rad.xl),
                border: Border.all(color: AppColors.border), boxShadow: toyShadow(AppColors.toyShadowColor, 4)),
            clipBehavior: Clip.antiAlias,
            child: Stack(children: [
              const Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: WritingGuidePainter()))),
              Positioned.fill(child: DrawSurface(controller: draw,
                  child: RepaintBoundary(child: CustomPaint(size: Size(size, size), painter: StrokePainterPublic(draw, AppColors.canvasStroke, 5))))),
              if (flash != null) Positioned.fill(child: IgnorePointer(child: PopIn(
                key: ValueKey('f$total'),
                duration: const Duration(milliseconds: 300),
                child: Center(child: Icon(flash! ? Icons.check_circle : Icons.cancel, size: 96,
                    color: (flash! ? AppColors.success : AppColors.error).withOpacity(0.85))),
              ))),
            ]),
          ),
          const SizedBox(height: Sp.md),
          AnimatedBuilder(animation: draw, builder: (_, __) => Row(children: [
            _iconBtn(Icons.delete_outline, draw.isEmpty ? AppColors.disabled : AppColors.error, draw.isEmpty ? null : draw.clear),
            const SizedBox(width: Sp.md),
            Expanded(child: Opacity(opacity: draw.isEmpty ? 0.5 : 1, child: GestureDetector(
              onTap: draw.isEmpty ? null : _submit,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: Sp.md),
                decoration: BoxDecoration(gradient: toneGradient(AppColors.success), borderRadius: BorderRadius.circular(9999),
                    boxShadow: toyShadow(AppColors.successDark, 6)),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.check, size: 24, color: Colors.white), const SizedBox(width: Sp.sm),
                  Text('Submit', style: Fonts.body(16, w: FontWeight.w800, color: AppColors.textOnPrimary)),
                ]),
              ),
            ))),
            const SizedBox(width: Sp.md),
            _iconBtn(Icons.skip_next, AppColors.primary, _skip),
          ])),
        ])),
      ));

  Widget _iconBtn(IconData i, Color c, VoidCallback? onTap) => GestureDetector(
        onTap: onTap,
        child: Container(width: 56, height: 56,
            decoration: BoxDecoration(color: AppColors.surface, shape: BoxShape.circle, border: Border.all(color: AppColors.border),
                boxShadow: toyShadow(AppColors.toyShadowColor, 4)),
            child: Icon(i, size: 24, color: c)),
      );
}
