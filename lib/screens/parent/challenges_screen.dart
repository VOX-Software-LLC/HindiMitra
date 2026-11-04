import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/accounts.dart';
import '../../data/parent_hub.dart';
import '../../l10n.dart';
import '../../store/app_store.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../../widgets/common.dart';
import '../../widgets/toy_button.dart';
import '../accounts/account_widgets.dart';
import 'assign_activity_screen.dart';
import 'hub_widgets.dart';

/// Every child's challenges: active ones with their progress, then won and
/// expired ones.
class ChallengesScreen extends StatelessWidget {
  const ChallengesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    final scope = ParentHubScope.of(context);
    final kids = hubChildren(s, scope.parentId);
    final all = [for (final k in kids) ...s.challengesFor(k.id)];
    final active = all.where((c) => !c.done && !c.expired).toList();
    final finished = all.where((c) => c.done || c.expired).toList()
      ..sort((a, b) => (b.completedAt ?? b.deadline ?? '').compareTo(a.completedAt ?? a.deadline ?? ''));
    return HubPage(
      title: tr('Challenges & goals', 'चुनौतियाँ और लक्ष्य'),
      action: SoftPill(icon: Icons.add_rounded, label: tr('New', 'नई'), onTap: () => pushHub(context, const CreateChallengeScreen())),
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.all(Sp.lg),
          decoration: BoxDecoration(gradient: toneGradient(AppColors.secondary), borderRadius: BorderRadius.circular(Rad.xl2),
              boxShadow: softShadow(AppColors.secondary)),
          child: Row(children: [
            const Text('🏆', style: TextStyle(fontSize: 46)),
            const SizedBox(width: Sp.md),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('${active.length} active · ${all.where((c) => c.done).length} won', '${active.length} चालू · ${all.where((c) => c.done).length} जीती'),
                  style: Fonts.display(21, color: Colors.white, height: 1.15)),
              Text(tr('Set a target and a reward. Progress counts by itself as your child learns.',
                  'लक्ष्य और इनाम तय करें। बच्चे के सीखते ही प्रगति अपने-आप गिनी जाती है।'),
                  style: Fonts.body(13.5, w: FontWeight.w600, color: Colors.white.withOpacity(0.92))),
            ])),
          ]),
        ),
        HubSection(tr('Active', 'चालू')),
        if (kids.isEmpty)
          EmptyState(emoji: '🧒', title: tr('No children yet', 'अभी कोई बच्चा नहीं'), message: tr('Add a child first.', 'पहले बच्चा जोड़ें।'))
        else if (active.isEmpty)
          EmptyState(emoji: '🎯', title: tr('No active challenges', 'कोई चालू चुनौती नहीं'),
              message: tr('A small goal with a reward is a great motivator.', 'इनाम वाला छोटा लक्ष्य बहुत प्रेरित करता है।'),
              actionLabel: tr('Create challenge', 'चुनौती बनाएँ'), onAction: () => pushHub(context, const CreateChallengeScreen()))
        else
          for (final c in active) ChallengeCard(c, showChild: kids.length > 1),
        if (finished.isNotEmpty) ...[
          HubSection(tr('Completed', 'पूरी हुई')),
          for (final c in finished) ChallengeCard(c, showChild: kids.length > 1),
        ],
      ]),
    );
  }
}

String rewardLabel(Challenge c) => switch (c.reward) {
      'badge' => tr('${c.badgeEmoji} Badge', '${c.badgeEmoji} बैज'),
      'certificate' => tr('📜 Certificate', '📜 प्रमाणपत्र'),
      _ => tr('⭐ ${c.rewardStars} stars', '⭐ ${c.rewardStars} सितारे'),
    };

class ChallengeCard extends StatelessWidget {
  final Challenge c;
  final bool showChild;
  const ChallengeCard(this.c, {super.key, this.showChild = true});
  @override
  Widget build(BuildContext context) {
    final s = context.read<AppStore>();
    final kind = challengeKind(c.category);
    final st = s.studentById(c.studentId);
    final tone = c.done ? AppColors.success : c.expired ? AppColors.textMuted : AppColors.secondary;
    return ToyCard(
      margin: const EdgeInsets.only(bottom: Sp.sm),
      borderColor: c.done ? AppColors.success.withOpacity(0.45) : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 46, height: 46, alignment: Alignment.center,
              decoration: BoxDecoration(color: tone.withOpacity(0.13), borderRadius: BorderRadius.circular(15)),
              child: Text(c.done ? '🏆' : kind.emoji, style: const TextStyle(fontSize: 23))),
          const SizedBox(width: Sp.sm + 2),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c.title, style: Fonts.body(15.5, w: FontWeight.w800)),
            if (c.description.isNotEmpty) Text(c.description, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: Fonts.body(12.5, w: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              if (showChild && st != null) Row(mainAxisSize: MainAxisSize.min, children: [
                learnerAvatar(st.name, st.avatar, size: 20), const SizedBox(width: 4),
                Text(st.name, style: Fonts.body(12, w: FontWeight.w800, color: AppColors.textSecondary)),
              ]),
              SoftPill(label: rewardLabel(c), color: const Color(0xFFB8860B)),
            ]),
          ])),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: AppColors.textSecondary),
            color: AppColors.surface,
            onSelected: (_) async {
              final ok = await confirmDialog(context, title: tr('Delete challenge?', 'चुनौती मिटाएँ?'), confirmLabel: tr('Delete', 'मिटाएँ'),
                  cancelLabel: tr('Cancel', 'रद्द करें'), destructive: true);
              if (ok) s.removeChallenge(c.id);
            },
            itemBuilder: (_) => [PopupMenuItem(value: 'delete', child: Text(tr('Delete', 'मिटाएँ'),
                style: Fonts.body(14, w: FontWeight.w700, color: AppColors.error)))],
          ),
        ]),
        const SizedBox(height: Sp.sm),
        ClipRRect(borderRadius: BorderRadius.circular(9999), child: LinearProgressIndicator(
            value: c.fraction, minHeight: 10, color: tone, backgroundColor: AppColors.muted)),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: Text('${c.progress}/${c.target} ${kind.unit}', style: Fonts.body(12.5, w: FontWeight.w800))),
          Text(c.done ? tr('Won ${shortDate(c.completedAt)}', '${shortDate(c.completedAt)} को जीती')
              : c.expired ? tr('Time ran out', 'समय खत्म') : c.deadline == null ? tr('No time limit', 'कोई समय सीमा नहीं')
              : tr('Ends ${shortDate(c.deadline)}', '${shortDate(c.deadline)} तक'),
              style: Fonts.body(12, w: FontWeight.w700, color: c.expired ? AppColors.error : AppColors.textSecondary)),
        ]),
      ]),
    );
  }
}

/// Create a challenge: title and description, child, kind, target, time
/// limit, reward and a motivational message. Templates fill it in fast.
class CreateChallengeScreen extends StatefulWidget {
  const CreateChallengeScreen({super.key});
  @override
  State<CreateChallengeScreen> createState() => _CreateChallengeScreenState();
}

class _CreateChallengeScreenState extends State<CreateChallengeScreen> {
  final title = TextEditingController(), description = TextEditingController(), message = TextEditingController();
  String? childId;
  String kind = 'daily';
  int target = 7, rewardStars = 20;
  int? days = 7;
  String reward = 'stars', badgeEmoji = '🏅';
  String? error;
  Challenge? created;

  static const _templates = [
    ('📅', '7-day streak', '7 दिन लगातार', 'daily', 7, 7),
    ('✍️', 'Writing week', 'लेखन सप्ताह', 'writing', 25, 7),
    ('📖', 'Bookworm', 'किताबी कीड़ा', 'reading', 5, 7),
    ('🎤', 'Speak up!', 'बोलो!', 'speaking', 5, 14),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final scope = ParentHubScope.of(context);
      final kids = hubChildren(context.read<AppStore>(), scope.parentId);
      setState(() => childId = kids.any((k) => k.id == scope.selected.value) ? scope.selected.value : kids.firstOrNull?.id);
    });
  }

  @override
  void dispose() { title.dispose(); description.dispose(); message.dispose(); super.dispose(); }

  void _create() {
    if (title.text.trim().isEmpty) { setState(() => error = tr('Give the challenge a title', 'चुनौती का नाम लिखें')); return; }
    if (childId == null) { setState(() => error = tr('Pick a child', 'बच्चा चुनें')); return; }
    final c = Challenge(
      id: newRecordId('ch'), studentId: childId!, parentId: ParentHubScope.of(context).parentId, title: title.text.trim(),
      description: description.text.trim(), category: kind, metric: challengeKind(kind).metric, target: target,
      deadline: days == null ? null : DateTime.now().add(Duration(days: days!)).toIso8601String().split('T').first,
      reward: reward, rewardStars: reward == 'stars' ? rewardStars : 0, badgeEmoji: badgeEmoji, message: message.text.trim(),
    );
    context.read<AppStore>().addChallenge(c);
    setState(() => created = c);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    final scope = ParentHubScope.of(context);
    final kids = hubChildren(s, scope.parentId);
    if (created != null) {
      final name = s.studentById(created!.studentId)?.name ?? '';
      return HubPage(title: tr('Challenge set!', 'चुनौती तैयार!'), scroll: false, body: HubSuccess(
        emoji: '🏆', title: tr('Game on, $name!', 'शुरू करो, $name!'),
        message: tr('“${created!.title}” is on $name’s Home screen. Reward: ${rewardLabel(created!)}.',
            '“${created!.title}” $name की होम स्क्रीन पर है। इनाम: ${rewardLabel(created!)}।'),
        actions: [ResultButton(label: tr('Done', 'हो गया'), icon: Icons.check_rounded, onTap: () => Navigator.of(context).maybePop())],
      ));
    }
    final k = challengeKind(kind);
    return HubPage(
      title: tr('Create challenge', 'चुनौती बनाएँ'),
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        fieldLabel(tr('Quick start', 'जल्दी शुरू करें')),
        SizedBox(height: 42, child: ListView(scrollDirection: Axis.horizontal, children: [
          for (final t in _templates) Padding(padding: const EdgeInsets.only(right: 6), child: HubChip('${t.$1} ${tr(t.$2, t.$3)}',
              selected: title.text == tr(t.$2, t.$3), onTap: () => setState(() {
                title.text = tr(t.$2, t.$3);
                kind = t.$4; target = t.$5; days = t.$6;
              }))),
        ])),
        const SizedBox(height: Sp.md),
        AccountField(controller: title, label: tr('Challenge title', 'चुनौती का नाम'), hint: tr('e.g. Super writer week', 'जैसे सुपर लेखक सप्ताह'), maxLength: 40),
        AccountField(controller: description, label: tr('Description (optional)', 'विवरण (वैकल्पिक)'),
            hint: tr('What should they do?', 'उन्हें क्या करना है?'), maxLength: 120, maxLines: 2),
        if (error != null) Text(error!, style: Fonts.body(13, w: FontWeight.w700, color: AppColors.error)),
        fieldLabel(tr('For', 'किसके लिए')),
        if (kids.isEmpty) Text(tr('Add a child first.', 'पहले बच्चा जोड़ें।'), style: Fonts.body(14, color: AppColors.textMuted))
        else ChildSelector(kids: kids, selected: childId ?? '', onSelect: (id) => setState(() => childId = id)),
        fieldLabel(tr('Category', 'प्रकार')),
        HubGrid(cols: 4, narrowCols: 2, children: [
          for (final c in challengeKinds) ChoiceCard(emoji: c.emoji, title: c.label, color: AppColors.secondary, selected: kind == c.id,
              onTap: () => setState(() { kind = c.id; target = c.targets[c.targets.length ~/ 2]; })),
        ]),
        fieldLabel(tr('Target: ${k.unit}', 'लक्ष्य: ${k.unit}')),
        AttemptStepper(value: target, max: 100, onChanged: (v) => setState(() => target = v)),
        fieldLabel(tr('Time limit', 'समय सीमा')),
        Wrap(spacing: Sp.xs, runSpacing: Sp.xs, children: [
          for (final d in <(String, int?)>[(tr('3 days', '3 दिन'), 3), (tr('1 week', '1 हफ़्ता'), 7), (tr('2 weeks', '2 हफ़्ते'), 14),
              (tr('1 month', '1 महीना'), 30), (tr('No limit', 'कोई सीमा नहीं'), null)])
            HubChip(d.$1, selected: days == d.$2, onTap: () => setState(() => days = d.$2)),
        ]),
        if (kind == 'daily' && days != null && target > days!) Padding(padding: const EdgeInsets.only(top: 6), child: Text(
            tr('$target days of practice will not fit in $days days.', '$days दिनों में $target दिन का अभ्यास नहीं हो पाएगा।'),
            style: Fonts.body(12.5, w: FontWeight.w700, color: AppColors.error))),
        fieldLabel(tr('Reward', 'इनाम')),
        HubGrid(cols: 3, narrowCols: 1, children: [
          ChoiceCard(emoji: '⭐', title: tr('Stars', 'सितारे'), color: const Color(0xFFB8860B), selected: reward == 'stars', onTap: () => setState(() => reward = 'stars')),
          ChoiceCard(emoji: badgeEmoji, title: tr('Badge', 'बैज'), color: AppColors.secondary, selected: reward == 'badge', onTap: () => setState(() => reward = 'badge')),
          ChoiceCard(emoji: '📜', title: tr('Certificate', 'प्रमाणपत्र'), color: AppColors.success, selected: reward == 'certificate',
              onTap: () => setState(() => reward = 'certificate')),
        ]),
        const SizedBox(height: Sp.sm),
        if (reward == 'stars') Wrap(spacing: Sp.xs, runSpacing: Sp.xs, children: [
          for (final n in [5, 10, 20, 50]) HubChip('+$n ⭐', selected: rewardStars == n, onTap: () => setState(() => rewardStars = n)),
        ]),
        if (reward == 'badge') Wrap(spacing: Sp.xs, runSpacing: Sp.xs, children: [
          for (final e in ['🏅', '🥇', '🦁', '🚀', '🌟', '👑', '🐘', '🦚']) HubChip(e, selected: badgeEmoji == e, onTap: () => setState(() => badgeEmoji = e)),
        ]),
        if (reward == 'certificate') Text(tr('A certificate appears in their achievements when they win.', 'जीतने पर उपलब्धियों में प्रमाणपत्र दिखेगा।'),
            style: Fonts.body(13, w: FontWeight.w600, color: AppColors.textSecondary)),
        fieldLabel(tr('Motivational message', 'प्रेरक संदेश')),
        AccountField(controller: message, label: '', hint: tr('You’ve got this! 💪', 'तुम कर सकते हो! 💪'), maxLength: 100),
        const SizedBox(height: Sp.sm),
        ToyButton(label: tr('Create challenge', 'चुनौती बनाएँ'), fullWidth: true, onPressed: _create,
            leading: Icon(Icons.emoji_events_rounded, size: 20, color: AppColors.textOnPrimary)),
      ]),
    );
  }
}
