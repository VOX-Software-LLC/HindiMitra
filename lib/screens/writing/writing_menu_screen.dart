import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models.dart';
import '../../routes.dart';
import '../../store/app_store.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../../widgets/common.dart';
import '../../widgets/icons.dart';
import '../../widgets/menu_tiles.dart';
import '../app_shell.dart';

const _levelColors = [
  Color(0xFFFF6B6B), Color(0xFFFF9F43), Color(0xFFFECA57), Color(0xFF48DBFB), Color(0xFF0ABDE3),
  Color(0xFF10AC84), Color(0xFFEE5A24), Color(0xFF6C5CE7), Color(0xFFFD79A8), Color(0xFFD4AC0D),
];

/// LetterGridScreen.tsx — accordion of Vowels, Consonants, + 8 practice activities.
class WritingMenuScreen extends StatefulWidget {
  const WritingMenuScreen({super.key});
  @override
  State<WritingMenuScreen> createState() => _WritingMenuScreenState();
}

class _WritingMenuScreenState extends State<WritingMenuScreen> {
  final Map<String, bool> expanded = {};

  void _toggle(String id) => setState(() => expanded[id] = !(expanded[id] ?? false));

  void _goPaywall() => AppShell.of(context)?.goTo(4); // Profile tab (Paywall reachable from there)

  void _onLetterLevel(LevelDef level, List<LevelDef> all, String section) {
    final s = context.read<AppStore>();
    final unlocked = AppData.isLevelUnlocked(level, all, s.letterProgress);
    if (!unlocked) {
      final needed = level.requiredStars - AppData.sectionStars(all, s.letterProgress);
      showInfoDialog(context, 'Level ${level.level} Locked 🔒',
          'Earn $needed more star${needed > 1 ? 's' : ''} to unlock "${level.name}"!\nKeep practicing previous levels.',
          actions: [('Got it!', null)]);
      return;
    }
    if (section == 'consonant' && level.level > 1 && !s.isPremium) {
      showInfoDialog(context, 'Premium Feature 🔒',
          '"${level.name}" requires Premium to unlock consonant levels beyond Level 1.',
          actions: [('Not Now', null), ('View Plans', _goPaywall)]);
      return;
    }
    openScreen(context, 'WritingCanvas', {
      'levelId': level.id, 'levelName': level.name, 'letterIds': level.letterIds,
      'bonusType': level.bonusType, 'timeLimit': level.timeLimit,
    });
  }

  void _onActivityLevel(ActivityDef a, LevelDef level, int idx) {
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
          actions: [('Not Now', null), ('View Plans', _goPaywall)]);
      return;
    }
    openScreen(context, a.screen, {
      'levelId': level.id, 'levelName': level.name, 'levelNumber': level.level,
      'activityId': a.id, ...level.params,
    });
  }

  @override
  Widget build(BuildContext context) {
    // Select a small set of derived scalars so this screen only rebuilds when
    // progress actually changes (not on every unrelated AppStore mutation).
    final (mastered, totalStars, isPremium, vStars, cStars, vDone, cDone, actLevels) =
        context.select<AppStore, (int, int, bool, int, int, int, int, int)>((store) {
      final progress = store.letterProgress;
      final vDone = AppData.vowelLevels.where((l) => AppData.levelStars(l.letterIds, progress).completed).length;
      final cDone = AppData.consonantLevels.where((l) => AppData.levelStars(l.letterIds, progress).completed).length;
      final actLevels = AppData.writingActivities.fold<int>(0, (sum, a) => sum + (store.activityProgress[a.id] ?? 0));
      return (
        store.masteredCount, store.totalStars, store.isPremium,
        AppData.sectionStars(AppData.vowelLevels, progress), AppData.sectionStars(AppData.consonantLevels, progress),
        vDone, cDone, actLevels,
      );
    });
    final s = context.read<AppStore>();
    final progress = s.letterProgress;
    final total = AppData.allLetters.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: screenScroll(
          padding: const EdgeInsets.fromLTRB(Sp.md, Sp.md, Sp.md, Sp.xxl),
          child: Column(children: [
            HeroBanner(
              color: AppColors.primary,
              icon: const Icon(Icons.draw_rounded, size: 30, color: Colors.white),
              title: 'लिखना सीखें', subtitle: 'Learn to Write',
              stats: [('$mastered', 'Mastered'), ('${vDone + cDone + actLevels}', 'Levels'), ('$totalStars', 'Stars')],
              progress: mastered / total,
            ),
            const SizedBox(height: Sp.sm),
            _accordion('vowels', child: Text('अ', style: Fonts.hindi(26, color: const Color(0xFFE5484D))),
                circleColor: const Color(0xFFFF6B6B), title: 'स्वर',
                subtitle: 'Vowels · $vStars stars', done: vDone, locked: false,
                children: [for (int i = 0; i < AppData.vowelLevels.length; i++)
                  _letterLevelCard(AppData.vowelLevels[i], i, AppData.vowelLevels, progress, false,
                      () => _onLetterLevel(AppData.vowelLevels[i], AppData.vowelLevels, 'vowel'))]),
            _accordion('consonants', child: Text('क', style: Fonts.hindi(26, color: const Color(0xFF6C5CE7))),
                circleColor: const Color(0xFF6C5CE7), title: 'व्यंजन',
                subtitle: 'Consonants · $cStars stars${!isPremium ? ' · Premium' : ''}',
                done: cDone, locked: !isPremium,
                children: [for (int i = 0; i < AppData.consonantLevels.length; i++)
                  _letterLevelCard(AppData.consonantLevels[i], i, AppData.consonantLevels, progress,
                      !isPremium && AppData.consonantLevels[i].level > 1,
                      () => _onLetterLevel(AppData.consonantLevels[i], AppData.consonantLevels, 'consonant'))]),
            for (final a in AppData.writingActivities)
              _activityAccordion(a, s),
            ToyCard(
              margin: const EdgeInsets.only(top: Sp.sm),
              onTap: () => openScreen(context, 'RoughPad'),
              child: Row(children: [
                Container(width: 48, height: 48,
                    decoration: BoxDecoration(color: AppColors.secondary.withOpacity(0.12), shape: BoxShape.circle),
                    child: const Icon(Icons.edit_note, size: 28, color: AppColors.secondary)),
                const SizedBox(width: Sp.md),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Rough Page · रफ़ पन्ना', style: Fonts.display(18)),
                  Text('Free practice for every word on ruled lines — no scores',
                      style: Fonts.body(13, color: AppColors.textSecondary)),
                ])),
                const Icon(Icons.chevron_right, color: AppColors.textSecondary),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _activityAccordion(ActivityDef a, AppStore s) {
    final color = hexColor(a.color);
    final done = s.activityProgress[a.id] ?? 0;
    final stars = done * 3;
    final locked = a.isPremium && !s.isPremium;
    return _accordion(a.id,
        child: a.iconEmoji != null
            ? Text(a.iconEmoji!, style: Fonts.hindi(22, color: color))
            : Icon(ionIcon(a.icon), size: 24, color: color),
        circleColor: color, title: a.hindiTitle,
        subtitle: '${a.title}${stars > 0 ? ' · $stars stars' : ''}${locked ? ' · Premium' : ''}',
        done: done, locked: locked,
        children: [for (int i = 0; i < a.levels.length; i++) _activityLevelCard(a, a.levels[i], i, s, locked)]);
  }

  Widget _accordion(String id, {required Widget child, required Color circleColor, required String title,
      required String subtitle, required int done, required bool locked, required List<Widget> children}) {
    final open = expanded[id] ?? false;
    return Column(children: [
      SectionTile(leading: child, color: circleColor, title: title, subtitle: subtitle, done: done,
          locked: locked, open: open, onTap: () => _toggle(id)),
      AnimatedSize(
        duration: const Duration(milliseconds: 240), curve: Curves.easeOutCubic,
        child: open
            ? Padding(padding: const EdgeInsets.only(top: Sp.sm),
                child: Column(children: [for (final c in children) Padding(padding: const EdgeInsets.only(bottom: Sp.sm), child: c)]))
            : const SizedBox(width: double.infinity),
      ),
    ]);
  }

  Widget _levelShell({required bool isLocked, required bool completed, required Color color, required int number,
      required Widget info, required VoidCallback onTap}) =>
      LevelTile(number: number, color: color, isLocked: isLocked, completed: completed, info: info, onTap: onTap);

  Widget _tag(String t, Color c) => LevelTag(t, c);

  Widget _hint(String t, Color c) => LevelHint(t, c);

  Widget _starRow(Color color, double ratio, int filledStars, {required List<bool> filled}) =>
      LevelStars(color: color, ratio: ratio, filled: filled);

  Widget _letterLevelCard(LevelDef level, int index, List<LevelDef> all, Map<String, LetterProgress> prog,
      bool premiumLocked, VoidCallback onTap) {
    final unlocked = AppData.isLevelUnlocked(level, all, prog);
    final st = AppData.levelStars(level.letterIds, prog);
    final ratio = st.total > 0 ? st.earned / st.total : 0.0;
    final color = _levelColors[index % _levelColors.length];
    final isLocked = !unlocked || premiumLocked;
    final preview = level.letterIds.take(6).map((id) => AppData.letterById(id)?.character ?? '').join(' ');
    final more = level.letterIds.length > 6 ? level.letterIds.length - 6 : 0;
    final bonus = {'speed': '⚡ SPEED', 'dictation': '👂 LISTEN', 'random': '🌀 RANDOM', 'master': '👑 BOSS'}[level.bonusType];
    return _levelShell(
      isLocked: isLocked, completed: st.completed, color: color, number: level.level, onTap: onTap,
      info: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 6, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text(level.emoji, style: const TextStyle(fontSize: 18)),
          Text(level.name, style: Fonts.display(15, w: FontWeight.w700, color: isLocked ? AppColors.textSecondary : AppColors.textPrimary)),
          if (bonus != null) _tag(bonus, color),
        ]),
        Padding(padding: const EdgeInsets.only(top: 1),
            child: Text(level.hindiName, style: Fonts.hindi(12, color: isLocked ? AppColors.textSecondary : AppColors.primary))),
        Padding(padding: const EdgeInsets.only(top: 3),
            child: Text('$preview${more > 0 ? ' +$more' : ''}', maxLines: 1, overflow: TextOverflow.ellipsis,
                style: Fonts.hindi(15, color: AppColors.textSecondary).copyWith(letterSpacing: 2))),
        if (!isLocked)
          _starRow(color, ratio, st.earned, filled: [for (int k = 1; k <= 3; k++) st.earned >= st.total * (k / 3)]),
        if (isLocked && !premiumLocked)
          _hint('Need ${level.requiredStars - AppData.sectionStars(all, prog)} more stars', Palette.light.pink),
        if (premiumLocked) _hint('Premium required', AppColors.secondary),
      ]),
    );
  }

  Widget _activityLevelCard(ActivityDef a, LevelDef level, int index, AppStore s, bool premiumLocked) {
    final st = AppData.activityLevelState(a.id, index, s.activityProgress);
    final color = _levelColors[index % _levelColors.length];
    final isLocked = !st.unlocked || (premiumLocked && index > 0);
    final hasTime = level.params['timeLimit'] != null;
    final hard = level.params['hardMode'] == true;
    final boss = level.level == 10;
    return _levelShell(
      isLocked: isLocked, completed: st.completed, color: color, number: level.level,
      onTap: () => _onActivityLevel(a, level, index),
      info: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 6, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text(level.emoji, style: const TextStyle(fontSize: 18)),
          Text(level.name, style: Fonts.display(15, w: FontWeight.w700, color: isLocked ? AppColors.textSecondary : AppColors.textPrimary)),
          if (boss) _tag('👑 BOSS', color)
          else if (hasTime) _tag('⚡ TIMED', color)
          else if (hard) _tag('🔥 HARD', color),
        ]),
        Padding(padding: const EdgeInsets.only(top: 1),
            child: Text(level.hindiName, style: Fonts.hindi(12, color: isLocked ? AppColors.textSecondary : AppColors.primary))),
        Padding(padding: const EdgeInsets.only(top: 3),
            child: Text(level.description, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: Fonts.body(12, color: AppColors.textSecondary, w: FontWeight.w500))),
        if (!isLocked)
          _starRow(color, st.stars / 3, st.stars, filled: [for (int k = 1; k <= 3; k++) st.stars >= k]),
        if (isLocked && premiumLocked && index > 0) _hint('Premium required', AppColors.secondary),
        if (isLocked && !premiumLocked) _hint('Complete Level ${level.level - 1} first', Palette.light.pink),
      ]),
    );
  }
}
