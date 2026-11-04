import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/accounts.dart';
import '../../l10n.dart';
import '../../store/app_store.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../../widgets/toy_button.dart';
import 'assign_activity_screen.dart';
import 'assignment_widgets.dart';
import 'hub_widgets.dart';
import 'parent_shell.dart';

/// Every assignment, filtered by status and child.
class AssignmentsTab extends StatefulWidget {
  const AssignmentsTab({super.key});
  @override
  State<AssignmentsTab> createState() => _AssignmentsTabState();
}

class _AssignmentsTabState extends State<AssignmentsTab> {
  HomeworkStatus? filter;
  bool allChildren = true;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    final scope = ParentHubScope.of(context);
    final kids = hubChildren(s, scope.parentId);
    final ids = allChildren ? kids.map((k) => k.id).toSet() : {scope.selected.value};
    final all = [for (final k in kids) if (ids.contains(k.id)) ...s.homeworkFor(k.id)];
    // Overdue first, then in progress, assigned, completed (newest).
    const order = [HomeworkStatus.overdue, HomeworkStatus.inProgress, HomeworkStatus.assigned, HomeworkStatus.completed];
    all.sort((a, b) {
      final c = order.indexOf(a.status).compareTo(order.indexOf(b.status));
      if (c != 0) return c;
      if (a.done) return (b.completedAt ?? '').compareTo(a.completedAt ?? '');
      return (a.dueDate ?? '9999').compareTo(b.dueDate ?? '9999');
    });
    final shown = filter == null ? all : all.where((h) => h.status == filter).toList();
    int count(HomeworkStatus? st) => st == null ? all.length : all.where((h) => h.status == st).length;
    final done = all.where((h) => h.done).length;

    return Stack(children: [
      HubTabBody(children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr('Assignments', 'काम'), style: Fonts.display(26, height: 1.1)),
            Text(all.isEmpty ? tr('Homework you set appears here', 'आपका दिया होमवर्क यहाँ दिखेगा')
                : tr('$done of ${all.length} completed', '${all.length} में से $done पूरे'),
                style: Fonts.body(14, w: FontWeight.w600, color: AppColors.textSecondary)),
          ])),
        ]),
        const SizedBox(height: Sp.md),
        if (kids.length > 1) Padding(
          padding: const EdgeInsets.only(bottom: Sp.sm),
          child: SizedBox(height: 40, child: ListView(scrollDirection: Axis.horizontal, children: [
            Padding(padding: const EdgeInsets.only(right: 6), child: HubChip(tr('All children', 'सभी बच्चे'),
                selected: allChildren, onTap: () => setState(() => allChildren = true))),
            for (final k in kids) Padding(padding: const EdgeInsets.only(right: 6), child: HubChip(k.name,
                selected: !allChildren && scope.selected.value == k.id,
                onTap: () => setState(() { allChildren = false; scope.selected.value = k.id; }))),
          ])),
        ),
        SizedBox(height: 40, child: ListView(scrollDirection: Axis.horizontal, children: [
          for (final st in <HomeworkStatus?>[null, ...HomeworkStatus.values]) Padding(
            padding: const EdgeInsets.only(right: 6),
            child: HubChip('${st == null ? tr('All', 'सभी') : st.label} · ${count(st)}', selected: filter == st,
                onTap: () => setState(() => filter = st)),
          ),
        ])),
        const SizedBox(height: Sp.md),
        if (kids.isEmpty)
          EmptyState(emoji: '🧒', title: tr('No children yet', 'अभी कोई बच्चा नहीं'),
              message: tr('Add a child to start setting homework.', 'होमवर्क देने के लिए बच्चा जोड़ें।'),
              actionLabel: tr('Go to Children', 'बच्चे देखें'), onAction: () => ParentShell.of(context)?.goTo(1))
        else if (shown.isEmpty)
          EmptyState(
            emoji: filter == HomeworkStatus.overdue ? '🎯' : filter == HomeworkStatus.completed ? '🌱' : '📝',
            title: filter == null ? tr('No assignments yet', 'अभी कोई काम नहीं')
                : filter == HomeworkStatus.overdue ? tr('Nothing overdue', 'कुछ भी देर से नहीं') : tr('Nothing here', 'यहाँ कुछ नहीं'),
            message: filter == null ? tr('Pick a child and an activity: it shows up on their Home screen.', 'बच्चा और गतिविधि चुनें: यह उनकी होम स्क्रीन पर दिखेगा।')
                : tr('No assignments with this status.', 'इस स्थिति का कोई काम नहीं।'),
            actionLabel: tr('Assign activity', 'काम दें'),
            onAction: () => pushHub(context, AssignActivityScreen(childId: allChildren ? null : scope.selected.value)),
          )
        else
          for (final h in shown) AssignmentCard(h, showChild: kids.length > 1),
        const SizedBox(height: 70),
      ]),
      if (kids.isNotEmpty) Positioned(right: Sp.md, bottom: Sp.md, child: ToyButton(
        label: tr('Assign', 'काम दें'),
        leading: Icon(Icons.add_rounded, size: 20, color: AppColors.textOnPrimary),
        onPressed: () => pushHub(context, AssignActivityScreen(childId: allChildren && kids.length > 1 ? null : scope.selected.value)),
      )),
    ]);
  }
}
