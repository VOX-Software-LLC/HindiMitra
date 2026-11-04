import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/accounts.dart';
import '../../data/models.dart';
import '../../data/parent_hub.dart';
import '../../l10n.dart';
import '../../store/app_store.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../../widgets/common.dart';
import '../../widgets/toy_button.dart';
import '../accounts/account_widgets.dart';
import 'assignment_detail_screen.dart';
import 'hub_widgets.dart';

/// Assign an activity in four steps: child, category, set-up, review. It
/// can start part-filled (from a weak area or a child's card).
class AssignActivityScreen extends StatefulWidget {
  final String? childId, category, letterId, activityId;
  const AssignActivityScreen({super.key, this.childId, this.category, this.letterId, this.activityId});
  @override
  State<AssignActivityScreen> createState() => _AssignActivityScreenState();
}

/// What the writing category assigns.
enum _WriteMode { letter, exercise, free }

class _AssignActivityScreenState extends State<AssignActivityScreen> {
  int step = 0;
  String? childId, category;
  var mode = _WriteMode.letter;
  String? letterId;
  ActivityDef? activity;
  int level = 1, attempts = 3;
  String difficulty = 'normal';
  String? due = _inDays(3);
  final message = TextEditingController();
  Homework? assigned;

  static String _inDays(int d) => DateTime.now().add(Duration(days: d)).toIso8601String().split('T').first;

  @override
  void initState() {
    super.initState();
    childId = widget.childId;
    category = widget.category;
    letterId = widget.letterId;
    if (widget.activityId != null) {
      activity = hubActivity(widget.activityId!);
      category ??= activity == null ? null : categoryOfActivity(activity!.id);
      if (category == 'writing') mode = _WriteMode.exercise;
    }
    if (letterId != null) { category ??= 'writing'; mode = _WriteMode.letter; }
    if (childId != null) step = category != null ? 2 : 1;
  }

  @override
  void dispose() { message.dispose(); super.dispose(); }

  AppStore get s => context.read<AppStore>();

  void _pickCategory(String c) {
    setState(() {
      category = c;
      if (c != 'writing' || mode == _WriteMode.exercise) {
        final acts = activitiesIn(c);
        if (activity == null || !acts.contains(activity)) activity = acts.firstOrNull;
        if (c != 'writing') mode = _WriteMode.exercise;
      }
      _syncLevel();
    });
  }

  /// The next level the child has not passed yet.
  void _syncLevel() {
    final a = activity;
    if (a == null || childId == null) return;
    final done = s.viewOf(childId!).activityProgress[a.id] ?? 0;
    level = min(done + 1, a.levels.length);
  }

  HomeworkKind get kind => category == 'writing'
      ? switch (mode) { _WriteMode.letter => HomeworkKind.letter, _WriteMode.exercise => HomeworkKind.level, _WriteMode.free => HomeworkKind.practice }
      : HomeworkKind.level;

  bool get configured => switch (kind) {
        HomeworkKind.letter => letterId != null,
        HomeworkKind.level => activity != null,
        HomeworkKind.practice => true,
      };

  String get title {
    final ch = AppData.letterById(letterId ?? '')?.character ?? '';
    return switch (kind) {
      HomeworkKind.letter => tr('Write $ch well $attempts times', '$ch को $attempts बार अच्छे से लिखो'),
      HomeworkKind.level => '${activity?.title ?? ''} · ${tr('Level', 'स्तर')} $level${attempts > 1 ? ' ×$attempts' : ''}',
      HomeworkKind.practice => tr('$attempts writing practices', '$attempts बार लिखने का अभ्यास'),
    };
  }

  void _assign() {
    final h = Homework(
      id: newRecordId('hw'), studentId: childId!, assignedBy: ParentHubScope.of(context).parentId, kind: kind,
      title: title, note: message.text.trim(), dueDate: due, goal: attempts, category: category!, difficulty: difficulty,
      target: switch (kind) { HomeworkKind.level => activity!.id, HomeworkKind.letter => letterId!, HomeworkKind.practice => '' },
      level: kind == HomeworkKind.level ? level : 0,
    );
    s.assignHomework(h);
    setState(() => assigned = h);
  }

  void _restart() => setState(() {
        assigned = null;
        step = 1;
        category = null;
        activity = null;
        letterId = null;
        message.clear();
      });

  @override
  Widget build(BuildContext context) {
    context.watch<AppStore>();
    if (assigned != null) {
      final name = s.studentById(assigned!.studentId)?.name ?? '';
      return HubPage(
        title: tr('Assigned!', 'दे दिया!'), scroll: false,
        body: HubSuccess(
          emoji: '🎉', title: tr('Sent to $name', '$name को भेजा गया'),
          message: tr('“${assigned!.title}” is now on $name’s Home screen. You’ll see each attempt here as it happens.',
              '“${assigned!.title}” अब $name की होम स्क्रीन पर है। हर प्रयास यहाँ दिखेगा।'),
          actions: [
            ResultButton(label: tr('View assignment', 'काम देखें'), icon: Icons.visibility_rounded,
                onTap: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ParentHubScope(
                    parentId: ParentHubScope.of(context).parentId, selected: ParentHubScope.of(context).selected,
                    child: AssignmentDetailScreen(homeworkId: assigned!.id))))),
            ResultButton(label: tr('Assign another', 'और काम दें'), icon: Icons.add_rounded, filled: false, onTap: _restart),
            ResultButton(label: tr('Done', 'हो गया'), icon: Icons.check_rounded, filled: false,
                onTap: () => Navigator.of(context).maybePop()),
          ],
        ),
      );
    }

    final steps = [tr('Child', 'बच्चा'), tr('Category', 'प्रकार'), tr('Set up', 'तैयारी'), tr('Review', 'जाँचें')];
    final canNext = switch (step) { 0 => childId != null, 1 => category != null, 2 => configured, _ => true };
    return HubPage(
      title: tr('Assign activity', 'काम दें'), subtitle: tr('Step ${step + 1} of 4 · ${steps[step]}', 'चरण ${step + 1}/4 · ${steps[step]}'),
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _Stepper(labels: steps, step: step, onTap: (i) { if (i < step) setState(() => step = i); }),
        const SizedBox(height: Sp.md),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          transitionBuilder: (c, a) => FadeTransition(opacity: a,
              child: SlideTransition(position: Tween(begin: const Offset(0.04, 0), end: Offset.zero).animate(a), child: c)),
          child: KeyedSubtree(key: ValueKey(step), child: switch (step) {
            0 => _childStep(),
            1 => _categoryStep(),
            2 => _configStep(),
            _ => _reviewStep(),
          }),
        ),
      ]),
      bottom: Container(
        padding: const EdgeInsets.fromLTRB(Sp.md, Sp.sm, Sp.md, Sp.md),
        decoration: BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: AppColors.border))),
        child: SafeArea(top: false, child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 820), child: Row(children: [
          if (step > 0) Expanded(child: ResultButton(label: tr('Back', 'पीछे'), icon: Icons.arrow_back_rounded, filled: false,
              onTap: () => setState(() => step--))),
          if (step > 0) const SizedBox(width: Sp.sm),
          Expanded(flex: 2, child: step < 3
              ? ResultButton(label: tr('Next', 'आगे'), icon: Icons.arrow_forward_rounded,
                  onTap: canNext ? () => setState(() { step++; if (step == 2) _syncLevel(); }) : null)
              : ResultButton(label: tr('Assign now', 'अभी दें'), icon: Icons.send_rounded, color: AppColors.success, onTap: _assign)),
        ])))),
      ),
    );
  }

  Widget _childStep() {
    final kids = hubChildren(s, ParentHubScope.of(context).parentId);
    if (kids.isEmpty) {
      return EmptyState(emoji: '🧒', title: tr('No children yet', 'अभी कोई बच्चा नहीं'),
          message: tr('Add a child from the Children tab first.', 'पहले बच्चे टैब से बच्चा जोड़ें।'));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(tr('Who is this for?', 'यह किसके लिए है?'), style: Fonts.display(22)),
      const SizedBox(height: Sp.md),
      for (final k in kids) Padding(
        padding: const EdgeInsets.only(bottom: Sp.sm),
        child: Builder(builder: (_) {
          final i = ChildInsights.of(s, k.id);
          final open = i.homework.where((h) => !h.done).length;
          return Pressable(
            onTap: () => setState(() { childId = k.id; step = 1; }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(Sp.md),
              decoration: BoxDecoration(
                color: childId == k.id ? AppColors.primary.withOpacity(0.1) : AppColors.surface,
                borderRadius: BorderRadius.circular(Rad.xl),
                border: Border.all(color: childId == k.id ? AppColors.primary : AppColors.border, width: childId == k.id ? 2 : 1),
                boxShadow: toyShadow(AppColors.toyShadowColor, 2)),
              child: Row(children: [
                learnerAvatar(k.name, k.avatar, size: 52),
                const SizedBox(width: Sp.md),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(k.name, style: Fonts.display(18)),
                  Text(tr('${i.mastered}/${i.totalLetters} letters · $open open', '${i.mastered}/${i.totalLetters} अक्षर · $open बाकी'),
                      style: Fonts.body(13, w: FontWeight.w600, color: AppColors.textSecondary)),
                ])),
                Icon(childId == k.id ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
                    color: childId == k.id ? AppColors.primary : AppColors.textMuted),
              ]),
            ),
          );
        }),
      ),
    ]);
  }

  Widget _categoryStep() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(tr('What kind of activity?', 'किस तरह का काम?'), style: Fonts.display(22)),
        const SizedBox(height: Sp.md),
        HubGrid(cols: 2, narrowCols: 1, children: [
          for (final c in hubCategories) ChoiceCard(emoji: c.emoji, title: tr(c.label, c.hindi), subtitle: c.blurb, color: c.color,
              selected: category == c.id, onTap: () { _pickCategory(c.id); setState(() { step = 2; _syncLevel(); }); }),
        ]),
      ]);

  Widget _configStep() {
    final cat = hubCategory(category!);
    final view = s.viewOf(childId!);
    final insights = ChildInsights.of(s, childId!);
    final acts = activitiesIn(category!);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Text(cat.emoji, style: const TextStyle(fontSize: 26)),
        const SizedBox(width: Sp.sm),
        Expanded(child: Text(tr('Set up ${cat.label.toLowerCase()}', '${cat.hindi} की तैयारी'), style: Fonts.display(22))),
      ]),
      if (category == 'writing') ...[
        fieldLabel(tr('Practise', 'अभ्यास')),
        HubSegmented(options: [tr('A letter', 'एक अक्षर'), tr('An exercise', 'एक अभ्यास'), tr('Free writing', 'कुछ भी लिखें')],
            selected: mode.index, onChanged: (i) => setState(() {
              mode = _WriteMode.values[i];
              if (mode == _WriteMode.exercise) { activity ??= acts.firstOrNull; _syncLevel(); }
            })),
      ],
      if (kind == HomeworkKind.letter) ...[
        fieldLabel(tr('Letter  ·  weak letters are marked', 'अक्षर  ·  कमज़ोर अक्षर चिह्नित हैं')),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final l in AppData.allLetters) Builder(builder: (_) {
            final band = insights.letterBand(l.id);
            final on = letterId == l.id;
            return Pressable(
              onTap: () => setState(() => letterId = l.id),
              child: Container(
                width: 46, height: 46, alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: on ? AppColors.primary : band == SkillBand.needsPractice ? band.color.withOpacity(0.1) : AppColors.background,
                  borderRadius: BorderRadius.circular(Rad.md),
                  border: Border.all(color: on ? AppColors.primaryDark
                      : band == SkillBand.needsPractice ? band.color.withOpacity(0.6) : AppColors.border, width: on ? 2 : 1)),
                child: Stack(clipBehavior: Clip.none, children: [
                  Text(l.character, style: Fonts.hindi(21, height: 1.2, color: on ? AppColors.textOnPrimary : AppColors.textPrimary)),
                  if (band == SkillBand.needsPractice && !on)
                    Positioned(right: -10, top: -6, child: Icon(Icons.priority_high_rounded, size: 12, color: band.color)),
                ]),
              ),
            );
          }),
        ]),
      ],
      if (kind == HomeworkKind.level) ...[
        fieldLabel(tr('Exercise', 'अभ्यास')),
        for (final a in acts) Padding(
          padding: const EdgeInsets.only(bottom: Sp.xs),
          child: ChoiceCard(
            emoji: a.iconEmoji ?? cat.emoji, title: a.title,
            subtitle: tr('${view.activityProgress[a.id] ?? 0}/${a.levels.length} levels passed', '${view.activityProgress[a.id] ?? 0}/${a.levels.length} स्तर पूरे'),
            color: cat.color, selected: activity?.id == a.id,
            onTap: () => setState(() { activity = a; _syncLevel(); }),
          ),
        ),
        if (activity != null) ...[
          fieldLabel(tr('Level', 'स्तर')),
          SizedBox(height: 44, child: ListView(scrollDirection: Axis.horizontal, children: [
            for (final l in activity!.levels) Padding(padding: const EdgeInsets.only(right: 6), child: HubChip(
                '${l.level}${(view.activityProgress[activity!.id] ?? 0) >= l.level ? ' ✓' : ''}',
                selected: level == l.level, onTap: () => setState(() => level = l.level))),
          ])),
          Padding(padding: const EdgeInsets.only(top: 4), child: Text('${activity!.levels[level - 1].emoji}  ${activity!.levels[level - 1].name} — ${activity!.levels[level - 1].description}',
              style: Fonts.body(13, w: FontWeight.w600, color: AppColors.textSecondary))),
        ],
      ],
      fieldLabel(tr('Difficulty', 'कठिनाई')),
      DifficultyPicker(value: difficulty, onChanged: (v) => setState(() {
        difficulty = v;
        // Harder asks for more good attempts.
        attempts = switch (v) { 'easy' => 2, 'hard' => 5, _ => 3 };
      })),
      fieldLabel(kind == HomeworkKind.letter ? tr('Good writes needed (2★ or more)', 'अच्छे लेख (2★ या ज़्यादा)')
          : kind == HomeworkKind.level ? tr('Times to pass the level', 'स्तर कितनी बार पूरा करना है') : tr('Number of writes', 'कितनी बार लिखना')),
      AttemptStepper(value: attempts, onChanged: (v) => setState(() => attempts = v)),
      fieldLabel(tr('Deadline', 'अंतिम तिथि')),
      DeadlinePicker(value: due, onChanged: (v) => setState(() => due = v)),
      fieldLabel(tr('Message (optional)', 'संदेश (वैकल्पिक)')),
      Wrap(spacing: Sp.xs, runSpacing: Sp.xs, children: [
        for (final m in [tr('You can do it! 💪', 'तुम कर सकते हो! 💪'), tr('Proud of you ⭐', 'तुम पर गर्व है ⭐'),
            tr('Before dinner please 🍲', 'खाने से पहले करना 🍲')])
          HubChip(m, selected: message.text == m, onTap: () => setState(() => message.text = m)),
      ]),
      const SizedBox(height: Sp.sm),
      AccountField(controller: message, label: '', hint: tr('Write your own note…', 'अपना संदेश लिखें…'), maxLength: 120),
    ]);
  }

  Widget _reviewStep() {
    final st = s.studentById(childId!)!;
    final cat = hubCategory(category!);
    Widget row(IconData i, String l, String v) => InfoRow(icon: i, label: l, value: v);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(tr('Review and assign', 'जाँचें और दें'), style: Fonts.display(22)),
      const SizedBox(height: Sp.md),
      Container(
        padding: const EdgeInsets.all(Sp.lg),
        decoration: BoxDecoration(gradient: LinearGradient(colors: [cat.color.withOpacity(0.16), cat.color.withOpacity(0.05)]),
            borderRadius: BorderRadius.circular(Rad.xl2), border: Border.all(color: cat.color.withOpacity(0.35))),
        child: Row(children: [
          Text(cat.emoji, style: const TextStyle(fontSize: 40)),
          const SizedBox(width: Sp.md),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: Fonts.display(20, height: 1.2)),
            Text(tr(cat.label, cat.hindi), style: Fonts.body(13, w: FontWeight.w700, color: AppColors.textSecondary)),
          ])),
        ]),
      ),
      const SizedBox(height: Sp.md),
      ToyCard(child: Column(children: [
        InfoRow(icon: Icons.child_care_rounded, label: tr('For', 'किसके लिए'),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [learnerAvatar(st.name, st.avatar, size: 24), const SizedBox(width: 6),
                Text(st.name, style: Fonts.body(14, w: FontWeight.w800))])),
        row(Icons.speed_rounded, tr('Difficulty', 'कठिनाई'), difficultyLabel(difficulty)),
        row(Icons.repeat_rounded, tr('Attempts', 'प्रयास'), '$attempts'),
        row(Icons.event_rounded, tr('Deadline', 'अंतिम तिथि'), due == null ? tr('No deadline', 'कोई तिथि नहीं') : shortDate(due)),
        if (message.text.trim().isNotEmpty) row(Icons.chat_bubble_outline_rounded, tr('Message', 'संदेश'), message.text.trim()),
      ])),
      const SizedBox(height: Sp.md),
      Row(children: [
        Icon(Icons.home_rounded, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Expanded(child: Text(tr('It will appear on ${st.name}’s Home screen straight away.', 'यह तुरंत ${st.name} की होम स्क्रीन पर दिखेगा।'),
            style: Fonts.body(13, w: FontWeight.w600, color: AppColors.textSecondary))),
      ]),
    ]);
  }
}

class _Stepper extends StatelessWidget {
  final List<String> labels;
  final int step;
  final ValueChanged<int> onTap;
  const _Stepper({required this.labels, required this.step, required this.onTap});
  @override
  Widget build(BuildContext context) => Row(children: [
        for (int i = 0; i < labels.length; i++) ...[
          Expanded(child: Pressable(
            onTap: () => onTap(i),
            child: Column(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                width: 32, height: 32, alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: i <= step ? toneGradient(i < step ? AppColors.success : AppColors.primary) : null,
                  color: i <= step ? null : AppColors.muted,
                  boxShadow: i == step ? toyShadow(AppColors.primaryDark, 2) : null),
                child: i < step ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
                    : Text('${i + 1}', style: Fonts.body(14, w: FontWeight.w800, color: i == step ? Colors.white : AppColors.textSecondary)),
              ),
              const SizedBox(height: 4),
              Text(labels[i], maxLines: 1, overflow: TextOverflow.ellipsis, style: Fonts.body(11.5, w: FontWeight.w800,
                  color: i == step ? AppColors.textPrimary : AppColors.textMuted)),
            ]),
          )),
          if (i < labels.length - 1) Expanded(child: Padding(padding: const EdgeInsets.only(bottom: 18), child: Container(
              height: 3, decoration: BoxDecoration(color: i < step ? AppColors.success : AppColors.muted, borderRadius: BorderRadius.circular(2))))),
        ],
      ]);
}

String difficultyLabel(String d) => switch (d) {
      'easy' => tr('Easy', 'आसान'),
      'hard' => tr('Hard', 'कठिन'),
      _ => tr('Normal', 'सामान्य'),
    };

class DifficultyPicker extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const DifficultyPicker({super.key, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => HubSegmented(
        options: ['🌱 ${difficultyLabel('easy')}', '🌿 ${difficultyLabel('normal')}', '🌳 ${difficultyLabel('hard')}'],
        selected: const ['easy', 'normal', 'hard'].indexOf(value).clamp(0, 2),
        onChanged: (i) => onChanged(const ['easy', 'normal', 'hard'][i]),
      );
}

/// − n + control for a number of attempts.
class AttemptStepper extends StatelessWidget {
  final int value, min, max;
  final ValueChanged<int> onChanged;
  const AttemptStepper({super.key, required this.value, required this.onChanged, this.min = 1, this.max = 30});
  @override
  Widget build(BuildContext context) {
    Widget btn(IconData i, int to) => Pressable(
          onTap: to < min || to > max ? null : () => onChanged(to),
          child: Opacity(opacity: to < min || to > max ? 0.35 : 1, child: Container(width: 44, height: 44,
              decoration: BoxDecoration(color: AppColors.surface, shape: BoxShape.circle, border: Border.all(color: AppColors.border),
                  boxShadow: toyShadow(AppColors.toyShadowColor, 2)),
              child: Icon(i, color: AppColors.primaryDark))),
        );
    return Row(children: [
      btn(Icons.remove_rounded, value - 1),
      SizedBox(width: 64, child: Text('$value', textAlign: TextAlign.center, style: Fonts.display(26))),
      btn(Icons.add_rounded, value + 1),
      const SizedBox(width: Sp.md),
      Expanded(child: Wrap(spacing: 6, runSpacing: 6, children: [
        for (final n in [1, 3, 5, 10]) if (n >= min) HubChip('$n', selected: value == n, onTap: () => onChanged(n)),
      ])),
    ]);
  }
}

/// Deadline chips plus a calendar for any date.
class DeadlinePicker extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  const DeadlinePicker({super.key, required this.value, required this.onChanged});
  static String _in(int d) => DateTime.now().add(Duration(days: d)).toIso8601String().split('T').first;
  @override
  Widget build(BuildContext context) {
    final presets = <(String, String?)>[(tr('Today', 'आज'), _in(0)), (tr('Tomorrow', 'कल'), _in(1)),
        (tr('3 days', '3 दिन'), _in(3)), (tr('1 week', '1 हफ़्ता'), _in(7)), (tr('No date', 'कोई तिथि नहीं'), null)];
    final custom = value != null && !presets.any((p) => p.$2 == value);
    return Wrap(spacing: Sp.xs, runSpacing: Sp.xs, children: [
      for (final p in presets) HubChip(p.$1, selected: !custom && value == p.$2, onTap: () => onChanged(p.$2)),
      HubChip(custom ? '📅 ${shortDate(value)}' : tr('📅 Pick date', '📅 तिथि चुनें'), selected: custom, onTap: () async {
        final now = DateTime.now();
        final d = await showDatePicker(context: context, firstDate: now, lastDate: now.add(const Duration(days: 365)),
            initialDate: DateTime.tryParse(value ?? '') ?? now.add(const Duration(days: 3)));
        if (d != null) onChanged(d.toIso8601String().split('T').first);
      }),
    ]);
  }
}
