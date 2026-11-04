import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/parent_hub.dart';
import '../../l10n.dart';
import '../../store/app_store.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../../widgets/common.dart';
import '../accounts/account_widgets.dart';
import 'achievements_screen.dart';
import 'assign_activity_screen.dart';
import 'children_tab.dart';
import 'dashboard_tab.dart';
import 'hub_widgets.dart';
import 'skill_analytics_screen.dart';

/// One child's learning overview: overall progress, writing and reading,
/// letters mastered, daily and weekly activity, and achievement history.
class ChildAnalyticsScreen extends StatefulWidget {
  const ChildAnalyticsScreen({super.key});
  @override
  State<ChildAnalyticsScreen> createState() => _ChildAnalyticsScreenState();
}

class _ChildAnalyticsScreenState extends State<ChildAnalyticsScreen> {
  int range = 0; // 0 = last 7 days, 1 = last 4 weeks

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    final scope = ParentHubScope.of(context);
    final i = selectedInsights(context);
    if (i == null) return HubPage(title: tr('Progress', 'प्रगति'), body: const SizedBox.shrink());
    final kids = hubChildren(s, scope.parentId);
    final (ws, wn) = i.wordSkill;

    // Daily (7 days) or weekly (4 weeks) activity.
    final List<double> bars;
    final List<String> labels;
    final List<int?> acc;
    if (range == 0) {
      final days = i.lastDays(7);
      bars = [for (final d in days) d.seconds / 60];
      labels = [for (final d in days) weekdayLabel(d.date)];
      acc = [for (final d in days) d.accuracy];
    } else {
      final weeks = [for (int w = 3; w >= 0; w--) i.period(7, offset: w * 7)];
      bars = [for (final w in weeks) w.seconds / 60];
      labels = [for (int w = 3; w >= 0; w--) w == 0 ? tr('This wk', 'इस हफ़्ते') : tr('$w wk ago', '$w हफ़्ते पहले')];
      acc = [for (final w in weeks) w.accuracy];
    }

    return HubPage(
      title: tr('${i.student.name}’s progress', '${i.student.name} की प्रगति'), subtitle: tr('Learning overview', 'सीखने का सार'),
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (kids.length > 1) ...[
          ChildSelector(kids: kids, selected: i.student.id, onSelect: (id) => scope.selected.value = id),
          const SizedBox(height: Sp.md),
        ],
        // Overview card.
        ToyCard(padding: const EdgeInsets.all(Sp.lg), child: Row(children: [
          ProgressRing(value: i.overallProgress / 100, size: 108, stroke: 11, center: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('${i.overallProgress}%', style: Fonts.display(26, height: 1)),
            Text(tr('overall', 'कुल'), style: Fonts.body(11.5, w: FontWeight.w800, color: AppColors.textSecondary)),
          ])),
          const SizedBox(width: Sp.lg),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              learnerAvatar(i.student.name, i.student.avatar, size: 32),
              const SizedBox(width: Sp.sm),
              Expanded(child: Text(i.student.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Fonts.display(19))),
            ]),
            const SizedBox(height: 4),
            Text(activityStatus(i), style: Fonts.body(13, w: FontWeight.w700, color: AppColors.textSecondary)),
            const SizedBox(height: Sp.sm),
            Text(tr('Letters mastered', 'पक्के अक्षर'), style: Fonts.body(12.5, w: FontWeight.w700, color: AppColors.textSecondary)),
            Text('${i.mastered} / ${i.totalLetters}', style: Fonts.display(22, color: AppColors.secondary)),
            const SizedBox(height: 4),
            ClipRRect(borderRadius: BorderRadius.circular(9999), child: LinearProgressIndicator(
                value: i.mastered / i.totalLetters, minHeight: 8, color: AppColors.secondary, backgroundColor: AppColors.muted)),
          ])),
        ])),
        const SizedBox(height: Sp.md),
        HubGrid(children: [
          KpiTile(icon: Icons.edit_rounded, color: const Color(0xFFFF7043), value: i.writingAccuracy == null ? '—' : '${i.writingAccuracy}%',
              label: tr('Writing accuracy', 'लेखन सटीकता'), note: tr(bandOf(i.writingAccuracy).label, bandOf(i.writingAccuracy).hindi)),
          KpiTile(icon: Icons.menu_book_rounded, color: AppColors.success, value: '${i.readingScore}%',
              label: tr('Reading progress', 'पढ़ने की प्रगति'), note: tr('${i.readingLevels} levels passed', '${i.readingLevels} स्तर पूरे')),
          KpiTile(icon: Icons.spellcheck_rounded, color: const Color(0xFF4FB2E6), value: ws == null ? '—' : '$ws%',
              label: tr('Word writing', 'शब्द लेखन'), note: tr('$wn words practised', '$wn शब्द')),
          KpiTile(icon: Icons.calendar_month_rounded, color: AppColors.primary, value: '${i.v.practicedDates.length}',
              label: tr('Days practised', 'अभ्यास के दिन'), note: tr('Streak ${i.streak}', 'लगातार ${i.streak}')),
        ]),
        HubSection(tr('Activity', 'गतिविधि'), action: SizedBox(width: 190, child: HubSegmented(
            options: [tr('Daily', 'रोज़'), tr('Weekly', 'हफ़्ते')], selected: range, onChanged: (v) => setState(() => range = v)))),
        ChartCard(
          title: tr('Practice time', 'अभ्यास का समय'),
          caption: range == 0 ? tr('Minutes each day, last 7 days', 'पिछले 7 दिन, हर दिन के मिनट')
              : tr('Minutes each week, last 4 weeks', 'पिछले 4 हफ़्ते, हर हफ़्ते के मिनट'),
          child: HubBarChart(values: bars, labels: labels, format: (v) => tr('${v.round()} min', '${v.round()} मिनट')),
        ),
        const SizedBox(height: Sp.md),
        ChartCard(
          title: tr('Writing accuracy', 'लेखन सटीकता'),
          caption: tr('Average score of graded writes', 'जाँचे गए लेखन का औसत'),
          child: HubLineChart(values: acc, labels: labels, color: const Color(0xFFFF7043)),
        ),
        HubSection(tr('Skills', 'कौशल'), action: SoftPill(label: tr('Detailed', 'विस्तार से'), icon: Icons.chevron_right_rounded,
            onTap: () => pushHub(context, const SkillAnalyticsScreen()))),
        ToyCard(child: Column(children: [
          for (final c in hubCategories) ProgressRow(
            label: tr(c.label, c.hindi), value: '${i.categoryProgress(c.id) ?? 0}%',
            fraction: (i.categoryProgress(c.id) ?? 0) / 100, color: c.color,
            leading: Text(c.emoji, style: const TextStyle(fontSize: 18)),
          ),
        ])),
        HubSection(tr('Achievement history', 'उपलब्धियों का इतिहास'), action: SoftPill(label: tr('All', 'सभी'),
            icon: Icons.chevron_right_rounded, onTap: () => pushHub(context, const AchievementsScreen()))),
        Builder(builder: (_) {
          final ev = achievementEvents(i).take(6).toList();
          if (ev.isEmpty) {
            return EmptyState(emoji: '🌱', title: tr('No achievements yet', 'अभी कोई उपलब्धि नहीं'),
                message: tr('Set a small first task to get ${i.student.name} going.', '${i.student.name} की शुरुआत के लिए छोटा काम दें।'),
                actionLabel: tr('Assign activity', 'काम दें'),
                onAction: () => pushHub(context, AssignActivityScreen(childId: i.student.id)));
          }
          return ToyCard(child: Column(children: [for (final e in ev) AchievementRow(e)]));
        }),
      ]),
    );
  }
}
