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
              final cardW = c.maxWidth * 0.48;
              // RN: space-between + gap md (wraps to 1 column when narrow)
              final gap = (c.maxWidth - 2 * cardW) < Sp.md ? Sp.md : (c.maxWidth - 2 * cardW);
              return Wrap(spacing: gap, runSpacing: Sp.md, children: [
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
      onTap: () => setState(() { category = cat; state = _S.learn; wordIndex = 0; }),
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
          Text('${(cat['words'] as List).length} words', style: Fonts.body(12, color: AppColors.textMuted)),
        ]),
      ),
    );
  }

  Widget _learn() {
    final words = _words;
    final word = words[wordIndex];
    final isLast = wordIndex == words.length - 1;
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
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            margin: const EdgeInsets.only(bottom: Sp.lg),
            padding: const EdgeInsets.symmetric(vertical: Sp.xl, horizontal: Sp.lg),
            decoration: BoxDecoration(color: color.withAlpha(0x15), borderRadius: BorderRadius.circular(Rad.xl2), boxShadow: softShadow(AppColors.primary)),
            child: Column(children: [
              Text(word['emoji'], style: const TextStyle(fontSize: 80)),
              const SizedBox(height: Sp.lg),
              GestureDetector(
                onTap: () => _play(word['hindi']),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: Sp.xl, vertical: Sp.lg),
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(9999), boxShadow: toyShadow(AppColors.toyShadowColor, 6)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(word['hindi'], style: Fonts.hindi(48, color: AppColors.textOnPrimary)),
                    const SizedBox(width: Sp.md),
                    Icon(playing == word['hindi'] ? Icons.volume_up : Icons.volume_off, size: 20, color: AppColors.textOnPrimary),
                  ]),
                ),
              ),
              const SizedBox(height: Sp.lg),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: Sp.lg, vertical: Sp.md),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(Rad.lg), border: Border.all(color: AppColors.border)),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Padding(padding: const EdgeInsets.only(bottom: Sp.xs), child: Text('ENGLISH:',
                      style: Fonts.body(12, w: FontWeight.w700, color: AppColors.textSecondary).copyWith(letterSpacing: 0.5))),
                  Text(word['english'], style: Fonts.display(24, color: AppColors.textPrimary)),
                ]),
              ),
            ]),
          ),
          GestureDetector(
            onTap: () => speakHindi(word['english'], rate: 0.6),
            child: Padding(padding: const EdgeInsets.only(bottom: Sp.lg), child: Container(
              padding: const EdgeInsets.symmetric(vertical: Sp.md), color: Colors.transparent,
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.volume_up, size: 18, color: AppColors.primary), const SizedBox(width: Sp.sm),
                Text('Hear English', style: Fonts.body(14, w: FontWeight.w700, color: AppColors.primary)),
              ]),
            )),
          ),
          Padding(padding: const EdgeInsets.symmetric(vertical: Sp.lg), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.only(bottom: Sp.md),
                child: Text('All words in this category:', style: Fonts.display(16, color: AppColors.textPrimary, w: FontWeight.w700))),
            Wrap(spacing: Sp.sm, runSpacing: Sp.sm, children: [
              for (int i = 0; i < words.length; i++) GestureDetector(
                onTap: () => setState(() => wordIndex = i),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.sm),
                  decoration: BoxDecoration(color: wordIndex == i ? color : AppColors.surface, borderRadius: BorderRadius.circular(Rad.lg),
                      border: Border.all(color: AppColors.border), boxShadow: toyShadow(AppColors.toyShadowColor, 3)),
                  child: Text(words[i]['hindi'], style: Fonts.hindi(16, color: wordIndex == i ? AppColors.textOnPrimary : AppColors.textPrimary)),
                ),
              ),
            ]),
          ])),
          Padding(padding: const EdgeInsets.symmetric(vertical: Sp.lg), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _navBtn(Icons.chevron_left, wordIndex == 0, () => setState(() => wordIndex = (wordIndex - 1).clampI(0, words.length - 1))),
            const SizedBox(width: Sp.lg),
            _navBtn(Icons.chevron_right, isLast, () => setState(() => wordIndex = (wordIndex + 1).clampI(0, words.length - 1))),
          ])),
          if (isLast) Padding(padding: const EdgeInsets.only(top: Sp.lg), child: GestureDetector(
            onTap: _startQuiz,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: Sp.lg),
              decoration: BoxDecoration(gradient: toneGradient(AppColors.primary), borderRadius: BorderRadius.circular(9999), boxShadow: toyShadow(AppColors.primaryDark, 6)),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.help, size: 20, color: AppColors.textOnPrimary), const SizedBox(width: Sp.md),
                Text('Test with Quiz', style: Fonts.body(16, w: FontWeight.w800, color: AppColors.textOnPrimary)),
              ]),
            ),
          )),
          const SizedBox(height: Sp.xl),
        ]),
      )),
    ]));
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
