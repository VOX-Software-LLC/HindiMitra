import 'package:flutter/material.dart';
import '../../data/word_bank.dart';
import '../../services/speech_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../../widgets/common.dart';
import '../../widgets/draw_canvas.dart';
import '../../widgets/stroke_guide.dart';

/// Rough page: a ruled copybook sheet (header + base line on every row) for
/// free practice of any word — nothing is graded or recorded. Pick a word as
/// the model at the top; optionally show its stroke order on the first row.
class RoughPadScreen extends StatefulWidget {
  final Map<String, dynamic> params;
  const RoughPadScreen({super.key, this.params = const {}});
  @override
  State<RoughPadScreen> createState() => _RoughPadScreenState();
}

class _RoughPadScreenState extends State<RoughPadScreen> {
  late final List<PracticeWord> words;
  int sel = 0;
  bool guide = true;
  Color pen = const Color(0xFF1565C0);
  final draw = DrawController();

  static const _pens = [Color(0xFF1565C0), Color(0xFF263238), Color(0xFFC62828), Color(0xFFF59E2D)];
  static const _rowH = 120.0;

  @override
  void initState() {
    super.initState();
    // Words from the calling screen first, then the rest of the bank.
    final first = ((widget.params['words'] as List?) ?? const []).cast<String>();
    words = [
      for (final w in first) ...practiceWords.where((p) => p.word == w),
      ...practiceWords.where((p) => !first.contains(p.word)),
    ];
  }

  @override
  void dispose() { draw.dispose(); super.dispose(); }

  PracticeWord get word => words[sel];

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(bottom: false, child: Column(children: [
          HeaderBar(title: 'Rough Page', subtitle: 'रफ़ पन्ना · free practice', onBack: () => Navigator.of(context).maybePop()),
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Sp.md),
              itemCount: words.length,
              separatorBuilder: (_, __) => const SizedBox(width: Sp.sm),
              itemBuilder: (_, i) => GestureDetector(
                onTap: () { setState(() => sel = i); speakHindi(words[i].word, rate: 0.7); },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: Sp.md), alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == sel ? AppColors.secondary : AppColors.surface,
                    borderRadius: BorderRadius.circular(Rad.md),
                    border: Border.all(color: i == sel ? AppColors.secondary : AppColors.border)),
                  child: Text(words[i].word, style: Fonts.hindi(20, height: 1.3,
                      color: i == sel ? AppColors.textOnPrimary : AppColors.textPrimary)),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Sp.md, Sp.sm, Sp.md, Sp.sm),
            child: Row(children: [
              Text(word.word, style: Fonts.hindi(30, height: 1.2)),
              const SizedBox(width: Sp.sm),
              Expanded(child: Text(word.meaning, style: Fonts.body(14, w: FontWeight.w700, color: AppColors.textSecondary))),
              for (final c in _pens) GestureDetector(
                onTap: () => setState(() => pen = c),
                child: Container(
                  width: 26, height: 26, margin: const EdgeInsets.only(left: 6),
                  decoration: BoxDecoration(color: c, shape: BoxShape.circle,
                      border: Border.all(color: pen == c ? AppColors.textPrimary : Colors.white, width: 3)),
                ),
              ),
            ]),
          ),
          Expanded(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Sp.md),
            child: LayoutBuilder(builder: (_, c) {
              final rows = (c.maxHeight / _rowH).floor().clamp(1, 12);
              return Container(
                decoration: BoxDecoration(color: AppColors.canvasBackground, borderRadius: BorderRadius.circular(Rad.lg),
                    border: Border.all(color: AppColors.border, width: 2)),
                clipBehavior: Clip.antiAlias,
                child: Stack(children: [
                  Positioned.fill(child: IgnorePointer(child: Column(children: [
                    for (int r = 0; r < rows; r++) Expanded(child: Stack(children: [
                      const Positioned.fill(child: CustomPaint(painter: WritingGuidePainter(top: 0.25, bottom: 0.8, labels: false))),
                      // The first row shows the model word's stroke order to copy.
                      if (r == 0 && guide) Positioned.fill(child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: Sp.sm),
                        child: ClipRect(child: OverflowBox(alignment: Alignment.centerLeft, maxWidth: double.infinity,
                            child: Row(mainAxisAlignment: MainAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                          for (final u in word.units) AspectRatio(aspectRatio: 0.9,
                              child: Opacity(opacity: 0.7, child: StrokeOrderGuide(character: u, top: 0.25, bottom: 0.8))),
                        ]))),
                      )),
                    ])),
                  ]))),
                  Positioned.fill(child: DrawSurface(controller: draw,
                      child: _PenLayer(controller: draw, color: pen))),
                ]),
              );
            }),
          )),
          Padding(
            padding: const EdgeInsets.all(Sp.md),
            child: AnimatedBuilder(animation: draw, builder: (_, __) => Row(children: [
              Expanded(child: ResultButton(label: 'Guide', icon: Icons.route, filled: guide,
                  color: AppColors.secondary, onTap: () => setState(() => guide = !guide))),
              const SizedBox(width: Sp.sm),
              Expanded(child: ResultButton(label: 'Undo', icon: Icons.undo, filled: false, onTap: draw.isEmpty ? null : draw.undo)),
              const SizedBox(width: Sp.sm),
              Expanded(child: ResultButton(label: 'Clear', icon: Icons.delete_outline, filled: false, color: AppColors.error,
                  onTap: draw.isEmpty ? null : draw.clear)),
            ])),
          ),
        ])),
      );
}

/// Ink layer: every stroke keeps the pen colour it was drawn with.
class _PenLayer extends StatefulWidget {
  final DrawController controller; final Color color;
  const _PenLayer({required this.controller, required this.color});
  @override
  State<_PenLayer> createState() => _PenLayerState();
}

class _PenLayerState extends State<_PenLayer> {
  final List<Color> colors = [];
  @override
  Widget build(BuildContext context) => RepaintBoundary(child: AnimatedBuilder(
        animation: widget.controller,
        builder: (_, __) {
          final n = widget.controller.strokes.length;
          if (colors.length > n) colors.removeRange(n, colors.length);
          while (colors.length < n) { colors.add(widget.color); }
          return CustomPaint(size: Size.infinite, painter: _InkPainter(widget.controller, colors, widget.color));
        },
      ));
}

class _InkPainter extends CustomPainter {
  final DrawController c; final List<Color> colors; final Color current;
  _InkPainter(this.c, this.colors, this.current);
  @override
  void paint(Canvas canvas, Size size) {
    void draw(List<Offset> pts, Color col) {
      if (pts.isEmpty) return;
      if (pts.length == 1) { canvas.drawCircle(pts.first, 2.5, Paint()..color = col); return; }
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final p in pts.skip(1)) { path.lineTo(p.dx, p.dy); }
      canvas.drawPath(path, Paint()..color = col..strokeWidth = 4.5..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
    }
    for (int i = 0; i < c.strokes.length; i++) { draw(c.strokes[i], i < colors.length ? colors[i] : current); }
    draw(c.current, current);
  }
  @override
  bool shouldRepaint(covariant _InkPainter o) => true;
}
