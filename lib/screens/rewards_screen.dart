import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/badges.dart';
import '../services/feedback.dart';
import '../store/app_store.dart';
import '../theme/app_theme.dart';
import '../theme/palette.dart';
import '../widgets/badge_reveal.dart';
import '../widgets/common.dart';
import '../widgets/icons.dart';

/// RewardsScreen.tsx — badge grid with per-badge progress, category tabs,
/// a detail sheet on tap and an unlock animation the first time a badge is earned.
class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});
  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  BadgeInfo? reveal;
  bool confetti = false;
  String category = 'All';
  bool _checkScheduled = false;

  /// Plays the unlock animation for a badge earned since the last visit.
  void _checkNewlyEarned(AppStore s) {
    // Tabs stay alive offstage; TickerMode is only enabled for the visible tab,
    // and depending on it rebuilds this screen when the child switches to it.
    if (!TickerMode.valuesOf(context).enabled || _checkScheduled) return;
    final fresh = badgeDefs.where((d) => d.earned(s) && !s.seenBadges.contains(d.info.id)).toList();
    if (fresh.isEmpty) return;
    _checkScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkScheduled = false;
      if (!mounted) return;
      s.markBadgesSeen(fresh.map((d) => d.info.id));
      hapticHeavy();
      setState(() { reveal = fresh.first.info; confetti = true; });
    });
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild only when a field that can flip a badge's progress changes.
    context.select<AppStore, (int, int, int, int, int, int, int)>((store) => (
          store.totalStars, store.totalPoints, store.currentStreak, store.todayPracticeCount, store.letterProgress.length,
          store.masteredCount, store.pinnedBadges.length,
        ));
    final s = context.read<AppStore>();
    _checkNewlyEarned(s);
    final w = MediaQuery.of(context).size.width;
    final cols = w >= 1024 ? 4 : w >= 600 ? 3 : 2;
    final maxW = w >= 1440 ? 1100.0 : w >= 1024 ? 960.0 : w >= 768 ? 720.0 : w;
    final shown = badgeDefs.where((d) => category == 'All' || d.category == category).toList();
    final earnedCount = badgeDefs.where((d) => d.earned(s)).length;
    return Container(color: AppColors.background, child: SafeArea(bottom: false, child: Stack(children: [
      SingleChildScrollView(padding: const EdgeInsets.all(Sp.md), child: Center(child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Rewards', textAlign: TextAlign.center, style: Fonts.display(32, color: AppColors.textPrimary, w: FontWeight.w800)),
          Padding(padding: const EdgeInsets.only(bottom: Sp.lg), child: Text('पुरस्कार', textAlign: TextAlign.center,
              style: Fonts.hindi(20, color: AppColors.secondary))),
          Container(
            margin: const EdgeInsets.only(bottom: Sp.lg), padding: const EdgeInsets.all(Sp.lg),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(Rad.xl), border: Border.all(color: AppColors.border),
                boxShadow: toyShadow(AppColors.toyShadowColor, 4)),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _stat(Icons.star, AppColors.starGold, '${s.totalStars}', 'Stars'),
              _stat(Icons.emoji_events, AppColors.secondary, '${s.totalPoints}', 'Points'),
              _stat(Icons.workspace_premium, AppColors.primary, '$earnedCount/${badgeDefs.length}', 'Badges'),
            ]),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(bottom: Sp.md),
            child: Row(children: [
              for (final c in badgeCategories) Padding(
                padding: const EdgeInsets.only(right: Sp.sm),
                child: GestureDetector(
                  onTap: () => setState(() => category = c),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.xs + 2),
                    decoration: BoxDecoration(
                      color: category == c ? AppColors.primary : AppColors.surface,
                      borderRadius: BorderRadius.circular(9999),
                      border: Border.all(color: category == c ? AppColors.primary : AppColors.border),
                      boxShadow: category == c ? toyShadow(AppColors.primaryDark, 3) : null),
                    child: Text(c, style: Fonts.body(13, w: FontWeight.w800,
                        color: category == c ? AppColors.textOnPrimary : AppColors.textSecondary)),
                  ),
                ),
              ),
            ]),
          ),
          // Cards have a minimum height and grow with their text, so they never overflow.
          for (var r = 0; r < shown.length; r += cols) Padding(
            padding: const EdgeInsets.only(bottom: Sp.sm),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (var c = 0; c < cols; c++) ...[
                if (c > 0) const SizedBox(width: Sp.sm),
                Expanded(child: r + c < shown.length ? _badgeCard(shown[r + c], s) : const SizedBox()),
              ],
            ]),
          ),
          const SizedBox(height: Sp.xl),
        ]),
      ))),
      BadgeReveal(badge: reveal, visible: reveal != null, onDismiss: () => setState(() { reveal = null; confetti = false; })),
      Positioned.fill(child: Confetti(visible: confetti, onComplete: () => setState(() => confetti = false))),
    ])));
  }

  Widget _stat(IconData i, Color c, String n, String label) => Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(i, size: 28, color: c), const SizedBox(height: Sp.xs),
        Text(n, style: Fonts.display(24, color: AppColors.textPrimary, w: FontWeight.w800)),
        const SizedBox(height: Sp.xs),
        Text(label, style: Fonts.body(12, w: FontWeight.w600, color: AppColors.textSecondary)),
      ]);

  Widget _badgeCard(BadgeDef d, AppStore s) {
    final b = d.info;
    final p = d.progress(s);
    final earned = p.complete;
    final pinned = s.pinnedBadges.contains(b.id);
    return GestureDetector(
      onTap: () => _showDetails(d),
      child: Container(
        constraints: const BoxConstraints(minHeight: 200),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(Sp.md),
        decoration: BoxDecoration(
            color: earned ? AppColors.surface : AppColors.background,
            borderRadius: BorderRadius.circular(Rad.xl),
            border: Border.all(color: earned ? b.color.withOpacity(0.6) : AppColors.border, width: earned ? 2 : 1),
            boxShadow: toyShadow(AppColors.toyShadowColor, earned ? 4 : 2)),
        child: Stack(children: [
          Column(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(width: double.infinity), // full card width, so the pin sits in the corner
            SizedBox(width: 64, height: 64, child: Stack(alignment: Alignment.center, children: [
              SizedBox(width: 64, height: 64, child: CircularProgressIndicator(
                value: earned ? 1 : p.fraction, strokeWidth: 5,
                backgroundColor: AppColors.muted,
                color: earned ? b.color : AppColors.disabled)),
              Container(width: 48, height: 48, alignment: Alignment.center,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                      color: earned ? b.color.withOpacity(0.14) : const Color(0x0F000000)),
                  child: Icon(earned ? ionIcon(b.icon) : Icons.lock_outline, size: 26,
                      color: earned ? b.color : AppColors.disabled)),
            ])),
            const SizedBox(height: Sp.sm),
            Text(b.name, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                style: Fonts.body(14, w: FontWeight.w800, color: earned ? AppColors.textPrimary : AppColors.textSecondary)),
            const SizedBox(height: 2),
            Text(b.description, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                style: Fonts.body(11, color: AppColors.textSecondary, height: 15 / 11)),
            const SizedBox(height: Sp.xs),
            Text(earned ? 'Earned ✓' : p.tracked ? '${(p.fraction * 100).round()}% · ${p.left}' : p.left,
                maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                style: Fonts.body(11, w: FontWeight.w800, color: earned ? AppColors.success : AppColors.primaryDark)),
          ]),
          if (pinned) const Positioned(top: 0, right: 0, child: Icon(Icons.push_pin, size: 16, color: AppColors.primary)),
        ]),
      ),
    );
  }

  void _showDetails(BadgeDef d) {
    hapticLight();
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Rad.xl2))),
      builder: (ctx) => Consumer<AppStore>(builder: (ctx, s, _) {
        final b = d.info;
        final p = d.progress(s);
        final earned = p.complete;
        final pinned = s.pinnedBadges.contains(b.id);
        return SafeArea(child: Padding(
          padding: const EdgeInsets.fromLTRB(Sp.xl, Sp.lg, Sp.xl, Sp.xl),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: Sp.lg),
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
            Icon(ionIcon(b.icon), size: 56, color: earned ? b.color : AppColors.disabled),
            const SizedBox(height: Sp.sm),
            Text(b.name, style: Fonts.display(24)),
            Text(b.hindiName, style: Fonts.hindi(16, color: AppColors.textSecondary)),
            const SizedBox(height: Sp.sm),
            Text('What it is for: ${b.description}.', textAlign: TextAlign.center,
                style: Fonts.body(15, color: AppColors.textSecondary)),
            const SizedBox(height: Sp.lg),
            if (p.tracked) ...[
              ClipRRect(borderRadius: BorderRadius.circular(9999), child: LinearProgressIndicator(
                  value: p.fraction, minHeight: 12, backgroundColor: AppColors.muted, color: earned ? AppColors.success : b.color)),
              const SizedBox(height: Sp.sm),
              Text(earned ? 'Earned! 🎉' : '${p.done} / ${p.goal} — ${p.left} to earn it',
                  textAlign: TextAlign.center, style: Fonts.body(15, w: FontWeight.w800, color: AppColors.primaryDark)),
            ] else
              Text('This badge is not tracked yet — coming soon!', textAlign: TextAlign.center,
                  style: Fonts.body(14, w: FontWeight.w700, color: AppColors.textMuted)),
            if (earned) ...[
              const SizedBox(height: Sp.lg),
              Row(children: [
                Expanded(child: PillButton(
                    label: pinned ? 'Unpin from Profile' : 'Pin to Profile', icon: Icons.push_pin_outlined,
                    onTap: () => s.togglePinnedBadge(b.id))),
                const SizedBox(width: Sp.sm),
                Expanded(child: PillButton(label: 'Celebrate', icon: Icons.celebration, filled: true, onTap: () {
                  Navigator.of(ctx).pop();
                  setState(() { reveal = b; confetti = true; });
                })),
              ]),
            ],
          ]),
        ));
      }),
    );
  }
}
