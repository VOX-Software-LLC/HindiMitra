import 'dart:async';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../util/num_ext.dart';

/// Result of a single on-device listen-and-score attempt.
class PronunciationResult {
  final String recognizedText;
  final int score; // 0-100 overall, blends similarity/confidence/timing
  final double similarity; // 0-1 text match vs target
  final double confidence; // 0-1 engine confidence in the transcription
  final double timing; // 0-1 pacing score
  final bool usedFallbackLocale; // true if no hi-* locale was available on-device
  const PronunciationResult({
    required this.recognizedText,
    required this.score,
    required this.similarity,
    required this.confidence,
    required this.timing,
    required this.usedFallbackLocale,
  });
}

/// On-device speech recognition for Pronunciation Coach (expo-speech-recognition
/// equivalent). No network call and no API key: uses the OS's built-in speech
/// recognizer (speech_to_text plugin) and scores the transcript locally against
/// the target Hindi text with a Levenshtein-distance similarity measure, mirroring
/// the static-function style of speech_service.dart.
class SpeechRecognitionService {
  static final SpeechToText _stt = SpeechToText();
  static bool _available = false;
  static bool _inited = false;
  static List<LocaleName> _locales = [];

  static Future<bool> _ensureInit() async {
    if (_inited) return _available;
    _inited = true;
    try {
      _available = await _stt.initialize(debugLogging: false);
      if (_available) {
        try { _locales = await _stt.locales(); } catch (_) {}
      }
    } catch (_) {
      _available = false;
    }
    return _available;
  }

  static String? _hindiLocaleId() {
    for (final l in _locales) {
      if (l.localeId.toLowerCase().startsWith('hi')) return l.localeId;
    }
    return null;
  }

  /// True once init has been attempted and the device has no usable recognizer
  /// (permission denied, unsupported platform/browser, etc).
  static bool get isUnavailable => _inited && !_available;

  /// Listens for up to [timeout], then scores how closely what was heard
  /// matches [targetHindi]. Returns null if the mic/recognizer is unavailable.
  static Future<PronunciationResult?> listenAndScore({
    required String targetHindi,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final ok = await _ensureInit();
    if (!ok) return null;
    final localeId = _hindiLocaleId();
    final sw = Stopwatch()..start();
    final completer = Completer<SpeechRecognitionResult?>();

    try {
      await _stt.listen(
        onResult: (r) {
          if (r.finalResult && !completer.isCompleted) completer.complete(r);
        },
        listenOptions: SpeechListenOptions(
          listenFor: timeout,
          pauseFor: Duration(seconds: timeout.inSeconds.clampI(2, 4)),
          localeId: localeId,
          partialResults: true,
          cancelOnError: true,
        ),
      );
    } catch (_) {
      return null;
    }

    SpeechRecognitionResult? result;
    try {
      result = await completer.future.timeout(timeout + const Duration(seconds: 1), onTimeout: () => null);
    } catch (_) {
      result = null;
    }
    sw.stop();
    try { await _stt.stop(); } catch (_) {}

    final recognized = result?.recognizedWords ?? '';
    final confidenceRaw = result?.confidence ?? 0;
    // Many devices never report a real confidence value (0 or -1 = "missing").
    // Don't let that tank the score — treat missing confidence as neutral.
    final confidence = confidenceRaw <= 0 ? 0.7 : confidenceRaw.clampD(0.0, 1.0);

    final similarity = _similarity(_normalize(recognized), _normalize(targetHindi));
    final timing = _timingScore(sw.elapsedMilliseconds, targetHindi);
    final score = ((similarity * 0.6 + confidence * 0.25 + timing * 0.15) * 100).clampD(0.0, 100.0).round();

    return PronunciationResult(
      recognizedText: recognized,
      score: score,
      similarity: similarity,
      confidence: confidence,
      timing: timing,
      usedFallbackLocale: localeId == null,
    );
  }

  static void cancel() { try { _stt.cancel(); } catch (_) {} }

  static String _normalize(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), '');

  static double _similarity(String a, String b) {
    if (a.isEmpty && b.isEmpty) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;
    final ra = a.runes.toList(), rb = b.runes.toList();
    final dist = _levenshtein(ra, rb);
    final maxLen = ra.length > rb.length ? ra.length : rb.length;
    return (1 - dist / maxLen).clampD(0.0, 1.0);
  }

  static int _levenshtein(List<int> a, List<int> b) {
    final m = a.length, n = b.length;
    var prev = List<int>.generate(n + 1, (j) => j);
    for (int i = 1; i <= m; i++) {
      final cur = List<int>.filled(n + 1, 0);
      cur[0] = i;
      for (int j = 1; j <= n; j++) {
        cur[j] = a[i - 1] == b[j - 1]
            ? prev[j - 1]
            : 1 + [prev[j - 1], prev[j], cur[j - 1]].reduce((x, y) => x < y ? x : y);
      }
      prev = cur;
    }
    return prev[n];
  }

  /// Rough expected speaking duration for [target], used to turn elapsed
  /// listen time into a 0-1 pacing score (closer to expected == closer to 1).
  static double _timingScore(int elapsedMs, String target) {
    final expectedMs = 400 + target.runes.length * 220;
    final ratio = elapsedMs / expectedMs;
    return (1 - (ratio - 1).abs()).clampD(0.0, 1.0);
  }
}
