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
import 'assign_activity_screen.dart';
import 'assignment_widgets.dart';
import 'hub_widgets.dart';

/// One assignment in full: progress, every attempt (with the child's
/// handwriting for letter work), the score trend and parent feedback.
class AssignmentDetailScreen extends StatelessWidget {
  final String homeworkId;
  const AssignmentDetailScreen({super.key, required this.homeworkId});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    final h = s.homeworkById(homeworkId);
    if (h == null) {
      return HubPage(title: tr('Assignment', 'काम'), body: EmptyState(emoji: '🗑️', title: tr('Assignment removed', 'काम हटा दिया गया'),
          message: tr('This assignment no longer exists.', 'यह काम अब मौजूद नहीं है।')));
    }
    final st = s.studentById(h.studentId);
    final cat = hubCategory(homeworkCategory(h));
    final status = h.status;
    final attempts = h.attempts.reversed.toList();
    final scores = [for (final a in h.attempts) if (a.accuracy != null) a.accuracy];
    final remaining = (h.goal - h.progress).clamp(0, h.goal);

    return HubPage(
      title: tr('Assignment', 'काम'), subtitle: st?.name,
      action: AssignmentMenu(h, onDeleted: () => Navigator.of(context).maybePop()),
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Summary.
        Container(
          padding: const EdgeInsets.all(Sp.lg),
          decoration: BoxDecoration(
              gradient: LinearGradient(colors: [cat.color.withOpacity(0.18), cat.color.withOpacity(0.05)]),
              borderRadius: BorderRadius.circular(Rad.xl2), border: Border.all(color: cat.color.withOpacity(0.35))),
          child: Row(children: [
            ProgressRing(value: h.fraction, size: 88, color: status.color, center: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('${h.progress.clamp(0, h.goal)}/${h.goal}', style: Fonts.display(20, height: 1)),
              Text(tr('done', 'पूरे'), style: Fonts.body(11, w: FontWeight.w800, color: AppColors.textSecondary)),
            ])),
            const SizedBox(width: Sp.md),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${cat.emoji}  ${tr(cat.label, cat.hindi)} · ${difficultyLabel(h.difficulty)}',
                  style: Fonts.body(12.5, w: FontWeight.w800, color: AppColors.textSecondary)),
              const SizedBox(height: 2),
              Text(h.title, style: Fonts.display(20, height: 1.2)),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 4, children: [
                StatusChip(status),
                SoftPill(icon: Icons.event_rounded, label: dueLabel(h), color: h.overdue ? AppColors.error : AppColors.textSecondary),
              ]),
            ])),
          ]),
        ),
        if (h.note.isNotEmpty) Padding(
          padding: const EdgeInsets.only(top: Sp.sm),
          child: Text('💬 “${h.note}”', style: Fonts.body(14, w: FontWeight.w600, color: AppColors.textSecondary)),
        ),
        const SizedBox(height: Sp.md),
        HubGrid(children: [
          KpiTile(icon: Icons.check_circle_rounded, color: AppColors.success, value: '${h.progress.clamp(0, h.goal)}', label: tr('Completed', 'पूरे')),
          KpiTile(icon: Icons.hourglass_bottom_rounded, color: AppColors.primary, value: '$remaining', label: tr('Remaining', 'बाकी')),
          KpiTile(icon: Icons.track_changes_rounded, color: AppColors.secondary, value: h.accuracy == null ? '—' : '${h.accuracy}%',
              label: tr('Avg accuracy', 'औसत सटीकता')),
          KpiTile(icon: Icons.timer_outlined, color: const Color(0xFF4FB2E6), value: formatDuration(h.secondsSpent), label: tr('Time spent', 'लगा समय')),
        ]),
        if (h.done) Padding(
          padding: const EdgeInsets.only(top: Sp.md),
          child: ToyCard(color: AppColors.success.withOpacity(0.08), borderColor: AppColors.success.withOpacity(0.4), child: Row(children: [
            const Text('🏆', style: TextStyle(fontSize: 28)),
            const SizedBox(width: Sp.sm),
            Expanded(child: Text(tr('${st?.name ?? 'Your child'} finished this on ${shortDate(h.completedAt)}. Send them a cheer below!',
                '${st?.name ?? 'बच्चे'} ने इसे ${shortDate(h.completedAt)} को पूरा किया। नीचे शाबाशी भेजें!'),
                style: Fonts.body(14, w: FontWeight.w700))),
          ])),
        ),
        if (scores.length >= 2) ...[
          HubSection(tr('Scores over attempts', 'प्रयासों में अंक')),
          ChartCard(title: tr('Accuracy per attempt', 'हर प्रयास की सटीकता'),
              caption: tr('First ${scores.first}% → latest ${scores.last}%', 'पहला ${scores.first}% → अभी ${scores.last}%'),
              child: HubLineChart(values: scores, labels: [for (int i = 0; i < scores.length; i++) '#${i + 1}'])),
        ],
        HubSection(tr('Attempts', 'प्रयास'), hindi: '(${h.attempts.length})'),
        if (attempts.isEmpty)
          EmptyState(emoji: '⏳', title: tr('No attempts yet', 'अभी कोई प्रयास नहीं'),
              message: tr('Attempts appear here as soon as ${st?.name ?? 'your child'} starts.', '${st?.name ?? 'बच्चे'} के शुरू करते ही प्रयास यहाँ दिखेंगे।'))
        else
          ToyCard(padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.xs), child: Column(children: [
            for (int i = 0; i < attempts.length; i++) ...[
              if (i > 0) Divider(height: 1, color: AppColors.border),
              _AttemptRow(attempts[i], number: attempts.length - i, h: h),
            ],
          ])),
        HubSection(tr('Feedback', 'संदेश')),
        _FeedbackPanel(h: h),
      ]),
    );
  }
}

class _AttemptRow extends StatelessWidget {
  final HomeworkAttempt a;
  final int number;
  final Homework h;
  const _AttemptRow(this.a, {required this.number, required this.h});
  @override
  Widget build(BuildContext context) {
    final band = bandOf(a.accuracy);
    final when = DateTime.tryParse(a.at)?.toLocal();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Sp.sm),
      child: Row(children: [
        if (a.strokes.isNotEmpty)
          Pressable(onTap: () => _showWork(context, a, h), child: WorkThumb(strokes: a.strokes,
              letter: AppData.letterById(h.target)?.character, size: 56))
        else
          Container(width: 56, height: 56, alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.muted, borderRadius: BorderRadius.circular(Rad.md)),
              child: Text('#$number', style: Fonts.display(17, color: AppColors.textSecondary))),
        const SizedBox(width: Sp.md),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(tr('Attempt $number', 'प्रयास $number'), style: Fonts.body(14.5, w: FontWeight.w800)),
            const SizedBox(width: 6),
            if (a.counted) Icon(Icons.check_circle_rounded, size: 15, color: AppColors.success)
            else Tooltip(message: tr('Not counted: needs 2★ or more', 'गिना नहीं गया: 2★ या ज़्यादा चाहिए'),
                child: Icon(Icons.remove_circle_outline_rounded, size: 15, color: AppColors.textMuted)),
          ]),
          Text([
            if (when != null) '${shortDate(a.at)} ${when.hour.toString().padLeft(2, '0')}:${when.minute.toString().padLeft(2, '0')}',
            if (a.seconds > 0) a.seconds < 60 ? '${a.seconds}s' : formatDuration(a.seconds),
          ].join(' · '), style: Fonts.body(12, w: FontWeight.w600, color: AppColors.textSecondary)),
          if (a.stars > 0) Padding(padding: const EdgeInsets.only(top: 2), child: Row(children: [
            for (int i = 0; i < 3; i++) Icon(i < a.stars ? Icons.star_rounded : Icons.star_outline_rounded, size: 16,
                color: i < a.stars ? AppColors.starGold : AppColors.border),
          ])),
        ])),
        if (a.accuracy != null) Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${a.accuracy}%', style: Fonts.display(20, color: shade(band.color, 0.05))),
          BandChip(band, compact: true),
        ]),
      ]),
    );
  }
}

void _showWork(BuildContext context, HomeworkAttempt a, Homework h) => showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rad.xl)),
      title: Text(tr('Submitted work', 'जमा किया काम'), style: Fonts.display(20)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        WorkThumb(strokes: a.strokes, letter: AppData.letterById(h.target)?.character, size: 260),
        const SizedBox(height: Sp.sm),
        Text([if (a.accuracy != null) '${a.accuracy}%', '${a.stars}★', shortDate(a.at)].join(' · '),
            style: Fonts.body(14, w: FontWeight.w700, color: AppColors.textSecondary)),
      ]),
      actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(),
          child: Text(tr('Close', 'बंद करें'), style: Fonts.body(15, w: FontWeight.w800, color: AppColors.primary)))],
    ));

/// The child's strokes over a faint model letter, on the writing board's paper.
class WorkThumb extends StatelessWidget {
  final List<List<double>> strokes;
  final String? letter;
  final double size;
  const WorkThumb({super.key, required this.strokes, this.letter, this.size = 64});
  @override
  Widget build(BuildContext context) => Container(
        width: size, height: size, clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: AppColors.canvasBackground, borderRadius: BorderRadius.circular(size > 100 ? Rad.lg : Rad.md),
            border: Border.all(color: AppColors.canvasGridLine, width: 1.5)),
        child: Stack(children: [
          if (letter != null) Center(child: Text(letter!, style: Fonts.hindi(size * 0.6, color: AppColors.canvasLetterOutline))),
          CustomPaint(size: Size.square(size), painter: _StrokePainter(strokes, size > 100 ? 6 : 2.5)),
        ]),
      );
}

class _StrokePainter extends CustomPainter {
  final List<List<double>> strokes;
  final double width;
  _StrokePainter(this.strokes, this.width);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = AppColors.canvasStroke..strokeWidth = width..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    for (final s in strokes) {
      if (s.length < 2) continue;
      final path = Path()..moveTo(s[0] * size.width, s[1] * size.height);
      for (int i = 2; i + 1 < s.length; i += 2) {
        path.lineTo(s[i] * size.width, s[i + 1] * size.height);
      }
      if (s.length == 2) canvas.drawCircle(Offset(s[0] * size.width, s[1] * size.height), width / 2, p..style = PaintingStyle.fill);
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(_StrokePainter o) => o.strokes != strokes;
}

/// Messages sent on this assignment, and a composer with quick cheers and
/// optional bonus stars.
class _FeedbackPanel extends StatefulWidget {
  final Homework h;
  const _FeedbackPanel({required this.h});
  @override
  State<_FeedbackPanel> createState() => _FeedbackPanelState();
}

class _FeedbackPanelState extends State<_FeedbackPanel> {
  final text = TextEditingController();
  int stars = 0;

  @override
  void dispose() { text.dispose(); super.dispose(); }

  void send() {
    final t = text.text.trim();
    if (t.isEmpty) return;
    final s = context.read<AppStore>();
    final scope = ParentHubScope.of(context);
    s.addHomeworkFeedback(widget.h.id, ParentNote(at: DateTime.now().toUtc().toIso8601String(), by: scope.parentId, text: t, stars: stars));
    final name = s.studentById(widget.h.studentId)?.name ?? '';
    text.clear();
    setState(() => stars = 0);
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(tr('Sent to $name', '$name को भेजा'))));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppStore>();
    final notes = widget.h.feedback.reversed.toList();
    final cheers = [tr('Shabaash! 🌟', 'शाबाश! 🌟'), tr('Beautiful writing ✍️', 'सुंदर लिखावट ✍️'),
        tr('So proud of you 💛', 'तुम पर बहुत गर्व है 💛'), tr('Keep practising 💪', 'अभ्यास करते रहो 💪')];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final n in notes) Container(
        margin: const EdgeInsets.only(bottom: Sp.sm),
        padding: const EdgeInsets.all(Sp.md - 2),
        decoration: BoxDecoration(color: AppColors.success.withOpacity(0.08), borderRadius: BorderRadius.circular(Rad.lg),
            border: Border.all(color: AppColors.success.withOpacity(0.25))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          learnerAvatar(s.parentById(n.by)?.name ?? 'P', '', size: 30),
          const SizedBox(width: Sp.sm),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(n.text, style: Fonts.body(14.5, w: FontWeight.w700)),
            Text([s.parentById(n.by)?.name ?? '', shortDate(n.at), if (n.stars > 0) '+${n.stars}★'].where((x) => x.isNotEmpty).join(' · '),
                style: Fonts.body(12, w: FontWeight.w600, color: AppColors.textSecondary)),
          ])),
        ]),
      ),
      ToyCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(tr('Send appreciation', 'शाबाशी भेजें'), style: Fonts.display(16)),
        const SizedBox(height: Sp.sm),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final c in cheers) HubChip(c, selected: text.text == c, onTap: () => setState(() => text.text = c)),
        ]),
        const SizedBox(height: Sp.sm),
        AccountField(controller: text, label: '', hint: tr('Write a message…', 'संदेश लिखें…'), maxLength: 140, maxLines: 2),
        Row(children: [
          Text(tr('Bonus stars', 'बोनस सितारे'), style: Fonts.body(13.5, w: FontWeight.w800, color: AppColors.textSecondary)),
          const SizedBox(width: Sp.sm),
          Expanded(child: Wrap(spacing: 6, runSpacing: 6, children: [
            for (final n in [0, 3, 5, 10]) HubChip(n == 0 ? tr('None', 'नहीं') : '+$n ⭐', selected: stars == n, onTap: () => setState(() => stars = n)),
          ])),
        ]),
        const SizedBox(height: Sp.md),
        ResultButton(label: tr('Send', 'भेजें'), icon: Icons.send_rounded, onTap: send),
        const SizedBox(height: 4),
        Text(tr('Your child sees this on their homework card.', 'बच्चा इसे अपने होमवर्क कार्ड पर देखेगा।'),
            textAlign: TextAlign.center, style: Fonts.body(12, w: FontWeight.w600, color: AppColors.textMuted)),
      ])),
    ]);
  }
}
