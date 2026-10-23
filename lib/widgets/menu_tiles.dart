import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/palette.dart';
import '../util/num_ext.dart';
import 'progress_bar.dart';
import 'toy_button.dart';

/// Gradient banner at the top of the Writing / Reading menus: icon, title,
/// subtitle, a row of stats and an optional progress bar.
class HeroBanner extends StatelessWidget {
  final Color color; final Widget icon; final String title, subtitle;
  final List<(String, String)> stats; final double? progress;
  const HeroBanner({super.key, required this.color, required this.icon, required this.title,
      required this.subtitle, this.stats = const [], this.progress});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.lg, Sp.lg, Sp.lg),
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color.lerp(color, Colors.white, 0.15)!, color, shade(color, 0.08)]),
          borderRadius: BorderRadius.circular(Rad.xl2),
          boxShadow: softShadow(color),
        ),
        // Clip so the decorative circles stay inside the rounded banner.
        clipBehavior: Clip.antiAlias,
        child: Stack(clipBehavior: Clip.none, children: [
          // Soft decorative circles.
          Positioned(right: -30, top: -40, child: _blob(120)),
          Positioned(right: 40, bottom: -50, child: _blob(80)),
          Column(children: [
            Row(children: [
              Container(width: 56, height: 56, alignment: Alignment.center,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.22), borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withOpacity(0.35))),
                  child: icon),
              const SizedBox(width: Sp.md),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: Fonts.hindi(28, color: Colors.white, height: 1.25)),
                Text(subtitle, style: Fonts.body(14, w: FontWeight.w700, color: Colors.white.withOpacity(0.9))),
              ])),
            ]),
            if (stats.isNotEmpty) ...[
              const SizedBox(height: Sp.md),
              Row(children: [
                for (int i = 0; i < stats.length; i++) ...[
                  if (i > 0) const SizedBox(width: Sp.sm),
                  Expanded(child: Container(
                    padding: const EdgeInsets.symmetric(vertical: Sp.sm),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(Rad.lg),
                        border: Border.all(color: Colors.white.withOpacity(0.25))),
                    child: Column(children: [
                      Text(stats[i].$1, style: Fonts.display(22, color: Colors.white, height: 1.1)),
                      Text(stats[i].$2, style: Fonts.body(12, w: FontWeight.w700, color: Colors.white.withOpacity(0.88))),
                    ]),
                  )),
                ],
              ]),
            ],
            if (progress != null) ...[
              const SizedBox(height: Sp.md),
              HsProgressBar(progress: progress!, height: 10, color: Colors.white, background: Colors.white.withOpacity(0.25)),
            ],
          ]),
        ]),
      );

  Widget _blob(double d) => Container(width: d, height: d,
      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.08)));
}

/// Collapsible section header (Vowels, Matra Practice, Odd One Out, ...):
/// gradient icon badge, title, subtitle, "done/total" chip and a thin
/// progress line along the bottom.
class SectionTile extends StatelessWidget {
  final Widget leading; final Color color; final String title, subtitle;
  final int done, total; final bool locked, open; final VoidCallback onTap;
  const SectionTile({super.key, required this.leading, required this.color, required this.title,
      required this.subtitle, required this.done, this.total = 10, required this.locked, required this.open, required this.onTap});
  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.only(top: Sp.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(Rad.xl),
            border: Border.all(color: open ? color.withOpacity(0.5) : AppColors.border, width: open ? 1.5 : 1),
            boxShadow: toyShadow(AppColors.toyShadowColor, open ? 6 : 4),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Sp.md, Sp.md, Sp.sm, Sp.md),
              child: Row(children: [
                Container(width: 52, height: 52, alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                          colors: [color.withOpacity(0.16), color.withOpacity(0.30)]),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: leading),
                const SizedBox(width: Sp.md),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Fonts.display(18, height: 1.2)),
                  const SizedBox(height: 2),
                  Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: Fonts.body(12, w: FontWeight.w600, color: AppColors.textSecondary)),
                ])),
                if (locked) Container(
                  margin: const EdgeInsets.only(right: 6), padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(color: AppColors.secondary.withOpacity(0.12), shape: BoxShape.circle),
                  child: const Icon(Icons.lock_rounded, size: 13, color: AppColors.secondary),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(gradient: toneGradient(color), borderRadius: BorderRadius.circular(9999)),
                  child: Text('$done/$total', style: Fonts.body(12, w: FontWeight.w800, color: Colors.white)),
                ),
                AnimatedRotation(
                  turns: open ? 0.5 : 0, duration: const Duration(milliseconds: 220),
                  child: const Icon(Icons.keyboard_arrow_down_rounded, size: 26, color: AppColors.textSecondary),
                ),
              ]),
            ),
            // Section progress, full width along the bottom edge.
            Container(height: 4, color: color.withOpacity(0.12), alignment: Alignment.centerLeft,
                child: FractionallySizedBox(widthFactor: total == 0 ? 0 : (done / total).clampD(0.0, 1.0),
                    child: Container(decoration: BoxDecoration(gradient: toneGradient(color))))),
          ]),
        ),
      );
}

/// One level row inside a section: number badge (✓ when done, 🔒 when
/// locked), the level's details, and a round play button.
class LevelTile extends StatelessWidget {
  final int number; final Color color; final bool isLocked, completed; final Widget info; final VoidCallback onTap;
  const LevelTile({super.key, required this.number, required this.color, required this.isLocked,
      required this.completed, required this.info, required this.onTap});
  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(left: Sp.sm),
          padding: const EdgeInsets.all(Sp.md),
          decoration: BoxDecoration(
            color: isLocked ? AppColors.muted.withOpacity(0.55) : AppColors.surface,
            borderRadius: BorderRadius.circular(Rad.lg),
            border: Border.all(color: completed ? color.withOpacity(0.6) : AppColors.border, width: completed ? 1.5 : 1),
            boxShadow: isLocked ? null : toyShadow(AppColors.toyShadowColor, 3),
          ),
          child: Row(children: [
            Container(width: 44, height: 44, alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: isLocked ? null : completed ? toneGradient(AppColors.success) : toneGradient(color),
                  color: isLocked ? const Color(0xFFE2DACB) : null,
                  boxShadow: isLocked ? null : toyShadow(shade(completed ? AppColors.success : color), 3),
                ),
                child: isLocked
                    ? const Icon(Icons.lock_rounded, size: 18, color: Color(0xFF9C8F7A))
                    : completed ? const Icon(Icons.check_rounded, size: 24, color: Colors.white)
                    : Text('$number', style: Fonts.display(19, color: Colors.white))),
            const SizedBox(width: Sp.md),
            Expanded(child: Opacity(opacity: isLocked ? 0.65 : 1, child: info)),
            if (!isLocked) Container(
              margin: const EdgeInsets.only(left: Sp.sm),
              width: 38, height: 38,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.12)),
              child: Icon(Icons.play_arrow_rounded, size: 26, color: color),
            ),
          ]),
        ),
      );
}

/// Small coloured label on a level ("⚡ TIMED", "👑 BOSS").
class LevelTag extends StatelessWidget {
  final String text; final Color color;
  const LevelTag(this.text, this.color, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: color.withOpacity(0.13), borderRadius: BorderRadius.circular(9999),
            border: Border.all(color: color.withOpacity(0.25))),
        child: Text(text, style: Fonts.body(9, w: FontWeight.w800, color: shade(color, 0.1)).copyWith(letterSpacing: 0.4)),
      );
}

/// Why a level is locked ("Complete Level 2 first").
class LevelHint extends StatelessWidget {
  final String text; final Color color;
  const LevelHint(this.text, this.color, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 6), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(9999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.lock_outline_rounded, size: 12, color: color),
          const SizedBox(width: 4),
          Flexible(child: Text(text, style: Fonts.body(11, w: FontWeight.w700, color: color))),
        ]),
      );
}

/// A level's progress bar and its 3 stars.
class LevelStars extends StatelessWidget {
  final Color color; final double ratio; final List<bool> filled;
  const LevelStars({super.key, required this.color, required this.ratio, required this.filled});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(children: [
          Expanded(child: HsProgressBar(progress: ratio, height: 6, color: color)),
          const SizedBox(width: Sp.sm),
          for (final f in filled) Icon(f ? Icons.star_rounded : Icons.star_outline_rounded, size: 17,
              color: f ? AppColors.starGold : const Color(0xFFD6CCB8)),
        ]),
      );
}
