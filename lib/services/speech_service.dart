import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../data/models.dart';

/// Port of speechService.ts — bundled mp3 first, device TTS fallback.
class SpeechService {
  static final AudioPlayer _player = AudioPlayer();
  static final FlutterTts _tts = FlutterTts();
  static bool _inited = false;
  /// Mirrors the Profile "Sound" setting; when true nothing is played.
  static bool muted = false;

  static Future<void> init() async {
    if (_inited) return;
    _inited = true;
    try {
      await _tts.setLanguage('hi-IN');
      await _tts.setPitch(1.0);
    } catch (_) {}
  }

  static Future<bool> _tryBundled(String text) async {
    if (muted) return true; // pretend it played so callers skip the TTS fallback
    try {
      final id = AppData.audioTextToId[text];
      if (id == null || !AppData.audioIds.contains(id)) return false;
      await _player.stop();
      await _player.play(AssetSource('audio/$id.mp3'));
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _tts_(String text, String lang, double rate) async {
    if (muted) return;
    try {
      await init();
      await _tts.setLanguage(lang);
      await _tts.setSpeechRate(rate);
      await _tts.speak(text);
    } catch (_) {}
  }
}

Future<void> speakHindi(String text, {double rate = 0.55}) async {
  if (await SpeechService._tryBundled(text)) return;
  await SpeechService._tts_(text, 'hi-IN', rate * 0.75);
}

Future<void> speakLetterSlow(String text) async {
  if (await SpeechService._tryBundled(text)) return;
  await SpeechService._tts_(text, 'hi-IN', 0.4);
}

void speakEnglish(String text) {
  SpeechService._tts_(text, 'en-US', 0.5);
}

Future<void> speakLetterWithGuide(String letter, String pronunciation, [String? exampleWord]) async {
  final played = await SpeechService._tryBundled(letter);
  if (played) {
    if (exampleWord != null) {
      Timer(const Duration(milliseconds: 800), () async {
        if (!await SpeechService._tryBundled(exampleWord)) {
          SpeechService._tts_(exampleWord, 'hi-IN', 0.5);
        }
      });
    }
  } else {
    await SpeechService._tts_(letter, 'hi-IN', 0.4);
    if (exampleWord != null) {
      Timer(const Duration(milliseconds: 1200), () => SpeechService._tts_(exampleWord, 'hi-IN', 0.5));
    }
  }
}

void speakSyllables(List<String> syllables, {int delayMs = 500}) {
  for (int i = 0; i < syllables.length; i++) {
    Timer(Duration(milliseconds: i * delayMs), () async {
      if (!await SpeechService._tryBundled(syllables[i])) {
        SpeechService._tts_(syllables[i], 'hi-IN', 0.45);
      }
    });
  }
}

Future<void> stopSpeaking() async {
  try { await SpeechService._tts.stop(); } catch (_) {}
  try { await SpeechService._player.stop(); } catch (_) {}
}

/// Direct device-TTS speak (expo-speech `Speech.speak` equivalent), skipping bundled audio.
Future<void> speakDevice(String text, {String lang = 'hi-IN', double rate = 0.8}) =>
    SpeechService._tts_(text, lang, rate * 0.75);
