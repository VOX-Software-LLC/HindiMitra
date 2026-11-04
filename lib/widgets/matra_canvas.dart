import 'dart:ui' show PathMetric;
import 'package:flutter/material.dart';
import '../data/models.dart';
import '../services/matra_checker.dart';
import '../theme/palette.dart';
import 'draw_canvas.dart';

/// Writing board for one matra: the letter is printed in the middle on the
/// copybook lines and the child writes only the sign next to it. [reveal]
/// draws the sign stroke by stroke (the "See" animation, or "Show me" as a
/// faint ghost while writing). [hintZone] lights up where the sign belongs.
class MatraCanvas extends StatelessWidget {
  final MatraGlyph glyph;
  final double width;
  final DrawController? controller;
  final Animation<double>? reveal;
  /// Paint the revealed sign faint (a ghost to copy) instead of solid.
  final bool ghost;
  final String? hintZone;
  const MatraCanvas({super.key, required this.glyph, required this.width, this.controller, this.reveal,
      this.ghost = false, this.hintZone});

  /// Height for a canvas [width] wide (room above and below the lines).
  static double heightFor(double width) => width / 1.35;

  MatraFrame frame() => MatraFrame(Size(width, heightFor(width)), glyph.baseMid);

  @override
  Widget build(BuildContext context) {
    final h = heightFor(width);
    final f = frame();
    return Container(
      width: width, height: h,
      decoration: BoxDecoration(color: AppColors.canvasBackground, borderRadius: BorderRadius.circular(Rad.xl2),
          border: Border.all(color: AppColors.primary.withOpacity(0.4), width: 3)),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        Positioned.fill(child: CustomPaint(painter: _BoardPainter(glyph, f, hintZone))),
        if (reveal != null)
          Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _SignPainter(glyph, f, reveal!, ghost)))),
        if (controller != null)
          Positioned.fill(child: DrawSurface(
            controller: controller!,
            child: RepaintBoundary(child: CustomPaint(
                painter: StrokePainterPublic(controller!, AppColors.canvasStroke, width * 0.022))),
          )),
      ]),
    );
  }
}

/// Block-space rectangle where a sign at [position] belongs.
Rect matraZoneRect(MatraGlyph g, String position) => switch (position) {
      'left' => Rect.fromLTRB(g.baseLeft - 0.42, 0.0, g.baseLeft - 0.02, 0.9),
      'right' => Rect.fromLTRB(g.baseRight + 0.02, 0.0, g.baseRight + 0.42, 0.9),
      'top' => Rect.fromLTRB(g.baseLeft, -0.1, g.baseRight, 0.17),
      _ => Rect.fromLTRB(g.baseLeft, 0.83, g.baseRight, 1.1),
    };

class _BoardPainter extends CustomPainter {
  final MatraGlyph g; final MatraFrame f; final String? zone;
  _BoardPainter(this.g, this.f, this.zone);

  @override
  void paint(Canvas c, Size s) {
    WritingGuidePainter.paintGuides(c, s, top: MatraFrame.kHeaderLineYFrac, bottom: MatraFrame.kBaseLineYFrac, labels: false);
    if (zone != null) {
      final r = matraZoneRect(g, zone!);
      final a = f.toCanvas(Pt(r.left, r.top)), b = f.toCanvas(Pt(r.right, r.bottom));
      final rr = RRect.fromRectAndRadius(Rect.fromPoints(a, b), const Radius.circular(14));
      c.drawRRect(rr, Paint()..color = AppColors.success.withOpacity(0.16));
      c.drawRRect(rr, Paint()..color = AppColors.success.withOpacity(0.7)..style = PaintingStyle.stroke..strokeWidth = 2);
    }
    final p = Paint()..color = AppColors.textPrimary.withOpacity(0.78)..strokeWidth = s.width * 0.03
      ..style = PaintingStyle.stroke..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    for (final st in f.strokes(g.baseStrokes)) { c.drawPath(_path(st), p); }
  }

  @override
  bool shouldRepaint(covariant _BoardPainter o) => o.g != g || o.zone != zone || o.f.size != f.size;
}

class _SignPainter extends CustomPainter {
  final MatraGlyph g; final MatraFrame f; final Animation<double> t; final bool ghost;
  _SignPainter(this.g, this.f, this.t, this.ghost) : super(repaint: t);

  @override
  void paint(Canvas c, Size s) {
    final paths = [for (final st in f.strokes(g.signStrokes)) _path(st)];
    final metrics = <PathMetric>[for (final p in paths) ...p.computeMetrics()];
    // Dots (ं ः) are too short to animate: each takes a fixed share and pops in.
    const dotLen = 10.0;
    double share(PathMetric m) => m.length < dotLen ? dotLen : m.length;
    final total = metrics.fold<double>(0, (a, m) => a + share(m));
    final color = ghost ? AppColors.primary.withOpacity(0.35) : AppColors.primary;
    final paint = Paint()..color = color..strokeWidth = s.width * 0.03..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    var left = total * t.value;
    for (final m in metrics) {
      if (left <= 0) break;
      if (m.length < dotLen) {
        final o = m.getTangentForOffset(0)?.position;
        if (o != null) c.drawCircle(o, s.width * 0.02, Paint()..color = color);
      } else {
        c.drawPath(m.extractPath(0, left.clamp(0, m.length).toDouble()), paint);
      }
      left -= share(m);
    }
  }

  @override
  bool shouldRepaint(covariant _SignPainter o) => o.g != g || o.ghost != ghost;
}

Path _path(List<Offset> pts) {
  final p = Path();
  if (pts.isEmpty) return p;
  p.moveTo(pts.first.dx, pts.first.dy);
  if (pts.length == 1) { p.lineTo(pts.first.dx + 0.5, pts.first.dy + 0.5); return p; }
  for (final o in pts.skip(1)) { p.lineTo(o.dx, o.dy); }
  return p;
}
