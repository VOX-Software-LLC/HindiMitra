import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/badges.dart';
import '../../data/models.dart';
import '../../data/parent_hub.dart';
import '../../l10n.dart';
import '../../store/app_store.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../../widgets/common.dart';
import '../../widgets/icons.dart';
import '../accounts/account_widgets.dart';
import 'challenges_screen.dart';
import 'hub_widgets.dart';

/// Something a child achieved, for the history lists.
class AchievementEvent {
  final String at, emoji, title, detail;
  const AchievementEvent(this.at, this.emoji, this.title, this.detail);
}

/// A child's achievements, newest first: finished homework and challenges,
/// and mastered letters.
List<AchievementEvent> achievementEvents(ChildInsights i) => i.once('achievements', () => _achievementEvents(i));

List<AchievementEvent> _achievementEvents(ChildInsights i) {
  final out = <AchievementEvent>[
    for (final h in i.homework.where((h) => h.done))
      AchievementEvent(h.completedAt!, hubCategory(homeworkCategory(h)).emoji, tr('Finished homework', 'होमवर्क पूरा'), h.title),
    for (final c in i.challenges.where((c) => c.done))
      AchievementEvent(c.completedAt!, c.reward == 'badge' ? c.badgeEmoji : c.reward == 'certificate' ? '📜' : '🏆',
          tr('Won a challenge', 'चुनौती जीती'), '${c.title}${c.reward == 'stars' ? ' · +${c.rewardStars}★' : ''}'),
    for (final p in i.v.letterProgress.values.where((p) => p.mastered && p.lastPracticedAt != null))
      AchievementEvent(p.lastPracticedAt!, '🔤', tr('Mastered a letter', 'अक्षर पक्का किया'),
          AppData.letterById(p.letterId)?.character ?? p.letterId),
  ];
  out.sort((a, b) => b.at.compareTo(a.at));
  return out;
}

class AchievementRow extends StatelessWidget {
  final AchievementEvent e;
  const AchievementRow(this.e, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Container(width: 40, height: 40, alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.starGold.withOpacity(0.18), shape: BoxShape.circle),
              child: Text(e.emoji, style: const TextStyle(fontSize: 19))),
          const SizedBox(width: Sp.sm + 2),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e.title, style: Fonts.body(12, w: FontWeight.w700, color: AppColors.textSecondary)),
            Text(e.detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: Fonts.body(14.5, w: FontWeight.w800)),
          ])),
          Text(shortDate(e.at), style: Fonts.body(12, w: FontWeight.w600, color: AppColors.textMuted)),
        ]),
      );
}

/// A milestone track (stars, letters, streak): its steps and the figure.
class _Track {
  final String label, emoji;
  final int value;
  final List<int> steps;
  const _Track(this.label, this.emoji, this.value, this.steps);
  int? get next => steps.where((s) => s > value).firstOrNull;
  int get reached => steps.where((s) => s <= value).length;
}

/// Badges (earned, in reach, locked), milestones, upcoming rewards and the
/// history of a child's achievements.
class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});
  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  int tab = 0;
  static const _timeBased = {'night-owl', 'early-bird'};

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    final scope = ParentHubScope.of(context);
    final i = selectedInsights(context);
    if (i == null) return HubPage(title: tr('Achievements', 'उपलब्धियाँ'), body: const SizedBox.shrink());
    final kids = hubChildren(s, scope.parentId);
    final v = i.v;
    bool earned(BadgeDef b) => v.seenBadges.contains(b.info.id) || (b.progress(v).complete && !_timeBased.contains(b.info.id));
    final got = badgeDefs.where(earned).toList();
    final open = badgeDefs.where((b) => !earned(b) && b.progress(v).tracked).toList()
      ..sort((a, b) => b.progress(v).fraction.compareTo(a.progress(v).fraction));
    final locked = badgeDefs.where((b) => !earned(b) && !b.progress(v).tracked).toList();
    final tracks = [
      _Track(tr('Stars', 'सितारे'), '⭐', i.stars, const [25, 50, 100, 250, 500, 1000]),
      _Track(tr('Letters mastered', 'पक्के अक्षर'), '🔤', i.mastered, [5, 13, 25, AppData.allLetters.length]),
      _Track(tr('Practice streak', 'लगातार अभ्यास'), '🔥', v.longestStreak, const [3, 7, 14, 30]),
      _Track(tr('Homework done', 'पूरे होमवर्क'), '📚', i.homework.where((h) => h.done).length, const [1, 5, 10, 25, 50]),
    ];
    final history = achievementEvents(i);
    final badgeList = [got, open, locked][tab];

    return HubPage(
      title: tr('Achievements', 'उपलब्धियाँ'), subtitle: i.student.name,
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (kids.length > 1) ...[
          ChildSelector(kids: kids, selected: i.student.id, onSelect: (id) => scope.selected.value = id),
          const SizedBox(height: Sp.md),
        ],
        // Stars hero.
        Container(
          padding: const EdgeInsets.all(Sp.lg),
          decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [AppColors.starGold, shade(AppColors.starGold, 0.12)]),
              borderRadius: BorderRadius.circular(Rad.xl2), boxShadow: softShadow(AppColors.starGold)),
          child: Row(children: [
            const Text('⭐', style: TextStyle(fontSize: 52)),
            const SizedBox(width: Sp.md),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${i.stars}', style: Fonts.display(38, color: const Color(0xFF4E402F), height: 1)),
              Text(tr('stars earned · ${got.length} badges', 'सितारे · ${got.length} बैज'),
                  style: Fonts.body(14, w: FontWeight.w800, color: const Color(0xFF4E402F))),
            ])),
            SoftPill(icon: Icons.emoji_events_rounded, label: tr('Challenges', 'चुनौतियाँ'), color: const Color(0xFF4E402F),
                onTap: () => pushHub(context, const ChallengesScreen())),
          ]),
        ),
        HubSection(tr('Next rewards', 'अगले इनाम')),
        ToyCard(child: Column(children: [
          for (final t in tracks) ProgressRow(
            leading: Text(t.emoji, style: const TextStyle(fontSize: 18)),
            label: t.next == null ? tr('${t.label}: all milestones reached!', '${t.label}: सब पूरे!') : '${t.label} → ${t.next}',
            value: t.next == null ? '✓' : '${t.value}/${t.next}',
            fraction: t.next == null ? 1 : t.value / t.next!, color: AppColors.primary,
          ),
        ])),
        HubSection(tr('Milestones', 'पड़ाव')),
        HubGrid(children: [
          for (final t in tracks) ToyCard(shadow: 2, child: Column(children: [
            Text(t.emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 4),
            Text(t.label, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: Fonts.body(12.5, w: FontWeight.w800)),
            const SizedBox(height: 6),
            Wrap(alignment: WrapAlignment.center, spacing: 4, runSpacing: 4, children: [
              for (final st in t.steps) Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: st <= t.value ? AppColors.success.withOpacity(0.15) : AppColors.muted,
                  borderRadius: BorderRadius.circular(9999)),
                child: Text(st <= t.value ? '✓ $st' : '$st', style: Fonts.body(11, w: FontWeight.w800,
                    color: st <= t.value ? AppColors.successDark : AppColors.textMuted)),
              ),
            ]),
          ])),
        ]),
        HubSection(tr('Badges', 'बैज')),
        HubSegmented(options: [tr('Earned · ${got.length}', 'मिले · ${got.length}'), tr('Available · ${open.length}', 'पास · ${open.length}'),
            tr('Locked · ${locked.length}', 'बंद · ${locked.length}')], selected: tab, onChanged: (t) => setState(() => tab = t)),
        const SizedBox(height: Sp.md),
        if (badgeList.isEmpty)
          EmptyState(emoji: tab == 0 ? '🎖️' : '✨', title: tab == 0 ? tr('No badges yet', 'अभी कोई बैज नहीं') : tr('Nothing here', 'यहाँ कुछ नहीं'),
              message: tab == 0 ? tr('The first badge comes with the first letter practice.', 'पहले अक्षर के अभ्यास पर पहला बैज मिलेगा।') : tr('All caught up.', 'सब पूरा।'))
        else
          HubGrid(cols: 3, narrowCols: 2, children: [
            for (final b in badgeList) Builder(builder: (_) {
              final p = b.progress(v);
              final isEarned = tab == 0;
              return ToyCard(shadow: 2, child: Column(children: [
                Opacity(opacity: tab == 2 ? 0.4 : 1, child: Container(width: 56, height: 56,
                    decoration: BoxDecoration(shape: BoxShape.circle,
                        color: isEarned ? b.info.color.withOpacity(0.18) : AppColors.muted,
                        border: Border.all(color: isEarned ? b.info.color : AppColors.border, width: 2)),
                    child: Icon(tab == 2 ? Icons.lock_rounded : ionIcon(b.info.icon), size: 28,
                        color: isEarned ? b.info.color : AppColors.textMuted))),
                const SizedBox(height: Sp.sm),
                Text(tr(b.info.name, b.info.hindiName), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: Fonts.body(13.5, w: FontWeight.w800)),
                Text(b.info.description, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: Fonts.body(11.5, w: FontWeight.w600, color: AppColors.textSecondary)),
                if (tab == 1) ...[
                  const SizedBox(height: 6),
                  ClipRRect(borderRadius: BorderRadius.circular(9999), child: LinearProgressIndicator(
                      value: p.fraction, minHeight: 6, color: b.info.color, backgroundColor: AppColors.muted)),
                  const SizedBox(height: 2),
                  Text(p.left, style: Fonts.body(11, w: FontWeight.w700, color: AppColors.textMuted)),
                ],
              ]));
            }),
          ]),
        HubSection(tr('History', 'इतिहास'), hindi: '(${history.length})'),
        if (history.isEmpty)
          EmptyState(emoji: '🌱', title: tr('Nothing yet', 'अभी कुछ नहीं'),
              message: tr('Finished homework, won challenges and mastered letters appear here.', 'पूरे होमवर्क, जीती चुनौतियाँ और पक्के अक्षर यहाँ दिखेंगे।'))
        else
          ToyCard(child: Column(children: [for (final e in history.take(30)) AchievementRow(e)])),
      ]),
    );
  }
}
