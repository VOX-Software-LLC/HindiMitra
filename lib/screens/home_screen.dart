import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/models.dart';
import '../store/app_store.dart';
import '../theme/app_theme.dart';
import '../theme/palette.dart';
import '../widgets/toy_button.dart';
import '../widgets/progress_bar.dart';
import '../widgets/common.dart';
import 'app_shell.dart';
import '../l10n.dart';
import '../routes.dart';
import '../widgets/hindi_name.dart';
import '../widgets/profile_menu.dart';
import 'accounts/important_info.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<AppStore>().updateStreak());
  }

  @override
  Widget build(BuildContext context) {
    final (userName, currentStreak, totalStars, mastered) = context.select<AppStore, (String, int, int, int)>(
        (s) => (s.userName, s.currentStreak, s.totalStars, s.masteredCount));
    final (todayCount, dailyGoal) = context.select<AppStore, (int, int)>((s) => (s.todayPracticeCount, s.dailyGoal));
    final w = MediaQuery.of(context).size.width;
    final wide = w >= 768;
    final total = AppData.allLetters.length;
    final pct = total > 0 ? mastered / total : 0.0;
    void goRead() => AppShell.of(context)?.goLearn(1);
    void goWrite() => AppShell.of(context)?.goLearn(0);

    final cards = [
      _ActivityCard(icon: Icons.grid_view_rounded, tone: const Color(0xFF6E4EDF), title: 'Learn Letters',
          hindi: 'वर्णमाला', desc: 'Vowels, consonants & matras with sound', onTap: goRead),
      _ActivityCard(icon: Icons.edit, tone: const Color(0xFF4FB2E6), title: 'Write & Trace',
          hindi: 'लिखो', desc: 'Trace letters with your finger', onTap: goWrite),
      _ActivityCard(icon: Icons.style, tone: const Color(0xFFF26E97), title: 'Word Cards',
          hindi: 'शब्द', desc: 'Flip cards to learn new words', onTap: goRead),
      _ActivityCard(icon: Icons.help_outline_rounded, tone: const Color(0xFF4EC58A), title: 'Play Quiz',
          hindi: 'खेल', desc: 'Fun questions & earn stars', onTap: goRead),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Sp.md, Sp.md, Sp.md, Sp.xxl),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const _HomeHeader(),
                const SizedBox(height: Sp.md),
                // Hero, with today's goal beside it on wide screens.
                if (wide)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Sp.lg),
                    child: IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Expanded(child: _hero(wide, userName, goWrite)),
                      const SizedBox(width: Sp.md),
                      SizedBox(width: 280, child: _GoalCard(current: todayCount, goal: dailyGoal, tall: true, onTap: goWrite)),
                    ])),
                  )
                else
                  Padding(padding: const EdgeInsets.only(bottom: Sp.md), child: _hero(wide, userName, goWrite)),
                // Stats
                _statsRow(wide, currentStreak, totalStars, mastered, total, pct),
                if (!wide) ...[
                  const SizedBox(height: Sp.sm),
                  _GoalCard(current: todayCount, goal: dailyGoal, tall: false, onTap: goWrite),
                ],
                const HomeworkCard(),
                const SizedBox(height: Sp.md),
                Padding(
                  padding: const EdgeInsets.only(top: Sp.sm, bottom: Sp.md),
                  child: Text('What do you want to do?', style: Fonts.display(26)),
                ),
                if (wide)
                  LayoutBuilder(builder: (_, c) {
                    final cw = (c.maxWidth - Sp.md) / 2;
                    return Wrap(spacing: Sp.md, runSpacing: Sp.md,
                        children: [for (final c2 in cards) SizedBox(width: cw, child: c2)]);
                  })
                else
                  Column(children: [for (final c2 in cards) Padding(padding: const EdgeInsets.only(bottom: Sp.md), child: c2)]),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _hero(bool wide, String userName, VoidCallback goWrite) => Container(
                  width: double.infinity, clipBehavior: Clip.antiAlias,
                  padding: EdgeInsets.all(wide ? Sp.xl : Sp.lg),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                        colors: [Color.lerp(AppColors.primary, Colors.white, 0.18)!, AppColors.primary, shade(AppColors.primary, 0.08)]),
                    borderRadius: BorderRadius.circular(wide ? Rad.xl3 : Rad.xl2),
                    boxShadow: softShadow(AppColors.primary)),
                  child: Stack(children: [
                    Positioned(
                      top: wide ? -28 : -12, right: wide ? -20 : -12,
                      child: Opacity(opacity: wide ? 0.2 : 0.16,
                          child: Text('🐘', style: TextStyle(fontSize: wide ? 180 : 96)))),
                    Padding(
                      // Wide: the hero sits in an IntrinsicHeight row, so its text width is set with padding
                      // (which intrinsics measure correctly) rather than a max-width box.
                      padding: EdgeInsets.only(right: wide ? 150 : Sp.sm),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: wide ? double.infinity : 560),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: 6),
                            margin: const EdgeInsets.only(bottom: Sp.sm),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.22),
                                borderRadius: BorderRadius.circular(9999)),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.star, size: 14, color: AppColors.textOnPrimary),
                              const SizedBox(width: 6),
                              Flexible(child: Text('Namaste, $userName! नमस्ते',
                                  style: Fonts.body(13, w: FontWeight.w800, color: AppColors.textOnPrimary))),
                            ]),
                          ),
                          Text("Let's learn to read & write Hindi!",
                              style: Fonts.display(wide ? 38 : 28, color: AppColors.textOnPrimary,
                                  height: wide ? 44 / 38 : 34 / 28)),
                          const SizedBox(height: Sp.sm),
                          Text('Tap letters to hear them, trace to write them, and play games to remember them.',
                              style: Fonts.body(15, color: AppColors.textOnPrimary.withOpacity(0.94),
                                  w: FontWeight.w500, height: 21 / 15)),
                          const SizedBox(height: Sp.md),
                          Pressable(
                            onTap: goWrite,
                            child: Container(
                              constraints: const BoxConstraints(minHeight: 48),
                              padding: const EdgeInsets.symmetric(horizontal: Sp.lg, vertical: 14),
                              decoration: BoxDecoration(color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(9999),
                                  boxShadow: toyShadow(AppColors.primaryDark, 5)),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Text('Start learning', style: Fonts.body(16, w: FontWeight.w800, color: AppColors.primary)),
                                const SizedBox(width: 8),
                                Icon(Icons.arrow_forward, size: 18, color: AppColors.primary),
                              ]),
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ]),
                );

  Widget _statsRow(bool wide, int currentStreak, int totalStars, int mastered, int total, double pct) {
    const a = _StreakCard();
    final b = _StatCard(icon: Icons.star, tint: AppColors.starGold, value: '$totalStars', label: 'Stars earned');
    final c = Container(
      padding: const EdgeInsets.all(Sp.md),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(Rad.xl),
          border: Border.all(color: AppColors.border), boxShadow: toyShadow(AppColors.toyShadowColor, 3)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Letters learned', style: Fonts.body(14, w: FontWeight.w700, color: AppColors.textSecondary)),
          Text('$mastered/$total', style: Fonts.body(14, w: FontWeight.w800)),
        ]),
        const SizedBox(height: Sp.sm),
        HsProgressBar(progress: pct, height: 12),
      ]),
    );
    if (wide) {
      return Column(children: [
        a,
        const SizedBox(height: Sp.sm),
        IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: b), const SizedBox(width: Sp.sm), Expanded(flex: 2, child: c),
        ])),
      ]);
    }
    return Column(children: [
      a,
      const SizedBox(height: Sp.sm),
      b,
      const SizedBox(height: Sp.sm), c,
    ]);
  }
}

/// Today's practice goal: a progress ring and a nudge to keep going. [tall]
/// is the column version that sits beside the hero on wide screens.
/// Avatar (opens Profile), name in English and Hindi, a Rewards chip and Settings.
class _HomeHeader extends StatefulWidget {
  const _HomeHeader();
  @override
  State<_HomeHeader> createState() => _HomeHeaderState();
}

/// Avatar + name open the profile drop-down (score, profile, switch learner,
/// parent zone, settings, help); the Rewards chip stays on the bar.
class _HomeHeaderState extends State<_HomeHeader> {
  final _anchor = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final (userName, avatar, stars) =
        context.select<AppStore, (String, String, int)>((s) => (s.userName, s.avatar, s.totalStars));
    final streak = context.select<AppStore, int>((s) => s.currentStreak);
    return Row(children: [
      Expanded(child: Tooltip(message: tr('Profile menu', 'प्रोफ़ाइल मेनू'), child: Pressable(
        onTap: () => showProfileMenu(context, _anchor),
        child: Row(key: _anchor, children: [
          Container(
            width: 52, height: 52, alignment: Alignment.center,
            decoration: BoxDecoration(gradient: toneGradient(AppColors.primary), shape: BoxShape.circle,
                border: Border.all(color: AppColors.surface, width: 3), boxShadow: toyShadow(AppColors.primaryDark, 3)),
            child: avatar.isNotEmpty
                ? Text(avatar, style: const TextStyle(fontSize: 26))
                : Text(userName.isEmpty ? '?' : userName[0].toUpperCase(),
                    style: Fonts.display(22, color: AppColors.textOnPrimary)),
          ),
          const SizedBox(width: Sp.sm + 4),
          Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(userName, maxLines: 1, overflow: TextOverflow.ellipsis, style: Fonts.display(20, height: 1.15)),
            HindiNameLine(color: AppColors.textSecondary, size: 15),
          ])),
          const SizedBox(width: 4),
          Icon(Icons.keyboard_arrow_down_rounded, size: 26, color: AppColors.textSecondary),
        ]),
      ))),
      const SizedBox(width: Sp.sm),
      Tooltip(message: tr('$streak-day streak', '$streak दिन लगातार'), child: Container(
        height: 44, padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
            color: streak > 0 ? const Color(0xFFFFF1E3) : AppColors.surface,
            borderRadius: BorderRadius.circular(9999),
            border: Border.all(color: streak > 0 ? const Color(0xFFFFC48A) : AppColors.border),
            boxShadow: toyShadow(AppColors.toyShadowColor, 2)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.local_fire_department_rounded, size: 20,
              color: streak > 0 ? const Color(0xFFF26B1D) : AppColors.textMuted),
          const SizedBox(width: 2),
          Text('$streak', style: Fonts.body(15, w: FontWeight.w800)),
        ]),
      )),
      const SizedBox(width: Sp.sm),
      Pressable(
        onTap: () => openScreen(context, 'Rewards'),
        child: Container(
          height: 44, padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(9999),
              border: Border.all(color: AppColors.border), boxShadow: toyShadow(AppColors.toyShadowColor, 2)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.emoji_events_rounded, size: 20, color: AppColors.starGold),
            const SizedBox(width: 4),
            Text('$stars', style: Fonts.body(15, w: FontWeight.w800)),
          ]),
        ),
      ),
    ]);
  }
}

class _GoalCard extends StatelessWidget {
  final int current, goal; final bool tall; final VoidCallback onTap;
  const _GoalCard({required this.current, required this.goal, required this.tall, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final done = current >= goal;
    final left = (goal - current).clamp(0, goal);
    final title = Text("Today's goal", style: Fonts.display(tall ? 22 : 18, height: 1.2));
    final msg = Text(
        done ? 'Goal reached — shabaash! 🎉' : '$left more ${left == 1 ? 'practice' : 'practices'} to hit your goal',
        maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: tall ? TextAlign.center : TextAlign.start,
        style: Fonts.body(13, w: FontWeight.w600, color: AppColors.textSecondary, height: 1.35));
    final decoration = BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(tall ? Rad.xl2 : Rad.xl),
        border: Border.all(color: done ? AppColors.success.withOpacity(0.5) : AppColors.border),
        boxShadow: toyShadow(AppColors.toyShadowColor, tall ? 4 : 3));
    if (!tall) {
      return Pressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(Sp.md), decoration: decoration,
          child: Row(children: [
            DailyGoalRing(current: current, goal: goal, size: 56, strokeWidth: 6),
            const SizedBox(width: Sp.md),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [title, const SizedBox(height: 2), msg])),
            Icon(Icons.chevron_right_rounded, size: 26, color: AppColors.textSecondary),
          ]),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(Sp.lg), decoration: decoration,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        title,
        const SizedBox(height: Sp.md),
        DailyGoalRing(current: current, goal: goal, size: 112, strokeWidth: 10),
        const SizedBox(height: Sp.md),
        msg,
        const SizedBox(height: Sp.md),
        ToyButton(label: done ? 'Keep practising' : 'Practice now', size: ToySize.sm, variant: done ? ToyVariant.success : ToyVariant.primary,
            onPressed: onTap, trailing: Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.textOnPrimary)),
      ]),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon; final Color tint; final String value, label;
  const _StatCard({required this.icon, required this.tint, required this.value, required this.label});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(Sp.md),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(Rad.xl),
            border: Border.all(color: AppColors.border), boxShadow: toyShadow(AppColors.toyShadowColor, 3)),
        child: Row(children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [tint.withOpacity(0.14), tint.withOpacity(0.30)]),
              borderRadius: BorderRadius.circular(14)), child: Icon(icon, size: 22, color: shade(tint, 0.08))),
          const SizedBox(width: Sp.sm + 4),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: Fonts.display(26, height: 30 / 26)),
            Text(label, maxLines: 1, softWrap: false, overflow: TextOverflow.fade,
                style: Fonts.body(12.5, w: FontWeight.w700, color: AppColors.textSecondary)),
          ])),
        ]),
      );
}

class _ActivityCard extends StatelessWidget {
  final IconData icon; final Color tone; final String title, hindi, desc; final VoidCallback onTap;
  const _ActivityCard({required this.icon, required this.tone, required this.title,
      required this.hindi, required this.desc, required this.onTap});
  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(Sp.md),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(Rad.xl),
              border: Border.all(color: AppColors.border), boxShadow: toyShadow(AppColors.toyShadowColor, 4)),
          child: Row(children: [
            Container(width: 62, height: 62,
                decoration: BoxDecoration(gradient: toneGradient(tone), borderRadius: BorderRadius.circular(20),
                    boxShadow: toyShadow(shade(tone), 4)),
                child: Icon(icon, size: 30, color: AppColors.textOnPrimary)),
            const SizedBox(width: Sp.md),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                Flexible(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Fonts.display(20))),
                const SizedBox(width: 8),
                Text(hindi, maxLines: 1, style: Fonts.hindi(16, color: AppColors.textSecondary)),
              ]),
              const SizedBox(height: 2),
              Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: Fonts.body(13, color: AppColors.textSecondary, w: FontWeight.w500)),
            ])),
            Container(width: 34, height: 34,
                decoration: BoxDecoration(color: tone.withOpacity(0.12), shape: BoxShape.circle),
                child: Icon(Icons.arrow_forward_rounded, size: 18, color: shade(tone, 0.1))),
          ]),
        ),
      );
}

/// The day streak, front and centre: how many days in a row, the best run so
/// far, and this week at a glance (🔥 on streak days, a tick when there was
/// practice, today ringed). Nudges the child when today still needs practice.
class _StreakCard extends StatelessWidget {
  const _StreakCard();

  static const _flame = Color(0xFFF26B1D);
  static String _iso(DateTime d) => d.toIso8601String().split('T').first;

  @override
  Widget build(BuildContext context) {
    final (streak, best, last, practiced, todayCount) = context.select<AppStore, (int, int, String?, List<String>, int)>(
        (s) => (s.currentStreak, s.longestStreak, s.lastActiveDate, s.practicedDates, s.todayPracticeCount));
    final now = DateTime.now().toUtc();
    final today = DateTime.utc(now.year, now.month, now.day);
    final todayIso = _iso(today);
    final practicedSet = practiced.toSet();
    // Days covered by the current streak: [last - streak + 1, last].
    final lastDay = last == null ? null : DateTime.tryParse('${last}T00:00:00Z');
    bool onStreak(DateTime d) =>
        lastDay != null && streak > 0 && !d.isAfter(lastDay) && lastDay.difference(d).inDays < streak;
    // Monday-first week containing today.
    final monday = today.subtract(Duration(days: today.weekday - 1));
    const names = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final practisedToday = practicedSet.contains(todayIso) || todayCount > 0;

    return Container(
      padding: const EdgeInsets.all(Sp.md),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFFFFF4E8), Color(0xFFFFE6CC)]),
        borderRadius: BorderRadius.circular(Rad.xl),
        border: Border.all(color: const Color(0xFFFFCF9E)),
        boxShadow: toyShadow(const Color(0xFFE9B887), 3),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 52, height: 52, alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFB25B), _flame]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: toyShadow(const Color(0xFFC4561A), 3)),
            child: const Icon(Icons.local_fire_department_rounded, size: 32, color: Colors.white),
          ),
          const SizedBox(width: Sp.sm + 4),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              Text('$streak', style: Fonts.display(30, color: const Color(0xFF7A3A0C), height: 1.1)),
              const SizedBox(width: 6),
              Flexible(child: Text(tr('day streak', 'दिन की लगातार गिनती'),
                  style: Fonts.display(17, color: const Color(0xFF7A3A0C)))),
            ]),
            Text(tr('$streak दिन लगातार · Best: $best ${best == 1 ? 'day' : 'days'}', '$streak दिन लगातार · सबसे अच्छा: $best दिन'),
                style: Fonts.body(12.5, w: FontWeight.w700, color: const Color(0xFF9A5A2A))),
          ])),
        ]),
        const SizedBox(height: Sp.md),
        Row(children: [
          for (int i = 0; i < 7; i++) Expanded(child: Builder(builder: (_) {
            final d = monday.add(Duration(days: i));
            final iso = _iso(d);
            final isToday = iso == todayIso;
            final future = d.isAfter(today);
            final fire = onStreak(d);
            final did = practicedSet.contains(iso);
            return Column(children: [
              Text(names[i], style: Fonts.body(11.5, w: FontWeight.w800,
                  color: isToday ? const Color(0xFF7A3A0C) : const Color(0xFFB07A50))),
              const SizedBox(height: 4),
              Container(
                width: 34, height: 34, alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: fire ? _flame : future ? Colors.white.withOpacity(0.45) : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: isToday ? const Color(0xFF7A3A0C) : const Color(0xFFFFCF9E), width: isToday ? 2.5 : 1),
                ),
                child: fire
                    ? const Icon(Icons.local_fire_department_rounded, size: 19, color: Colors.white)
                    : did
                        ? const Icon(Icons.check_rounded, size: 18, color: Color(0xFF2E9E5B))
                        : null,
              ),
              const SizedBox(height: 3),
              Container(width: 5, height: 5, decoration: BoxDecoration(
                  shape: BoxShape.circle, color: did ? const Color(0xFF2E9E5B) : Colors.transparent)),
            ]);
          })),
        ]),
        const SizedBox(height: Sp.sm),
        Row(children: [
          Icon(practisedToday ? Icons.check_circle_rounded : Icons.notifications_active_outlined, size: 16,
              color: practisedToday ? const Color(0xFF2E9E5B) : const Color(0xFFB0581E)),
          const SizedBox(width: 6),
          Expanded(child: Text(
            practisedToday
                ? tr('You practised today — come back tomorrow to keep the fire going!',
                    'आज अभ्यास हो गया — कल फिर आना, आग जलती रहे!')
                : tr('Practise one activity today to keep your streak alive.',
                    'अपनी लगातार गिनती बचाने के लिए आज एक अभ्यास करें।'),
            style: Fonts.body(12.5, w: FontWeight.w700, color: const Color(0xFF8A4B1E)))),
        ]),
      ]),
    );
  }
}
