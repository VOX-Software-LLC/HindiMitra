import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/parent_hub.dart';
import '../../l10n.dart';
import '../../store/app_store.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../../widgets/common.dart';
import 'achievements_screen.dart';
import 'children_tab.dart';
import 'dashboard_tab.dart';
import 'hub_widgets.dart';
import 'parent_shell.dart';
import 'weekly_summary_screen.dart';

/// Weekly, monthly and all-time reports: practice time, activities,
/// writing accuracy, letters, consistency, each against the period before.
class ReportsTab extends StatefulWidget {
  const ReportsTab({super.key});
  @override
  State<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<ReportsTab> {
  int period = 0; // week, month, all time

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    final scope = ParentHubScope.of(context);
    final kids = hubChildren(s, scope.parentId);
    final i = selectedInsights(context);
    final days = const [7, 30, 0][period];

    return HubTabBody(children: [
      Text(tr('Learning reports', 'सीखने की रिपोर्ट'), style: Fonts.display(26, height: 1.1)),
      const SizedBox(height: Sp.md),
      if (i == null)
        EmptyState(emoji: '📊', title: tr('No reports yet', 'अभी कोई रिपोर्ट नहीं'),
            message: tr('Add a child to see their reports.', 'रिपोर्ट देखने के लिए बच्चा जोड़ें।'),
            actionLabel: tr('Add child', 'बच्चा जोड़ें'), onAction: () => showChildEditor(context))
      else ...[
        if (kids.length > 1) ...[
          ChildSelector(kids: kids, selected: i.student.id, onSelect: (id) => scope.selected.value = id),
          const SizedBox(height: Sp.md),
        ],
        HubSegmented(options: [tr('This week', 'यह हफ़्ता'), tr('This month', 'यह महीना'), tr('All time', 'शुरू से')],
            selected: period, onChanged: (p) => setState(() => period = p)),
        const SizedBox(height: Sp.md),
        _ReportBody(i: i, days: days),
      ],
    ]);
  }
}

class _ReportBody extends StatelessWidget {
  final ChildInsights i;
  final int days;
  const _ReportBody({required this.i, required this.days});

  @override
  Widget build(BuildContext context) {
    final now = i.period(days);
    final before = days == 0 ? null : i.period(days, offset: days);
    String cmp(num a, num? b, {bool pts = false}) => b == null ? '' : tr('${changeLabel(a, b, percent: pts)} vs before', 'पहले से ${changeLabel(a, b, percent: pts)}');

    // Trend series: days for a week, weeks otherwise.
    final List<String> labels;
    final List<double> time;
    final List<int?> acc, prevAcc;
    final List<double> acts;
    if (days == 7) {
      final d = i.lastDays(7), p = i.lastDays(7, offset: 7);
      labels = [for (final x in d) weekdayLabel(x.date)];
      time = [for (final x in d) x.seconds / 60];
      acts = [for (final x in d) x.practices.toDouble()];
      acc = [for (final x in d) x.accuracy];
      prevAcc = [for (final x in p) x.accuracy];
    } else {
      final weeks = days == 30 ? 5 : 12;
      final w = [for (int k = weeks - 1; k >= 0; k--) i.period(7, offset: k * 7)];
      final pw = [for (int k = weeks * 2 - 1; k >= weeks; k--) i.period(7, offset: k * 7)];
      labels = [for (int k = weeks - 1; k >= 0; k--) k == 0 ? tr('Now', 'अब') : '-${k}w'];
      time = [for (final x in w) x.seconds / 60];
      acts = [for (final x in w) x.practices.toDouble()];
      acc = [for (final x in w) x.accuracy];
      prevAcc = [for (final x in pw) x.accuracy];
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      HubGrid(cols: 3, narrowCols: 2, children: [
        KpiTile(icon: Icons.timer_outlined, color: const Color(0xFF4FB2E6), value: formatDuration(now.seconds),
            label: tr('Practice time', 'अभ्यास समय'), note: before == null ? null : cmp(now.seconds ~/ 60, before.seconds ~/ 60)),
        KpiTile(icon: Icons.check_circle_outline_rounded, color: AppColors.success, value: '${now.practices}',
            label: tr('Activities done', 'पूरी गतिविधियाँ'), note: before == null ? null : cmp(now.practices, before.practices)),
        KpiTile(icon: Icons.track_changes_rounded, color: const Color(0xFFFF7043), value: now.accuracy == null ? '—' : '${now.accuracy}%',
            label: tr('Writing accuracy', 'लेखन सटीकता'),
            note: before == null || now.accuracy == null || before.accuracy == null ? null : cmp(now.accuracy!, before.accuracy, pts: true)),
        KpiTile(icon: Icons.translate_rounded, color: AppColors.secondary, value: '${now.lettersMastered}',
            label: tr('Letters mastered', 'पक्के अक्षर'), note: before == null ? null : cmp(now.lettersMastered, before.lettersMastered)),
        KpiTile(icon: Icons.event_available_rounded, color: AppColors.primary,
            value: days == 0 ? '${now.activeDays}' : '${now.activeDays}/${now.days}',
            label: tr('Active days', 'सक्रिय दिन'), note: before == null ? null : cmp(now.activeDays, before.activeDays)),
        KpiTile(icon: Icons.assignment_turned_in_rounded, color: const Color(0xFFF26E97), value: '${now.homeworkDone}',
            label: tr('Homework done', 'पूरे होमवर्क'), note: before == null ? null : cmp(now.homeworkDone, before.homeworkDone)),
      ]),
      const SizedBox(height: Sp.md),
      _WeeklySummaryBanner(i: i),
      HubSection(tr('Trends', 'रुझान')),
      ChartCard(title: tr('Writing accuracy trend', 'लेखन सटीकता का रुझान'),
          caption: days == 7 ? tr('Each day, compared with the week before', 'हर दिन, पिछले हफ़्ते से तुलना')
              : tr('Each week, compared with the weeks before', 'हर हफ़्ता, पिछले हफ़्तों से तुलना'),
          child: HubLineChart(values: acc, previous: prevAcc, labels: labels, color: const Color(0xFFFF7043))),
      const SizedBox(height: Sp.md),
      ChartCard(title: tr('Practice time', 'अभ्यास समय'), caption: tr('Minutes', 'मिनट'),
          child: HubBarChart(values: time, labels: labels, color: const Color(0xFF4FB2E6), format: (v) => tr('${v.round()} min', '${v.round()} मिनट'))),
      const SizedBox(height: Sp.md),
      ChartCard(title: tr('Activities completed', 'पूरी गतिविधियाँ'),
          child: HubBarChart(values: acts, labels: labels, color: AppColors.success, format: (v) => tr('${v.round()} activities', '${v.round()} गतिविधियाँ'))),
      HubSection(tr('Reading & skills', 'पढ़ना और कौशल')),
      ToyCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(tr('Passes by category in this period', 'इस अवधि में प्रकार अनुसार'), style: Fonts.body(13, w: FontWeight.w700, color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Builder(builder: (_) {
          final maxV = hubCategories.map((c) => now.byCategory[c.id] ?? 0).fold<int>(1, (a, b) => b > a ? b : a);
          return Column(children: [for (final c in hubCategories) ProgressRow(
            label: tr(c.label, c.hindi), value: '${now.byCategory[c.id] ?? 0}${before == null ? '' : '  (${changeLabel(now.byCategory[c.id] ?? 0, before.byCategory[c.id] ?? 0)})'}',
            fraction: (now.byCategory[c.id] ?? 0) / maxV, color: c.color, leading: Text(c.emoji, style: const TextStyle(fontSize: 17)))]);
        }),
      ])),
      HubSection(tr('Consistency', 'नियमितता')),
      ToyCard(child: _ConsistencyGrid(i: i, days: days == 7 ? 7 : 28)),
      const SizedBox(height: Sp.md),
      Row(children: [
        Expanded(child: ResultButton(label: tr('Achievements', 'उपलब्धियाँ'), icon: Icons.emoji_events_rounded, filled: false,
            onTap: () => pushHub(context, const AchievementsScreen()))),
        const SizedBox(width: Sp.sm),
        Expanded(child: ResultButton(label: tr('Weekly summary', 'साप्ताहिक सारांश'), icon: Icons.summarize_rounded,
            onTap: () => pushHub(context, const WeeklySummaryScreen()))),
      ]),
    ]);
  }
}

class _WeeklySummaryBanner extends StatelessWidget {
  final ChildInsights i;
  const _WeeklySummaryBanner({required this.i});
  @override
  Widget build(BuildContext context) => ToyCard(
        onTap: () => pushHub(context, const WeeklySummaryScreen()),
        color: AppColors.primary.withOpacity(0.07), borderColor: AppColors.primary.withOpacity(0.35),
        child: Row(children: [
          const Text('📝', style: TextStyle(fontSize: 28)),
          const SizedBox(width: Sp.sm + 2),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr('Weekly summary', 'साप्ताहिक सारांश'), style: Fonts.display(16)),
            Text(summaryHeadline(i), maxLines: 2, overflow: TextOverflow.ellipsis,
                style: Fonts.body(13, w: FontWeight.w600, color: AppColors.textSecondary)),
          ])),
          Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ]),
      );
}

/// A dot per day (oldest first): filled on days with practice, bigger the
/// more was done.
class _ConsistencyGrid extends StatelessWidget {
  final ChildInsights i;
  final int days;
  const _ConsistencyGrid({required this.i, required this.days});
  @override
  Widget build(BuildContext context) {
    final list = i.lastDays(days);
    final active = list.where((d) => d.active).length;
    final maxN = list.fold<int>(1, (a, d) => d.practices > a ? d.practices : a);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(tr('Practised on $active of the last $days days', 'पिछले $days में से $active दिन अभ्यास'), style: Fonts.body(14, w: FontWeight.w800)),
      const SizedBox(height: Sp.sm),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final d in list) Tooltip(
          message: '${shortDateOf(d.date)} · ${tr('${d.practices} activities', '${d.practices} गतिविधियाँ')}',
          child: Container(
            width: 30, height: 30, alignment: Alignment.center,
            decoration: BoxDecoration(
              color: d.active ? AppColors.success.withOpacity(0.25 + 0.75 * (d.practices / maxN)) : AppColors.muted,
              borderRadius: BorderRadius.circular(9)),
            child: Text('${d.date.day}', style: Fonts.body(11, w: FontWeight.w800,
                color: d.active && d.practices / maxN > 0.5 ? Colors.white : AppColors.textSecondary)),
          ),
        ),
      ]),
      const SizedBox(height: Sp.sm),
      Wrap(spacing: Sp.md, runSpacing: 4, children: [
        for (final (c, t) in [(AppColors.muted, tr('No practice', 'अभ्यास नहीं')), (AppColors.success, tr('More practice = darker', 'ज़्यादा अभ्यास = गहरा'))])
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 14, height: 14, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4))),
            const SizedBox(width: 4),
            Text(t, style: Fonts.body(12, w: FontWeight.w600, color: AppColors.textSecondary)),
          ]),
      ]),
    ]);
  }
}

String shortDateOf(DateTime d) => shortDateLabel(d);

String shortDateLabel(DateTime d) {
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${m[d.month - 1]}';
}
