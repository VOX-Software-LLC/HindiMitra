import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/reading_data.dart';
import '../../services/speech_recognition_service.dart';
import '../../services/speech_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../../widgets/common.dart';
import '../../widgets/quiz_common.dart';
import '../../util/num_ext.dart';

enum _Coach { idle, listening, evaluating, result }

/// PronunciationCoachScreen.tsx — real on-device speech recognition scoring
/// (speech_to_text), no network call / API key.
class PronunciationCoachScreen extends StatefulWidget {
  final Map<String, dynamic> params;
  const PronunciationCoachScreen({super.key, this.params = const {}});
  @override
  State<PronunciationCoachScreen> createState() => _PronunciationCoachScreenState();
}

class _PronunciationCoachScreenState extends State<PronunciationCoachScreen> with SingleTickerProviderStateMixin {
  int idx = 0, attempts = 0, totalScore = 0;
  _Coach state = _Coach.idle;
  PronunciationResult? result;
  String? error;
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));

  Map get item => practiceItemsData[idx.clampI(0, practiceItemsData.length - 1)] as Map;

  @override
  void dispose() { SpeechRecognitionService.cancel(); _pulse.dispose(); super.dispose(); }

  Future<void> _start() async {
    setState(() { state = _Coach.listening; error = null; });
    _pulse.repeat();
    final target = item['hindi'] as String;
    final res = await SpeechRecognitionService.listenAndScore(targetHindi: target);
    if (!mounted) return;
    _pulse.stop(); _pulse.value = 0;
    if (res == null) {
      setState(() {
        state = _Coach.idle;
        error = 'Microphone unavailable. Check mic permission and try again.';
      });
      return;
    }
    setState(() => state = _Coach.evaluating);
    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    setState(() { result = res; totalScore += res.score; attempts++; state = _Coach.result; });
  }

  Color _sc(int s) => s >= 90 ? AppColors.success : s >= 70 ? AppColors.primaryDark : AppColors.error;
  String _label(int s) => s >= 90 ? 'Excellent!' : s >= 80 ? 'Great!' : s >= 70 ? 'Good' : 'Keep Practicing';
  String _emoji(int s) => s >= 90 ? '🌟' : s >= 80 ? '👍' : s >= 70 ? '👌' : '💪';

  @override
  Widget build(BuildContext context) {
    final it = item;
    final isWord = it['type'] == 'word';
    return ScreenScaffold(child: Column(children: [
      HeaderBar(
        title: 'Pronunciation Coach', subtitle: 'उच्चारण कोच', onBack: () => Navigator.of(context).maybePop(),
        rightAction: attempts > 0 ? Container(
          padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: 4),
          decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.13), borderRadius: BorderRadius.circular(9999),
              border: Border.all(color: AppColors.primary.withOpacity(0.33))),
          child: Text('Avg: ${(totalScore / attempts).round()}%', style: Fonts.body(12, w: FontWeight.w800, color: AppColors.primaryDark)),
        ) : null,
      ),
      Expanded(child: screenScroll(
        padding: const EdgeInsets.all(Sp.md),
        child: Column(children: [
          Padding(padding: const EdgeInsets.only(bottom: Sp.lg), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (int i = 0; i < practiceItemsData.length; i++) Container(
              margin: const EdgeInsets.symmetric(horizontal: 2), height: 8, width: i == idx ? 20 : 8,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(4),
                  color: i == idx ? AppColors.primary : i < idx ? AppColors.success : AppColors.border),
            ),
          ])),
          Container(
            key: ValueKey(idx), width: double.infinity, padding: const EdgeInsets.all(Sp.xl), margin: const EdgeInsets.only(bottom: Sp.lg),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(Rad.xl),
                border: Border.all(color: AppColors.border), boxShadow: toyShadow(AppColors.toyShadowColor, 4)),
            child: Column(children: [
              Container(
                margin: const EdgeInsets.only(bottom: Sp.md), padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: 2),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(9999),
                    color: (isWord ? AppColors.primary : AppColors.readingModule).withOpacity(0.13)),
                child: Text((it['type'] as String)[0].toUpperCase() + (it['type'] as String).substring(1),
                    style: Fonts.body(10, w: FontWeight.w800, color: AppColors.textPrimary).copyWith(letterSpacing: 0.5)),
              ),
              Text(it['hindi'], style: Fonts.hindi(64, color: AppColors.textPrimary, height: 76 / 64)),
              const SizedBox(height: Sp.xs),
              Text(it['romanized'], style: Fonts.display(20, color: AppColors.primaryDark, w: FontWeight.w700)),
              const SizedBox(height: Sp.xs),
              Text('"${it['pronunciation']}"', textAlign: TextAlign.center, style: Fonts.body(16, color: AppColors.textSecondary)),
              const SizedBox(height: Sp.md),
              GestureDetector(
                onTap: () => speakHindi(it['hindi'], rate: 0.6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: Sp.lg, vertical: Sp.sm),
                  decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.09), borderRadius: BorderRadius.circular(9999),
                      border: Border.all(color: AppColors.primary.withOpacity(0.33))),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.volume_up, size: 20, color: AppColors.primary), const SizedBox(width: Sp.sm),
                    Text('Listen First', style: Fonts.body(14, w: FontWeight.w800, color: AppColors.primaryDark)),
                  ]),
                ),
              ),
            ]),
          ),
          ConstrainedBox(constraints: const BoxConstraints(minHeight: 250), child: Center(child: _area(it))),
          Container(
            margin: const EdgeInsets.only(top: Sp.lg), padding: const EdgeInsets.all(Sp.md),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(Rad.xl),
                border: Border.all(color: AppColors.border), boxShadow: toyShadow(AppColors.toyShadowColor, 3)),
            child: Row(children: [
              const Icon(Icons.info_outline, size: 18, color: AppColors.primary), const SizedBox(width: Sp.sm),
              Expanded(child: Text('Live on-device speech recognition — speak clearly in a quiet room for the best score.',
                  style: Fonts.body(12, color: AppColors.textSecondary, height: 18 / 12))),
            ]),
          ),
          const SizedBox(height: Sp.xxl * 2),
        ]),
      )),
    ]));
  }

  Widget _area(Map it) {
    switch (state) {
      case _Coach.idle:
        return Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Tap the microphone and say:', style: Fonts.body(16, color: AppColors.textSecondary)),
          const SizedBox(height: Sp.xs),
          Text(it['hindi'], style: Fonts.hindi(32, color: AppColors.primaryDark, height: 44 / 32)),
          const SizedBox(height: Sp.lg),
          GestureDetector(
            onTap: _start,
            child: Container(width: 88, height: 88,
                decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle, boxShadow: toyShadow(AppColors.primaryDark, 6)),
                child: const Icon(Icons.mic, size: 36, color: AppColors.textOnPrimary)),
          ),
          const SizedBox(height: Sp.md),
          Text('Tap to start speaking', style: Fonts.body(12, color: AppColors.textMuted)),
          if (error != null) ...[
            const SizedBox(height: Sp.md),
            Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.error_outline, size: 16, color: AppColors.error), const SizedBox(width: 4),
              Flexible(child: Text(error!, textAlign: TextAlign.center, style: Fonts.body(12, color: AppColors.error))),
            ]),
          ],
        ]);
      case _Coach.listening:
        return Column(mainAxisSize: MainAxisSize.min, children: [
          RepaintBoundary(child: AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) {
              final t = _pulse.value < 0.5 ? _pulse.value * 2 : (1 - _pulse.value) * 2;
              return Transform.scale(scale: 1 + 0.2 * Curves.easeInOut.transform(t), child: Container(
                width: 88, height: 88,
                decoration: BoxDecoration(color: AppColors.error, shape: BoxShape.circle, boxShadow: toyShadow(const Color(0xFFA32E1E), 6)),
                child: const Icon(Icons.mic, size: 36, color: AppColors.textOnPrimary)));
            },
          )),
          const SizedBox(height: Sp.md),
          Text('Listening...', style: Fonts.body(16, w: FontWeight.w800, color: AppColors.error)),
          const SizedBox(height: Sp.xs),
          Text('Say "${it['hindi']}" clearly', style: Fonts.body(12, color: AppColors.textMuted)),
        ]);
      case _Coach.evaluating:
        return Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.hourglass_empty, size: 36, color: AppColors.primary),
          const SizedBox(height: Sp.md),
          Text('Analyzing pronunciation...', style: Fonts.body(16, color: AppColors.textSecondary)),
        ]);
      case _Coach.result:
        final r = result;
        final s = r?.score ?? 0;
        Widget bar(String label, double pct) => Padding(padding: const EdgeInsets.only(bottom: Sp.sm), child: Row(children: [
              SizedBox(width: 56, child: Text(label, style: Fonts.body(12, w: FontWeight.w700, color: AppColors.textSecondary))),
              const SizedBox(width: Sp.md),
              Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(9999), child: Container(
                  height: 10, color: AppColors.border, alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(widthFactor: (pct / 100).clampD(0.0, 1.0), child: Container(
                      decoration: BoxDecoration(color: _sc(s), borderRadius: BorderRadius.circular(9999))))))),
            ]));
        return Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_emoji(s), style: const TextStyle(fontSize: 48)),
          const SizedBox(height: Sp.sm),
          Text('$s%', style: Fonts.display(48, color: _sc(s), height: 56 / 48)),
          Text(_label(s), style: Fonts.body(18, w: FontWeight.w800, color: _sc(s))),
          const SizedBox(height: Sp.sm),
          Text(
            r == null || r.recognizedText.isEmpty ? 'I heard: (nothing detected)' : 'I heard: "${r.recognizedText}"',
            textAlign: TextAlign.center, style: Fonts.body(13, color: AppColors.textSecondary),
          ),
          if (r?.usedFallbackLocale == true) Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('No Hindi voice model on this device — results may be less accurate.',
                textAlign: TextAlign.center, style: Fonts.body(11, color: AppColors.textMuted)),
          ),
          const SizedBox(height: Sp.lg),
          bar('Accuracy', (r?.similarity ?? 0) * 100),
          bar('Clarity', (r?.confidence ?? 0) * 100),
          bar('Timing', (r?.timing ?? 0) * 100),
          const SizedBox(height: Sp.md),
          Row(children: [
            Expanded(child: GestureDetector(
              onTap: () => setState(() { state = _Coach.idle; result = null; }),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: Sp.md),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(9999), border: Border.all(color: AppColors.primary, width: 2)),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.refresh, size: 18, color: AppColors.primary), const SizedBox(width: Sp.xs),
                  Text('Try Again', style: Fonts.body(16, w: FontWeight.w800, color: AppColors.primary)),
                ]),
              ),
            )),
            const SizedBox(width: Sp.md),
            Expanded(child: GestureDetector(
              onTap: () => setState(() {
                idx = idx < practiceItemsData.length - 1 ? idx + 1 : 0;
                state = _Coach.idle; result = null;
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: Sp.md),
                decoration: BoxDecoration(gradient: toneGradient(AppColors.primary), borderRadius: BorderRadius.circular(9999), boxShadow: toyShadow(AppColors.primaryDark, 6)),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('Next', style: Fonts.body(16, w: FontWeight.w800, color: AppColors.textOnPrimary)), const SizedBox(width: Sp.xs),
                  const Icon(Icons.arrow_forward, size: 18, color: AppColors.textOnPrimary),
                ]),
              ),
            )),
          ]),
        ]);
    }
  }
}
