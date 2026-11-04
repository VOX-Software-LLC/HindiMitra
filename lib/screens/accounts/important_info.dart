import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/accounts.dart';
import '../../l10n.dart';
import '../../routes.dart';
import '../../store/app_store.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../../widgets/common.dart';
import '../../widgets/hindi_name.dart';
import '../../widgets/toy_button.dart';
import 'account_widgets.dart';
import 'code_pad.dart';
import 'homework_sheet.dart';
import '../../data/parent_hub.dart';

/// "Important information" of a learner's account: their Student ID, their
/// details and the linked parents' IDs and contacts. Editing needs a
/// parent's PIN once a parent is set up; [unlocked] skips that (the parent
/// is already signed in to parent control).
class ImportantInfoCard extends StatelessWidget {
  final String studentId;
  final bool unlocked;
  const ImportantInfoCard({super.key, required this.studentId, this.unlocked = false});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    final st = s.studentById(studentId);
    if (st == null) return const SizedBox.shrink();
    final guardians = s.parentsOf(st.id);
    final isActive = st.id == s.activeStudentId;

    Future<void> edit() async {
      if (!unlocked && (s.parents.isNotEmpty)) {
        final p = await requireParent(context, forStudentId: st.id);
        if (p == null || !context.mounted) return;
      }
      await showStudentInfoEditor(context, st.id);
    }

    Future<void> linkParent() async {
      final p = await requireParent(context);
      if (p != null && context.mounted) context.read<AppStore>().linkParent(st.id, p.id);
    }

    return ToyCard(
      margin: const EdgeInsets.only(bottom: Sp.lg),
      padding: const EdgeInsets.fromLTRB(Sp.md, Sp.md, Sp.md, Sp.sm),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(Icons.badge_rounded, color: AppColors.primary), const SizedBox(width: Sp.sm),
          Expanded(child: Text(tr('Important information', 'ज़रूरी जानकारी'), style: Fonts.display(18))),
          SoftPill(icon: unlocked || s.parents.isEmpty ? Icons.edit_rounded : Icons.lock_rounded,
              label: tr('Edit', 'बदलें'), onTap: edit),
        ]),
        const SizedBox(height: Sp.sm),
        InfoRow(icon: Icons.fingerprint_rounded, label: tr('Student ID', 'Student ID'), trailing: IdChip(st.id)),
        InfoRow(icon: Icons.person_rounded, label: tr('Name', 'नाम'), value: st.name),
        if (isActive || unlocked) InfoRow(icon: Icons.key_rounded, label: tr('Login code', 'लॉगिन कोड'),
            trailing: StudentCodeChip(code: st.loginCode)),
        if (isActive) InfoRow(icon: Icons.translate_rounded, label: tr('Name in Hindi', 'हिंदी में नाम'), value: hindiNameOf(s)),
        InfoRow(icon: Icons.cake_rounded, label: tr('Date of birth', 'जन्म तिथि'), value: shortDate(st.dateOfBirth)),
        InfoRow(icon: Icons.school_rounded, label: tr('Class / grade', 'कक्षा'), value: st.grade),
        InfoRow(icon: Icons.account_balance_rounded, label: tr('School', 'स्कूल'), value: st.school),
        InfoRow(icon: Icons.location_city_rounded, label: tr('City', 'शहर'), value: st.city),
        InfoRow(icon: Icons.emergency_rounded, label: tr('Emergency contact', 'आपातकालीन संपर्क'), value: st.emergencyContact),
        InfoRow(icon: Icons.event_rounded, label: tr('Member since', 'सदस्य कब से'), value: shortDate(st.createdAt)),
        if (isActive && st.paired) InfoRow(icon: Icons.sync_rounded, label: tr('Cloud', 'क्लाउड'),
            value: tr('Paired: syncs with your parent', 'जुड़ा है: अभिभावक के साथ सिंक')),
        if (st.notes.isNotEmpty) InfoRow(icon: Icons.sticky_note_2_rounded, label: tr('Notes', 'नोट'), value: st.notes),
        Divider(color: AppColors.border, height: Sp.lg),
        Text(tr('Parents / guardians', 'अभिभावक'), style: Fonts.body(14, w: FontWeight.w800, color: AppColors.textSecondary)),
        const SizedBox(height: Sp.xs),
        if (guardians.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Sp.sm),
            child: Row(children: [
              Expanded(child: Text(tr('No parent linked yet. A parent can track progress and set homework.',
                      'अभी कोई अभिभावक जुड़ा नहीं है। अभिभावक प्रगति देख सकते हैं और होमवर्क दे सकते हैं।'),
                  style: Fonts.body(13, color: AppColors.textSecondary))),
              const SizedBox(width: Sp.sm),
              SoftPill(icon: Icons.link_rounded, label: tr('Link parent', 'अभिभावक जोड़ें'), onTap: linkParent),
            ]),
          ),
        for (final (i, p) in guardians.indexed) Container(
          margin: const EdgeInsets.only(bottom: Sp.sm),
          padding: const EdgeInsets.all(Sp.sm + 2),
          decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(Rad.lg),
              border: Border.all(color: AppColors.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text('${p.name} · ${p.relationship}', style: Fonts.body(15, w: FontWeight.w800))),
              if (i == 0) SoftPill(label: tr('Primary', 'मुख्य'), color: AppColors.success),
            ]),
            InfoRow(icon: Icons.fingerprint_rounded, label: tr('Parent ID', 'Parent ID'), trailing: IdChip(p.id, color: AppColors.success)),
            if (p.phone.isNotEmpty) InfoRow(icon: Icons.phone_rounded, label: tr('Phone', 'फ़ोन'), value: p.phone),
            if (p.email.isNotEmpty) InfoRow(icon: Icons.mail_rounded, label: tr('Email', 'ईमेल'), value: p.email),
          ]),
        ),
      ]),
    );
  }
}

/// Form for a learner's details (name, birth date, class, school, city,
/// emergency contact, notes).
Future<void> showStudentInfoEditor(BuildContext context, String studentId) {
  final s = context.read<AppStore>();
  final st = s.studentById(studentId)!;
  final name = TextEditingController(text: st.name), grade = TextEditingController(text: st.grade),
      school = TextEditingController(text: st.school), city = TextEditingController(text: st.city),
      emergency = TextEditingController(text: st.emergencyContact), notes = TextEditingController(text: st.notes);
  String dob = st.dateOfBirth;
  return showModalBottomSheet(
    context: context, useRootNavigator: true, isScrollControlled: true, backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Rad.xl2))),
    builder: (ctx) => StatefulBuilder(builder: (ctx, set) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: SafeArea(child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.88),
        child: SingleChildScrollView(padding: const EdgeInsets.all(Sp.lg), child: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(tr('Edit important information', 'ज़रूरी जानकारी बदलें'), style: Fonts.display(20)),
            Text(st.id, style: TextStyle(fontFamily: 'monospace', fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: Sp.md),
            AccountField(controller: name, label: tr('Name', 'नाम'), maxLength: 30),
            Padding(padding: const EdgeInsets.only(bottom: Sp.xs),
                child: Text(tr('Date of birth', 'जन्म तिथि'), style: Fonts.body(13, w: FontWeight.w700, color: AppColors.textSecondary))),
            Pressable(
              onTap: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(context: ctx, firstDate: DateTime(now.year - 80), lastDate: now,
                    initialDate: DateTime.tryParse(dob) ?? DateTime(now.year - 7));
                if (picked != null) set(() => dob = picked.toIso8601String().split('T').first);
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: Sp.md), padding: const EdgeInsets.all(Sp.md),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(Rad.lg), border: Border.all(color: AppColors.border, width: 1.5)),
                child: Row(children: [
                  Expanded(child: Text(dob.isEmpty ? tr('Choose a date', 'तारीख चुनें') : shortDate(dob),
                      style: Fonts.body(16, color: dob.isEmpty ? AppColors.textMuted : AppColors.textPrimary))),
                  Icon(Icons.calendar_month_rounded, color: AppColors.primary),
                ]),
              ),
            ),
            AccountField(controller: grade, label: tr('Class / grade', 'कक्षा'), hint: tr('e.g. Class 3', 'जैसे कक्षा 3'), maxLength: 20),
            AccountField(controller: school, label: tr('School', 'स्कूल'), maxLength: 60),
            AccountField(controller: city, label: tr('City', 'शहर'), maxLength: 40),
            AccountField(controller: emergency, label: tr('Emergency contact', 'आपातकालीन संपर्क'),
                hint: tr('Name and phone', 'नाम और फ़ोन'), maxLength: 60),
            AccountField(controller: notes, label: tr('Notes (allergies, needs…)', 'नोट (एलर्जी, ज़रूरतें…)'), maxLines: 3, maxLength: 200),
            ResultButton(label: tr('Save', 'सेव करें'), icon: Icons.check_rounded, onTap: () {
              final store = context.read<AppStore>();
              if (name.text.trim().isNotEmpty && name.text.trim() != st.name) {
                if (st.id == store.activeStudentId) {
                  store.setUserName(name.text.trim());
                } else {
                  st.name = name.text.trim();
                }
              }
              store.updateStudentInfo(st.id, dateOfBirth: dob, grade: grade.text, school: school.text, city: city.text,
                  emergencyContact: emergency.text, notes: notes.text);
              Navigator.of(ctx).pop();
            }),
          ]),
        ))),
      )),
    )),
  );
}

/// The active learner's open homework and challenges from their parents
/// (Home screen). Hidden when there is none.
class HomeworkCard extends StatelessWidget {
  const HomeworkCard({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    final open = s.homeworkFor(s.activeStudentId).where((h) => !h.done).toList();
    // Recently finished work with a parent's message stays a few days, so the child sees it.
    final cheered = s.homeworkFor(s.activeStudentId).where((h) => h.done && h.feedback.isNotEmpty &&
        DateTime.now().difference(DateTime.tryParse(h.feedback.last.at) ?? DateTime(2000)).inDays < 3).toList();
    final challenges = s.challengesFor(s.activeStudentId)
        .where((c) => !c.expired && (!c.done || DateTime.now().difference(DateTime.tryParse(c.completedAt!) ?? DateTime(2000)).inDays < 2))
        .toList();
    if (open.isEmpty && cheered.isEmpty && challenges.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (open.isNotEmpty || cheered.isNotEmpty) ToyCard(
        margin: const EdgeInsets.only(top: Sp.sm),
        borderColor: AppColors.primary.withOpacity(0.5), borderWidth: 2,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Text('📚', style: TextStyle(fontSize: 22)), const SizedBox(width: Sp.sm),
            Expanded(child: Text(tr('Homework', 'होमवर्क'), style: Fonts.display(20))),
            if (open.isNotEmpty) SoftPill(label: tr('${open.length} to do', '${open.length} बाकी')),
          ]),
          const SizedBox(height: Sp.sm),
          for (final h in open.take(3)) HomeworkTile(h, onGo: () => openHomework(context, h)),
          for (final h in cheered.take(2)) HomeworkTile(h),
        ]),
      ),
      for (final c in challenges.take(2)) _ChildChallengeCard(c),
    ]);
  }
}

/// A parent's challenge as the child sees it.
class _ChildChallengeCard extends StatelessWidget {
  final Challenge c;
  const _ChildChallengeCard(this.c);
  @override
  Widget build(BuildContext context) {
    final s = context.read<AppStore>();
    final by = s.parentById(c.parentId);
    final kind = challengeKind(c.category);
    final tone = c.done ? AppColors.success : AppColors.secondary;
    return ToyCard(
      margin: const EdgeInsets.only(top: Sp.sm),
      borderColor: tone.withOpacity(0.45), borderWidth: 2,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Text(c.done ? '🏆' : kind.emoji, style: const TextStyle(fontSize: 24)), const SizedBox(width: Sp.sm),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c.done ? tr('Challenge won!', 'चुनौती जीती!') : tr('Challenge', 'चुनौती'),
                style: Fonts.body(12, w: FontWeight.w800, color: tone)),
            Text(c.title, style: Fonts.display(18, height: 1.15)),
          ])),
          SoftPill(label: c.reward == 'stars' ? '+${c.rewardStars} ⭐' : c.reward == 'badge' ? c.badgeEmoji : '📜',
              color: const Color(0xFFB8860B)),
        ]),
        if (c.message.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4),
            child: Text('“${c.message}”${by == null ? '' : ' — ${by.name}'}', style: Fonts.body(13, color: AppColors.textSecondary))),
        const SizedBox(height: 8),
        ClipRRect(borderRadius: BorderRadius.circular(9999),
            child: LinearProgressIndicator(value: c.fraction, minHeight: 8, color: tone, backgroundColor: tone.withOpacity(0.12))),
        const SizedBox(height: 4),
        Text('${c.progress}/${c.target} ${kind.unit}${c.deadline != null && !c.done ? '  ·  ${tr('ends', 'अंतिम')} ${shortDate(c.deadline)}' : ''}',
            style: Fonts.body(12, w: FontWeight.w600, color: AppColors.textSecondary)),
      ]),
    );
  }
}

/// One homework with its progress; [onGo] starts it, [onDelete] removes it.
class HomeworkTile extends StatelessWidget {
  final Homework h;
  final VoidCallback? onGo, onDelete;
  const HomeworkTile(this.h, {super.key, this.onGo, this.onDelete});
  @override
  Widget build(BuildContext context) {
    final s = context.read<AppStore>();
    final by = s.parentById(h.assignedBy);
    final frac = h.fraction;
    final tone = h.done ? AppColors.success : h.overdue ? AppColors.error : AppColors.primary;
    final cat = h.category.isEmpty ? null : hubCategory(h.category);
    final cheer = h.feedback.isEmpty ? null : h.feedback.last;
    return Container(
      margin: const EdgeInsets.only(bottom: Sp.sm),
      padding: const EdgeInsets.all(Sp.sm + 2),
      decoration: BoxDecoration(color: tone.withOpacity(0.06), borderRadius: BorderRadius.circular(Rad.lg),
          border: Border.all(color: tone.withOpacity(0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          if (h.done) Icon(Icons.check_circle_rounded, size: 20, color: tone)
          else if (cat != null) Text(cat.emoji, style: const TextStyle(fontSize: 18))
          else Icon(switch (h.kind) {
            HomeworkKind.level => Icons.flag_rounded,
            HomeworkKind.letter => Icons.edit_rounded,
            HomeworkKind.practice => Icons.fitness_center_rounded,
          }, size: 20, color: tone),
          const SizedBox(width: Sp.sm),
          Expanded(child: Text(h.title, style: Fonts.body(15, w: FontWeight.w800)
              .copyWith(decoration: h.done ? TextDecoration.lineThrough : null))),
          if (onGo != null && !h.done) SoftPill(icon: Icons.play_arrow_rounded, label: tr('Start', 'शुरू'), onTap: onGo),
          if (onDelete != null) Pressable(onTap: onDelete,
              child: Padding(padding: const EdgeInsets.only(left: Sp.xs), child: Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.textMuted))),
        ]),
        if (h.note.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4),
            child: Text('“${h.note}”', style: Fonts.body(13, color: AppColors.textSecondary))),
        const SizedBox(height: 6),
        ClipRRect(borderRadius: BorderRadius.circular(9999),
            child: LinearProgressIndicator(value: frac, minHeight: 6, color: tone, backgroundColor: tone.withOpacity(0.12))),
        const SizedBox(height: 4),
        Text([
          '${h.progress.clamp(0, h.goal)}/${h.goal}',
          if (h.done) tr('Done ${shortDate(h.completedAt)}', '${shortDate(h.completedAt)} को पूरा')
          else if (h.dueDate != null) (h.overdue ? tr('Overdue · was due ', 'देर हो गई · ') : tr('Due ', 'अंतिम तिथि ')) + shortDate(h.dueDate),
          if (by != null) tr('from ${by.name}', '${by.name} से'),
        ].join('  ·  '), style: Fonts.body(12, w: FontWeight.w600, color: AppColors.textSecondary)),
        if (cheer != null) Container(
          margin: const EdgeInsets.only(top: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: AppColors.success.withOpacity(0.12), borderRadius: BorderRadius.circular(Rad.md)),
          child: Text('💬 ${s.parentById(cheer.by)?.name ?? ''}: ${cheer.text}${cheer.stars > 0 ? '  +${cheer.stars}⭐' : ''}',
              style: Fonts.body(13, w: FontWeight.w700, color: AppColors.successDark)),
        ),
      ]),
    );
  }
}

/// Opens the activity a homework asks for.
void openHomework(BuildContext context, Homework h) {
  context.read<AppStore>().beginHomework(h.id);
  switch (h.kind) {
    case HomeworkKind.level:
      final a = activityById(h.target);
      if (a == null || h.level < 1 || h.level > a.levels.length) return;
      final lvl = a.levels[h.level - 1];
      openScreen(context, a.screen, {
        'levelId': lvl.id, 'levelName': lvl.name, 'levelNumber': lvl.level, 'activityId': a.id, ...lvl.params,
      });
    case HomeworkKind.letter:
      openScreen(context, 'WritingCanvas', {'letterId': h.target});
    case HomeworkKind.practice:
      openScreen(context, 'RandomDrill');
  }
}
