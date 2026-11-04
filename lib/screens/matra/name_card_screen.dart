import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/matra_course.dart';
import '../../services/speech_service.dart';
import '../../services/word_grader.dart';
import '../../store/app_store.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../../widgets/common.dart';
import '../../widgets/draw_canvas.dart';
import '../../widgets/hindi_name.dart';
import 'matra_level_screen.dart';
import 'matra_text.dart';

/// "Write my name": the child traces their own name in Devanagari (graded
/// with the word grader), then gets a name card they can share.
class NameCardScreen extends StatefulWidget {
  final Map<String, dynamic> params;
  const NameCardScreen({super.key, this.params = const {}});
  @override
  State<NameCardScreen> createState() => _NameCardScreenState();
}

class _NameCardScreenState extends State<NameCardScreen> {
  final draw = DrawController();
  final cardKey = GlobalKey();
  bool showCard = false, sharing = false;
  int? score;
  /// Size of the pad the name was written on (to show the ink on the card).
  Size pad = const Size(600, 270);

  @override
  void dispose() { draw.dispose(); super.dispose(); }

  void _check(String name, Size padSize) {
    if (draw.isEmpty) return;
    pad = padSize;
    final g = gradeWordStrokes(draw.strokes.map((s) => [...s]).toList(), aksharas(name), padSize.height);
    setState(() => score = g.accuracy);
    speakHindi(name, rate: 0.6);
  }

  Future<void> _share(String name) async {
    setState(() => sharing = true);
    try {
      final boundary = cardKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      await SharePlus.instance.share(ShareParams(
        text: '${MT.shareText} $name',
        files: [XFile.fromData(png!.buffer.asUint8List(), mimeType: 'image/png', name: 'hindi_name_card.png')],
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(MT.shareFailed)));
    } finally {
      if (mounted) setState(() => sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    final name = hindiNameOf(s);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(bottom: false, child: Column(children: [
        HeaderBar(title: MT.writeMyName, subtitle: MT.nameCardTitle, onBack: () => Navigator.of(context).maybePop()),
        Expanded(child: name.isEmpty
            ? Center(child: Text(MT.noNameYet, style: Fonts.body(16, w: FontWeight.w700)))
            : screenScroll(maxWidth: 640, child: showCard ? _card(s, name) : _trace(name))),
      ])),
    );
  }

  Widget _trace(String name) => LayoutBuilder(builder: (_, c) {
        final w = math.min(c.maxWidth, 600.0), h = w * 0.45;
        // Ghost name size: fit the pad's width, but never taller than the lines.
        final fontSize = math.min(h * 0.5, w / math.max(2, aksharas(name).length) * 0.9);
        return Column(children: [
          Text(MT.traceYourName, textAlign: TextAlign.center, style: Fonts.display(22)),
          const SizedBox(height: Sp.xs),
          GestureDetector(
            onTap: () => showHindiNameSheet(context),
            child: Text(MT.fixSpelling, textAlign: TextAlign.center,
                style: Fonts.body(13, w: FontWeight.w600, color: AppColors.textSecondary)),
          ),
          const SizedBox(height: Sp.md),
          SimpleCanvas(
            controller: draw, size: w, height: h, strokeWidth: 6,
            underlay: Center(child: Text(name, maxLines: 1,
                style: Fonts.hindi(fontSize, color: AppColors.textPrimary.withOpacity(0.14), height: 1.2))),
          ),
          const SizedBox(height: Sp.md),
          Row(children: [
            Expanded(child: ResultButton(label: MT.undo, icon: Icons.undo_rounded, filled: false, onTap: draw.undo)),
            const SizedBox(width: Sp.sm),
            Expanded(child: ResultButton(label: MT.clear, icon: Icons.delete_outline_rounded, filled: false,
                onTap: () { draw.clear(); setState(() => score = null); })),
            const SizedBox(width: Sp.sm),
            Expanded(child: ResultButton(label: MT.check, icon: Icons.check_rounded, onTap: () => _check(name, Size(w, h)))),
          ]),
          if (score != null) ...[
            const SizedBox(height: Sp.md),
            PopIn(key: ValueKey(score), child: Column(children: [
              StarRating(stars: math.max(1, score! >= 85 ? 3 : score! >= 60 ? 2 : 1), size: 36),
              const SizedBox(height: Sp.sm),
              Text(score! >= 60 ? MT.greatPlace : MT.tryAgainFriendly, style: Fonts.body(16, w: FontWeight.w700)),
            ])),
            const SizedBox(height: Sp.md),
            ResultButton(label: MT.makeCard, icon: Icons.badge_rounded, onTap: () => setState(() => showCard = true)),
          ],
          const SizedBox(height: Sp.xl),
        ]);
      });

  Widget _card(AppStore s, String name) {
    final known = matrasKnownAfter(s.activityProgress[matraActivityId] ?? 0);
    return Column(children: [
      RepaintBoundary(
        key: cardKey,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(Sp.xl),
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [const Color(0xFFFFF3E0), AppColors.primary.withOpacity(0.25)]),
            borderRadius: BorderRadius.circular(Rad.xl2),
            border: Border.all(color: AppColors.primary, width: 3)),
          child: Column(children: [
            Text('🪔  ${MT.nameCardTitle}  🪔', style: Fonts.display(18, color: const Color(0xFF8A4B12))),
            const SizedBox(height: Sp.md),
            FittedBox(child: Text(name, style: Fonts.hindi(64, color: const Color(0xFF3E2410), height: 1.3))),
            Text(s.userName, style: Fonts.display(20, color: const Color(0xFF6D4C41))),
            if (score != null) ...[
              const SizedBox(height: Sp.md),
              ClipRRect(borderRadius: BorderRadius.circular(Rad.lg), child: Container(
                color: Colors.white.withOpacity(0.6), padding: const EdgeInsets.all(Sp.sm),
                child: SizedBox(height: 90, child: FittedBox(child: SizedBox(
                    width: pad.width, height: pad.height,
                    child: CustomPaint(painter: StrokePainterPublic(draw, const Color(0xFF8A4B12), 7))))),
              )),
            ],
            const SizedBox(height: Sp.md),
            if (known > 0) Text('⭐ ${MT.matrasIKnow(known)}', style: Fonts.body(16, w: FontWeight.w800, color: const Color(0xFF6D4C41))),
            const SizedBox(height: Sp.xs),
            Text('HindiMitra', style: Fonts.body(12, w: FontWeight.w700, color: const Color(0xFF8D6E63))),
          ]),
        ),
      ),
      const SizedBox(height: Sp.lg),
      Row(children: [
        Expanded(child: ResultButton(label: MT.writeMyName, icon: Icons.edit_rounded, filled: false,
            onTap: () => setState(() { showCard = false; draw.clear(); score = null; }))),
        const SizedBox(width: Sp.sm),
        Expanded(child: ResultButton(label: MT.share, icon: Icons.share_rounded, onTap: sharing ? null : () => _share(name))),
      ]),
      const SizedBox(height: Sp.xl),
    ]);
  }
}
