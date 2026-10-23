import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/badges.dart';
import '../data/models.dart';
import '../routes.dart';
import '../store/app_store.dart';
import '../theme/app_theme.dart';
import '../theme/palette.dart';
import 'common.dart';
import 'icons.dart';

String _day(DateTime d) => d.toIso8601String().split('T').first;

int _levelsDone(AppStore s) {
  final v = AppData.vowelLevels.where((l) => AppData.levelStars(l.letterIds, s.letterProgress).completed).length;
  final c = AppData.consonantLevels.where((l) => AppData.levelStars(l.letterIds, s.letterProgress).completed).length;
  final a = [...AppData.writingActivities, ...AppData.readingActivities]
      .fold<int>(0, (sum, x) => sum + (s.activityProgress[x.id] ?? 0));
  return v + c + a;
}

/// Lowest-accuracy letters (only letters with at least one graded attempt).
List<(HindiLetter, int)> weakLetters(AppStore s, {int max = 5}) {
  final out = <(HindiLetter, int)>[];
  for (final l in AppData.allLetters) {
    final a = s.letterAccuracy(l.id);
    if (a != null && a < 90) out.add((l, a));
  }
  out.sort((x, y) => x.$2.compareTo(y.$2));
  return out.take(max).toList();
}

class _Section extends StatelessWidget {
  final String title; final IconData icon; final Widget child; final Widget? trailing;
  const _Section({required this.title, required this.icon, required this.child, this.trailing});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: Sp.md),
        padding: const EdgeInsets.all(Sp.md),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(Rad.xl),
            border: Border.all(color: AppColors.border), boxShadow: toyShadow(AppColors.toyShadowColor, 4)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(icon, size: 20, color: AppColors.primary), const SizedBox(width: Sp.sm),
            Expanded(child: Text(title, style: Fonts.display(18))),
            if (trailing != null) trailing!,
          ]),
          const SizedBox(height: Sp.sm),
          child,
        ]),
      );
}

Widget _tile(String value, String label, Color color) => Expanded(child: Column(children: [
      Text(value, style: Fonts.display(22, color: color)),
      Text(label, textAlign: TextAlign.center, style: Fonts.body(12, w: FontWeight.w700, color: AppColors.textSecondary)),
    ]));

/// Levels done, average accuracy, total stars, day streak.
class ProfileProgressSummary extends StatelessWidget {
  const ProfileProgressSummary({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    final acc = s.averageAccuracy;
    return _Section(title: 'Progress', icon: Icons.insights, child: Row(children: [
      _tile('${_levelsDone(s)}', 'Levels done', AppColors.primary),
      _tile(acc == null ? '–' : '$acc%', 'Avg accuracy', AppColors.success),
      _tile('${s.totalStars}', 'Total stars', AppColors.starGold),
      _tile('${s.practiceStreakDays} 🔥', 'Day streak', AppColors.primaryDark),
    ]));
  }
}

/// Weak letters with a "Practise these" button (opens them as one level).
class ProfileWeakLetters extends StatelessWidget {
  const ProfileWeakLetters({super.key});
  @override
  Widget build(BuildContext context) {
    final weak = weakLetters(context.watch<AppStore>());
    return _Section(
      title: 'Letters to practise', icon: Icons.track_changes,
      child: weak.isEmpty
          ? Text('Write a few letters and your trickiest ones will show up here.',
              style: Fonts.body(14, color: AppColors.textSecondary))
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Wrap(spacing: Sp.sm, runSpacing: Sp.sm, children: [
                for (final (l, a) in weak) Container(
                  padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.xs),
                  decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(Rad.lg),
                      border: Border.all(color: a < 50 ? AppColors.error : AppColors.warning, width: 1.5)),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(l.character, style: Fonts.hindi(26, height: 32 / 26)),
                    Text('$a%', style: Fonts.body(11, w: FontWeight.w800, color: a < 50 ? AppColors.error : AppColors.primaryDark)),
                  ]),
                ),
              ]),
              const SizedBox(height: Sp.md),
              PillButton(label: 'Practise these', icon: Icons.edit, filled: true, onTap: () {
                final ids = [for (final (l, _) in weak) l.id];
                openScreen(context, 'WritingCanvas', ids.length > 1
                    ? {'letterIds': ids, 'levelName': 'Weak letters'}
                    : {'letterId': ids.first});
              }),
            ]),
    );
  }
}

/// Minutes practised on each of the last 7 days.
class ProfileWeeklyChart extends StatelessWidget {
  const ProfileWeeklyChart({super.key});
  static const _wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    final today = DateTime.now().toUtc();
    final days = [for (int i = 6; i >= 0; i--) today.subtract(Duration(days: i))];
    final mins = [for (final d in days) ((s.practiceSeconds[_day(d)] ?? 0) / 60).ceil()];
    final peak = mins.fold<int>(0, (a, b) => a > b ? a : b);
    final total = mins.fold<int>(0, (a, b) => a + b);
    return _Section(
      title: 'This week', icon: Icons.bar_chart,
      trailing: Text('$total min', style: Fonts.body(13, w: FontWeight.w800, color: AppColors.primaryDark)),
      child: SizedBox(height: 130, child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (int i = 0; i < 7; i++) Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
          Text(mins[i] == 0 ? '' : '${mins[i]}', style: Fonts.body(11, w: FontWeight.w700, color: AppColors.textSecondary)),
          const SizedBox(height: 2),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 6),
            height: peak == 0 ? 4 : 4 + 80 * mins[i] / peak,
            decoration: BoxDecoration(
                color: i == 6 ? AppColors.primary : AppColors.primary.withOpacity(0.45),
                borderRadius: BorderRadius.circular(6)),
          ),
          const SizedBox(height: Sp.xs),
          Text(_wd[days[i].weekday - 1], style: Fonts.body(11, w: FontWeight.w700,
              color: i == 6 ? AppColors.primaryDark : AppColors.textMuted)),
        ])),
      ])),
    );
  }
}

/// Up to 3 badges pinned from the Rewards tab.
class ProfileBadgeShowcase extends StatelessWidget {
  final VoidCallback onOpenRewards;
  const ProfileBadgeShowcase({super.key, required this.onOpenRewards});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    final pinned = [for (final id in s.pinnedBadges) badgeById(id)].whereType<BadgeDef>().where((d) => d.earned(s)).toList();
    return _Section(
      title: 'Badge showcase', icon: Icons.workspace_premium,
      trailing: GestureDetector(onTap: onOpenRewards,
          child: Text('All badges ›', style: Fonts.body(13, w: FontWeight.w800, color: AppColors.primary))),
      child: Row(children: [
        for (int i = 0; i < 3; i++) Expanded(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: i < pinned.length
              ? Column(children: [
                  Container(width: 56, height: 56, alignment: Alignment.center,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: pinned[i].info.color.withOpacity(0.14),
                          border: Border.all(color: pinned[i].info.color, width: 2)),
                      child: Icon(ionIcon(pinned[i].info.icon), size: 28, color: pinned[i].info.color)),
                  const SizedBox(height: Sp.xs),
                  Text(pinned[i].info.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: Fonts.body(12, w: FontWeight.w700)),
                ])
              : GestureDetector(onTap: onOpenRewards, child: Column(children: [
                  Container(width: 56, height: 56, alignment: Alignment.center,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.background,
                          border: Border.all(color: AppColors.border, width: 2)),
                      child: const Icon(Icons.add, color: AppColors.textMuted)),
                  const SizedBox(height: Sp.xs),
                  Text('Pin a badge', style: Fonts.body(12, w: FontWeight.w600, color: AppColors.textMuted)),
                ])),
        )),
      ]),
    );
  }
}

/// Sound, writing hand, language and difficulty.
class ProfileSettings extends StatelessWidget {
  const ProfileSettings({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    Widget seg(String label, List<(String, String)> opts, String value, ValueChanged<String> onChanged) => Padding(
          padding: const EdgeInsets.only(top: Sp.sm),
          child: Row(children: [
            Expanded(child: Text(label, style: Fonts.body(15, w: FontWeight.w600))),
            Wrap(spacing: 6, children: [
              for (final (v, t) in opts) GestureDetector(
                onTap: () => onChanged(v),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: Sp.sm + 2, vertical: 6),
                  decoration: BoxDecoration(
                    color: value == v ? AppColors.primary : AppColors.background,
                    borderRadius: BorderRadius.circular(9999),
                    border: Border.all(color: value == v ? AppColors.primary : AppColors.border)),
                  child: Text(t, style: Fonts.body(12, w: FontWeight.w800,
                      color: value == v ? AppColors.textOnPrimary : AppColors.textSecondary)),
                ),
              ),
            ]),
          ]),
        );
    return _Section(title: 'Settings', icon: Icons.tune, child: Column(children: [
      Row(children: [
        Expanded(child: Text('Sound', style: Fonts.body(15, w: FontWeight.w600))),
        Switch(value: s.soundOn, activeThumbColor: AppColors.primary, onChanged: s.setSoundOn),
      ]),
      seg('Writing hand', const [('right', 'Right'), ('left', 'Left')], s.leftHanded ? 'left' : 'right',
          (v) => s.setLeftHanded(v == 'left')),
      seg('Language', const [('en', 'English'), ('hi', 'हिन्दी')], s.appLanguage, s.setAppLanguage),
      seg('Difficulty', const [('easy', 'Easy'), ('normal', 'Normal'), ('hard', 'Hard')], s.difficulty, s.setDifficulty),
    ]));
  }
}

/// Plain-text progress report for a parent or teacher.
String buildProgressReport(AppStore s) {
  final acc = s.averageAccuracy;
  final weak = weakLetters(s);
  final today = DateTime.now().toUtc();
  final week = [for (int i = 0; i < 7; i++) s.practiceSeconds[_day(today.subtract(Duration(days: i)))] ?? 0]
      .fold<int>(0, (a, b) => a + b);
  return [
    'HindiMitra — progress report for ${s.userName}',
    'Date: ${_day(DateTime.now())}',
    '',
    'Levels completed: ${_levelsDone(s)}',
    'Letters practised: ${s.letterProgress.length} (mastered: ${s.masteredCount})',
    'Average accuracy: ${acc == null ? 'not enough data yet' : '$acc%'}',
    'Total stars: ${s.totalStars}',
    'Practice streak: ${s.practiceStreakDays} day(s)',
    'Practice this week: ${(week / 60).ceil()} min',
    'Badges earned: ${badgeDefs.where((d) => d.earned(s)).length}/${badgeDefs.length}',
    if (weak.isNotEmpty) 'Letters to practise: ${weak.map((w) => '${w.$1.character} (${w.$2}%)').join(', ')}',
  ].join('\n');
}

class ProfileParentReport extends StatelessWidget {
  const ProfileParentReport({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.read<AppStore>();
    return _Section(
      title: 'Parent / teacher view', icon: Icons.family_restroom,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Share a summary of progress with a parent or teacher.', style: Fonts.body(14, color: AppColors.textSecondary)),
        const SizedBox(height: Sp.sm),
        Wrap(spacing: Sp.sm, runSpacing: Sp.sm, children: [
          PillButton(label: 'Copy report', icon: Icons.copy, onTap: () async {
            await Clipboard.setData(ClipboardData(text: buildProgressReport(s)));
            if (context.mounted) {
              ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text('Report copied')));
            }
          }),
          PillButton(label: 'Email report', icon: Icons.mail_outline, onTap: () async {
            final uri = Uri.parse('mailto:?subject=${Uri.encodeComponent('HindiMitra progress — ${s.userName}')}'
                '&body=${Uri.encodeComponent(buildProgressReport(s))}');
            try {
              if (!await launchUrl(uri) && context.mounted) {
                showInfoDialog(context, 'Email not available', 'Use "Copy report" and paste it into a message instead.');
              }
            } catch (_) {
              if (context.mounted) {
                showInfoDialog(context, 'Email not available', 'Use "Copy report" and paste it into a message instead.');
              }
            }
          }),
          PillButton(label: 'Dashboard', icon: Icons.dashboard_outlined, onTap: () => openScreen(context, 'ParentDashboard')),
        ]),
      ]),
    );
  }
}
