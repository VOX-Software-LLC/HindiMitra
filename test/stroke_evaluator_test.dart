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

  test('drawing strokes backwards costs points', () {
    final back = [for (final s in _draw('c02')) s.reversed.toList()];
    expect(_acc(back, 'c02'), lessThan(70));
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
}
