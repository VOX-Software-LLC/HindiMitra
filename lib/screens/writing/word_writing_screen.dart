import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models.dart';
import '../../data/word_bank.dart';
import '../../routes.dart';
import '../../services/crash_reporter.dart';
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

/// A whole-word attempt: score per written block, plus whether the header
/// line (शिरोरेखा) was drawn across the word.
class _WordCheck {
  final List<int> unitScores; final bool headerDrawn; final int accuracy;
  const _WordCheck(this.unitScores, this.headerDrawn, this.accuracy);
}

/// Two separate sections:
///  * Word Writing — the whole word on one ruled line (header + base line),
///    graded block by block, repeated an adaptive number of times.
///  * Letter Writing — one block at a time with an animated stroke-order guide.
/// Every word of the level is listed at the top; a Rough Page is one tap away.
class WordWritingScreen extends StatefulWidget {
  final Map<String, dynamic> params;
  const WordWritingScreen({super.key, this.params = const {}});
  @override
  State<WordWritingScreen> createState() => _WordWritingScreenState();
}

class _WordWritingScreenState extends State<WordWritingScreen> {
  late final List<PracticeWord> words;
  int wi = 0;
  bool letterSection = false, confetti = false, sessionComplete = false;
  /// Words whose repetitions are all done this session.
  final Set<int> doneWords = {};
  /// Best whole-word accuracy reached per word this session.
  final Map<int, int> bestAcc = {};

  // Word section
  final wordDraw = DrawController();
  bool wordHint = false;
  int repsNeeded = 3, repsDone = 0;
  _WordCheck? check;
  String repNote = '';

  // Letter section
  final letterDraw = DrawController();
  int li = 0, letterTries = 0;
  bool letterHint = true;
  final Set<int> lettersDone = {};
  StrictEvaluationResult? letterResult;

  Timer? _speakTimer;

  bool get _dictation => widget.params['mode'] == 'dictation';
  PracticeWord get word => words[wi];
  String get unit => word.units[li.clampI(0, word.units.length - 1)];

  @override
  void initState() {
    super.initState();
    final pool = wordsForLevel(widget.params);
    final count = (widget.params['count'] as int?) ?? pool.length;
    words = AppData.deck(pool, count.clampI(1, pool.length));
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _enterWord(0); });
  }

  @override
  void dispose() { _speakTimer?.cancel(); wordDraw.dispose(); letterDraw.dispose(); stopSpeaking(); super.dispose(); }

  void _say(String text, {double rate = 0.7}) {
    _speakTimer?.cancel();
    _speakTimer = Timer(const Duration(milliseconds: 300), () { if (mounted) speakHindi(text, rate: rate); });
  }

  void _enterWord(int i) {
    final store = context.read<AppStore>();
    setState(() {
      wi = i;
      repsNeeded = store.wordRepsNeeded(words[i].word);
      repsDone = 0; check = null; repNote = ''; wordHint = false;
      li = 0; letterTries = 0; lettersDone.clear(); letterResult = null; letterHint = true;
    });
    wordDraw.clear(); wordDraw.locked = false;
    letterDraw.clear(); letterDraw.locked = false;
    _say(letterSection ? unit : words[i].word, rate: letterSection ? 0.6 : 0.7);
  }

  // ───────────────────────── Word section ─────────────────────────

  /// Assigns each stroke to the letter box its centre falls in; a long, flat
  /// stroke spanning several boxes is the header line and is shared between
  /// the boxes it crosses. Each box is then graded against its block.
  _WordCheck _gradeWord(double width, double height) {
    final n = word.units.length;
    final colW = width / n;
    final parts = List.generate(n, (_) => <List<Offset>>[]);
    bool header = false;
    for (final s in wordDraw.strokes) {
      if (s.isEmpty) continue;
      double minX = s.first.dx, maxX = s.first.dx, minY = s.first.dy, maxY = s.first.dy;
      for (final p in s) {
        if (p.dx < minX) minX = p.dx;
        if (p.dx > maxX) maxX = p.dx;
        if (p.dy < minY) minY = p.dy;
        if (p.dy > maxY) maxY = p.dy;
      }
      final isHeader = n > 1 && maxX - minX > colW * 1.3 && maxY - minY < height * 0.18;
      if (isHeader) {
        header = true;
        for (int c = 0; c < n; c++) {
          final seg = s.where((p) => p.dx >= c * colW && p.dx < (c + 1) * colW).toList();
          if (seg.length > 1) parts[c].add(seg);
        }
      } else {
        final c = (((minX + maxX) / 2) / colW).floor().clampI(0, n - 1);
        parts[c].add(s);
      }
    }
    final scores = [
      for (int c = 0; c < n; c++)
        parts[c].isEmpty ? 0 : evaluateStrokesByCharacter(parts[c], word.units[c], colW).accuracy,
    ];
    var acc = (scores.fold<int>(0, (a, b) => a + b) / n).round();
    if (n > 1 && !header) acc = (acc - 8).clamp(0, 100); // the header line is part of writing a word
    return _WordCheck(scores, header || n == 1, acc);
  }

  void _checkWord(double width, double height) {
    if (wordDraw.isEmpty) return;
    _WordCheck c;
    try {
      c = _gradeWord(width, height);
    } catch (e, st) {
      CrashReporter.record(e, st, reason: 'word check ${word.word}');
      wordDraw.clear();
      showInfoDialog(context, 'Try again', "We couldn't check that one. Please write the word again.");
      return;
    }
    // Good writes count as a repetition; an excellent one counts double, so
    // a child who already writes the word well finishes sooner.
    final gained = c.accuracy >= 92 ? 2 : c.accuracy >= 60 ? 1 : 0;
    final newDone = (repsDone + gained).clamp(0, repsNeeded);
    context.read<AppStore>().recordWordAttempt(word.word, c.accuracy, countsAsRep: gained > 0);
    setState(() {
      check = c;
      repsDone = newDone;
      if (c.accuracy > (bestAcc[wi] ?? -1)) bestAcc[wi] = c.accuracy;
      repNote = gained == 2 ? 'Excellent — counts as 2 practices!'
          : gained == 1 ? 'Good — 1 practice done.'
          : 'Below 60% — this one doesn\'t count yet. Use Hint and try again.';
      if (repsDone >= repsNeeded) { doneWords.add(wi); confetti = true; }
    });
    wordDraw.locked = true;
    gained > 0 ? hapticSuccess() : hapticMedium();
    if (repsDone >= repsNeeded) speakHindi(word.word, rate: 0.8);
  }

  void _writeAgain() {
    wordDraw.clear(); wordDraw.locked = false;
    setState(() => check = null);
  }

  void _nextWord() {
    if (doneWords.length == words.length) { _finishSession(); return; }
    // Next unfinished word after this one (wrapping around).
    for (int k = 1; k <= words.length; k++) {
      final j = (wi + k) % words.length;
      if (!doneWords.contains(j)) { _enterWord(j); return; }
    }
  }

  void _finishSession() {
    setState(() => sessionComplete = true);
    final aId = widget.params['activityId'], lvl = widget.params['levelNumber'];
    if (aId is String && lvl is int) context.read<AppStore>().completeActivityLevel(aId, lvl);
  }

  // ──────────────────────── Letter section ────────────────────────

  void _checkLetter(double size) {
    if (letterDraw.isEmpty) return;
    StrictEvaluationResult r;
    try {
      r = evaluateLetterStrict(letterDraw.strokes, unit, size);
    } catch (e, st) {
      CrashReporter.record(e, st, reason: 'letter check $unit');
      letterDraw.clear();
      return;
    }
    final ok = r.stars >= 2 && r.isTargetBestMatch;
    setState(() { letterResult = r; letterTries++; if (ok) lettersDone.add(li); });
    letterDraw.locked = true;
    ok ? hapticSuccess() : hapticMedium();
    final id = templateForCharacter(unit)?.letterId;
    if (id != null && unit.length == 1) {
      final store = context.read<AppStore>();
      store.letterProgress.putIfAbsent(id, () => LetterProgress(letterId: id));
      store.recordAttempt(id, r.stars, accuracy: r.accuracy);
    }
  }

  void _letterAgain() {
    letterDraw.clear(); letterDraw.locked = false;
    setState(() => letterResult = null);
  }

  void _nextLetter() {
    letterDraw.clear(); letterDraw.locked = false;
    if (li < word.units.length - 1) {
      setState(() { li++; letterResult = null; letterTries = 0; letterHint = true; });
      _say(unit, rate: 0.6);
    } else {
      setState(() { letterResult = null; confetti = true; });
      speakHindi(word.word, rate: 0.8);
    }
  }

  // ─────────────────────────── Build ───────────────────────────

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Stack(children: [
          Column(children: [
            HeaderBar(
              title: 'Word Writing', subtitle: 'शब्द लेखन',
              onBack: () => Navigator.of(context).maybePop(),
              rightAction: GestureDetector(
                onTap: () => openScreen(context, 'RoughPad', {'words': [for (final x in words) x.word]}),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: Sp.sm, vertical: 6),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(Rad.md),
                      border: Border.all(color: AppColors.border)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.edit_note, size: 20, color: AppColors.secondary),
                    const SizedBox(width: 2),
                    Text('Rough', style: Fonts.body(12, w: FontWeight.w800, color: AppColors.secondary)),
                  ]),
                ),
              ),
            ),
            if (sessionComplete)
              Expanded(child: _complete())
            else ...[
              _sectionTabs(),
              _wordStrip(),
              Expanded(child: screenScroll(maxWidth: 600, child: letterSection ? _letterSection(w) : _wordSection(w))),
            ],
          ]),
          Positioned.fill(child: Confetti(visible: confetti, onComplete: () => setState(() => confetti = false))),
        ]),
      ),
    );
  }

  Widget _sectionTabs() {
    Widget tab(String hi, String en, IconData icon, bool value) {
      final on = letterSection == value;
      return Expanded(child: GestureDetector(
        onTap: () {
          if (on) return;
          setState(() { letterSection = value; letterResult = null; check = null; });
          wordDraw.clear(); wordDraw.locked = false; letterDraw.clear(); letterDraw.locked = false;
          _say(value ? unit : word.word, rate: value ? 0.6 : 0.7);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: Sp.sm),
          decoration: BoxDecoration(
            color: on ? (value ? AppColors.secondary : AppColors.primary) : AppColors.surface,
            borderRadius: BorderRadius.circular(Rad.lg),
            border: Border.all(color: on ? Colors.transparent : AppColors.border),
            boxShadow: on ? toyShadow(value ? AppColors.secondaryDark : AppColors.primaryDark, 3) : null,
          ),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 18, color: on ? AppColors.textOnPrimary : AppColors.textSecondary),
              const SizedBox(width: 6),
              Flexible(child: Text(en, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: Fonts.body(14, w: FontWeight.w800, color: on ? AppColors.textOnPrimary : AppColors.textSecondary))),
            ]),
            Text(hi, style: Fonts.hindi(13, color: on ? AppColors.textOnPrimary : AppColors.textSecondary)),
          ]),
        ),
      ));
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.md, 0, Sp.md, Sp.sm),
      child: Row(children: [
        tab('शब्द लेखन', 'Word Writing', Icons.short_text, false),
        const SizedBox(width: Sp.sm),
        tab('अक्षर लेखन', 'Letter Writing', Icons.text_fields, true),
      ]),
    );
  }

  /// Every word of the level, so the child sees the whole set and can jump.
  Widget _wordStrip() => SizedBox(
        height: 58,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: Sp.md),
          itemCount: words.length,
          separatorBuilder: (_, __) => const SizedBox(width: Sp.sm),
          itemBuilder: (_, i) {
            final cur = i == wi, done = doneWords.contains(i);
            return GestureDetector(
              onTap: () => _enterWord(i),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: Sp.md),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: cur ? AppColors.primary.withOpacity(0.12) : done ? AppColors.success.withOpacity(0.1) : AppColors.surface,
                  borderRadius: BorderRadius.circular(Rad.md),
                  border: Border.all(color: cur ? AppColors.primary : done ? AppColors.success : AppColors.border, width: cur ? 2 : 1),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(_dictation && !done ? '${i + 1}' : words[i].word,
                      style: Fonts.hindi(20, color: done ? AppColors.successDark : AppColors.textPrimary, height: 1.3)),
                  if (done) ...[const SizedBox(width: 4), const Icon(Icons.check_circle, size: 16, color: AppColors.success)],
                  if (bestAcc[i] != null && !done) ...[
                    const SizedBox(width: 4),
                    Text('${bestAcc[i]}%', style: Fonts.body(11, w: FontWeight.w800, color: AppColors.textSecondary)),
                  ],
                ]),
              ),
            );
          },
        ),
      );

  Widget _wordCard({bool showWord = true}) {
    final skill = context.select<AppStore, int?>((s) => s.wordSkill[word.word]);
    return ToyCard(
      radius: Rad.xl2, padding: const EdgeInsets.all(Sp.md), margin: const EdgeInsets.symmetric(vertical: Sp.sm),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(showWord ? word.word : '🔊  ? ? ?', style: Fonts.hindi(40, height: 1.3, color: AppColors.textPrimary)),
          Text(word.meaning, style: Fonts.body(15, w: FontWeight.w700, color: AppColors.textSecondary)),
          if (skill != null) Text('Your skill on this word: $skill%',
              style: Fonts.body(12, w: FontWeight.w700, color: AppColors.secondary)),
        ])),
        GestureDetector(
          onTap: () => speakHindi(word.word, rate: 0.7),
          child: Container(width: 52, height: 52,
              decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle, boxShadow: toyShadow(AppColors.primaryDark, 4)),
              child: const Icon(Icons.volume_up, size: 26, color: AppColors.textOnPrimary)),
        ),
      ]),
    );
  }

  /// "Practice 2 of 4" with one dot per required repetition.
  Widget _repsBar() => Container(
        padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.sm),
        decoration: BoxDecoration(color: AppColors.secondary.withOpacity(0.08), borderRadius: BorderRadius.circular(Rad.lg),
            border: Border.all(color: AppColors.secondary.withOpacity(0.3))),
        child: Row(children: [
          const Icon(Icons.repeat, size: 18, color: AppColors.secondary),
          const SizedBox(width: Sp.sm),
          Expanded(child: Text(
              repsDone >= repsNeeded ? 'Word practiced ✓' : 'Write it $repsNeeded× · done $repsDone',
              style: Fonts.body(13, w: FontWeight.w800, color: AppColors.secondary))),
          for (int i = 0; i < repsNeeded; i++)
            Padding(padding: const EdgeInsets.only(left: 4), child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 14, height: 14,
              decoration: BoxDecoration(shape: BoxShape.circle,
                  color: i < repsDone ? AppColors.success : AppColors.surface,
                  border: Border.all(color: i < repsDone ? AppColors.success : AppColors.secondary.withOpacity(0.4), width: 2)),
            )),
        ]),
      );

  /// One small box per block with its numbered stroke order; tap for a big animated demo.
  Widget _referenceStrip() => FittedBox(fit: BoxFit.scaleDown, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (int i = 0; i < word.units.length; i++) ...[
          if (i > 0) const SizedBox(width: Sp.sm),
          GestureDetector(
            onTap: () => _showGuideSheet(word.units[i]),
            child: Container(
              width: 74, height: 74,
              decoration: BoxDecoration(color: AppColors.canvasBackground, borderRadius: BorderRadius.circular(Rad.md),
                  border: Border.all(color: AppColors.border)),
              clipBehavior: Clip.antiAlias,
              child: Stack(children: [
                const Positioned.fill(child: CustomPaint(painter: WritingGuidePainter(labels: false))),
                Positioned.fill(child: StrokeOrderGuide(character: word.units[i], showNumbers: false)),
                Positioned(right: 3, bottom: 1, child: Text(word.units[i], style: Fonts.hindi(13, color: AppColors.textSecondary))),
              ]),
            ),
          ),
        ],
      ]));

  void _showGuideSheet(String text) {
    speakHindi(text, rate: 0.6);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Rad.xl))),
      builder: (_) => SafeArea(child: Padding(
        padding: const EdgeInsets.all(Sp.lg),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('How to write  $text', style: Fonts.display(20)),
          Text('Start at the green dot · follow the numbers · stop at the red dot',
              textAlign: TextAlign.center, style: Fonts.body(13, w: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: Sp.md),
          Container(
            width: 280, height: 280,
            decoration: BoxDecoration(color: AppColors.canvasBackground, borderRadius: BorderRadius.circular(Rad.lg),
                border: Border.all(color: AppColors.border)),
            clipBehavior: Clip.antiAlias,
            child: Stack(children: [
              const Positioned.fill(child: CustomPaint(painter: WritingGuidePainter())),
              Positioned.fill(child: AnimatedStrokeGuide(character: text)),
            ]),
          ),
          const SizedBox(height: Sp.md),
          _strokeLegend(text),
        ]),
      )),
    );
  }

  Widget _strokeLegend(String text) {
    final n = strokesForText(text)?.length ?? 0;
    return Wrap(alignment: WrapAlignment.center, spacing: Sp.md, runSpacing: 4, children: [
      for (int k = 0; k < n; k++) Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 14, height: 4, color: kStrokeColors[k % kStrokeColors.length]),
        const SizedBox(width: 4),
        Text('Stroke ${k + 1}', style: Fonts.body(12, w: FontWeight.w700, color: AppColors.textSecondary)),
      ]),
    ]);
  }

  Widget _wordSection(double screenW) {
    final n = word.units.length;
    final canvasW = (screenW - Sp.md * 2).clampD(260.0, 568.0);
    final canvasH = (canvasW / n * 1.05).clampD(150.0, 220.0);
    final reveal = !_dictation || check != null;
    return Column(children: [
      _wordCard(showWord: reveal),
      _repsBar(),
      const SizedBox(height: Sp.md),
      if (reveal) ...[
        Text('Stroke order — tap a block to watch it', style: Fonts.body(13, w: FontWeight.w700, color: AppColors.textSecondary)),
        const SizedBox(height: Sp.xs),
        _referenceStrip(),
        const SizedBox(height: Sp.md),
      ] else
        Padding(padding: const EdgeInsets.only(bottom: Sp.md), child: Text('Dictation: listen and write the word you hear',
            style: Fonts.body(14, w: FontWeight.w700, color: AppColors.textSecondary))),
      Text('Write the whole word on the line — one block per box, header line across the top',
          textAlign: TextAlign.center, style: Fonts.body(14, w: FontWeight.w600, color: AppColors.textSecondary)),
      const SizedBox(height: Sp.sm),
      Container(
        width: canvasW, height: canvasH,
        decoration: BoxDecoration(color: AppColors.canvasBackground, borderRadius: BorderRadius.circular(Rad.xl),
            border: Border.all(color: AppColors.border, width: 2), boxShadow: toyShadow(AppColors.toyShadowColor, 4)),
        clipBehavior: Clip.antiAlias,
        child: Stack(children: [
          const Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: WritingGuidePainter()))),
          Positioned.fill(child: IgnorePointer(child: Row(children: [
            for (int i = 0; i < n; i++) Expanded(child: Container(
              decoration: BoxDecoration(
                color: check == null ? null
                    : (check!.unitScores[i] >= 60 ? AppColors.success : AppColors.error).withOpacity(0.08),
                border: i == 0 ? null : Border(left: BorderSide(color: AppColors.border.withOpacity(0.8), width: 1)),
              ),
              child: Stack(children: [
                if (wordHint && reveal) Positioned.fill(child: Opacity(opacity: 0.85,
                    child: StrokeOrderGuide(character: word.units[i]))),
                if (check != null) Positioned(left: 0, right: 0, bottom: 2, child: Text('${word.units[i]} ${check!.unitScores[i]}%',
                    textAlign: TextAlign.center,
                    style: Fonts.body(12, w: FontWeight.w800, color: check!.unitScores[i] >= 60 ? AppColors.successDark : AppColors.error))),
              ]),
            )),
          ]))),
          Positioned.fill(child: DrawSurface(controller: wordDraw,
              child: RepaintBoundary(child: CustomPaint(painter: StrokePainterPublic(wordDraw, AppColors.primaryDark, 5))))),
        ]),
      ),
      const SizedBox(height: Sp.md),
      if (check == null)
        AnimatedBuilder(animation: wordDraw, builder: (_, __) {
          final empty = wordDraw.isEmpty;
          return Row(children: [
            Expanded(child: ResultButton(label: wordHint ? 'Hide' : 'Hint', icon: Icons.lightbulb_outline, filled: wordHint,
                color: const Color(0xFFE0A800),
                onTap: reveal ? () => setState(() => wordHint = !wordHint) : null)),
            const SizedBox(width: Sp.sm),
            SizedBox(width: 56, child: ResultButton(label: '', icon: Icons.undo, filled: false, onTap: empty ? null : wordDraw.undo)),
            const SizedBox(width: Sp.sm),
            SizedBox(width: 56, child: ResultButton(label: '', icon: Icons.delete_outline, filled: false, color: AppColors.error,
                onTap: empty ? null : wordDraw.clear)),
            const SizedBox(width: Sp.sm),
            Expanded(child: ResultButton(label: 'Check', icon: Icons.check, color: AppColors.success,
                onTap: empty ? null : () => _checkWord(canvasW, canvasH))),
          ]);
        })
      else
        PopIn(key: ValueKey('w$wi-$repsDone-${check.hashCode}'), child: _wordResult()),
      const SizedBox(height: Sp.xxl),
    ]);
  }

  Widget _wordResult() {
    final c = check!;
    final finished = repsDone >= repsNeeded;
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(Sp.lg),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(Rad.xl),
          border: Border.all(color: finished ? AppColors.success : AppColors.border, width: 2),
          boxShadow: toyShadow(AppColors.toyShadowColor, 4)),
      child: Column(children: [
        if (finished) Text('Word practiced! 🎉', style: Fonts.display(22, color: AppColors.success)),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          StarRating(stars: starsForAccuracy(c.accuracy), size: 32),
          const SizedBox(width: Sp.md),
          Text('${c.accuracy}%', style: Fonts.display(28, color: AppColors.primaryDark)),
        ]),
        const SizedBox(height: Sp.xs),
        Text(repNote, textAlign: TextAlign.center, style: Fonts.body(14, w: FontWeight.w700, color: AppColors.textSecondary)),
        if (!c.headerDrawn) Padding(
          padding: const EdgeInsets.only(top: Sp.sm),
          child: Text('Draw one header line (शिरोरेखा) across the whole word — it joins the letters.',
              textAlign: TextAlign.center, style: Fonts.body(13, w: FontWeight.w700, color: AppColors.error)),
        ),
        if (c.unitScores.any((s) => s < 60)) Padding(
          padding: const EdgeInsets.only(top: Sp.sm),
          child: Text('Practise ${[for (int i = 0; i < c.unitScores.length; i++) if (c.unitScores[i] < 60) word.units[i]].join(', ')} '
              'in Letter Writing, or tap it above to watch the strokes.',
              textAlign: TextAlign.center, style: Fonts.body(13, w: FontWeight.w600, color: AppColors.textSecondary)),
        ),
        const SizedBox(height: Sp.md),
        Row(children: [
          Expanded(child: ResultButton(label: finished ? 'Extra practice' : 'Write again', icon: Icons.refresh, filled: !finished,
              onTap: _writeAgain)),
          const SizedBox(width: Sp.sm),
          Expanded(child: ResultButton(
              label: doneWords.length == words.length ? 'Finish' : 'Next word', icon: Icons.arrow_forward,
              filled: finished, color: AppColors.success,
              onTap: _nextWord)),
        ]),
      ]),
    );
  }

  Widget _letterSection(double screenW) {
    final size = (screenW - Sp.md * 2).clampD(220.0, 340.0);
    final allDone = lettersDone.length == word.units.length;
    final r = letterResult;
    return Column(children: [
      _wordCard(),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (int i = 0; i < word.units.length; i++) ...[
          if (i > 0) const SizedBox(width: Sp.sm),
          GestureDetector(
            onTap: () { letterDraw.clear(); letterDraw.locked = false;
              setState(() { li = i; letterResult = null; letterTries = 0; letterHint = true; }); _say(unit, rate: 0.6); },
            child: Container(
              width: 56, height: 62, alignment: Alignment.center,
              decoration: BoxDecoration(
                color: i == li ? AppColors.secondary : lettersDone.contains(i) ? AppColors.success.withOpacity(0.1) : AppColors.surface,
                borderRadius: BorderRadius.circular(Rad.lg),
                border: Border.all(color: i == li ? AppColors.secondary : lettersDone.contains(i) ? AppColors.success : AppColors.border, width: 2),
                boxShadow: i == li ? toyShadow(AppColors.secondaryDark, 3) : null),
              child: Text(word.units[i], style: Fonts.hindi(28, height: 1.3,
                  color: i == li ? AppColors.textOnPrimary : lettersDone.contains(i) ? AppColors.successDark : AppColors.textPrimary)),
            ),
          ),
        ],
      ]),
      const SizedBox(height: Sp.md),
      if (allDone && r == null) ...[
        PopIn(child: ToyCard(padding: const EdgeInsets.all(Sp.lg), child: SizedBox(width: double.infinity, child: Column(children: [
          Text('All letters written! ✨', style: Fonts.display(22, color: AppColors.success)),
          const SizedBox(height: Sp.xs),
          Text('Now join them: write the whole word in Word Writing.', textAlign: TextAlign.center,
              style: Fonts.body(14, w: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: Sp.md),
          ResultButton(label: 'Go to Word Writing', icon: Icons.short_text, onTap: () {
            setState(() { letterSection = false; check = null; });
            wordDraw.clear(); wordDraw.locked = false;
            _say(word.word);
          }),
        ])))),
      ] else ...[
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('Write  ', style: Fonts.body(16, w: FontWeight.w700, color: AppColors.textSecondary)),
          Text(unit, style: Fonts.hindi(28, color: AppColors.secondary)),
          const SizedBox(width: Sp.sm),
          SoftPill(icon: Icons.volume_up, label: 'Hear', onTap: () => speakHindi(unit, rate: 0.6)),
        ]),
        const SizedBox(height: Sp.sm),
        SimpleCanvas(controller: letterDraw, size: size, stroke: AppColors.primaryDark,
            underlay: letterHint ? Opacity(opacity: 0.75, child: AnimatedStrokeGuide(character: unit)) : null),
        const SizedBox(height: Sp.xs),
        if (letterHint) _strokeLegend(unit),
        const SizedBox(height: Sp.md),
        if (r == null)
          AnimatedBuilder(animation: letterDraw, builder: (_, __) {
            final empty = letterDraw.isEmpty;
            return Row(children: [
              Expanded(child: ResultButton(label: letterHint ? 'Hide' : 'Hint', icon: Icons.lightbulb_outline, filled: letterHint,
                  color: const Color(0xFFE0A800), onTap: () => setState(() => letterHint = !letterHint))),
              const SizedBox(width: Sp.sm),
              SizedBox(width: 56, child: ResultButton(label: '', icon: Icons.undo, filled: false, onTap: empty ? null : letterDraw.undo)),
              const SizedBox(width: Sp.sm),
              SizedBox(width: 56, child: ResultButton(label: '', icon: Icons.delete_outline, filled: false, color: AppColors.error,
                  onTap: empty ? null : letterDraw.clear)),
              const SizedBox(width: Sp.sm),
              Expanded(child: ResultButton(label: 'Check', icon: Icons.check, color: AppColors.success,
                  onTap: empty ? null : () => _checkLetter(size))),
            ]);
          })
        else
          PopIn(key: ValueKey('l$li-$letterTries'), child: _letterResultCard(r)),
      ],
      const SizedBox(height: Sp.xxl),
    ]);
  }

  Widget _letterResultCard(StrictEvaluationResult r) {
    final ok = lettersDone.contains(li);
    final wrong = !r.isTargetBestMatch && r.bestMatchCharacter != null;
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(Sp.lg),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(Rad.xl),
          border: Border.all(color: ok ? AppColors.success : AppColors.border, width: 2), boxShadow: toyShadow(AppColors.toyShadowColor, 4)),
      child: Column(children: [
        Text(ok ? 'Well written!' : wrong ? 'That looks like ${r.bestMatchCharacter}' : 'Not quite $unit yet',
            style: Fonts.display(20, color: ok ? AppColors.success : AppColors.primaryDark)),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          StarRating(stars: r.stars, size: 30),
          const SizedBox(width: Sp.md),
          Text('${r.accuracy}%', style: Fonts.display(24, color: AppColors.primaryDark)),
        ]),
        const SizedBox(height: Sp.sm),
        ScoreBreakdown(r),
        if (getActionableTip(r, templateForCharacter(unit)?.letterId ?? '') case final tip? when !ok)
          Padding(padding: const EdgeInsets.only(top: Sp.sm),
              child: Text(tip, textAlign: TextAlign.center, style: Fonts.body(13, w: FontWeight.w600, color: AppColors.textSecondary))),
        const SizedBox(height: Sp.md),
        Row(children: [
          Expanded(child: ResultButton(label: 'Try again', icon: Icons.refresh, filled: !ok, onTap: _letterAgain)),
          const SizedBox(width: Sp.sm),
          // After 3 tries the child may move on even without 2 stars.
          Expanded(child: ResultButton(label: li < word.units.length - 1 ? 'Next letter' : 'Done', icon: Icons.arrow_forward,
              filled: ok, color: AppColors.success,
              onTap: ok || letterTries >= 3 ? () { if (!ok) lettersDone.add(li); _nextLetter(); } : null)),
        ]),
      ]),
    );
  }

  Widget _complete() {
    final avg = bestAcc.isEmpty ? 0 : (bestAcc.values.fold<int>(0, (a, b) => a + b) / bestAcc.length).round();
    return SessionCompleteCard(
      emoji: avg >= 85 ? '🏆' : avg >= 70 ? '🎉' : '✍️',
      title: 'All Words Practiced!', stars: starsForAccuracy(avg),
      stats: [('${words.length}', 'Words'), ('$avg%', 'Best avg')],
      message: 'Words you write well will need fewer repetitions next time.',
      retryLabel: 'Practise Again',
      onRetry: () { doneWords.clear(); bestAcc.clear(); setState(() => sessionComplete = false); _enterWord(0); },
      onDone: () => Navigator.of(context).maybePop(),
    );
  }
}
