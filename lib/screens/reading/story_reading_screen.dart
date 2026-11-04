import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  Timer? _t;

  // ── Read-along ──
  /// Speed as a multiple of a natural speaking pace (1.0 = natural). Learners
  /// start a little slower; the choice is remembered.
  double speed = 0.75;
  static const _speeds = [(0.5, 'Very slow', '🐢'), (0.75, 'Slow', '🚶'), (0.9, 'Normal', '🙂'), (1.1, 'Fast', '🐇')];
  bool playing = false, paused = false, wordByWord = false, repeatEach = false, showEnglish = true;
  int? currentSentence, currentWord;
  int _run = 0; // bumped to cancel a read-along in progress
  final _sentenceKeys = <int, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      final v = p.getDouble('storySpeed');
      if (v != null && mounted) setState(() => speed = v);
    }).catchError((_) {});
  }

  @override
  void dispose() { _t?.cancel(); _run++; stopSpeaking(); super.dispose(); }

  void _setSpeed(double v) {
    setState(() => speed = v);
    SharedPreferences.getInstance().then((p) => p.setDouble('storySpeed', v)).catchError((_) => false);
  }

  List get _sentences => story['sentences'] as List;

  /// Reads the story from [from], sentence by sentence (or word by word),
  /// highlighting what is being read and scrolling it into view.
  Future<void> _readAlong([int from = 0]) async {
    final run = ++_run;
    await stopSpeaking();
    if (!mounted) return;
    setState(() { playing = true; paused = false; });
    for (int si = from; si < _sentences.length; si++) {
      if (run != _run || !mounted) return;
      final sentence = _sentences[si] as Map;
      setState(() { currentSentence = si; currentWord = null; });
      _scrollTo(si);
      for (int rep = 0; rep < (repeatEach ? 2 : 1); rep++) {
        if (wordByWord) {
          final words = sentence['words'] as List;
          for (int wi = 0; wi < words.length; wi++) {
            if (run != _run || !mounted) return;
            setState(() => currentWord = wi);
            await speakHindiPaced((words[wi] as Map)['hindi'], speed: speed);
            await Future.delayed(Duration(milliseconds: (350 / speed).round()));
          }
          if (run != _run || !mounted) return;
          setState(() => currentWord = null);
        } else {
          await speakHindiPaced(sentence['fullHindi'], speed: speed);
        }
        if (run != _run || !mounted) return;
        // A pause between sentences, longer at slower speeds.
        await Future.delayed(Duration(milliseconds: (800 / speed).round()));
      }
    }
    if (run == _run && mounted) setState(() { playing = false; currentSentence = null; currentWord = null; });
  }

  void _pause() {
    _run++;
    stopSpeaking();
    setState(() { playing = false; paused = true; });
  }

  void _stop() {
    _run++;
    stopSpeaking();
    setState(() { playing = false; paused = false; currentSentence = null; currentWord = null; });
  }

  void _jump(int delta) {
    final next = ((currentSentence ?? 0) + delta).clamp(0, _sentences.length - 1);
    _readAlong(next);
  }

  void _scrollTo(int si) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _sentenceKeys[si]?.currentContext;
      if (ctx != null && mounted) {
        Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic, alignment: 0.3);
      }
    });
  }

  /// One sentence (or word) read on its own at the chosen speed.
  void _sayOnce(String text) {
    _run++;
    setState(() { playing = false; });
    stopSpeaking().then((_) => speakHindiPaced(text, speed: speed));
  }

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
              onTap: () => setState(() { storyIdx = i; _sentenceKeys.clear(); currentSentence = null; paused = false; }),
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
                    Icon(Icons.chevron_right, size: 20, color: AppColors.textMuted),
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
    final sentences = _sentences;
    return ScreenScaffold(child: Column(children: [
      HeaderBar(title: story['title'], subtitle: story['hindiTitle'], onBack: () { _stop(); setState(() => storyIdx = null); }),
      Expanded(child: screenScroll(
        padding: const EdgeInsets.all(Sp.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _settingsCard(),
          for (int si = 0; si < sentences.length; si++) _sentenceCard(si, sentences[si] as Map),
          GestureDetector(
            onTap: () { _stop(); setState(() { showQuiz = true; qIdx = 0; selected = null; showFeedback = false; score = 0; }); },
            child: Container(
              margin: const EdgeInsets.only(top: Sp.md), padding: const EdgeInsets.symmetric(vertical: Sp.md, horizontal: Sp.lg),
              decoration: BoxDecoration(gradient: toneGradient(AppColors.primary), borderRadius: BorderRadius.circular(9999), boxShadow: toyShadow(AppColors.primaryDark, 6)),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.help_outline, size: 20, color: AppColors.surface), const SizedBox(width: Sp.sm),
                Text('Take Quiz', style: Fonts.body(14, w: FontWeight.w800, color: AppColors.textOnPrimary)),
              ]),
            ),
          ),
          const SizedBox(height: Sp.xl),
        ]),
      )),
      _playerBar(sentences.length),
    ]));
  }

  /// Speed presets and reading options.
  Widget _settingsCard() => Container(
        margin: const EdgeInsets.only(bottom: Sp.md), padding: const EdgeInsets.all(Sp.md),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(Rad.xl),
            border: Border.all(color: AppColors.border), boxShadow: toyShadow(AppColors.toyShadowColor, 4)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.speed_rounded, size: 18, color: AppColors.textSecondary), const SizedBox(width: 6),
            Flexible(child: Text('Voice speed · आवाज़ की गति', style: Fonts.body(14, w: FontWeight.w800, color: AppColors.textPrimary))),
          ]),
          const SizedBox(height: Sp.sm),
          Row(children: [
            for (final (v, label, icon) in _speeds) Expanded(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: GestureDetector(
                onTap: () => _setSpeed(v),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: Sp.sm),
                  decoration: BoxDecoration(
                    color: speed == v ? AppColors.primary : AppColors.background, borderRadius: BorderRadius.circular(Rad.md),
                    border: Border.all(color: speed == v ? AppColors.primary : AppColors.border),
                    boxShadow: speed == v ? toyShadow(AppColors.primaryDark, 3) : null),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(icon, style: const TextStyle(fontSize: 18)),
                    Text(label, textAlign: TextAlign.center, style: Fonts.body(11.5, w: FontWeight.w800,
                        color: speed == v ? AppColors.textOnPrimary : AppColors.textSecondary)),
                  ]),
                ),
              ),
            )),
          ]),
          const SizedBox(height: Sp.sm),
          Wrap(spacing: Sp.sm, runSpacing: Sp.sm, children: [
            _toggle('Word by word', Icons.short_text_rounded, wordByWord, (v) => setState(() => wordByWord = v)),
            _toggle('Repeat each sentence', Icons.repeat_rounded, repeatEach, (v) => setState(() => repeatEach = v)),
            _toggle('Show English', Icons.translate_rounded, showEnglish, (v) => setState(() => showEnglish = v)),
          ]),
        ]),
      );

  Widget _toggle(String label, IconData icon, bool on, ValueChanged<bool> set) => GestureDetector(
        onTap: () => set(!on),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: 7),
          decoration: BoxDecoration(
            color: on ? AppColors.primary.withOpacity(0.12) : AppColors.background,
            borderRadius: BorderRadius.circular(9999),
            border: Border.all(color: on ? AppColors.primary : AppColors.border, width: 1.5)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(on ? Icons.check_circle_rounded : icon, size: 16, color: on ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(label, style: Fonts.body(12.5, w: FontWeight.w800, color: on ? AppColors.primaryDark : AppColors.textSecondary)),
          ]),
        ),
      );

  /// Sticky play / pause / previous / next / stop bar.
  Widget _playerBar(int n) {
    final cur = currentSentence;
    return Container(
      padding: const EdgeInsets.fromLTRB(Sp.md, Sp.sm, Sp.md, Sp.md),
      decoration: BoxDecoration(color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, -4))]),
      child: SafeArea(top: false, child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(playing ? 'Reading…' : paused ? 'Paused' : 'Read the story to me',
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: Fonts.body(14, w: FontWeight.w800, color: AppColors.textPrimary)),
          Text(cur == null ? '$n sentences' : 'Sentence ${cur + 1} of $n',
              style: Fonts.body(12, w: FontWeight.w600, color: AppColors.textSecondary)),
        ])),
        _round(Icons.skip_previous_rounded, cur == null || cur == 0 ? null : () => _jump(-1), 'Previous sentence'),
        const SizedBox(width: 6),
        _round(playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
            playing ? _pause : () => _readAlong(paused ? (cur ?? 0) : 0), playing ? 'Pause' : 'Play', big: true),
        const SizedBox(width: 6),
        _round(Icons.skip_next_rounded, cur == null || cur >= n - 1 ? null : () => _jump(1), 'Next sentence'),
        const SizedBox(width: 6),
        _round(Icons.stop_rounded, playing || paused ? _stop : null, 'Stop'),
      ])),
    );
  }

  Widget _round(IconData icon, VoidCallback? onTap, String tip, {bool big = false}) {
    final size = big ? 54.0 : 40.0;
    final enabled = onTap != null;
    return Tooltip(message: tip, child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(
          gradient: big && enabled ? toneGradient(AppColors.primary) : null,
          color: big ? (enabled ? null : AppColors.border) : AppColors.background, shape: BoxShape.circle,
          border: big ? null : Border.all(color: enabled ? AppColors.primary : AppColors.border, width: 1.5),
          boxShadow: big && enabled ? toyShadow(AppColors.primaryDark, 4) : null),
        child: Icon(icon, size: big ? 32 : 22,
            color: big ? AppColors.textOnPrimary : enabled ? AppColors.primary : AppColors.textMuted),
      ),
    ));
  }

  Widget _sentenceCard(int si, Map sentence) {
    final words = sentence['words'] as List;
    final current = currentSentence == si;
    return AnimatedContainer(
      key: _sentenceKeys.putIfAbsent(si, GlobalKey.new),
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: Sp.md), padding: const EdgeInsets.all(Sp.lg),
      decoration: BoxDecoration(
          color: current ? AppColors.primary.withOpacity(0.07) : AppColors.surface,
          borderRadius: BorderRadius.circular(Rad.xl2),
          border: Border.all(color: current ? AppColors.primary : AppColors.border, width: current ? 2 : 1),
          boxShadow: softShadow(AppColors.primary)),
      child: Column(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 26, height: 26, margin: const EdgeInsets.only(right: Sp.sm, top: 4), alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle,
                color: current ? AppColors.primary : AppColors.background, border: Border.all(color: AppColors.border)),
            child: Text('${si + 1}', style: Fonts.body(12, w: FontWeight.w800,
                color: current ? AppColors.textOnPrimary : AppColors.textSecondary)),
          ),
          Expanded(child: Padding(padding: const EdgeInsets.only(bottom: Sp.md), child: Wrap(spacing: Sp.sm, runSpacing: Sp.sm, children: [
            for (int wi = 0; wi < words.length; wi++) _word(si, wi, words[wi] as Map),
          ]))),
        ]),
        Container(
          padding: const EdgeInsets.only(top: Sp.sm),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
          child: Row(children: [
            Expanded(child: showEnglish
                ? Text(sentence['english'], style: Fonts.body(16, color: AppColors.textSecondary))
                : GestureDetector(
                    onTap: () => showInfoDialog(context, 'Meaning', sentence['english']),
                    child: Row(children: [
                      Icon(Icons.visibility_outlined, size: 18, color: AppColors.textMuted), const SizedBox(width: 6),
                      Flexible(child: Text('Tap to check the meaning', style: Fonts.body(13, w: FontWeight.w700, color: AppColors.textMuted))),
                    ]),
                  )),
            Tooltip(message: 'Read from here', child: GestureDetector(
              onTap: () => _readAlong(si),
              child: Padding(padding: const EdgeInsets.all(Sp.xs), child: Icon(Icons.playlist_play_rounded, size: 28, color: AppColors.textSecondary)),
            )),
            Tooltip(message: 'Hear this sentence', child: GestureDetector(
              onTap: () { setState(() => currentSentence = si); _sayOnce(sentence['fullHindi']); },
              child: Padding(padding: const EdgeInsets.all(Sp.xs), child: Icon(Icons.play_circle_fill, size: 28, color: AppColors.primary)),
            )),
          ]),
        ),
      ]),
    );
  }

  Widget _word(int si, int wi, Map word) {
    final reading = currentSentence == si && currentWord == wi;
    final active = reading || (tapped != null && tapped!.s == si && tapped!.w == wi);
    final a = _wordAccents[(si + wi) % _wordAccents.length];
    return GestureDetector(
      onTap: () {
        setState(() => tapped = (s: si, w: wi));
        _sayOnce(word['hindi']);
        _t?.cancel();
        _t = Timer(const Duration(milliseconds: 1800), () { if (mounted) setState(() => tapped = null); });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
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
                Icon(Icons.arrow_forward, size: 18, color: AppColors.surface),
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
                Icon(Icons.arrow_back, size: 18, color: AppColors.surface), const SizedBox(width: Sp.sm),
                Text('Back to Stories', style: Fonts.body(14, w: FontWeight.w800, color: AppColors.textOnPrimary)),
              ]),
            ),
          ),
        ])))),
      ]));
}
