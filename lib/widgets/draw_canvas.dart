import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../theme/palette.dart';
import '../util/num_ext.dart';

/// Finger/mouse drawing surface (react-native-svg + PanResponder equivalent).
/// Strokes are stored as point lists; Done -> graded by stroke_evaluator.
class DrawController extends ChangeNotifier {
  final List<List<Offset>> strokes = [];
  List<Offset> current = [];
  bool locked = false;
  /// Bumped only when a stroke is completed/undone/cleared — NOT on every
  /// pointer-move. Widgets like [TracingMeter] that only need to react to a
  /// finished stroke should listen to this instead of the controller itself,
  /// so they don't recompute on every touch-move event.
  final ValueNotifier<int> strokeVersion = ValueNotifier(0);
  void down(Offset p) { if (locked) return; current = [p]; notifyListeners(); }
  void move(Offset p) { if (locked || current.isEmpty) return; current.add(p); notifyListeners(); }
  void up() {
    if (current.isNotEmpty) strokes.add(current);
    current = [];
    notifyListeners();
    strokeVersion.value++;
  }
  void undo() { if (strokes.isNotEmpty) { strokes.removeLast(); notifyListeners(); strokeVersion.value++; } }
  void clear() { strokes.clear(); current = []; notifyListeners(); strokeVersion.value++; }
  bool get isEmpty => strokes.isEmpty;
  @override
  void dispose() { strokeVersion.dispose(); super.dispose(); }
}

class DrawCanvas extends StatelessWidget {
  final DrawController controller;
  final double size;
  final bool showGuideLines;
  final List<Widget> overlays; // placed under the strokes (ghost letter)
  final List<Widget> topOverlays; // chips etc.
  final Color strokeColor;
  final double strokeWidth;
  const DrawCanvas({super.key, required this.controller, required this.size, this.showGuideLines = true,
      this.overlays = const [], this.topOverlays = const [],
      this.strokeColor = AppColors.canvasStroke, this.strokeWidth = 6});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: AppColors.canvasBackground,
        borderRadius: BorderRadius.circular(Rad.xl2),
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Rad.xl2),
        border: Border.all(color: AppColors.primary.withOpacity(0.4), width: 4),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        Positioned.fill(child: CustomPaint(painter: _GridPainter(showGuideLines))),
        ...overlays,
        Positioned.fill(child: DrawSurface(
          controller: controller,
          // Isolated so a finger move repaints only the ink, not the whole screen.
          child: RepaintBoundary(child: CustomPaint(painter: StrokePainterPublic(controller, strokeColor, strokeWidth))),
        )),
        ...topOverlays,
      ]),
    );
  }
}

class _GridPainter extends CustomPainter {
  final bool on;
  _GridPainter(this.on);
  @override
  void paint(Canvas c, Size s) {
    if (on) WritingGuidePainter.paintGuides(c, s);
  }
  @override
  bool shouldRepaint(covariant _GridPainter o) => o.on != on;
}

/// Where the header line (शिरोरेखा) and the base line sit, as fractions of
/// the canvas height. Letters hang from the header line and rest on the base.
const kHeaderLineY = 0.2, kBaseLineY = 0.82;

/// Hindi copybook ruling: a bold header line (शिरोरेखा) the letters hang
/// from, a base line they sit on, a faint dashed middle line and a lightly
/// tinted writing band between them.
class WritingGuidePainter extends CustomPainter {
  final double top, bottom; final bool labels;
  const WritingGuidePainter({this.top = kHeaderLineY, this.bottom = kBaseLineY, this.labels = true});

  static void paintGuides(Canvas c, Size s, {double top = kHeaderLineY, double bottom = kBaseLineY, bool labels = true}) {
    const inset = 12.0;
    final yTop = s.height * top, yBottom = s.height * bottom, yMid = (yTop + yBottom) / 2;
    c.drawRect(Rect.fromLTRB(0, yTop, s.width, yBottom), Paint()..color = AppColors.canvasGridLine.withOpacity(0.25));
    c.drawLine(Offset(inset, yTop), Offset(s.width - inset, yTop), Paint()..color = const Color(0xFFE57373)..strokeWidth = 2.5);
    c.drawLine(Offset(inset, yBottom), Offset(s.width - inset, yBottom), Paint()..color = const Color(0xFF64B5F6)..strokeWidth = 2);
    final dash = Paint()..color = AppColors.border..strokeWidth = 1;
    for (double x = inset; x < s.width - inset; x += 10) {
      c.drawLine(Offset(x, yMid), Offset((x + 5).clampD(0.0, s.width - inset), yMid), dash);
    }
    if (!labels || s.width < 160) return;
    void label(String t, double y, Color col) {
      final tp = TextPainter(text: TextSpan(text: t, style: TextStyle(fontSize: 9, color: col, fontWeight: FontWeight.w700)),
          textDirection: TextDirection.ltr)..layout();
      tp.paint(c, Offset(s.width - inset - tp.width, y - tp.height - 2));
    }
    label('header line', yTop, const Color(0xFFE57373));
    label('base line', yBottom, const Color(0xFF64B5F6));
  }

  @override
  void paint(Canvas c, Size s) => paintGuides(c, s, top: top, bottom: bottom, labels: labels);
  @override
  bool shouldRepaint(covariant WritingGuidePainter o) => o.top != top || o.bottom != bottom || o.labels != labels;
}

/// Pointer surface for every writing canvas. It wins the gesture arena the
/// moment a finger touches it, so a surrounding scroll view never steals the
/// drag — the page stays locked while the child writes.
class DrawSurface extends StatelessWidget {
  final DrawController controller; final Widget child;
  const DrawSurface({super.key, required this.controller, required this.child});
  @override
  Widget build(BuildContext context) => RawGestureDetector(
        behavior: HitTestBehavior.opaque,
        gestures: {EagerGestureRecognizer: GestureRecognizerFactoryWithHandlers<EagerGestureRecognizer>(
            EagerGestureRecognizer.new, (_) {})},
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (e) => controller.down(e.localPosition),
          onPointerMove: (e) => controller.move(e.localPosition),
          onPointerUp: (_) => controller.up(),
          onPointerCancel: (_) => controller.up(),
          child: child,
        ),
      );
}

class StrokePainterPublic extends CustomPainter {
  final DrawController c; final Color color; final double w;
  StrokePainterPublic(this.c, this.color, this.w) : super(repaint: c);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color..strokeWidth = w..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    void draw(List<Offset> pts) {
      if (pts.isEmpty) return;
      if (pts.length == 1) { canvas.drawCircle(pts.first, w / 2, Paint()..color = color); return; }
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (int i = 1; i < pts.length; i++) { path.lineTo(pts[i].dx, pts[i].dy); }
      canvas.drawPath(path, p);
    }
    for (final s in c.strokes) { draw(s); }
    draw(c.current);
  }
  @override
  bool shouldRepaint(covariant StrokePainterPublic o) =>
      o.color != color ||
      o.w != w ||
      o.c.strokes.length != c.strokes.length ||
      o.c.current.length != c.current.length ||
      (o.c.current.isNotEmpty && c.current.isNotEmpty && o.c.current.last != c.current.last);
}

/// Plain canvas used by Speed/Dictation/Comparison/Drill screens:
/// white-cream box, toy shadow, header/base guide lines, orange stroke.
class SimpleCanvas extends StatelessWidget {
  final DrawController controller; final double size; final Color stroke; final double strokeWidth; final bool midLine;
  final Widget? underlay; final double radius; final double? height;
  const SimpleCanvas({super.key, required this.controller, required this.size, this.stroke = AppColors.canvasStroke,
      this.strokeWidth = 5, this.midLine = true, this.underlay, this.radius = Rad.xl, this.height});
  @override
  Widget build(BuildContext context) => Container(
        width: size, height: height ?? size,
        decoration: BoxDecoration(color: AppColors.canvasBackground, borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: AppColors.border),
            boxShadow: const [BoxShadow(color: AppColors.toyShadowColor, offset: Offset(0, 4), blurRadius: 0)]),
        clipBehavior: Clip.antiAlias,
        child: Stack(children: [
          if (midLine) const Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: WritingGuidePainter()))),
          if (underlay != null) Positioned.fill(child: IgnorePointer(child: underlay!)),
          Positioned.fill(child: DrawSurface(
            controller: controller,
            child: RepaintBoundary(child: CustomPaint(painter: StrokePainterPublic(controller, stroke, strokeWidth))),
          )),
        ]),
      );
}
