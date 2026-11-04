import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/models.dart';
import '../l10n.dart';
import '../routes.dart';
import '../screens/accounts/account_widgets.dart';
import '../store/app_store.dart';
import '../theme/app_theme.dart';
import '../theme/palette.dart';
import 'hindi_name.dart';

/// Drop-down card that opens under the avatar on Home: the learner's score
/// (stars, streak, letters) and every account action in one place.
Future<void> showProfileMenu(BuildContext context, GlobalKey anchorKey) {
  final box = anchorKey.currentContext?.findRenderObject() as RenderBox?;
  final origin = box?.localToGlobal(Offset.zero) ?? const Offset(16, 60);
  final anchorH = box?.size.height ?? 52;
  return showGeneralDialog(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierLabel: 'Close profile menu',
    barrierColor: Colors.black.withOpacity(0.12),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (ctx, _, __) {
      final size = MediaQuery.sizeOf(ctx);
      const w = 320.0;
      final left = origin.dx.clamp(12.0, (size.width - w - 12).clamp(12.0, double.infinity));
      final top = origin.dy + anchorH + 8;
      return Stack(children: [
        Positioned(left: left, top: top, width: (size.width - 24).clamp(0, w),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: size.height - top - 12),
              child: _ProfileMenuCard(hostContext: context),
            )),
      ]);
    },
    transitionBuilder: (ctx, anim, _, child) {
      final a = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(opacity: a, child: ScaleTransition(
          scale: Tween(begin: 0.96, end: 1.0).animate(a), alignment: Alignment.topLeft, child: child));
    },
  );
}

class _ProfileMenuCard extends StatelessWidget {
  /// The Home screen's context: actions run there after the menu closes.
  final BuildContext hostContext;
  const _ProfileMenuCard({required this.hostContext});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    final total = AppData.allLetters.length;

    void run(void Function(BuildContext) action) {
      Navigator.of(context).pop();
      if (hostContext.mounted) action(hostContext);
    }

    return Material(
      type: MaterialType.transparency,
      borderRadius: BorderRadius.circular(Rad.xl),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(Rad.xl),
          border: Border.all(color: AppColors.border),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 30, offset: const Offset(0, 14))],
        ),
        child: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Who is signed in.
            Container(
              padding: const EdgeInsets.fromLTRB(Sp.md, Sp.md, Sp.md, Sp.sm),
              child: Row(children: [
                learnerAvatar(s.userName, s.avatar, size: 48),
                const SizedBox(width: Sp.sm + 4),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.userName.isEmpty ? tr('Learner', 'विद्यार्थी') : s.userName,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: Fonts.display(18, height: 1.15)),
                  HindiNameLine(color: AppColors.textSecondary, size: 14),
                ])),
              ]),
            ),
            // Score.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Sp.md),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(Rad.md)),
                child: IntrinsicHeight(child: Row(children: [
                  _Score(icon: Icons.star_rounded, color: AppColors.starGold, value: '${s.totalStars}',
                      label: tr('Stars', 'तारे')),
                  VerticalDivider(width: 1, color: AppColors.border),
                  _Score(icon: Icons.local_fire_department_rounded, color: AppColors.primary,
                      value: '${s.currentStreak}', label: tr('Day streak', 'दिन लगातार')),
                  VerticalDivider(width: 1, color: AppColors.border),
                  _Score(icon: Icons.school_rounded, color: const Color(0xFF138808),
                      value: '${s.masteredCount}/$total', label: tr('Letters', 'अक्षर')),
                ])),
              ),
            ),
            const SizedBox(height: Sp.sm),
            _Item(Icons.person_outline_rounded, tr('My profile', 'मेरी प्रोफ़ाइल'),
                () => run((c) => openScreen(c, 'Profile'))),
            _Item(Icons.emoji_events_outlined, tr('Rewards & badges', 'इनाम और बैज'),
                () => run((c) => openScreen(c, 'Rewards'))),
            _Item(Icons.leaderboard_outlined, tr('Leaderboard', 'लीडरबोर्ड'),
                () => run((c) => openScreen(c, 'Leaderboard'))),
            const _Rule(),
            _Item(Icons.switch_account_outlined, tr('Switch learner', 'विद्यार्थी बदलें'),
                () => run(showLearnerSwitcher)),
            _Item(Icons.family_restroom_rounded, tr('Parent zone', 'अभिभावक क्षेत्र'),
                () => run(openParentControl), trailing: Icons.lock_outline_rounded),
            const _Rule(),
            _Item(Icons.settings_outlined, tr('Settings', 'सेटिंग्स'),
                () => run((c) => openScreen(c, 'Settings'))),
            _Item(Icons.help_outline_rounded, tr('Help & support', 'सहायता'),
                () => run((c) => openScreen(c, 'HelpSupport'))),
            const SizedBox(height: Sp.xs),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              color: AppColors.background,
              child: Text('Made in India  ·  Developed by VoxCRE', textAlign: TextAlign.center,
                  style: Fonts.body(11.5, w: FontWeight.w700, color: AppColors.textSecondary)),
            ),
          ],
        )),
      ),
    );
  }
}

class _Score extends StatelessWidget {
  final IconData icon; final Color color; final String value, label;
  const _Score({required this.icon, required this.color, required this.value, required this.label});
  @override
  Widget build(BuildContext context) => Expanded(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 4),
          Text(value, style: Fonts.display(17, height: 1.1)),
        ]),
        const SizedBox(height: 2),
        Text(label, style: Fonts.body(11.5, w: FontWeight.w700, color: AppColors.textSecondary)),
      ]));
}

class _Item extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback onTap; final IconData? trailing;
  const _Item(this.icon, this.label, this.onTap, {this.trailing});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: 11),
          child: Row(children: [
            Icon(icon, size: 22, color: AppColors.textPrimary),
            const SizedBox(width: Sp.md),
            Expanded(child: Text(label, style: Fonts.body(15, w: FontWeight.w700))),
            Icon(trailing ?? Icons.chevron_right_rounded, size: 20, color: AppColors.textSecondary),
          ]),
        ),
      );
}

class _Rule extends StatelessWidget {
  const _Rule();
  @override
  Widget build(BuildContext context) =>
      Divider(height: 9, thickness: 1, indent: Sp.md, endIndent: Sp.md, color: AppColors.border);
}
