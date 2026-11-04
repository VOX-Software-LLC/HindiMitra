import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/models.dart';
import '../../data/parent_hub.dart';
import '../../l10n.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../../widgets/common.dart';
import 'achievements_screen.dart';
import 'assign_activity_screen.dart';
import 'hub_widgets.dart';

/// One line on how the week went.
String summaryHeadline(ChildInsights i) {
  final w = i.period(7), p = i.period(7, offset: 7);
  final name = i.student.name;
  if (w.activeDays == 0) return tr('$name did not practise this week. A short daily task can help.', '$name ने इस हफ़्ते अभ्यास नहीं किया। रोज़ का छोटा काम मदद करेगा।');
  final more = w.practices > p.practices;
  return tr('$name practised ${w.activeDays} of 7 days, ${formatDuration(w.seconds)} in all${more ? ', more than last week' : ''}.',
      '$name ने 7 में से ${w.activeDays} दिन अभ्यास किया, कुल ${formatDuration(w.seconds)}${more ? ', पिछले हफ़्ते से ज़्यादा' : ''}।');
}

/// Improvements and wins of the last 7 days.
List<String> summaryWins(ChildInsights i) {
  final w = i.period(7), p = i.period(7, offset: 7);
  final out = <String>[];
  if (w.accuracy != null && p.accuracy != null && w.accuracy! > p.accuracy!) {
    out.add(tr('Writing accuracy went up from ${p.accuracy}% to ${w.accuracy}%.', 'लेखन सटीकता ${p.accuracy}% से बढ़कर ${w.accuracy}% हुई।'));
  } else if (w.accuracy != null && w.accuracy! >= 80) {
    out.add(tr('Writing accuracy was a strong ${w.accuracy}%.', 'लेखन सटीकता ${w.accuracy}% रही, बहुत अच्छा।'));
  }
  if (w.lettersMastered > 0) out.add(tr('Mastered ${w.lettersMastered} new letter${w.lettersMastered == 1 ? '' : 's'}.', '${w.lettersMastered} नए अक्षर पक्के किए।'));
  if (w.levels > 0) out.add(tr('Passed ${w.levels} activity level${w.levels == 1 ? '' : 's'}.', '${w.levels} गतिविधि स्तर पूरे किए।'));
  if (w.homeworkDone > 0) out.add(tr('Finished ${w.homeworkDone} homework.', '${w.homeworkDone} होमवर्क पूरे किए।'));
  if (w.practices > p.practices && p.practices > 0) {
    out.add(tr('Did ${w.practices - p.practices} more activities than last week.', 'पिछले हफ़्ते से ${w.practices - p.practices} ज़्यादा गतिविधियाँ कीं।'));
  }
  if (i.streak >= 3) out.add(tr('On a ${i.streak}-day streak 🔥', '${i.streak} दिन लगातार 🔥'));
  final weekAgo = DateTime.now().subtract(const Duration(days: 7)).toUtc().toIso8601String();
  for (final e in achievementEvents(i).where((e) => e.at.compareTo(weekAgo) >= 0 && e.emoji == '🏆').take(2)) {
    out.add(tr('Won the challenge “${e.detail}”.', 'चुनौती “${e.detail}” जीती।'));
  }
  return out;
}

/// Automatic weekly report for a parent: headline, wins, weak areas and
/// next week's recommended activities (each one tap to assign).
class WeeklySummaryScreen extends StatelessWidget {
  const WeeklySummaryScreen({super.key});

  static String asText(ChildInsights i) {
    final wins = summaryWins(i);
    return [
      'HindiMitra · ${i.student.name} · ${tr('weekly summary', 'साप्ताहिक सारांश')}',
      summaryHeadline(i),
      '',
      if (wins.isNotEmpty) ...[tr('Wins:', 'उपलब्धियाँ:'), for (final w in wins) '• $w', ''],
      if (i.weakAreas.isNotEmpty) ...[tr('Needs attention:', 'ध्यान दें:'), for (final w in i.weakAreas) '• ${w.title}: ${w.reason}', ''],
      tr('Letters mastered: ${i.mastered}/${i.totalLetters}', 'पक्के अक्षर: ${i.mastered}/${i.totalLetters}'),
    ].join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final i = selectedInsights(context);
    if (i == null) return HubPage(title: tr('Weekly summary', 'साप्ताहिक सारांश'), body: const SizedBox.shrink());
    final wins = summaryWins(i);
    final weak = i.weakAreas;
    final recs = _recommendations(i);
    final w = i.period(7);
    final now = DateTime.now(), from = now.subtract(const Duration(days: 6));

    Widget bullet(String emoji, String t) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(emoji, style: const TextStyle(fontSize: 17)),
            const SizedBox(width: Sp.sm),
            Expanded(child: Text(t, style: Fonts.body(14.5, w: FontWeight.w600, height: 1.35))),
          ]),
        );

    return HubPage(
      title: tr('Weekly summary', 'साप्ताहिक सारांश'), subtitle: '${i.student.name} · ${from.day}/${from.month}–${now.day}/${now.month}',
      action: SoftPill(icon: Icons.ios_share_rounded, onTap: () => SharePlus.instance.share(ShareParams(text: asText(i), subject: 'HindiMitra · ${i.student.name}'))),
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.all(Sp.lg),
          decoration: BoxDecoration(gradient: toneGradient(AppColors.primary), borderRadius: BorderRadius.circular(Rad.xl2),
              boxShadow: softShadow(AppColors.primary)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(w.activeDays >= 5 ? '🌟' : w.activeDays >= 3 ? '👍' : '🌱', style: const TextStyle(fontSize: 38)),
            const SizedBox(height: Sp.sm),
            Text(summaryHeadline(i), style: Fonts.display(19, color: AppColors.textOnPrimary, height: 1.3)),
            const SizedBox(height: Sp.md),
            Wrap(spacing: Sp.sm, runSpacing: Sp.sm, children: [
              for (final t in [
                '⏱ ${formatDuration(w.seconds)}', '✅ ${w.practices} ${tr('activities', 'गतिविधियाँ')}',
                if (w.accuracy != null) '🎯 ${w.accuracy}%', '🔤 ${i.mastered}/${i.totalLetters}',
              ]) Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.24), borderRadius: BorderRadius.circular(9999)),
                child: Text(t, style: Fonts.body(13, w: FontWeight.w800, color: AppColors.textOnPrimary)),
              ),
            ]),
          ]),
        ),
        HubSection(tr('Improvements & achievements', 'सुधार और उपलब्धियाँ')),
        ToyCard(child: wins.isEmpty
            ? bullet('🌱', tr('No new wins this week yet. Every practice counts!', 'इस हफ़्ते अभी कोई नई जीत नहीं। हर अभ्यास मायने रखता है!'))
            : Column(children: [for (final x in wins) bullet('✅', x)])),
        HubSection(tr('Needs attention', 'ध्यान दें')),
        ToyCard(child: weak.isEmpty
            ? bullet('🌟', tr('Nothing needs extra attention right now.', 'अभी किसी चीज़ पर अलग से ध्यान की ज़रूरत नहीं।'))
            : Column(children: [for (final x in weak) bullet('⚠️', '${x.title}: ${x.reason}')])),
        HubSection(tr('Recommended for next week', 'अगले हफ़्ते के लिए सुझाव')),
        for (final r in recs) ToyCard(
          margin: const EdgeInsets.only(bottom: Sp.sm),
          child: Row(children: [
            Container(width: 44, height: 44, alignment: Alignment.center,
                decoration: BoxDecoration(color: hubCategory(r.category).color.withOpacity(0.14), borderRadius: BorderRadius.circular(14)),
                child: Text(hubCategory(r.category).emoji, style: const TextStyle(fontSize: 21))),
            const SizedBox(width: Sp.sm + 2),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.title, style: Fonts.body(15, w: FontWeight.w800)),
              Text(r.reason, style: Fonts.body(12.5, w: FontWeight.w600, color: AppColors.textSecondary)),
            ])),
            SoftPill(icon: Icons.add_task_rounded, label: tr('Assign', 'दें'), onTap: () => pushHub(context, AssignActivityScreen(
                childId: i.student.id, category: r.category, letterId: r.letterId, activityId: r.activityId))),
          ]),
        ),
      ]),
    );
  }

  /// Next week's activities: fixes for weak areas, then the next new thing.
  static List<WeakArea> _recommendations(ChildInsights i) {
    final out = [
      for (final w in i.weakAreas.take(3))
        WeakArea(w.letterId != null ? tr('Practise ${AppData.letterById(w.letterId!)?.character}', '${AppData.letterById(w.letterId!)?.character} का अभ्यास') : w.title,
            tr('To improve: ${w.reason.toLowerCase()}', 'सुधार के लिए: ${w.reason}'), w.category, letterId: w.letterId, activityId: w.activityId),
    ];
    // The least-explored category gets a fresh activity.
    final cats = [...hubCategories]..sort((a, b) => (i.categoryProgress(a.id) ?? 0).compareTo(i.categoryProgress(b.id) ?? 0));
    for (final c in cats) {
      if (out.length >= 4) break;
      if (out.any((o) => o.category == c.id)) continue;
      final a = activitiesIn(c.id).firstOrNull;
      if (a == null) continue;
      out.add(WeakArea(a.title, tr('Explore ${c.label.toLowerCase()}: ${i.categoryProgress(c.id) ?? 0}% done so far', '${c.hindi} आज़माएँ: अब तक ${i.categoryProgress(c.id) ?? 0}%'),
          c.id, activityId: a.id));
    }
    return out;
  }
}
