import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/palette.dart';
import '../theme/themes.dart';
import '../widgets/toy_button.dart';

const _saffron = Color(0xFFFF9933);
const _green = Color(0xFF138808);
const _navy = Color(0xFF0B1F6B);
const _muted = Color(0xFF5B6475);
const _cream = Color(0xFFFFFBF4);
const _line = Color(0xFFEDE6D8);

/// Letters that drift around the chakra in the hero visual: (glyph, angle°, colour).
const _orbit = [
  ('अ', -150.0, Color(0xFFE8820C)),
  ('क', -35.0, _navy),
  ('म', 40.0, _green),
  ('ह', 145.0, Color(0xFF7B3FC4)),
];

/// Opening screen shown on every launch: the turning Ashoka Chakra, the
/// HindiMitra wordmark, "Made in India" and "Developed by VoxCRE". First-time
/// users tap to begin; returning users are taken on automatically after a
/// moment (tap anywhere to skip).
class IntroScreen extends StatefulWidget {
  final VoidCallback onContinue;
  final bool autoContinue;
  const IntroScreen({super.key, required this.onContinue, this.autoContinue = false});
  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> with TickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(vsync: this, duration: const Duration(seconds: 24))..repeat();
  late final AnimationController _enter = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..forward();
  late final AnimationController _auto = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200));
  bool _done = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoContinue) {
      _auto.forward().whenComplete(() { if (_auto.isCompleted) _go(); });
    }
  }

  void _go() {
    if (_done) return;
    _done = true;
    widget.onContinue();
  }

  @override
  void dispose() { _spin.dispose(); _enter.dispose(); _auto.dispose(); super.dispose(); }

  Widget _fadeIn(double from, Widget child) {
    final a = CurvedAnimation(parent: _enter, curve: Interval(from, (from + 0.45).clamp(0, 1), curve: Curves.easeOutCubic));
    return FadeTransition(opacity: a, child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.08), end: Offset.zero).animate(a), child: child));
  }

  @override
  Widget build(BuildContext context) {
    final tall = MediaQuery.sizeOf(context).height >= 700;
    return Scaffold(
      backgroundColor: _cream,
      body: Stack(children: [
        const Positioned.fill(child: _Backdrop()),
        const Positioned(top: 0, left: 0, right: 0, child: _TricolourBar()),
        SafeArea(child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.autoContinue ? _go : null,
          child: Column(children: [
            Expanded(child: Center(child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: Sp.lg, vertical: Sp.lg),
              child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: Column(children: [
                _fadeIn(0.0, _HeroVisual(spin: _spin, size: tall ? 260 : 200)),
                const SizedBox(height: Sp.md),
                _fadeIn(0.15, Column(children: [
                  Text('हिन्दी मित्र', textAlign: TextAlign.center, style: Fonts.hindi(48, color: _navy, height: 1.3)),
                  Text('HindiMitra', style: Fonts.display(20, color: _navy.withOpacity(0.7)).copyWith(letterSpacing: 1.5)),
                ])),
                const SizedBox(height: Sp.lg),
                _fadeIn(0.3, const _MadeInIndia()),
              ])),
            ))),
            _fadeIn(0.45, Padding(
              padding: const EdgeInsets.fromLTRB(Sp.lg, 0, Sp.lg, Sp.md),
              child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ToyButton(label: 'शुरू करें · Get started', fullWidth: true, size: ToySize.lg, onPressed: _go,
                      trailing: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20)),
                  if (widget.autoContinue) ...[
                    const SizedBox(height: Sp.sm),
                    AnimatedBuilder(animation: _auto, builder: (_, __) => ClipRRect(
                      borderRadius: BorderRadius.circular(9999),
                      child: LinearProgressIndicator(value: _auto.value, minHeight: 4,
                          color: _green, backgroundColor: _green.withOpacity(0.15)),
                    )),
                  ],
                  const SizedBox(height: Sp.lg),
                  const _DevelopedBy(),
                ],
              )),
            )),
          ]),
        )),
      ]),
    );
  }
}

// ─── Pieces ────────────────────────────────────────────────────────────────

class _Backdrop extends StatelessWidget {
  const _Backdrop();
  @override
  Widget build(BuildContext context) => Stack(children: [
        Positioned(top: -160, left: -140, child: _glow(_saffron, 460, 0.20)),
        Positioned(bottom: -180, right: -160, child: _glow(_green, 480, 0.14)),
        Positioned(top: 220, right: -120, child: _glow(_navy, 300, 0.05)),
      ]);

  static Widget _glow(Color c, double s, double o) => Container(
        width: s, height: s,
        decoration: BoxDecoration(shape: BoxShape.circle,
            gradient: RadialGradient(colors: [c.withOpacity(o), c.withOpacity(0)])),
      );
}

class _TricolourBar extends StatelessWidget {
  const _TricolourBar();
  @override
  Widget build(BuildContext context) => const SizedBox(height: 5, width: double.infinity, child: DecoratedBox(
        decoration: BoxDecoration(gradient: LinearGradient(
          colors: [_saffron, _saffron, Colors.white, Colors.white, _green, _green],
          stops: [0, 1 / 3, 1 / 3, 2 / 3, 2 / 3, 1],
        )),
      ));
}

/// "Made in India" badge: a drawn flag, the English line and the Hindi line.
class _MadeInIndia extends StatelessWidget {
  const _MadeInIndia();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 20, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(9999),
          border: Border.all(color: _saffron.withOpacity(0.35)),
          boxShadow: [BoxShadow(color: _saffron.withOpacity(0.16), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(width: 30, height: 20, child: CustomPaint(painter: _FlagPainter())),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('Made in India', style: Fonts.display(17, color: _navy, height: 1.1)),
            Text('भारत में बना', style: Fonts.hindi(13, color: _muted, height: 1.3)),
          ]),
        ]),
      );
}

class _DevelopedBy extends StatelessWidget {
  const _DevelopedBy();
  @override
  Widget build(BuildContext context) => Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 24, height: 1, color: _line),
        const SizedBox(width: 10),
        Flexible(child: Text.rich(TextSpan(children: [
          TextSpan(text: 'Developed by ', style: Fonts.body(13, w: FontWeight.w600, color: _muted)),
          TextSpan(text: 'VoxCRE', style: Fonts.display(15, color: _navy).copyWith(letterSpacing: 0.6)),
        ]), textAlign: TextAlign.center)),
        const SizedBox(width: 10),
        Container(width: 24, height: 1, color: _line),
      ]);
}

class _HeroVisual extends StatelessWidget {
  final Animation<double> spin;
  final double size;
  const _HeroVisual({required this.spin, required this.size});

  @override
  Widget build(BuildContext context) {
    final chakra = size * 0.46;
    final chip = size * 0.19;
    final orbitR = size * 0.39;
    return SizedBox(width: size, height: size, child: AnimatedBuilder(
      animation: spin,
      builder: (_, __) {
        final t = spin.value * 2 * math.pi;
        return Stack(clipBehavior: Clip.none, children: [
          Positioned.fill(child: CustomPaint(painter: _HaloPainter())),
          Center(child: Transform.rotate(angle: t, child: SizedBox(width: chakra, height: chakra,
              child: const CustomPaint(painter: _ChakraPainter(ring: true))))),
          for (var i = 0; i < _orbit.length; i++)
            Builder(builder: (_) {
              final (glyph, deg, color) = _orbit[i];
              final a = deg * math.pi / 180;
              final bob = math.sin(t * 3 + i * 1.7) * size * 0.015;
              final cx = size / 2 + math.cos(a) * orbitR - chip / 2;
              final cy = size / 2 + math.sin(a) * orbitR - chip / 2 + bob;
              return Positioned(left: cx, top: cy, child: _LetterChip(glyph: glyph, color: color, size: chip));
            }),
        ]);
      },
    ));
  }
}

class _LetterChip extends StatelessWidget {
  final String glyph;
  final Color color;
  final double size;
  const _LetterChip({required this.glyph, required this.color, required this.size});
  @override
  Widget build(BuildContext context) => Container(
        width: size, height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(size * 0.32),
          border: Border.all(color: color.withOpacity(0.22), width: 1.5),
          boxShadow: [BoxShadow(color: color.withOpacity(0.18), blurRadius: 18, offset: const Offset(0, 8))],
        ),
        child: Text(glyph, style: Fonts.hindi(size * 0.5, color: color, height: 1.1)),
      );
}

// ─── Painters ──────────────────────────────────────────────────────────────

class _ChakraPainter extends CustomPainter {
  final bool ring;
  const _ChakraPainter({required this.ring});
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    if (ring) {
      canvas.drawCircle(c, r, Paint()..color = Colors.white);
      canvas.drawCircle(c, r, Paint()..color = _navy.withOpacity(0.08)..style = PaintingStyle.stroke..strokeWidth = 2);
    }
    drawChakra(canvas, c, ring ? r - r * 0.12 : r - 1.5, _navy);
  }

  @override
  bool shouldRepaint(covariant _ChakraPainter old) => old.ring != ring;
}

/// Soft concentric rings behind the chakra: saffron glow fading out, with a
/// dashed orbit the letters sit on.
class _HaloPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    canvas.drawCircle(c, r * 0.62, Paint()..shader = RadialGradient(
        colors: [_saffron.withOpacity(0.22), _saffron.withOpacity(0)]).createShader(Rect.fromCircle(center: c, radius: r * 0.62)));
    canvas.drawCircle(c, r * 0.56, Paint()..color = Colors.white.withOpacity(0.7));
    final dash = Paint()..color = _navy.withOpacity(0.14)..strokeWidth = 1.4..style = PaintingStyle.stroke;
    const n = 64;
    final orbit = r * 0.78;
    for (var i = 0; i < n; i += 2) {
      final a0 = i * 2 * math.pi / n, a1 = (i + 1) * 2 * math.pi / n;
      canvas.drawArc(Rect.fromCircle(center: c, radius: orbit), a0, a1 - a0, false, dash);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// A small Indian flag, drawn rather than an emoji so it renders everywhere.
class _FlagPainter extends CustomPainter {
  const _FlagPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height / 3;
    final clip = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(2.5));
    canvas.save();
    canvas.clipRRect(clip);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, h), Paint()..color = _saffron);
    canvas.drawRect(Rect.fromLTWH(0, h, size.width, h), Paint()..color = Colors.white);
    canvas.drawRect(Rect.fromLTWH(0, h * 2, size.width, h), Paint()..color = _green);
    canvas.restore();
    canvas.drawRRect(clip, Paint()..color = Colors.black.withOpacity(0.08)..style = PaintingStyle.stroke..strokeWidth = 0.8);
    canvas.drawCircle(size.center(Offset.zero), h * 0.42, Paint()..color = _navy..style = PaintingStyle.stroke..strokeWidth = 0.9);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
