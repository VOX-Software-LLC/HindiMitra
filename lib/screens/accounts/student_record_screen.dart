import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/accounts.dart';
import '../../data/models.dart';
import '../../services/cloud_accounts.dart';
import '../../l10n.dart';
import '../../store/app_store.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../../widgets/common.dart';
import '../../widgets/progress_bar.dart';
import 'account_widgets.dart';
import 'homework_sheet.dart';
import 'important_info.dart';
import 'pairing_screens.dart';

/// One child's full record for a signed-in parent: important information,
/// progress, every activity's level, homework, and a shareable report.
class StudentRecordScreen extends StatelessWidget {
  final Map<String, dynamic> params;
  const StudentRecordScreen({super.key, this.params = const {}});

  String studentId(AppStore s) => (params['studentId'] as String?) ?? s.activeStudentId;
  String get parentId => (params['parentId'] as String?) ?? '';

  /// Plain-text progress report (for WhatsApp, email or a teacher).
  static String report(AppStore s, StudentAccount st) {
    final r = s.recordOf(st.id);
    final hw = s.homeworkFor(st.id);
    final total = AppData.allLetters.length;
    final lines = [
      'HindiMitra progress report',
      '${st.name} · Student ID ${st.id}',
      if (st.grade.isNotEmpty || st.school.isNotEmpty) [st.grade, st.school].where((x) => x.isNotEmpty).join(', '),
      'Parents: ${s.parentsOf(st.id).map((p) => '${p.name} (${p.id})').join(', ')}',
      '',
      'Stars: ${r.totalStars} · Points: ${r.totalPoints}',
      'Letters mastered: ${r.mastered}/$total (started ${r.lettersStarted})',
      'Streak: ${r.currentStreak} days (best ${r.longestStreak}) · Active ${r.activeThisWeek}/7 days this week',
      if (r.averageAccuracy != null) 'Writing accuracy: ${r.averageAccuracy}%',
      if (r.weakLetters.isNotEmpty) 'Needs practice: ${r.weakLetters.map((id) => AppData.letterById(id)?.character ?? id).join(' ')}',
      '',
      'Activities:',
      for (final a in assignableActivities)
        if ((r.activityProgress[a.id] ?? 0) > 0) '  ${a.title}: level ${r.activityProgress[a.id]}/${a.levels.length}',
      '',
      'Homework: ${hw.where((h) => h.done).length} done, ${hw.where((h) => !h.done).length} open',
      for (final h in hw) '  ${h.done ? '✓' : h.overdue ? '!' : '•'} ${h.title}${h.dueDate != null && !h.done ? ' (due ${shortDate(h.dueDate)})' : ''}',
      '',
      'Generated ${shortDate(DateTime.now().toIso8601String())}',
    ];
    return lines.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    final st = s.studentById(studentId(s));
    if (st == null) return const Scaffold(body: SizedBox.shrink());
    final r = s.recordOf(st.id);
    final hw = s.homeworkFor(st.id);
    final total = AppData.allLetters.length;
    final started = assignableActivities.where((a) => (r.activityProgress[a.id] ?? 0) > 0).toList();
    final isActive = st.id == s.activeStudentId;
    // In the cloud for the signed-in parent: changes there go to the cloud too.
    final inCloud = st.remote || (s.parentById(parentId)?.cloudUid.isNotEmpty == true && CloudAccounts.user != null);
    // The signed-in parent can pair devices and invite parents for this child.
    final me = CloudAccounts.user;
    final manageCloud = me != null && !me.isAnonymous && s.parentById(parentId)?.cloudUid == me.uid;

    Future<bool> cloudStep(Future<void> Function() f) async {
      if (!inCloud) return true;
      try {
        await f();
        return true;
      } on CloudError catch (e) {
        if (context.mounted) await showInfoDialog(context, tr('Cloud', 'क्लाउड'), e.message);
        return false;
      }
    }

    Future<void> unlink() async {
      final ok = await confirmDialog(context, title: tr('Unlink ${st.name}?', '${st.name} को हटाएँ?'),
          message: tr('Their progress stays. You will no longer see their record or set their homework.',
              'उनकी प्रगति बनी रहेगी। आप उनका रिकॉर्ड नहीं देख पाएँगे और होमवर्क नहीं दे पाएँगे।'),
          confirmLabel: tr('Unlink', 'हटाएँ'), destructive: true);
      if (!ok || !context.mounted) return;
      if (!await cloudStep(() => CloudAccounts.unlinkParent(st.id, parentId))) return;
      st.remote ? s.removeCloudCopy(st.id) : s.unlinkParent(st.id, parentId);
      if (context.mounted) Navigator.of(context).maybePop();
    }

    Future<void> remove() async {
      final ok = await confirmDialog(context, title: tr('Delete ${st.name} from this device?', '${st.name} को डिवाइस से मिटाएँ?'),
          message: inCloud
              ? tr('All of ${st.name}\'s progress, information and homework will be deleted from this device and the cloud backup. This cannot be undone.',
                  '${st.name} की सारी प्रगति, जानकारी और होमवर्क इस डिवाइस और क्लाउड बैकअप से मिट जाएँगे। यह वापस नहीं होगा।')
              : tr('All of ${st.name}\'s progress, information and homework on this device will be deleted. This cannot be undone.',
                  '${st.name} की सारी प्रगति, जानकारी और होमवर्क इस डिवाइस से मिट जाएँगे। यह वापस नहीं होगा।'),
          confirmLabel: tr('Delete', 'मिटाएँ'), destructive: true);
      if (!ok || !context.mounted) return;
      if (!await cloudStep(() => CloudAccounts.deleteStudent(st.id, parentId))) return;
      s.removeStudent(st.id);
      if (context.mounted) Navigator.of(context).maybePop();
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(bottom: false, child: Column(children: [
        HeaderBar(title: st.name, subtitle: st.id, onBack: () => Navigator.of(context).maybePop(),
            rightAction: SoftPill(icon: Icons.ios_share_rounded,
                onTap: () => SharePlus.instance.share(ShareParams(text: report(s, st), subject: 'HindiMitra · ${st.name}')))),
        Expanded(child: screenScroll(maxWidth: 760, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          ImportantInfoCard(studentId: st.id, unlocked: true),

          if (st.remote) ToyCard(
            margin: const EdgeInsets.only(bottom: Sp.md),
            color: AppColors.primary.withOpacity(0.06),
            child: Row(children: [
              Icon(Icons.devices_other_rounded, color: AppColors.primary), const SizedBox(width: Sp.sm),
              Expanded(child: Text(tr('${st.name} learns on another device. This record updates live from the cloud. '
                      'Setting homework from here comes in the next update.',
                      '${st.name} दूसरे डिवाइस पर सीखते हैं। यह रिकॉर्ड क्लाउड से अपने-आप अपडेट होता है। '
                      'यहाँ से होमवर्क देना अगले अपडेट में आएगा।'),
                  style: Fonts.body(13, color: AppColors.textSecondary))),
            ]),
          ),
          accountSection(tr('Homework', 'होमवर्क'),
              action: st.remote ? null : SoftPill(icon: Icons.add_rounded, label: tr('Set homework', 'होमवर्क दें'),
                  onTap: () => showAssignHomework(context, studentId: st.id, parentId: parentId))),
          if (hw.isEmpty)
            ToyCard(child: Text(tr('No homework yet.', 'अभी कोई होमवर्क नहीं।'), style: Fonts.body(14, color: AppColors.textSecondary)))
          else
            ToyCard(child: Column(children: [
              for (final h in hw) HomeworkTile(h, onDelete: () => s.removeHomework(h.id)),
            ])),

          if (manageCloud) ...[
            accountSection(tr('Devices and parents', 'डिवाइस और अभिभावक')),
            ToyCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (st.devices.isEmpty)
                Text(tr('No device paired yet. Pair ${st.name}\'s own tablet or phone so their progress syncs without your account.',
                        'अभी कोई डिवाइस नहीं जुड़ा। ${st.name} का टैबलेट या फ़ोन जोड़ें ताकि आपके खाते के बिना प्रगति सिंक हो।'),
                    style: Fonts.body(13, color: AppColors.textSecondary)),
              for (final e in st.devices.entries) InfoRow(
                icon: Icons.tablet_android_rounded,
                label: '${(e.value as Map)['name'] ?? 'Device'}',
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(shortDate((e.value as Map)['pairedAt'] as String?), style: Fonts.body(12, color: AppColors.textMuted)),
                  const SizedBox(width: Sp.sm),
                  SoftPill(icon: Icons.link_off_rounded, label: tr('Remove', 'हटाएँ'), color: AppColors.error, onTap: () async {
                    final ok = await confirmDialog(context, title: tr('Remove this device?', 'यह डिवाइस हटाएँ?'),
                        message: tr('It stops syncing ${st.name}\'s progress at once. What is on it stays there.',
                            'यह तुरंत ${st.name} की प्रगति सिंक करना बंद कर देगा। उस पर जो है, वहीं रहेगा।'),
                        confirmLabel: tr('Remove', 'हटाएँ'), destructive: true);
                    if (ok) await cloudStep(() => CloudAccounts.removeDevice(st.id, e.key));
                  }),
                ]),
              ),
              const SizedBox(height: Sp.sm),
              Wrap(spacing: Sp.sm, runSpacing: Sp.sm, children: [
                SoftPill(icon: Icons.add_link_rounded, label: tr('Pair a device', 'डिवाइस जोड़ें'),
                    onTap: () => showPairingCode(context, studentId: st.id, childName: st.name, kind: 'device')),
                SoftPill(icon: Icons.person_add_alt_1_rounded, label: tr('Invite another parent', 'दूसरे अभिभावक को बुलाएँ'),
                    onTap: () => showPairingCode(context, studentId: st.id, childName: st.name, kind: 'parent')),
              ]),
            ])),
          ],

          accountSection(tr('Progress', 'प्रगति')),
          ToyCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              for (final (v, l) in [('${r.totalStars}', tr('Stars', 'सितारे')), ('${r.totalPoints}', tr('Points', 'अंक')),
                  ('${r.currentStreak}', tr('Streak', 'लगातार')), ('${r.daysPracticed}', tr('Days', 'दिन'))])
                Expanded(child: Column(children: [
                  Text(v, style: Fonts.display(22)),
                  Text(l, style: Fonts.body(12, w: FontWeight.w600, color: AppColors.textMuted)),
                ])),
            ]),
            const SizedBox(height: Sp.md),
            InfoRow(icon: Icons.translate_rounded, label: tr('Letters mastered', 'सीखे अक्षर'), value: '${r.mastered}/$total'),
            HsProgressBar(progress: total == 0 ? 0 : r.mastered / total, height: 8, color: AppColors.success),
            InfoRow(icon: Icons.track_changes_rounded, label: tr('Writing accuracy', 'लिखने की सटीकता'),
                value: r.averageAccuracy == null ? '' : '${r.averageAccuracy}%'),
            InfoRow(icon: Icons.calendar_today_rounded, label: tr('Active this week', 'इस हफ़्ते सक्रिय'), value: '${r.activeThisWeek}/7'),
            InfoRow(icon: Icons.emoji_events_rounded, label: tr('Best streak', 'सबसे लंबा सिलसिला'), value: '${r.longestStreak}'),
            if (r.weakLetters.isNotEmpty) InfoRow(icon: Icons.healing_rounded, label: tr('Needs practice', 'अभ्यास चाहिए'),
                trailing: Text(r.weakLetters.map((id) => AppData.letterById(id)?.character ?? id).join('  '),
                    style: Fonts.hindi(20, color: AppColors.error, height: 1.2))),
          ])),

          accountSection(tr('Activities', 'गतिविधियाँ')),
          ToyCard(child: started.isEmpty
              ? Text(tr('No levels finished yet.', 'अभी कोई स्तर पूरा नहीं हुआ।'), style: Fonts.body(14, color: AppColors.textSecondary))
              : Column(children: [
                  for (final a in started) Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      SizedBox(width: 28, child: Icon(Icons.flag_rounded, size: 18, color: AppColors.primary)),
                      SizedBox(width: 150, child: Text(a.title, style: Fonts.body(14, w: FontWeight.w700), overflow: TextOverflow.ellipsis)),
                      Expanded(child: HsProgressBar(progress: (r.activityProgress[a.id] ?? 0) / a.levels.length, height: 8)),
                      const SizedBox(width: Sp.sm),
                      Text('${r.activityProgress[a.id]}/${a.levels.length}', style: Fonts.body(13, w: FontWeight.w800)),
                    ]),
                  ),
                ])),

          accountSection(tr('Account', 'खाता')),
          Wrap(spacing: Sp.sm, runSpacing: Sp.sm, children: [
            SizedBox(width: 220, child: ResultButton(label: tr('Share report', 'रिपोर्ट भेजें'), icon: Icons.ios_share_rounded,
                filled: false, onTap: () => SharePlus.instance.share(ShareParams(text: report(s, st), subject: 'HindiMitra · ${st.name}')))),
            if (!isActive && !st.remote) SizedBox(width: 220, child: ResultButton(label: tr('Switch to ${st.name}', '${st.name} पर जाएँ'),
                icon: Icons.swap_horiz_rounded, filled: false, onTap: () {
                  Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
                  s.switchStudent(st.id);
                })),
            SizedBox(width: 220, child: ResultButton(label: tr('Unlink from me', 'मुझसे हटाएँ'), icon: Icons.link_off_rounded,
                filled: false, color: AppColors.error, onTap: unlink)),
            if (!isActive && !st.remote) SizedBox(width: 220, child: ResultButton(label: tr('Delete learner', 'विद्यार्थी मिटाएँ'),
                icon: Icons.delete_forever_rounded, filled: false, color: AppColors.error, onTap: remove)),
          ]),
          const SizedBox(height: Sp.xxl),
        ]))),
      ])),
    );
  }
}
