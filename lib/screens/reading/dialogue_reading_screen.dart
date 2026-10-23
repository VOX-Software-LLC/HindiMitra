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
import '../../widgets/progress_bar.dart';
import '../../widgets/quiz_common.dart';

const _fg = Color(0xFFFEFCF4); // purpleForeground / greenForeground (light)

/// DialogueReadingScreen.tsx
class DialogueReadingScreen extends StatefulWidget {
  final Map<String, dynamic> params;
  const DialogueReadingScreen({super.key, this.params = const {}});
  @override
  State<DialogueReadingScreen> createState() => _DialogueReadingScreenState();
}

class _DialogueReadingScreenState extends State<DialogueReadingScreen> {
  int current = 0;
  bool quiz = false;
  int qIndex = 0, score = 0;
  int? selectedAnswer;
  String? playingLine;
  final Set<String> completed = {};
  Timer? _pt;

  Map get dialogue => dialoguesData[current] as Map;
  List get questions => dialogue['questions'] as List;

  @override
  void dispose() { _pt?.cancel(); super.dispose(); }

  void _resetQuiz() { qIndex = 0; selectedAnswer = null; score = 0; }

  void _playLine(String text) {
    setState(() => playingLine = text);
    speakHindi(text, rate: 0.6);
    _pt?.cancel();
    _pt = Timer(const Duration(seconds: 2), () { if (mounted) setState(() => playingLine = null); });
  }

  void _select(int opt) {
    if (selectedAnswer != null) return;
    final correct = opt == (questions[qIndex] as Map)['correctIndex'];
    final qAtTap = qIndex, scoreAtTap = score, curAtTap = current;
    setState(() {
      selectedAnswer = opt;
      if (correct) score++;
    });
    correct ? hapticSuccess() : hapticError();
    Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      if (qAtTap < questions.length - 1) {
        setState(() { qIndex = qAtTap + 1; selectedAnswer = null; });
      } else {
        final finalScore = scoreAtTap + (correct ? 1 : 0);
        context.read<AppStore>().addPoints(finalScore * 15);
        completed.add(dialogue['id'] as String);
        if (curAtTap < dialoguesData.length - 1) {
          setState(() { current = curAtTap + 1; quiz = false; _resetQuiz(); });
        } else {
          final aId = widget.params['activityId'], lvl = widget.params['levelNumber'];
          if (finalScore * 2 >= questions.length && aId is String && lvl is int) context.read<AppStore>().completeActivityLevel(aId, lvl);
          Navigator.of(context).maybePop();
        }
      }
    });
  }

  Color _bg(int idx, int correct) {
    if (selectedAnswer == null) return AppColors.surface;
    if (selectedAnswer == idx) return idx == correct ? AppColors.success : AppColors.error;
    if (idx == correct) return AppColors.success.withAlpha(0x30);
    return AppColors.surface;
  }

  Color _border(int idx, int correct) {
    if (selectedAnswer == null) return AppColors.border;
    if (selectedAnswer == idx) return idx == correct ? AppColors.success : AppColors.error;
    if (idx == correct) return AppColors.success;
    return AppColors.border;
  }

  Color _text(int idx) {
    if (selectedAnswer == null) return AppColors.textPrimary;
    if (selectedAnswer == idx) return AppColors.textOnPrimary;
    return AppColors.textSecondary;
  }

  @override
  Widget build(BuildContext context) => quiz ? _quiz() : _dialogue();

  Widget _quiz() {
    final q = questions[qIndex] as Map;
    final options = (q['options'] as List).cast<String>();
    final correct = q['correctIndex'] as int;
    return ScreenScaffold(child: Column(children: [
      HeaderBar(
        title: dialogue['title'], subtitle: 'Question ${qIndex + 1} of ${questions.length}',
        onBack: () => setState(() { quiz = false; _resetQuiz(); }),
        rightAction: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.check_circle, size: 14, color: AppColors.success), const SizedBox(width: Sp.xs),
          Text('$score', style: Fonts.body(14, w: FontWeight.w600, color: AppColors.success)),
        ]),
      ),
      HsProgressBar(progress: (qIndex + 1) / questions.length, height: 4),
      Expanded(child: screenScroll(
        padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.lg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            margin: const EdgeInsets.only(bottom: Sp.lg),
            padding: const EdgeInsets.all(Sp.lg),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(Rad.xl),
                border: const Border(left: BorderSide(color: AppColors.primary, width: 4), top: BorderSide(color: AppColors.border), right: BorderSide(color: AppColors.border), bottom: BorderSide(color: AppColors.border)),
                boxShadow: toyShadow(AppColors.toyShadowColor, 4)),
            child: Text(q['question'], style: Fonts.hindi(20, color: AppColors.textPrimary, height: 30 / 20)),
          ),
          for (int i = 0; i < options.length; i++) Padding(
            padding: const EdgeInsets.only(bottom: Sp.md),
            child: GestureDetector(
              onTap: selectedAnswer != null ? null : () => _select(i),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: Sp.lg, vertical: Sp.md),
                decoration: BoxDecoration(color: _bg(i, correct), borderRadius: BorderRadius.circular(Rad.xl),
                    border: Border.all(color: _border(i, correct), width: 2), boxShadow: toyShadow(AppColors.toyShadowColor, 3)),
                child: Row(children: [
                  Expanded(child: Text(options[i], style: Fonts.hindi(16, color: _text(i), height: 1.5))),
                  if (selectedAnswer == i) Icon(i == correct ? Icons.check_circle : Icons.cancel, size: 24,
                      color: i == correct ? AppColors.success : AppColors.error),
                ]),
              ),
            ),
          ),
        ]),
      )),
    ]));
  }

  Widget _dialogue() {
    final lines = dialogue['lines'] as List;
    return ScreenScaffold(child: Column(children: [
      HeaderBar(
        title: dialogue['title'], subtitle: 'पढ़ें और सुनें', onBack: () => Navigator.of(context).maybePop(),
        rightAction: Container(
          padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.xs),
          decoration: BoxDecoration(color: AppColors.primary.withAlpha(0x15), borderRadius: BorderRadius.circular(9999)),
          child: Text('${current + 1} / ${dialoguesData.length}', style: Fonts.body(12, w: FontWeight.w700, color: AppColors.primary)),
        ),
      ),
      HsProgressBar(progress: (current + 1) / dialoguesData.length, height: 4),
      Expanded(child: screenScroll(
        padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (int i = 0; i < lines.length; i++) _bubble(lines[i] as Map, i),
          const SizedBox(height: Sp.md),
          GestureDetector(
            onTap: () => setState(() => quiz = true),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: Sp.lg),
              decoration: BoxDecoration(gradient: toneGradient(AppColors.primary), borderRadius: BorderRadius.circular(9999), boxShadow: toyShadow(AppColors.primaryDark, 6)),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.help, size: 20, color: AppColors.textOnPrimary), const SizedBox(width: Sp.md),
                Text('Answer Questions', style: Fonts.body(16, w: FontWeight.w800, color: AppColors.textOnPrimary)),
              ]),
            ),
          ),
          const SizedBox(height: Sp.xl),
        ]),
      )),
    ]));
  }

  Widget _bubble(Map line, int idx) {
    final left = idx % 2 == 0;
    final bubbleColor = left ? Palette.light.purple : Palette.light.green;
    final avatar = Container(
      width: 36, height: 36, alignment: Alignment.center,
      decoration: BoxDecoration(color: AppColors.surface, shape: BoxShape.circle, border: Border.all(color: AppColors.border),
          boxShadow: toyShadow(AppColors.toyShadowColor, 3)),
      child: Text(line['characterEmoji'], style: const TextStyle(fontSize: 20)),
    );
    final text = line['text'] as String;
    final bubble = GestureDetector(
      onTap: () => _playLine(text),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.md),
        decoration: BoxDecoration(color: bubbleColor, borderRadius: BorderRadius.circular(Rad.xl), boxShadow: toyShadow(AppColors.toyShadowColor, 4)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Padding(padding: const EdgeInsets.only(bottom: Sp.xs), child: Opacity(opacity: 0.85,
              child: Text(line['character'], style: Fonts.body(12, w: FontWeight.w800, color: _fg).copyWith(letterSpacing: 0.3)))),
          Text(text, style: Fonts.hindi(16, color: _fg, height: 1.5)),
          if (playingLine == text) const Align(alignment: Alignment.centerRight,
              child: Padding(padding: EdgeInsets.only(top: Sp.xs), child: Icon(Icons.volume_up, size: 14, color: AppColors.textOnPrimary))),
        ]),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Sp.sm + Sp.xs),
      child: Align(
        alignment: left ? Alignment.centerLeft : Alignment.centerRight,
        child: FractionallySizedBox(
          widthFactor: 0.85,
          alignment: left ? Alignment.centerLeft : Alignment.centerRight,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: left ? MainAxisAlignment.start : MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: left
                ? [avatar, const SizedBox(width: Sp.sm), Flexible(child: bubble)]
                : [Flexible(child: bubble), const SizedBox(width: Sp.sm), avatar],
          ),
        ),
      ),
    );
  }
}
