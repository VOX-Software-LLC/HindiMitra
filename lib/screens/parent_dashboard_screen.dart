import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/models.dart';
import '../store/app_store.dart';
import '../theme/app_theme.dart';
import '../theme/palette.dart';
import '../widgets/common.dart';
import '../widgets/progress_bar.dart';

/// ParentDashboardScreen.tsx (the Profile-stack version that reads the local store)
class ParentDashboardScreen extends StatelessWidget {
  final Map<String, dynamic> params;
  const ParentDashboardScreen({super.key, this.params = const {}});

  @override
  Widget build(BuildContext context) {
    // Rebuild only when one of these derived scalars actually changes, not on
    // every unrelated AppStore mutation (this screen is premium-gated and data-heavy).
    final (mastered, started, vowelsMastered, consMastered, daysActive, totalSessions, isPremium) =
        context.select<AppStore, (int, int, int, int, int, int, bool)>((store) {
      final lp = store.letterProgress.values.toList();
      final vowelIds = AppData.vowels.map((v) => v.id).toSet();
      final consIds = AppData.consonants.map((v) => v.id).toSet();
      final now = DateTime.now();
      final last7 = List.generate(7, (i) => now.subtract(Duration(days: i)).toUtc().toIso8601String().split('T').first);
      return (
        lp.where((p) => p.mastered).length,
        store.letterProgress.length,
        lp.where((p) => p.mastered && vowelIds.contains(p.letterId)).length,
        lp.where((p) => p.mastered && consIds.contains(p.letterId)).length,
        last7.where(store.practicedDates.contains).length,
        lp.fold<int>(0, (sum, p) => sum + p.attemptsInCurrentStage + p.successfulAttempts),
        store.isPremium,
      );
    });
    final s = context.read<AppStore>();
    final total = AppData.allLetters.length;

    return Scaffold(backgroundColor: AppColors.background, body: SafeArea(bottom: false, child: Column(children: [
      Padding(padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.sm), child: Row(children: [
        GestureDetector(onTap: () => Navigator.of(context).maybePop(), child: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: AppColors.surface, shape: BoxShape.circle, border: Border.all(color: AppColors.border)),
          child: const Icon(Icons.chevron_left, size: 24, color: AppColors.textPrimary))),
        Expanded(child: Column(children: [
          Text('Parent Dashboard', style: Fonts.display(20, color: AppColors.textPrimary, w: FontWeight.w800)),
          Text('अभिभावक डैशबोर्ड', style: Fonts.body(12, color: AppColors.textSecondary)),
        ])),
        const SizedBox(width: 40),
      ])),
      Expanded(child: !isPremium ? _gate() : screenScroll(padding: const EdgeInsets.all(Sp.md), maxWidth: 720, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _card(Row(children: [
          Container(width: 48, height: 48, alignment: Alignment.center, decoration: const BoxDecoration(color: AppColors.primaryDark, shape: BoxShape.circle),
              child: Text(s.userName.isEmpty ? '' : s.userName[0].toUpperCase(), style: Fonts.display(20, color: AppColors.textOnPrimary, w: FontWeight.w800))),
          const SizedBox(width: Sp.md),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.userName, style: Fonts.display(16, color: AppColors.textPrimary, w: FontWeight.w700)),
            Text('Level ${s.userLevel}', style: Fonts.body(12, color: AppColors.textSecondary)),
          ])),
          const SizedBox(width: Sp.md),
          DailyGoalRing(current: s.todayPracticeCount, goal: s.dailyGoal, size: 56, strokeWidth: 6),
        ]), margin: const EdgeInsets.only(bottom: Sp.md)),
        Padding(padding: const EdgeInsets.only(bottom: Sp.lg), child: LayoutBuilder(builder: (context, c) {
          final w = (c.maxWidth - Sp.sm) / 2;
          return Wrap(spacing: Sp.sm, runSpacing: Sp.sm, children: [
            _stat(w, Icons.star, AppColors.starGold, '${s.totalStars}', 'Stars Earned'),
            _stat(w, Icons.local_fire_department, const Color(0xFFFF6B35), '${s.currentStreak}', 'Current Streak'),
            _stat(w, Icons.emoji_events, AppColors.primary, '${s.longestStreak}', 'Best Streak'),
            _stat(w, Icons.calendar_today, AppColors.readingModule, '$daysActive/7', 'Active This Week'),
          ]);
        })),
        _section('Letter Mastery'),
        _card(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _mrow('Overall Progress', '$mastered/$total'),
          const SizedBox(height: Sp.sm),
          HsProgressBar(progress: total == 0 ? 0 : mastered / total, height: 8, color: AppColors.success),
          const SizedBox(height: Sp.sm),
          Padding(padding: const EdgeInsets.symmetric(vertical: Sp.xs), child: Row(children: [
            _dot(AppColors.readingModule), const SizedBox(width: Sp.xs),
            Text('Vowels: $vowelsMastered/${AppData.vowels.length}', style: Fonts.body(12, color: AppColors.textSecondary)),
            const SizedBox(width: Sp.lg),
            _dot(AppColors.secondary), const SizedBox(width: Sp.xs),
            Text('Consonants: $consMastered/${AppData.consonants.length}', style: Fonts.body(12, color: AppColors.textSecondary)),
          ])),
          const SizedBox(height: Sp.sm),
          _mrow('Letters Started', '$started'),
          const SizedBox(height: Sp.sm),
          HsProgressBar(progress: total == 0 ? 0 : started / total, height: 6, color: AppColors.primary),
        ])),
        const SizedBox(height: Sp.lg),
        _section('Activity Summary'),
        _card(Column(children: [
          _arow(Icons.create_outlined, 'Total Practice Sessions', '$totalSessions'), const SizedBox(height: Sp.md),
          _arow(Icons.workspace_premium_outlined, 'Points Earned', '${s.totalPoints}'), const SizedBox(height: Sp.md),
          _arow(Icons.calendar_today_outlined, 'Total Days Practiced', '${s.practicedDates.length}'), const SizedBox(height: Sp.md),
          _arow(Icons.today_outlined, "Today's Letters", '${s.todayPracticeCount}/${s.dailyGoal}'),
        ])),
        const SizedBox(height: Sp.lg),
        Container(
          padding: const EdgeInsets.all(Sp.md),
          decoration: BoxDecoration(color: AppColors.primary.withAlpha(0x15), borderRadius: BorderRadius.circular(Rad.xl),
              border: Border.all(color: AppColors.primary.withAlpha(0x30)), boxShadow: toyShadow(AppColors.toyShadowColor, 4)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.lightbulb_outline, size: 22, color: AppColors.primaryDark), const SizedBox(width: Sp.md),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Tips for Parents', style: Fonts.display(14, color: AppColors.primaryDark, w: FontWeight.w700)),
              const SizedBox(height: Sp.xs),
              Text(
                s.currentStreak == 0
                    ? 'Encourage your child to practice daily — even 5 minutes helps build consistency!'
                    : s.currentStreak < 7
                        ? 'Great start! ${s.userName} has a ${s.currentStreak}-day streak. Regular short sessions work better than long occasional ones.'
                        : 'Wonderful! ${s.userName} is showing great dedication with a ${s.currentStreak}-day streak. Keep celebrating their progress!',
                style: Fonts.body(14, color: AppColors.textSecondary, height: 20 / 14)),
            ])),
          ]),
        ),
        const SizedBox(height: Sp.xxl * 2),
      ]))),
    ])));
  }

  Widget _gate() => Center(child: SingleChildScrollView(padding: const EdgeInsets.all(Sp.md), child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Container(
          margin: const EdgeInsets.only(top: Sp.md), padding: const EdgeInsets.symmetric(vertical: Sp.xl, horizontal: Sp.lg),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(Rad.xl2), border: Border.all(color: AppColors.border),
              boxShadow: softShadow(AppColors.primary)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 80, height: 80, alignment: Alignment.center, decoration: BoxDecoration(color: AppColors.primary.withAlpha(0x20), shape: BoxShape.circle),
                child: const Text('👑', style: TextStyle(fontSize: 40))),
            const SizedBox(height: Sp.md),
            Text('Premium Feature', style: Fonts.display(24, color: AppColors.textPrimary, w: FontWeight.w800)),
            const SizedBox(height: Sp.md),
            Text('Parent Dashboard', style: Fonts.display(20, color: AppColors.primary, w: FontWeight.w700)),
            const SizedBox(height: Sp.md),
            Padding(padding: const EdgeInsets.symmetric(horizontal: Sp.lg), child: Text(
              "Monitor your child's progress, track learning streaks, and get personalized tips to support their Hindi learning journey.",
              textAlign: TextAlign.center, style: Fonts.body(16, color: AppColors.textSecondary, height: 20 / 16))),
            const SizedBox(height: Sp.md),
            // NOTE: in the original this button has no onPress handler.
            Container(
              margin: const EdgeInsets.only(top: Sp.md), padding: const EdgeInsets.symmetric(horizontal: Sp.xl, vertical: Sp.md),
              decoration: BoxDecoration(gradient: toneGradient(AppColors.primary), borderRadius: BorderRadius.circular(9999), boxShadow: toyShadow(AppColors.primaryDark, 6)),
              child: Text('Upgrade to Premium', textAlign: TextAlign.center, style: Fonts.body(14, w: FontWeight.w800, color: AppColors.textOnPrimary)),
            ),
          ]),
        ),
      )));

  Widget _card(Widget child, {EdgeInsets margin = EdgeInsets.zero}) => Container(
        margin: margin, padding: const EdgeInsets.all(Sp.md),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(Rad.xl), border: Border.all(color: AppColors.border),
            boxShadow: toyShadow(AppColors.toyShadowColor, 4)),
        child: child,
      );

  Widget _stat(double w, IconData i, Color c, String n, String l) => Container(
        width: w, padding: const EdgeInsets.all(Sp.md),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(Rad.xl), border: Border.all(color: AppColors.border),
            boxShadow: toyShadow(AppColors.toyShadowColor, 4)),
        child: Column(children: [
          Icon(i, size: 22, color: c), const SizedBox(height: Sp.xs),
          Text(n, style: Fonts.display(24, color: AppColors.textPrimary, w: FontWeight.w800)), const SizedBox(height: Sp.xs),
          Text(l, textAlign: TextAlign.center, style: Fonts.body(11, color: AppColors.textMuted)),
        ]),
      );

  Widget _section(String t) => Padding(padding: const EdgeInsets.only(bottom: Sp.sm),
      child: Text(t, style: Fonts.display(16, color: AppColors.textPrimary, w: FontWeight.w800)));

  Widget _mrow(String l, String v) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(l, style: Fonts.body(16, color: AppColors.textSecondary)),
        Text(v, style: Fonts.body(14, w: FontWeight.w700, color: AppColors.textPrimary)),
      ]);

  Widget _dot(Color c) => Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle));

  Widget _arow(IconData i, String l, String v) => Row(children: [
        Icon(i, size: 20, color: AppColors.textSecondary), const SizedBox(width: Sp.sm),
        Expanded(child: Text(l, style: Fonts.body(16, color: AppColors.textPrimary))),
        Text(v, style: Fonts.body(14, w: FontWeight.w800, color: AppColors.primaryDark)),
      ]);
}
