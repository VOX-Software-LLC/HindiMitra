import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../data/models.dart';
import '../../services/speech_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../../widgets/common.dart';
import '../../util/num_ext.dart';

class _CardColor {
  final Color bg, accent;
  const _CardColor(this.bg, this.accent);
}

final List<_CardColor> _cardColors = [
  const _CardColor(Color(0xFFFEF1DC), AppColors.primary),
  _CardColor(const Color(0xFFE4F6EC), Palette.light.green),
  _CardColor(const Color(0xFFE1F1FB), Palette.light.sky),
  _CardColor(const Color(0xFFFBE4EC), Palette.light.pink),
  _CardColor(const Color(0xFFEBE4FB), Palette.light.purple),
  _CardColor(const Color(0xFFFBF1D3), Palette.light.sunnyForeground),
  const _CardColor(Color(0xFFF1EAD8), AppColors.primaryDark),
  const _CardColor(Color(0xFFFEF6E7), AppColors.textPrimary),
];

/// FlashcardScreen.tsx — swipeable letter flashcards with stamps and sparkles.
class FlashcardsScreen extends StatefulWidget {
  final Map<String, dynamic> params;
  const FlashcardsScreen({super.key, this.params = const {}});
  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

// Two controllers (fly-off + snap-back) need TickerProviderStateMixin; a
// SingleTickerProviderStateMixin can only vend one ticker and crashes the Read tab.
class _FlashcardsScreenState extends State<FlashcardsScreen> with TickerProviderStateMixin {
  int index = 0;
  bool flipped = false;
  String filter = 'all';
  double dx = 0, dy = 0;
  late final AnimationController _fly;
  late final AnimationController _snap;
  double _from = 0, _to = 0, _fromY = 0;
  VoidCallback? _afterFly;

  List<HindiLetter> get letters =>
      filter == 'vowel' ? AppData.vowels : filter == 'consonant' ? AppData.consonants : AppData.allLetters;

  @override
  void initState() {
    super.initState();
    _fly = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _snap = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _fly.addListener(() => setState(() => dx = _from + (_to - _from) * Curves.easeInOut.transform(_fly.value)));
    _fly.addStatusListener((s) {
      if (s == AnimationStatus.completed) { _afterFly?.call(); _afterFly = null; }
    });
    _snap.addListener(() {
      final t = Curves.elasticOut.transform(_snap.value);
      setState(() { dx = _from * (1 - t); dy = _fromY * (1 - t); });
    });
  }

  @override
  void dispose() { _fly.dispose(); _snap.dispose(); super.dispose(); }

  void _advance() {
    setState(() {
      if (index < letters.length - 1) index++;
      flipped = false; dx = 0; dy = 0;
    });
  }

  void _flyTo(double target, VoidCallback after) {
    if (_fly.isAnimating) return;
    _from = dx; _to = target; _afterFly = after;
    _fly.forward(from: 0);
  }

  void _goNext() {
    if (index < letters.length - 1) {
      final w = MediaQuery.of(context).size.width;
      _flyTo(-w * 1.5, _advance);
    }
  }

  void _goPrev() {
    if (index > 0) setState(() { index--; flipped = false; });
  }

  void _listen(HindiLetter l) => speakLetterWithGuide(l.character, l.pronunciation, l.exampleWord);

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final cardW = math.min(w - Sp.lg * 2, 340.0), cardH = cardW * 1.4;
    final threshold = w * 0.3;
    final ls = letters;
    final safe = math.min(index, ls.length - 1);
    final letter = ls[safe];
    final cc = _cardColors[index % _cardColors.length];
    final next = _cardColors[(index + 1) % _cardColors.length];
    final deep = _cardColors[(index + 2) % _cardColors.length];

    final learnedOpacity = (dx / (threshold * 0.6)).clampD(0.0, 1.0);
    final nextOpacity = (-dx / (threshold * 0.6)).clampD(0.0, 1.0);
    final t = ((dx.abs()) / w).clampD(0.0, 1.0);
    final nextScale = 0.92 + 0.08 * t;
    final nextCardOpacity = (0.5 + 0.5 * t).clampD(0.0, 1.0);
    final rot = (dx / w).clampD(-1.0, 1.0) * 12 * math.pi / 180;

    BoxDecoration cardDeco(Color bg) => BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(Rad.xl2),
        border: Border.all(color: AppColors.border), boxShadow: softShadow(AppColors.primary));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(bottom: false, child: Column(children: [
        HeaderBar(title: 'Flashcards', subtitle: 'फ्लैशकार्ड', onBack: () => Navigator.of(context).maybePop()),
        Padding(
          padding: const EdgeInsets.fromLTRB(Sp.md, 0, Sp.md, Sp.sm),
          child: Row(children: [
            for (final g in const ['all', 'vowel', 'consonant']) Padding(
              padding: const EdgeInsets.only(right: Sp.sm),
              child: GestureDetector(
                onTap: () => setState(() { filter = g; index = 0; flipped = false; }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.xs + 2),
                  decoration: BoxDecoration(
                    color: filter == g ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.circular(9999),
                    border: Border.all(color: filter == g ? AppColors.primary : AppColors.border),
                    boxShadow: filter == g ? toyShadow(AppColors.primaryDark, 4) : null),
                  child: Text(g == 'all' ? 'All' : g == 'vowel' ? 'स्वर' : 'व्यंजन',
                      style: filter == g
                          ? Fonts.body(12, w: FontWeight.w800, color: AppColors.textOnPrimary)
                          : Fonts.body(12, w: FontWeight.w600, color: AppColors.textSecondary)),
                ),
              ),
            ),
          ]),
        ),
        Padding(padding: const EdgeInsets.only(bottom: Sp.sm), child: Text.rich(TextSpan(
            style: Fonts.body(14, color: AppColors.textSecondary),
            children: [
              TextSpan(text: '${index + 1}', style: Fonts.display(20, color: AppColors.primaryDark)),
              TextSpan(text: ' / ', style: Fonts.body(14, color: AppColors.textMuted)),
              TextSpan(text: '${ls.length}', style: Fonts.body(14, w: FontWeight.w600, color: AppColors.textMuted)),
            ]))),
        Expanded(child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
          if (index < ls.length - 1)
            Positioned(top: 10, child: Opacity(opacity: nextCardOpacity, child: Transform.scale(scale: nextScale,
              child: Container(width: cardW, height: cardH, decoration: cardDeco(next.bg), alignment: Alignment.center,
                child: Opacity(opacity: 0.3, child: Text(ls[index + 1].character,
                    style: Fonts.hindi(80, color: next.accent, height: cardH / 80))))))),
          if (index < ls.length - 2)
            Positioned(top: 20, child: Opacity(opacity: 0.3, child: Container(
              width: cardW, height: cardH, decoration: cardDeco(deep.bg), alignment: Alignment.center,
              child: Text(ls[index + 2].character, style: Fonts.hindi(60, color: deep.accent.withOpacity(0.25), height: cardH / 60))))),
          GestureDetector(
            onPanStart: (_) { _snap.stop(); },
            onPanUpdate: (d) => setState(() { dx += d.delta.dx; dy += d.delta.dy * 0.3; }),
            onPanEnd: (_) {
              if (dx > threshold || dx < -threshold) {
                final right = dx > 0;
                _flyTo(right ? w * 1.5 : -w * 1.5, _advance);
              } else {
                _from = dx; _fromY = dy;
                _snap.forward(from: 0);
              }
            },
            // The card is cached as one layer while it's dragged around.
            child: Transform.translate(offset: Offset(dx, dy), child: Transform.rotate(angle: rot,
              child: RepaintBoundary(child: Container(
                width: cardW, height: cardH, decoration: cardDeco(cc.bg),
                clipBehavior: Clip.antiAlias,
                child: Stack(children: [
                  Positioned.fill(child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => flipped = !flipped),
                    child: flipped ? _back(letter, cc) : _front(letter, cc),
                  )),
                  Positioned(top: 30, left: 20, child: Opacity(opacity: learnedOpacity, child: _stamp('LEARNED! ✓', AppColors.success))),
                  Positioned(top: 30, right: 20, child: Opacity(opacity: nextOpacity, child: _stamp('NEXT →', AppColors.primary))),
                ]),
              )))),
          ),
        ])),
        Padding(
          padding: const EdgeInsets.fromLTRB(0, Sp.lg, 0, Sp.xl),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _circle(44, AppColors.error, Icons.undo, 24, index > 0 ? AppColors.error : AppColors.disabled, index == 0 ? null : _goPrev),
            const SizedBox(width: Sp.md),
            _circle(52, AppColors.primary, Icons.sync, 28, AppColors.primary, () => setState(() => flipped = !flipped)),
            const SizedBox(width: Sp.md),
            _circle(52, AppColors.primaryDark, Icons.volume_up, 28, AppColors.primaryDark, () => _listen(letter)),
            const SizedBox(width: Sp.md),
            _circle(56, AppColors.success, Icons.favorite, 26,
                index < ls.length - 1 ? AppColors.success : AppColors.disabled, index >= ls.length - 1 ? null : _goNext),
          ]),
        ),
      ])),
    );
  }

  Widget _circle(double size, Color border, IconData ic, double isz, Color icc, VoidCallback? onTap) => GestureDetector(
        onTap: onTap,
        child: Container(width: size, height: size,
            decoration: BoxDecoration(color: AppColors.surface, shape: BoxShape.circle,
                border: Border.all(color: border, width: 2), boxShadow: toyShadow(AppColors.toyShadowColor, 3)),
            child: Icon(ic, size: isz, color: icc)),
      );

  Widget _stamp(String text, Color c) => Transform.rotate(
        angle: -15 * math.pi / 180,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.xs + 2),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(9999),
              border: Border.all(color: c, width: 2), boxShadow: toyShadow(AppColors.primaryDark, 3)),
          child: Text(text, style: Fonts.body(15, w: FontWeight.w800, color: AppColors.success).copyWith(letterSpacing: 0.5)),
        ),
      );

  Widget _front(HindiLetter l, _CardColor cc) => Stack(alignment: Alignment.center, children: [
        const Positioned.fill(child: _Sparkles()),
        FittedBox(fit: BoxFit.scaleDown, child: Column(mainAxisSize: MainAxisSize.min, children: [
          _FloatingLetter(character: l.character, color: cc.accent),
          Container(
            margin: const EdgeInsets.only(top: Sp.md),
            padding: const EdgeInsets.symmetric(horizontal: Sp.lg, vertical: Sp.xs + 2),
            decoration: BoxDecoration(color: cc.accent.withOpacity(0.125), borderRadius: BorderRadius.circular(9999)),
            child: Text(l.group == 'vowel' ? '✦ स्वर Vowel' : '✦ व्यंजन Consonant',
                style: Fonts.body(12, w: FontWeight.w800, color: cc.accent).copyWith(letterSpacing: 0.3)),
          ),
        ])),
        Positioned(bottom: 60, right: 20, child: GestureDetector(
          onTap: () => _listen(l),
          child: Container(width: 52, height: 52,
              decoration: BoxDecoration(color: cc.accent, shape: BoxShape.circle, boxShadow: toyShadow(AppColors.toyShadowColor, 4)),
              child: const Icon(Icons.volume_up, size: 24, color: Colors.white)),
        )),
        Positioned(bottom: 16, child: Opacity(opacity: 0.7,
            child: Text('tap to flip ↻', style: Fonts.body(12, w: FontWeight.w600, color: AppColors.textSecondary)))),
      ]);

  Widget _back(HindiLetter l, _CardColor cc) {
    Widget detail(String emoji, String label, Widget value, {bool wide = false}) => Container(
          width: wide ? double.infinity : null,
          padding: const EdgeInsets.all(Sp.sm),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.8), borderRadius: BorderRadius.circular(Rad.lg),
              border: Border.all(color: const Color(0x99E3D8BC))),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 2),
            Text(label.toUpperCase(), style: Fonts.body(10, w: FontWeight.w600, color: AppColors.textMuted).copyWith(letterSpacing: 0.4)),
            const SizedBox(height: 2),
            value,
          ]),
        );
    return Padding(
      padding: const EdgeInsets.all(Sp.lg),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 80, height: 80, alignment: Alignment.center,
            decoration: BoxDecoration(color: cc.accent.withOpacity(0.08), shape: BoxShape.circle),
            child: Text(l.character, style: Fonts.hindi(48, color: cc.accent, height: 56 / 48))),
        const SizedBox(height: Sp.md),
        Row(children: [
          Expanded(child: detail('🔤', 'Romanized', Text(l.romanized, style: Fonts.body(16, w: FontWeight.w800, color: cc.accent)))),
          const SizedBox(width: Sp.sm),
          Expanded(child: detail('🗣️', 'Say it', Text('"${l.pronunciation}"', textAlign: TextAlign.center,
              style: Fonts.body(16, w: FontWeight.w800, color: cc.accent)))),
        ]),
        const SizedBox(height: Sp.sm),
        detail('📝', 'Example Word', Column(children: [
          Text(l.exampleWord, style: Fonts.hindi(28, color: cc.accent, height: 34 / 28)),
          Text(l.exampleMeaning, style: Fonts.body(12, w: FontWeight.w500, color: AppColors.textSecondary)),
        ]), wide: true),
        const SizedBox(height: Sp.md),
        GestureDetector(
          onTap: () => _listen(l),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: Sp.lg, vertical: Sp.sm + 2),
            decoration: BoxDecoration(color: cc.accent.withOpacity(0.08), borderRadius: BorderRadius.circular(9999)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.volume_up, size: 22, color: cc.accent), const SizedBox(width: Sp.sm),
              Text('Listen to pronunciation', style: Fonts.body(13, w: FontWeight.w800, color: cc.accent).copyWith(letterSpacing: 0.3)),
            ]),
          ),
        ),
        const SizedBox(height: Sp.sm),
        Opacity(opacity: 0.7, child: Text('tap to see letter ↻', style: Fonts.body(12, w: FontWeight.w600, color: AppColors.textSecondary))),
      ]),
    );
  }
}

class _FloatingLetter extends StatefulWidget {
  final String character; final Color color;
  const _FloatingLetter({required this.character, required this.color});
  @override
  State<_FloatingLetter> createState() => _FloatingLetterState();
}

class _FloatingLetterState extends State<_FloatingLetter> with TickerProviderStateMixin {
  late final AnimationController _s = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
  late final AnimationController _r = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000));
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 500), () { if (mounted) _r.repeat(reverse: true); });
  }
  @override
  void dispose() { _s.dispose(); _r.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => RepaintBoundary(child: AnimatedBuilder(
        animation: Listenable.merge([_s, _r]),
        builder: (_, __) {
          final sc = 1 + 0.05 * Curves.easeInOut.transform(_s.value);
          final deg = -2 + 4 * Curves.easeInOut.transform(_r.value);
          return Transform.rotate(angle: deg * math.pi / 180, child: Transform.scale(scale: sc,
              child: Text(widget.character, style: Fonts.hindi(180, color: widget.color, height: 210 / 180))));
        },
      ));
}

class _Sparkles extends StatelessWidget {
  const _Sparkles();
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (_, c) {
        final w = c.maxWidth, h = c.maxHeight;
        Widget at({double? top, double? bottom, double? left, double? right, required int delay}) => Positioned(
            top: top == null ? null : h * top, bottom: bottom == null ? null : h * bottom,
            left: left == null ? null : w * left, right: right == null ? null : w * right,
            child: _Sparkle(delay: delay));
        return Stack(children: [
          at(top: 0.10, left: 0.15, delay: 0),
          at(top: 0.15, right: 0.18, delay: 200),
          at(bottom: 0.25, left: 0.12, delay: 400),
          at(bottom: 0.20, right: 0.15, delay: 600),
          at(top: 0.35, left: 0.08, delay: 300),
          at(top: 0.30, right: 0.10, delay: 500),
        ]);
      });
}

class _Sparkle extends StatefulWidget {
  final int delay;
  const _Sparkle({required this.delay});
  @override
  State<_Sparkle> createState() => _SparkleState();
}

class _SparkleState extends State<_Sparkle> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
  bool _started = false;
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) { setState(() => _started = true); _c.repeat(reverse: true); }
    });
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => RepaintBoundary(child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          final v = _started ? _c.value : 0.0;
          return Opacity(opacity: _started ? (0.2 + 0.8 * v) : 0,
              child: Transform.scale(scale: 0.3 + 0.9 * v,
                  child: Text('✦', style: Fonts.body(20, color: AppColors.starGold))));
        },
      ));
}
