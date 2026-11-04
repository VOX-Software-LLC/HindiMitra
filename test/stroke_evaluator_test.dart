import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:hindi_mitra/data/models.dart';
import 'package:hindi_mitra/services/stroke_evaluator.dart';

/// Letter [id]'s template written on a [size]px canvas the way a hand would:
/// a smooth wobble of [warp] (fraction of the letter size) plus [jitter] px of
/// shake, optionally stretched by [sx]/[sy].
List<List<Offset>> _draw(String id,
    {double size = 300, double warp = 0, double jitter = 0, int seed = 1, double sx = 1, double sy = 1}) {
  final r = Random(seed);
  final px = r.nextDouble() * 6, py = r.nextDouble() * 6, f1 = 2 + r.nextDouble() * 2, f2 = 2 + r.nextDouble() * 2;
  Offset at(double x, double y) => Offset(
        (x + warp * sin(f1 * y + px)) * size * sx + (r.nextDouble() - 0.5) * jitter,
        (y + warp * sin(f2 * x + py)) * size * sy + (r.nextDouble() - 0.5) * jitter,
      );
  return [
    for (final s in AppData.strokeTemplates[id]!.strokes)
      [
        for (int i = 0; i < s.length - 1; i++)
          for (int k = 0; k < 6; k++) at(s[i].x + (s[i + 1].x - s[i].x) * k / 6, s[i].y + (s[i + 1].y - s[i].y) * k / 6),
        at(s.last.x, s.last.y),
      ],
  ];
}

int _acc(List<List<Offset>> drawing, String id) => evaluateStrokes(drawing, id, 300).accuracy;

void main() {
  setUpAll(() {
    final st = json.decode(File('assets/data/stroke_templates.json').readAsStringSync()) as Map;
    AppData.strokeTemplates = st.map((k, v) => MapEntry(k as String, StrokeTemplate.fromJson(v)));
  });

  test('every letter written carefully scores 3 stars', () {
    for (final id in AppData.strokeTemplates.keys) {
      expect(_acc(_draw(id, warp: 0.02, jitter: 4), id), greaterThanOrEqualTo(90), reason: id);
    }
  });

  test('a wobbly but correct letter still earns at least 2 stars', () {
    final scores = [
      for (final id in AppData.strokeTemplates.keys)
        for (int seed = 1; seed <= 3; seed++) _acc(_draw(id, warp: 0.04, jitter: 10, seed: seed), id),
    ];
    expect(scores.where((s) => s >= 70).length / scores.length, greaterThanOrEqualTo(0.95));
  });

  test('look-alike letters are told apart', () {
    // ख/र, ब/प, श/ष, च/छ, ठ/थ, ड/द, ध/य
    const pairs = [['c02', 'c27'], ['c23', 'c21'], ['c30', 'c31'], ['c06', 'c07'], ['c12', 'c17'], ['c13', 'c18'], ['c19', 'c26']];
    for (final p in pairs) {
      expect(_acc(_draw(p[0], warp: 0.02, jitter: 6), p[1]), lessThan(70), reason: '${p[0]} graded as ${p[1]}');
      expect(_acc(_draw(p[1], warp: 0.02, jitter: 6), p[0]), lessThan(70), reason: '${p[1]} graded as ${p[0]}');
    }
  });

  test('writing a different letter rarely earns 2 stars', () {
    final ids = AppData.strokeTemplates.keys.toList();
    int high = 0, total = 0;
    for (final a in ids) {
      for (final b in ids) {
        if (a == b) continue;
        total++;
        if (_acc(_draw(a, warp: 0.02, jitter: 6), b) >= 70) high++;
      }
    }
    expect(high / total, lessThan(0.02));
  });

  test('a shaky copy scores lower than a careful one', () {
    expect(_acc(_draw('c02', jitter: 40), 'c02'), lessThan(_acc(_draw('c02', jitter: 4), 'c02')));
  });

  test('a stretched letter is penalised', () {
    expect(_acc(_draw('c27', sx: 2.5, sy: 0.6), 'c27'), lessThan(_acc(_draw('c27'), 'c27') - 15));
  });

  test('drawing strokes backwards costs points but the letter is still accepted', () {
    // Stroke direction is a style difference, not a different letter: it costs
    // its 10 % weight, and the result names it, but the letter still passes.
    final back = [for (final s in _draw('c02')) s.reversed.toList()];
    final forward = _acc(_draw('c02'), 'c02');
    expect(_acc(back, 'c02'), lessThanOrEqualTo(forward - 8));
    expect(_acc(back, 'c02'), greaterThanOrEqualTo(70));
    expect(evaluateStrokes(back, 'c02', 300).directionScore, lessThan(0.3));
  });

  test('the final score is exactly the weighted average of the criteria shown', () {
    final ids = AppData.strokeTemplates.keys.toList();
    for (int i = 0; i < ids.length; i++) {
      for (final d in [_draw(ids[i], warp: 0.03, jitter: 8), _draw(ids[(i + 7) % ids.length], jitter: 6)]) {
        final r = evaluateStrokes(d, ids[i], 300);
        final sum = r.criteria.fold<double>(0, (a, c) => a + c.score * c.weight);
        expect(r.accuracy, (sum * 100).round(), reason: ids[i]);
        expect(r.adjustments, isEmpty);
      }
    }
  });

  test('weights sum to 1 and the formula behaves on hand-picked combinations', () {
    expect(criterionWeights.reduce((a, b) => a + b), closeTo(1, 1e-9));
    List<Criterion> cs(List<double> v) => [for (int i = 0; i < v.length; i++) Criterion('$i', v[i], criterionWeights[i])];
    expect(weightedAverage(cs([1, 1, 1, 1, 1, 1, 1])), 100);
    expect(weightedAverage(cs([0, 0, 0, 0, 0, 0, 0])), 0);
    // Shape 57 %, parts 45 % and the rest around 50 % lands near 50 %, not 20 %.
    expect(weightedAverage(cs([0.57, 0.45, 0.5, 0.5, 0.5, 0.5, 0.5])), inInclusiveRange(48, 52));
    // A single weak criterion only costs its own weight.
    expect(weightedAverage(cs([1, 1, 1, 1, 0, 1, 1])), 90);
    expect(weightedAverage(cs([1, 1, 1, 1, 1, 0, 1])), 95);
    // Every value stays in range.
    expect(weightedAverage(cs([2, -1, 1, 1, 1, 1, 1])), inInclusiveRange(0, 100));
  });

  test('a small or squashed but correct letter is not crushed', () {
    // Written at a third of the box and a little wide: still a pass.
    final small = _draw('c02', size: 110, warp: 0.02, jitter: 2);
    expect(_acc(small, 'c02'), greaterThanOrEqualTo(70));
    expect(_acc(_draw('c02', sx: 1.25, warp: 0.02, jitter: 4), 'c02'), greaterThanOrEqualTo(70));
  });

  test('a missing stroke costs points', () {
    // ष without its slash looks like प — it must not pass as ष.
    final noSlash = _draw('c31')..removeAt(1);
    expect(_acc(noSlash, 'c31'), lessThan(70));
  });

  test('a random scribble scores 0-1 stars', () {
    final r = Random(7);
    final scribble = [
      [for (int i = 0; i < 40; i++) Offset(r.nextDouble() * 300, r.nextDouble() * 300)],
    ];
    expect(evaluateStrokes(scribble, 'c02', 300).stars, lessThanOrEqualTo(1));
  });

  test('every template sits inside the writing box', () {
    for (final t in AppData.strokeTemplates.values) {
      for (final p in t.strokes.expand((s) => s)) {
        expect(p.x, inInclusiveRange(0.0, 1.0), reason: t.letterId);
        expect(p.y, inInclusiveRange(0.0, 1.0), reason: t.letterId);
      }
    }
  });

  test('a tilted letter is still the same letter', () {
    // Children often write the whole letter on a slant: it is straightened
    // using its header line (or standing line) before comparing.
    List<List<Offset>> tilted(String id, double deg) {
      final a = deg * pi / 180;
      return [
        for (final s in _draw(id, warp: 0.02, jitter: 4))
          [for (final p in s) Offset(150 + (p.dx - 150) * cos(a) - (p.dy - 150) * sin(a), 150 + (p.dx - 150) * sin(a) + (p.dy - 150) * cos(a))],
      ];
    }
    for (final id in AppData.strokeTemplates.keys) {
      for (final deg in [-10.0, 10.0]) {
        final d = tilted(id, deg);
        expect(_acc(d, id), greaterThanOrEqualTo(80), reason: '$id tilted $deg°');
        expect(findBestMatchingLetter(d, 300)?.letterId, id, reason: '$id tilted $deg° recognised');
      }
    }
  });
}

