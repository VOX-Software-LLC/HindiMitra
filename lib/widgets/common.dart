import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/stroke_evaluator.dart';
import '../theme/app_theme.dart';
import '../theme/palette.dart';
import '../util/num_ext.dart';
import 'draw_canvas.dart';
import 'toy_button.dart';

/// HeaderBar.tsx
class HeaderBar extends StatelessWidget {
  final String title; final String? subtitle; final VoidCallback? onBack; final Widget? rightAction;
  const HeaderBar({super.key, required this.title, this.subtitle, this.onBack, this.rightAction});
  @override
  Widget build(BuildContext context) => Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.sm),
        child: Row(children: [
          SizedBox(width: 44, child: Align(alignment: Alignment.centerLeft,
              child: onBack != null
                  ? Pressable(onTap: onBack, child: Container(width: 42, height: 42,
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border), boxShadow: toyShadow(AppColors.toyShadowColor, 2)),
                      child: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.textPrimary)))
                  : const SizedBox(width: 40))),
          Expanded(child: Column(children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Fonts.display(20, height: 1.15)),
            if (subtitle != null)
              Container(
                margin: const EdgeInsets.only(top: 3),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(9999)),
                child: Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: Fonts.body(12, w: FontWeight.w700, color: AppColors.primaryDark)),
              ),
          ])),
          // Right slot grows with its content (e.g. a "60s" timer pill) instead
          // of squeezing it into 44 px, which wrapped the text vertically.
          ConstrainedBox(constraints: const BoxConstraints(minWidth: 44),
              child: Align(alignment: Alignment.centerRight, widthFactor: 1, child: rightAction ?? const SizedBox(width: 40))),
        ]),
      );
}

/// StarRating.tsx (bounce-in animation)
class StarRating extends StatelessWidget {
  final int stars, total; final double size; final bool animated;
  const StarRating({super.key, required this.stars, this.total = 3, this.size = 32, this.animated = true});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        for (int i = 0; i < total; i++)
          Padding(
            padding: EdgeInsets.only(left: i == 0 ? 0 : Sp.sm),
            child: _AnimStar(filled: i < stars, size: size, delay: animated ? i * 200 : 0, animated: animated),
          ),
      ]);
}

class _AnimStar extends StatefulWidget {
  final bool filled, animated; final double size; final int delay;
  const _AnimStar({required this.filled, required this.size, required this.delay, required this.animated});
  @override
  State<_AnimStar> createState() => _AnimStarState();
}

class _AnimStarState extends State<_AnimStar> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
  @override
  void initState() {
    super.initState();
    if (widget.animated && widget.filled) {
      Future.delayed(Duration(milliseconds: widget.delay), () { if (mounted) c.forward(); });
    } else {
      c.value = 1;
    }
  }
  @override
  void dispose() { c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: c,
        builder: (_, __) {
          final t = c.value;
          final s = t < 0.6 ? Curves.easeOut.transform(t / 0.6) * 1.3 : 1.3 - 0.3 * Curves.easeOut.transform((t - 0.6) / 0.4);
          return Transform.scale(scale: s, child: Icon(widget.filled ? Icons.star : Icons.star_border, size: widget.size,
              color: widget.filled ? AppColors.starGold : AppColors.starEmpty));
        },
      );
}

/// DailyGoalRing.tsx
class DailyGoalRing extends StatelessWidget {
  final int current, goal; final double size, strokeWidth;
  const DailyGoalRing({super.key, required this.current, required this.goal, this.size = 80, this.strokeWidth = 8});
  @override
  Widget build(BuildContext context) {
    final done = current >= goal;
    return SizedBox(width: size, height: size, child: Stack(alignment: Alignment.center, children: [
      CustomPaint(size: Size(size, size), painter: _RingPainter(
          progress: goal == 0 ? 0 : math.min(current / goal, 1), stroke: strokeWidth,
          color: done ? AppColors.success : AppColors.primaryDark)),
      Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('$current', style: Fonts.display(size * 0.28, color: done ? AppColors.success : AppColors.textPrimary)),
        Text('/$goal', style: Fonts.body(size * 0.16, color: AppColors.textSecondary, w: FontWeight.w600)),
      ]),
    ]));
  }
}

class _RingPainter extends CustomPainter {
  final double progress, stroke; final Color color;
  _RingPainter({required this.progress, required this.stroke, required this.color});
  @override
  void paint(Canvas c, Size s) {
    final r = (s.width - stroke) / 2;
    final center = Offset(s.width / 2, s.height / 2);
    c.drawCircle(center, r, Paint()..color = AppColors.border..style = PaintingStyle.stroke..strokeWidth = stroke);
    c.drawArc(Rect.fromCircle(center: center, radius: r), -math.pi / 2, 2 * math.pi * progress, false,
        Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = stroke..strokeCap = StrokeCap.round);
  }
  @override
  bool shouldRepaint(covariant _RingPainter o) => o.progress != progress || o.color != color;
}

/// Marigold-petal confetti (ConfettiAnimation.tsx — simplified petals).
class Confetti extends StatefulWidget {
  final bool visible; final VoidCallback? onComplete;
  const Confetti({super.key, required this.visible, this.onComplete});
  @override
  State<Confetti> createState() => _ConfettiState();
}

class _Petal {
  final double x, delay, dur, size, rot, sway; final Color color;
  _Petal(this.x, this.delay, this.dur, this.size, this.rot, this.sway, this.color);
}

class _ConfettiState extends State<Confetti> with SingleTickerProviderStateMixin {
  static const _colors = [Color(0xFFFFB74D), Color(0xFFFFA726), Color(0xFFFFD54F), Color(0xFFFF9800),
      Color(0xFFFFCA28), Color(0xFFFF7043), Color(0xFFFFE082), Color(0xFFF4511E)];
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 5200));
  late final List<_Petal> petals;
  @override
  void initState() {
    super.initState();
    final r = math.Random();
    petals = List.generate(65, (i) => _Petal(r.nextDouble(), r.nextDouble() * 1200, 2800 + r.nextDouble() * 2200,
        12 + r.nextDouble() * 18, r.nextDouble() * 6.28, 20 + r.nextDouble() * 40, _colors[r.nextInt(_colors.length)]));
    c.addStatusListener((s) { if (s == AnimationStatus.completed) widget.onComplete?.call(); });
    if (widget.visible) c.forward();
  }
  @override
  void didUpdateWidget(covariant Confetti old) {
    super.didUpdateWidget(old);
    if (widget.visible && !old.visible) c.forward(from: 0);
  }
  @override
  void dispose() { c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();
    return IgnorePointer(child: AnimatedBuilder(animation: c, builder: (_, __) => CustomPaint(
        size: MediaQuery.of(context).size, painter: _ConfettiPainter(petals, c.value * 5200))));
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<_Petal> petals; final double ms;
  _ConfettiPainter(this.petals, this.ms);
  @override
  void paint(Canvas canvas, Size s) {
    for (final p in petals) {
      final t = ((ms - p.delay) / p.dur).clampD(0.0, 1.0);
      if (t <= 0 || t >= 1) continue;
      final x = p.x * s.width + math.sin(t * 6.28 * 2 + p.rot) * p.sway;
      final y = -40 + t * (s.height + 80);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rot + t * 6);
      final paint = Paint()..color = p.color.withOpacity(t > 0.85 ? (1 - t) / 0.15 : 1);
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: p.size * 0.6, height: p.size), paint);
      canvas.restore();
    }
  }
  @override
  bool shouldRepaint(covariant _ConfettiPainter o) => true;
}

/// Shared helpers
Widget screenScroll({required Widget child, double maxWidth = 1100, EdgeInsets padding = const EdgeInsets.all(Sp.md)}) =>
    SingleChildScrollView(padding: padding, child: Center(child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child)));

Future<void> showInfoDialog(BuildContext context, String title, String message, {List<(String, VoidCallback?)>? actions}) =>
    showDialog(context: context, builder: (dialogCtx) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rad.xl)),
      title: Text(title, style: Fonts.display(20)),
      content: Text(message, style: Fonts.body(15, color: AppColors.textSecondary)),
      actions: [for (final a in (actions ?? [('OK', null)]))
        // Close the dialog with ITS OWN context: the caller's context resolves to the
        // tab's nested Navigator, so popping with it removed the screen under the
        // dialog (and, on a tab's root screen, emptied the Navigator -> crash).
        TextButton(onPressed: () { Navigator.of(dialogCtx).pop(); a.$2?.call(); },
            child: Text(a.$1, style: Fonts.body(15, w: FontWeight.w800, color: AppColors.primary)))],
    ));

/// White card with hairline border + toy shadow (used everywhere in the RN app).
class ToyCard extends StatelessWidget {
  final Widget child; final EdgeInsets padding; final double radius, shadow; final Color? color, borderColor; final double borderWidth;
  final VoidCallback? onTap; final EdgeInsets margin;
  const ToyCard({super.key, required this.child, this.padding = const EdgeInsets.all(Sp.md), this.radius = Rad.xl,
      this.shadow = 4, this.color, this.borderColor, this.borderWidth = 1, this.onTap, this.margin = EdgeInsets.zero});
  @override
  Widget build(BuildContext context) {
    final c = Container(
      margin: margin, padding: padding,
      decoration: BoxDecoration(color: color ?? AppColors.surface, borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: borderColor ?? AppColors.border, width: borderWidth),
          boxShadow: shadow > 0 ? toyShadow(AppColors.toyShadowColor, shadow) : null),
      child: child);
    return onTap == null ? c : Pressable(onTap: onTap, child: c);
  }
}

/// Rounded pill button, optionally filled with toy shadow.
class PillButton extends StatelessWidget {
  final String label; final IconData? icon; final VoidCallback? onTap; final bool filled; final Color? _color; final Color? shadowColor;
  Color get color => _color ?? AppColors.primary;
  const PillButton({super.key, required this.label, this.icon, this.onTap, this.filled = false,
      Color? color, this.shadowColor}) : _color = color;
  @override
  Widget build(BuildContext context) {
    final fg = filled ? AppColors.textOnPrimary : color;
    return Opacity(
      opacity: onTap == null ? 0.4 : 1,
      child: Pressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: Sp.lg, vertical: Sp.sm + 4),
          decoration: BoxDecoration(
            gradient: filled ? toneGradient(color) : null,
            color: filled ? null : AppColors.surface, borderRadius: BorderRadius.circular(9999),
            border: filled ? null : Border.all(color: color.withOpacity(0.55), width: 2),
            boxShadow: filled ? toyShadow(shadowColor ?? shade(color), 4) : toyShadow(AppColors.toyShadowColor, 2)),
          child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
            if (icon != null) ...[Icon(icon, size: 20, color: fg), const SizedBox(width: Sp.xs)],
            Flexible(child: Text(label, style: Fonts.body(16, w: filled ? FontWeight.w800 : FontWeight.w700, color: fg))),
          ]),
        ),
      ),
    );
  }
}

/// Small soft-tinted pill with an icon + text ("Hear" buttons).
class SoftPill extends StatelessWidget {
  final IconData? icon; final String? label; final VoidCallback? onTap; final Color? _color; final double size;
  Color get color => _color ?? AppColors.primary;
  const SoftPill({super.key, this.icon, this.label, this.onTap, Color? color, this.size = 16}) : _color = color;
  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: label == null ? 8 : Sp.md, vertical: label == null ? 8 : 7),
          decoration: BoxDecoration(color: color.withOpacity(0.11), borderRadius: BorderRadius.circular(9999),
              border: Border.all(color: color.withOpacity(0.18))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) Icon(icon, size: size, color: color),
            if (icon != null && label != null) const SizedBox(width: 4),
            if (label != null) Flexible(child: Text(label!, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: Fonts.body(12, w: FontWeight.w700, color: color))),
          ]),
        ),
      );
}

/// utils/confirm.ts — promise-based confirmation dialog.
Future<bool> confirmDialog(BuildContext context, {required String title, String? message, String confirmLabel = 'OK',
    String cancelLabel = 'Cancel', bool destructive = false}) async {
  final r = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
    backgroundColor: AppColors.surface,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rad.xl)),
    title: Text(title, style: Fonts.display(20)),
    content: message == null ? null : Text(message, style: Fonts.body(15, color: AppColors.textSecondary)),
    actions: [
      TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(cancelLabel, style: Fonts.body(15, w: FontWeight.w800, color: AppColors.primary))),
      TextButton(onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirmLabel, style: Fonts.body(15, w: FontWeight.w800, color: destructive ? AppColors.error : AppColors.primary))),
    ],
  ));
  return r ?? false;
}

/// Springy entrance (fade + rise + scale) for result cards and popups, so they
/// don't snap onto the screen. Give it a new [key] to replay it.
class PopIn extends StatelessWidget {
  final Widget child; final int delayMs; final Duration duration;
  const PopIn({super.key, required this.child, this.delayMs = 0, this.duration = const Duration(milliseconds: 520)});
  @override
  Widget build(BuildContext context) {
    final total = duration + Duration(milliseconds: delayMs);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      builder: (_, v, child) {
        final start = delayMs / total.inMilliseconds;
        final t = ((v - start) / (1 - start)).clampD(0.0, 1.0);
        final e = Curves.easeOutBack.transform(t);
        return Opacity(
          opacity: Curves.easeOut.transform(t),
          child: Transform.translate(offset: Offset(0, 28 * (1 - e)), child: Transform.scale(scale: 0.88 + 0.12 * e, child: child)),
        );
      },
      child: child,
    );
  }
}

/// Dimmed backdrop that fades in behind a [PopIn] card (result overlays).
class PopupBackdrop extends StatelessWidget {
  final Widget child;
  const PopupBackdrop({super.key, required this.child});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 260),
        builder: (_, v, c) => Container(color: Colors.black.withOpacity(0.45 * v), alignment: Alignment.center,
            padding: const EdgeInsets.all(Sp.lg), child: c),
        child: PopIn(delayMs: 80, child: child),
      );
}

/// One stat tile ("8/10 · Correct") for result cards.
class StatTile extends StatelessWidget {
  final String value, label;
  const StatTile(this.value, this.label, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: Sp.md, horizontal: Sp.sm),
        decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [AppColors.primary.withOpacity(0.10), AppColors.primary.withOpacity(0.04)]),
            borderRadius: BorderRadius.circular(Rad.lg),
            border: Border.all(color: AppColors.primary.withOpacity(0.18))),
        child: Column(children: [
          Text(value, style: Fonts.display(20, color: AppColors.primary)),
          Text(label.toUpperCase(), textAlign: TextAlign.center,
              style: Fonts.body(11, w: FontWeight.w800, color: AppColors.textSecondary).copyWith(letterSpacing: 0.4)),
        ]),
      );
}

/// Session-complete card shared by every practice screen: emoji badge, title,
/// stars, stats, a message and the two actions — animated in piece by piece.
class SessionCompleteCard extends StatelessWidget {
  final String emoji, title; final String? message;
  final int stars; final List<(String, String)> stats;
  final String retryLabel, doneLabel;
  final VoidCallback onRetry, onDone;
  final Widget? extra;
  const SessionCompleteCard({super.key, required this.emoji, required this.title, required this.stars,
      this.stats = const [], this.message, this.retryLabel = 'Try Again', this.doneLabel = 'Back to Menu',
      required this.onRetry, required this.onDone, this.extra});

  @override
  Widget build(BuildContext context) => Center(child: SingleChildScrollView(
        padding: const EdgeInsets.all(Sp.lg),
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 380), child: PopIn(child: Container(
          padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.xl, Sp.lg, Sp.lg),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(Rad.xl2),
              border: Border.all(color: AppColors.border), boxShadow: softShadow(AppColors.primary)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            PopIn(delayMs: 120, child: Container(
              width: 92, height: 92, alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [AppColors.starGold.withOpacity(0.45), AppColors.primary.withOpacity(0.12)])),
              child: Text(emoji, style: const TextStyle(fontSize: 52)),
            )),
            const SizedBox(height: Sp.md),
            Text(title, textAlign: TextAlign.center, style: Fonts.display(24)),
            const SizedBox(height: Sp.sm),
            StarRating(stars: stars, size: 44),
            if (stats.isNotEmpty) Padding(
              padding: const EdgeInsets.only(top: Sp.lg),
              child: Row(children: [
                for (int i = 0; i < stats.length; i++) ...[
                  if (i > 0) const SizedBox(width: Sp.sm),
                  Expanded(child: PopIn(delayMs: 250 + i * 90, child: StatTile(stats[i].$1, stats[i].$2))),
                ],
              ]),
            ),
            if (extra != null) Padding(padding: const EdgeInsets.only(top: Sp.md), child: extra!),
            if (message != null) Padding(
              padding: const EdgeInsets.only(top: Sp.md),
              child: Text(message!, textAlign: TextAlign.center, style: Fonts.body(15, w: FontWeight.w600, color: AppColors.textSecondary)),
            ),
            const SizedBox(height: Sp.lg),
            PopIn(delayMs: 420, child: Row(children: [
              Expanded(child: ResultButton(label: retryLabel, icon: Icons.refresh, filled: false, onTap: onRetry)),
              const SizedBox(width: Sp.sm),
              Expanded(child: ResultButton(label: doneLabel, icon: Icons.home_rounded, filled: true, onTap: onDone)),
            ])),
          ]),
        ))),
      ));
}

/// Rounded pill used for result actions (filled = primary, outline = secondary).
class ResultButton extends StatelessWidget {
  final String label; final IconData icon; final bool filled; final VoidCallback? onTap; final Color? _color;
  Color get color => _color ?? AppColors.primary;
  const ResultButton({super.key, required this.label, required this.icon, this.filled = true, this.onTap,
      Color? color}) : _color = color;
  @override
  Widget build(BuildContext context) => Opacity(
        opacity: onTap == null ? 0.45 : 1,
        child: Pressable(
          onTap: onTap,
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: Sp.sm),
            decoration: BoxDecoration(
              gradient: filled ? toneGradient(color) : null,
              color: filled ? null : AppColors.surface,
              borderRadius: BorderRadius.circular(9999),
              border: filled ? null : Border.all(color: color.withOpacity(0.6), width: 2),
              boxShadow: filled ? toyShadow(shade(color), 4) : toyShadow(AppColors.toyShadowColor, 2),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: label.isEmpty ? 22 : 18, color: filled ? AppColors.textOnPrimary : color),
              // An empty label makes a compact icon-only button.
              if (label.isNotEmpty) ...[
                const SizedBox(width: 6),
                Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: Fonts.body(15, w: FontWeight.w800, color: filled ? AppColors.textOnPrimary : color))),
              ],
            ]),
          ),
        ),
      );
}

/// Points each criterion adds to the final score (score × weight × 100),
/// rounded so they sum exactly to [weightedAverage] (largest remainder).
List<int> criterionPoints(List<Criterion> cs) {
  final exact = [for (final c in cs) c.score.clampD(0.0, 1.0) * c.weight * 100];
  final out = [for (final e in exact) e.floor()];
  final target = weightedAverage(cs);
  final order = List.generate(cs.length, (i) => i)..sort((a, b) => (exact[b] - out[b]).compareTo(exact[a] - out[a]));
  var missing = target - out.fold<int>(0, (a, b) => a + b);
  for (final i in order) {
    if (missing <= 0) break;
    out[i]++;
    missing--;
  }
  return out;
}

/// Per-attempt breakdown of the grade, so the child sees *why* they got their
/// score: every criterion with its percentage and, in the detailed style, how
/// many of the 100 points it earned, then any adjustment, then the total.
/// The numbers always add up to the score shown on the card.
class ScoreBreakdown extends StatelessWidget {
  final EvaluationResult r;
  /// Compact: a row of chips instead of bars and the points column.
  final bool compact;
  const ScoreBreakdown(this.r, {super.key, this.compact = false});

  static Color _tone(double v) => v >= 0.8 ? AppColors.success : v >= 0.6 ? AppColors.warning : AppColors.error;

  @override
  Widget build(BuildContext context) {
    final cs = r.criteria;
    if (compact) {
      return Wrap(alignment: WrapAlignment.center, spacing: 6, runSpacing: 6, children: [
        for (final c in cs) Container(
          padding: const EdgeInsets.symmetric(horizontal: Sp.sm, vertical: 4),
          decoration: BoxDecoration(color: _tone(c.score).withOpacity(0.12), borderRadius: BorderRadius.circular(9999)),
          child: Text('${c.label} ${c.percent}%', style: Fonts.body(12, w: FontWeight.w800, color: AppColors.textPrimary)),
        ),
        for (final a in r.adjustments) Text('${a.reason} (${a.points > 0 ? '+' : '−'}${a.points.abs()})',
            style: Fonts.body(12, w: FontWeight.w700, color: AppColors.textSecondary)),
      ]);
    }
    final pts = criterionPoints(cs);
    final small = Fonts.body(11, w: FontWeight.w700, color: AppColors.textMuted);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: Text('How your score adds up', style: Fonts.body(13, w: FontWeight.w800))),
        SizedBox(width: 64, child: Text('points', textAlign: TextAlign.right, style: small)),
      ]),
      const SizedBox(height: 4),
      for (int i = 0; i < cs.length; i++) Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          SizedBox(width: 112, child: Text(cs[i].label, style: Fonts.body(12, w: FontWeight.w700, color: AppColors.textSecondary))),
          Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(9999), child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: cs[i].score.clampD(0.0, 1.0)), duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (_, x, __) => LinearProgressIndicator(value: x, minHeight: 8, backgroundColor: AppColors.muted, color: _tone(x)),
          ))),
          SizedBox(width: 40, child: Text('${cs[i].percent}%', textAlign: TextAlign.right,
              style: Fonts.body(12, w: FontWeight.w800, color: AppColors.textPrimary))),
          SizedBox(width: 64, child: Text('${pts[i]}/${(cs[i].weight * 100).round()}', textAlign: TextAlign.right, style: small)),
        ]),
      ),
      for (final a in r.adjustments) Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Row(children: [
          Icon(a.points >= 0 ? Icons.add_circle_outline : Icons.remove_circle_outline, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Expanded(child: Text(a.reason, style: Fonts.body(12, w: FontWeight.w700, color: AppColors.textSecondary))),
          SizedBox(width: 64, child: Text('${a.points >= 0 ? '+' : '−'}${a.points.abs()}', textAlign: TextAlign.right,
              style: Fonts.body(12, w: FontWeight.w800, color: AppColors.textSecondary))),
        ]),
      ),
      Divider(height: 12, color: AppColors.border),
      Row(children: [
        Expanded(child: Text('Accuracy', style: Fonts.body(13, w: FontWeight.w800))),
        Text('${r.accuracy}%', style: Fonts.body(13, w: FontWeight.w800, color: AppColors.primaryDark)),
      ]),
    ]);
  }
}

/// Shown under a result below [kTipsThreshold]: why the score is what it is,
/// up to three concrete fixes (biggest point loss first), and buttons to try
/// again straight away or look at the model.
class ImprovementPanel extends StatelessWidget {
  final List<ImprovementTip> tips;
  final VoidCallback? onRetry, onShowModel;
  /// A small picture of the model letter (stroke colours match the tips).
  final Widget? reference;
  const ImprovementPanel({super.key, required this.tips, this.onRetry, this.onShowModel, this.reference});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(Sp.md),
        decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.07), borderRadius: BorderRadius.circular(Rad.lg),
            border: Border.all(color: AppColors.primary.withOpacity(0.25))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.auto_awesome, size: 18, color: AppColors.primary),
            const SizedBox(width: Sp.xs),
            Expanded(child: Text("You're close — here's how to make it clearer",
                style: Fonts.body(14, w: FontWeight.w800, color: AppColors.primaryDark))),
            if (reference != null) Container(
              width: 64, height: 64, margin: const EdgeInsets.only(left: Sp.sm),
              decoration: BoxDecoration(color: AppColors.canvasBackground, borderRadius: BorderRadius.circular(Rad.md),
                  border: Border.all(color: AppColors.border)),
              clipBehavior: Clip.antiAlias,
              child: reference,
            ),
          ]),
          const SizedBox(height: Sp.sm),
          if (tips.isEmpty)
            Text('Write it slowly once more, following the model.', style: Fonts.body(13, color: AppColors.textSecondary)),
          for (int i = 0; i < tips.length; i++) Padding(
            padding: const EdgeInsets.only(bottom: Sp.sm),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 22, height: 22, alignment: Alignment.center,
                decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                child: Text('${i + 1}', style: Fonts.body(12, w: FontWeight.w800, color: AppColors.textOnPrimary)),
              ),
              const SizedBox(width: Sp.sm),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tips[i].title, style: Fonts.body(13.5, w: FontWeight.w800)),
                Text(tips[i].detail, style: Fonts.body(13, color: AppColors.textSecondary, height: 1.35)),
                Text('${tips[i].criterion} · cost ${tips[i].pointsLost} points',
                    style: Fonts.body(11, w: FontWeight.w700, color: AppColors.textMuted)),
              ])),
            ]),
          ),
          if (onRetry != null || onShowModel != null) Row(children: [
            if (onShowModel != null) Expanded(child: ResultButton(label: 'Show model', icon: Icons.visibility_outlined,
                filled: false, onTap: onShowModel)),
            if (onShowModel != null && onRetry != null) const SizedBox(width: Sp.sm),
            if (onRetry != null) Expanded(child: ResultButton(label: 'Try again', icon: Icons.refresh, onTap: onRetry)),
          ]),
        ]),
      );
}

/// Live 0-100 % accuracy meter shown under the drawing canvas, with the stars
/// the current drawing would earn. Recomputes only when a stroke completes /
/// is undone / cleared (via [DrawController.strokeVersion]) — never on raw
/// pointer-move — and uses the same scorer as the final grade, so the number
/// the child sees while writing matches the result screen.
class TracingMeter extends StatelessWidget {
  final DrawController controller;
  final String letterId;
  final double canvasSize;
  /// Extra percentage points added to the score (e.g. the "From Memory" bonus).
  final int bonus;
  const TracingMeter({super.key, required this.controller, required this.letterId, this.canvasSize = 340, this.bonus = 0});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
        valueListenable: controller.strokeVersion,
        builder: (_, __, ___) {
          int pctInt = 0;
          if (!controller.isEmpty) {
            try {
              pctInt = (evaluateStrokes(controller.strokes, letterId, canvasSize).accuracy + bonus).clamp(0, 100);
            } catch (_) {
              pctInt = 0;
            }
          }
          final pct = pctInt / 100;
          final stars = controller.isEmpty ? 0 : starsForAccuracy(pctInt);
          final color = pct >= 0.7 ? AppColors.success : (pct >= 0.5 ? AppColors.warning : AppColors.primary);
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.sm),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(Rad.lg),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(children: [
              Text('Accuracy', style: Fonts.body(13, w: FontWeight.w700, color: AppColors.textSecondary)),
              const SizedBox(width: Sp.sm),
              Expanded(child: ClipRRect(
                borderRadius: BorderRadius.circular(9999),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: pct.clampD(0.0, 1.0)),
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, __) => Stack(children: [
                    Container(height: 10, color: AppColors.muted),
                    FractionallySizedBox(
                      widthFactor: v,
                      child: Container(height: 10, color: color),
                    ),
                  ]),
                ),
              )),
              const SizedBox(width: Sp.sm),
              SizedBox(
                width: 40,
                child: Text('$pctInt%',
                    textAlign: TextAlign.right, style: Fonts.body(13, w: FontWeight.w800, color: color)),
              ),
              const SizedBox(width: Sp.xs),
              for (int k = 1; k <= 3; k++)
                Icon(stars >= k ? Icons.star : Icons.star_border, size: 16,
                    color: stars >= k ? AppColors.starGold : AppColors.starEmpty),
            ]),
          );
        },
      );
}
