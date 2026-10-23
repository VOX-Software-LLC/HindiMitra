import 'dart:async';
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
import '../../widgets/stroke_guide.dart';
import '../../util/num_ext.dart';
import '../../services/crash_reporter.dart';

const _stageNames = {1: 'Guided Tracing', 2: 'Faded Ghost', 3: 'Freehand + Reference', 4: 'From Memory'};
const _hintsPerLevel = 3;
/// Writing "From Memory" (stage 4) is harder, so it earns a small accuracy bonus.
const _memoryBonus = 10;
/// Profile "Difficulty" shifts the accuracy score: Easy +10, Hard -10.
int _bonusFor(int stage, String difficulty) =>
    (stage == 4 ? _memoryBonus : 0) + (difficulty == 'easy' ? 10 : difficulty == 'hard' ? -10 : 0);

class WritingCanvasScreen extends StatefulWidget {
  final Map<String, dynamic> params;
  const WritingCanvasScreen({super.key, this.params = const {}});
  @override
  State<WritingCanvasScreen> createState() => _WritingCanvasScreenState();
}

class _WritingCanvasScreenState extends State<WritingCanvasScreen> with TickerProviderStateMixin {
  late final List<String> allIds;
  int idx = 0;
  final draw = DrawController();
  bool attemptComplete = false, showConfetti = false, stageAdvanced = false, showDemo = false;
  bool _grading = false, levelComplete = false;
  int earnedStars = 0, earnedAccuracy = 0;
  String evalFeedback = '';
  String? tip;
  GradedResult? lastGraded;
  // Hint: faint dotted outline of the letter + the first stroke animated.
  bool showHint = false, hintUsedThisAttempt = false;
  int hintsLeft = _hintsPerLevel;
  /// Best accuracy reached on each letter of the level (index -> %).
  final Map<int, int> _levelBest = {};
  DateTime _attemptStart = DateTime.now();
  late final AnimationController demo;
  late final AnimationController hint;
  Timer? _demoTimer;
  Timer? _listenTimer;
  double canvasSize = 340;

  @override
  void initState() {
    super.initState();
    demo = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    hint = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
    final p = widget.params;
    final single = p['letterId'] as String?;
    allIds = (p['letterIds'] as List?)?.cast<String>() ?? (single != null ? [single] : []);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (allIds.isNotEmpty) context.read<AppStore>().selectLetter(allIds[0]);
      _maybeListen();
    });
  }

  @override
  void dispose() {
    _demoTimer?.cancel(); _listenTimer?.cancel(); demo.dispose(); hint.dispose(); draw.dispose(); stopSpeaking();
    super.dispose();
  }

  String get letterId => idx < allIds.length ? allIds[idx] : (widget.params['letterId'] ?? '');
  bool get isLevelMode => (widget.params['letterIds'] as List?) != null && (widget.params['letterIds'] as List).length > 1;

  void _maybeListen() {
    final s = context.read<AppStore>();
    final letter = AppData.letterById(letterId);
    s.letterProgress.putIfAbsent(letterId, () => LetterProgress(letterId: letterId));
    final stage = s.letterProgress[letterId]?.currentStage ?? 1;
    _listenTimer?.cancel();
    if (stage == 4 && letter != null) {
      _listenTimer = Timer(const Duration(milliseconds: 300), () => speakLetterSlow(letter.character));
    }
  }

  /// Clears the canvas and every per-attempt flag. Called after each checked
  /// attempt so the stroke list never keeps growing across letters.
  void _reset({bool keepResult = false}) {
    draw.clear();
    draw.locked = false;
    hint.stop();
    _attemptStart = DateTime.now();
    setState(() {
      attemptComplete = false; earnedStars = 0; earnedAccuracy = 0; evalFeedback = ''; tip = null; lastGraded = null;
      showConfetti = false; stageAdvanced = false; showHint = false; hintUsedThisAttempt = false;
    });
  }

  void _useHint() {
    if (hintsLeft <= 0 || attemptComplete) return;
    setState(() { showHint = true; hintUsedThisAttempt = true; hintsLeft--; });
    hint.repeat();
  }

  Future<void> _done() async {
    if (_grading || draw.isEmpty) return;
    _grading = true;
    final store = context.read<AppStore>();
    GradedResult result;
    try {
      result = await gradeWriting(draw.strokes, letterId, canvasSize);
    } catch (e, st) {
      CrashReporter.record(e, st, reason: 'gradeWriting($letterId)');
      _grading = false;
      if (!mounted) return;
      draw.clear();
      showInfoDialog(context, 'Try again', "We couldn't check that one. Please write the letter again.");
      return;
    }
    _grading = false;
    if (!mounted) return;
    final prog = store.letterProgress[letterId];
    final stageBefore = prog?.currentStage ?? 1;
    final accuracy = (result.accuracy + _bonusFor(stageBefore, store.difficulty)).clamp(0, 100);
    var stars = starsForAccuracy(accuracy);
    // Using a hint on this attempt caps it at 2 stars.
    if (hintUsedThisAttempt && stars > 2) stars = 2;
    final successfulBefore = prog?.successfulAttempts ?? 0;
    final willMaster = stars >= 2 && stageBefore == 4;
    final willAdvance = willMaster || (stars >= 2 && stageBefore < 4 && successfulBefore + 1 >= 3);
    draw.locked = true;
    hint.stop();
    setState(() {
      earnedStars = stars; earnedAccuracy = accuracy; evalFeedback = result.feedback; tip = result.actionableTip;
      lastGraded = result; attemptComplete = true; showHint = false;
      if (accuracy > (_levelBest[idx] ?? -1)) _levelBest[idx] = accuracy;
    });
    final secs = DateTime.now().difference(_attemptStart).inSeconds.clamp(1, 180);
    store.recordAttempt(letterId, stars, accuracy: accuracy, practicedSeconds: secs);
    if (willAdvance) {
      setState(() { stageAdvanced = true; showConfetti = true; });
      hapticSuccess();
    } else if (stars >= 2) {
      hapticMedium();
    }
  }

  void _watchDemo() {
    setState(() => showDemo = true);
    demo.repeat(reverse: true);
    _demoTimer?.cancel();
    _demoTimer = Timer(const Duration(milliseconds: 4200), () {
      if (!mounted) return;
      demo.stop();
      setState(() => showDemo = false);
    });
  }

  void _next() {
    if (isLevelMode && idx < allIds.length - 1) {
      setState(() => idx++);
      _reset();
      context.read<AppStore>().selectLetter(letterId);
      _maybeListen();
      return;
    }
    if (isLevelMode) {
      final id = widget.params['levelId'] as String?;
      if (id != null) context.read<AppStore>().recordLevelAccuracy(id, levelAccuracy);
      draw.clear();
      setState(() { attemptComplete = false; levelComplete = true; showConfetti = true; });
      return;
    }
    final next = AppData.nextLetter(letterId);
    if (next != null) {
      context.read<AppStore>().selectLetter(next.id);
      Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => WritingCanvasScreen(params: {'letterId': next.id})));
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _replayLevel() {
    _levelBest.clear();
    setState(() { idx = 0; levelComplete = false; hintsLeft = _hintsPerLevel; });
    _reset();
    context.read<AppStore>().selectLetter(letterId);
    _maybeListen();
  }

  /// Average of the best accuracy on each letter in the level.
  int get levelAccuracy => _levelBest.isEmpty
      ? 0
      : (_levelBest.values.fold<int>(0, (a, b) => a + b) / _levelBest.length).round();

  /// The level after this one in the same section, or null after the final level.
  LevelDef? get _nextLevel {
    final id = widget.params['levelId'];
    for (final list in [AppData.vowelLevels, AppData.consonantLevels]) {
      final i = list.indexWhere((l) => l.id == id);
      if (i >= 0) return i + 1 < list.length ? list[i + 1] : null;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild only when this letter's own progress actually changes, not on
    // every unrelated AppStore mutation (other letters, stars, streaks, etc.).
    context.select<AppStore, (int, int, bool)>((store) {
      final p = store.letterProgress[letterId];
      return (p?.currentStage ?? 1, p?.attemptsInCurrentStage ?? 0, p?.mastered ?? false);
    });
    final store = context.read<AppStore>();
    final letter = AppData.letterById(letterId);
    if (letter == null) return const Scaffold(body: SafeArea(child: Center(child: Text('Letter not found'))));
    final progress = store.letterProgress[letterId];
    final stage = progress?.currentStage ?? 1;
    final attempts = progress?.attemptsInCurrentStage ?? 0;
    final w = MediaQuery.of(context).size.width;
    canvasSize = (w - Sp.md * 2).clampD(200.0, 400.0);
    final levelName = (widget.params['levelName'] as String?) ?? '';
    final leftHanded = context.select<AppStore, bool>((s) => s.leftHanded);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Stack(children: [
          SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(children: [
                  HeaderBar(
                    title: isLevelMode && levelName.isNotEmpty ? '${letter.character} — $levelName' : '${letter.character} — ${letter.romanized}',
                    subtitle: isLevelMode
                        ? 'Letter ${idx + 1} of ${allIds.length} · Stage $stage'
                        : 'Stage $stage: ${_stageNames[stage]}',
                    onBack: () => Navigator.of(context).maybePop(),
                    rightAction: Container(
                      padding: const EdgeInsets.symmetric(horizontal: Sp.sm, vertical: Sp.xs),
                      decoration: BoxDecoration(color: AppColors.secondary, borderRadius: BorderRadius.circular(12)),
                      child: Text(isLevelMode ? '${idx + 1}/${allIds.length}' : '$attempts/3',
                          style: Fonts.body(12, w: FontWeight.w700)),
                    ),
                  ),
                  if (isLevelMode) _levelProgress(),
                  // Stage pills
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: Sp.sm),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      for (int s = 1; s <= 4; s++) ...[
                        if (s > 1) const SizedBox(width: Sp.sm),
                        _stagePill(s, stage, progress?.mastered == true && s == 4),
                      ],
                    ]),
                  ),
                  const SizedBox(height: Sp.sm),
                  DrawCanvas(
                    controller: draw, size: canvasSize,
                    overlays: [
                      if (stage == 1 || stage == 2)
                        Positioned.fill(child: IgnorePointer(child: Center(child: Opacity(
                          opacity: stage == 1 ? 0.28 : 0.12,
                          child: Text(letter.character, style: Fonts.hindi(canvasSize * 0.6).copyWith(fontWeight: FontWeight.w900)))))),
                      if (showHint)
                        Positioned.fill(child: IgnorePointer(child: AnimatedStrokeGuide(character: letter.character))),
                    ],
                    topOverlays: [
                      if (stage <= 3)
                        Positioned(top: Sp.sm, left: Sp.sm, child: IgnorePointer(child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: Sp.sm, vertical: 4),
                          decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(Rad.sm)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.back_hand_outlined, size: 14, color: Colors.white),
                            const SizedBox(width: 4),
                            Text('${letter.strokeCount} stroke${letter.strokeCount == 1 ? '' : 's'}${letter.strokeCount > 1 ? ' · lift between' : ''}',
                                style: Fonts.body(12, w: FontWeight.w600, color: Colors.white)),
                          ]),
                        ))),
                      if (stage == 3)
                        Positioned(top: Sp.sm, right: Sp.sm, child: Container(
                          padding: const EdgeInsets.all(Sp.xs),
                          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(Rad.sm),
                              border: Border.all(color: AppColors.border)),
                          child: Text(letter.character, style: Fonts.hindi(36)))),
                      if (stage == 4)
                        Positioned(top: Sp.sm, right: Sp.sm, child: GestureDetector(
                          onTap: () => speakLetterSlow(letter.character),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: Sp.sm, vertical: Sp.xs),
                            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(Rad.sm), border: Border.all(color: AppColors.primary)),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.volume_up, size: 18, color: AppColors.primary),
                              const SizedBox(width: Sp.xs),
                              Text('Tap to listen again', style: Fonts.body(12, w: FontWeight.w600, color: AppColors.primary)),
                            ]),
                          ))),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.xs),
                    child: TracingMeter(controller: draw, letterId: letterId, canvasSize: canvasSize,
                        bonus: _bonusFor(stage, context.select<AppStore, String>((s) => s.difficulty))),
                  ),
                  // Actions
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: Sp.md),
                    child: RepaintBoundary(child: AnimatedBuilder(
                      animation: draw,
                      builder: (_, __) {
                        final actions = <Widget>[
                          if (stage == 1) _action(Icons.visibility_outlined, 'Watch', AppColors.primary, !attemptComplete, _watchDemo),
                          _action(Icons.lightbulb_outline, 'Hint ($hintsLeft)', AppColors.warning,
                              hintsLeft > 0 && !attemptComplete && !showHint, _useHint),
                          _action(Icons.undo, 'Undo', AppColors.primary, !draw.isEmpty && !attemptComplete, draw.undo),
                          _action(Icons.delete_outline, 'Clear', AppColors.error, !draw.isEmpty && !attemptComplete, draw.clear),
                          _action(Icons.check_circle, 'Done', AppColors.success, !draw.isEmpty && !attemptComplete && !_grading, _done, big: true),
                        ];
                        // Left-handed: put "Done" under the left thumb.
                        final ordered = leftHanded ? actions.reversed.toList() : actions;
                        return Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                          for (final a in ordered) Flexible(child: a),
                        ]);
                      },
                    )),
                  ),
                  // Pronunciation row
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: Sp.md),
                    padding: const EdgeInsets.symmetric(horizontal: Sp.lg, vertical: Sp.sm),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(Rad.lg),
                        border: Border.all(color: AppColors.border)),
                    child: Row(children: [
                      GestureDetector(
                        onTap: () => speakLetterWithGuide(letter.character, letter.pronunciation, letter.exampleWord),
                        child: Container(width: 44, height: 44,
                            decoration: const BoxDecoration(color: AppColors.background, shape: BoxShape.circle),
                            child: const Icon(Icons.volume_up, size: 24, color: AppColors.primary)),
                      ),
                      const SizedBox(width: Sp.md),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${letter.character} = "${letter.pronunciation}"', style: Fonts.body(18, w: FontWeight.w600)),
                        Text('${letter.exampleWord} (${letter.exampleMeaning})',
                            style: Fonts.body(14, color: AppColors.textSecondary)),
                      ])),
                    ]),
                  ),
                  const SizedBox(height: Sp.xl),
                ]),
              ),
            ),
          ),
          if (showDemo) _demoOverlay(letter),
          if (attemptComplete) _resultOverlay(store, letter, progress, stage),
          if (levelComplete) _levelCompleteOverlay(),
          Positioned.fill(child: Confetti(visible: showConfetti, onComplete: () => setState(() => showConfetti = false))),
        ]),
      ),
    );
  }

  Widget _stagePill(int s, int current, bool masteredCell) {
    final isPast = s < current;
    final isCurrent = s == current && !masteredCell;
    final done = isPast || masteredCell;
    return Container(
      constraints: const BoxConstraints(minWidth: 40), height: 36,
      padding: const EdgeInsets.symmetric(horizontal: Sp.md),
      decoration: BoxDecoration(
        color: done ? AppColors.success : isCurrent ? AppColors.primary : AppColors.surface,
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: done ? AppColors.success : isCurrent ? AppColors.primary : AppColors.border),
        boxShadow: isCurrent ? toyShadow(AppColors.primaryDark, 4) : null),
      child: Center(child: masteredCell
          ? const Icon(Icons.check, size: 18, color: Colors.white)
          : Text('$s', style: Fonts.body(14, w: FontWeight.w800,
              color: (isCurrent || isPast) ? Colors.white : AppColors.textSecondary))),
    );
  }

  Widget _action(IconData icon, String label, Color color, bool enabled, VoidCallback onTap, {bool big = false}) =>
      GestureDetector(
        onTap: enabled ? onTap : null,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: big ? 28 : 24, color: enabled ? color : AppColors.disabled),
          const SizedBox(height: Sp.xs),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: Fonts.body(12, color: AppColors.textSecondary, w: FontWeight.w500)),
        ]),
      );

  Widget _demoOverlay(HindiLetter letter) => Positioned.fill(
        child: GestureDetector(
          onTap: () { demo.stop(); setState(() => showDemo = false); },
          child: PopupBackdrop(child: Container(
            width: canvasSize, height: canvasSize + 56,
            decoration: BoxDecoration(color: AppColors.canvasBackground, borderRadius: BorderRadius.circular(Rad.lg)),
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
              Expanded(child: Stack(children: [
                const Positioned.fill(child: CustomPaint(painter: WritingGuidePainter())),
                Positioned.fill(child: AnimatedStrokeGuide(character: letter.character)),
              ])),
              Padding(padding: const EdgeInsets.all(Sp.sm), child: Text('Green dot = start · follow the numbers · tap to close',
                  textAlign: TextAlign.center, style: Fonts.body(13, w: FontWeight.w700, color: AppColors.textSecondary))),
            ]),
          )),
        ),
      );

  Widget _resultOverlay(AppStore store, HindiLetter letter, LetterProgress? progress, int stage) {
    final mastered = progress?.mastered == true;
    final title = mastered ? 'Mastered! 🏆' : stageAdvanced ? 'Stage Complete!' : earnedStars >= 2 ? 'Great Job!' : 'Keep Trying!';
    final msg = mastered
        ? "You've fully mastered this letter!"
        : stageAdvanced
            ? "You've advanced to Stage ${(progress?.currentStage ?? 1).clampI(1, 4)}!"
            : (evalFeedback.isNotEmpty ? evalFeedback : (earnedStars >= 2 ? 'Good work!' : 'Keep practicing!'));
    return Positioned.fill(
      child: PopupBackdrop(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 360),
          padding: const EdgeInsets.all(Sp.xl),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(Rad.xl2),
              border: Border.all(color: AppColors.border), boxShadow: softShadow(AppColors.primary)),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: Sp.lg, vertical: Sp.sm),
                decoration: BoxDecoration(gradient: toneGradient(AppColors.primary), borderRadius: BorderRadius.circular(9999),
                    boxShadow: toyShadow(AppColors.primaryDark, 6)),
                child: Text(title, textAlign: TextAlign.center, style: Fonts.display(24, color: AppColors.textOnPrimary)),
              ),
              const SizedBox(height: Sp.md),
              StarRating(stars: earnedStars, size: 48),
              const SizedBox(height: Sp.sm),
              Text('$earnedAccuracy% accuracy', style: Fonts.display(22, color: AppColors.primaryDark)),
              if (hintUsedThisAttempt)
                Text('Hint used · max 2 stars', style: Fonts.body(12, w: FontWeight.w600, color: AppColors.textMuted)),
              const SizedBox(height: Sp.md),
              Text(msg, textAlign: TextAlign.center, style: Fonts.body(16, color: AppColors.textSecondary)),
              if (tip != null && !mastered && !stageAdvanced)
                Container(
                  margin: const EdgeInsets.only(top: Sp.md),
                  padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.sm),
                  decoration: const BoxDecoration(color: Color(0x1FEE9A4C),
                      border: Border(left: BorderSide(color: AppColors.primary, width: 3)),
                      borderRadius: BorderRadius.all(Radius.circular(Rad.md))),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.lightbulb_outline, size: 18, color: AppColors.primary),
                    const SizedBox(width: Sp.sm),
                    Expanded(child: Text(tip!, style: Fonts.body(14, height: 18 / 14))),
                  ]),
                ),
              if (lastGraded?.detail != null)
                Padding(padding: const EdgeInsets.only(top: Sp.md), child: ScoreBreakdown(lastGraded!.detail!)),
              const SizedBox(height: Sp.sm),
              Text('+${earnedStars * 10 * stage} points', style: Fonts.display(20, w: FontWeight.w700, color: AppColors.primary)),
              const SizedBox(height: Sp.lg),
              Row(children: [
                Expanded(child: GestureDetector(
                  onTap: _reset,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: Sp.sm),
                    decoration: BoxDecoration(border: Border.all(color: AppColors.primary, width: 2),
                        borderRadius: BorderRadius.circular(Rad.lg)),
                    child: Center(child: Text(earnedStars < 3 ? 'Retry for 3 ★' : 'Try Again', textAlign: TextAlign.center,
                        style: Fonts.body(16, w: FontWeight.w800, color: AppColors.primary))),
                  ),
                )),
                const SizedBox(width: Sp.md),
                Expanded(child: GestureDetector(
                  onTap: _next,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: Sp.sm),
                    decoration: BoxDecoration(color: AppColors.primaryDark, borderRadius: BorderRadius.circular(Rad.lg)),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Flexible(child: Text(
                        isLevelMode
                            ? (idx < allIds.length - 1 ? 'Next (${idx + 2}/${allIds.length})' : 'Finish Level')
                            : 'Next Letter',
                        style: Fonts.body(16, w: FontWeight.w800, color: Colors.white))),
                      const SizedBox(width: Sp.xs),
                      Icon(isLevelMode && idx >= allIds.length - 1 ? Icons.emoji_events : Icons.arrow_forward, size: 18, color: Colors.white),
                    ]),
                  ),
                )),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _levelProgress() {
    final done = idx + (attemptComplete ? 1 : 0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.md, Sp.xs, Sp.md, 0),
      child: Row(children: [
        Text('Letter ${idx + 1} of ${allIds.length}', style: Fonts.body(13, w: FontWeight.w800, color: AppColors.textSecondary)),
        const SizedBox(width: Sp.sm),
        Expanded(child: ClipRRect(
          borderRadius: BorderRadius.circular(9999),
          child: LinearProgressIndicator(
              value: allIds.isEmpty ? 0 : done / allIds.length, minHeight: 8,
              backgroundColor: AppColors.muted, color: AppColors.success),
        )),
      ]),
    );
  }

  Widget _levelCompleteOverlay() {
    final acc = levelAccuracy;
    final stars = starsForAccuracy(acc);
    final next = _nextLevel;
    final levelName = (widget.params['levelName'] as String?) ?? '';
    final isLast = next == null;
    Widget btn(String label, IconData icon, bool filled, VoidCallback onTap) => SizedBox(width: double.infinity, child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: Sp.sm + 2),
            decoration: BoxDecoration(
                color: filled ? AppColors.primaryDark : null,
                border: filled ? null : Border.all(color: AppColors.primary, width: 2),
                borderRadius: BorderRadius.circular(Rad.lg)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 18, color: filled ? Colors.white : AppColors.primary),
              const SizedBox(width: Sp.xs),
              Flexible(child: Text(label, style: Fonts.body(15, w: FontWeight.w800,
                  color: filled ? Colors.white : AppColors.primary))),
            ]),
          ),
        ));
    return Positioned.fill(child: PopupBackdrop(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        padding: const EdgeInsets.all(Sp.xl),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(Rad.xl2),
            border: Border.all(color: AppColors.border), boxShadow: softShadow(AppColors.primary)),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(isLast ? '🏆' : '🎉', style: const TextStyle(fontSize: 56)),
          const SizedBox(height: Sp.sm),
          Text(isLast ? 'You finished every level!' : 'Level Complete!', textAlign: TextAlign.center,
              style: Fonts.display(24, color: AppColors.primaryDark)),
          const SizedBox(height: Sp.xs),
          Text(levelName.isNotEmpty
                  ? 'You wrote all ${allIds.length} letters in "$levelName".'
                  : 'You wrote all ${allIds.length} letters in this level.',
              textAlign: TextAlign.center, style: Fonts.body(15, color: AppColors.textSecondary)),
          const SizedBox(height: Sp.md),
          StarRating(stars: stars, size: 44),
          const SizedBox(height: Sp.sm),
          Text('$acc% accuracy', style: Fonts.display(22, color: AppColors.primary)),
          if (next != null) Padding(
            padding: const EdgeInsets.only(top: Sp.sm),
            child: Text('Next up: ${next.name}', textAlign: TextAlign.center,
                style: Fonts.body(14, w: FontWeight.w700, color: AppColors.textSecondary)),
          ),
          const SizedBox(height: Sp.lg),
          btn('Back to Levels', Icons.grid_view, true, () => Navigator.of(context).maybePop()),
          const SizedBox(height: Sp.sm),
          btn(stars < 3 ? 'Replay for 3 ★' : 'Replay', Icons.refresh, false, _replayLevel),
        ])),
      ),
    ));
  }
}
