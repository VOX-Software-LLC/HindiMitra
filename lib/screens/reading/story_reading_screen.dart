import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/reading_data.dart';
import '../../services/speech_service.dart';
import '../../store/app_store.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../../widgets/common.dart';
import '../../widgets/quiz_common.dart';

class _WA {
  final Color bg, fg, border;
  const _WA(this.bg, this.fg, this.border);
}

final _wordAccents = [
  _WA(Palette.light.purple.withOpacity(0.10), Palette.light.purple, Palette.light.purple),
  _WA(Palette.light.green.withOpacity(0.10), Palette.light.green, Palette.light.green),
  _WA(Palette.light.sky.withOpacity(0.10), Palette.light.sky, Palette.light.sky),
  _WA(Palette.light.pink.withOpacity(0.10), Palette.light.pink, Palette.light.pink),
  _WA(Palette.light.sunny.withOpacity(0.20), Palette.light.sunnyForeground, Palette.light.sunny),
];

/// StoryReadingScreen.tsx — tap words for meaning, play sentences, take a quiz.
class StoryReadingScreen extends StatefulWidget {
  final Map<String, dynamic> params;
  const StoryReadingScreen({super.key, this.params = const {}});
  @override
  State<StoryReadingScreen> createState() => _StoryReadingScreenState();
}

class _StoryReadingScreenState extends State<StoryReadingScreen> {
  int? storyIdx;
  ({int s, int w})? tapped;
  bool showQuiz = false, showFeedback = false;
  int qIdx = 0, score = 0;
  int? selected;
  double rate = 1.0;
  Timer? _t;

  @override
  void dispose() { _t?.cancel(); super.dispose(); }

  Map get story => storiesData[storyIdx!] as Map;
  List get questions => story['questions'] as List;

  void _resetQuiz() {
    showQuiz = false; qIdx = 0; selected = null; showFeedback = false; score = 0;
  }

  @override
  Widget build(BuildContext context) {
    if (storyIdx == null) return _list();
    final qs = questions;
    if (showQuiz && qIdx == qs.length) return _quizResult(qs.length);
    if (showQuiz && qIdx < qs.length) return _quiz(qs[qIdx] as Map, qs.length);
    return _reading();
  }

  Widget _list() {
    final tints = [Palette.light.purple, Palette.light.green, Palette.light.pink];
    return ScreenScaffold(child: Column(children: [
      HeaderBar(title: 'Story Reading', subtitle: 'कहानी पढ़ना', onBack: () => Navigator.of(context).maybePop()),
      Expanded(child: screenScroll(
        padding: const EdgeInsets.all(Sp.md),
        child: Column(children: [
          Padding(padding: const EdgeInsets.only(bottom: Sp.lg), child: Text(
              'Read simple stories in Hindi. Tap any word to hear it and see its meaning.',
              textAlign: TextAlign.center, style: Fonts.body(16, color: AppColors.textSecondary))),
          for (int i = 0; i < storiesData.length; i++) Padding(
            padding: const EdgeInsets.only(bottom: Sp.md),
            child: GestureDetector(
              onTap: () => setState(() => storyIdx = i),
              child: Container(
                padding: const EdgeInsets.all(Sp.md),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(Rad.xl),
                    border: Border.all(color: AppColors.border), boxShadow: toyShadow(AppColors.toyShadowColor, 4)),
                child: Row(children: [
                  Container(width: 52, height: 52, decoration: BoxDecoration(color: tints[i % 3].withOpacity(0.10), borderRadius: BorderRadius.circular(Rad.lg)),
                      child: Icon(Icons.menu_book_outlined, size: 24, color: tints[i % 3])),
                  const SizedBox(width: Sp.md),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(storiesData[i]['title'], style: Fonts.display(16, w: FontWeight.w700)),
                    Text(storiesData[i]['hindiTitle'], style: Fonts.hindi(13, color: AppColors.textSecondary)),
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      padding: const EdgeInsets.symmetric(horizontal: Sp.sm, vertical: 2),
                      decoration: BoxDecoration(
                          color: storiesData[i]['difficulty'] == 'beginner' ? AppColors.success.withOpacity(0.125) : Palette.light.sunny.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(9999)),
                      child: Text(_cap(storiesData[i]['difficulty']), style: Fonts.body(10, w: FontWeight.w700, color: AppColors.textPrimary)),
                    ),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('${(storiesData[i]['sentences'] as List).length} sentences', style: Fonts.body(12, color: AppColors.textMuted)),
                    const SizedBox(height: Sp.xs),
                    const Icon(Icons.chevron_right, size: 20, color: AppColors.textMuted),
                  ]),
                ]),
              ),
            ),
          ),
          const SizedBox(height: Sp.xxl),
        ]),
      )),
    ]));
  }

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  Widget _reading() {
    final sentences = story['sentences'] as List;
    return ScreenScaffold(child: Column(children: [
      HeaderBar(title: story['title'], subtitle: story['hindiTitle'], onBack: () => setState(() => storyIdx = null)),
      Expanded(child: screenScroll(
        padding: const EdgeInsets.all(Sp.md),
        child: Column(children: [
          Container(
            margin: const EdgeInsets.only(bottom: Sp.md), padding: const EdgeInsets.all(Sp.md),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(Rad.xl),
                border: Border.all(color: AppColors.border), boxShadow: toyShadow(AppColors.toyShadowColor, 4)),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Speech Speed:', style: Fonts.body(14, w: FontWeight.w700, color: AppColors.textPrimary)),
              Row(children: [
                for (final r in const [0.5, 1.0, 1.5]) Padding(
                  padding: const EdgeInsets.only(left: Sp.sm),
                  child: GestureDetector(
                    onTap: () => setState(() => rate = r),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.sm),
                      decoration: BoxDecoration(
                        color: rate == r ? AppColors.primary : AppColors.surface, borderRadius: BorderRadius.circular(9999),
                        border: Border.all(color: rate == r ? AppColors.primary : AppColors.border),
                        boxShadow: rate == r ? toyShadow(AppColors.primaryDark, 4) : null),
                      child: Text('${r == 1.0 ? '1' : r}x', style: Fonts.body(12, w: rate == r ? FontWeight.w800 : FontWeight.w700,
                          color: rate == r ? AppColors.textOnPrimary : AppColors.textSecondary)),
                    ),
                  ),
                ),
              ]),
            ]),
          ),
          for (int si = 0; si < sentences.length; si++) _sentenceCard(si, sentences[si] as Map),
          GestureDetector(
            onTap: () => speakHindi(sentences.map((s) => s['fullHindi']).join('। '), rate: rate),
            child: Container(
              margin: const EdgeInsets.only(top: Sp.md), padding: const EdgeInsets.symmetric(vertical: Sp.md, horizontal: Sp.lg),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(9999), border: Border.all(color: AppColors.primary, width: 2)),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.headset_outlined, size: 20, color: AppColors.primary), const SizedBox(width: Sp.sm),
                Text('Listen to full story', style: Fonts.body(14, w: FontWeight.w700, color: AppColors.primary)),
              ]),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() { showQuiz = true; qIdx = 0; selected = null; showFeedback = false; score = 0; }),
            child: Container(
              margin: const EdgeInsets.only(top: Sp.md), padding: const EdgeInsets.symmetric(vertical: Sp.md, horizontal: Sp.lg),
              decoration: BoxDecoration(gradient: toneGradient(AppColors.primary), borderRadius: BorderRadius.circular(9999), boxShadow: toyShadow(AppColors.primaryDark, 6)),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.help_outline, size: 20, color: AppColors.surface), const SizedBox(width: Sp.sm),
                Text('Take Quiz', style: Fonts.body(14, w: FontWeight.w800, color: AppColors.textOnPrimary)),
              ]),
            ),
          ),
          const SizedBox(height: Sp.xxl * 2),
        ]),
      )),
    ]));
  }

  Widget _sentenceCard(int si, Map sentence) {
    final words = sentence['words'] as List;
    return Container(
      margin: const EdgeInsets.only(bottom: Sp.md), padding: const EdgeInsets.all(Sp.lg),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(Rad.xl2),
          border: Border.all(color: AppColors.border), boxShadow: softShadow(AppColors.primary)),
      child: Column(children: [
        Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.only(bottom: Sp.md), child: Wrap(spacing: Sp.sm, runSpacing: Sp.sm, children: [
          for (int wi = 0; wi < words.length; wi++) _word(si, wi, words[wi] as Map),
        ]))),
        Container(
          padding: const EdgeInsets.only(top: Sp.sm),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
          child: Row(children: [
            Expanded(child: Text(sentence['english'], style: Fonts.body(16, color: AppColors.textSecondary))),
            GestureDetector(
              onTap: () => speakHindi(sentence['fullHindi'], rate: rate),
              child: const Padding(padding: EdgeInsets.all(Sp.xs), child: Icon(Icons.play_circle_fill, size: 28, color: AppColors.primary)),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _word(int si, int wi, Map word) {
    final active = tapped != null && tapped!.s == si && tapped!.w == wi;
    final a = _wordAccents[(si + wi) % _wordAccents.length];
    return GestureDetector(
      onTap: () {
        setState(() => tapped = (s: si, w: wi));
        speakHindi(word['hindi'], rate: rate);
        _t?.cancel();
        _t = Timer(const Duration(milliseconds: 1500), () { if (mounted) setState(() => tapped = null); });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Sp.sm, vertical: Sp.xs),
        decoration: BoxDecoration(color: active ? a.bg : AppColors.background, borderRadius: BorderRadius.circular(Rad.md),
            border: Border.all(color: active ? a.border : Colors.transparent, width: 1.5)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(word['hindi'], style: Fonts.hindi(24, color: active ? a.fg : AppColors.textPrimary, height: 32 / 24)),
          if (active) Text(word['meaning'], style: Fonts.body(10, w: FontWeight.w700, color: a.fg)),
        ]),
      ),
    );
  }

  Widget _quiz(Map q, int n) {
    final answered = selected != null;
    final correct = selected == q['correctIndex'];
    final options = q['options'] as List;
    return ScreenScaffold(child: Column(children: [
      HeaderBar(title: 'Quiz', subtitle: 'प्रश्न ${qIdx + 1}/$n', onBack: () => setState(() => storyIdx = null)),
      Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(Sp.md), child: Container(
        padding: const EdgeInsets.all(Sp.lg),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(Rad.xl2),
            border: Border.all(color: AppColors.border), boxShadow: softShadow(AppColors.primary)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(bottom: Sp.lg), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(q['question'], style: Fonts.hindi(20, color: AppColors.textPrimary, height: 28 / 20)),
            const SizedBox(height: Sp.sm),
            Text(q['questionEn'], style: Fonts.body(16, color: AppColors.textSecondary).copyWith(fontStyle: FontStyle.italic)),
          ])),
          for (int i = 0; i < options.length; i++) Padding(padding: const EdgeInsets.only(bottom: Sp.md), child: _qOption(i, options[i], answered, q['correctIndex'] as int)),
          if (answered) Container(
            width: double.infinity, margin: const EdgeInsets.only(bottom: Sp.md), padding: const EdgeInsets.all(Sp.md),
            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(Rad.lg)),
            child: Text(correct ? 'सही! (Correct!)' : 'गलत (Incorrect)', textAlign: TextAlign.center,
                style: Fonts.body(16, w: FontWeight.w700, color: correct ? AppColors.success : AppColors.error)),
          ),
          if (answered) GestureDetector(
            onTap: () {
              setState(() {
                if (qIdx < n - 1) { qIdx++; selected = null; showFeedback = false; }
                else { qIdx = n; }
              });
              final aId = widget.params['activityId'], lvl = widget.params['levelNumber'];
              if (qIdx == n && score * 2 >= n && aId is String && lvl is int) context.read<AppStore>().completeActivityLevel(aId, lvl);
            },
            child: Container(
              width: double.infinity, padding: const EdgeInsets.symmetric(vertical: Sp.md, horizontal: Sp.lg),
              decoration: BoxDecoration(gradient: toneGradient(AppColors.primary), borderRadius: BorderRadius.circular(9999), boxShadow: toyShadow(AppColors.primaryDark, 6)),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(qIdx == n - 1 ? 'See Results' : 'Next Question', style: Fonts.body(14, w: FontWeight.w800, color: AppColors.textOnPrimary)),
                const SizedBox(width: Sp.sm),
                const Icon(Icons.arrow_forward, size: 18, color: AppColors.surface),
              ]),
            ),
          ),
        ]),
      ))),
    ]));
  }

  Widget _qOption(int i, String text, bool answered, int correctIdx) {
    final isSel = selected == i;
    final asCorrect = answered && i == correctIdx;
    final asWrong = answered && isSel && selected != correctIdx;
    return GestureDetector(
      onTap: answered ? null : () => setState(() {
        selected = i; showFeedback = true;
        if (i == correctIdx) score++;
      }),
      child: Container(
        padding: const EdgeInsets.all(Sp.md),
        decoration: BoxDecoration(
          color: asCorrect ? AppColors.success.withOpacity(0.08) : asWrong ? AppColors.error.withOpacity(0.08) : AppColors.background,
          borderRadius: BorderRadius.circular(Rad.lg),
          border: Border.all(color: asCorrect ? AppColors.success : asWrong ? AppColors.error : AppColors.border, width: 2)),
        child: Row(children: [
          Container(width: 32, height: 32, alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, color: asCorrect ? AppColors.success : asWrong ? AppColors.error : AppColors.primary),
              child: Text(String.fromCharCode(65 + i), style: Fonts.body(14, w: FontWeight.w800, color: AppColors.textOnPrimary))),
          const SizedBox(width: Sp.md),
          Expanded(child: Text(text, style: Fonts.body(16, color: asCorrect ? AppColors.success : asWrong ? AppColors.error : AppColors.textPrimary))),
          if (asCorrect) const Icon(Icons.check_circle, size: 20, color: AppColors.success),
          if (asWrong) const Icon(Icons.cancel, size: 20, color: AppColors.error),
        ]),
      ),
    );
  }

  Widget _quizResult(int n) => ScreenScaffold(child: Column(children: [
        HeaderBar(title: story['title'], subtitle: story['hindiTitle'], onBack: () => setState(() => storyIdx = null)),
        Expanded(child: Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: Sp.lg), child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 160, height: 160, margin: const EdgeInsets.only(bottom: Sp.xl),
            decoration: BoxDecoration(color: AppColors.success.withOpacity(0.125), shape: BoxShape.circle,
                border: Border.all(color: AppColors.success.withOpacity(0.25), width: 2), boxShadow: softShadow(AppColors.success)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              Text('$score', style: Fonts.display(52, color: AppColors.success)),
              Text('/$n', style: Fonts.body(18, color: AppColors.textSecondary)),
            ]),
          ),
          Padding(padding: const EdgeInsets.only(bottom: Sp.sm), child: Text('Quiz Complete!', textAlign: TextAlign.center, style: Fonts.display(24))),
          Padding(padding: const EdgeInsets.only(bottom: Sp.xl), child: Text('आपका स्कोर: ${(score / n * 100).round()}%',
              textAlign: TextAlign.center, style: Fonts.body(16, color: AppColors.textSecondary))),
          GestureDetector(
            onTap: () => setState(_resetQuiz),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: Sp.lg, vertical: Sp.md),
              decoration: BoxDecoration(gradient: toneGradient(AppColors.primary), borderRadius: BorderRadius.circular(9999), boxShadow: toyShadow(AppColors.primaryDark, 6)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.arrow_back, size: 18, color: AppColors.surface), const SizedBox(width: Sp.sm),
                Text('Back to Stories', style: Fonts.body(14, w: FontWeight.w800, color: AppColors.textOnPrimary)),
              ]),
            ),
          ),
        ])))),
      ]));
}
