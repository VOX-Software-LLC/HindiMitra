import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:google_mlkit_digital_ink_recognition/google_mlkit_digital_ink_recognition.dart' as mlkit;

/// Google ML Kit on-device handwriting recognition for Hindi. It tells us which
/// character the child actually wrote, as a second opinion next to the shape
/// score. The model (~20 MB) downloads once on first launch; until it is ready,
/// or on platforms without ML Kit (web, desktop), [recognize] returns null and
/// grading uses shape matching alone.
class InkModel {
  static const _lang = 'hi';
  static mlkit.DigitalInkRecognizer? _recognizer;
  static Future<void>? _preparing;

  static bool get supported =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  static bool get ready => _recognizer != null;

  /// Downloads the Hindi model if needed. Safe to call repeatedly; never throws.
  static Future<void> prepare() {
    if (!supported || ready) return Future.value();
    return _preparing ??= () async {
      try {
        final manager = mlkit.DigitalInkRecognizerModelManager();
        if (!await manager.isModelDownloaded(_lang)) {
          await manager.downloadModel(_lang, isWifiRequired: false);
        }
        _recognizer = mlkit.DigitalInkRecognizer(languageCode: _lang);
      } catch (e) {
        debugPrint('InkModel.prepare failed: $e');
      } finally {
        _preparing = null;
      }
    }();
  }

  /// Candidate texts for [strokes] (best first), or null when the model is
  /// not available. Points get synthetic timestamps since the canvas keeps none.
  static Future<List<String>?> recognize(List<List<Offset>> strokes, Size area) async {
    final rec = _recognizer;
    if (rec == null) {
      unawaited(prepare());
      return null;
    }
    try {
      final ink = mlkit.Ink();
      int t = 0;
      for (final s in strokes) {
        if (s.isEmpty) continue;
        final stroke = mlkit.Stroke();
        for (final p in s) {
          stroke.points.add(mlkit.StrokePoint(x: p.dx, y: p.dy, t: t));
          t += 12;
        }
        t += 150;
        ink.strokes.add(stroke);
      }
      if (ink.strokes.isEmpty) return const [];
      final out = await rec
          .recognize(ink, context: mlkit.DigitalInkRecognitionContext(
              writingArea: mlkit.WritingArea(width: area.width, height: area.height)))
          .timeout(const Duration(seconds: 3));
      return [for (final c in out) c.text.trim()];
    } catch (e) {
      debugPrint('InkModel.recognize failed: $e');
      return null;
    }
  }
}
