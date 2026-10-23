import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/feedback.dart';
import '../../services/speech_service.dart';
import '../../services/stroke_evaluator.dart';
import '../../data/models.dart';
import '../../store/app_store.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../../widgets/common.dart';
import '../../widgets/draw_canvas.dart';
import '../../util/num_ext.dart';

class _Conjunct {
  final String character, romanized, pronunciation, exampleWord, exampleMeaning;
  final List<String> components;
  const _Conjunct(this.character, this.romanized, this.components, this.pronunciation, this.exampleWord, this.exampleMeaning);
}

const _conjuncts = <_Conjunct>[
  _Conjunct('क्र', 'kra', ['क', '्', 'र'], 'kruh', 'क्रांति', 'Revolution'),
  _Conjunct('प्र', 'pra', ['प', '्', 'र'], 'pruh', 'प्रसन्न', 'Happy'),
  _Conjunct('त्र', 'tra', ['त', '्', 'र'], 'truh', 'त्रिमुख', 'Three-faced'),
  _Conjunct('श्र', 'shra', ['श', '्', 'र'], 'shruh', 'श्रीमान', 'Sir / Mr.'),
  _Conjunct('स्त', 'sta', ['स', '्', 'त'], 'stuh', 'स्तंभ', 'Pillar'),
  _Conjunct('न्द', 'nda', ['न', '्', 'द'], 'nduh', 'नंद', 'Joy'),
  _Conjunct('ग्र', 'gra', ['ग', '्', 'र'], 'gruh', 'ग्राम', 'Village'),
  _Conjunct('ज्ञ', 'gya', ['ज', '्', 'ञ'], 'gyuh', 'ज्ञान', 'Knowledge'),
  _Conjunct('क्ष', 'ksha', ['क', '्', 'ष'], 'kshuh', 'क्षत्रिय', 'Warrior'),
];

/// Tile colours for the parts of a conjunct: first letter, halant, second
/// letter, result — each a light fill with a dark text of the same hue.
const _partColors = [
  (Color(0xFFE3F2FD), Color(0xFF1565C0)),
  (Color(0xFFF3E5F5), Color(0xFF6A1B9A)),
  (Color(0xFFE8F5E9), Color(0xFF2E7D32)),
];
const _resultColors = (Color(0xFFFFF3E0), Color(0xFFE65100));

/// Reference strokes for a conjunct: its own template when one exists (क्ष त्र
/// ज्ञ); for र-conjuncts the first letter plus the small slanted र-stroke at
/// the foot of its stem; otherwise the half first letter beside the second.
List<List<Pt>> _conjunctStrokes(_Conjunct c) {
  final own = templateForCharacter(c.character);
  if (own != null && own.character == c.character) return own.strokes;
  final first = templateForCharacter(c.components.first)?.strokes ?? const <List<Pt>>[];
  final second = templateForCharacter(c.components.last)?.strokes ?? const <List<Pt>>[];
  if (c.components.last == 'र') {
    return [...first, const [Pt(0.48, 0.6), Pt(0.36, 0.72), Pt(0.26, 0.8)]];
  }
  List<List<Pt>> place(List<List<Pt>> st, double x0, double x1) =>
      [for (final s in st) [for (final p in s) Pt(x0 + p.x * (x1 - x0), p.y)]];
  return [...place(first, 0, 0.5), ...place(second, 0.42, 1)];
}

class ConjunctPracticeScreen extends StatefulWidget {
  final Map<String, dynamic> params;
  const ConjunctPracticeScreen({super.key, this.params = const {}});
  @override
  State<ConjunctPracticeScreen> createState() => _ConjunctPracticeScreenState();
}

class _ConjunctPracticeScreenState extends State<ConjunctPracticeScreen> {
  int idx = 0, earned = 0, correct = 0;
  bool evaluated = false, complete = false;
  EvaluationResult? result;
  double size = 300;
  final draw = DrawController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() { draw.dispose(); super.dispose(); }

  void _submit() {
    if (draw.isEmpty) return;
    final c = _conjuncts[idx.clampI(0, _conjuncts.length - 1)];
    final r = evaluateAgainst(draw.strokes, _conjunctStrokes(c), size);
    final stars = r.stars;
    setState(() {
      earned = stars; evaluated = true; result = r;
      if (stars >= 2) correct++;
    });
    draw.locked = true;
    stars >= 2 ? hapticSuccess() : hapticMedium();
  }

  void _next() {
    if (idx < _conjuncts.length - 1) {
      setState(() { idx++; evaluated = false; earned = 0; result = null; });
      draw.locked = false; draw.clear();
    } else {
      setState(() => complete = true);
      final aId = widget.params['activityId'], lvl = widget.params['levelNumber'];
      if (correct / _conjuncts.length >= 0.4 && aId is String && lvl is int) context.read<AppStore>().completeActivityLevel(aId, lvl);
    }
  }

  void _retry() {
    draw.locked = false; draw.clear();
    setState(() { idx = 0; evaluated = false; earned = 0; correct = 0; complete = false; });
  }

  @override
  Widget build(BuildContext context) {
    Widget scaffold(Widget body) => Scaffold(backgroundColor: AppColors.background, body: SafeArea(bottom: false, child: body));
    if (complete) return scaffold(_complete());
    final c = _conjuncts[idx.clampI(0, _conjuncts.length - 1)];
    size = (MediaQuery.of(context).size.width - Sp.md * 2).clampD(200.0, 300.0);

    BoxDecoration card({Color? bg, Color? border}) => BoxDecoration(
        color: bg ?? AppColors.surface, borderRadius: BorderRadius.circular(Rad.xl),
        border: Border.all(color: border ?? AppColors.border), boxShadow: toyShadow(AppColors.toyShadowColor, 4));

    return scaffold(Column(children: [
      HeaderBar(title: 'Conjunct Practice', subtitle: '${idx + 1}/${_conjuncts.length} conjuncts',
          onBack: () { if (!evaluated) Navigator.of(context).maybePop(); }),
      Expanded(child: SingleChildScrollView(
        padding: const EdgeInsets.all(Sp.md),
        child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 600), child: Column(children: [
          Container(
            width: double.infinity, margin: const EdgeInsets.only(bottom: Sp.lg), padding: const EdgeInsets.all(Sp.lg),
            decoration: card(),
            child: Column(children: [
              Text('Write this conjunct:', style: Fonts.body(12, w: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: Sp.sm),
              Text(c.character, style: Fonts.hindi(80, color: AppColors.primary, height: 88 / 80)),
              const SizedBox(height: Sp.sm),
              Text(c.romanized, style: Fonts.body(16, w: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: Sp.md),
              GestureDetector(
                onTap: () { speakHindi(c.character, rate: 0.8); hapticLight(); },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: Sp.lg, vertical: Sp.sm),
                  decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(9999)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.volume_up, size: 18, color: AppColors.primary), const SizedBox(width: Sp.sm),
                    Text(c.pronunciation, style: Fonts.body(14, w: FontWeight.w700, color: AppColors.primary)),
                  ]),
                ),
              ),
            ]),
          ),
          Container(
            width: double.infinity, margin: const EdgeInsets.only(bottom: Sp.lg), padding: const EdgeInsets.all(Sp.lg),
            decoration: card(),
            child: Column(children: [
              Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.only(bottom: Sp.md),
                  child: Text('Component Letters:', style: Fonts.body(14, w: FontWeight.w700, color: AppColors.textSecondary)))),
              Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, spacing: Sp.sm, runSpacing: Sp.sm, children: [
                for (int i = 0; i < c.components.length; i++) ...[
                  if (i > 0) Text('+', style: Fonts.display(22, color: AppColors.textSecondary)),
                  _tile(c.components[i] == '्' ? '◌्' : c.components[i],
                      c.components[i] == '्' ? 'halant' : 'letter ${i == 0 ? 1 : 2}', _partColors[i % 3]),
                ],
                Text('=', style: Fonts.display(22, color: AppColors.textSecondary)),
                _tile(c.character, c.romanized, _resultColors),
              ]),
            ]),
          ),
          Container(
            width: double.infinity, margin: const EdgeInsets.only(bottom: Sp.lg), padding: const EdgeInsets.all(Sp.lg),
            decoration: card(bg: const Color(0xFFE8F5E9), border: const Color(0xFFA5D6A7)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('EXAMPLE WORD', style: Fonts.body(12, w: FontWeight.w800, color: const Color(0xFF2E7D32)).copyWith(letterSpacing: 0.5)),
              const SizedBox(height: Sp.sm),
              Row(children: [
                Expanded(child: Text(c.exampleWord, style: Fonts.hindi(36, color: const Color(0xFF1B5E20), height: 1.3))),
                GestureDetector(
                  onTap: () => speakHindi(c.exampleWord, rate: 0.8),
                  child: Container(width: 44, height: 44,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF2E7D32)),
                      child: const Icon(Icons.volume_up, size: 22, color: Colors.white)),
                ),
              ]),
              const SizedBox(height: Sp.sm),
              Text(c.exampleMeaning, style: Fonts.body(16, w: FontWeight.w700, color: const Color(0xFF33691E))),
            ]),
          ),
          if (!evaluated) _drawing(size) else PopIn(key: ValueKey('r$idx'), child: _result()),
          const SizedBox(height: Sp.lg),
        ]))),
      )),
    ]));
  }

  Widget _drawing(double size) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: Sp.lg), child: Column(children: [
      Padding(padding: const EdgeInsets.only(bottom: Sp.md),
          child: Text('Now you try!', style: Fonts.body(16, w: FontWeight.w600, color: AppColors.textSecondary))),
      SimpleCanvas(controller: draw, size: size, strokeWidth: 5, radius: Rad.lg),
      const SizedBox(height: Sp.md),
      AnimatedBuilder(animation: draw, builder: (_, __) {
        final empty = draw.isEmpty;
        return Row(children: [
          Expanded(child: GestureDetector(
            onTap: empty ? null : draw.clear,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: Sp.md),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(9999), border: Border.all(color: AppColors.border, width: 2)),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.delete_outline, size: 20, color: empty ? AppColors.disabled : AppColors.error),
                const SizedBox(width: Sp.xs),
                Text('Clear', style: Fonts.body(16, w: FontWeight.w700, color: empty ? AppColors.disabled : AppColors.textSecondary)),
              ]),
            ),
          )),
          const SizedBox(width: Sp.md),
          Expanded(child: Opacity(opacity: empty ? 0.5 : 1, child: GestureDetector(
            onTap: empty ? null : _submit,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: Sp.md),
              decoration: BoxDecoration(gradient: toneGradient(AppColors.success), borderRadius: BorderRadius.circular(9999),
                  border: Border.all(color: AppColors.success, width: 2), boxShadow: toyShadow(const Color(0xFF2E8B57), 6)),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.check, size: 20, color: Colors.white), const SizedBox(width: Sp.xs),
                Text('Submit', style: Fonts.body(16, w: FontWeight.w800, color: AppColors.textOnPrimary)),
              ]),
            ),
          ))),
        ]);
      }),
    ]));
  }

  Widget _result() => Padding(padding: const EdgeInsets.symmetric(vertical: Sp.lg), child: Column(children: [
        Container(
          width: double.infinity, margin: const EdgeInsets.only(bottom: Sp.lg), padding: const EdgeInsets.all(Sp.lg),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(Rad.xl),
              border: Border.all(color: AppColors.border), boxShadow: toyShadow(AppColors.toyShadowColor, 4)),
          child: Column(children: [
            Text(earned >= 2 ? 'Great attempt!' : 'Good try!', style: Fonts.display(20)),
            const SizedBox(height: Sp.sm),
            StarRating(stars: earned, size: 40),
            Text('${result?.accuracy ?? 0}% match', style: Fonts.display(18, color: AppColors.primaryDark)),
            Padding(padding: const EdgeInsets.only(top: Sp.sm), child: Text(
                earned >= 2 ? 'You captured the conjunct well!' : 'Keep practicing this combination.',
                textAlign: TextAlign.center, style: Fonts.body(16, color: AppColors.textSecondary))),
            if (result != null) Padding(padding: const EdgeInsets.only(top: Sp.md), child: ScoreBreakdown(result!)),
          ]),
        ),
        GestureDetector(
          onTap: _next,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: Sp.xl, vertical: Sp.md),
            decoration: BoxDecoration(gradient: toneGradient(AppColors.primary), borderRadius: BorderRadius.circular(9999), boxShadow: toyShadow(AppColors.primaryDark, 6)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(idx < _conjuncts.length - 1 ? 'Next Conjunct' : 'Finish', style: Fonts.body(16, w: FontWeight.w800, color: AppColors.textOnPrimary)),
              const SizedBox(width: Sp.sm),
              const Icon(Icons.arrow_forward, size: 18, color: Colors.white),
            ]),
          ),
        ),
      ]));

  Widget _complete() {
    final accuracy = correct / _conjuncts.length * 100;
    final st = accuracy >= 80 ? 3 : accuracy >= 60 ? 2 : accuracy >= 40 ? 1 : 0;
    return Column(children: [
      HeaderBar(title: 'Practice Complete', onBack: () => Navigator.of(context).maybePop()),
      Expanded(child: SessionCompleteCard(
        emoji: accuracy >= 80 ? '🎉' : accuracy >= 60 ? '👏' : '🎯',
        title: 'All Conjuncts Practiced!', stars: st,
        stats: [('$correct/${_conjuncts.length}', 'Completed'), ('${accuracy.round()}%', 'Accuracy')],
        message: 'Conjunct consonants are challenging! Great effort practicing these combinations.',
        retryLabel: 'Practice Again', onRetry: _retry, onDone: () => Navigator.of(context).maybePop(),
      )),
    ]);
  }

  Widget _tile(String text, String label, (Color, Color) colors) => Container(
        constraints: const BoxConstraints(minWidth: 64),
        padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.sm),
        decoration: BoxDecoration(color: colors.$1, borderRadius: BorderRadius.circular(Rad.md),
            border: Border.all(color: colors.$2.withOpacity(0.5), width: 1.5),
            boxShadow: toyShadow(colors.$2.withOpacity(0.35), 3)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(text, style: Fonts.hindi(30, color: colors.$2, height: 1.3)),
          Text(label, style: Fonts.body(11, w: FontWeight.w800, color: colors.$2)),
        ]),
      );
}
