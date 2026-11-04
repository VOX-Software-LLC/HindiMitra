import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/reading_data.dart';
import '../../services/feedback.dart';
import '../../services/speech_service.dart';
import '../../store/app_store.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../../widgets/common.dart';
import '../../widgets/icons.dart';
import '../../widgets/progress_bar.dart';
import '../../widgets/quiz_common.dart';
import '../../util/num_ext.dart';
import '../../util/transliterate.dart';

class _MQ {
  final String hindiWord; final List<String> options; final int correctIndex;
  _MQ(this.hindiWord, this.options, this.correctIndex);
}

List<_MQ> _generateQuiz(Map category) {
  final words = (category['words'] as List).cast<Map>();
  return words.take(4).map((word) {
    final wrong = shuffled<Map>(words.where((w) => !identical(w, word)))
        .take(3).map((w) => w['english'] as String).toList();
    final all = shuffled<String>([word['english'] as String, ...wrong]);
    return _MQ(word['hindi'], all, all.indexOf(word['english'] as String));
  }).toList();
}

enum _S { categories, learn, quiz }

/// VocabCategoryScreen.tsx
class VocabCategoryScreen extends StatefulWidget {
  final Map<String, dynamic> params;
  const VocabCategoryScreen({super.key, this.params = const {}});
  @override
  State<VocabCategoryScreen> createState() => _VocabCategoryScreenState();
}

class _VocabCategoryScreenState extends State<VocabCategoryScreen> {
  _S state = _S.categories;
  Map? category;
  int wordIndex = 0;
  String? playing;
  bool flipped = false;
  List<_MQ> questions = [];
  int quizIndex = 0, quizScore = 0;
  int? selectedAnswer;
  Timer? _pt;

  @override
  void dispose() { _pt?.cancel(); super.dispose(); }

  List<Map> get _words => (category!['words'] as List).cast<Map>();
  Color get _cc => hexColor(category!['color'] as String);

  void _play(String w) {
    setState(() => playing = w);
    speakHindi(w, rate: 0.6);
    _pt?.cancel();
    _pt = Timer(const Duration(milliseconds: 1500), () { if (mounted) setState(() => playing = null); });
  }

  void _startQuiz() => setState(() {
        questions = _generateQuiz(category!);
        quizIndex = 0; selectedAnswer = null; quizScore = 0; state = _S.quiz;
      });

  void _answer(int opt) {
    if (selectedAnswer != null) return;
    final correct = opt == questions[quizIndex].correctIndex;
    final idxAtTap = quizIndex, scoreAtTap = quizScore;
    setState(() { selectedAnswer = opt; if (correct) quizScore++; });
    correct ? hapticSuccess() : hapticError();
    Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      if (idxAtTap < questions.length - 1) {
        setState(() { quizIndex = idxAtTap + 1; selectedAnswer = null; });
      } else {
        final store = context.read<AppStore>(), finalScore = scoreAtTap + (correct ? 1 : 0);
        store.addPoints(finalScore * 20);
        final aId = widget.params['activityId'], lvl = widget.params['levelNumber'];
        if (finalScore * 2 >= questions.length && aId is String && lvl is int) store.completeActivityLevel(aId, lvl);
        setState(() { state = _S.learn; wordIndex = 0; });
      }
    });
  }

  Color _bg(int i, int c) {
    if (selectedAnswer == null) return AppColors.surface;
    if (selectedAnswer == i) return i == c ? AppColors.success : AppColors.error;
    if (i == c) return AppColors.success.withAlpha(0x30);
    return AppColors.surface;
  }

  Color _border(int i, int c) {
    if (selectedAnswer == null) return AppColors.border;
    if (selectedAnswer == i) return i == c ? AppColors.success : AppColors.error;
    if (i == c) return AppColors.success;
    return AppColors.border;
  }

  Color _text(int i) {
    if (selectedAnswer == null) return AppColors.textPrimary;
    if (selectedAnswer == i) return AppColors.textOnPrimary;
    return AppColors.textSecondary;
  }

  @override
  Widget build(BuildContext context) {
    if (state == _S.categories) return _categories();
    if (state == _S.learn && category != null) return _learn();
    if (state == _S.quiz && category != null && questions.isNotEmpty) return _quiz();
    return const SizedBox.shrink();
  }

  Widget _categories() => ScreenScaffold(child: Column(children: [
        HeaderBar(title: 'Vocabulary', subtitle: 'शब्दावली', onBack: () => Navigator.of(context).maybePop()),
        Expanded(child: screenScroll(
          padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.lg),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.only(bottom: Sp.lg),
                child: Text('Choose a Topic', style: Fonts.display(24, color: AppColors.textPrimary, w: FontWeight.w800))),
            LayoutBuilder(builder: (context, c) {
              // Two topic cards per row on phones, three on wider screens.
              final cols = c.maxWidth >= 640 ? 3 : 2;
              final cardW = (c.maxWidth - Sp.md * (cols - 1)) / cols;
              return Wrap(spacing: Sp.md, runSpacing: Sp.md, children: [
                for (final cat in vocabCategoriesData.cast<Map>()) _catCard(cat, cardW),
              ]);
            }),
            const SizedBox(height: Sp.xl),
          ]),
        )),
      ]));

  Widget _catCard(Map cat, double w) {
    final color = hexColor(cat['color'] as String);
    return GestureDetector(
      onTap: () => setState(() { category = cat; state = _S.learn; wordIndex = 0; flipped = false; }),
      child: Container(
        width: w,
        padding: const EdgeInsets.symmetric(vertical: Sp.lg),
        decoration: BoxDecoration(color: color.withAlpha(0x15), borderRadius: BorderRadius.circular(Rad.xl),
            border: Border.all(color: color, width: 2), boxShadow: toyShadow(AppColors.toyShadowColor, 4)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 56, height: 56, decoration: BoxDecoration(color: color.withAlpha(0x30), shape: BoxShape.circle),
              child: Icon(ionIcon(cat['icon'] as String), size: 32, color: color)),
          const SizedBox(height: Sp.sm),
          Text(cat['name'], style: Fonts.display(16, color: AppColors.textPrimary, w: FontWeight.w700)),
          const SizedBox(height: Sp.sm),
          Text(cat['hindiName'], style: Fonts.hindi(14, color: AppColors.textSecondary)),
          const SizedBox(height: Sp.sm),
          // A peek at the words inside.
          Text([for (final w in (cat['words'] as List).take(4)) (w as Map)['emoji']].join(' '),
              style: const TextStyle(fontSize: 18)),
          const SizedBox(height: Sp.xs),
          Text('${(cat['words'] as List).length} words', style: Fonts.body(12, color: AppColors.textMuted)),
        ]),
      ),
    );
  }

  Widget _learn() {
    final words = _words;
    final word = words[wordIndex];
    final color = _cc;
    return ScreenScaffold(child: Column(children: [
      HeaderBar(
        title: category!['name'], subtitle: category!['hindiName'],
        onBack: () => setState(() { state = _S.categories; category = null; }),
        rightAction: Container(
          padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.xs),
          decoration: BoxDecoration(color: AppColors.primary.withAlpha(0x15), borderRadius: BorderRadius.circular(9999)),
          child: Text('${wordIndex + 1} / ${words.length}', style: Fonts.body(12, w: FontWeight.w700, color: AppColors.primary)),
        ),
      ),
      HsProgressBar(progress: (wordIndex + 1) / words.length, height: 4),
      Expanded(child: screenScroll(
        padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.lg),
        child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 640), child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // The word as a flash card: picture and Hindi on the front, English on the back.
          GestureDetector(
            onTap: () => setState(() => flipped = !flipped),
            onHorizontalDragEnd: (d) {
              final v = d.primaryVelocity ?? 0;
              if (v < -200) { _goTo(wordIndex + 1); } else if (v > 200) { _goTo(wordIndex - 1); }
            },
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              transitionBuilder: (child, anim) {
                final turn = Tween(begin: 0.5, end: 1.0).animate(anim);
                return AnimatedBuilder(animation: turn, child: child, builder: (_, c) => Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..setEntry(3, 2, 0.0012)..rotateY((1 - turn.value) * 3.14159),
                  child: Opacity(opacity: anim.value < 0.5 ? 0 : 1, child: c)));
              },
              child: flipped
                  ? _cardBack(word, color, key: ValueKey('b$wordIndex'))
                  : _cardFront(word, color, key: ValueKey('f$wordIndex')),
            ),
          ),
          const SizedBox(height: Sp.sm),
          Text(flipped ? 'Tap the card to see the Hindi again' : 'Tap the card to see the meaning · swipe for the next word',
              textAlign: TextAlign.center, style: Fonts.body(12.5, w: FontWeight.w700, color: AppColors.textMuted)),
          Padding(padding: const EdgeInsets.symmetric(vertical: Sp.md), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _navBtn(Icons.chevron_left, wordIndex == 0, () => _goTo(wordIndex - 1)),
            const SizedBox(width: Sp.lg),
            _navBtn(Icons.chevron_right, wordIndex == words.length - 1, () => _goTo(wordIndex + 1)),
          ])),
          // Every word in the topic, as cards.
          Padding(padding: const EdgeInsets.only(top: Sp.sm, bottom: Sp.md), child: Row(children: [
            Expanded(child: Text('All ${words.length} words', style: Fonts.display(18, color: AppColors.textPrimary, w: FontWeight.w700))),
            Text('Tap a card to hear it', style: Fonts.body(12, w: FontWeight.w700, color: AppColors.textMuted)),
          ])),
          LayoutBuilder(builder: (context, c) {
            final cols = c.maxWidth >= 520 ? 4 : c.maxWidth >= 340 ? 3 : 2;
            final w = (c.maxWidth - Sp.sm * (cols - 1)) / cols;
            return Wrap(spacing: Sp.sm, runSpacing: Sp.sm, children: [
              for (int i = 0; i < words.length; i++) SizedBox(width: w, child: _miniCard(i, words[i], color)),
            ]);
          }),
          Padding(padding: const EdgeInsets.only(top: Sp.xl), child: GestureDetector(
            onTap: _startQuiz,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: Sp.lg),
              decoration: BoxDecoration(gradient: toneGradient(AppColors.primary), borderRadius: BorderRadius.circular(9999), boxShadow: toyShadow(AppColors.primaryDark, 6)),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.help, size: 20, color: AppColors.textOnPrimary), const SizedBox(width: Sp.md),
                Text('Test with Quiz', style: Fonts.body(16, w: FontWeight.w800, color: AppColors.textOnPrimary)),
              ]),
            ),
          )),
          const SizedBox(height: Sp.xl),
        ]))),
      )),
    ]));
  }

  void _goTo(int i) {
    final n = _words.length;
    if (i < 0 || i >= n) return;
    setState(() { wordIndex = i; flipped = false; });
    _play(_words[i]['hindi']);
  }

  BoxDecoration _cardDecoration(Color color, {bool back = false}) => BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: back
                ? [Color.lerp(color, Colors.white, 0.05)!, shade(color, 0.12)]
                : [Colors.white, Color.lerp(color, Colors.white, 0.86)!]),
        borderRadius: BorderRadius.circular(Rad.xl2),
        border: Border.all(color: color.withOpacity(back ? 0 : 0.45), width: 2),
        boxShadow: toyShadow(shade(color, 0.2).withOpacity(0.55), 6),
      );

  Widget _cardFront(Map word, Color color, {Key? key}) => Container(
        key: key, height: 300,
        decoration: _cardDecoration(color),
        child: Stack(children: [
          Positioned(top: Sp.md, right: Sp.md, child: GestureDetector(
            onTap: () => _play(word['hindi']),
            child: Container(
              width: 46, height: 46, alignment: Alignment.center,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: toyShadow(shade(color, 0.25), 3)),
              child: Icon(playing == word['hindi'] ? Icons.volume_up_rounded : Icons.volume_up_outlined, color: Colors.white, size: 24),
            ),
          )),
          Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(word['emoji'], style: const TextStyle(fontSize: 76)),
            const SizedBox(height: Sp.sm),
            Text(word['hindi'], style: Fonts.hindi(52, color: AppColors.textPrimary, height: 1.25)),
            Text(toRoman(word['hindi']), style: Fonts.body(16, w: FontWeight.w700, color: AppColors.textSecondary).copyWith(letterSpacing: 0.5)),
          ])),
        ]),
      );

  Widget _cardBack(Map word, Color color, {Key? key}) => Container(
        key: key, height: 300,
        decoration: _cardDecoration(color, back: true),
        child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(word['emoji'], style: const TextStyle(fontSize: 44)),
          const SizedBox(height: Sp.sm),
          Text('ENGLISH', style: Fonts.body(12, w: FontWeight.w800, color: Colors.white.withOpacity(0.85)).copyWith(letterSpacing: 1.5)),
          Text(word['english'], textAlign: TextAlign.center, style: Fonts.display(38, color: Colors.white)),
          const SizedBox(height: Sp.xs),
          Text('${word['hindi']} = ${word['english']}', style: Fonts.hindi(18, color: Colors.white.withOpacity(0.92))),
          const SizedBox(height: Sp.md),
          GestureDetector(
            onTap: () => speakEnglish(word['english']),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: Sp.lg, vertical: Sp.sm),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(9999)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.volume_up_rounded, size: 18, color: shade(color, 0.15)), const SizedBox(width: Sp.sm),
                Text('Hear English', style: Fonts.body(14, w: FontWeight.w800, color: shade(color, 0.15))),
              ]),
            ),
          ),
        ])),
      );

  Widget _miniCard(int i, Map word, Color color) {
    final sel = i == wordIndex;
    return GestureDetector(
      onTap: () => _goTo(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: Sp.md, horizontal: Sp.xs),
        decoration: BoxDecoration(
          color: sel ? color.withOpacity(0.14) : AppColors.surface,
          borderRadius: BorderRadius.circular(Rad.lg),
          border: Border.all(color: sel ? color : AppColors.border, width: sel ? 2 : 1),
          boxShadow: toyShadow(AppColors.toyShadowColor, sel ? 4 : 3)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(word['emoji'], style: const TextStyle(fontSize: 32)),
          const SizedBox(height: 4),
          Text(word['hindi'], maxLines: 1, overflow: TextOverflow.ellipsis,
              style: Fonts.hindi(20, color: AppColors.textPrimary, height: 1.3)),
          Text(word['english'], maxLines: 1, overflow: TextOverflow.ellipsis,
              style: Fonts.body(12, w: FontWeight.w700, color: AppColors.textSecondary)),
        ]),
      ),
    );
  }

  Widget _navBtn(IconData icon, bool disabled, VoidCallback onTap) => GestureDetector(
        onTap: disabled ? null : onTap,
        child: Container(
          width: 48, height: 48, alignment: Alignment.center,
          decoration: BoxDecoration(color: AppColors.surface, shape: BoxShape.circle,
              border: Border.all(color: disabled ? AppColors.border : AppColors.primary, width: 2),
              boxShadow: toyShadow(AppColors.toyShadowColor, 4)),
          child: Icon(icon, size: 20, color: disabled ? AppColors.textMuted : AppColors.primary),
        ),
      );

  Widget _quiz() {
    final q = questions[quizIndex.clampI(0, questions.length - 1)];
    final color = _cc;
    return ScreenScaffold(child: Column(children: [
      HeaderBar(
        title: category!['name'], subtitle: 'Question ${quizIndex + 1} of ${questions.length}',
        onBack: () => setState(() { state = _S.learn; wordIndex = 0; }),
        rightAction: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.check_circle, size: 14, color: AppColors.success), const SizedBox(width: Sp.xs),
          Text('$quizScore', style: Fonts.body(14, w: FontWeight.w800, color: AppColors.success)),
        ]),
      ),
      HsProgressBar(progress: (quizIndex + 1) / questions.length, height: 4),
      Expanded(child: screenScroll(
        padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.lg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            margin: const EdgeInsets.only(bottom: Sp.lg),
            padding: const EdgeInsets.symmetric(vertical: Sp.xl, horizontal: Sp.lg),
            decoration: BoxDecoration(color: color.withAlpha(0x15), borderRadius: BorderRadius.circular(Rad.xl2), boxShadow: softShadow(AppColors.primary)),
            child: Column(children: [
              Text('What does this word mean?', style: Fonts.body(16, w: FontWeight.w700, color: AppColors.textSecondary)),
              const SizedBox(height: Sp.lg),
              Text(q.hindiWord, style: Fonts.hindi(56, color: AppColors.textPrimary)),
              const SizedBox(height: Sp.lg),
              GestureDetector(
                onTap: () => _play(q.hindiWord),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: Sp.lg, vertical: Sp.md),
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(9999), boxShadow: toyShadow(AppColors.toyShadowColor, 4)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(playing == q.hindiWord ? Icons.volume_up : Icons.volume_off, size: 18, color: AppColors.textOnPrimary),
                    const SizedBox(width: Sp.sm),
                    Text('Tap to hear', style: Fonts.body(14, w: FontWeight.w800, color: AppColors.textOnPrimary)),
                  ]),
                ),
              ),
            ]),
          ),
          for (int i = 0; i < q.options.length; i++) Padding(
            padding: const EdgeInsets.only(bottom: Sp.md),
            child: GestureDetector(
              onTap: selectedAnswer != null ? null : () => _answer(i),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: Sp.lg, vertical: Sp.md),
                decoration: BoxDecoration(color: _bg(i, q.correctIndex), borderRadius: BorderRadius.circular(Rad.xl),
                    border: Border.all(color: _border(i, q.correctIndex), width: 2), boxShadow: toyShadow(AppColors.toyShadowColor, 4)),
                child: Row(children: [
                  Expanded(child: Text(q.options[i], style: Fonts.body(16, w: FontWeight.w700, color: _text(i)))),
                  if (selectedAnswer == i) Icon(i == q.correctIndex ? Icons.check_circle : Icons.cancel, size: 24,
                      color: i == q.correctIndex ? AppColors.success : AppColors.error),
                ]),
              ),
            ),
          ),
          const SizedBox(height: Sp.xl),
        ]),
      )),
    ]));
  }
}
