import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models.dart';
import '../../routes.dart';
import '../../store/app_store.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../../widgets/menu_tiles.dart';
import '../../widgets/common.dart';
import '../../widgets/icons.dart';
import '../app_shell.dart';

const _levelColors = [
  Color(0xFFFF6B6B), Color(0xFFFF9F43), Color(0xFFFECA57), Color(0xFF48DBFB), Color(0xFF0ABDE3),
  Color(0xFF10AC84), Color(0xFFEE5A24), Color(0xFF6C5CE7), Color(0xFFFD79A8), Color(0xFFD4AC0D),
];

/// ReadingMenuScreen.tsx — 16+ reading activities x 10 levels.
class ReadingMenuScreen extends StatefulWidget {
  const ReadingMenuScreen({super.key});
  @override
  State<ReadingMenuScreen> createState() => _ReadingMenuScreenState();
}

class _ReadingMenuScreenState extends State<ReadingMenuScreen> {
  final Map<String, bool> expanded = {};

  void _onLevel(ActivityDef a, LevelDef level, int idx) {
    final s = context.read<AppStore>();
    final st = AppData.activityLevelState(a.id, idx, s.activityProgress);
    if (!st.unlocked) {
      showInfoDialog(context, 'Level ${level.level} Locked 🔒',
          'Complete Level ${level.level - 1} first to unlock "${level.name}"!', actions: [('Got it!', null)]);
      return;
    }
    if (a.isPremium && !s.isPremium) {
      showInfoDialog(context, 'Premium Feature 🔒',
          '"${a.title}" is a Premium feature! Upgrade to unlock all levels.',
          actions: [('Not Now', null), ('View Plans', () => AppShell.of(context)?.goTo(4))]);
      return;
    }
    openScreen(context, a.screen, {
      'levelId': level.id, 'levelName': level.name, 'levelNumber': level.level,
      'activityId': a.id, ...level.params,
    });
  }

  @override
  Widget build(BuildContext context) {
    final (totalStars, totalLevels) = context.select<AppStore, (int, int)>((store) => (
          store.totalStars,
          AppData.readingActivities.fold<int>(0, (sum, a) => sum + (store.activityProgress[a.id] ?? 0)),
        ));
    final s = context.read<AppStore>();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: screenScroll(
          padding: const EdgeInsets.fromLTRB(Sp.md, Sp.md, Sp.md, Sp.xxl),
          child: Column(children: [
            HeroBanner(
              color: AppColors.readingModule,
              icon: const Icon(Icons.menu_book_rounded, size: 30, color: Colors.white),
              title: 'पढ़ना सीखें', subtitle: 'Learn to Read',
              stats: [('$totalLevels', 'Levels'), ('${AppData.readingActivities.length}', 'Activities'), ('$totalStars', 'Stars')],
            ),
            const SizedBox(height: Sp.sm),
            for (final a in AppData.readingActivities) _accordion(a, s),
            Padding(padding: const EdgeInsets.symmetric(vertical: Sp.lg), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.auto_awesome_outlined, size: 20, color: AppColors.textMuted), const SizedBox(width: Sp.sm),
              Flexible(child: Text('More stories and grammar games coming soon!', style: Fonts.body(12, color: AppColors.textMuted))),
            ])),
          ]),
        ),
      ),
    );
  }

  Widget _accordion(ActivityDef a, AppStore s) {
    final color = hexColor(a.color);
    final done = s.activityProgress[a.id] ?? 0;
    final stars = done * 3;
    final locked = a.isPremium && !s.isPremium;
    final open = expanded[a.id] ?? false;
    return Column(children: [
      SectionTile(
        leading: a.iconEmoji != null
            ? Text(a.iconEmoji!, style: const TextStyle(fontSize: 24))
            : Icon(ionIcon(a.icon), size: 26, color: color),
        color: color, title: a.hindiTitle,
        subtitle: '${a.title}${stars > 0 ? ' · $stars stars' : ''}${locked ? ' · Premium' : ''}',
        done: done, locked: locked, open: open,
        onTap: () => setState(() => expanded[a.id] = !open),
      ),
      AnimatedSize(
        duration: const Duration(milliseconds: 200), curve: Curves.easeInOut,
        child: open
            ? Padding(padding: const EdgeInsets.only(top: Sp.sm), child: Column(children: [
                for (int i = 0; i < a.levels.length; i++)
                  Padding(padding: const EdgeInsets.only(bottom: Sp.sm), child: _levelCard(a, a.levels[i], i, s, locked)),
              ]))
            : const SizedBox(width: double.infinity),
      ),
    ]);
  }

  Widget _levelCard(ActivityDef a, LevelDef level, int index, AppStore s, bool premiumLocked) {
    final st = AppData.activityLevelState(a.id, index, s.activityProgress);
    final color = _levelColors[index % _levelColors.length];
    final isLocked = !st.unlocked || (premiumLocked && index > 0);
    final hasTime = level.params['timeLimit'] != null && level.params['timeLimit'] != 0;
    final boss = level.level == 10;
    return LevelTile(
      number: level.level, color: color, isLocked: isLocked, completed: st.completed,
      onTap: () => _onLevel(a, level, index),
      info: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 6, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text(level.emoji, style: const TextStyle(fontSize: 18)),
          Text(level.name, style: Fonts.display(15, w: FontWeight.w700, color: isLocked ? AppColors.textSecondary : AppColors.textPrimary)),
          if (boss) LevelTag('👑 BOSS', color) else if (hasTime) LevelTag('⚡ TIMED', color),
        ]),
        Padding(padding: const EdgeInsets.only(top: 1),
            child: Text(level.hindiName, style: Fonts.hindi(12, color: isLocked ? AppColors.textMuted : AppColors.readingModule))),
        Padding(padding: const EdgeInsets.only(top: 3),
            child: Text(level.description, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: Fonts.body(12, color: AppColors.textSecondary, w: FontWeight.w500))),
        if (!isLocked) LevelStars(color: color, ratio: st.stars / 3, filled: [for (int k = 1; k <= 3; k++) st.stars >= k]),
        if (isLocked && premiumLocked && index > 0) LevelHint('Premium required', AppColors.secondary),
        if (isLocked && !premiumLocked) LevelHint('Complete Level ${level.level - 1} first', Palette.light.pink),
      ]),
    );
  }
}
