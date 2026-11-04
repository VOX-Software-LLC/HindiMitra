import 'dart:math' as math;
import 'dart:ui' show Offset, Size;
import '../data/models.dart' show Pt;
import 'ink_recognizer.dart';
import 'stroke_evaluator.dart';

/// Result of grading a written word: one score per block, whether a header
/// line (शिरोरेखा) was drawn across the word, and the overall accuracy.
class WordGrade {
  final List<int> unitScores;
  final bool headerDrawn;
  final int accuracy;
  /// True when the on-device handwriting model read the writing as exactly
  /// this word (a second opinion; null when the model was not available).
  final bool? readByModel;
  /// Points added because the model read the word correctly (0 if none).
  final int modelBonus;
  const WordGrade(this.unitScores, this.headerDrawn, this.accuracy, {this.readByModel, this.modelBonus = 0});
}

/// [gradeWordStrokes] plus a second opinion from the on-device Hindi
/// handwriting model (Android/iOS). When the model reads the writing as
/// exactly this word, it is clearly legible, so it scores at least
/// [kRecognisedFloor]. The model never lowers a score, and without it (web,
/// desktop, model not downloaded yet) the result is the shape score alone.
Future<WordGrade> gradeWordWithModel(List<List<Offset>> strokes, List<String> units, Size pad) async {
  final g = gradeWordStrokes(strokes, units, pad.height);
  final candidates = await InkModel.recognize(strokes, pad);
  if (candidates == null || candidates.isEmpty) return g;
  final word = units.join();
  final read = candidates.take(3).map((c) => c.replaceAll(' ', '')).contains(word);
  if (!read) return WordGrade(g.unitScores, g.headerDrawn, g.accuracy, readByModel: false);
  final bonus = math.max(0, kRecognisedFloor - g.accuracy);
  return WordGrade(g.unitScores, g.headerDrawn, g.accuracy + bonus, readByModel: true, modelBonus: bonus);
}

/// Points taken off a multi-letter word written without a header line.
const kNoHeaderPenalty = 8;

/// Most strokes one block can take (क्ष, a letter plus two matras …).
const _maxStrokesPerUnit = 8;

/// Grades [strokes] as the word made of [units], wherever and however large it
/// was written on the pad: the writing is split into blocks by its own shape
/// (trying every left-to-right split and keeping the one that matches the
/// word best), not by the guide boxes on screen. [padHeight] only sets how
/// small is too small to read.
WordGrade gradeWordStrokes(List<List<Offset>> strokes, List<String> units, double padHeight) {
  final n = units.length;
  var all = [for (final s in strokes) if (s.isNotEmpty) s];
  if (all.isEmpty || n == 0) return WordGrade(List.filled(n, 0), false, 0);
  if (n == 1) {
    final acc = evaluateStrokesByCharacter(all, units[0], padHeight).accuracy;
    return WordGrade([acc], true, acc);
  }

  // 1. Level the word: children often write on a slant. The writing's main
  //    direction (a word is much wider than tall) is turned back to horizontal.
  all = _level(all);

  // 2. Split off the header line (शिरोरेखा): straight, nearly level strokes in
  //    the top part of the writing — across the whole word or drawn letter by
  //    letter. Curved strokes up there (the tops of ि and ी) stay with the letters.
  final whole = _box(all.expand((s) => s));
  final header = <List<Offset>>[], body = <List<Offset>>[];
  for (final s in all) {
    (_isHeader(s, whole, n) ? header : body).add(s);
  }
  if (body.isEmpty) return WordGrade(List.filled(n, 0), header.isNotEmpty, 0);
  body.sort((a, b) => _box(a).centerX.compareTo(_box(b).centerX));

  // 3. Find the letters by their own shape: every left-to-right split of the
  //    strokes is tried and the one that matches the word best is kept. Each
  //    letter is compared without its header, which is checked on its own.
  final refs = [for (final u in units) _bodyStrokes(u)];
  final groups = body.length >= n
      ? _bestSplit(body, refs, units, padHeight)
      : _splitByWidth(body, _box(body.expand((x) => x)), n);
  final scores = [
    for (int k = 0; k < n; k++)
      groups[k].isEmpty ? 0 : _gradeBody(groups[k], refs[k], units[k], padHeight),
  ];
  var acc = (scores.fold<int>(0, (a, b) => a + b) / n).round();
  if (header.isEmpty) acc = math.max(0, acc - kNoHeaderPenalty); // the header line is part of writing a word
  return WordGrade(scores, header.isNotEmpty, acc);
}

/// [strokes] turned about their centre so the word's main direction is
/// horizontal (only for moderate slants; a word stood on end is left alone).
List<List<Offset>> _level(List<List<Offset>> strokes) {
  final pts = [for (final s in strokes) ..._densify(s, 4)];
  if (pts.length < 3) return strokes;
  double mx = 0, my = 0;
  for (final p in pts) { mx += p.dx; my += p.dy; }
  mx /= pts.length; my /= pts.length;
  final whole = _box(pts);
  // Best guide: a long, straight header line across most of the word — its
  // own angle is the slant, even when the letters bob up and down under it.
  double? angle;
  double longest = 0;
  for (final s in strokes) {
    if (s.length < 2) continue;
    final d = s.last - s.first;
    double len = 0;
    for (int i = 1; i < s.length; i++) { len += (s[i] - s[i - 1]).distance; }
    if (len <= 0 || d.distance / len < 0.9 || d.dx.abs() < 1e-6 || d.dy.abs() > d.dx.abs() * 0.5) continue;
    if (d.distance >= whole.width * 0.6 && d.distance > longest) {
      longest = d.distance;
      final a = math.atan2(d.dy, d.dx);
      angle = a > math.pi / 2 ? a - math.pi : a < -math.pi / 2 ? a + math.pi : a;
    }
  }
  if (angle == null) {
    // Otherwise the writing's main direction, when it is clearly wider than tall.
    double sxx = 0, syy = 0, sxy = 0;
    for (final p in pts) {
      final dx = p.dx - mx, dy = p.dy - my;
      sxx += dx * dx; syy += dy * dy; sxy += dx * dy;
    }
    final tr = sxx + syy, det = sxx * syy - sxy * sxy;
    final l1 = tr / 2 + math.sqrt(math.max(0.0, tr * tr / 4 - det)), l2 = tr - l1;
    if (l1 < 2.2 * math.max(l2, 1e-9)) return strokes;
    angle = 0.5 * math.atan2(2 * sxy, sxx - syy);
  }
  if (angle.abs() < 0.02 || angle.abs() > 0.45) return strokes;
  final c = math.cos(-angle), sn = math.sin(-angle);
  return [
    for (final s in strokes)
      [for (final p in s) Offset(mx + (p.dx - mx) * c - (p.dy - my) * sn, my + (p.dx - mx) * sn + (p.dy - my) * c)],
  ];
}

/// A header-line stroke: nearly straight and level, reasonably long, and in
/// the top part of the writing.
bool _isHeader(List<Offset> s, _Box whole, int units) {
  if (s.length < 2) return false;
  final b = _box(s);
  double len = 0;
  for (int i = 1; i < s.length; i++) { len += (s[i] - s[i - 1]).distance; }
  final chord = (s.last - s.first).distance;
  if (len <= 0 || chord / len < 0.9) return false; // curved: a matra or part of a letter
  final dir = s.last - s.first;
  if (dir.dy.abs() > dir.dx.abs() * 0.3) return false; // steeper than ~17°
  // At least about half a letter wide (च's own short top bar is narrower)
  // and at the very top of the writing (च's bar sits lower, below the header).
  final letterH = whole.height; // a word's letters are about as tall as the writing
  if (b.width < math.min(whole.width / units * 0.55, letterH * 0.55)) return false;
  return (b.minY + b.maxY) / 2 <= whole.minY + whole.height * 0.22;
}

/// The model strokes of [unit] without its header line(s).
List<List<Pt>> _bodyStrokes(String unit) {
  final ref = strokesForText(unit) ?? const <List<Pt>>[];
  if (ref.isEmpty) return ref;
  // The header is the highest flat line; a flat bar lower down (च's top bar,
  // ज्ञ's short bar) is part of the letter, and curved matra tops are not flat.
  bool flat(List<Pt> s) {
    if (s.length < 2) return false;
    final xs = s.map((p) => p.x), sy = s.map((p) => p.y);
    return xs.reduce(math.max) - xs.reduce(math.min) > 0.3 && sy.reduce(math.max) - sy.reduce(math.min) < 0.04;
  }
  double y0(List<Pt> s) => s.map((p) => p.y).reduce(math.min);
  final flats = ref.where(flat).toList();
  if (flats.isEmpty) return ref;
  final headerY = flats.map(y0).reduce(math.min);
  bool isHeader(List<Pt> s) => flat(s) && y0(s) <= headerY + 0.03;
  final body = ref.where((s) => !isHeader(s)).toList();
  return body.isEmpty ? ref : body;
}

/// Score of one letter's strokes: compared with the model both without its
/// header and with it (a child may draw a short header piece over just this
/// letter, which then stays with the letter), keeping the better match.
int _gradeBody(List<List<Offset>> paths, List<List<Pt>> ref, String unit, double padHeight) {
  final full = strokesForText(unit) ?? const <List<Pt>>[];
  final a = ref.isEmpty ? 0 : evaluateAgainst(paths, ref, padHeight).accuracy;
  final b = full.isEmpty || identical(full, ref) ? 0 : evaluateAgainst(paths, full, padHeight).accuracy;
  return math.max(a, b);
}

/// Splits [body] (sorted left to right) into one contiguous group per unit,
/// choosing the split with the highest total score.
List<List<List<Offset>>> _bestSplit(
    List<List<Offset>> body, List<List<List<Pt>>> refs, List<String> units, double padHeight) {
  final s = body.length, n = refs.length;
  final cache = <int, double>{};
  double score(int i, int j, int k) => cache.putIfAbsent((i * 64 + j) * 16 + k,
      () => _gradeBody(body.sublist(i, j), refs[k], units[k], padHeight).toDouble());

  // best[k][j]: best total for the first j strokes written as the first k units.
  final best = List.generate(n + 1, (_) => List.filled(s + 1, -1.0));
  final from = List.generate(n + 1, (_) => List.filled(s + 1, 0));
  best[0][0] = 0;
  for (int k = 1; k <= n; k++) {
    for (int j = k; j <= s - (n - k); j++) {
      for (int i = math.max(k - 1, j - _maxStrokesPerUnit); i < j; i++) {
        if (best[k - 1][i] < 0) continue;
        final v = best[k - 1][i] + score(i, j, k - 1);
        if (v > best[k][j]) { best[k][j] = v; from[k][j] = i; }
      }
    }
  }
  if (best[n][s] < 0) return _splitByWidth(body, _box(body.expand((x) => x)), n);
  final groups = List.generate(n, (_) => <List<Offset>>[]);
  int j = s;
  for (int k = n; k >= 1; k--) {
    final i = from[k][j];
    groups[k - 1].addAll(body.sublist(i, j));
    j = i;
  }
  return groups;
}

/// Fallback when there are fewer strokes than blocks: equal-width columns
/// across the writing itself (not across the pad).
List<List<List<Offset>>> _splitByWidth(List<List<Offset>> body, _Box whole, int n) {
  final groups = List.generate(n, (_) => <List<Offset>>[]);
  final w = math.max(whole.width, 1e-6) / n;
  for (final s in body) {
    groups[((_box(s).centerX - whole.minX) / w).floor().clamp(0, n - 1)].add(s);
  }
  return groups;
}

/// [s] with extra points so no two neighbours are more than [step] apart.
List<Offset> _densify(List<Offset> s, double step) {
  final out = <Offset>[s.first];
  for (int i = 1; i < s.length; i++) {
    final a = s[i - 1], b = s[i];
    final k = math.max(1, ((b - a).distance / step).ceil());
    for (int j = 1; j <= k; j++) {
      out.add(Offset.lerp(a, b, j / k)!);
    }
  }
  return out;
}

class _Box {
  final double minX, maxX, minY, maxY;
  const _Box(this.minX, this.maxX, this.minY, this.maxY);
  double get width => maxX - minX;
  double get height => maxY - minY;
  double get centerX => (minX + maxX) / 2;
}

_Box _box(Iterable<Offset> pts) {
  double minX = double.infinity, maxX = -double.infinity, minY = double.infinity, maxY = -double.infinity;
  for (final p in pts) {
    minX = math.min(minX, p.dx); maxX = math.max(maxX, p.dx);
    minY = math.min(minY, p.dy); maxY = math.max(maxY, p.dy);
  }
  return minX == double.infinity ? const _Box(0, 0, 0, 0) : _Box(minX, maxX, minY, maxY);
}
