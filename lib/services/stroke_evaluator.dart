import 'dart:math' as math;
import 'dart:ui' show Offset, Size;
import '../data/models.dart';
import '../util/num_ext.dart';
import 'ink_recognizer.dart';

/// Handwriting grader. Strokes are lists of canvas points; templates are lists
/// of 0..1 points. Both are normalised with a *uniform* scale (aspect ratio is
/// kept, so a squashed or stretched letter is penalised) and then compared on
/// seven criteria, each scored 0-1 (shown to the child as a percentage):
///
///  * shape        – mean two-way distance between the drawing and the letter
///  * parts drawn  – how much of the letter's path the child drew (recall)
///  * clean lines  – how much of the child's ink lies on the letter (no scribbles)
///  * proportion   – width/height ratio close to the letter's
///  * direction    – each stroke drawn the right way round
///  * strokes      – the right number of strokes
///  * size         – big enough to read
///
/// The final accuracy is exactly the weighted average of those seven numbers
/// ([criterionWeights]), plus any labelled [ScoreAdjustment]s (e.g. "this is
/// a different letter"). Nothing else feeds into it, so the result card can
/// show the whole sum. Each criterion is calibrated on its own so that a
/// careful copy scores ~100 %, a recognisable-but-rough letter lands in the
/// 70s and a wrong letter or a scribble scores well below 70 %.
class EvaluationResult {
  final int stars;
  final double coverageScore, directionScore, strokeCountPenalty;
  final String feedback;
  final double shapeScore, smoothnessScore, precisionScore, proportionScore;
  /// 0-1 scores for the stroke count and the size of the drawing.
  final double strokeScore, sizeScore;
  /// Overall 0-100 accuracy; [stars] is derived from it via [starsForAccuracy].
  final int accuracy;
  /// Share of each model stroke the drawing covers (index = stroke number - 1).
  final List<double> strokeHits;
  /// Strokes drawn vs strokes in the model.
  final int userStrokes, refStrokes;
  /// Width/height of the drawing and of the model, and how big the drawing is
  /// (1 = big enough, lower = too small to read well).
  final double userAspect, refAspect, sizeFactor;
  /// Changes made on top of the weighted average, each with its reason.
  final List<ScoreAdjustment> adjustments;
  const EvaluationResult(this.stars, this.coverageScore, this.directionScore, this.strokeCountPenalty, this.feedback,
      {this.shapeScore = 0, this.smoothnessScore = 0, this.precisionScore = 0, this.proportionScore = 0, this.accuracy = 0,
      this.strokeScore = 1, this.sizeScore = 1,
      this.strokeHits = const [], this.userStrokes = 0, this.refStrokes = 0, this.userAspect = 1, this.refAspect = 1,
      this.sizeFactor = 1, this.adjustments = const []});

  /// Every criterion with its score and weight, in display order.
  List<Criterion> get criteria => [
        Criterion('Shape', shapeScore, criterionWeights[0]),
        Criterion('All parts drawn', coverageScore, criterionWeights[1]),
        Criterion('No extra lines', precisionScore, criterionWeights[2]),
        Criterion('Proportion', proportionScore, criterionWeights[3]),
        Criterion('Direction', directionScore, criterionWeights[4]),
        Criterion('Stroke count', strokeScore, criterionWeights[5]),
        Criterion('Size', sizeScore, criterionWeights[6]),
      ];

  /// The weighted average of [criteria] on 0-100, before [adjustments].
  int get weightedScore => weightedAverage(criteria);

  /// A copy with [accuracy] replaced and [adj] recorded as the reason.
  EvaluationResult adjusted(int newAccuracy, ScoreAdjustment adj) => EvaluationResult(
      starsForAccuracy(newAccuracy), coverageScore, directionScore, strokeCountPenalty, feedback,
      shapeScore: shapeScore, smoothnessScore: smoothnessScore, precisionScore: precisionScore,
      proportionScore: proportionScore, accuracy: newAccuracy, strokeScore: strokeScore, sizeScore: sizeScore,
      strokeHits: strokeHits, userStrokes: userStrokes, refStrokes: refStrokes, userAspect: userAspect,
      refAspect: refAspect, sizeFactor: sizeFactor, adjustments: [...adjustments, adj]);
}

/// One graded criterion: its 0-1 [score] and its share of the final [weight].
class Criterion {
  final String label;
  final double score, weight;
  const Criterion(this.label, this.score, this.weight);
  int get percent => (score.clampD(0.0, 1.0) * 100).round();
}

/// A change to the score on top of the weighted average, with its reason
/// (shown on the result card so the final number always adds up).
class ScoreAdjustment {
  final String reason;
  /// Points added (positive) or removed (negative).
  final int points;
  const ScoreAdjustment(this.reason, this.points);
}

/// Weights of shape, parts drawn, clean lines, proportion, direction, stroke
/// count and size. They sum to 1.
const criterionWeights = [0.25, 0.30, 0.15, 0.10, 0.10, 0.05, 0.05];

/// Final 0-100 score: Σ weight × score, rounded.
int weightedAverage(List<Criterion> cs) {
  double sum = 0, w = 0;
  for (final c in cs) {
    sum += c.score.clampD(0.0, 1.0) * c.weight;
    w += c.weight;
  }
  return w == 0 ? 0 : (sum / w * 100).round().clamp(0, 100);
}

/// Linear map of [raw] so [lo] → 0 and [hi] → 1 (clamped).
double _cal(double raw, double lo, double hi) => ((raw - lo) / (hi - lo)).clampD(0.0, 1.0);

/// 3 stars at >= 90 %, 2 at 70-89 %, 1 at 50-69 %, 0 below 50 %.
int starsForAccuracy(int pct) => pct >= 90 ? 3 : pct >= 70 ? 2 : pct >= 50 ? 1 : 0;

class StrictEvaluationResult extends EvaluationResult {
  final bool isTargetBestMatch;
  final String? bestMatchCharacter;
  StrictEvaluationResult(EvaluationResult r, this.isTargetBestMatch, this.bestMatchCharacter)
      : super(r.stars, r.coverageScore, r.directionScore, r.strokeCountPenalty, r.feedback,
            shapeScore: r.shapeScore, smoothnessScore: r.smoothnessScore, precisionScore: r.precisionScore,
            proportionScore: r.proportionScore, accuracy: r.accuracy, strokeScore: r.strokeScore, sizeScore: r.sizeScore,
            strokeHits: r.strokeHits, userStrokes: r.userStrokes, refStrokes: r.refStrokes, userAspect: r.userAspect,
            refAspect: r.refAspect, sizeFactor: r.sizeFactor, adjustments: r.adjustments);
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

/// Share of each stroke of [strokes] lying on [other].
List<double> _strokeHits(List<List<Pt>> strokes, List<Pt> other) => [
      for (final st in strokes)
        () {
          final len = _length(st);
          final pts = _resample(st, math.max(2, (len / _step).ceil() + 1));
          // Dots and ticks are tiny; give them a little more room.
          final tol = (len < 0.05 ? 1.8 : 1.4) * gradeTolerance;
          return pts.where((p) => _nearest(p, other) <= tol).length / pts.length;
        }(),
    ];

/// Lowest share of any single stroke of [strokes] lying on [other].
double _worstStroke(List<List<Pt>> strokes, List<Pt> other) =>
    _strokeHits(strokes, other).fold(1.0, (a, b) => math.min(a, b));

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

/// The single most useful tip for [r] (the criterion that cost the most
/// points), or null for a 3★ attempt.
String? getActionableTip(EvaluationResult r, String letterId) {
  if (r.stars >= 3) return null;
  final tips = improvementTips(r, AppData.strokeTemplates[letterId]?.character ?? '', max: 1);
  return tips.isEmpty ? 'Tip: Almost there! One more careful try.' : 'Tip: ${tips.first.title} — ${tips.first.detail}';
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
/// ु/ृ below, ं dot above, ः dots on the right, ़ dot below). Null when there is no base template.
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
  final rightStem = marks.contains('ा') || marks.contains('ी') || marks.contains('ो') || marks.contains('ौ') ||
      marks.contains('ः');
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
      case 'ृ': out.add(const [Pt(0.52, 0.85), Pt(0.44, 0.93), Pt(0.56, 0.98), Pt(0.62, 0.93)]);
      case 'ः': out.addAll(const [[Pt(0.86, 0.36), Pt(0.87, 0.37)], [Pt(0.86, 0.66), Pt(0.87, 0.67)]]);
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
  final shown = wrong && result.accuracy > kOtherLetterCap
      ? result.adjusted(kOtherLetterCap,
          ScoreAdjustment('Reads as ${best.character}, not $character', kOtherLetterCap - result.accuracy))
      : result;
  return StrictEvaluationResult(shown, !wrong, wrong ? best.character : null);
}

/// [evaluateLetterStrict] with a second opinion from the on-device Hindi
/// handwriting model (Android/iOS). When the model reads the block as exactly
/// [character], it is clearly that letter: a "reads as another letter" verdict
/// from shape matching is dropped and the score is at least
/// [kRecognisedFloor]. The model never lowers a score; without it the result
/// is the shape check alone.
Future<StrictEvaluationResult> evaluateLetterWithModel(
    List<List<Offset>> paths, String character, double canvasSize) async {
  final strict = evaluateLetterStrict(paths, character, canvasSize);
  if (paths.isEmpty || character.isEmpty) return strict;
  final candidates = await InkModel.recognize(paths, Size(canvasSize, canvasSize));
  if (candidates == null || candidates.isEmpty || candidates.first != character) return strict;
  // Recognised: start again from the plain shape score, without the cap.
  final base = evaluateStrokesByCharacter(paths, character, canvasSize);
  final shown = base.accuracy < kRecognisedFloor
      ? base.adjusted(kRecognisedFloor, ScoreAdjustment('Recognised as $character', kRecognisedFloor - base.accuracy))
      : base;
  return StrictEvaluationResult(shown, true, null);
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

/// A letter written on a slant, turned upright using its own header line
/// (शिरोरेखा): the longest straight, nearly level stroke in the top part of
/// the drawing. Children often tilt the whole letter; that is not a mistake in
/// the letter's shape, so it is undone before comparing. Drawings without a
/// clear header line (or tilted more than ~20°) are left as they are.
List<List<Pt>> levelByHeader(List<List<Pt>> strokes) {
  if (strokes.isEmpty) return strokes;
  final box = _bbox(strokes.expand((e) => e));
  final size = math.max(box.width, box.height);
  if (size <= 0) return strokes;
  double? angle;
  double longest = 0;
  for (final s in strokes) {
    if (s.length < 2) continue;
    final len = _length(s);
    final dx = s.last.x - s.first.x, dy = s.last.y - s.first.y;
    final chord = math.sqrt(dx * dx + dy * dy);
    if (len <= 0 || chord / len < 0.9 || dx.abs() < 1e-9 || dy.abs() > dx.abs() * 0.36) continue;
    if (chord < size * 0.4) continue;
    final cy = (s.first.y + s.last.y) / 2;
    if (cy > box.minY + box.height * 0.35) continue;
    if (chord > longest) {
      longest = chord;
      angle = math.atan(dy / dx);
    }
  }
  if (angle == null) {
    // No long header (अ, थ, ध have only a short one): the standing line's
    // lean from vertical shows the tilt just as well.
    for (final s in strokes) {
      if (s.length < 2) continue;
      final len = _length(s);
      final dx = s.last.x - s.first.x, dy = s.last.y - s.first.y;
      final chord = math.sqrt(dx * dx + dy * dy);
      if (len <= 0 || chord / len < 0.93 || dy.abs() < 1e-9 || dx.abs() > dy.abs() * 0.36) continue;
      if (chord < box.height * 0.5) continue;
      if (chord > longest) {
        longest = chord;
        angle = -math.atan(dx / dy);
      }
    }
  }
  if (angle == null || angle.abs() < 0.052) return strokes; // under ~3°: just a wobble, leave it
  final c = math.cos(-angle), sn = math.sin(-angle);
  final cx = (box.minX + box.maxX) / 2, cy = (box.minY + box.maxY) / 2;
  return [
    for (final s in strokes)
      [for (final p in s) Pt(cx + (p.x - cx) * c - (p.y - cy) * sn, cy + (p.x - cx) * sn + (p.y - cy) * c)],
  ];
}

/// Grades [userPaths] (canvas pixels) against arbitrary 0..1 reference strokes.
/// With no reference strokes it can only judge neatness, so it is capped at 2★.
EvaluationResult evaluateAgainst(List<List<Offset>> userPaths, List<List<Pt>> refStrokes, double canvasSize) {
  var raw = <List<Pt>>[
    for (final s in userPaths) if (s.isNotEmpty) [for (final o in s) Pt(o.dx, o.dy)],
  ];
  if (raw.isEmpty) return const EvaluationResult(0, 0, 0, 1, 'No strokes detected. Please draw the letter.');
  final userBox = _bbox(raw.expand((e) => e));
  // A drawing smaller than ~12 % of the canvas is too tiny to read.
  final sizeFactor = canvasSize <= 0 ? 1.0
      : (math.max(userBox.width, userBox.height) / canvasSize / 0.25).clampD(0.4, 1.0);
  final smooth = _smoothness(_normalize(raw));

  final sizeScore = canvasSize <= 0 ? 1.0 : _cal(sizeFactor, 0.4, 0.85);

  if (refStrokes.isEmpty) {
    // No model to compare with: only neatness and size can be judged, so the
    // other criteria sit at a neutral 50 % and the result stays below 3★.
    final r = EvaluationResult(0, 0.5, 0.5, 0, '',
        smoothnessScore: smooth, precisionScore: smooth, proportionScore: 0.5, shapeScore: 0.5, sizeScore: sizeScore);
    final acc = math.min(r.weightedScore, 75);
    return EvaluationResult(starsForAccuracy(acc), 0.5, 0.5, 0, _feedbackFor(acc),
        smoothnessScore: smooth, precisionScore: smooth, proportionScore: 0.5, shapeScore: 0.5, sizeScore: sizeScore,
        accuracy: acc);
  }

  var s = rawSignals(raw, refStrokes);
  // A tilted letter is turned upright by its header line; that version is
  // used only when it matches better, so a shaky header can never make an
  // upright letter worse.
  final leveled = levelByHeader(raw);
  if (!identical(leveled, raw)) {
    final t = rawSignals(leveled, refStrokes);
    if (t.shape + t.coverage > s.shape + s.coverage) { s = t; raw = leveled; }
  }
  final shape = _cal(s.shape, kShapeCal.$1, kShapeCal.$2);
  final coverage = _cal(s.coverage, kCoverageCal.$1, kCoverageCal.$2);
  final precision = _cal(s.precision, kPrecisionCal.$1, kPrecisionCal.$2);
  final proportion = _cal(s.proportion, kProportionCal.$1, kProportionCal.$2);
  final dir = s.direction;
  final pen = _strokeCountPenalty(refStrokes.length, raw.length);
  final strokeScore = _strokeCountScore(refStrokes.length, raw.length);

  final r = EvaluationResult(0, coverage, dir, pen, '',
      shapeScore: shape, smoothnessScore: smooth, precisionScore: precision, proportionScore: proportion,
      strokeScore: strokeScore, sizeScore: sizeScore);
  final acc = r.weightedScore;
  return EvaluationResult(starsForAccuracy(acc), coverage, dir, pen, _feedbackFor(acc),
      shapeScore: shape, smoothnessScore: smooth, precisionScore: precision, proportionScore: proportion, accuracy: acc,
      strokeScore: strokeScore, sizeScore: sizeScore, strokeHits: s.hits, userStrokes: raw.length,
      refStrokes: refStrokes.length, userAspect: s.userAspect, refAspect: s.refAspect, sizeFactor: sizeFactor);
}

/// Calibration of each criterion: (raw value scored 0 %, raw value scored 100 %).
/// Tuned on synthetic handwriting (see test/stroke_evaluator_test.dart): a
/// careful copy reaches the top of every range, a different letter sits near
/// the bottom of shape / parts / clean lines.
const kShapeCal = (0.60, 0.88), kCoverageCal = (0.50, 0.95), kPrecisionCal = (0.50, 0.95), kProportionCal = (0.40, 0.85);

/// The uncalibrated comparison of [raw] (canvas points) with [refStrokes]
/// (0..1 model strokes). Exposed for tuning the calibration constants.
({double shape, double coverage, double precision, double proportion, double direction, List<double> hits,
    double userAspect, double refAspect}) rawSignals(List<List<Pt>> raw, List<List<Pt>> refStrokes) {
  final rb = _bbox(refStrokes.expand((e) => e)), ub = _bbox(raw.expand((e) => e));
  double aspect(_BBox b) => math.max(b.width, 1e-3) / math.max(b.height, 1e-3);
  final ra = aspect(rb).clampD(0.15, 6.0), ua = aspect(ub).clampD(0.15, 6.0);
  final proportion = (math.min(ra, ua) / math.max(ra, ua)).clampD(0.0, 1.0);
  // Width/height is graded by the proportion criterion alone. For a moderate
  // difference the drawing is partly stretched towards the model's aspect
  // before comparing shapes, so a slightly wide letter isn't marked down a
  // second time as "wrong shape" and "missing parts".
  final align = proportion >= kAspectAlignMin ? math.pow(ra / ua, kAspectAlign).toDouble() : 1.0;
  final user = _normalize([for (final s in raw) [for (final p in s) Pt(p.x * align, p.y)]]);
  final ref = _normalize(refStrokes);
  final refPts = _densify(ref, _step), userPts = _densify(user, _step);
  final (pointCoverage, refToUser) = _match(refPts, _weights(ref, _step), userPts, gradeTolerance);
  final (pointPrecision, userToRef) = _match(userPts, _weights(user, _step), refPts, gradeTolerance);
  // A whole missing part (ष's slash, the dot of अं) or a whole extra one
  // must cost real points, not just its small share of the letter's ink.
  final hits = _strokeHits(ref, userPts);
  final coverage = pointCoverage * (0.35 + 0.65 * hits.fold(1.0, (a, b) => math.min(a, b)));
  final precision = pointPrecision * (0.35 + 0.65 * _worstStroke(user, refPts));
  final shape = (1 - ((refToUser + userToRef) / 2) / gradeShapeScale).clampD(0.0, 1.0);
  return (
    shape: shape, coverage: coverage, precision: precision, proportion: proportion,
    direction: _direction(ref, user), hits: hits, userAspect: ua, refAspect: ra,
  );
}

/// Aspect alignment: applied when the width/height ratios are within this
/// factor of each other, by this power (0 = none, 1 = full).
const kAspectAlignMin = 0.75, kAspectAlign = 0.5;

/// 1 for the model's stroke count; each missing stroke costs 30 %, each extra
/// one 15 % (an extra lift is a smaller mistake than a missing part).
double _strokeCountScore(int rc, int uc) {
  if (rc == 0 || uc == rc) return 1;
  return (uc < rc ? 1 - (rc - uc) * 0.3 : 1 - (uc - rc) * 0.15).clampD(0.0, 1.0);
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

/// What the handwriting model said about an attempt.
enum ModelVerdict { unavailable, confirmed, plausible, otherLetter }

/// Grades one written letter. The shape score comes from [evaluateStrokes];
/// then a second opinion decides whether it is the right letter at all — the
/// on-device ML Kit model when it is ready, otherwise matching against every
/// letter template. Writing a different letter is capped at 1 star however neat
/// it is. Feedback names the actual problem (which stroke, how many strokes,
/// size, direction) and compares with [previousAccuracy].
Future<GradedResult> gradeWriting(List<List<Offset>> paths, String letterId, double canvasSize,
    {int? previousAccuracy}) async {
  final r = evaluateStrokes(paths, letterId, canvasSize);
  final character = AppData.strokeTemplates[letterId]?.character ?? '';
  var acc = r.accuracy;
  String? otherLetter;
  var verdict = ModelVerdict.unavailable;

  final candidates = character.isEmpty ? null : await InkModel.recognize(paths, Size(canvasSize, canvasSize));
  if (candidates != null && candidates.isNotEmpty) {
    final rank = candidates.take(5).toList().indexOf(character);
    // The model only confirms or rejects the letter; it never changes the
    // number, so the result always matches the live accuracy meter.
    if (rank == 0) {
      verdict = ModelVerdict.confirmed;
    } else if (rank > 0) {
      verdict = ModelVerdict.plausible;
    } else if (candidates.first.runes.length <= 2) {
      verdict = ModelVerdict.otherLetter;
      otherLetter = candidates.first;
    }
  } else if (character.isNotEmpty) {
    final strict = evaluateLetterStrict(paths, character, canvasSize);
    if (!strict.isTargetBestMatch) otherLetter = strict.bestMatchCharacter;
  }
  var graded = r;
  if (otherLetter != null && acc > kOtherLetterCap) {
    graded = graded.adjusted(kOtherLetterCap, ScoreAdjustment('Reads as $otherLetter, not $character', kOtherLetterCap - acc));
  } else if (verdict == ModelVerdict.confirmed && acc < kRecognisedFloor) {
    // The handwriting model read it as the right letter: it is legible, so
    // an unusual (but valid) style is not marked as a fail.
    graded = graded.adjusted(kRecognisedFloor, ScoreAdjustment('Recognised as $character', kRecognisedFloor - acc));
  }
  acc = graded.accuracy;

  final (feedback, tip) = describeAttempt(graded, character,
      previousAccuracy: previousAccuracy, otherLetter: otherLetter, verdict: verdict);
  return GradedResult(graded.stars, feedback, tip, verdict == ModelVerdict.unavailable ? 'algorithmic' : 'ml-kit',
      otherLetter, null, r.coverageScore, accuracy: acc, detail: graded);
}

/// Highest score for writing a different letter (1★), and the lowest score
/// for a letter the handwriting model reads as the right one (2★).
const kOtherLetterCap = 45, kRecognisedFloor = 70;

/// One concrete way to improve, tied to the criterion it fixes.
class ImprovementTip {
  final String criterion, title, detail;
  /// Points this criterion cost the attempt (weight × what was missed).
  final int pointsLost;
  /// Model stroke (0-based) the tip is about, for highlighting; -1 for none.
  final int stroke;
  const ImprovementTip(this.criterion, this.title, this.detail, this.pointsLost, {this.stroke = -1});
}

/// Below this accuracy the result shows step-by-step help.
const kTipsThreshold = 70;

/// Up to [max] tips for [r], biggest point loss first, each explaining in
/// plain words what went wrong and how to fix it. Only criteria that cost at
/// least 3 points get a tip, so the advice always matches a real mistake.
List<ImprovementTip> improvementTips(EvaluationResult r, String character, {String? otherLetter, int max = 3}) {
  final name = character.isEmpty ? 'the letter' : character;
  final tips = <ImprovementTip>[];
  int lost(double score, double weight) => ((1 - score.clampD(0.0, 1.0)) * weight * 100).round();
  const w = criterionWeights;
  if (otherLetter != null) {
    tips.add(ImprovementTip('Letter', 'This reads as $otherLetter',
        'Compare $name and $otherLetter in the model — look for the curve, loop or line that makes them different.',
        r.adjustments.fold(0, (a, x) => a - math.min(0, x.points))));
  }
  int weakest = -1;
  for (int i = 0; i < r.strokeHits.length; i++) {
    if (weakest < 0 || r.strokeHits[i] < r.strokeHits[weakest]) weakest = i;
  }
  final parts = lost(r.coverageScore, w[1]);
  if (parts >= 3) {
    tips.add(weakest >= 0 && r.strokeHits.length > 1 && r.strokeHits[weakest] < 0.65
        ? ImprovementTip('All parts drawn', 'Stroke ${weakest + 1} is missing or off',
            'Stroke ${weakest + 1} (${_strokeColourNames[weakest % _strokeColourNames.length]} in the guide) only lines up '
                '${(r.strokeHits[weakest] * 100).round()}%. Watch it in the hint, then draw it fully.', parts, stroke: weakest)
        : ImprovementTip('All parts drawn', 'Some parts are missing',
            'Draw every part of $name — the header line on top, every curve and any dot.', parts));
  }
  final shape = lost(r.shapeScore, w[0]);
  if (shape >= 3) {
    tips.add(ImprovementTip('Shape', 'Make the curves closer to the model',
        'Go slowly on the round parts and keep loops closed. It is fine if it does not look exactly like print — '
            'it should just be clearly $name.', shape));
  }
  final clean = lost(r.precisionScore, w[2]);
  if (clean >= 3) {
    tips.add(ImprovementTip('No extra lines', 'Remove extra lines',
        'Some ink is outside the letter. Use Undo for a stray line instead of drawing over it.', clean));
  }
  final prop = lost(r.proportionScore, w[3]);
  if (prop >= 3) {
    tips.add(ImprovementTip('Proportion', r.userAspect > r.refAspect ? 'A bit too wide' : 'A bit too tall and thin',
        r.userAspect > r.refAspect
            ? 'Make $name a little narrower — let it hang from the header line down to the base line.'
            : 'Give $name a little more width so its parts do not squeeze together.', prop));
  }
  final dir = lost(r.directionScore, w[4]);
  if (dir >= 3) {
    tips.add(ImprovementTip('Direction', 'Start each stroke at its green dot',
        'A stroke went the other way round. Any direction is readable, but the usual one makes writing faster.', dir));
  }
  final strokes = lost(r.strokeScore, w[5]);
  if (strokes >= 3 && r.refStrokes > 0) {
    tips.add(ImprovementTip('Stroke count', 'Use ${r.refStrokes} ${r.refStrokes == 1 ? 'stroke' : 'strokes'}',
        r.userStrokes < r.refStrokes
            ? 'You drew ${r.userStrokes}. Lift your finger between the parts of $name.'
            : 'You drew ${r.userStrokes}. Try fewer, longer strokes without stopping mid-line.', strokes));
  }
  final size = lost(r.sizeScore, w[6]);
  if (size >= 3) {
    tips.add(ImprovementTip('Size', 'Write it bigger', 'Fill most of the box so every part is clear.', size));
  }
  tips.sort((a, b) => b.pointsLost.compareTo(a.pointsLost));
  return tips.take(max).toList();
}

final _rng = math.Random();
String _pick(List<String> options) => options[_rng.nextInt(options.length)];

const _strokeColourNames = ['red', 'blue', 'green', 'purple', 'orange'];

/// A short headline, the one thing that matters most about this attempt, and
/// (when useful) how it compares with the last try. The second most important
/// issue comes back separately as a tip.
(String, String?) describeAttempt(EvaluationResult r, String character,
    {int? previousAccuracy, String? otherLetter, ModelVerdict verdict = ModelVerdict.unavailable}) {
  final acc = r.accuracy;
  final headline = acc >= 90
      ? _pick(['Excellent!', 'Beautiful writing!', 'शाबाश! Spot on.', 'Perfect strokes!', 'That looks just like the model!'])
      : acc >= 80
          ? _pick(['Very good!', 'Great control!', 'Nearly perfect!', 'Really neat!'])
          : acc >= 70
              ? _pick(['Good job!', 'Nice work!', "You're getting it!", 'Well done!'])
              : acc >= 50
                  ? _pick(['Getting closer.', 'Not bad — keep going.', 'Halfway there.', 'Good try.'])
                  : _pick(["Let's try that again.", 'Not quite yet.', 'Have another go.', 'Almost — one more try.']);

  final issues = <String>[];
  final hits = r.strokeHits;
  int weakest = -1;
  for (int i = 0; i < hits.length; i++) {
    if (weakest < 0 || hits[i] < hits[weakest]) weakest = i;
  }
  final name = character.isEmpty ? 'this letter' : character;

  if (otherLetter != null) {
    issues.add(_pick([
      'This looks more like $otherLetter than $name. Check the model and try again.',
      "That reads as $otherLetter, not $name — look closely at how they're different.",
    ]));
  }
  if (r.refStrokes > 0 && r.userStrokes < r.refStrokes) {
    issues.add('You drew ${r.userStrokes} ${r.userStrokes == 1 ? 'stroke' : 'strokes'} — $name needs ${r.refStrokes}. '
        'Lift your finger between strokes.');
  } else if (r.refStrokes > 0 && r.userStrokes > r.refStrokes + 1) {
    issues.add('You used ${r.userStrokes} strokes; $name is written in ${r.refStrokes}. Try fewer, longer strokes.');
  }
  if (r.sizeFactor < 0.85) {
    issues.add(_pick(["It's quite small — fill more of the box.", 'Write it bigger so every part is clear.']));
  }
  if (weakest >= 0 && hits.length > 1 && hits[weakest] < 0.65) {
    final colour = _strokeColourNames[weakest % _strokeColourNames.length];
    issues.add(_pick([
      'Stroke ${weakest + 1} ($colour) is the furthest off — only ${(hits[weakest] * 100).round()}% of it lines up.',
      'Look at stroke ${weakest + 1}, the $colour one: it misses most of its path.',
    ]));
  } else if (r.coverageScore < 0.6) {
    issues.add('Some parts are missing — draw every part, including the line on top.');
  }
  if (r.directionScore < 0.6) {
    issues.add(_pick([
      'A stroke went the wrong way — start at the green dot and follow the arrows.',
      'Check the direction: each stroke starts at its green dot.',
    ]));
  }
  if (r.proportionScore < 0.65) {
    issues.add(r.userAspect > r.refAspect
        ? 'It came out too wide — make it a little narrower and taller.'
        : 'It came out too tall and thin — give it a little more width.');
  }
  if (r.precisionScore < 0.65) issues.add('There are extra lines outside the letter — keep to the shape.');
  if (r.shapeScore < 0.7) {
    issues.add(_pick(['The curves are a little off — slow down on the round parts.', 'Trace the curves more slowly and smoothly.']));
  }

  final parts = <String>[headline];
  if (acc >= 90 || issues.isEmpty) {
    parts.add(_pick([
      'Shape ${(r.shapeScore * 100).round()}%, direction ${(r.directionScore * 100).round()}%.',
      'Every stroke lines up with the model.',
      'Clean strokes in the right order.',
    ]));
  } else {
    parts.add(issues.first);
  }
  if (verdict == ModelVerdict.confirmed) parts.add('✓ Recognised as $name.');
  if (previousAccuracy != null) {
    final diff = acc - previousAccuracy;
    if (diff >= 5) {
      parts.add(_pick(['That is $diff% better than your last try!', 'Up $diff% from last time — great progress!']));
    } else if (diff <= -5) {
      parts.add('A little below your last try (${diff.abs()}% lower) — take it slowly.');
    }
  }
  final tip = acc < 90 && issues.length > 1 ? 'Tip: ${issues[1]}' : null;
  return (parts.join(' '), tip);
}
