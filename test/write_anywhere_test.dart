import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:hindi_mitra/data/models.dart';
import 'package:hindi_mitra/services/stroke_evaluator.dart';
import 'package:hindi_mitra/data/word_bank.dart';
import 'package:hindi_mitra/services/word_grader.dart';

/// [units] written left to right, each [h] tall, starting at ([x], [y]), with
/// [gaps][k] px of space before block k and one header line across the word.
List<List<Offset>> _word(List<String> units, {double x = 0, double y = 0, double h = 200, List<double>? gaps}) {
  final out = <List<Offset>>[];
  double left = x;
  for (int k = 0; k < units.length; k++) {
    left += gaps?[k] ?? 0;
    final w = h * 0.9;
    for (final s in strokesForText(units[k])!) {
      // Skip each block's own header line; one long header is drawn below.
      if (s.length == 2 && (s[0].y - s[1].y).abs() < 0.03 && (s[0].x - s[1].x).abs() > 0.5) continue;
      out.add([for (final p in s) Offset(left + p.x * w, y + p.y * h)]);
    }
    left += w;
  }
  out.add([Offset(x, y + h * 0.1), Offset(left, y + h * 0.1)]);
  return out;
}


/// A word written by a "hand": optional slant, per-letter header pieces,
/// letters bobbing up and down, spacing and shake.
List<List<Offset>> _hand(List<String> units,
    {double x = 20, double y = 40, double h = 160, double gap = 0, bool letterHeaders = false,
    double slantDeg = 0, double drift = 0, double jitter = 0, int seed = 1}) {
  final r = Random(seed);
  final out = <List<Offset>>[], heads = <List<Offset>>[];
  final a = slantDeg * pi / 180;
  Offset tf(Offset p) => Offset(x + (p.dx - x) * cos(a) - (p.dy - y) * sin(a), y + (p.dx - x) * sin(a) + (p.dy - y) * cos(a));
  double left = x;
  for (final u in units) {
    final w = h * 0.9, top = y + (r.nextDouble() * 2 - 1) * drift * h;
    Offset at(double ux, double uy) =>
        tf(Offset(left + ux * w + (r.nextDouble() - 0.5) * jitter, top + uy * h + (r.nextDouble() - 0.5) * jitter));
    for (final s in strokesForText(u)!) {
      final isHead = s.length == 2 && (s[0].y - s[1].y).abs() < 0.03 && (s[0].x - s[1].x).abs() > 0.5;
      final pts = [
        for (int i = 0; i < s.length - 1; i++)
          for (int k = 0; k < 6; k++) at(s[i].x + (s[i + 1].x - s[i].x) * k / 6, s[i].y + (s[i + 1].y - s[i].y) * k / 6),
        at(s.last.x, s.last.y),
      ];
      if (!isHead) { out.add(pts); } else if (letterHeaders) { heads.add(pts); }
    }
    left += w + gap;
  }
  if (!letterHeaders) heads.add([for (int i = 0; i <= 20; i++) tf(Offset(x + (left - gap - x) * i / 20, y + h * 0.1))]);
  return [...out, ...heads];
}

void main() {
  setUpAll(() {
    final st = json.decode(File('assets/data/stroke_templates.json').readAsStringSync()) as Map;
    AppData.strokeTemplates = st.map((k, v) => MapEntry(k as String, StrokeTemplate.fromJson(v)));
  });

  const units = ['क', 'म', 'ल'];
  const pad = 300.0;

  test('a word scores well wherever and however it is written on the pad', () {
    final normal = gradeWordStrokes(_word(units), units, pad).accuracy;
    final shifted = gradeWordStrokes(_word(units, x: 140, y: 60), units, pad).accuracy;
    final smaller = gradeWordStrokes(_word(units, x: 30, y: 90, h: 120), units, pad).accuracy;
    final uneven = gradeWordStrokes(_word(units, x: 20, h: 150, gaps: [0, 45, 10]), units, pad).accuracy;
    expect(normal, greaterThanOrEqualTo(80));
    for (final v in [shifted, smaller, uneven]) {
      expect(v, greaterThanOrEqualTo(normal - 10), reason: 'normal $normal shifted $shifted smaller $smaller uneven $uneven');
    }
  });

  test('a different word still scores low', () {
    const other = ['ग', 'ज', 'ह'];
    final good = gradeWordStrokes(_word(units), units, pad).accuracy;
    final wrong = gradeWordStrokes(_word(other), units, pad).accuracy;
    expect(wrong, lessThan(good - 25), reason: 'good $good wrong $wrong');
  });

  test('a letter scores the same wherever it is on the pad', () {
    final ka = AppData.strokeTemplates.entries.firstWhere((e) => e.value.character == 'क').key;
    List<List<Offset>> at(double x, double y, double size) => [
          for (final s in AppData.strokeTemplates[ka]!.strokes) [for (final p in s) Offset(x + p.x * size, y + p.y * size)],
        ];
    final centred = evaluateStrokes(at(30, 30, 240), ka, 300).accuracy;
    final corner = evaluateStrokes(at(150, 150, 140), ka, 300).accuracy;
    expect(corner, centred);
  });

  test('every practice word scores well however a child writes it', () {
    // Slanted, letters bobbing, a header piece over each letter, squeezed,
    // spread out, tiny in a corner — all are the same word.
    final ways = <String, List<List<Offset>> Function(List<String>)>{
      'neat': (u) => _hand(u),
      'slant +8°': (u) => _hand(u, slantDeg: 8),
      'slant -8°': (u) => _hand(u, slantDeg: -8),
      'bobbing letters': (u) => _hand(u, drift: 0.12, seed: 3),
      'header per letter': (u) => _hand(u, letterHeaders: true),
      'squeezed': (u) => _hand(u, gap: -18),
      'spread out': (u) => _hand(u, gap: 60),
      'tiny in a corner': (u) => _hand(u, x: 200, y: 220, h: 50),
    };
    for (final w in practiceWords) {
      for (final e in ways.entries) {
        final g = gradeWordStrokes(e.value(w.units), w.units, pad);
        expect(g.accuracy, greaterThanOrEqualTo(80),
            reason: '${w.word} written ${e.key}: ${g.unitScores} header ${g.headerDrawn}');
      }
    }
  });

  test('a different word of the same length rarely passes', () {
    int high = 0, total = 0;
    for (final a in practiceWords) {
      for (final b in practiceWords) {
        if (a.word == b.word || a.units.length != b.units.length) continue;
        total++;
        if (gradeWordStrokes(_hand(b.units), a.units, pad).accuracy >= 70) high++;
      }
    }
    expect(high / total, lessThan(0.01), reason: '$high of $total wrong words passed');
  });
}
