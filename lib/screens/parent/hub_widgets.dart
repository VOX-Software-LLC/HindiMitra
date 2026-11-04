import 'dart:math' as math;
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

/// Shared state of an open Parent Hub: who unlocked it and which child the
/// hub is looking at (kept in step across every tab and pushed screen).
class ParentHubScope extends InheritedNotifier<ValueNotifier<String>> {
  final String parentId;
  const ParentHubScope({super.key, required this.parentId, required ValueNotifier<String> selected,
      required super.child}) : super(notifier: selected);
  ValueNotifier<String> get selected => notifier!;

  static ParentHubScope of(BuildContext c) => c.dependOnInheritedWidgetOfExactType<ParentHubScope>()!;
}

/// Locks the Parent Hub: ends any "stay unlocked" time and closes the hub.
void lockParentHub(BuildContext context) {
  context.read<AppStore>().keepParentUnlocked(ParentHubScope.of(context).parentId, 0);
  Navigator.of(context).maybePop();
}

/// Pushes a Parent Hub screen, keeping the hub's scope above it.
Future<T?> pushHub<T>(BuildContext context, Widget screen) {
  final scope = ParentHubScope.of(context);
  return Navigator.of(context, rootNavigator: true).push<T>(MaterialPageRoute(
      builder: (_) => ParentHubScope(parentId: scope.parentId, selected: scope.selected, child: screen)));
}

/// Children the open hub can see: the parent's linked children, or every
/// learner on the device when none is linked yet. A fresh install's
/// placeholder learner (never set up) is left out.
List<StudentAccount> hubChildren(AppStore s, String parentId) {
  bool real(StudentAccount k) => k.remote || s.recordOf(k.id).onboarded;
  final kids = s.childrenOf(parentId).where(real).toList();
  return kids.isNotEmpty ? kids : s.learners.where(real).toList();
}

/// A pushed Parent Hub page: header with back button, scrolling body.
class HubPage extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget body;
  final Widget? action, bottom;
  final bool scroll;
  const HubPage({super.key, required this.title, this.subtitle, required this.body, this.action, this.bottom,
      this.scroll = true});
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(bottom: false, child: Column(children: [
          HeaderBar(title: title, subtitle: subtitle, onBack: () => Navigator.of(context).maybePop(), rightAction: action),
          Expanded(child: scroll
              ? screenScroll(maxWidth: 820, padding: const EdgeInsets.fromLTRB(Sp.md, Sp.sm, Sp.md, Sp.xxl), child: body)
              : body),
          if (bottom != null) bottom!,
        ])),
      );
}

/// Section title with an optional action on the right.
class HubSection extends StatelessWidget {
  final String title;
  final String? hindi;
  final Widget? action;
  const HubSection(this.title, {super.key, this.hindi, this.action});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: Sp.lg, bottom: Sp.sm),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(child: Text.rich(TextSpan(text: title, style: Fonts.display(19), children: [
            if (hindi != null) TextSpan(text: '  $hindi', style: Fonts.body(14, w: FontWeight.w700, color: AppColors.textSecondary)),
          ]), maxLines: 1, overflow: TextOverflow.ellipsis)),
          if (action != null) ...[const SizedBox(width: Sp.sm), action!],
        ]),
      );
}

/// A headline figure: icon tile, big value, label and an optional note.
class KpiTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value, label;
  final String? note;
  final VoidCallback? onTap;
  const KpiTile({super.key, required this.icon, required this.color, required this.value, required this.label,
      this.note, this.onTap});
  @override
  Widget build(BuildContext context) => ToyCard(
        onTap: onTap, shadow: 3, padding: const EdgeInsets.all(Sp.md - 2),
        child: Row(children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [color.withOpacity(0.14), color.withOpacity(0.30)]),
              borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, size: 21, color: shade(color, 0.08))),
          const SizedBox(width: Sp.sm + 2),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
                child: Text(value, style: Fonts.display(23, height: 1.1))),
            Text(label, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: Fonts.body(12, w: FontWeight.w700, color: AppColors.textSecondary, height: 1.2)),
            if (note != null) Text(note!, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: Fonts.body(11, w: FontWeight.w600, color: AppColors.textMuted)),
          ])),
        ]),
      );
}

/// Lays children out in [cols] equal columns (fewer on narrow screens).
class HubGrid extends StatelessWidget {
  final List<Widget> children;
  final int cols, narrowCols;
  final double gap;
  const HubGrid({super.key, required this.children, this.cols = 4, this.narrowCols = 2, this.gap = Sp.sm});
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (_, c) {
        final n = c.maxWidth >= 640 ? cols : narrowCols;
        final w = (c.maxWidth - gap * (n - 1)) / n;
        return Wrap(spacing: gap, runSpacing: gap, children: [for (final ch in children) SizedBox(width: w, child: ch)]);
      });
}

/// Horizontal row of child avatars to pick which child the hub shows.
class ChildSelector extends StatelessWidget {
  final List<StudentAccount> kids;
  final String selected;
  final ValueChanged<String> onSelect;
  final VoidCallback? onAdd;
  const ChildSelector({super.key, required this.kids, required this.selected, required this.onSelect, this.onAdd});
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 46,
        child: ListView(scrollDirection: Axis.horizontal, children: [
          for (final k in kids) Padding(
            padding: const EdgeInsets.only(right: Sp.sm),
            child: Pressable(
              onTap: () => onSelect(k.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.fromLTRB(4, 4, 14, 4),
                decoration: BoxDecoration(
                  gradient: k.id == selected ? toneGradient(AppColors.primary) : null,
                  color: k.id == selected ? null : AppColors.surface,
                  borderRadius: BorderRadius.circular(9999),
                  border: Border.all(color: k.id == selected ? AppColors.primaryDark : AppColors.border),
                  boxShadow: toyShadow(k.id == selected ? AppColors.primaryDark : AppColors.toyShadowColor, 2)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  learnerAvatar(k.name, k.avatar, size: 36, ring: k.id == selected ? Colors.white : null),
                  const SizedBox(width: 8),
                  Text(k.name, style: Fonts.body(14, w: FontWeight.w800,
                      color: k.id == selected ? AppColors.textOnPrimary : AppColors.textPrimary)),
                ]),
              ),
            ),
          ),
          if (onAdd != null) Center(child: SoftPill(icon: Icons.add_rounded, label: tr('Add', 'जोड़ें'), onTap: onAdd)),
        ]),
      );
}

/// A skill band with its icon and label (never colour alone).
class BandChip extends StatelessWidget {
  final SkillBand band;
  final bool compact;
  const BandChip(this.band, {super.key, this.compact = false});
  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 9, vertical: 3),
        decoration: BoxDecoration(color: band.color.withOpacity(0.12), borderRadius: BorderRadius.circular(9999),
            border: Border.all(color: band.color.withOpacity(0.3))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(band.icon, size: 13, color: band.color),
          if (!compact) ...[
            const SizedBox(width: 4),
            Text(tr(band.label, band.hindi), style: Fonts.body(11.5, w: FontWeight.w800, color: shade(band.color, 0.1))),
          ],
        ]),
      );
}

/// Legend for the four skill bands.
class BandLegend extends StatelessWidget {
  const BandLegend({super.key});
  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: Sp.xs, runSpacing: Sp.xs, children: [for (final b in SkillBand.values) BandChip(b)]);
}

extension HomeworkStatusUi on HomeworkStatus {
  String get label => tr(const ['Assigned', 'In progress', 'Completed', 'Overdue'][index],
      const ['दिया गया', 'चल रहा है', 'पूरा', 'देर हो गई'][index]);
  Color get color => [AppColors.secondary, const Color(0xFF4FB2E6), AppColors.success, AppColors.error][index];
  IconData get icon => const [Icons.assignment_rounded, Icons.timelapse_rounded, Icons.check_circle_rounded,
      Icons.warning_amber_rounded][index];
}

class StatusChip extends StatelessWidget {
  final HomeworkStatus status;
  const StatusChip(this.status, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(color: status.color.withOpacity(0.12), borderRadius: BorderRadius.circular(9999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(status.icon, size: 13, color: status.color),
          const SizedBox(width: 4),
          Text(status.label, style: Fonts.body(11.5, w: FontWeight.w800, color: shade(status.color, 0.12))),
        ]),
      );
}

/// Friendly empty state: a big emoji, a line of text and an optional action.
class EmptyState extends StatelessWidget {
  final String emoji, title, message;
  final String? actionLabel;
  final IconData actionIcon;
  final VoidCallback? onAction;
  const EmptyState({super.key, required this.emoji, required this.title, required this.message, this.actionLabel,
      this.actionIcon = Icons.add_rounded, this.onAction});
  @override
  Widget build(BuildContext context) => ToyCard(
        padding: const EdgeInsets.symmetric(horizontal: Sp.lg, vertical: Sp.xl),
        child: Column(children: [
          Container(width: 76, height: 76, alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primary.withOpacity(0.1)),
              child: Text(emoji, style: const TextStyle(fontSize: 38))),
          const SizedBox(height: Sp.md),
          Text(title, textAlign: TextAlign.center, style: Fonts.display(19)),
          const SizedBox(height: 4),
          Text(message, textAlign: TextAlign.center, style: Fonts.body(14, color: AppColors.textSecondary, height: 1.4)),
          if (actionLabel != null) ...[
            const SizedBox(height: Sp.md),
            ToyButton(label: actionLabel!, size: ToySize.sm, onPressed: onAction,
                leading: Icon(actionIcon, size: 18, color: AppColors.textOnPrimary)),
          ],
        ]),
      );
}

/// Progress ring with a label in the middle.
class ProgressRing extends StatelessWidget {
  final double value;
  final double size, stroke;
  final Color? color;
  final Widget center;
  const ProgressRing({super.key, required this.value, required this.center, this.size = 92, this.stroke = 10,
      this.color});
  @override
  Widget build(BuildContext context) => SizedBox(
        width: size, height: size,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)), duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (_, v, __) => CustomPaint(
            painter: _RingPainter(v, color ?? AppColors.primary, AppColors.muted, stroke),
            child: Center(child: center),
          ),
        ),
      );
}

class _RingPainter extends CustomPainter {
  final double v, stroke;
  final Color color, track;
  _RingPainter(this.v, this.color, this.track, this.stroke);
  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    canvas.drawArc(r, 0, math.pi * 2, false, Paint()..color = track..style = PaintingStyle.stroke..strokeWidth = stroke);
    if (v > 0) {
      canvas.drawArc(r, -math.pi / 2, math.pi * 2 * v, false, Paint()
        ..color = color..style = PaintingStyle.stroke..strokeWidth = stroke..strokeCap = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.v != v || o.color != color;
}

/// Label, value and a thin progress bar.
class ProgressRow extends StatelessWidget {
  final String label, value;
  final double fraction;
  final Color? color;
  final Widget? leading;
  const ProgressRow({super.key, required this.label, required this.value, required this.fraction, this.color,
      this.leading});
  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          if (leading != null) ...[leading!, const SizedBox(width: Sp.sm)],
          Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: Fonts.body(14, w: FontWeight.w700))),
          Text(value, style: Fonts.body(13, w: FontWeight.w800, color: AppColors.textSecondary)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(borderRadius: BorderRadius.circular(9999),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: fraction.clamp(0.0, 1.0)), duration: const Duration(milliseconds: 600),
              builder: (_, v, __) => LinearProgressIndicator(value: v, minHeight: 8, color: c, backgroundColor: AppColors.muted),
            )),
      ]),
    );
  }
}

/// Card holding a chart: title, an optional caption and the plot.
class ChartCard extends StatelessWidget {
  final String title;
  final String? caption;
  final Widget child;
  final Widget? trailing;
  const ChartCard({super.key, required this.title, this.caption, required this.child, this.trailing});
  @override
  Widget build(BuildContext context) => ToyCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: Fonts.display(16)),
              if (caption != null) Text(caption!, style: Fonts.body(12.5, w: FontWeight.w600, color: AppColors.textSecondary)),
            ])),
            if (trailing != null) trailing!,
          ]),
          const SizedBox(height: Sp.md),
          child,
        ]),
      );
}

/// Single-series bar chart with a recessive baseline, rounded bar tops, the
/// latest bar highlighted, and the value of the tapped bar shown above it.
class HubBarChart extends StatefulWidget {
  final List<double> values;
  final List<String> labels;
  final String Function(double) format;
  final Color? color;
  final double height;
  const HubBarChart({super.key, required this.values, required this.labels, required this.format, this.color,
      this.height = 150});
  @override
  State<HubBarChart> createState() => _HubBarChartState();
}

class _HubBarChartState extends State<HubBarChart> {
  int? sel;
  @override
  Widget build(BuildContext context) {
    final c = widget.color ?? AppColors.primary;
    final maxV = widget.values.fold<double>(0, math.max);
    final n = widget.values.length;
    final showEvery = n > 14 ? (n / 7).ceil() : 1;
    final focus = sel ?? (n == 0 ? null : n - 1);
    if (maxV == 0) {
      return SizedBox(height: widget.height, child: Center(child: Text(tr('No practice in this period yet', 'इस अवधि में अभी अभ्यास नहीं'),
          style: Fonts.body(13, w: FontWeight.w700, color: AppColors.textMuted))));
    }
    return Column(children: [
      SizedBox(
        height: 22,
        child: focus == null ? null : Text('${widget.labels[focus]} · ${widget.format(widget.values[focus])}',
            style: Fonts.body(13, w: FontWeight.w800)),
      ),
      SizedBox(
        height: widget.height,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (int i = 0; i < n; i++) Expanded(child: MouseRegion(
            onEnter: (_) => setState(() => sel = i),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => sel = i),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: n > 14 ? 1 : 3),
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 500), curve: Curves.easeOutCubic,
                    height: math.max(widget.values[i] > 0 ? 4 : 2, (widget.height - 4) * widget.values[i] / maxV),
                    decoration: BoxDecoration(
                      color: widget.values[i] == 0 ? AppColors.muted
                          : i == focus ? c : c.withOpacity(0.45),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
                  ),
                ]),
              ),
            ),
          )),
        ]),
      ),
      Container(height: 1, color: AppColors.border),
      const SizedBox(height: 4),
      Row(children: [
        for (int i = 0; i < n; i++) Expanded(child: Text(i % showEvery == 0 || i == n - 1 ? widget.labels[i] : '',
            textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.visible, softWrap: false,
            style: Fonts.body(10.5, w: FontWeight.w700, color: i == focus ? AppColors.textPrimary : AppColors.textMuted))),
      ]),
    ]);
  }
}

/// Line chart of a 0-100 measure over time (gaps where there is no value),
/// optionally with an earlier period as a dashed grey line for comparison.
class HubLineChart extends StatefulWidget {
  final List<int?> values;
  final List<int?>? previous;
  final List<String> labels;
  final Color? color;
  final double height;
  final String unit;
  const HubLineChart({super.key, required this.values, required this.labels, this.previous, this.color,
      this.height = 150, this.unit = '%'});
  @override
  State<HubLineChart> createState() => _HubLineChartState();
}

class _HubLineChartState extends State<HubLineChart> {
  int? sel;
  @override
  Widget build(BuildContext context) {
    final c = widget.color ?? AppColors.secondary;
    final n = widget.values.length;
    final has = widget.values.any((v) => v != null);
    if (!has) {
      return SizedBox(height: widget.height, child: Center(child: Text(tr('No scored practice in this period yet', 'इस अवधि में अभी कोई अंक नहीं'),
          style: Fonts.body(13, w: FontWeight.w700, color: AppColors.textMuted))));
    }
    int? focus = sel;
    focus ??= widget.values.lastIndexWhere((v) => v != null);
    final showEvery = n > 14 ? (n / 7).ceil() : 1;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(height: 22, child: Text(
          widget.values[focus] == null ? '${widget.labels[focus]} · —'
              : '${widget.labels[focus]} · ${widget.values[focus]}${widget.unit}'
                  '${widget.previous != null && widget.previous![focus] != null ? tr('  (before: ${widget.previous![focus]}${widget.unit})', '  (पहले: ${widget.previous![focus]}${widget.unit})') : ''}',
          style: Fonts.body(13, w: FontWeight.w800))),
      SizedBox(
        height: widget.height,
        child: LayoutBuilder(builder: (_, box) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => setState(() => sel = (d.localPosition.dx / box.maxWidth * n).floor().clamp(0, n - 1)),
          onHorizontalDragUpdate: (d) => setState(() => sel = (d.localPosition.dx / box.maxWidth * n).floor().clamp(0, n - 1)),
          child: MouseRegion(
            onHover: (e) => setState(() => sel = (e.localPosition.dx / box.maxWidth * n).floor().clamp(0, n - 1)),
            child: CustomPaint(size: Size(box.maxWidth, widget.height),
                painter: _LinePainter(widget.values, widget.previous, c, AppColors.border, AppColors.textMuted,
                    AppColors.surface, focus)),
          ),
        )),
      ),
      const SizedBox(height: 4),
      Row(children: [
        for (int i = 0; i < n; i++) Expanded(child: Text(i % showEvery == 0 || i == n - 1 ? widget.labels[i] : '',
            textAlign: TextAlign.center, maxLines: 1, softWrap: false, overflow: TextOverflow.visible,
            style: Fonts.body(10.5, w: FontWeight.w700, color: i == focus ? AppColors.textPrimary : AppColors.textMuted))),
      ]),
      if (widget.previous != null) Padding(
        padding: const EdgeInsets.only(top: Sp.sm),
        child: Wrap(spacing: Sp.md, children: [
          _legend(c, tr('This period', 'यह अवधि'), false),
          _legend(AppColors.textMuted, tr('Previous period', 'पिछली अवधि'), true),
        ]),
      ),
    ]);
  }

  Widget _legend(Color c, String t, bool dashed) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 18, height: 3, decoration: BoxDecoration(color: dashed ? c.withOpacity(0.6) : c,
            borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Text(t, style: Fonts.body(12, w: FontWeight.w700, color: AppColors.textSecondary)),
      ]);
}

class _LinePainter extends CustomPainter {
  final List<int?> v;
  final List<int?>? prev;
  final Color c, grid, muted, surface;
  final int? focus;
  _LinePainter(this.v, this.prev, this.c, this.grid, this.muted, this.surface, this.focus);

  @override
  void paint(Canvas canvas, Size size) {
    final n = v.length;
    final step = size.width / n;
    double x(int i) => step * i + step / 2;
    double y(int val) => size.height - 6 - (size.height - 12) * val / 100;
    final g = Paint()..color = grid..strokeWidth = 1;
    for (final t in [0, 50, 100]) {
      canvas.drawLine(Offset(0, y(t)), Offset(size.width, y(t)), g);
    }
    void series(List<int?> s, Paint p, {bool dots = false}) {
      Path? path;
      for (int i = 0; i < s.length; i++) {
        final val = s[i];
        if (val == null) continue;
        final pt = Offset(x(i), y(val));
        if (path == null) {
          path = Path()..moveTo(pt.dx, pt.dy);
        } else {
          path.lineTo(pt.dx, pt.dy);
        }
      }
      if (path != null) canvas.drawPath(path, p);
      if (dots) {
        for (int i = 0; i < s.length; i++) {
          if (s[i] == null) continue;
          final pt = Offset(x(i), y(s[i]!));
          final r = i == focus ? 6.0 : 4.0;
          canvas.drawCircle(pt, r + 2, Paint()..color = surface);
          canvas.drawCircle(pt, r, Paint()..color = c);
        }
      }
    }

    if (prev != null) {
      final p = Paint()..color = muted.withOpacity(0.55)..strokeWidth = 2..style = PaintingStyle.stroke;
      series(prev!, p);
    }
    if (focus != null) {
      canvas.drawLine(Offset(x(focus!), 0), Offset(x(focus!), size.height), Paint()..color = grid..strokeWidth = 1.5);
    }
    series(v, Paint()..color = c..strokeWidth = 2.5..style = PaintingStyle.stroke..strokeJoin = StrokeJoin.round, dots: true);
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (final t in [0, 50, 100]) {
      tp.text = TextSpan(text: '$t', style: TextStyle(fontSize: 9, color: muted));
      tp.layout();
      tp.paint(canvas, Offset(2, y(t) - tp.height - 1));
    }
  }

  @override
  bool shouldRepaint(_LinePainter o) => true;
}

/// Rounded square for one letter, tinted by its skill band, with accuracy.
class LetterTile extends StatelessWidget {
  final String character;
  final SkillBand band;
  final int? accuracy;
  final VoidCallback? onTap;
  const LetterTile({super.key, required this.character, required this.band, this.accuracy, this.onTap});
  @override
  Widget build(BuildContext context) => Tooltip(
        message: '$character · ${tr(band.label, band.hindi)}${accuracy == null ? '' : ' · $accuracy%'}',
        child: Pressable(
          onTap: onTap,
          child: Container(
            width: 56, height: 64,
            decoration: BoxDecoration(
              color: band == SkillBand.notStarted ? AppColors.surface : band.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(Rad.md),
              border: Border.all(color: band == SkillBand.notStarted ? AppColors.border : band.color.withOpacity(0.5),
                  width: 1.5)),
            child: Stack(children: [
              Positioned(right: 3, top: 3, child: Icon(band.icon, size: 11, color: band.color)),
              Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(character, style: Fonts.hindi(22, height: 1.15,
                    color: band == SkillBand.notStarted ? AppColors.textMuted : AppColors.textPrimary)),
                Text(accuracy == null ? '—' : '$accuracy%',
                    style: Fonts.body(10.5, w: FontWeight.w800, color: AppColors.textSecondary)),
              ]),
            ]),
          ),
        ),
      );
}

/// Big round icon button used for the dashboard's quick actions.
class QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const QuickAction({super.key, required this.icon, required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: Sp.md, horizontal: Sp.xs),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(Rad.xl),
              border: Border.all(color: AppColors.border), boxShadow: toyShadow(AppColors.toyShadowColor, 3)),
          child: Column(children: [
            Container(width: 50, height: 50,
                decoration: BoxDecoration(gradient: toneGradient(color), borderRadius: BorderRadius.circular(17),
                    boxShadow: toyShadow(shade(color), 3)),
                child: Icon(icon, color: Colors.white, size: 25)),
            const SizedBox(height: Sp.sm),
            Text(label, textAlign: TextAlign.center, maxLines: 2,
                style: Fonts.body(13, w: FontWeight.w800, height: 1.15)),
          ]),
        ),
      );
}

/// Segmented control (e.g. Week / Month / All time).
class HubSegmented extends StatelessWidget {
  final List<String> options;
  final int selected;
  final ValueChanged<int> onChanged;
  const HubSegmented({super.key, required this.options, required this.selected, required this.onChanged});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: AppColors.muted, borderRadius: BorderRadius.circular(9999)),
        child: Row(children: [
          for (int i = 0; i < options.length; i++) Expanded(child: Pressable(
            onTap: () => onChanged(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                color: i == selected ? AppColors.surface : Colors.transparent,
                borderRadius: BorderRadius.circular(9999),
                boxShadow: i == selected ? toyShadow(AppColors.toyShadowColor, 2) : null),
              child: Text(options[i], textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: Fonts.body(13.5, w: FontWeight.w800,
                      color: i == selected ? AppColors.primaryDark : AppColors.textSecondary)),
            ),
          )),
        ]),
      );
}

/// Selectable card used in pickers (category, reward, kind).
class ChoiceCard extends StatelessWidget {
  final String emoji, title;
  final String? subtitle;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const ChoiceCard({super.key, required this.emoji, required this.title, this.subtitle, required this.color,
      required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(Sp.md - 2),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.12) : AppColors.surface,
            borderRadius: BorderRadius.circular(Rad.xl),
            border: Border.all(color: selected ? color : AppColors.border, width: selected ? 2 : 1),
            boxShadow: toyShadow(selected ? shade(color, 0.1).withOpacity(0.6) : AppColors.toyShadowColor, selected ? 3 : 2)),
          child: Row(children: [
            Container(width: 44, height: 44, alignment: Alignment.center,
                decoration: BoxDecoration(color: color.withOpacity(0.16), borderRadius: BorderRadius.circular(14)),
                child: Text(emoji, style: const TextStyle(fontSize: 22))),
            const SizedBox(width: Sp.sm + 2),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Fonts.body(15, w: FontWeight.w800)),
              if (subtitle != null) Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: Fonts.body(12, w: FontWeight.w600, color: AppColors.textSecondary)),
            ])),
            AnimatedOpacity(opacity: selected ? 1 : 0, duration: const Duration(milliseconds: 200),
                child: Icon(Icons.check_circle_rounded, color: color)),
          ]),
        ),
      );
}

/// Small choice chip in the app's style.
class HubChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const HubChip(this.label, {super.key, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            gradient: selected ? toneGradient(AppColors.primary) : null,
            color: selected ? null : AppColors.surface,
            borderRadius: BorderRadius.circular(9999),
            border: Border.all(color: selected ? AppColors.primaryDark : AppColors.border),
            boxShadow: selected ? toyShadow(AppColors.primaryDark, 2) : null),
          child: Text(label, style: Fonts.body(13.5, w: FontWeight.w800,
              color: selected ? AppColors.textOnPrimary : AppColors.textPrimary)),
        ),
      );
}

/// Label above a form control.
Widget fieldLabel(String t) => Padding(
      padding: const EdgeInsets.only(top: Sp.md, bottom: Sp.sm),
      child: Text(t, style: Fonts.body(13.5, w: FontWeight.w800, color: AppColors.textSecondary)),
    );

/// Full-screen success state with confetti, used after assigning or creating.
class HubSuccess extends StatelessWidget {
  final String emoji, title, message;
  final List<Widget> actions;
  const HubSuccess({super.key, required this.emoji, required this.title, required this.message, required this.actions});
  @override
  Widget build(BuildContext context) => Stack(children: [
        Center(child: SingleChildScrollView(padding: const EdgeInsets.all(Sp.lg), child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: PopIn(child: Container(
            padding: const EdgeInsets.all(Sp.lg),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(Rad.xl2),
                border: Border.all(color: AppColors.border), boxShadow: softShadow(AppColors.success)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              PopIn(delayMs: 120, child: Container(width: 96, height: 96, alignment: Alignment.center,
                  decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(
                      colors: [AppColors.starGold.withOpacity(0.5), AppColors.success.withOpacity(0.12)])),
                  child: Text(emoji, style: const TextStyle(fontSize: 50)))),
              const SizedBox(height: Sp.md),
              Text(title, textAlign: TextAlign.center, style: Fonts.display(24)),
              const SizedBox(height: Sp.sm),
              Text(message, textAlign: TextAlign.center, style: Fonts.body(15, color: AppColors.textSecondary, height: 1.4)),
              const SizedBox(height: Sp.lg),
              for (final a in actions) Padding(padding: const EdgeInsets.only(bottom: Sp.sm), child: a),
            ]),
          )),
        ))),
        const IgnorePointer(child: Confetti(visible: true)),
      ]);
}

/// Title of a homework's target ("Write क", "Word Reading · Level 3").
String targetLabel(Homework h) => switch (h.kind) {
      HomeworkKind.letter => AppData.letterById(h.target)?.character ?? h.target,
      HomeworkKind.level => '${hubActivity(h.target)?.title ?? h.target} · L${h.level}',
      HomeworkKind.practice => tr('Any writing', 'कोई भी लेखन'),
    };

/// A homework's category, guessed for homework set before categories existed.
String homeworkCategory(Homework h) => h.category.isNotEmpty ? h.category
    : h.kind == HomeworkKind.level ? categoryOfActivity(h.target) : 'writing';

/// "Due today" / "Due in 3 days" / "2 days late".
String dueLabel(Homework h) {
  if (h.done) return tr('Done ${shortDate(h.completedAt)}', '${shortDate(h.completedAt)} को पूरा');
  if (h.dueDate == null) return tr('No deadline', 'कोई तिथि नहीं');
  final now = DateTime.now();
  final due = DateTime.tryParse(h.dueDate!);
  if (due == null) return h.dueDate!;
  final d = due.difference(DateTime(now.year, now.month, now.day)).inDays;
  if (d == 0) return tr('Due today', 'आज तक');
  if (d == 1) return tr('Due tomorrow', 'कल तक');
  if (d > 1) return tr('Due in $d days', '$d दिन में');
  return tr('${-d} day${d == -1 ? '' : 's'} late', '${-d} दिन देर');
}

/// Watches the store and gives the selected child's insights.
ChildInsights? selectedInsights(BuildContext context) {
  final s = context.watch<AppStore>();
  final scope = ParentHubScope.of(context);
  final kids = hubChildren(s, scope.parentId);
  if (kids.isEmpty) return null;
  final id = kids.any((k) => k.id == scope.selected.value) ? scope.selected.value : kids.first.id;
  return ChildInsights.of(s, id);
}
