import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hindi_mitra/data/models.dart';
import 'package:hindi_mitra/services/ink_recognizer.dart';
import 'package:hindi_mitra/services/stroke_evaluator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final st = json.decode(File('assets/data/stroke_templates.json').readAsStringSync()) as Map;
    AppData.strokeTemplates = st.map((k, v) => MapEntry(k as String, StrokeTemplate.fromJson(v)));
    // A handwriting model that is downloaded and always reads the ink as क.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('google_mlkit_digital_ink_recognizer'), (call) async {
      if (call.method == 'vision#manageInkModels') return true;
      if (call.method == 'vision#startDigitalInkRecognizer') return [{'text': 'क', 'score': 0.0}];
      return null;
    });
    await InkModel.prepare();
  });

  test('the result shows the same accuracy as the live meter when the model agrees', () async {
    final ka = AppData.strokeTemplates.entries.firstWhere((e) => e.value.character == 'क').key;
    // A slightly sloppy क: shifted points so the score is below 100.
    final drawing = [
      for (final s in AppData.strokeTemplates[ka]!.strokes)
        [for (int i = 0; i < s.length; i++) Offset(s[i].x * 300 + (i.isEven ? 9 : -9), s[i].y * 300 + (i % 3) * 6)],
    ];
    final meter = evaluateStrokes(drawing, ka, 300).accuracy;
    final result = await gradeWriting(drawing, ka, 300);
    expect(InkModel.ready, isTrue);
    expect(result.source, 'ml-kit');
    expect(result.feedback, contains('Recognised as क'));
    expect(result.accuracy, meter);
  });

  test('a letter the model reads correctly is not marked as a fail', () async {
    final ka = AppData.strokeTemplates.entries.firstWhere((e) => e.value.character == 'क').key;
    // Recognisable but very rough: big offsets on every point.
    final rough = [
      for (final s in AppData.strokeTemplates[ka]!.strokes)
        [for (int i = 0; i < s.length; i++) Offset(s[i].x * 300 + (i.isEven ? 30 : -30), s[i].y * 300 + (i % 3) * 22)],
    ];
    final meter = evaluateStrokes(rough, ka, 300).accuracy;
    final result = await gradeWriting(rough, ka, 300);
    expect(result.accuracy, greaterThanOrEqualTo(kRecognisedFloor));
    if (meter < kRecognisedFloor) {
      expect(result.detail!.adjustments.single.reason, contains('Recognised'));
      expect(result.accuracy, meter + result.detail!.adjustments.single.points);
    }
  });
}
