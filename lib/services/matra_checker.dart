import 'dart:math' as math;
import 'dart:ui' show Offset, Size;
import '../data/models.dart';
import 'ink_recognizer.dart';
import 'stroke_evaluator.dart';

/// A letter with one matra, split into the letter's own model strokes and the
/// matra's, all in the 0..1 block space of [strokesForText] (the header line
/// at y = 0.15, the base line at y = 0.85).
class MatraGlyph {
  final String base, sign;
  final List<List<Pt>> baseStrokes, signStrokes;
  /// Left and right edge of the letter itself.
  final double baseLeft, baseRight;
  const MatraGlyph._(this.base, this.sign, this.baseStrokes, this.signStrokes, this.baseLeft, this.baseRight);

  /// Null when [base] has no stroke model.
  static MatraGlyph? of(String base, String sign) {
    final t = templateForCharacter(base);
    final all = strokesForText(base + sign);
    if (t == null || all == null || all.length < t.strokes.length) return null;
    final n = t.strokes.length;
    final b = all.take(n).toList();
    double lo = double.infinity, hi = -double.infinity;
    for (final p in b.expand((s) => s)) { lo = math.min(lo, p.x); hi = math.max(hi, p.x); }
    return MatraGlyph._(base, sign, b, all.skip(n).toList(), lo, hi);
  }

  String get text => base + sign;
  double get baseMid => (baseLeft + baseRight) / 2;
}

/// Maps block space onto a canvas of [size]: the header and base lines land
/// at [kHeaderLineYFrac] and [kBaseLineYFrac] of the height (lower and higher
/// than on a letter board, so signs above and below fit) and the letter is
/// centred, leaving room on both sides so a sign written on the wrong
/// side is still on the canvas.
class MatraFrame {
  final Size size; final double baseMid;
  const MatraFrame(this.size, this.baseMid);
  static const kHeaderLineYFrac = 0.26, kBaseLineYFrac = 0.74;
  double get _k => size.height * (kBaseLineYFrac - kHeaderLineYFrac) / 0.7;
  double get _y0 => size.height * kHeaderLineYFrac - 0.15 * _k;
  Offset toCanvas(Pt p) => Offset(size.width / 2 + (p.x - baseMid) * _k, _y0 + p.y * _k);
  Pt toBlock(Offset o) => Pt((o.dx - size.width / 2) / _k + baseMid, (o.dy - _y0) / _k);
  /// Block-space strokes as canvas strokes.
  List<List<Offset>> strokes(List<List<Pt>> s) => [for (final st in s) [for (final p in st) toCanvas(p)]];
}

/// How a written matra was judged.
class MatraVerdict {
  /// Where the ink was found: left, right, top, bottom or middle (on the letter).
  final String zone;
  final bool placedRight;
  /// 0-100 shape score of the sign alone; 0 when misplaced.
  final int accuracy;
  /// The handwriting model read the letter + sign as a different sign.
  final String? readAs;
  const MatraVerdict(this.zone, this.placedRight, this.accuracy, {this.readAs});
  int get stars => placedRight ? math.max(1, starsForAccuracy(accuracy)) : 0;
  /// Good enough to move on: in the right spot and recognisably the sign.
  bool get passed => placedRight && accuracy >= kMatraPass && readAs == null;
}

/// Lowest shape score that counts as the sign (kept gentle for young writers).
const kMatraPass = 50;

/// Which side of the letter the ink in [userBlock] (block space) sits on.
/// Signs with a tall stem (ा ि ी ो ौ) are placed by that stem; everything
/// else by the centre of the ink.
String matraZone(List<List<Pt>> userBlock, MatraGlyph g) {
  final pts = [for (final s in userBlock) ...s];
  if (pts.isEmpty) return 'middle';
  double mx = 0, my = 0;
  for (final p in pts) { mx += p.x; my += p.y; }
  mx /= pts.length; my /= pts.length;
  final w = g.baseRight - g.baseLeft;
  // The tallest stroke, if it is stem-like.
  List<Pt>? stem; double stemH = 0;
  for (final s in userBlock) {
    if (s.isEmpty) continue;
    final ys = s.map((p) => p.y);
    final h = ys.reduce(math.max) - ys.reduce(math.min);
    if (h > stemH) { stemH = h; stem = s; }
  }
  if (stem != null && stemH >= 0.35) {
    final sx = stem.map((p) => p.x).reduce((a, b) => a + b) / stem.length;
    if (sx <= g.baseLeft + w * 0.15) return 'left';
    if (sx >= g.baseRight - w * 0.15) return 'right';
    return 'middle';
  }
  if (my < 0.2) return 'top';
  if (my > 0.8) return 'bottom';
  if (mx <= g.baseLeft + w * 0.1) return 'left';
  if (mx >= g.baseRight - w * 0.1) return 'right';
  return 'middle';
}

/// Signs made only of dots: their shape is judged by the number of marks.
const _dotSigns = {'ं': 1, 'ः': 2};

/// Grades a matra written next to a printed letter: first where it is (the
/// child gets a placement hint, not a cross, when it is on the wrong side),
/// then its shape with the stroke checker used for letters.
MatraVerdict checkMatraPlacement(List<List<Offset>> strokes, MatraGlyph g, String position, MatraFrame f) {
  final ink = [for (final s in strokes) if (s.isNotEmpty) s];
  if (ink.isEmpty) return const MatraVerdict('middle', false, 0);
  final block = [for (final s in ink) [for (final o in s) f.toBlock(o)]];
  final zone = matraZone(block, g);
  if (zone != position) return MatraVerdict(zone, false, 0);
  final dots = _dotSigns[g.sign];
  if (dots != null) {
    // Each dot must be small; the count must match.
    final small = block.every((s) {
      final xs = s.map((p) => p.x), ys = s.map((p) => p.y);
      return xs.reduce(math.max) - xs.reduce(math.min) < 0.3 && ys.reduce(math.max) - ys.reduce(math.min) < 0.3;
    });
    final acc = !small ? 40 : block.length == dots ? 95 : (block.length - dots).abs() == 1 ? 60 : 40;
    return MatraVerdict(zone, true, acc);
  }
  // Size doesn't matter for a sign on its own (it is small by nature).
  final r = evaluateAgainst([for (final s in block) [for (final p in s) Offset(p.x, p.y)]], g.signStrokes, 0);
  return MatraVerdict(zone, true, r.accuracy);
}

/// [checkMatraPlacement] plus a second opinion from the on-device handwriting
/// model (mobile only): the printed letter and the child's sign are read
/// together, and a confident reading of the right syllable lifts a rough
/// shape to a pass, while a reading as another sign is pointed out.
Future<MatraVerdict> gradeMatra(List<List<Offset>> strokes, MatraGlyph g, String position, MatraFrame f) async {
  final v = checkMatraPlacement(strokes, g, position, f);
  if (!v.placedRight || g.sign.isEmpty) return v;
  final candidates = await InkModel.recognize([...f.strokes(g.baseStrokes), ...strokes], f.size);
  if (candidates == null || candidates.isEmpty) return v;
  final top = candidates.take(5).toList();
  if (top.contains(g.text)) {
    return MatraVerdict(v.zone, true, math.max(v.accuracy, kRecognisedFloor));
  }
  final first = top.first;
  if (first.length == 2 && first.startsWith(g.base) && first != g.text && v.accuracy < 80) {
    return MatraVerdict(v.zone, true, math.min(v.accuracy, kOtherLetterCap), readAs: first.substring(1));
  }
  return v;
}
