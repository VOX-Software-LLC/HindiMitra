import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/accounts.dart';
import '../../data/models.dart';
import '../../l10n.dart';
import '../../store/app_store.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../../widgets/common.dart';
import '../../widgets/toy_button.dart';
import 'account_widgets.dart';

/// Every activity with levels (writing first, then reading).
List<ActivityDef> get assignableActivities => [...AppData.writingActivities, ...AppData.readingActivities];

ActivityDef? activityById(String id) => assignableActivities.where((a) => a.id == id).firstOrNull;

/// Sheet where a parent sets homework for [studentId]: finish a level, write
/// a letter well a number of times, or a number of writing practices, with
/// an optional due date and a note.
Future<void> showAssignHomework(BuildContext context, {required String studentId, required String parentId}) {
  final s = context.read<AppStore>();
  final progress = s.recordOf(studentId).activityProgress;
  final note = TextEditingController();
  var kind = HomeworkKind.level;
  var activity = assignableActivities.first;
  int nextLevel(ActivityDef a) => min((progress[a.id] ?? 0) + 1, a.levels.length);
  var level = nextLevel(activity);
  var letter = AppData.allLetters.first;
  var goal = 5;
  int? dueDays = 3;

  return showModalBottomSheet(
    context: context, useRootNavigator: true, isScrollControlled: true, backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Rad.xl2))),
    builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
      final student = s.studentById(studentId)!;
      Widget chip(String label, bool on, VoidCallback tap) => Padding(
            padding: const EdgeInsets.only(right: Sp.xs, bottom: Sp.xs),
            child: ChoiceChip(label: Text(label), selected: on, onSelected: (_) => set(tap)));
      Widget label(String t) => Padding(padding: const EdgeInsets.only(top: Sp.md, bottom: Sp.xs),
          child: Text(t, style: Fonts.body(13, w: FontWeight.w700, color: AppColors.textSecondary)));

      final title = switch (kind) {
        HomeworkKind.level => '${activity.title} · ${tr('Level', 'स्तर')} $level',
        HomeworkKind.letter => tr('Write ${letter.character} well $goal times', '${letter.character} को $goal बार अच्छे से लिखो'),
        HomeworkKind.practice => tr('$goal writing practices', '$goal बार लिखने का अभ्यास'),
      };
      final already = kind == HomeworkKind.level && (progress[activity.id] ?? 0) >= level;

      void assign() {
        final due = dueDays == null ? null
            : DateTime.now().add(Duration(days: dueDays!)).toIso8601String().split('T').first;
        s.assignHomework(Homework(
          id: 'hw-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-${Random().nextInt(1 << 20).toRadixString(36)}',
          studentId: studentId, assignedBy: parentId, kind: kind, title: title, note: note.text.trim(), dueDate: due,
          target: switch (kind) { HomeworkKind.level => activity.id, HomeworkKind.letter => letter.id, HomeworkKind.practice => '' },
          level: kind == HomeworkKind.level ? level : 0, goal: kind == HomeworkKind.level ? 1 : goal,
        ));
        Navigator.of(ctx).pop();
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
            content: Text(tr('Homework set for ${student.name}', '${student.name} को होमवर्क दिया गया'))));
      }

      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SafeArea(child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.9),
          child: SingleChildScrollView(padding: const EdgeInsets.all(Sp.lg), child: Center(child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(tr('Set homework', 'होमवर्क दें'), style: Fonts.display(22)),
              Text(tr('for ${student.name} · ${student.id}', '${student.name} के लिए · ${student.id}'),
                  style: Fonts.body(14, color: AppColors.textSecondary)),
              label(tr('Type', 'प्रकार')),
              Wrap(children: [
                chip(tr('🎯 Finish a level', '🎯 स्तर पूरा करो'), kind == HomeworkKind.level, () => kind = HomeworkKind.level),
                chip(tr('✍️ Practise a letter', '✍️ अक्षर का अभ्यास'), kind == HomeworkKind.letter, () => kind = HomeworkKind.letter),
                chip(tr('💪 Daily writing', '💪 रोज़ लिखना'), kind == HomeworkKind.practice, () => kind = HomeworkKind.practice),
              ]),
              if (kind == HomeworkKind.level) ...[
                label(tr('Activity', 'गतिविधि')),
                _Dropdown<ActivityDef>(
                  value: activity, items: assignableActivities,
                  text: (a) => '${a.title}  ·  ${progress[a.id] ?? 0}/${a.levels.length}',
                  onChanged: (a) => set(() { activity = a; level = nextLevel(a); }),
                ),
                label(tr('Level', 'स्तर')),
                _Dropdown<int>(
                  value: level, items: [for (int i = 1; i <= activity.levels.length; i++) i],
                  text: (i) => '$i · ${activity.levels[i - 1].name}${(progress[activity.id] ?? 0) >= i ? '  ✓' : ''}',
                  onChanged: (i) => set(() => level = i),
                ),
                if (already) Padding(padding: const EdgeInsets.only(top: Sp.xs), child: Text(
                    tr('Already finished once. It counts when they pass it again.', 'यह पहले पूरा हो चुका है। दोबारा पूरा करने पर गिना जाएगा।'),
                    style: Fonts.body(13, w: FontWeight.w700, color: AppColors.error))),
              ],
              if (kind == HomeworkKind.letter) ...[
                label(tr('Letter', 'अक्षर')),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final l in AppData.allLetters) Pressable(
                    onTap: () => set(() => letter = l),
                    child: Container(
                      width: 42, height: 42, alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: letter.id == l.id ? AppColors.primary : AppColors.background,
                        borderRadius: BorderRadius.circular(Rad.md),
                        border: Border.all(color: letter.id == l.id ? AppColors.primaryDark : AppColors.border)),
                      child: Text(l.character, style: Fonts.hindi(20,
                          color: letter.id == l.id ? AppColors.textOnPrimary : AppColors.textPrimary, height: 1.2)),
                    ),
                  ),
                ]),
              ],
              if (kind != HomeworkKind.level) ...[
                label(kind == HomeworkKind.letter ? tr('Good writes (2★ or more)', 'अच्छे लेख (2★ या ज़्यादा)') : tr('Number of writes', 'कितनी बार लिखना')),
                Wrap(children: [for (final n in kind == HomeworkKind.letter ? [3, 5, 10] : [5, 10, 20, 30]) chip('$n', goal == n, () => goal = n)]),
              ],
              label(tr('Due', 'अंतिम तिथि')),
              Wrap(children: [
                for (final d in <(String, int?)>[(tr('Today', 'आज'), 0), (tr('Tomorrow', 'कल'), 1),
                    (tr('In 3 days', '3 दिन में'), 3), (tr('In a week', 'एक हफ़्ते में'), 7), (tr('No date', 'कोई तिथि नहीं'), null)])
                  chip(d.$1, dueDays == d.$2, () => dueDays = d.$2),
              ]),
              const SizedBox(height: Sp.md),
              AccountField(controller: note, label: tr('Note for your child (optional)', 'बच्चे के लिए संदेश (वैकल्पिक)'),
                  hint: tr('e.g. Do this before dinner!', 'जैसे खाने से पहले कर लेना!'), maxLength: 120),
              Container(
                padding: const EdgeInsets.all(Sp.md), margin: const EdgeInsets.only(bottom: Sp.md),
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(Rad.lg)),
                child: Text('📚  $title', style: Fonts.body(15, w: FontWeight.w800)),
              ),
              ResultButton(label: tr('Assign homework', 'होमवर्क दें'), icon: Icons.send_rounded, onTap: assign),
            ]),
          ))),
        )),
      );
    }),
  );
}

class _Dropdown<T> extends StatelessWidget {
  final T value;
  final List<T> items;
  final String Function(T) text;
  final ValueChanged<T> onChanged;
  const _Dropdown({required this.value, required this.items, required this.text, required this.onChanged});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: Sp.md),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(Rad.lg), border: Border.all(color: AppColors.border, width: 1.5)),
        child: DropdownButtonHideUnderline(child: DropdownButton<T>(
          value: value, isExpanded: true, dropdownColor: AppColors.surface, borderRadius: BorderRadius.circular(Rad.lg),
          items: [for (final i in items) DropdownMenuItem(value: i, child: Text(text(i), overflow: TextOverflow.ellipsis,
              style: Fonts.body(15, w: FontWeight.w600)))],
          onChanged: (v) { if (v != null) onChanged(v); },
        )),
      );
}
