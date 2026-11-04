import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/accounts.dart';
import '../../data/parent_hub.dart';
import '../../app_session.dart';
import '../../l10n.dart';
import '../../routes.dart';
import '../../store/app_store.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../../widgets/common.dart';
import '../../widgets/toy_button.dart';
import '../accounts/account_widgets.dart';
import '../accounts/code_pad.dart';
import 'assign_activity_screen.dart';
import 'child_analytics_screen.dart';
import 'hub_widgets.dart';
import 'parent_shell.dart';

const _ages = [('kid-4-6', '4–6'), ('kid-7-10', '7–10'), ('teen', '11–16'), ('adult', '17+')];
const _avatars = ['🦁', '🐯', '🐼', '🐨', '🐵', '🦊', '🐰', '🐸', '🦄', '🐙', '🦋', '🐢', '🚀', '⚽', '🌸', '⭐'];

/// "Age 7" from the date of birth, else the age group ("Age 7–10").
String? ageLabel(ChildInsights i) {
  final dob = DateTime.tryParse(i.student.dateOfBirth);
  if (dob != null) {
    final now = DateTime.now();
    var y = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) y--;
    return tr('Age $y', 'उम्र $y');
  }
  final g = _ages.where((a) => a.$1 == i.v.ageGroup).firstOrNull;
  return g == null ? null : tr('Age ${g.$2}', 'उम्र ${g.$2}');
}

/// "Practised today" / "Last active 3 days ago" / "Not started yet".
String activityStatus(ChildInsights i) {
  if (i.activeToday) return tr('Practised today', 'आज अभ्यास किया');
  final last = DateTime.tryParse(i.lastActive ?? '');
  if (last == null) return tr('Not started yet', 'अभी शुरू नहीं किया');
  final d = DateTime.now().difference(last).inDays;
  if (d <= 1) return tr('Active yesterday', 'कल सक्रिय');
  return tr('Last active $d days ago', '$d दिन पहले सक्रिय');
}

/// Every child the parent follows, with add, edit, switch and assign.
class ChildrenTab extends StatelessWidget {
  const ChildrenTab({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    final scope = ParentHubScope.of(context);
    final kids = hubChildren(s, scope.parentId);
    return HubTabBody(children: [
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr('Children', 'बच्चे'), style: Fonts.display(26, height: 1.1)),
          Text(tr('${kids.length} ${kids.length == 1 ? 'child' : 'children'} on this device', 'इस डिवाइस पर ${kids.length} बच्चे'),
              style: Fonts.body(14, w: FontWeight.w600, color: AppColors.textSecondary)),
        ])),
        ToyButton(label: tr('Add child', 'बच्चा जोड़ें'), size: ToySize.sm, onPressed: () => showChildEditor(context),
            leading: Icon(Icons.person_add_alt_1_rounded, size: 18, color: AppColors.textOnPrimary)),
      ]),
      const SizedBox(height: Sp.md),
      if (kids.isEmpty)
        EmptyState(emoji: '🧒', title: tr('No children yet', 'अभी कोई बच्चा नहीं'),
            message: tr('Add a child to follow their progress and set them activities.', 'प्रगति देखने और काम देने के लिए बच्चा जोड़ें।'),
            actionLabel: tr('Add child', 'बच्चा जोड़ें'), onAction: () => showChildEditor(context))
      else
        LayoutBuilder(builder: (_, c) {
          final cols = c.maxWidth >= 640 ? 2 : 1;
          final w = (c.maxWidth - Sp.md * (cols - 1)) / cols;
          return Wrap(spacing: Sp.md, runSpacing: Sp.md, children: [
            for (final k in kids) SizedBox(width: w, child: ChildProfileCard(insights: ChildInsights.of(s, k.id))),
          ]);
        }),
      const SizedBox(height: Sp.md),
      Text(tr('Each child’s progress, homework and reports are kept separately.', 'हर बच्चे की प्रगति, होमवर्क और रिपोर्ट अलग रखी जाती है।'),
          textAlign: TextAlign.center, style: Fonts.body(12.5, w: FontWeight.w600, color: AppColors.textMuted)),
    ]);
  }
}

/// One child's profile card: identity, class and age, progress and status.
class ChildProfileCard extends StatelessWidget {
  final ChildInsights insights;
  const ChildProfileCard({super.key, required this.insights});
  @override
  Widget build(BuildContext context) {
    final i = insights;
    final s = context.read<AppStore>();
    final scope = ParentHubScope.of(context);
    final st = i.student;
    final active = st.id == s.activeStudentId;
    final open = i.homework.where((h) => !h.done).length;
    final overdue = i.homework.where((h) => h.overdue).length;
    void view() {
      scope.selected.value = st.id;
      pushHub(context, const ChildAnalyticsScreen());
    }

    Widget stat(String v, String l) => Expanded(child: Column(children: [
          Text(v, style: Fonts.display(19, height: 1.1)),
          Text(l, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: Fonts.body(11, w: FontWeight.w700, color: AppColors.textMuted)),
        ]));

    return ToyCard(
      borderColor: active ? AppColors.primary.withOpacity(0.6) : null, borderWidth: active ? 2 : 1,
      onTap: view,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          learnerAvatar(st.name, st.avatar, size: 56, ring: active ? AppColors.primary : null),
          const SizedBox(width: Sp.md),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(st.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Fonts.display(19, height: 1.1)),
            Text([if (st.grade.isNotEmpty) st.grade, ageLabel(i) ?? ''].where((x) => x.isNotEmpty).join(' · ').ifEmpty(tr('Add class and age', 'कक्षा और उम्र जोड़ें')),
                style: Fonts.body(13, w: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 3),
            Row(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle,
                  color: i.activeToday ? AppColors.success : i.started ? AppColors.warning : AppColors.disabled)),
              const SizedBox(width: 5),
              Flexible(child: Text(activityStatus(i), maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: Fonts.body(12, w: FontWeight.w700, color: AppColors.textSecondary))),
            ]),
          ])),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: AppColors.textSecondary),
            color: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rad.lg)),
            onSelected: (v) async {
              switch (v) {
                case 'edit': showChildEditor(context, child: st);
                case 'code': showChangeCode(context, st);
                case 'switch': switchToChild(context, st);
                case 'record': openScreen(context, 'StudentRecord', {'studentId': st.id, 'parentId': scope.parentId});
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'edit', child: _menu(Icons.edit_rounded, tr('Edit profile', 'प्रोफ़ाइल बदलें'))),
              PopupMenuItem(value: 'code', child: _menu(Icons.key_rounded, tr('Change login code', 'लॉगिन कोड बदलें'))),
              if (!active && !st.remote) PopupMenuItem(value: 'switch', child: _menu(Icons.swap_horiz_rounded, tr('Switch to ${st.name}', '${st.name} पर जाएँ'))),
              PopupMenuItem(value: 'record', child: _menu(Icons.badge_rounded, tr('Record & devices', 'रिकॉर्ड और डिवाइस'))),
            ],
          ),
        ]),
        const SizedBox(height: Sp.sm),
        _CodeRow(student: st),
        const SizedBox(height: Sp.sm),
        ProgressRow(label: tr('Overall progress', 'कुल प्रगति'), value: '${i.overallProgress}%', fraction: i.overallProgress / 100),
        const SizedBox(height: Sp.sm),
        Row(children: [
          stat('${i.stars}', tr('Stars', 'सितारे')),
          stat('${i.streak}', tr('Streak', 'लगातार')),
          stat('${i.mastered}/${i.totalLetters}', tr('Letters', 'अक्षर')),
          stat(i.writingAccuracy == null ? '—' : '${i.writingAccuracy}%', tr('Accuracy', 'सटीकता')),
        ]),
        const SizedBox(height: Sp.sm),
        Wrap(spacing: Sp.xs, runSpacing: Sp.xs, children: [
          SoftPill(icon: Icons.assignment_rounded, label: tr('$open open', '$open बाकी'),
              color: open == 0 ? AppColors.success : AppColors.primary, onTap: () {
                scope.selected.value = st.id;
                ParentShell.of(context)?.goTo(2);
              }),
          if (overdue > 0) SoftPill(icon: Icons.warning_amber_rounded, label: tr('$overdue overdue', '$overdue देर से'), color: AppColors.error),
          if (active) SoftPill(icon: Icons.phone_android_rounded, label: tr('Using the app', 'ऐप पर है'), color: AppColors.success),
          if (st.remote) SoftPill(icon: Icons.devices_other_rounded, label: tr('Another device', 'दूसरा डिवाइस')),
        ]),
        const SizedBox(height: Sp.md),
        Row(children: [
          Expanded(child: ResultButton(label: tr('Progress', 'प्रगति'), icon: Icons.insights_rounded, filled: false, onTap: view)),
          const SizedBox(width: Sp.sm),
          Expanded(child: ResultButton(label: tr('Assign', 'काम दें'), icon: Icons.add_task_rounded,
              onTap: () => pushHub(context, AssignActivityScreen(childId: st.id)))),
        ]),
      ]),
    );
  }
}

Widget _menu(IconData icon, String label) => Row(children: [
      Icon(icon, size: 20, color: AppColors.textSecondary),
      const SizedBox(width: Sp.sm),
      Text(label, style: Fonts.body(14, w: FontWeight.w700)),
    ]);

/// A child's login code, hidden until the parent taps the eye; tap the code
/// to copy it, or change it.
class _CodeRow extends StatefulWidget {
  final StudentAccount student;
  const _CodeRow({required this.student});
  @override
  State<_CodeRow> createState() => _CodeRowState();
}

class _CodeRowState extends State<_CodeRow> {
  bool shown = false;
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    final remembered = s.isRemembered(widget.student.id);
    return Container(
        padding: const EdgeInsets.fromLTRB(Sp.sm + 2, 6, 4, 6),
        decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(Rad.lg),
            border: Border.all(color: AppColors.border)),
        child: Column(children: [Row(children: [
          Icon(Icons.key_rounded, size: 18, color: AppColors.primaryDark),
          const SizedBox(width: 6),
          Text(tr('Login code', 'लॉगिन कोड'), style: Fonts.body(13, w: FontWeight.w800, color: AppColors.textSecondary)),
          const Spacer(),
          StudentCodeChip(code: widget.student.loginCode, hidden: !shown),
          IconButton(
            tooltip: shown ? tr('Hide', 'छुपाएँ') : tr('Show', 'दिखाएँ'),
            onPressed: () => setState(() => shown = !shown),
            icon: Icon(shown ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20, color: AppColors.textSecondary),
          ),
        ]),
          // "Remember me on this phone": the child goes in without the code here.
          if (remembered) Row(children: [
            Icon(Icons.lock_open_rounded, size: 16, color: AppColors.successDark),
            const SizedBox(width: 6),
            Expanded(child: Text(tr('Remembered on this phone: no code needed', 'इस फ़ोन पर याद है: कोड की ज़रूरत नहीं'),
                style: Fonts.body(12, w: FontWeight.w700, color: AppColors.successDark))),
            TextButton(
              onPressed: () => s.setRemembered(widget.student.id, false),
              child: Text(tr('Forget', 'भूल जाएँ'), style: Fonts.body(13, w: FontWeight.w800, color: AppColors.error)),
            ),
          ]),
        ]),
      );
  }
}

/// Sheet to give a child a new code: a fresh generated one, or one the
/// parent types (6 letters and numbers, not used by another child).
Future<void> showChangeCode(BuildContext context, StudentAccount st) {
  final s = context.read<AppStore>();
  String? message;
  return showModalBottomSheet(
    context: context, useRootNavigator: true, isScrollControlled: true, backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Rad.xl2))),
    builder: (ctx) => StatefulBuilder(builder: (ctx, set) => SafeArea(child: SingleChildScrollView(
      padding: const EdgeInsets.all(Sp.lg),
      child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 460), child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(tr('${st.name}’s login code', '${st.name} का लॉगिन कोड'), style: Fonts.display(22)),
          const SizedBox(height: 4),
          Text(tr('6 letters and numbers. Every child on this device has a different one.',
                  '6 अक्षर और अंक। इस डिवाइस पर हर बच्चे का अलग होता है।'),
              style: Fonts.body(13.5, color: AppColors.textSecondary)),
          const SizedBox(height: Sp.md),
          Center(child: StudentCodeChip(code: s.studentById(st.id)?.loginCode ?? st.loginCode, big: true)),
          const SizedBox(height: Sp.md),
          ResultButton(label: tr('Make a new code', 'नया कोड बनाएँ'), icon: Icons.autorenew_rounded, filled: false, onTap: () {
            s.newStudentCode(st.id);
            set(() => message = tr('New code made. Tell ${st.name}!', 'नया कोड बना। ${st.name} को बताएँ!'));
          }),
          const SizedBox(height: Sp.lg),
          Text(tr('Or type your own', 'या अपना लिखें'), style: Fonts.display(16)),
          const SizedBox(height: Sp.sm),
          CodePad(
            message: message,
            onComplete: (code) async {
              final why = s.setStudentCode(st.id, code);
              if (why == null) {
                set(() => message = tr('Saved! The new code is ${StudentCodes.format(code)}.', 'सेव हुआ! नया कोड ${StudentCodes.format(code)}।'));
                return null;
              }
              return switch (why) {
                'mix' => tr('Use at least one letter and one number.', 'कम से कम एक अक्षर और एक अंक रखें।'),
                'taken' => tr('Another child already has that code.', 'यह कोड किसी और बच्चे का है।'),
                _ => tr('That code can’t be used.', 'यह कोड नहीं चल सकता।'),
              };
            },
          ),
        ],
      ))),
    ))),
  );
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}

/// Makes [st] the learner using the app: leaves the hub and opens their Home.
Future<void> switchToChild(BuildContext context, StudentAccount st) async {
  final ok = await confirmDialog(context, title: tr('Switch to ${st.name}?', '${st.name} पर जाएँ?'),
      message: tr('The Parent Hub locks and the app opens for ${st.name}.', 'अभिभावक केंद्र लॉक होगा और ऐप ${st.name} के लिए खुलेगा।'),
      confirmLabel: tr('Switch', 'बदलें'), cancelLabel: tr('Cancel', 'रद्द करें'));
  if (!ok || !context.mounted) return;
  AppSession.enterLearner(context, st.id);
}

/// Sheet to add a child or edit one: name, avatar, age group and class.
Future<void> showChildEditor(BuildContext context, {StudentAccount? child}) {
  final s = context.read<AppStore>();
  final scope = ParentHubScope.of(context);
  final view = child == null ? null : s.viewOf(child.id);
  final name = TextEditingController(text: child?.name ?? '');
  final grade = TextEditingController(text: child?.grade ?? '');
  var avatar = child?.avatar ?? '';
  var age = view?.ageGroup ?? 'kid-7-10';
  String? error;
  return showModalBottomSheet(
    context: context, useRootNavigator: true, isScrollControlled: true, backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Rad.xl2))),
    builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
      void save() {
        if (name.text.trim().isEmpty) { set(() => error = tr('Enter a name', 'नाम लिखें')); return; }
        if (child == null) {
          final st = s.addStudent(name.text, ageGroup: age, parentId: scope.parentId);
          s.updateStudentProfile(st.id, avatar: avatar, grade: grade.text);
          scope.selected.value = st.id;
          Navigator.of(ctx).pop();
          // Tell the parent the new child's login code straight away.
          showStudentCode(context, st, title: tr('${st.name} is added! Their code:', '${st.name} जुड़ गए! उनका कोड:'));
          return;
        } else {
          s.updateStudentProfile(child.id, name: name.text, avatar: avatar, ageGroup: age, grade: grade.text);
        }
        Navigator.of(ctx).pop();
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(tr('Profile saved', 'प्रोफ़ाइल सेव हुई'))));
      }

      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(Sp.lg), child: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              learnerAvatar(name.text, avatar, size: 56),
              const SizedBox(width: Sp.md),
              Expanded(child: Text(child == null ? tr('Add a child', 'बच्चा जोड़ें') : tr('Edit ${child.name}', '${child.name} बदलें'),
                  style: Fonts.display(22))),
            ]),
            const SizedBox(height: Sp.md),
            AccountField(controller: name, label: tr("Child's name", 'बच्चे का नाम'), hint: tr('e.g. Aarav', 'जैसे Aarav'), maxLength: 30),
            if (error != null) Padding(padding: const EdgeInsets.only(bottom: Sp.sm),
                child: Text(error!, style: Fonts.body(13, w: FontWeight.w700, color: AppColors.error))),
            AccountField(controller: grade, label: tr('Class (optional)', 'कक्षा (वैकल्पिक)'), hint: tr('e.g. Class 2', 'जैसे कक्षा 2'), maxLength: 20),
            fieldLabel(tr('Age', 'उम्र')),
            Wrap(spacing: Sp.xs, runSpacing: Sp.xs, children: [
              for (final a in _ages) HubChip(a.$2, selected: age == a.$1, onTap: () => set(() => age = a.$1)),
            ]),
            fieldLabel(tr('Avatar', 'अवतार')),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final e in ['', ..._avatars]) Pressable(
                onTap: () => set(() => avatar = e),
                child: Container(width: 44, height: 44, alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: avatar == e ? AppColors.primary.withOpacity(0.16) : AppColors.background,
                      shape: BoxShape.circle,
                      border: Border.all(color: avatar == e ? AppColors.primary : AppColors.border, width: avatar == e ? 2 : 1)),
                    child: e.isEmpty
                        ? Text(name.text.isEmpty ? 'A' : name.text[0].toUpperCase(), style: Fonts.display(18, color: AppColors.primaryDark))
                        : Text(e, style: const TextStyle(fontSize: 22))),
              ),
            ]),
            const SizedBox(height: Sp.lg),
            ResultButton(label: child == null ? tr('Add child', 'बच्चा जोड़ें') : tr('Save', 'सेव करें'),
                icon: child == null ? Icons.person_add_alt_1_rounded : Icons.check_rounded, onTap: save),
          ]),
        )))),
      );
    }),
  );
}
