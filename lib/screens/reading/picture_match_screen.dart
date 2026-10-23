import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/reading_data.dart';
import '../../services/speech_service.dart';
import '../../store/app_store.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../../widgets/common.dart';
import '../../widgets/quiz_common.dart';
import '../../util/num_ext.dart';

/// PictureMatchScreen.tsx — match a Hindi word to its emoji.
class PictureMatchScreen extends StatefulWidget {
  final Map<String, dynamic> params;
  const PictureMatchScreen({super.key, this.params = const {}});
  @override
  State<PictureMatchScreen> createState() => _PictureMatchScreenState();
}

class _PictureMatchScreenState extends State<PictureMatchScreen> with SingleTickerProviderStateMixin {
  bool results = false, confetti = false;
  int cur = 0, score = 0, cardKey = 0;
  String? selectedEmoji;
  String? selState; // 'correct' | 'wrong'
  Timer? _t;
  late final AnimationController _wordPulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);

  int get total => pictureMatchData.length;
  Map get q => pictureMatchData[cur.clampI(0, total - 1)] as Map;

  @override
  void dispose() { _t?.cancel(); _wordPulse.dispose(); super.dispose(); }

  void _select(String emoji) {
    if (selState != null) return;
    final ok = emoji == q['correctEmoji'];
    final idxAtTap = cur;
    setState(() {
      selectedEmoji = emoji; selState = ok ? 'correct' : 'wrong';
      if (ok) score++;
    });
    if (ok) { speakHindi(q['word']); setState(() => confetti = true); }
    _t = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      setState(() {
        if (idxAtTap < total - 1) { cur = idxAtTap + 1; selectedEmoji = null; selState = null; cardKey++; }
        else { results = true; }
      });
      final aId = widget.params['activityId'], lvl = widget.params['levelNumber'];
      if (results && stars > 0 && aId is String && lvl is int) context.read<AppStore>().completeActivityLevel(aId, lvl);
    });
  }

  void _playAgain() => setState(() { cur = 0; selectedEmoji = null; selState = null; score = 0; results = false; cardKey++; });

  void _exit() {
    context.read<AppStore>().addPoints(score * 10);
    Navigator.of(context).maybePop();
  }

  int get stars {
    final pct = score / total * 100;
    return pct >= 80 ? 3 : pct >= 60 ? 2 : pct >= 40 ? 1 : 0;
  }

  @override
  Widget build(BuildContext context) {
    if (results) return _results();
    final w = MediaQuery.of(context).size.width;
    final cardSize = math.min((w - Sp.lg * 2 - Sp.md) / 2, 170.0);
    final answered = selState != null;
    final options = (q['options'] as List).cast<String>();
    return ScreenScaffold(child: Stack(children: [
      Column(children: [
        HeaderBar(title: 'Picture Matching', subtitle: 'चित्र मिलान', onBack: _exit),
        Padding(padding: const EdgeInsets.symmetric(horizontal: Sp.lg, vertical: Sp.sm), child: Column(children: [
          Wrap(spacing: 4, runSpacing: 4, alignment: WrapAlignment.center, children: [
            for (int i = 0; i < total; i++) Container(
              height: 8, width: i == cur ? 20 : 8,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(4),
                  color: i < cur ? AppColors.success : i == cur ? AppColors.primary : AppColors.border),
            ),
          ]),
          const SizedBox(height: Sp.xs),
          Text('${cur + 1} / $total', style: Fonts.body(12, w: FontWeight.w700, color: AppColors.textSecondary)),
        ])),
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Sp.lg, 0, Sp.lg, Sp.xxl),
          child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child: Column(children: [
            Padding(padding: const EdgeInsets.only(top: Sp.md, bottom: Sp.sm), child: ScaleTransition(
              scale: Tween(begin: 1.0, end: 1.03).animate(CurvedAnimation(parent: _wordPulse, curve: Curves.easeInOut)),
              child: Text(q['word'], textAlign: TextAlign.center, style: Fonts.hindi(56, color: AppColors.textPrimary, height: 68 / 56)),
            )),
            Padding(padding: const EdgeInsets.only(bottom: Sp.md), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              GestureDetector(
                onTap: () => speakHindi(q['word']),
                child: Container(width: 52, height: 52,
                    decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle, boxShadow: toyShadow(AppColors.toyShadowColor, 4)),
                    child: const Icon(Icons.volume_up, size: 26, color: Colors.white)),
              ),
              const SizedBox(width: Sp.md),
              Text(q['meaning'], style: Fonts.body(20, w: FontWeight.w600, color: AppColors.textSecondary)),
            ])),
            Padding(padding: const EdgeInsets.only(bottom: Sp.lg),
                child: Text('Pick the right picture!', textAlign: TextAlign.center, style: Fonts.body(15, w: FontWeight.w500, color: AppColors.textSecondary))),
            Wrap(spacing: Sp.md, runSpacing: Sp.md, alignment: WrapAlignment.center, children: [
              for (int i = 0; i < options.length; i++) _EmojiCard(
                key: ValueKey('$cardKey-$i'),
                emoji: options[i], index: i, size: cardSize,
                isSelected: selectedEmoji == options[i],
                isCorrectAnswer: options[i] == q['correctEmoji'],
                isAnswered: answered,
                onTap: () => _select(options[i]),
              ),
            ]),
          ]))),
        )),
      ]),
      Positioned.fill(child: Confetti(visible: confetti, onComplete: () => setState(() => confetti = false))),
    ]));
  }

  Widget _results() {
    final s = stars;
    return ScreenScaffold(child: Center(child: SingleChildScrollView(
      padding: const EdgeInsets.all(Sp.xl),
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(s == 3 ? '🏆' : s == 2 ? '🎉' : s >= 1 ? '💪' : '📚', style: const TextStyle(fontSize: 80)),
        const SizedBox(height: Sp.md),
        Text(s == 3 ? 'Amazing!' : s == 2 ? 'Great Job!' : s >= 1 ? 'Good Try!' : 'Keep Learning!',
            textAlign: TextAlign.center, style: Fonts.display(32, height: 40 / 32)),
        const SizedBox(height: Sp.lg),
        Container(
          width: 140, height: 140, margin: const EdgeInsets.only(bottom: Sp.lg),
          decoration: BoxDecoration(color: AppColors.surface, shape: BoxShape.circle,
              border: Border.all(color: AppColors.border, width: 2), boxShadow: softShadow(AppColors.primary)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('$score', style: Fonts.display(48, color: AppColors.primary, height: 52 / 48)),
            Text('out of', style: Fonts.body(11, w: FontWeight.w500, color: AppColors.textSecondary)),
            Text('$total', style: Fonts.body(20, w: FontWeight.w600, color: AppColors.textSecondary)),
          ]),
        ),
        Padding(padding: const EdgeInsets.only(bottom: Sp.xl), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (int i = 0; i < 3; i++) Padding(padding: const EdgeInsets.symmetric(horizontal: Sp.sm),
              child: Icon(i < s ? Icons.star : Icons.star_border, size: 52, color: i < s ? AppColors.starGold : AppColors.border)),
        ])),
        GestureDetector(
          onTap: _playAgain,
          child: Container(
            width: double.infinity, padding: const EdgeInsets.symmetric(vertical: Sp.md),
            decoration: BoxDecoration(gradient: toneGradient(AppColors.primary), borderRadius: BorderRadius.circular(9999), boxShadow: toyShadow(AppColors.primaryDark, 6)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.refresh, size: 22, color: AppColors.textOnPrimary), const SizedBox(width: Sp.sm),
              Text('Play Again', style: Fonts.body(16, w: FontWeight.w800, color: AppColors.textOnPrimary)),
            ]),
          ),
        ),
        const SizedBox(height: Sp.md),
        GestureDetector(
          onTap: _exit,
          child: Container(
            width: double.infinity, padding: const EdgeInsets.symmetric(vertical: Sp.md),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(9999), border: Border.all(color: AppColors.primary, width: 2)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.arrow_back, size: 22, color: AppColors.primary), const SizedBox(width: Sp.sm),
              Text('Exit', style: Fonts.body(16, w: FontWeight.w800, color: AppColors.primary)),
            ]),
          ),
        ),
      ])),
    )));
  }
}

class _EmojiCard extends StatefulWidget {
  final String emoji; final int index; final double size;
  final bool isSelected, isCorrectAnswer, isAnswered; final VoidCallback onTap;
  const _EmojiCard({super.key, required this.emoji, required this.index, required this.size, required this.isSelected,
      required this.isCorrectAnswer, required this.isAnswered, required this.onTap});
  @override
  State<_EmojiCard> createState() => _EmojiCardState();
}

class _EmojiCardState extends State<_EmojiCard> with TickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  late final AnimationController _idle = AnimationController(vsync: this, duration: Duration(milliseconds: 2400 + widget.index * 300));
  late final AnimationController _breath = AnimationController(vsync: this, duration: Duration(milliseconds: 1200 + widget.index * 100));
  late final AnimationController _react = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
  bool get _correct => widget.isSelected && widget.isCorrectAnswer;
  bool get _wrong => widget.isSelected && !widget.isCorrectAnswer;
  bool get _reveal => widget.isAnswered && widget.isCorrectAnswer;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.index * 120), () { if (mounted) _enter.forward(); });
    Future.delayed(Duration(milliseconds: widget.index * 200 + 500), () { if (mounted) _idle.repeat(); });
    Future.delayed(Duration(milliseconds: widget.index * 150), () { if (mounted) _breath.repeat(reverse: true); });
  }

  @override
  void didUpdateWidget(covariant _EmojiCard old) {
    super.didUpdateWidget(old);
    if ((_correct || _wrong || _reveal) && !(old.isSelected && old.isAnswered) && widget.isAnswered != old.isAnswered) {
      _idle.stop(); _breath.stop();
      Future.delayed(Duration(milliseconds: _reveal && !_correct ? 400 : 0), () { if (mounted) _react.forward(from: 0); });
    }
  }

  @override
  void dispose() { _enter.dispose(); _idle.dispose(); _breath.dispose(); _react.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    Color border = AppColors.border, bg = AppColors.surface;
    if (_correct || _reveal) { border = AppColors.success; bg = const Color(0xFFE8F7EF); }
    else if (_wrong) { border = AppColors.error; bg = const Color(0xFFFDECEA); }
    return RepaintBoundary(child: AnimatedBuilder(
      animation: Listenable.merge([_enter, _idle, _breath, _react]),
      builder: (_, __) {
        final enter = Curves.elasticOut.transform(_enter.value.clampD(0.0, 1.0));
        double wiggle = 0;
        final t = _idle.value;
        if (!widget.isAnswered) {
          if (t < 0.25) {
            wiggle = -3 * (t / 0.25);
          } else if (t < 0.5) {
            wiggle = -3 + 6 * ((t - 0.25) / 0.25);
          } else if (t < 0.6) {
            wiggle = 3 * (1 - (t - 0.5) / 0.1);
          }
        }
        double emojiScale = 1 + 0.08 * Curves.easeInOut.transform(_breath.value);
        double shake = 0, cardPop = 1;
        final r = _react.value;
        if (_correct) emojiScale = 1 + 0.4 * Curves.elasticOut.transform(r) - (r > 0.5 ? 0.25 * ((r - 0.5) * 2) : 0);
        if (_reveal && !_correct) emojiScale = 1 + 0.2 * Curves.elasticOut.transform(r);
        if (_wrong) {
          shake = math.sin(r * math.pi * 5) * 8 * (1 - r);
          cardPop = r < 0.2 ? 1 - 0.1 * (r / 0.2) : 0.9 + 0.1 * Curves.elasticOut.transform((r - 0.2) / 0.8);
        }
        final glow = (_correct ? r : _reveal ? r : 0.0) * 0.3;
        return Transform.scale(
          scale: (enter.clampD(0.0, 1.4)) * cardPop,
          child: Transform.rotate(
            angle: (wiggle + shake) * math.pi / 180,
            child: SizedBox(width: widget.size, height: widget.size, child: GestureDetector(
              onTap: widget.isAnswered ? null : widget.onTap,
              child: Stack(clipBehavior: Clip.none, children: [
                Positioned.fill(child: Container(
                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Rad.xl2),
                      border: Border.all(color: border, width: 2), boxShadow: softShadow(AppColors.primary)),
                  alignment: Alignment.center,
                  child: Transform.scale(scale: emojiScale, child: Text(widget.emoji, style: const TextStyle(fontSize: 72))),
                )),
                Positioned(top: -6, left: -6, right: -6, bottom: -6, child: IgnorePointer(child: Opacity(opacity: glow,
                    child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(Rad.xl2 + 4),
                        border: Border.all(color: border, width: 4)))))),
                if (_correct || _reveal) Positioned(top: -8, right: -8, child: _badge(Icons.check_circle, AppColors.success)),
                if (_wrong) Positioned(top: -8, right: -8, child: _badge(Icons.cancel, AppColors.error)),
              ]),
            )),
          ),
        );
      },
    ));
  }

  Widget _badge(IconData i, Color c) => Container(
        decoration: BoxDecoration(color: AppColors.surface, shape: BoxShape.circle, boxShadow: toyShadow(AppColors.toyShadowColor, 3)),
        child: Icon(i, size: 32, color: c),
      );
}
