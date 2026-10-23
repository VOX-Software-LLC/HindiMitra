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

/// How two look-alike letters differ: a one-line rule to remember plus a
/// feature-by-feature table (what letter A has vs what letter B has).
class _Diff {
  final String a, b, summary;
  final List<(String, String, String)> rows;
  const _Diff(this.a, this.b, this.summary, this.rows);
}

const _diffs = <_Diff>[
  _Diff('ख', 'र', 'ख has a closed round loop and a full standing line on the right. र has NO standing line — only a hook with a tail.', [
    ('Standing line (खड़ी पाई)', 'Yes — full height, on the right', 'None'),
    ('Loop', 'Closed round loop at the lower left', 'No loop — an open hook'),
    ('Header line', 'Runs across the whole letter', 'Short — only over the hook'),
    ('Ending', 'Loop joins the standing line in the middle', 'Tail sweeps down to the right'),
    ('Sound', 'kha — खरगोश', 'ra — रथ'),
  ]),
  _Diff('ब', 'प', 'ब is a closed box (header covers it) with a small slant inside. प is an open cup — no header over its left side.', [
    ('Top', 'Closed — header covers the whole letter', 'Open at the top-left'),
    ('Inside', 'Small slanted line at the bottom-left', 'Empty'),
    ('Shape', 'Square box + standing line', 'U-shaped cup + standing line'),
    ('Sound', 'ba — बतख', 'pa — पतंग'),
  ]),
  _Diff('ब', 'व', 'Both are a loop + standing line. ब has a small slanted line inside the loop; व is empty inside.', [
    ('Inside the loop', 'Small slanted line', 'Empty'),
    ('Loop shape', 'Squarer', 'Rounder'),
    ('Sound', 'ba — बतख', 'va — वन'),
  ]),
  _Diff('म', 'भ', 'म has a full header line and a small knot at the bottom-left. भ has a gap in the header — its left part is an open curl.', [
    ('Header line', 'Covers the whole letter', 'Only over the right standing line'),
    ('Left part', 'Straight line with a small knot at the bottom', 'Curly hook, open at the top'),
    ('Standing line', 'Yes, on the right', 'Yes, on the right'),
    ('Sound', 'ma — मछली', 'bha — भालू'),
  ]),
  _Diff('ध', 'घ', 'घ has a full header line. ध has a break in the header with a small hook sticking up on the top-left.', [
    ('Header line', 'Broken — none over the left part', 'Covers the whole letter'),
    ('Top-left', 'Small hook sticking up', 'Flat, joined into the header'),
    ('Left part', 'Loop that closes at the bottom', 'U-cup joined to the standing line'),
    ('Sound', 'dha — धनुष', 'gha — घर'),
  ]),
  _Diff('ध', 'य', 'ध has a closed loop on the left. य has an open curve with a slanted line inside and joins the stem low down.', [
    ('Left part', 'Closed loop', 'Open curve with a slanted line'),
    ('Top-left', 'Small hook above the loop', 'Nothing above'),
    ('Joins the stem', 'In the middle', 'Near the bottom'),
    ('Sound', 'dha — धनुष', 'ya — यान'),
  ]),
  _Diff('क', 'ख', 'क has its standing line in the MIDDLE with curls on both sides. ख has its standing line on the RIGHT with a loop on the left.', [
    ('Standing line', 'In the middle', 'On the right'),
    ('Curves', 'Loop on the left + curl on the right', 'Loop on the left only'),
    ('Looks like', 'A plus sign with curls', 'र and व joined together'),
    ('Sound', 'ka — कमल', 'kha — खरगोश'),
  ]),
  _Diff('ग', 'घ', 'ग is just a hanging line + standing line (open at the bottom). घ has a closed U-cup that touches the standing line.', [
    ('Left part', 'A single hanging line', 'U-shaped cup'),
    ('Bottom', 'Open — left part does not touch the stem', 'Closed — cup touches the stem'),
    ('Sound', 'ga — गमला', 'gha — घर'),
  ]),
  _Diff('च', 'छ', 'च has a standing line on the right. छ has NO standing line — it is two round bulges with a curl at the bottom.', [
    ('Standing line', 'Yes, on the right', 'None'),
    ('Main shape', 'Short bar going left, bending down', 'Two round bulges stacked'),
    ('Size', 'Wide and short', 'Narrow and tall'),
    ('Sound', 'cha — चम्मच', 'chha — छतरी'),
  ]),
  _Diff('ट', 'त', 'ट has NO standing line — one curve hanging from the header. त has a standing line on the right.', [
    ('Standing line', 'None', 'Yes, on the right'),
    ('Curve', 'Opens left, like a backwards C', 'Bar from the stem bending down-left'),
    ('Sound', 'ṭa — tongue curled back (टमाटर)', 'ta — tongue on the teeth (तितली)'),
  ]),
  _Diff('ठ', 'थ', 'ठ is a round circle hanging from the header with no standing line. थ has a standing line with a loop on its left.', [
    ('Standing line', 'None', 'Yes, on the right'),
    ('Shape', 'One closed circle', 'Loop + slanted join to the stem'),
    ('Sound', 'ṭha — ठठेरा', 'tha — थाली'),
  ]),
  _Diff('ड', 'द', 'ड has a small curl sticking out on the right. द has nothing on the right but a long tail curling right at the bottom.', [
    ('Standing line', 'None', 'None'),
    ('Right side', 'Small curl, like a dot', 'Nothing'),
    ('Bottom', 'Short and rounded', 'Long tail curling to the right'),
    ('Sound', 'ḍa — डमरू', 'da — दवात'),
  ]),
  _Diff('श', 'ष', 'ष has a slanted line cutting through its loop. श has no slant — its left part is a curl joined to the stem by a small bar.', [
    ('Slanted line', 'None', 'Yes, crossing the loop'),
    ('Left part', 'Curl with a small joining bar', 'Round loop'),
    ('Sound', 'sha — शेर', 'ṣha — षट्कोण'),
  ]),
];

_Diff? _diffFor(String a, String b) {
  for (final d in _diffs) {
    if (d.a == a && d.b == b) return d;
    if (d.a == b && d.b == a) {
      return _Diff(a, b, d.summary, [for (final r in d.rows) (r.$1, r.$3, r.$2)]);
    }
  }
  return null;
}

HindiLetter? _byChar(String c) {
  for (final l in AppData.allLetters) { if (l.character == c) return l; }
  return null;
}

class LetterComparisonScreen extends StatefulWidget {
  final Map<String, dynamic> params;
  const LetterComparisonScreen({super.key, this.params = const {}});
  @override
  State<LetterComparisonScreen> createState() => _LetterComparisonScreenState();
}

class _LetterComparisonScreenState extends State<LetterComparisonScreen> {
  late List<_Diff> rounds;
  int pairIdx = 0, completed = 0;
  bool evaluated = false, sessionComplete = false, showGuide = false, countedPair = false;
  String? selectedId, confusedWith;
  EvaluationResult? result;
  double accuracy = 0;
  final draw = DrawController();
  double canvasSize = 300;

  @override
  void initState() {
    super.initState();
    rounds = _buildRounds();
  }

  /// Pairs from the level's `pairs` param when given, else every pair; dealt
  /// without repeats until all have been shown.
  List<_Diff> _buildRounds() {
    final p = widget.params['pairs'];
    var pool = <_Diff>[];
    if (p is List) {
      for (final e in p) {
        if (e is List && e.length == 2) {
          final d = _diffFor(e[0] as String, e[1] as String);
          if (d != null) pool.add(d);
        }
      }
    }
    if (pool.isEmpty) pool = [..._diffs];
    final count = (widget.params['count'] as int?) ?? pool.length;
    return AppData.deck(pool, count.clampI(1, 15));
  }

  @override
  void dispose() { draw.dispose(); super.dispose(); }

  void _select(String id) {
    if (evaluated) return;
    setState(() { selectedId = id; showGuide = false; });
    draw.locked = false; draw.clear();
    hapticLight();
  }

  void _submit(HindiLetter target, HindiLetter other) {
    if (draw.isEmpty) return;
    final r = evaluateStrokes(draw.strokes, target.id, canvasSize);
    final vsOther = evaluateStrokes(draw.strokes, other.id, canvasSize);
    // Wrote the look-alike instead? Only say so when it clearly fits better.
    final confused = vsOther.accuracy >= r.accuracy + 10;
    final stars = confused ? (r.stars > 1 ? 1 : r.stars) : r.stars;
    setState(() {
      result = r; evaluated = true; confusedWith = confused ? other.character : null;
      // A pair counts once, however many times it is rewritten.
      if (stars >= 2 && !countedPair) { completed++; countedPair = true; }
    });
    draw.locked = true;
    stars >= 2 ? hapticSuccess() : hapticMedium();
    final store = context.read<AppStore>();
    store.letterProgress.putIfAbsent(target.id, () => LetterProgress(letterId: target.id));
    store.recordAttempt(target.id, stars, accuracy: r.accuracy);
  }

  void _resetPairState() {
    selectedId = null; evaluated = false; result = null; confusedWith = null; showGuide = false; countedPair = false;
    draw.locked = false; draw.clear();
  }

  void _next() {
    if (pairIdx < rounds.length - 1) {
      setState(() { pairIdx++; _resetPairState(); });
    } else {
      setState(() { accuracy = completed / rounds.length * 100; sessionComplete = true; });
      final aId = widget.params['activityId'], lvl = widget.params['levelNumber'];
      if (accuracy >= 40 && aId is String && lvl is int) context.read<AppStore>().completeActivityLevel(aId, lvl);
    }
  }

  void _retry() => setState(() {
        rounds = _buildRounds();
        pairIdx = 0; completed = 0; sessionComplete = false; accuracy = 0; _resetPairState();
      });

  @override
  Widget build(BuildContext context) {
    canvasSize = (MediaQuery.of(context).size.width - Sp.md * 2).clampD(200.0, 320.0);
    Widget scaffold(Widget body) => Scaffold(backgroundColor: AppColors.background, body: SafeArea(bottom: false, child: body));
    if (sessionComplete) {
      final st = accuracy >= 80 ? 3 : accuracy >= 60 ? 2 : accuracy >= 40 ? 1 : 0;
      return scaffold(Column(children: [
        HeaderBar(title: 'Comparison Complete', onBack: () => Navigator.of(context).maybePop()),
        Expanded(child: SessionCompleteCard(
          emoji: accuracy >= 80 ? '🎉' : accuracy >= 60 ? '👏' : '🎯',
          title: 'All Pairs Complete!', stars: st,
          stats: [('$completed/${rounds.length}', 'Correct'), ('${accuracy.round()}%', 'Accuracy')],
          message: accuracy >= 80 ? 'You can tell these look-alikes apart!' : 'Look again at the differences table, then retry.',
          onRetry: _retry, onDone: () => Navigator.of(context).maybePop(),
        )),
      ]));
    }

    final pair = rounds[pairIdx.clampI(0, rounds.length - 1)];
    final l1 = _byChar(pair.a), l2 = _byChar(pair.b);
    if (l1 == null || l2 == null) return scaffold(const SizedBox.shrink());
    final sel = selectedId == l1.id ? l1 : selectedId == l2.id ? l2 : null;

    return scaffold(Column(children: [
      HeaderBar(title: 'Letter Comparison', subtitle: 'Pair ${pairIdx + 1}/${rounds.length}',
          onBack: () => Navigator.of(context).maybePop()),
      Expanded(child: SingleChildScrollView(
        padding: const EdgeInsets.all(Sp.md),
        child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 600), child: Column(children: [
          _letters(l1, l2),
          const SizedBox(height: Sp.md),
          _differences(pair),
          const SizedBox(height: Sp.lg),
          if (!evaluated) ...[
            Text('Now write one of them — tap to choose:', textAlign: TextAlign.center,
                style: Fonts.body(16, w: FontWeight.w700, color: AppColors.textSecondary)),
            const SizedBox(height: Sp.sm),
            Row(children: [_choice(l1), const SizedBox(width: Sp.md), _choice(l2)]),
            if (sel != null) _drawing(sel, sel == l1 ? l2 : l1),
          ] else
            PopIn(key: ValueKey('r$pairIdx'), child: _result(sel)),
          const SizedBox(height: Sp.lg),
        ]))),
      )),
    ]));
  }

  Widget _letters(HindiLetter l1, HindiLetter l2) {
    Widget box(HindiLetter l, Color c) => Expanded(child: GestureDetector(
          onTap: () => speakHindi(l.character, rate: 0.8),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: Sp.md),
            // Opaque tint: a translucent fill would let the toy shadow show through.
            decoration: BoxDecoration(color: Color.alphaBlend(c.withOpacity(0.08), AppColors.surface), borderRadius: BorderRadius.circular(Rad.xl),
                border: Border.all(color: c, width: 2), boxShadow: toyShadow(c.withOpacity(0.6), 4)),
            child: Column(children: [
              Text(l.character, style: Fonts.hindi(72, color: c, height: 1.2)),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(l.romanized, style: Fonts.body(14, w: FontWeight.w800, color: AppColors.textPrimary)),
                const SizedBox(width: 4),
                Icon(Icons.volume_up, size: 16, color: c),
              ]),
            ]),
          ),
        ));
    return Row(children: [
      box(l1, const Color(0xFF1E88E5)),
      Padding(padding: const EdgeInsets.symmetric(horizontal: Sp.sm), child: Container(width: 40, height: 40,
          decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle, boxShadow: toyShadow(AppColors.primaryDark, 3)),
          child: Center(child: Text('vs', style: Fonts.body(14, w: FontWeight.w800, color: AppColors.textOnPrimary))))),
      box(l2, const Color(0xFF8E24AA)),
    ]);
  }

  Widget _differences(_Diff d) => Container(
        width: double.infinity,
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(Rad.xl),
            border: Border.all(color: AppColors.border), boxShadow: toyShadow(AppColors.toyShadowColor, 3)),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          Container(
            width: double.infinity, padding: const EdgeInsets.all(Sp.md),
            color: AppColors.primary.withOpacity(0.1),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.lightbulb, size: 20, color: AppColors.primaryDark), const SizedBox(width: Sp.sm),
              Expanded(child: Text(d.summary, style: Fonts.body(15, w: FontWeight.w700, color: AppColors.textPrimary, height: 1.35))),
            ]),
          ),
          Padding(padding: const EdgeInsets.fromLTRB(Sp.md, Sp.sm, Sp.md, 4), child: Row(children: [
            const Expanded(flex: 4, child: SizedBox()),
            Expanded(flex: 5, child: Text(d.a, textAlign: TextAlign.center, style: Fonts.hindi(24, color: const Color(0xFF1E88E5)))),
            Expanded(flex: 5, child: Text(d.b, textAlign: TextAlign.center, style: Fonts.hindi(24, color: const Color(0xFF8E24AA)))),
          ])),
          for (int i = 0; i < d.rows.length; i++) Container(
            color: i.isEven ? AppColors.background : AppColors.surface,
            padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.sm),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 4, child: Text(d.rows[i].$1, style: Fonts.body(13, w: FontWeight.w800, color: AppColors.textSecondary))),
              Expanded(flex: 5, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(d.rows[i].$2, style: Fonts.body(13, w: FontWeight.w600)))),
              Expanded(flex: 5, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(d.rows[i].$3, style: Fonts.body(13, w: FontWeight.w600)))),
            ]),
          ),
        ]),
      );

  Widget _choice(HindiLetter l) {
    final active = selectedId == l.id;
    return Expanded(child: GestureDetector(
      onTap: () => _select(l.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: Sp.sm),
        decoration: BoxDecoration(
          color: active ? AppColors.success : AppColors.surface,
          borderRadius: BorderRadius.circular(Rad.xl),
          border: Border.all(color: active ? AppColors.success : AppColors.border, width: 2),
          boxShadow: toyShadow(active ? AppColors.successDark : AppColors.toyShadowColor, 4),
        ),
        child: Center(child: Text.rich(TextSpan(children: [
          TextSpan(text: 'Write  ', style: Fonts.body(16, w: FontWeight.w800, color: active ? AppColors.textOnPrimary : AppColors.textSecondary)),
          TextSpan(text: l.character, style: Fonts.hindi(26, color: active ? AppColors.textOnPrimary : AppColors.textPrimary)),
        ]))),
      ),
    ));
  }

  Widget _drawing(HindiLetter sel, HindiLetter other) => Padding(
        padding: const EdgeInsets.only(top: Sp.md),
        child: Column(children: [
          SimpleCanvas(controller: draw, size: canvasSize, radius: Rad.xl,
              underlay: showGuide ? AnimatedStrokeGuide(character: sel.character) : null),
          const SizedBox(height: Sp.md),
          AnimatedBuilder(animation: draw, builder: (_, __) {
            final empty = draw.isEmpty;
            return Row(children: [
              Expanded(child: ResultButton(label: showGuide ? 'Hide' : 'Hint', icon: Icons.lightbulb_outline, filled: false,
                  onTap: () => setState(() => showGuide = !showGuide))),
              const SizedBox(width: Sp.sm),
              Expanded(child: ResultButton(label: 'Clear', icon: Icons.delete_outline, filled: false, color: AppColors.error,
                  onTap: empty ? null : draw.clear)),
              const SizedBox(width: Sp.sm),
              Expanded(child: ResultButton(label: 'Check', icon: Icons.check, color: AppColors.success,
                  onTap: empty ? null : () => _submit(sel, other))),
            ]);
          }),
        ]),
      );

  Widget _result(HindiLetter? sel) {
    final r = result!;
    final good = r.stars >= 2 && confusedWith == null;
    return Column(children: [
      Container(
        width: double.infinity, padding: const EdgeInsets.all(Sp.lg),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(Rad.xl),
            border: Border.all(color: good ? AppColors.success : AppColors.border, width: 2), boxShadow: toyShadow(AppColors.toyShadowColor, 4)),
        child: Column(children: [
          Text(good ? 'Correct!' : 'Not quite', style: Fonts.display(22, color: good ? AppColors.success : AppColors.primaryDark)),
          const SizedBox(height: Sp.xs),
          StarRating(stars: confusedWith != null ? (r.stars > 1 ? 1 : r.stars) : r.stars, size: 40),
          Text('${r.accuracy}% match with ${sel?.character ?? ''}', style: Fonts.display(18, color: AppColors.primaryDark)),
          if (confusedWith != null) Container(
            margin: const EdgeInsets.only(top: Sp.sm), padding: const EdgeInsets.all(Sp.sm),
            decoration: BoxDecoration(color: AppColors.error.withOpacity(0.08), borderRadius: BorderRadius.circular(Rad.md)),
            child: Text('Careful — this looks more like $confusedWith than ${sel?.character}. Check the table above.',
                textAlign: TextAlign.center, style: Fonts.body(14, w: FontWeight.w700, color: AppColors.error)),
          ),
          const SizedBox(height: Sp.md),
          ScoreBreakdown(r),
        ]),
      ),
      const SizedBox(height: Sp.md),
      Row(children: [
        Expanded(child: ResultButton(label: 'Write again', icon: Icons.refresh, filled: false,
            onTap: () => setState(() { evaluated = false; result = null; confusedWith = null; draw.locked = false; draw.clear(); }))),
        const SizedBox(width: Sp.sm),
        Expanded(child: ResultButton(label: pairIdx < rounds.length - 1 ? 'Next Pair' : 'Finish', icon: Icons.arrow_forward, onTap: _next)),
      ]),
    ]);
  }
}
