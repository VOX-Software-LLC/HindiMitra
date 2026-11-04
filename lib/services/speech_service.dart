import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../data/audio_qa.dart';
import '../data/models.dart';
import '../data/voice_clips.dart';

/// Port of speechService.ts — bundled mp3 first, device TTS fallback.
class SpeechService {
  static final AudioPlayer _player = AudioPlayer();
  static final FlutterTts _tts = FlutterTts();
  static bool _inited = false;
  /// Mirrors the Profile "Sound" setting; when true nothing is played.
  static bool muted = false;
  /// Mirrors the Profile "Voice" setting: 'female' or 'male'.
  static String voice = 'female';

  static Future<void> init() async {
    if (_inited) return;
    _inited = true;
    try {
      await _tts.setLanguage('hi-IN');
      await _tts.setPitch(1.0);
    } catch (_) {}
  }

  static bool? _hindiVoice;

  /// Whether the device has a Hindi voice (checked once).
  static Future<bool> _hasHindiVoice() async {
    if (_hindiVoice != null) return _hindiVoice!;
    try {
      await init();
      _hindiVoice = (await _tts.isLanguageAvailable('hi-IN')) == true;
    } catch (_) {
      _hindiVoice = false;
    }
    return _hindiVoice!;
  }

  static Future<bool> _tryBundled(String text) async {
    if (muted) return true; // pretend it played so callers skip the TTS fallback
    try {
      final id = AppData.audioTextToId[text];
      if (id == null || !AppData.audioIds.contains(id)) return false;
      // Letters have a male and a female recording.
      if (voiceLetterId(id) != null) {
        await _playVoice(id);
        return true;
      }
      // A clip that failed QA: use the device voice instead when there is one.
      if (audioClipsFailedQa.contains(id) && await _hasHindiVoice()) {
        await _tts_(text, 'hi-IN', 0.4);
        return true;
      }
      await _player.stop();
      await _player.play(AssetSource('audio/$id.mp3'));
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _playVoice(String clipId) async {
    final g = voiceGenders.contains(voice) ? voice : voiceGenders.first;
    await _player.stop();
    await _player.play(AssetSource('audio/$g/$clipId.wav'));
  }

  /// Plays the "क से …" example recording for [letter] in the chosen voice;
  /// false when there is none for it.
  static Future<bool> _tryVoiceExample(String letter) async {
    if (muted) return true;
    try {
      final lid = voiceLetterId(AppData.audioTextToId[letter] ?? '');
      if (lid == null || !voiceExampleLetterIds.contains(lid)) return false;
      await _playVoice('example_$lid');
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
        if (await SpeechService._tryVoiceExample(letter)) return;
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

/// Speaks [text] at [speed] times a natural speaking pace (1.0 = natural on
/// every platform: device voices count 0.5 as normal on Android/iOS but 1.0 on
/// the web) and completes when it has finished — so callers can read a story
/// sentence by sentence. A recorded clip is used when there is one, played at
/// the same speed. Never takes longer than a generous estimate, in case a
/// voice never reports that it finished.
Future<void> speakHindiPaced(String text, {double speed = 0.8}) async {
  if (SpeechService.muted || text.trim().isEmpty) return;
  final estimate = Duration(milliseconds: (600 + text.runes.length * 110 / speed.clamp(0.3, 2.0)).round());
  Future<void> run() async {
    final id = AppData.audioTextToId[text];
    if (id != null && AppData.audioIds.contains(id) && voiceLetterId(id) == null) {
      try {
        final p = SpeechService._player;
        await p.stop();
        final done = p.onPlayerComplete.first;
        await p.setPlaybackRate(speed.clamp(0.5, 2.0));
        await p.play(AssetSource('audio/$id.mp3'));
        await done;
        await p.setPlaybackRate(1.0);
        return;
      } catch (_) {}
    }
    try {
      await SpeechService.init();
      final tts = SpeechService._tts;
      await tts.awaitSpeakCompletion(true);
      await tts.setLanguage('hi-IN');
      await tts.setSpeechRate((kIsWeb ? 1.0 : 0.5) * speed);
      try {
        await tts.speak(text);
      } finally {
        await tts.awaitSpeakCompletion(false); // the rest of the app speaks fire-and-forget
      }
    } catch (_) {}
  }
  await run().timeout(estimate * 2, onTimeout: () {});
}

Future<void> stopSpeaking() async {
  try { await SpeechService._tts.stop(); } catch (_) {}
  try { await SpeechService._player.stop(); } catch (_) {}
}

/// Direct device-TTS speak (expo-speech `Speech.speak` equivalent), skipping bundled audio.
Future<void> speakDevice(String text, {String lang = 'hi-IN', double rate = 0.8}) =>
    SpeechService._tts_(text, lang, rate * 0.75);
