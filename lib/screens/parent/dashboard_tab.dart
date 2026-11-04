import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/parent_hub.dart';
import '../../l10n.dart';
import '../../store/app_store.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../../widgets/common.dart';
import '../../widgets/toy_button.dart';
import '../accounts/account_widgets.dart';
import 'achievements_screen.dart';
import 'assign_activity_screen.dart';
import 'assignment_widgets.dart';
import 'challenges_screen.dart';
import 'child_analytics_screen.dart';
import 'children_tab.dart';
import 'hub_widgets.dart';
import 'parent_shell.dart';
import 'skill_analytics_screen.dart';
import 'weekly_summary_screen.dart';

/// Parent Hub home: greeting, child picker, the child's headline figures,
/// progress by skill, quick actions, open assignments and recent wins.
class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    final scope = ParentHubScope.of(context);
    final parent = s.parentById(scope.parentId)!;
    final kids = hubChildren(s, scope.parentId);
    final i = selectedInsights(context);
    final hour = DateTime.now().hour;
    final greet = hour < 12 ? tr('Good morning', 'सुप्रभात') : hour < 17 ? tr('Good afternoon', 'नमस्ते') : tr('Good evening', 'शुभ संध्या');

    return HubTabBody(children: [
      // Greeting + lock.
      Row(children: [
        Container(width: 52, height: 52, alignment: Alignment.center,
            decoration: BoxDecoration(gradient: toneGradient(AppColors.success), shape: BoxShape.circle,
                border: Border.all(color: AppColors.surface, width: 3), boxShadow: toyShadow(shade(AppColors.success), 3)),
            child: Text(parent.name.isEmpty ? '?' : parent.name[0].toUpperCase(), style: Fonts.display(22, color: Colors.white))),
        const SizedBox(width: Sp.sm + 4),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$greet 👋', style: Fonts.body(13, w: FontWeight.w700, color: AppColors.textSecondary)),
          Text(parent.name.split(' ').first, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: Fonts.display(22, height: 1.15)),
          Text(tr('Parent Hub', 'अभिभावक केंद्र'), style: Fonts.body(12, w: FontWeight.w800, color: AppColors.success)),
        ])),
        Tooltip(message: tr('Lock and return to the app', 'लॉक करके ऐप पर लौटें'), child: SoftPill(
            icon: Icons.lock_rounded, label: tr('Lock', 'लॉक'), onTap: () => lockParentHub(context))),
      ]),
      const SizedBox(height: Sp.md),
      if (i == null) ...[
        EmptyState(emoji: '👧', title: tr('Add your first child', 'पहला बच्चा जोड़ें'),
            message: tr('Each child gets their own progress, homework and reports.', 'हर बच्चे की अपनी प्रगति, होमवर्क और रिपोर्ट होती है।'),
            actionLabel: tr('Add child', 'बच्चा जोड़ें'), onAction: () => showChildEditor(context)),
      ] else ...[
        ChildSelector(kids: kids, selected: i.student.id, onSelect: (id) => scope.selected.value = id,
            onAdd: () => showChildEditor(context)),
        const SizedBox(height: Sp.md),
        _ChildHero(i: i),
        const SizedBox(height: Sp.md),
        HubGrid(children: [
          KpiTile(icon: Icons.star_rounded, color: AppColors.starGold, value: '${i.stars}', label: tr('Total stars', 'कुल सितारे'),
              onTap: () => pushHub(context, const AchievementsScreen())),
          KpiTile(icon: Icons.local_fire_department_rounded, color: AppColors.primary, value: '${i.streak}',
              label: tr('Day streak', 'लगातार दिन'), note: tr('Best ${i.v.longestStreak}', 'सबसे ज़्यादा ${i.v.longestStreak}')),
          KpiTile(icon: Icons.translate_rounded, color: AppColors.secondary, value: '${i.mastered}/${i.totalLetters}',
              label: tr('Letters learned', 'अक्षर सीखे'), onTap: () => pushHub(context, const SkillAnalyticsScreen())),
          KpiTile(icon: Icons.track_changes_rounded, color: AppColors.success,
              value: i.writingAccuracy == null ? '—' : '${i.writingAccuracy}%', label: tr('Writing accuracy', 'लेखन सटीकता'),
              note: tr(bandOf(i.writingAccuracy).label, bandOf(i.writingAccuracy).hindi),
              onTap: () => pushHub(context, const SkillAnalyticsScreen())),
        ]),
        HubSection(tr('Quick actions', 'जल्दी करें')),
        HubGrid(children: [
          QuickAction(icon: Icons.insights_rounded, label: tr('View progress', 'प्रगति देखें'), color: const Color(0xFF4FB2E6),
              onTap: () => pushHub(context, const ChildAnalyticsScreen())),
          QuickAction(icon: Icons.add_task_rounded, label: tr('Assign activity', 'काम दें'), color: AppColors.primary,
              onTap: () => pushHub(context, AssignActivityScreen(childId: i.student.id))),
          QuickAction(icon: Icons.menu_book_rounded, label: tr('Homework', 'होमवर्क'), color: AppColors.success,
              onTap: () => ParentShell.of(context)?.goTo(2)),
          QuickAction(icon: Icons.emoji_events_rounded, label: tr('Challenges', 'चुनौतियाँ'), color: AppColors.secondary,
              onTap: () => pushHub(context, const ChallengesScreen())),
        ]),
        HubSection(tr('Learning progress', 'सीखने की प्रगति'), action: SoftPill(label: tr('Details', 'विवरण'),
            icon: Icons.chevron_right_rounded, onTap: () => pushHub(context, const ChildAnalyticsScreen()))),
        ToyCard(child: Column(children: [
          ProgressRow(label: tr('Letters mastered', 'अक्षर पक्के'), value: '${i.mastered}/${i.totalLetters}',
              fraction: i.mastered / i.totalLetters, color: AppColors.secondary,
              leading: const Text('अ', style: TextStyle(fontSize: 18))),
          for (final c in hubCategories) ProgressRow(
            label: tr(c.label, c.hindi), value: '${i.categoryProgress(c.id) ?? 0}%',
            fraction: (i.categoryProgress(c.id) ?? 0) / 100, color: c.color,
            leading: Text(c.emoji, style: const TextStyle(fontSize: 18)),
          ),
        ])),
        HubSection(tr('This week', 'इस हफ़्ते'), action: SoftPill(label: tr('Weekly summary', 'साप्ताहिक सारांश'),
            icon: Icons.chevron_right_rounded, onTap: () => pushHub(context, const WeeklySummaryScreen()))),
        ChartCard(
          title: tr('Daily practice', 'रोज़ का अभ्यास'),
          caption: tr('Activities finished each day', 'हर दिन पूरी गतिविधियाँ'),
          child: Builder(builder: (_) {
            final days = i.lastDays(7);
            return HubBarChart(values: [for (final d in days) d.practices.toDouble()],
                labels: [for (final d in days) _weekday(d.date)], format: (v) => tr('${v.round()} activities', '${v.round()} गतिविधियाँ'));
          }),
        ),
        if (i.weakAreas.isNotEmpty) ...[
          HubSection(tr('Needs attention', 'ध्यान दें'), action: SoftPill(label: tr('Skills', 'कौशल'),
              icon: Icons.chevron_right_rounded, onTap: () => pushHub(context, const SkillAnalyticsScreen()))),
          for (final w in i.weakAreas.take(2)) WeakAreaTile(w, childId: i.student.id),
        ],
        HubSection(tr('Pending assignments', 'बाकी काम'), action: SoftPill(label: tr('All', 'सभी'),
            icon: Icons.chevron_right_rounded, onTap: () => ParentShell.of(context)?.goTo(2))),
        Builder(builder: (_) {
          final open = i.homework.where((h) => !h.done).toList();
          if (open.isEmpty) {
            return EmptyState(emoji: '📭', title: tr('Nothing pending', 'कुछ बाकी नहीं'),
                message: tr('${i.student.name} has no open assignments.', '${i.student.name} के पास कोई काम बाकी नहीं।'),
                actionLabel: tr('Assign activity', 'काम दें'),
                onAction: () => pushHub(context, AssignActivityScreen(childId: i.student.id)));
          }
          return Column(children: [for (final h in open.take(3)) AssignmentCard(h, showChild: false)]);
        }),
        HubSection(tr('Recent achievements', 'हाल की उपलब्धियाँ'), action: SoftPill(label: tr('All', 'सभी'),
            icon: Icons.chevron_right_rounded, onTap: () => pushHub(context, const AchievementsScreen()))),
        Builder(builder: (_) {
          final ev = achievementEvents(i).take(4).toList();
          if (ev.isEmpty) {
            return EmptyState(emoji: '🌱', title: tr('First wins are coming', 'पहली जीत आने वाली है'),
                message: tr('Achievements appear here as ${i.student.name} learns.', '${i.student.name} के सीखने पर उपलब्धियाँ यहाँ दिखेंगी।'));
          }
          return ToyCard(child: Column(children: [for (final e in ev) AchievementRow(e)]));
        }),
      ],
    ]);
  }
}

String _weekday(DateTime d) => tr(const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d.weekday - 1],
    const ['सोम', 'मंगल', 'बुध', 'गुरु', 'शुक्र', 'शनि', 'रवि'][d.weekday - 1]);

/// Short day name for chart labels.
String weekdayLabel(DateTime d) => _weekday(d);

/// The selected child's banner: avatar, class and age, today's status and
/// an overall progress ring.
class _ChildHero extends StatelessWidget {
  final ChildInsights i;
  const _ChildHero({required this.i});
  @override
  Widget build(BuildContext context) {
    final st = i.student;
    final info = [if (st.grade.isNotEmpty) st.grade, ageLabel(i)].whereType<String>().where((x) => x.isNotEmpty).join(' · ');
    return Pressable(
      onTap: () => pushHub(context, const ChildAnalyticsScreen()),
      child: Container(
        padding: const EdgeInsets.all(Sp.lg),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color.lerp(AppColors.primary, Colors.white, 0.18)!, AppColors.primary, shade(AppColors.primary, 0.08)]),
          borderRadius: BorderRadius.circular(Rad.xl2), boxShadow: softShadow(AppColors.primary)),
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned(right: -18, top: -30, child: Opacity(opacity: 0.14, child: Text('🐘', style: const TextStyle(fontSize: 110)))),
          Row(children: [
            learnerAvatar(st.name, st.avatar, size: 54, ring: Colors.white),
            const SizedBox(width: Sp.md),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(st.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Fonts.display(24, color: AppColors.textOnPrimary, height: 1.1)),
              if (info.isNotEmpty) Text(info, style: Fonts.body(13.5, w: FontWeight.w700, color: AppColors.textOnPrimary.withOpacity(0.92))),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.24), borderRadius: BorderRadius.circular(9999)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(i.activeToday ? Icons.check_circle_rounded : Icons.schedule_rounded, size: 14, color: AppColors.textOnPrimary),
                  const SizedBox(width: 5),
                  Flexible(child: Text(activityStatus(i), maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: Fonts.body(12.5, w: FontWeight.w800, color: AppColors.textOnPrimary))),
                ]),
              ),
            ])),
            ProgressRing(value: i.overallProgress / 100, size: 76, stroke: 8, color: Colors.white,
                center: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('${i.overallProgress}%', style: Fonts.display(19, color: AppColors.textOnPrimary, height: 1)),
                  Text(tr('overall', 'कुल'), style: Fonts.body(10.5, w: FontWeight.w800, color: AppColors.textOnPrimary.withOpacity(0.9))),
                ])),
          ]),
        ]),
      ),
    );
  }
}
