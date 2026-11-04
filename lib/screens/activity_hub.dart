import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/models.dart';
import '../l10n.dart';
import '../routes.dart';
import '../store/app_store.dart';
import '../theme/app_theme.dart';
import '../theme/palette.dart';
import '../widgets/menu_tiles.dart';
import '../widgets/toy_button.dart';

/// One card on a hub: opens [screen]. When the screen belongs to an activity
/// with levels, tapping first asks which level to play.
class HubItem {
  final String screen, emoji, title, hindi, desc;
  final Color color;
  const HubItem(this.screen, this.emoji, this.title, this.hindi, this.desc, this.color);
}

/// Shared layout for the Practice and Test tabs: a banner, then groups of
/// activity cards (one column on phones, two on wide screens).
class ActivityHub extends StatelessWidget {
  final Color color; final IconData icon; final String title, subtitle, intro;
  final List<(String, List<HubItem>)> groups;
  const ActivityHub({super.key, required this.color, required this.icon, required this.title,
      required this.subtitle, required this.intro, required this.groups});

  @override
  Widget build(BuildContext context) {
    final count = groups.fold<int>(0, (n, g) => n + g.$2.length);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Sp.md, Sp.md, Sp.md, Sp.xxl),
          child: Center(child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              HeroBanner(color: color, icon: Icon(icon, size: 30, color: Colors.white),
                  title: title, subtitle: subtitle, stats: [('$count', tr('Activities', 'गतिविधियाँ'))]),
              Padding(
                padding: const EdgeInsets.fromLTRB(Sp.xs, Sp.md, Sp.xs, 0),
                child: Text(intro, style: Fonts.body(14, w: FontWeight.w600, color: AppColors.textSecondary, height: 1.4)),
              ),
              for (final g in groups) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(Sp.xs, Sp.lg, Sp.xs, Sp.sm),
                  child: Text(g.$1, style: Fonts.display(20)),
                ),
                LayoutBuilder(builder: (_, c) {
                  final cols = c.maxWidth >= 700 ? 2 : 1;
                  final w = (c.maxWidth - Sp.md * (cols - 1)) / cols;
                  return Wrap(spacing: Sp.md, runSpacing: Sp.md, children: [
                    for (final item in g.$2) SizedBox(width: w, child: _HubCard(item)),
                  ]);
                }),
              ],
            ]),
          )),
        ),
      ),
    );
  }
}

ActivityDef? _activityFor(String screen) {
  for (final a in [...AppData.writingActivities, ...AppData.readingActivities]) {
    if (a.screen == screen) return a;
  }
  return null;
}

void openHubItem(BuildContext context, HubItem item) {
  final a = _activityFor(item.screen);
  if (a == null) {
    openScreen(context, item.screen);
    return;
  }
  showModalBottomSheet(
    context: context, useRootNavigator: true, isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Rad.xl2))),
    builder: (ctx) {
      final s = ctx.read<AppStore>();
      return SafeArea(child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.75),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Sp.lg),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('${item.emoji}  ${item.title}', style: Fonts.display(22)),
            Text(tr('Pick a level', 'स्तर चुनें'), style: Fonts.body(14, w: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: Sp.md),
            Wrap(spacing: Sp.sm, runSpacing: Sp.sm, children: [
              for (int i = 0; i < a.levels.length; i++) Builder(builder: (_) {
                final lvl = a.levels[i];
                final st = AppData.activityLevelState(a.id, i, s.activityProgress);
                return Pressable(
                  onTap: () {
                    Navigator.of(ctx).pop();
                    openScreen(context, a.screen, {
                      'levelId': lvl.id, 'levelName': lvl.name, 'levelNumber': lvl.level,
                      'activityId': a.id, ...lvl.params,
                    });
                  },
                  child: Container(
                    width: 150, padding: const EdgeInsets.all(Sp.sm + 2),
                    decoration: BoxDecoration(
                      color: st.completed ? AppColors.success.withOpacity(0.10) : AppColors.background,
                      borderRadius: BorderRadius.circular(Rad.lg),
                      border: Border.all(color: st.completed ? AppColors.success : AppColors.border)),
                    child: Row(children: [
                      Container(width: 30, height: 30, alignment: Alignment.center,
                          decoration: BoxDecoration(gradient: toneGradient(st.completed ? AppColors.success : item.color),
                              shape: BoxShape.circle),
                          child: st.completed
                              ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
                              : Text('${lvl.level}', style: Fonts.display(14, color: Colors.white))),
                      const SizedBox(width: Sp.sm),
                      Expanded(child: Text(lvl.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: Fonts.body(12.5, w: FontWeight.w700))),
                    ]),
                  ),
                );
              }),
            ]),
          ]),
        ),
      ));
    },
  );
}

class _HubCard extends StatelessWidget {
  final HubItem item;
  const _HubCard(this.item);
  @override
  Widget build(BuildContext context) => Pressable(
        onTap: () => openHubItem(context, item),
        child: Container(
          padding: const EdgeInsets.all(Sp.md),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(Rad.xl),
              border: Border.all(color: AppColors.border), boxShadow: toyShadow(AppColors.toyShadowColor, 4)),
          child: Row(children: [
            Container(width: 56, height: 56, alignment: Alignment.center,
                decoration: BoxDecoration(gradient: toneGradient(item.color), borderRadius: BorderRadius.circular(18),
                    boxShadow: toyShadow(shade(item.color), 3)),
                child: Text(item.emoji, style: const TextStyle(fontSize: 26))),
            const SizedBox(width: Sp.md),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Fonts.display(18, height: 1.2)),
              Text(item.hindi, maxLines: 1, style: Fonts.hindi(13, color: AppColors.textSecondary)),
              const SizedBox(height: 2),
              Text(item.desc, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: Fonts.body(12.5, w: FontWeight.w500, color: AppColors.textSecondary)),
            ])),
            Icon(Icons.chevron_right_rounded, size: 26, color: AppColors.textSecondary),
          ]),
        ),
      );
}
