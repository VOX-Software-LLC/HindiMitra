import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../data/models.dart';
import '../services/stroke_evaluator.dart';
import '../theme/palette.dart';
import 'draw_canvas.dart';

/// Colour of each stroke in the guide (stroke 1 red, 2 blue, 3 green, ...).
const kStrokeColors = [Color(0xFFE53935), Color(0xFF1E88E5), Color(0xFF43A047), Color(0xFF8E24AA), Color(0xFFFB8C00)];

/// Stroke-order hint in the style of a tracing worksheet: the letter as a thick
/// grey stencil, every stroke as a coloured arrowed path with numbered steps,
/// a green dot where to start and a red dot where to stop. With [progress]
/// < 1 only that much of the path is drawn and a "finger" dot leads it, so it
/// doubles as the animated demo.
class StrokeOrderGuide extends StatelessWidget {
  final String character;
  final double progress;
  final bool showStencil, showNumbers;
  final double top, bottom;
  const StrokeOrderGuide({super.key, required this.character, this.progress = 1, this.showStencil = true,
      this.showNumbers = true, this.top = kHeaderLineY, this.bottom = kBaseLineY});

  @override
  Widget build(BuildContext context) {
    final strokes = strokesForText(character);
    if (strokes == null) return const SizedBox.expand();
    return CustomPaint(size: Size.infinite, painter: StrokeOrderPainter(strokes, progress,
        showStencil: showStencil, showNumbers: showNumbers, top: top, bottom: bottom));
  }
}

/// Looping animated version of [StrokeOrderGuide] (draws, holds, repeats).
class AnimatedStrokeGuide extends StatefulWidget {
  final String character; final bool showStencil;
  final double top, bottom;
  const AnimatedStrokeGuide({super.key, required this.character, this.showStencil = true,
      this.top = kHeaderLineY, this.bottom = kBaseLineY});
  @override
  State<AnimatedStrokeGuide> createState() => _AnimatedStrokeGuideState();
}

class _AnimatedStrokeGuideState extends State<AnimatedStrokeGuide> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3600))..repeat();
  @override
  void dispose() { c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => RepaintBoundary(child: AnimatedBuilder(
        animation: c,
        // Draw for the first 75 %, then hold the finished guide.
        builder: (_, __) => StrokeOrderGuide(character: widget.character, progress: (c.value / 0.75).clamp(0.0, 1.0),
            showStencil: widget.showStencil, top: widget.top, bottom: widget.bottom),
      ));
}

class StrokeOrderPainter extends CustomPainter {
  final List<List<Pt>> strokes; final double progress; final bool showStencil, showNumbers;
  final double top, bottom;
  StrokeOrderPainter(this.strokes, this.progress,
      {this.showStencil = true, this.showNumbers = true, this.top = kHeaderLineY, this.bottom = kBaseLineY});

  /// Fits the template's bounding box between the header and base lines,
  /// keeping its proportions, so the guide sits on the ruling like real writing.
  List<List<Offset>> _layout(Size size) {
    final all = strokes.expand((e) => e);
    double minX = 1, maxX = 0, minY = 1, maxY = 0;
    for (final p in all) {
      minX = math.min(minX, p.x); maxX = math.max(maxX, p.x);
      minY = math.min(minY, p.y); maxY = math.max(maxY, p.y);
    }
    final w = math.max(maxX - minX, 0.05), h = math.max(maxY - minY, 0.05);
    final boxTop = size.height * top, boxH = size.height * (bottom - top);
    final scale = math.min(boxH / h, size.width * 0.8 / w);
    final ox = (size.width - w * scale) / 2, oy = boxTop + (boxH - h * scale) / 2;
    return [for (final s in strokes) [for (final p in s) Offset(ox + (p.x - minX) * scale, oy + (p.y - minY) * scale)]];
  }

  static double _len(List<Offset> s) {
    double l = 0;
    for (int i = 1; i < s.length; i++) { l += (s[i] - s[i - 1]).distance; }
    return l;
  }

  /// Point at distance [d] along the polyline, and the heading there.
  static (Offset, double) _at(List<Offset> s, double d) {
    if (s.length == 1) return (s.first, 0);
    for (int i = 1; i < s.length; i++) {
      final seg = (s[i] - s[i - 1]).distance;
      if (d <= seg || i == s.length - 1) {
        final f = seg == 0 ? 0.0 : (d / seg).clamp(0.0, 1.0);
        return (Offset.lerp(s[i - 1], s[i], f)!, (s[i] - s[i - 1]).direction);
      }
      d -= seg;
    }
    return (s.last, 0);
  }

  void _arrowHead(Canvas c, Offset tip, double angle, double size, Paint p) {
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(tip.dx - size * math.cos(angle - 0.45), tip.dy - size * math.sin(angle - 0.45))
      ..lineTo(tip.dx - size * math.cos(angle + 0.45), tip.dy - size * math.sin(angle + 0.45))
      ..close();
    c.drawPath(path, p..style = PaintingStyle.fill);
  }

  void _label(Canvas c, String text, Offset at, Color color, double size) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(fontSize: size, fontWeight: FontWeight.w900, color: color)),
      textDirection: TextDirection.ltr,
    )..layout();
    final r = math.max(tp.width, tp.height) / 2 + 3;
    c.drawCircle(at, r, Paint()..color = Colors.white.withOpacity(0.92));
    c.drawCircle(at, r, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.5);
    tp.paint(c, at - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (strokes.isEmpty) return;
    final laid = _layout(size);
    final unit = math.min(size.width, size.height);
    if (showStencil) {
      final stencil = Paint()..color = const Color(0xFFBDB8B0).withOpacity(0.55)..style = PaintingStyle.stroke
        ..strokeWidth = unit * 0.075..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
      for (final s in laid) {
        if (s.length < 2) { canvas.drawCircle(s.first, unit * 0.04, Paint()..color = stencil.color); continue; }
        canvas.drawPath(Path()..addPolygon(s, false), stencil);
      }
    }
    final lengths = [for (final s in laid) _len(s)];
    final total = lengths.fold<double>(0, (a, b) => a + b);
    var budget = total * progress.clamp(0.0, 1.0);
    int number = 1;
    final numSize = (unit * 0.045).clamp(9.0, 14.0);
    // Few, well-spaced numbers (like a worksheet), never more than 4 per stroke.
    final spacing = unit * 0.3;
    Offset? finger;

    for (int k = 0; k < laid.length; k++) {
      final s = laid[k];
      final color = kStrokeColors[k % kStrokeColors.length];
      final len = lengths[k];
      final shown = budget.clamp(0.0, len);
      budget -= len;
      // Start dot is always visible so the child knows where each stroke begins.
      canvas.drawCircle(s.first, unit * 0.022, Paint()..color = const Color(0xFF2E7D32));
      if (shown <= 0) continue;

      final line = Paint()..color = color.withOpacity(0.85)..strokeWidth = math.max(2.5, unit * 0.012)
        ..style = PaintingStyle.stroke..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
      final path = Path()..moveTo(s.first.dx, s.first.dy);
      for (double d = 4; d < shown; d += 4) {
        final (p, _) = _at(s, d);
        path.lineTo(p.dx, p.dy);
      }
      final (head, headAngle) = _at(s, shown);
      path.lineTo(head.dx, head.dy);
      canvas.drawPath(path, line);

      // Arrow heads every [spacing] and at the tip, numbered steps between them.
      final marks = (len / spacing).round().clamp(1, 4);
      for (int m = 0; m <= marks; m++) {
        final d = len * m / marks;
        if (d > shown + 0.5) break;
        final (p, a) = _at(s, d);
        if (m > 0) _arrowHead(canvas, p, a, unit * 0.035, Paint()..color = color);
        if (showNumbers && m < marks) _label(canvas, '${number++}', p + Offset.fromDirection(a - math.pi / 2, unit * 0.06), color, numSize);
      }
      if (shown >= len - 0.5) {
        canvas.drawCircle(s.last, unit * 0.02, Paint()..color = const Color(0xFFD32F2F));
      } else {
        finger = head;
        _arrowHead(canvas, head, headAngle, unit * 0.04, Paint()..color = color);
      }
      if (showNumbers && len > 0 && s.length > 1 && k == 0) {
        _label(canvas, 'START', s.first + Offset(-unit * 0.08, -unit * 0.05), const Color(0xFF2E7D32), numSize * 0.75);
      }
    }
    if (finger != null) {
      canvas.drawCircle(finger, unit * 0.04, Paint()..color = AppColors.primary.withOpacity(0.35));
      canvas.drawCircle(finger, unit * 0.022, Paint()..color = AppColors.primaryDark);
    }
  }

  @override
  bool shouldRepaint(covariant StrokeOrderPainter o) =>
      o.progress != progress || o.strokes != strokes || o.showStencil != showStencil || o.top != top || o.bottom != bottom;
}
