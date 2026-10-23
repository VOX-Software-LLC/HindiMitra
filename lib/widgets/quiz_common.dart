import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/palette.dart';
import 'common.dart';

final _rng = Random();

List<T> shuffled<T>(Iterable<T> src) {
  final copy = List<T>.from(src);
  for (int i = copy.length - 1; i > 0; i--) {
    final j = _rng.nextInt(i + 1);
    final t = copy[i]; copy[i] = copy[j]; copy[j] = t;
  }
  return copy;
}

T randomOf<T>(List<T> l) => l[_rng.nextInt(l.length)];

/// Green "✓ n" pill used in HeaderBar rightAction.
class ScoreBadge extends StatelessWidget {
  final int score;
  const ScoreBadge(this.score, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: Sp.sm, vertical: 4),
        decoration: BoxDecoration(color: AppColors.success.withOpacity(0.125), borderRadius: BorderRadius.circular(9999),
            border: Border.all(color: AppColors.success.withOpacity(0.33))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.check_circle, size: 14, color: AppColors.success), const SizedBox(width: 4),
          Text('$score', style: Fonts.body(14, w: FontWeight.w800, color: AppColors.success)),
        ]),
      );
}

class StreakBar extends StatelessWidget {
  final int streak;
  const StreakBar(this.streak, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: Sp.xs),
        color: AppColors.starGold.withOpacity(0.13),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.local_fire_department, size: 16, color: AppColors.starGold), const SizedBox(width: Sp.xs),
          Text('$streak in a row!', style: Fonts.body(12, w: FontWeight.w800, color: const Color(0xFF8A6A18))),
        ]),
      );
}

/// The "Quiz Complete!" card shared by many quiz screens.
class QuizResultCard extends StatelessWidget {
  final String emoji, title, scoreText, message;
  final int stars;
  final VoidCallback onRetry, onDone;
  final String retryLabel, doneLabel;
  final Widget? extra;
  const QuizResultCard({super.key, required this.emoji, required this.title, required this.stars,
      required this.scoreText, required this.message, required this.onRetry, required this.onDone,
      this.retryLabel = 'Try Again', this.doneLabel = 'Done', this.extra});
  @override
  Widget build(BuildContext context) => Center(child: SingleChildScrollView(
        padding: const EdgeInsets.all(Sp.lg),
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 380), child: PopIn(child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: Sp.xl, horizontal: Sp.lg),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(Rad.xl2),
              border: Border.all(color: AppColors.border), boxShadow: softShadow(AppColors.primary)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(emoji, style: const TextStyle(fontSize: 64)),
            const SizedBox(height: Sp.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: Sp.lg, vertical: Sp.sm),
              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(9999),
                  boxShadow: toyShadow(AppColors.primaryDark, 6)),
              child: Text(title, textAlign: TextAlign.center, style: Fonts.display(24, color: AppColors.textOnPrimary)),
            ),
            const SizedBox(height: Sp.md),
            StarRating(stars: stars, size: 48),
            Padding(padding: const EdgeInsets.only(top: Sp.md),
                child: Text(scoreText, textAlign: TextAlign.center, style: Fonts.display(24, color: AppColors.primary))),
            if (extra != null) extra!,
            Padding(padding: const EdgeInsets.only(top: Sp.sm, bottom: Sp.xl),
                child: Text(message, textAlign: TextAlign.center, style: Fonts.body(16, color: AppColors.textSecondary))),
            Row(children: [
              Expanded(child: GestureDetector(
                onTap: onRetry,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: Sp.sm + 2),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(9999), border: Border.all(color: AppColors.primary, width: 2)),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.refresh, size: 18, color: AppColors.primary), const SizedBox(width: Sp.sm),
                    Flexible(child: Text(retryLabel, style: Fonts.body(16, w: FontWeight.w800, color: AppColors.primary))),
                  ]),
                ),
              )),
              const SizedBox(width: Sp.md),
              Expanded(child: GestureDetector(
                onTap: onDone,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: Sp.sm + 2),
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(9999), boxShadow: toyShadow(AppColors.primaryDark, 6)),
                  child: Center(child: Text(doneLabel, style: Fonts.body(16, w: FontWeight.w800, color: AppColors.textOnPrimary))),
                ),
              )),
            ]),
          ]),
        )),
      )));
}

/// Feedback row: ✓ Correct! / ✗ message
class FeedbackRow extends StatelessWidget {
  final bool correct; final String text;
  const FeedbackRow({super.key, required this.correct, required this.text});
  @override
  Widget build(BuildContext context) {
    final c = correct ? AppColors.success : AppColors.error;
    return Padding(padding: const EdgeInsets.symmetric(vertical: Sp.md), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(correct ? Icons.check_circle : Icons.cancel, size: 24, color: c), const SizedBox(width: Sp.sm),
      Flexible(child: Text(text, textAlign: TextAlign.center, style: Fonts.body(18, w: FontWeight.w800, color: c))),
    ]));
  }
}

/// Pill "Hear it" button (primary tint).
class HearButton extends StatelessWidget {
  final VoidCallback onTap; final String label; final IconData icon;
  const HearButton({super.key, required this.onTap, this.label = 'Hear it', this.icon = Icons.volume_down});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.xs),
          decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.09), borderRadius: BorderRadius.circular(9999),
              border: Border.all(color: AppColors.primary.withOpacity(0.33))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 20, color: AppColors.primary), const SizedBox(width: Sp.xs),
            Text(label, style: Fonts.body(12, w: FontWeight.w800, color: AppColors.primary)),
          ]),
        ),
      );
}

/// Scaffold with the standard cream background and top safe area.
class ScreenScaffold extends StatelessWidget {
  final Widget child;
  const ScreenScaffold({super.key, required this.child});
  @override
  Widget build(BuildContext context) =>
      Scaffold(backgroundColor: AppColors.background, body: SafeArea(bottom: false, child: child));
}

/// Result screen without the card: emoji, big title, score, message, two buttons.
class SimpleResult extends StatelessWidget {
  final String emoji, title, scoreText, message, retryLabel, doneLabel;
  final VoidCallback onRetry, onDone;
  const SimpleResult({super.key, required this.emoji, required this.title, required this.scoreText, required this.message,
      required this.onRetry, required this.onDone, this.retryLabel = 'Try Again', this.doneLabel = 'Done'});
  @override
  Widget build(BuildContext context) => Center(child: SingleChildScrollView(
        padding: const EdgeInsets.all(Sp.xl),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(emoji, style: const TextStyle(fontSize: 64)),
          const SizedBox(height: Sp.md),
          Text(title, textAlign: TextAlign.center, style: Fonts.display(32, height: 40 / 32)),
          const SizedBox(height: Sp.sm),
          Padding(padding: const EdgeInsets.only(top: Sp.md), child: Text(scoreText, style: Fonts.display(24, color: AppColors.primary))),
          Padding(padding: const EdgeInsets.only(top: Sp.sm, bottom: Sp.xl),
              child: Text(message, textAlign: TextAlign.center, style: Fonts.body(16, color: AppColors.textSecondary))),
          ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480), child: Row(children: [
            Expanded(child: GestureDetector(
              onTap: onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: Sp.md),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(9999), border: Border.all(color: AppColors.primary, width: 2)),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.refresh, size: 18, color: AppColors.primary), const SizedBox(width: Sp.sm),
                  Flexible(child: Text(retryLabel, style: Fonts.body(16, w: FontWeight.w800, color: AppColors.primary))),
                ]),
              ),
            )),
            const SizedBox(width: Sp.md),
            Expanded(child: GestureDetector(
              onTap: onDone,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: Sp.md),
                decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(9999), boxShadow: toyShadow(AppColors.primaryDark, 6)),
                child: Center(child: Text(doneLabel, style: Fonts.body(16, w: FontWeight.w800, color: AppColors.textOnPrimary))),
              ),
            )),
          ])),
        ]),
      ));
}

/// Easy/medium/hard small badge.
Widget difficultyBadge(String d, {double fontSize = 10, FontWeight weight = FontWeight.w700}) {
  final c = d == 'easy' ? AppColors.success : d == 'medium' ? AppColors.warning : AppColors.error;
  final op = d == 'medium' ? 0.19 : 0.125;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: Sp.sm, vertical: 2),
    decoration: BoxDecoration(color: c.withOpacity(op), borderRadius: BorderRadius.circular(9999)),
    child: Text(d[0].toUpperCase() + d.substring(1), style: Fonts.body(fontSize, w: weight, color: AppColors.textPrimary)),
  );
}

/// Dashed rounded border drawn over [child] (RN `borderStyle: 'dashed'`).
class DashedBorder extends StatelessWidget {
  final Widget child; final double radius, width; final Color color; final double dash, gap;
  const DashedBorder({super.key, required this.child, this.radius = Rad.xl, this.width = 2,
      this.color = AppColors.border, this.dash = 6, this.gap = 4});
  @override
  Widget build(BuildContext context) => CustomPaint(foregroundPainter: _DashedPainter(radius, width, color, dash, gap), child: child);
}

class _DashedPainter extends CustomPainter {
  final double radius, width, dash, gap; final Color color;
  _DashedPainter(this.radius, this.width, this.color, this.dash, this.gap);
  @override
  void paint(Canvas canvas, Size size) {
    if (color.opacity == 0) return;
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)));
    final paint = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = width;
    for (final m in path.computeMetrics()) {
      double d = 0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + dash), paint);
        d += dash + gap;
      }
    }
  }
  @override
  bool shouldRepaint(covariant _DashedPainter o) => o.color != color || o.radius != radius;
}

/// Centered "Quiz Complete!" screen (80px emoji, stars, score, message, 2 buttons) shared by several quizzes.
class PlainQuizResult extends StatelessWidget {
  final String emoji, title, scoreText, message; final int stars;
  final VoidCallback onRetry, onDone;
  const PlainQuizResult({super.key, required this.emoji, this.title = 'Quiz Complete!', required this.stars,
      required this.scoreText, required this.message, required this.onRetry, required this.onDone});
  @override
  Widget build(BuildContext context) => Center(child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: Sp.lg),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(emoji, style: const TextStyle(fontSize: 80)),
          const SizedBox(height: Sp.md),
          Text(title, textAlign: TextAlign.center, style: Fonts.display(24)),
          const SizedBox(height: Sp.md),
          StarRating(stars: stars, size: 48),
          Padding(padding: const EdgeInsets.symmetric(vertical: Sp.md),
              child: Text(scoreText, style: Fonts.display(20, color: AppColors.primary, w: FontWeight.w700))),
          Padding(padding: const EdgeInsets.only(bottom: Sp.lg),
              child: Text(message, textAlign: TextAlign.center, style: Fonts.body(16, color: AppColors.textSecondary, height: 24 / 16))),
          const SizedBox(height: Sp.lg),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Flexible(child: GestureDetector(
              onTap: onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: Sp.md, horizontal: Sp.lg),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(9999), border: Border.all(color: AppColors.primary, width: 2)),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.refresh, size: 18, color: AppColors.primary), const SizedBox(width: Sp.sm),
                  Text('Try Again', style: Fonts.body(16, w: FontWeight.w800, color: AppColors.primary)),
                ]),
              ),
            )),
            const SizedBox(width: Sp.md),
            Flexible(child: GestureDetector(
              onTap: onDone,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: Sp.md, horizontal: Sp.xl),
                decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(9999), boxShadow: toyShadow(AppColors.primaryDark, 6)),
                child: Text('Done', style: Fonts.body(16, w: FontWeight.w800, color: AppColors.textOnPrimary)),
              ),
            )),
          ]),
        ]),
      ));
}

/// Compact header score ("✓ n") without a pill (used by the sound / pairs quizzes).
class PlainScore extends StatelessWidget {
  final int score;
  const PlainScore(this.score, {super.key});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.check_circle, size: 14, color: AppColors.success), const SizedBox(width: Sp.xs),
        Text('$score', style: Fonts.body(14, w: FontWeight.w700, color: AppColors.success)),
      ]);
}

/// Streak chip with a gold left accent (pairs quiz).
class StreakChip extends StatelessWidget {
  final int streak; final bool goldLeft;
  const StreakChip(this.streak, {super.key, this.goldLeft = false});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.sm),
        padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.sm),
        decoration: BoxDecoration(
          color: AppColors.surface, borderRadius: BorderRadius.circular(9999),
          border: goldLeft
              ? const Border(left: BorderSide(color: AppColors.starGold, width: 4), top: BorderSide(color: AppColors.border),
                  right: BorderSide(color: AppColors.border), bottom: BorderSide(color: AppColors.border))
              : Border.all(color: AppColors.border),
          boxShadow: toyShadow(AppColors.toyShadowColor, 3)),
        child: Row(children: [
          const Icon(Icons.local_fire_department, size: 16, color: AppColors.starGold), const SizedBox(width: Sp.sm),
          Text('$streak in a row!', style: Fonts.body(14, w: FontWeight.w700, color: AppColors.textPrimary)),
        ]),
      );
}
