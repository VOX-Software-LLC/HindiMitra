import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../data/matra_course.dart';
import '../../data/models.dart';
import '../../services/feedback.dart';
import '../../services/matra_checker.dart';
import '../../services/speech_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../../widgets/common.dart';
import '../../widgets/draw_canvas.dart';
import '../../widgets/matra_canvas.dart';
import '../../widgets/quiz_common.dart';
import '../../widgets/toy_button.dart';
import 'matra_text.dart';

/// One round of the matra course: the [matra] the child learns and the real
/// [word] they use it in. "Matra Magic" starts from [from]; "Fix the sign"
/// starts from the misspelt blocks in [wrong].
class MatraRound {
  final Matra matra;
  final MatraWord word;
  final MatraWord? from;
  final List<String>? wrong;
  const MatraRound(this.matra, this.word, {this.from, this.wrong});
  String get sign => matra.symbol;
  String get base => word.base;
  String get syllable => word.unit;
}

class RoundResult {
  /// 0-100 writing score for the round, and wrong taps in the other steps.
  final int accuracy, mistakes;
  final bool passed;
  const RoundResult(this.accuracy, this.mistakes, this.passed);
}

/// Signs a child is likely to confuse with each one (used for the choices).
const _confusable = <String, List<String>>{
  'ा': ['ि', 'ो'], 'ि': ['ी', 'ा'], 'ी': ['ि', 'े'], 'ु': ['ू', 'ृ'], 'ू': ['ु', 'ो'], 'ृ': ['ु', 'ू'],
  'े': ['ै', 'ो'], 'ै': ['े', 'ौ'], 'ो': ['ौ', 'ा'], 'ौ': ['ो', 'ै'], 'ं': ['ः', 'े'], 'ः': ['ं', 'ा'],
};

/// [sign] plus confusable signs (and [also] when given), shuffled, [n] in all.
List<String> signChoices(String sign, {String? also, int n = 3}) {
  final out = <String>{sign, if (also != null && also.isNotEmpty) also, ...?_confusable[sign]};
  return shuffled(out.take(n));
}

enum _Phase { challenge, see, write, use }

/// Plays one [MatraRound]: the level's own challenge ([game]), then
/// See (the sign animates onto the letter, with sound), Write (only the sign,
/// in the right spot) and Use (complete a real word).
class MatraRoundView extends StatefulWidget {
  final MatraRound round;
  final String game;
  /// Light up where the sign goes while writing (the early levels).
  final bool guided;
  final ValueChanged<RoundResult> onDone;
  const MatraRoundView({super.key, required this.round, required this.game, required this.onDone, this.guided = false});
  @override
  State<MatraRoundView> createState() => _MatraRoundViewState();
}

class _MatraRoundViewState extends State<MatraRoundView> with SingleTickerProviderStateMixin {
  late final MatraGlyph glyph = MatraGlyph.of(r.base, r.sign)!;
  late final reveal = AnimationController(vsync: this, duration: Duration(milliseconds: fast ? 700 : 1600));
  final draw = DrawController();
  late _Phase phase = _hasChallenge ? _Phase.challenge : _Phase.see;
  int mistakes = 0, attempts = 0, best = 0, pickStep = 0;
  bool checking = false, passed = false, canMoveOn = false, ghost = false, filled = false;
  String? message, hintZone, wrongChoice;
  bool messageGood = false;
  late List<String> choices = _initialChoices();
  Timer? _timer;

  MatraRound get r => widget.round;
  bool get fast => widget.game == 'speed';
  bool get listenOnly => widget.game == 'dictation';
  bool get _hasChallenge =>
      const {'where', 'shortLong', 'flags', 'build', 'detective', 'magic', 'fix'}.contains(widget.game);

  @override
  void initState() {
    super.initState();
    if (phase == _Phase.see) {
      _startSee();
    } else {
      _startChallenge();
    }
  }

  @override
  void dispose() { _timer?.cancel(); reveal.dispose(); draw.dispose(); super.dispose(); }

  void _go(_Phase p) {
    if (!mounted) return;
    setState(() {
      phase = p; message = null; hintZone = null; wrongChoice = null;
    });
    if (p == _Phase.see) _startSee();
    if (p == _Phase.write) {
      setState(() { if (widget.guided) hintZone = r.matra.position; reveal.value = 0; ghost = true; });
    }
    if (p == _Phase.use) _startUse();
  }

  // ── Challenge ──
  List<String> _initialChoices() => switch (widget.game) {
        'shortLong' => const {'ि', 'ी'}.contains(r.sign) ? ['ि', 'ी'] : ['ु', 'ू'],
        'flags' => ['े', 'ै'],
        'build' => shuffled(['ो', 'ौ', 'ै']),
        'detective' => shuffled(['ृ', 'ं', 'ः']),
        'magic' => signChoices(r.sign, also: matraOf(r.from!.unit)),
        'fix' => signChoices(r.sign, also: matraOf(r.wrong![r.word.slot])),
        _ => signChoices(r.sign),
      };

  void _startChallenge() {
    switch (widget.game) {
      case 'shortLong' || 'flags': speakHindi(r.syllable, rate: 0.5);
      case 'detective': speakHindi(r.word.word, rate: 0.55);
      case 'magic': speakHindi(r.from!.word, rate: 0.6);
    }
  }

  void _wrong(String hint) {
    hapticError();
    setState(() { mistakes++; message = hint; messageGood = false; });
  }

  void _challengeDone() {
    hapticSuccess();
    setState(() { message = null; wrongChoice = null; });
    _timer = Timer(const Duration(milliseconds: 350), () => _go(_Phase.see));
  }

  void _pickSign(String s) {
    if (s == r.sign) {
      _challengeDone();
    } else {
      setState(() => wrongChoice = s);
      _wrong(MT.tryAgainFriendly);
      if (widget.game == 'shortLong' || widget.game == 'flags') speakHindi(r.syllable, rate: 0.5);
    }
  }

  void _pickPlace(String pos) {
    if (pos == r.matra.position) {
      _challengeDone();
    } else {
      setState(() => wrongChoice = pos);
      _wrong(MT.placeHint(r.sign, r.matra.position));
    }
  }

  void _pickSyllable(int i) {
    if (i == r.word.slot) {
      hapticSuccess();
      setState(() { pickStep = 1; message = null; });
    } else {
      _wrong(MT.notThisPart);
    }
  }

  // ── See ──
  Future<void> _startSee() async {
    setState(() => ghost = false);
    if (listenOnly) {
      await speakHindi(r.syllable, rate: 0.5);
      await speakHindi(r.word.word, rate: 0.6);
      return;
    }
    await reveal.forward(from: 0);
    if (!mounted) return;
    await speakHindi(r.syllable, rate: 0.5);
    if (fast && mounted && phase == _Phase.see) _go(_Phase.write);
  }

  // ── Write ──
  Future<void> _check(MatraFrame frame) async {
    if (checking || passed) return;
    if (draw.isEmpty) {
      setState(() { message = MT.drawFirst; messageGood = false; });
      return;
    }
    setState(() => checking = true);
    final v = await gradeMatra(draw.strokes.map((s) => [...s]).toList(), glyph, r.matra.position, frame);
    if (!mounted) return;
    attempts++;
    if (v.placedRight) best = math.max(best, v.accuracy);
    setState(() {
      checking = false;
      if (v.passed) {
        passed = true; draw.locked = true; messageGood = true; hintZone = null;
        message = '${MT.greatPlace} ${'⭐' * v.stars}';
      } else {
        messageGood = false;
        if (!v.placedRight) {
          hintZone = r.matra.position;
          message = MT.placeHint(r.sign, r.matra.position);
        } else {
          message = v.readAs != null ? MT.looksLike(v.readAs!) : MT.nearlyShape;
          ghost = true;
          reveal.forward(from: 0);
        }
        if (attempts >= 3) { canMoveOn = true; message = MT.letsMoveOn; }
      }
    });
    if (v.passed) {
      hapticSuccess();
      await speakHindi(r.syllable, rate: 0.55);
      if (fast && mounted) _go(_Phase.use);
    } else {
      hapticError();
    }
  }

  void _showMe() {
    setState(() => ghost = true);
    reveal.forward(from: 0);
    speakHindi(r.syllable, rate: 0.5);
  }

  // ── Use ──
  void _startUse() {
    choices = signChoices(r.sign);
    // Magic and Fix already chose the sign: the word changes in front of them.
    if (r.from != null || r.wrong != null) {
      setState(() => filled = true);
      _sayWords();
    }
  }

  Future<void> _sayWords() async {
    if (r.from != null) await speakHindi(r.from!.word, rate: 0.6);
    await speakHindi(r.word.word, rate: 0.6);
    if (fast && mounted) _finish();
  }

  void _fill(String s) {
    if (filled) return;
    if (s == r.sign) {
      hapticSuccess();
      setState(() { filled = true; message = null; wrongChoice = null; });
      _sayWords();
    } else {
      setState(() => wrongChoice = s);
      _wrong(MT.notThatOne);
    }
  }

  void _finish() {
    final acc = passed ? math.max(kMatraPass, best - 6 * (attempts - 1)) : (best * 0.5).round();
    widget.onDone(RoundResult(acc, mistakes, passed));
  }

  // ── UI ──
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (_, c) {
        final w = math.min(c.maxWidth, 520.0);
        return Column(children: [
          _steps(),
          const SizedBox(height: Sp.md),
          switch (phase) {
            _Phase.challenge => _challenge(),
            _Phase.see => _see(w),
            _Phase.write => _write(w),
            _Phase.use => _use(),
          },
          if (message != null) Padding(
            padding: const EdgeInsets.only(top: Sp.md),
            child: PopIn(key: ValueKey(message), child: _bubble(message!, messageGood)),
          ),
        ]);
      });

  Widget _steps() {
    final cur = phase == _Phase.use ? 2 : phase == _Phase.write ? 1 : phase == _Phase.see ? 0 : -1;
    Widget chip(int i, String emoji, String label) {
      final on = i == cur, done = i < cur;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: on ? AppColors.primary : done ? AppColors.success.withOpacity(0.15) : AppColors.surface,
          borderRadius: BorderRadius.circular(9999),
          border: Border.all(color: on ? AppColors.primary : done ? AppColors.success : AppColors.border)),
        child: Text('${done ? '✓' : emoji} $label',
            style: Fonts.body(13, w: FontWeight.w800, color: on ? AppColors.textOnPrimary : AppColors.textSecondary)),
      );
    }
    return Wrap(alignment: WrapAlignment.center, spacing: Sp.sm, runSpacing: Sp.xs, children: [
      chip(0, '👀', MT.stepSee), chip(1, '✍️', MT.stepWrite), chip(2, '🧩', MT.stepUse),
    ]);
  }

  Widget _bubble(String text, bool good) => Container(
        width: double.infinity, padding: const EdgeInsets.all(Sp.md),
        decoration: BoxDecoration(
          color: (good ? AppColors.success : AppColors.warning).withOpacity(0.16),
          borderRadius: BorderRadius.circular(Rad.lg),
          border: Border.all(color: (good ? AppColors.success : AppColors.warning).withOpacity(0.6))),
        child: Row(children: [
          Text(good ? '🎉' : '💡', style: const TextStyle(fontSize: 22)),
          const SizedBox(width: Sp.sm),
          Expanded(child: Text(text, style: Fonts.body(16, w: FontWeight.w700))),
        ]),
      );

  Widget _prompt(String t) => Padding(
        padding: const EdgeInsets.only(bottom: Sp.md),
        child: Text(t, textAlign: TextAlign.center, style: Fonts.display(20)),
      );

  Widget _challenge() {
    switch (widget.game) {
      case 'where':
        return Column(children: [_prompt(MT.whereGoes(r.sign)), _whereBoard()]);
      case 'magic':
        final f = r.from!;
        return Column(children: [
          _prompt(MT.magicGoal(f.meaning, r.word.meaning)),
          _wordTiles(f.units, highlight: pickStep == 1 ? f.slot : null, onTap: pickStep == 0 ? _pickSyllable : null),
          const SizedBox(height: Sp.sm),
          HearButton(onTap: () => speakHindi(f.word, rate: 0.6), label: f.word),
          const SizedBox(height: Sp.md),
          Text(pickStep == 0 ? MT.tapSyllableToChange : MT.pickNewSign,
              style: Fonts.body(16, w: FontWeight.w700, color: AppColors.textSecondary)),
          if (pickStep == 1) ...[const SizedBox(height: Sp.md), _signButtons(choices, _pickSign)],
        ]);
      case 'fix':
        return Column(children: [
          _prompt(MT.fixGoal(r.word.meaning)),
          _wordTiles(r.wrong!, highlight: pickStep == 1 ? r.word.slot : null, onTap: pickStep == 0 ? _pickSyllable : null),
          const SizedBox(height: Sp.md),
          Text(pickStep == 0 ? MT.tapSyllableToChange : MT.pickRightSign,
              style: Fonts.body(16, w: FontWeight.w700, color: AppColors.textSecondary)),
          if (pickStep == 1) ...[const SizedBox(height: Sp.md), _signButtons(choices, _pickSign)],
        ]);
      case 'build':
        final parts = r.sign == 'ो' ? ('ा', 'े') : ('ा', 'ै');
        return Column(children: [
          _prompt(MT.matraMaths(parts.$1, parts.$2)),
          Text('◌${parts.$1}  +  ◌${parts.$2}  =  ?', style: Fonts.hindi(44, color: AppColors.primaryDark)),
          const SizedBox(height: Sp.lg),
          _signButtons(choices, _pickSign),
        ]);
      default:
        final prompt = switch (widget.game) {
          'shortLong' => MT.shortOrLong,
          'flags' => MT.oneOrTwoFlags,
          _ => MT.whichSignHeard,
        };
        String? label(String s) => switch (widget.game) {
              'shortLong' => const {'ि', 'ु'}.contains(s) ? MT.shortLabel : MT.longLabel,
              'flags' => s == 'े' ? MT.oneFlag : MT.twoFlags,
              _ => null,
            };
        final hear = widget.game == 'detective' ? r.word.word : r.syllable;
        return Column(children: [
          _prompt(prompt),
          Pressable(
            onTap: () => speakHindi(hear, rate: 0.5),
            child: Container(
              width: 96, height: 96, alignment: Alignment.center,
              decoration: BoxDecoration(gradient: toneGradient(AppColors.primary), shape: BoxShape.circle,
                  boxShadow: toyShadow(AppColors.primaryDark, 5)),
              child: const Icon(Icons.volume_up_rounded, size: 46, color: Colors.white),
            ),
          ),
          if (widget.game == 'detective') Padding(
            padding: const EdgeInsets.only(top: Sp.sm),
            child: Text(r.word.meaning, style: Fonts.body(15, w: FontWeight.w700, color: AppColors.textSecondary)),
          ),
          const SizedBox(height: Sp.lg),
          _signButtons(choices, _pickSign, label: label),
        ]);
    }
  }

  /// The letter with four places a sign can go; the child taps one.
  Widget _whereBoard() {
    Widget spot(String pos) {
      final wrong = wrongChoice == pos;
      return Pressable(
        onTap: () => _pickPlace(pos),
        child: Container(
          width: 84, padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: wrong ? AppColors.warning.withOpacity(0.25) : AppColors.surface,
            borderRadius: BorderRadius.circular(Rad.lg),
            border: Border.all(color: wrong ? AppColors.warning : AppColors.primary.withOpacity(0.5), width: 2),
            boxShadow: toyShadow(AppColors.toyShadowColor, 3)),
          child: Column(children: [
            Text('?', style: Fonts.display(22, color: AppColors.primary)),
            Text(MT.placeName(pos), style: Fonts.body(12, w: FontWeight.w800, color: AppColors.textSecondary)),
          ]),
        ),
      );
    }
    return Column(children: [
      spot('top'),
      const SizedBox(height: Sp.sm),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        spot('left'),
        const SizedBox(width: Sp.md),
        Text(r.base, style: Fonts.hindi(88, height: 1.2)),
        const SizedBox(width: Sp.md),
        spot('right'),
      ]),
      const SizedBox(height: Sp.sm),
      spot('bottom'),
    ]);
  }

  Widget _signButtons(List<String> signs, ValueChanged<String> onPick, {String? Function(String)? label}) =>
      Wrap(alignment: WrapAlignment.center, spacing: Sp.md, runSpacing: Sp.md, children: [
        for (final s in signs) Pressable(
          onTap: () => onPick(s),
          child: Container(
            constraints: const BoxConstraints(minWidth: 88), height: 96,
            padding: const EdgeInsets.symmetric(horizontal: Sp.md),
            decoration: BoxDecoration(
              color: wrongChoice == s ? AppColors.warning.withOpacity(0.25) : AppColors.surface,
              borderRadius: BorderRadius.circular(Rad.xl),
              border: Border.all(color: wrongChoice == s ? AppColors.warning : AppColors.border, width: 2),
              boxShadow: toyShadow(AppColors.toyShadowColor, 4)),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('◌$s', style: Fonts.hindi(38, height: 1.2)),
              if (label?.call(s) != null)
                Text(label!(s)!, style: Fonts.body(12, w: FontWeight.w800, color: AppColors.textSecondary)),
            ]),
          ),
        ),
      ]);

  Widget _see(double w) => Column(children: [
        _prompt(listenOnly ? MT.listenFirst : MT.watch(r.sign, r.base)),
        MatraCanvas(glyph: glyph, width: w, reveal: listenOnly ? null : reveal),
        const SizedBox(height: Sp.md),
        if (!listenOnly) ...[
          _anchorCard(),
          if (!fast && r.matra.hinglish.isNotEmpty) ...[const SizedBox(height: Sp.sm), _hinglishCard()],
        ],
        const SizedBox(height: Sp.md),
        Wrap(alignment: WrapAlignment.center, spacing: Sp.sm, runSpacing: Sp.sm, children: [
          HearButton(onTap: listenOnly ? () => _startSee() : () { reveal.forward(from: 0); speakHindi(r.syllable, rate: 0.5); },
              label: MT.playAgain),
          if (!fast) SizedBox(width: 220, child: ResultButton(label: listenOnly ? MT.ready : MT.myTurn,
              icon: Icons.edit_rounded, onTap: () => _go(_Phase.write))),
        ]),
      ]);

  Widget _anchorCard() => Container(
        width: double.infinity, padding: const EdgeInsets.all(Sp.md),
        decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(Rad.lg),
            border: Border.all(color: AppColors.primary.withOpacity(0.25))),
        child: Row(children: [
          Text('${r.base}${r.sign}', style: Fonts.hindi(34, color: AppColors.primaryDark, height: 1.2)),
          const SizedBox(width: Sp.md),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${r.matra.name} · ${r.matra.romanized}', style: Fonts.body(13, w: FontWeight.w800, color: AppColors.textSecondary)),
            Text(MT.soundsLike(r.matra.anchor), style: Fonts.body(16, w: FontWeight.w700)),
          ])),
        ]),
      );

  Widget _hinglishCard() => Container(
        width: double.infinity, padding: const EdgeInsets.all(Sp.md),
        decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.12), borderRadius: BorderRadius.circular(Rad.lg),
            border: Border.all(color: AppColors.warning.withOpacity(0.5))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('🔤 ${MT.hinglishTip}', style: Fonts.body(13, w: FontWeight.w800, color: AppColors.textSecondary)),
          const SizedBox(height: 2),
          Text(r.matra.hinglish, style: Fonts.body(15, w: FontWeight.w600)),
        ]),
      );

  Widget _write(double w) {
    final canvas = MatraCanvas(glyph: glyph, width: w, controller: draw, reveal: ghost ? reveal : null, ghost: true,
        hintZone: hintZone);
    final frame = canvas.frame();
    return Column(children: [
      _prompt(listenOnly && !passed ? MT.writeWhatYouHeard : MT.writeOnly(r.sign, r.base)),
      canvas,
      const SizedBox(height: Sp.md),
      if (passed || canMoveOn)
        SizedBox(width: 240, child: ResultButton(label: MT.useIt, icon: Icons.extension_rounded, onTap: () => _go(_Phase.use)))
      else
        Row(children: [
          Expanded(child: ResultButton(label: MT.undo, icon: Icons.undo_rounded, filled: false, onTap: draw.undo)),
          const SizedBox(width: Sp.sm),
          Expanded(child: ResultButton(label: MT.clear, icon: Icons.delete_outline_rounded, filled: false,
              onTap: () { draw.clear(); setState(() => message = null); })),
          if (!listenOnly) ...[
            const SizedBox(width: Sp.sm),
            Expanded(child: ResultButton(label: MT.showMe, icon: Icons.visibility_rounded, filled: false, onTap: _showMe)),
          ],
          const SizedBox(width: Sp.sm),
          Expanded(child: ResultButton(label: checking ? MT.checking : MT.check, icon: Icons.check_rounded,
              onTap: checking ? null : () => _check(frame))),
        ]),
    ]);
  }

  Widget _use() {
    final from = r.from, wrong = r.wrong;
    final units = filled ? r.word.units : (wrong ?? from?.units ?? r.word.units);
    return Column(children: [
      _prompt(MT.completeWord(r.word.meaning)),
      if (from != null) Padding(
        padding: const EdgeInsets.only(bottom: Sp.sm),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(from.word, style: Fonts.hindi(22, color: AppColors.textSecondary)),
          Text('  (${from.meaning})  ➜', style: Fonts.body(16, w: FontWeight.w700, color: AppColors.textSecondary)),
        ]),
      ),
      _wordTiles(units, blankSlot: filled || from != null || wrong != null ? null : r.word.slot,
          highlight: filled ? r.word.slot : null),
      if (filled) Padding(
        padding: const EdgeInsets.only(top: Sp.sm),
        child: PopIn(child: Text('${r.word.word} = ${r.word.meaning}', style: Fonts.display(20, color: AppColors.success))),
      ),
      const SizedBox(height: Sp.lg),
      if (!filled) ...[
        Text(MT.tapTheSign, style: Fonts.body(16, w: FontWeight.w700, color: AppColors.textSecondary)),
        const SizedBox(height: Sp.md),
        _signButtons(choices, _fill),
      ] else if (!fast)
        Wrap(alignment: WrapAlignment.center, spacing: Sp.sm, runSpacing: Sp.sm, children: [
          HearButton(onTap: _sayWords, label: MT.playAgain),
          SizedBox(width: 200, child: ResultButton(label: MT.nextRound, icon: Icons.arrow_forward_rounded, onTap: _finish)),
        ]),
    ]);
  }

  /// A word as blocks. [blankSlot] shows that block's bare letter with an
  /// empty box where the sign goes; [highlight] marks a block in colour.
  Widget _wordTiles(List<String> units, {int? blankSlot, int? highlight, ValueChanged<int>? onTap}) {
    Widget tile(int i) {
      final hi = i == highlight;
      Widget content;
      if (i == blankSlot) {
        final box = DashedBorder(radius: 8, color: AppColors.primary, child: SizedBox(width: 26, height: 26,
            child: Center(child: Text('?', style: Fonts.display(16, color: AppColors.primary)))));
        final letter = Text(r.base, style: Fonts.hindi(46, height: 1.25));
        content = switch (r.matra.position) {
          'left' => Row(mainAxisSize: MainAxisSize.min, children: [box, const SizedBox(width: 2), letter]),
          'top' => Column(mainAxisSize: MainAxisSize.min, children: [box, letter]),
          'bottom' => Column(mainAxisSize: MainAxisSize.min, children: [letter, box]),
          _ => Row(mainAxisSize: MainAxisSize.min, children: [letter, const SizedBox(width: 2), box]),
        };
      } else {
        content = Text(units[i], style: Fonts.hindi(46, height: 1.25, color: hi ? AppColors.success : null));
      }
      final c = Container(
        constraints: const BoxConstraints(minWidth: 64, minHeight: 84),
        padding: const EdgeInsets.symmetric(horizontal: Sp.sm, vertical: Sp.xs),
        decoration: BoxDecoration(
          color: hi ? AppColors.success.withOpacity(0.12) : AppColors.surface,
          borderRadius: BorderRadius.circular(Rad.lg),
          border: Border.all(color: hi ? AppColors.success : AppColors.border, width: 2),
          boxShadow: toyShadow(AppColors.toyShadowColor, 3)),
        // widthFactor keeps the tile as wide as its block, not the whole row.
        child: Align(widthFactor: 1, child: content),
      );
      return onTap == null ? c : Pressable(onTap: () => onTap(i), child: c);
    }
    return Wrap(alignment: WrapAlignment.center, spacing: Sp.sm, runSpacing: Sp.sm,
        children: [for (int i = 0; i < units.length; i++) tile(i)]);
  }
}
