import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:hindi_mitra/data/matra_course.dart';
import 'package:hindi_mitra/data/models.dart';
import 'package:hindi_mitra/services/matra_checker.dart';

/// Canvas strokes for [g]'s own sign model (a perfect copy), optionally
/// shifted by [dx] block units.
List<List<Offset>> _signInk(MatraGlyph g, MatraFrame f, {double dx = 0, double dy = 0}) =>
    [for (final s in g.signStrokes) [for (final p in s) f.toCanvas(Pt(p.x + dx, p.y + dy))]];

void main() {
  late List<Matra> matras;
  setUpAll(() {
    final st = json.decode(File('assets/data/stroke_templates.json').readAsStringSync()) as Map;
    AppData.strokeTemplates = st.map((k, v) => MapEntry(k as String, StrokeTemplate.fromJson(v)));
    final m = json.decode(File('assets/data/matras.json').readAsStringSync()) as Map;
    matras = (m['matras'] as List).map((e) => Matra.fromJson(e)).toList();
  });

  Matra bySign(String s) => matras.firstWhere((m) => m.symbol == s);

  test('every matra has a place, an English anchor, a Hinglish tip and words', () {
    expect(matras.map((m) => m.symbol).toSet(), containsAll(['ृ', 'ं', 'ः']));
    for (final m in matras) {
      expect(['left', 'right', 'top', 'bottom'], contains(m.position), reason: m.symbol);
      expect(m.anchor, isNotEmpty, reason: m.symbol);
      expect(m.hinglish, isNotEmpty, reason: m.symbol);
      expect(matraWords[m.romanized], isNotEmpty, reason: m.symbol);
    }
  });

  test('course words: blocks spell the word, the slot carries the matra and can be drawn', () {
    final all = <(MatraWord, String)>[
      for (final e in matraWords.entries)
        for (final w in e.value) (w, matras.firstWhere((m) => m.romanized == e.key).symbol),
      for (final p in matraPairs) (p.to, matraOf(p.to.unit)),
      for (final f in matraFixes) (f.right, matraOf(f.right.unit)),
      for (final t in matraThemes) for (final w in t.$3) (w, matraOf(w.unit)),
    ];
    for (final (w, sign) in all) {
      expect(w.units.join(), w.word, reason: w.word);
      expect(w.unit, w.base + sign, reason: '${w.word}: slot ${w.unit} should be ${w.base} + $sign');
      expect(MatraGlyph.of(w.base, sign), isNotNull, reason: '${w.word}: no model for ${w.base}');
    }
    for (final p in matraPairs) {
      expect(p.from.units.length, p.to.units.length);
      for (int i = 0; i < p.to.units.length; i++) {
        if (i != p.to.slot) expect(p.from.units[i], p.to.units[i], reason: '${p.from.word} → ${p.to.word}');
      }
      expect(p.from.unit, isNot(p.to.unit));
    }
    for (final f in matraFixes) {
      for (int i = 0; i < f.wrong.length; i++) {
        expect(f.wrong[i] == f.right.units[i], i != f.right.slot, reason: f.right.word);
      }
    }
  });

  test('a well-made sign in the right place passes', () {
    for (final m in matras) {
      for (final base in ['क', 'म', 'स', 'प']) {
        final g = MatraGlyph.of(base, m.symbol)!;
        final f = MatraFrame(const Size(480, 300), g.baseMid);
        final v = checkMatraPlacement(_signInk(g, f), g, m.position, f);
        expect(v.zone, m.position, reason: '$base${m.symbol}');
        expect(v.passed, isTrue, reason: '$base${m.symbol} scored ${v.accuracy}');
      }
    }
  });

  test('a sign on the wrong side gets a placement hint, not a pass', () {
    final f0 = MatraGlyph.of('क', 'ि')!;
    final f = MatraFrame(const Size(480, 300), f0.baseMid);
    // ि written after the letter (where ी's stem goes).
    final shift = (f0.baseRight + 0.14) - 0.14;
    final v = checkMatraPlacement(_signInk(f0, f, dx: shift), f0, bySign('ि').position, f);
    expect(v.zone, 'right');
    expect(v.placedRight, isFalse);

    // ा written before the letter.
    final g = MatraGlyph.of('क', 'ा')!;
    final f2 = MatraFrame(const Size(480, 300), g.baseMid);
    final v2 = checkMatraPlacement(_signInk(g, f2, dx: -(g.baseRight + 0.16 - g.baseLeft + 0.16)), g, 'right', f2);
    expect(v2.zone, 'left');
    expect(v2.passed, isFalse);

    // े drawn under the letter instead of on top.
    final e = MatraGlyph.of('म', 'े')!;
    final f3 = MatraFrame(const Size(480, 300), e.baseMid);
    final v3 = checkMatraPlacement(_signInk(e, f3, dy: 0.9), e, 'top', f3);
    expect(v3.zone, 'bottom');
    expect(v3.passed, isFalse);
  });

  test('a scribble in the right place does not pass as the sign', () {
    final g = MatraGlyph.of('क', 'ु')!;
    final f = MatraFrame(const Size(480, 300), g.baseMid);
    final zig = [for (int i = 0; i < 12; i++) f.toCanvas(Pt(0.3 + i * 0.04, i.isEven ? 0.88 : 0.98))];
    final v = checkMatraPlacement([zig], g, 'bottom', f);
    expect(v.placedRight, isTrue);
    expect(v.passed, isFalse, reason: 'scribble scored ${v.accuracy}');
  });

  test('aksharas splits names into written blocks', () {
    expect(aksharas('अभिषेक'), ['अ', 'भि', 'षे', 'क']);
    expect(aksharas('प्रिया'), ['प्रि', 'या']);
    expect(aksharas('आर्यन शर्मा'), ['आ', 'र्य', 'न', 'श', 'र्मा']);
  });
}
