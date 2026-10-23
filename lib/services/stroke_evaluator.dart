import 'dart:math' as math;
import 'dart:ui' show Offset;
import '../data/models.dart';
import '../util/num_ext.dart';

/// Handwriting grader. Strokes are lists of canvas points; templates are lists
/// of 0..1 points. Both are normalised with a *uniform* scale (aspect ratio is
/// kept, so a squashed or stretched letter is penalised) and then compared on
/// five independent signals:
///
///  * coverage   – how much of the letter's path the child actually drew (recall)
///  * precision  – how much of the child's ink lies on the letter (no scribbles)
///  * shape      – mean two-way distance between the drawing and the letter
///  * direction  – each stroke drawn the right way round
///  * proportion – width/height ratio close to the letter's
///
/// plus a stroke-count penalty. The blend is stretched onto 0-100 so a careful
/// attempt, a sloppy one and a wrong letter land far apart instead of all
/// collapsing to the same score.
class EvaluationResult {
  final int stars;
  final double coverageScore, directionScore, strokeCountPenalty;
  final String feedback;
  final double shapeScore, smoothnessScore, precisionScore, proportionScore;
  /// Overall 0-100 accuracy; [stars] is derived from it via [starsForAccuracy].
  final int accuracy;
  const EvaluationResult(this.stars, this.coverageScore, this.directionScore, this.strokeCountPenalty, this.feedback,
      {this.shapeScore = 0, this.smoothnessScore = 0, this.precisionScore = 0, this.proportionScore = 0, this.accuracy = 0});
}

/// 3 stars at >= 90 %, 2 at 70-89 %, 1 at 50-69 %, 0 below 50 %.
int starsForAccuracy(int pct) => pct >= 90 ? 3 : pct >= 70 ? 2 : pct >= 50 ? 1 : 0;

class StrictEvaluationResult extends EvaluationResult {
  final bool isTargetBestMatch;
  final String? bestMatchCharacter;
  StrictEvaluationResult(EvaluationResult r, this.isTargetBestMatch, this.bestMatchCharacter)
      : super(r.stars, r.coverageScore, r.directionScore, r.strokeCountPenalty, r.feedback,
            shapeScore: r.shapeScore, smoothnessScore: r.smoothnessScore, precisionScore: r.precisionScore,
            proportionScore: r.proportionScore, accuracy: r.accuracy);
}

class _BBox {
  final double minX, maxX, minY, maxY;
  _BBox(this.minX, this.maxX, this.minY, this.maxY);
  double get width => maxX - minX;
  double get height => maxY - minY;
}

_BBox _bbox(Iterable<Pt> pts) {
  double minX = double.infinity, maxX = -double.infinity, minY = double.infinity, maxY = -double.infinity;
  for (final p in pts) {
    minX = math.min(minX, p.x); maxX = math.max(maxX, p.x);
    minY = math.min(minY, p.y); maxY = math.max(maxY, p.y);
  }
  if (minX == double.infinity) return _BBox(0, 0, 0, 0);
  return _BBox(minX, maxX, minY, maxY);
}

/// Centre the strokes on (0.5, 0.5) and scale uniformly so the longer side is 1.
List<List<Pt>> _normalize(List<List<Pt>> strokes) {
  final b = _bbox(strokes.expand((e) => e));
  final scale = math.max(math.max(b.width, b.height), 1e-6);
  final cx = (b.minX + b.maxX) / 2, cy = (b.minY + b.maxY) / 2;
  return [for (final s in strokes) [for (final p in s) Pt((p.x - cx) / scale + 0.5, (p.y - cy) / scale + 0.5)]];
}

List<Pt> _resample(List<Pt> points, int target) {
  if (points.isEmpty) return [];
  if (points.length == 1 || target < 2) return List.filled(math.max(target, 1), points[0]);
  double total = 0;
  final seg = <double>[0];
  for (int i = 1; i < points.length; i++) {
    final dx = points[i].x - points[i - 1].x, dy = points[i].y - points[i - 1].y;
    total += math.sqrt(dx * dx + dy * dy);
    seg.add(total);
  }
  final out = <Pt>[];
  int si = 0;
  for (int i = 0; i < target; i++) {
    final tl = (i / (target - 1)) * total;
    while (si < seg.length - 2 && seg[si + 1] < tl) { si++; }
    final p0 = points[si], p1 = points[si + 1];
    final sl = seg[si + 1] - seg[si];
    final t = sl > 0 ? ((tl - seg[si]) / sl).clampD(0.0, 1.0) : 0.0;
    out.add(Pt(p0.x + t * (p1.x - p0.x), p0.y + t * (p1.y - p0.y)));
  }
  return out;
}

double _length(List<Pt> s) {
  double l = 0;
  for (int i = 1; i < s.length; i++) {
    final dx = s[i].x - s[i - 1].x, dy = s[i].y - s[i - 1].y;
    l += math.sqrt(dx * dx + dy * dy);
  }
  return l;
}

/// Points spaced ~[step] apart along every stroke (dots keep one point).
List<Pt> _densify(List<List<Pt>> strokes, double step) => [
      for (final s in strokes) ..._resample(s, math.max(2, (_length(s) / step).ceil() + 1)),
    ];

/// Weight of each [_densify] point. Long straight strokes — the header line
/// and the standing line, which nearly every letter shares — count for much
/// less than curves, loops and hooks, which are what tell letters apart.
List<double> _weights(List<List<Pt>> strokes, double step) => [
      for (final s in strokes)
        ...List.filled(math.max(2, (_length(s) / step).ceil() + 1), _isStructural(s) ? 0.25 : 1.0),
    ];

bool _isStructural(List<Pt> s) {
  final len = _length(s);
  if (len < 0.3) return false;
  final dx = s.last.x - s.first.x, dy = s.last.y - s.first.y;
  return math.sqrt(dx * dx + dy * dy) / len > 0.97;
}

/// Lowest share of any single stroke of [strokes] lying on [other].
double _worstStroke(List<List<Pt>> strokes, List<Pt> other) {
  double worst = 1;
  for (final st in strokes) {
    final len = _length(st);
    final pts = _resample(st, math.max(2, (len / _step).ceil() + 1));
    // Dots and ticks are tiny; give them a little more room.
    final tol = (len < 0.05 ? 1.8 : 1.4) * gradeTolerance;
    final hit = pts.where((p) => _nearest(p, other) <= tol).length / pts.length;
    if (hit < worst) worst = hit;
  }
  return worst;
}

double _nearest(Pt p, List<Pt> pts) {
  double best = double.infinity;
  for (final q in pts) {
    final dx = p.x - q.x, dy = p.y - q.y;
    final d = dx * dx + dy * dy;
    if (d < best) best = d;
  }
  return math.sqrt(best);
}

/// Weighted fraction of [from] points lying within [tol] of [to], plus their
/// weighted mean distance.
(double, double) _match(List<Pt> from, List<double> w, List<Pt> to, double tol) {
  if (from.isEmpty || to.isEmpty) return (0, 1);
  double hit = 0, sum = 0, total = 0;
  for (int i = 0; i < from.length; i++) {
    final d = _nearest(from[i], to);
    if (d <= tol) hit += w[i];
    sum += d * w[i];
    total += w[i];
  }
  return (hit / total, sum / total);
}

double _angleDiff(Pt a0, Pt a1, Pt b0, Pt b1) {
  final ra = math.atan2(a1.y - a0.y, a1.x - a0.x);
  final ua = math.atan2(b1.y - b0.y, b1.x - b0.x);
  double d = (ra - ua).abs();
  if (d > math.pi) d = 2 * math.pi - d;
  return d;
}

double _pairDist(List<Pt> a, List<Pt> b) {
  double s = 0;
  for (int i = 0; i < a.length; i++) {
    final dx = a[i].x - b[i].x, dy = a[i].y - b[i].y;
    s += math.sqrt(dx * dx + dy * dy);
  }
  return s / a.length;
}

/// Direction + order: with the right stroke count, user stroke i is compared
/// with template stroke i (so strokes drawn in the wrong order score low);
/// otherwise each is matched to the template stroke it lies closest to. Each
/// pair is compared point-by-point forwards and reversed — drawn the right way
/// round, the forward distance is much smaller; drawn backwards, the reverse is.
double _direction(List<List<Pt>> ref, List<List<Pt>> user) {
  if (ref.isEmpty || user.isEmpty) return 0;
  const target = 16;
  final paired = ref.length == user.length;
  final all = [for (final r in ref) _resample(r, target)];
  double sum = 0, weight = 0;
  for (int i = 0; i < user.length; i++) {
    final us = user[i];
    if (_length(us) < 0.04) continue; // dots/ticks carry no direction
    final candidates = paired ? [all[i]] : all;
    final u = _resample(us, target);
    final ur = u.reversed.toList();
    double bestF = double.infinity, bestR = double.infinity;
    for (final r in candidates) {
      final f = _pairDist(u, r), b = _pairDist(ur, r);
      if (math.min(f, b) < math.min(bestF, bestR)) { bestF = f; bestR = b; }
    }
    // 1 = clearly forwards, 0 = clearly backwards, ~0.5 = can't tell (loops).
    final s = bestR / math.max(bestF + bestR, 1e-6);
    final w = _length(us);
    sum += ((s - 0.3) / 0.4).clampD(0.0, 1.0) * w;
    weight += w;
  }
  return weight == 0 ? 1.0 : sum / weight;
}

/// Shaky, uncontrolled strokes have erratic turning angles (high variance).
double _smoothness(List<List<Pt>> user) {
  double sum = 0; int counted = 0;
  for (final s in user) {
    if (s.length < 4 || _length(s) < 0.08) continue;
    final pts = _resample(s, math.min(24, s.length));
    final turns = <double>[];
    for (int i = 2; i < pts.length; i++) {
      turns.add(_angleDiff(pts[i - 2], pts[i - 1], pts[i - 1], pts[i]));
    }
    if (turns.isEmpty) continue;
    final mean = turns.reduce((a, b) => a + b) / turns.length;
    final variance = turns.map((t) => (t - mean) * (t - mean)).reduce((a, b) => a + b) / turns.length;
    sum += (1 - variance / 0.6).clampD(0.0, 1.0);
    counted++;
  }
  return counted == 0 ? 1.0 : sum / counted;
}

double _strokeCountPenalty(int rc, int uc) {
  if (rc == 0) return 0;
  if (uc < rc) return math.min(0.5, (rc - uc) * 0.12);
  return math.min(0.3, (uc - rc) * 0.06);
}

String? getActionableTip(EvaluationResult r, String letterId) {
  if (r.stars >= 3) return null;
  final t = AppData.strokeTemplates[letterId];
  final strokeCount = t?.strokes.length ?? 1;
  if (r.strokeCountPenalty >= 0.2) {
    return strokeCount == 1
        ? "Tip: This letter is one continuous stroke — don't lift your finger."
        : 'Tip: This letter has $strokeCount strokes. Tap "Hint" to see the numbered order.';
  }
  if (r.proportionScore < 0.6) return 'Tip: Your letter is too squashed or stretched — match the width and height of the model.';
  if (r.coverageScore < 0.6) return 'Tip: Some parts are missing — draw every part of the letter, including the header line.';
  if (r.precisionScore < 0.6) return 'Tip: Extra lines are going outside the letter — stay on the shape.';
  if (r.directionScore < 0.6) return 'Tip: Follow the arrows — start at the green dot and draw in the shown direction.';
  if (r.shapeScore < 0.7) return 'Tip: The curves are a little off — trace slowly along the model.';
  return 'Tip: Almost there! One more careful try.';
}

StrokeTemplate? _findByChar(String ch) {
  for (final t in AppData.strokeTemplates.values) { if (t.character == ch) return t; }
  return null;
}

/// Template for a character, or for its base consonant when it carries a
/// matra/nukta (so कि, सड़ etc. are still graded on the letter they're built on).
StrokeTemplate? templateForCharacter(String ch) {
  final exact = _findByChar(ch);
  if (exact != null || ch.isEmpty) return exact;
  return _findByChar(ch.substring(0, 1));
}

/// Reference strokes for any written block: a letter's own template, or for a
/// consonant + matra (की, रा, मो, ड़) the base letter with the matra's strokes
/// added in the usual place (ा/ी stem on the right, ि on the left, े above,
/// ु below, ं dot above, ़ dot below). Null when there is no base template.
List<List<Pt>>? strokesForText(String text) {
  final exact = _findByChar(text);
  if (exact != null) return exact.strokes;
  if (text.isEmpty) return null;
  final base = _findByChar(text.substring(0, 1));
  if (base == null) return null;
  final b = _bbox(base.strokes.expand((e) => e));
  final w = math.max(b.width, 1e-3), h = math.max(b.height, 1e-3);
  // Base letter mapped into [x0, x1] × [0.15, 0.85]; matras fill the rest.
  List<List<Pt>> fit(double x0, double x1) => [
        for (final s in base.strokes)
          [for (final p in s) Pt(x0 + (p.x - b.minX) / w * (x1 - x0), 0.15 + (p.y - b.minY) / h * 0.7)],
      ];
  final marks = text.substring(1);
  final rightStem = marks.contains('ा') || marks.contains('ी') || marks.contains('ो') || marks.contains('ौ');
  final leftStem = marks.contains('ि');
  final out = fit(leftStem ? 0.3 : 0.0, rightStem ? 0.7 : 1.0);
  for (final m in marks.split('')) {
    switch (m) {
      case 'ा': out.add(const [Pt(0.86, 0.15), Pt(0.86, 0.85)]);
      case 'ी': out.addAll(const [[Pt(0.86, 0.15), Pt(0.86, 0.85)], [Pt(0.86, 0.15), Pt(0.72, 0.02), Pt(0.48, 0.02), Pt(0.36, 0.15)]]);
      case 'ि': out.addAll(const [[Pt(0.14, 0.15), Pt(0.14, 0.85)], [Pt(0.14, 0.15), Pt(0.3, 0.02), Pt(0.55, 0.02), Pt(0.68, 0.15)]]);
      case 'ो': out.addAll(const [[Pt(0.86, 0.15), Pt(0.86, 0.85)], [Pt(0.86, 0.15), Pt(0.74, 0.0)]]);
      case 'ौ': out.addAll(const [[Pt(0.86, 0.15), Pt(0.86, 0.85)], [Pt(0.86, 0.15), Pt(0.74, 0.0)], [Pt(0.78, 0.15), Pt(0.66, 0.0)]]);
      case 'े': out.add(const [Pt(0.55, 0.15), Pt(0.4, 0.0)]);
      case 'ै': out.addAll(const [[Pt(0.55, 0.15), Pt(0.4, 0.0)], [Pt(0.68, 0.15), Pt(0.53, 0.0)]]);
      case 'ु': out.add(const [Pt(0.5, 0.86), Pt(0.4, 0.95), Pt(0.5, 1.0), Pt(0.6, 0.96)]);
      case 'ू': out.add(const [Pt(0.45, 0.86), Pt(0.6, 0.93), Pt(0.45, 1.0)]);
      case 'ं': out.add(const [Pt(0.62, 0.04), Pt(0.63, 0.05)]);
      case 'ँ': out.addAll(const [[Pt(0.5, 0.08), Pt(0.6, 0.12), Pt(0.7, 0.08)], [Pt(0.6, 0.02), Pt(0.61, 0.03)]]);
      case '़': out.add(const [Pt(0.45, 0.94), Pt(0.46, 0.95)]);
    }
  }
  return out;
}

EvaluationResult evaluateStrokesByCharacter(List<List<Offset>> paths, String character, double canvasSize) =>
    evaluateAgainst(paths, strokesForText(character) ?? const [], canvasSize);

({String letterId, String character, double combinedScore, EvaluationResult result})? findBestMatchingLetter(
    List<List<Offset>> paths, double canvasSize) {
  if (paths.isEmpty) return null;
  ({String letterId, String character, double combinedScore, EvaluationResult result})? best;
  for (final e in AppData.strokeTemplates.entries) {
    final r = evaluateAgainst(paths, e.value.strokes, canvasSize);
    // Rank on the continuous blend, not the rounded %, so ties are rare.
    final combined = r.accuracy + r.shapeScore;
    if (best == null || combined > best.combinedScore) {
      best = (letterId: e.key, character: e.value.character, combinedScore: combined, result: r);
    }
  }
  return best;
}

StrictEvaluationResult evaluateLetterStrict(List<List<Offset>> paths, String character, double canvasSize) {
  final result = evaluateStrokesByCharacter(paths, character, canvasSize);
  // Only bare letters are compared against the alphabet; matra blocks aren't.
  if (paths.isEmpty || _findByChar(character) == null) return StrictEvaluationResult(result, true, null);
  final best = findBestMatchingLetter(paths, canvasSize);
  if (best == null) return StrictEvaluationResult(result, true, null);
  final wrong = best.character != character && best.result.accuracy >= result.accuracy + 12;
  return StrictEvaluationResult(result, !wrong, wrong ? best.character : null);
}

EvaluationResult evaluateStrokes(List<List<Offset>> userPaths, String letterId, double canvasSize) {
  final template = AppData.strokeTemplates[letterId];
  if (template == null) return const EvaluationResult(0, 0, 0, 1, 'Letter template not found.');
  return evaluateAgainst(userPaths, template.strokes, canvasSize);
}

const _step = 0.02;
/// How far (as a fraction of the letter's size) a point may be from the model
/// and still count as on it, and the mean distance at which shape scores 0.
const gradeTolerance = 0.075, gradeShapeScale = 0.16;

/// Grades [userPaths] (canvas pixels) against arbitrary 0..1 reference strokes.
/// With no reference strokes it can only judge neatness, so it is capped at 2★.
EvaluationResult evaluateAgainst(List<List<Offset>> userPaths, List<List<Pt>> refStrokes, double canvasSize) {
  final raw = <List<Pt>>[
    for (final s in userPaths) if (s.isNotEmpty) [for (final o in s) Pt(o.dx, o.dy)],
  ];
  if (raw.isEmpty) return const EvaluationResult(0, 0, 0, 1, 'No strokes detected. Please draw the letter.');
  final user = _normalize(raw);
  final userBox = _bbox(raw.expand((e) => e));
  // A drawing smaller than ~12 % of the canvas is too tiny to read.
  final sizeFactor = canvasSize <= 0 ? 1.0
      : (math.max(userBox.width, userBox.height) / canvasSize / 0.25).clampD(0.4, 1.0);
  final smooth = _smoothness(user);

  if (refStrokes.isEmpty) {
    final acc = (40 + smooth * 35 * sizeFactor).round().clamp(0, 75);
    return EvaluationResult(starsForAccuracy(acc), 0.5, 0.5, 0, _feedbackFor(acc),
        smoothnessScore: smooth, accuracy: acc, precisionScore: 0.5, proportionScore: 0.5, shapeScore: 0.5);
  }

  final ref = _normalize(refStrokes);
  final refPts = _densify(ref, _step), userPts = _densify(user, _step);
  final (pointCoverage, refToUser) = _match(refPts, _weights(ref, _step), userPts, gradeTolerance);
  final (pointPrecision, userToRef) = _match(userPts, _weights(user, _step), refPts, gradeTolerance);
  // A whole missing part (ष's slash, the dot of अं) or a whole extra one
  // must cost real points, not just its small share of the letter's ink.
  final coverage = pointCoverage * (0.35 + 0.65 * _worstStroke(ref, userPts));
  final precision = pointPrecision * (0.35 + 0.65 * _worstStroke(user, refPts));
  final shape = (1 - ((refToUser + userToRef) / 2) / gradeShapeScale).clampD(0.0, 1.0);
  final dir = _direction(ref, user);
  final rb = _bbox(refStrokes.expand((e) => e)), ub = userBox;
  double aspect(_BBox b) => math.max(b.width, 1e-3) / math.max(b.height, 1e-3);
  final ra = aspect(rb).clampD(0.15, 6.0), ua = aspect(ub).clampD(0.15, 6.0);
  final proportion = (math.min(ra, ua) / math.max(ra, ua)).clampD(0.0, 1.0);
  final pen = _strokeCountPenalty(refStrokes.length, raw.length);

  final blend = 0.33 * coverage + 0.28 * precision + 0.24 * shape + 0.15 * proportion;
  // Stretch: a random scribble blends to ~0.45, a careful copy to ~0.9+.
  final stretched = ((blend - 0.45) / (0.92 - 0.45)).clampD(0.0, 1.0);
  // Direction scales the whole score: a perfect shape drawn backwards is ~half marks.
  final dirFactor = 0.5 + 0.5 * dir;
  final acc = ((stretched * 100 * dirFactor - pen * 60 - (1 - smooth) * 6) * sizeFactor).round().clamp(0, 100);
  return EvaluationResult(starsForAccuracy(acc), coverage, dir, pen, _feedbackFor(acc),
      shapeScore: shape, smoothnessScore: smooth, precisionScore: precision, proportionScore: proportion, accuracy: acc);
}

String _feedbackFor(int acc) => acc >= 90
    ? 'Excellent! Your letter looks great!'
    : acc >= 80
        ? 'Very good! Just a small detail to fix.'
        : acc >= 70
            ? 'Good effort! A bit more practice will make it perfect.'
            : acc >= 50
                ? 'Keep practicing! Focus on the shape and direction of the strokes.'
                : "This doesn't match the letter yet. Try again!";

/// Cheap live-accuracy check (kept for callers that only need coverage).
double quickTracingAccuracy(List<List<Offset>> userPaths, String letterId) =>
    evaluateStrokes(userPaths, letterId, 0).coverageScore;

/// aiGrader.grade() — algorithmic path.
class GradedResult {
  final int stars;
  final String feedback;
  final String? actionableTip, detectedLetter;
  final String source;
  final double? confidence;
  final double coverageScore;
  final int accuracy;
  final EvaluationResult? detail;
  GradedResult(this.stars, this.feedback, this.actionableTip, this.source, this.detectedLetter, this.confidence, this.coverageScore,
      {this.accuracy = 0, this.detail});
}

Future<GradedResult> gradeWriting(List<List<Offset>> paths, String letterId, double canvasSize) async {
  final r = evaluateStrokes(paths, letterId, canvasSize);
  return GradedResult(r.stars, r.feedback, getActionableTip(r, letterId), 'algorithmic', null, null, r.coverageScore,
      accuracy: r.accuracy, detail: r);
}
