import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/accounts.dart';
import '../../data/parent_hub.dart';
import '../../l10n.dart';
import '../../store/app_store.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../../widgets/common.dart';
import '../accounts/account_widgets.dart';
import 'assign_activity_screen.dart';
import 'assignment_detail_screen.dart';
import 'hub_widgets.dart';

/// An assignment in a list: what, for whom, status, attempts, accuracy,
/// time and deadline, with a menu of actions.
class AssignmentCard extends StatelessWidget {
  final Homework h;
  final bool showChild;
  const AssignmentCard(this.h, {super.key, this.showChild = true});
  @override
  Widget build(BuildContext context) {
    final s = context.read<AppStore>();
    final cat = hubCategory(homeworkCategory(h));
    final st = s.studentById(h.studentId);
    final status = h.status;
    Widget fact(IconData i, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(i, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 3),
          Text(t, style: Fonts.body(12, w: FontWeight.w700, color: AppColors.textSecondary)),
        ]);
    return ToyCard(
      margin: const EdgeInsets.only(bottom: Sp.sm),
      onTap: () => pushHub(context, AssignmentDetailScreen(homeworkId: h.id)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 44, height: 44, alignment: Alignment.center,
              decoration: BoxDecoration(color: cat.color.withOpacity(0.14), borderRadius: BorderRadius.circular(14)),
              child: Text(cat.emoji, style: const TextStyle(fontSize: 22))),
          const SizedBox(width: Sp.sm + 2),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(h.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Fonts.body(15, w: FontWeight.w800, height: 1.25)),
            const SizedBox(height: 4),
            Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              StatusChip(status),
              if (showChild && st != null) Row(mainAxisSize: MainAxisSize.min, children: [
                learnerAvatar(st.name, st.avatar, size: 20),
                const SizedBox(width: 4),
                Text(st.name, style: Fonts.body(12, w: FontWeight.w800, color: AppColors.textSecondary)),
              ]),
            ]),
          ])),
          AssignmentMenu(h),
        ]),
        const SizedBox(height: Sp.sm),
        ClipRRect(borderRadius: BorderRadius.circular(9999), child: LinearProgressIndicator(
            value: h.fraction, minHeight: 8, color: status.color, backgroundColor: AppColors.muted)),
        const SizedBox(height: 6),
        Wrap(spacing: Sp.md, runSpacing: 4, children: [
          fact(Icons.repeat_rounded, tr('${h.progress.clamp(0, h.goal)}/${h.goal} attempts', '${h.progress.clamp(0, h.goal)}/${h.goal} प्रयास')),
          if (h.accuracy != null) fact(Icons.track_changes_rounded, '${h.accuracy}%'),
          if (h.secondsSpent > 0) fact(Icons.timer_outlined, formatDuration(h.secondsSpent)),
          fact(Icons.event_rounded, dueLabel(h)),
        ]),
      ]),
    );
  }
}

/// The ⋮ menu of an assignment: edit, extend, reassign, delete.
class AssignmentMenu extends StatelessWidget {
  final Homework h;
  final VoidCallback? onDeleted;
  const AssignmentMenu(this.h, {super.key, this.onDeleted});
  @override
  Widget build(BuildContext context) {
    Widget item(IconData i, String t, {Color? c}) => Row(children: [
          Icon(i, size: 20, color: c ?? AppColors.textSecondary),
          const SizedBox(width: Sp.sm),
          Text(t, style: Fonts.body(14, w: FontWeight.w700, color: c)),
        ]);
    return PopupMenuButton<String>(
      tooltip: tr('Actions', 'विकल्प'),
      icon: Icon(Icons.more_vert_rounded, color: AppColors.textSecondary),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rad.lg)),
      onSelected: (v) => switch (v) {
        'edit' => showEditAssignment(context, h),
        'extend' => showExtendDeadline(context, h),
        'reassign' => showReassign(context, h),
        _ => deleteAssignment(context, h, onDeleted: onDeleted),
      },
      itemBuilder: (_) => [
        if (!h.done) PopupMenuItem(value: 'edit', child: item(Icons.edit_rounded, tr('Edit', 'बदलें'))),
        if (!h.done) PopupMenuItem(value: 'extend', child: item(Icons.more_time_rounded, tr('Extend deadline', 'तिथि बढ़ाएँ'))),
        PopupMenuItem(value: 'reassign', child: item(Icons.replay_rounded, tr('Reassign', 'फिर से दें'))),
        PopupMenuItem(value: 'delete', child: item(Icons.delete_outline_rounded, tr('Delete', 'मिटाएँ'), c: AppColors.error)),
      ],
    );
  }
}

Future<void> deleteAssignment(BuildContext context, Homework h, {VoidCallback? onDeleted}) async {
  final ok = await confirmDialog(context, title: tr('Delete this assignment?', 'यह काम मिटाएँ?'),
      message: tr('“${h.title}” and its attempts will be removed.', '“${h.title}” और उसके प्रयास हट जाएँगे।'),
      confirmLabel: tr('Delete', 'मिटाएँ'), cancelLabel: tr('Cancel', 'रद्द करें'), destructive: true);
  if (!ok || !context.mounted) return;
  context.read<AppStore>().removeHomework(h.id);
  onDeleted?.call();
}

Future<void> _sheet(BuildContext context, String title, Widget Function(BuildContext, StateSetter) body) =>
    showModalBottomSheet(
      context: context, useRootNavigator: true, isScrollControlled: true, backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Rad.xl2))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, set) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(Sp.lg), child: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(title, style: Fonts.display(22)),
            body(ctx, set),
          ]),
        )))),
      )),
    );

Future<void> showExtendDeadline(BuildContext context, Homework h) => _sheet(context, tr('Extend deadline', 'तिथि बढ़ाएँ'), (ctx, set) =>
    Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('${h.title} · ${dueLabel(h)}', style: Fonts.body(14, color: AppColors.textSecondary)),
      const SizedBox(height: Sp.md),
      for (final d in [1, 2, 3, 7]) Padding(
        padding: const EdgeInsets.only(bottom: Sp.sm),
        child: ResultButton(label: tr('+$d day${d == 1 ? '' : 's'}', '+$d दिन'), icon: Icons.more_time_rounded, filled: d == 3,
            onTap: () {
              ctx.read<AppStore>().extendHomework(h.id, d);
              Navigator.of(ctx).pop();
              ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(tr('Deadline extended', 'तिथि बढ़ा दी'))));
            }),
      ),
    ]));

Future<void> showEditAssignment(BuildContext context, Homework h) {
  final note = TextEditingController(text: h.note);
  var goal = h.goal;
  var difficulty = h.difficulty;
  String? due = h.dueDate;
  return _sheet(context, tr('Edit assignment', 'काम बदलें'), (ctx, set) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Text(h.title, style: Fonts.body(14, color: AppColors.textSecondary)),
    fieldLabel(tr('Attempts', 'प्रयास')),
    AttemptStepper(value: goal, min: h.progress.clamp(1, 99), onChanged: (v) => set(() => goal = v)),
    fieldLabel(tr('Difficulty', 'कठिनाई')),
    DifficultyPicker(value: difficulty, onChanged: (v) => set(() => difficulty = v)),
    fieldLabel(tr('Deadline', 'अंतिम तिथि')),
    DeadlinePicker(value: due, onChanged: (v) => set(() => due = v)),
    const SizedBox(height: Sp.md),
    AccountField(controller: note, label: tr('Message for your child', 'बच्चे के लिए संदेश'), maxLength: 120),
    ResultButton(label: tr('Save changes', 'बदलाव सेव करें'), icon: Icons.check_rounded, onTap: () {
      ctx.read<AppStore>().updateHomework(h.id, note: note.text, goal: goal, difficulty: difficulty, dueDate: due, clearDue: due == null);
      Navigator.of(ctx).pop();
    }),
  ]));
}

Future<void> showReassign(BuildContext context, Homework h) {
  final s = context.read<AppStore>();
  final scope = ParentHubScope.of(context);
  final kids = hubChildren(s, scope.parentId);
  var to = h.studentId;
  int? dueDays = 3;
  return _sheet(context, tr('Reassign', 'फिर से दें'), (ctx, set) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Text(tr('A fresh copy of “${h.title}”, with no attempts yet.', '“${h.title}” की नई प्रति, बिना किसी प्रयास के।'),
        style: Fonts.body(14, color: AppColors.textSecondary)),
    fieldLabel(tr('For', 'किसके लिए')),
    Wrap(spacing: Sp.xs, runSpacing: Sp.xs, children: [for (final k in kids) HubChip(k.name, selected: to == k.id, onTap: () => set(() => to = k.id))]),
    fieldLabel(tr('Due', 'अंतिम तिथि')),
    Wrap(spacing: Sp.xs, runSpacing: Sp.xs, children: [
      for (final d in <(String, int?)>[(tr('Tomorrow', 'कल'), 1), (tr('In 3 days', '3 दिन में'), 3),
          (tr('In a week', 'एक हफ़्ते में'), 7), (tr('No date', 'कोई तिथि नहीं'), null)])
        HubChip(d.$1, selected: dueDays == d.$2, onTap: () => set(() => dueDays = d.$2)),
    ]),
    const SizedBox(height: Sp.lg),
    ResultButton(label: tr('Assign again', 'फिर से दें'), icon: Icons.send_rounded, onTap: () {
      s.reassignHomework(h.id, studentId: to, parentId: scope.parentId, dueDays: dueDays);
      Navigator.of(ctx).pop();
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(
          tr('Assigned to ${s.studentById(to)?.name}', '${s.studentById(to)?.name} को दिया गया'))));
    }),
  ]));
}

/// A weak spot with a one-tap "Assign" that opens the assignment flow
/// already set up for it.
class WeakAreaTile extends StatelessWidget {
  final WeakArea w;
  final String childId;
  const WeakAreaTile(this.w, {super.key, required this.childId});
  @override
  Widget build(BuildContext context) {
    final cat = hubCategory(w.category);
    return ToyCard(
      margin: const EdgeInsets.only(bottom: Sp.sm),
      borderColor: SkillBand.needsPractice.color.withOpacity(0.35),
      child: Row(children: [
        Container(width: 40, height: 40, alignment: Alignment.center,
            decoration: BoxDecoration(color: SkillBand.needsPractice.color.withOpacity(0.1), borderRadius: BorderRadius.circular(13)),
            child: Text(cat.emoji, style: const TextStyle(fontSize: 20))),
        const SizedBox(width: Sp.sm + 2),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(w.title, style: Fonts.body(15, w: FontWeight.w800)),
          Text(w.reason, style: Fonts.body(12.5, w: FontWeight.w600, color: AppColors.textSecondary)),
        ])),
        SoftPill(icon: Icons.add_task_rounded, label: tr('Assign', 'काम दें'), onTap: () => pushHub(context, AssignActivityScreen(
            childId: childId, category: w.category, letterId: w.letterId, activityId: w.activityId))),
      ]),
    );
  }
}
