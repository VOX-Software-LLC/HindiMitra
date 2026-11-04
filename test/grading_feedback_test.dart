import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hindi_mitra/data/models.dart';
import 'package:hindi_mitra/services/stroke_evaluator.dart';

/// Letter [id]'s template drawn on a [size]px canvas.
List<List<Offset>> _draw(String id, {double size = 300}) => [
      for (final s in AppData.strokeTemplates[id]!.strokes) [for (final p in s) Offset(p.x * size, p.y * size)],
    ];

String _idOf(String ch) => AppData.strokeTemplates.entries.firstWhere((e) => e.value.character == ch).key;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    final st = json.decode(File('assets/data/stroke_templates.json').readAsStringSync()) as Map;
    AppData.strokeTemplates = st.map((k, v) => MapEntry(k as String, StrokeTemplate.fromJson(v)));
    // No ML Kit in tests: the recognizer falls back to template matching.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('google_mlkit_digital_ink_recognizer'), (_) async => throw PlatformException(code: 'none'));
  });

  test('the right letter written well scores 3 stars with specific feedback', () async {
    final ka = _idOf('क');
    final r = await gradeWriting(_draw(ka), ka, 300);
    expect(r.stars, 3);
    expect(r.detectedLetter, isNull);
    expect(r.feedback, isNotEmpty);
  });

  test('a different letter is caught and capped at 1 star', () async {
    final ka = _idOf('क'), kha = _idOf('ख');
    final r = await gradeWriting(_draw(kha), ka, 300);
    expect(r.stars, lessThanOrEqualTo(1));
    expect(r.detectedLetter, 'ख');
    expect(r.feedback, contains('ख'));
  });

  test('missing a stroke is named in the feedback', () async {
    final ka = _idOf('क');
    final r = await gradeWriting(_draw(ka).sublist(0, 2), ka, 300);
    expect(r.feedback + (r.actionableTip ?? ''), contains('needs 3'));
  });

  test('feedback is not the same sentence every time', () async {
    final ka = _idOf('क');
    final seen = <String>{};
    for (int i = 0; i < 12; i++) {
      seen.add((await gradeWriting(_draw(ka), ka, 300)).feedback);
    }
    expect(seen.length, greaterThan(2));
  });

  test('progress against the last try is mentioned', () async {
    final ka = _idOf('क');
    final r = await gradeWriting(_draw(ka), ka, 300, previousAccuracy: 50);
    expect(r.feedback, contains('last'));
    expect(r.feedback, contains('%'));
  });

  test('the shown score always adds up: weighted average + labelled adjustments', () async {
    final ids = AppData.strokeTemplates.keys.toList();
    for (int i = 0; i < ids.length; i += 3) {
      final r = await gradeWriting(_draw(ids[(i + 5) % ids.length]), ids[i], 300);
      final d = r.detail!;
      final adj = d.adjustments.fold<int>(0, (a, x) => a + x.points);
      expect(r.accuracy, d.weightedScore + adj, reason: ids[i]);
      expect(r.stars, starsForAccuracy(r.accuracy));
    }
  });

  test('tips below 70 % name the mistake that cost the most points', () async {
    final ka = _idOf('क');
    // Two of three strokes: the biggest loss is the missing part.
    final missing = await gradeWriting(_draw(ka).sublist(0, 2), ka, 300);
    final tips = improvementTips(missing.detail!, 'क');
    expect(tips, isNotEmpty);
    expect(tips.first.criterion, anyOf('All parts drawn', 'Stroke count'));
    for (int i = 1; i < tips.length; i++) {
      expect(tips[i].pointsLost, lessThanOrEqualTo(tips[i - 1].pointsLost));
    }
    // Writing a different letter leads with that.
    final kha = _idOf('ख');
    final wrong = await gradeWriting(_draw(kha), ka, 300);
    expect(improvementTips(wrong.detail!, 'क', otherLetter: wrong.detectedLetter).first.title, contains('ख'));
    // A perfect letter gets no tips at all.
    expect(improvementTips((await gradeWriting(_draw(ka), ka, 300)).detail!, 'क'), isEmpty);
  });

  test('a tip is only given for a criterion that actually lost points', () {
    final ka = _idOf('क');
    final r = evaluateStrokes(_draw(ka), ka, 300);
    final lost = {for (final c in r.criteria) c.label: ((1 - c.score) * c.weight * 100).round()};
    for (final t in improvementTips(r, 'क', max: 7)) {
      expect(lost[t.criterion], greaterThanOrEqualTo(3), reason: t.criterion);
    }
  });
}
