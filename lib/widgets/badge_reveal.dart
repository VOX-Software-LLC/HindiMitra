import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/palette.dart';
import 'icons.dart';
import '../util/num_ext.dart';

class BadgeInfo {
  final String id, name, hindiName, description, icon;
  final Color color;
  const BadgeInfo(this.id, this.name, this.hindiName, this.description, this.icon, this.color);
}

/// BadgeReveal.tsx — full-screen overlay with pop-in badge, glow pulse, text slide, delayed button.
class BadgeReveal extends StatefulWidget {
  final BadgeInfo? badge; final bool visible; final VoidCallback onDismiss;
  const BadgeReveal({super.key, required this.badge, required this.visible, required this.onDismiss});
  @override
  State<BadgeReveal> createState() => _BadgeRevealState();
}

class _BadgeRevealState extends State<BadgeReveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2900));

  @override
  void initState() { super.initState(); if (widget.visible && widget.badge != null) _c.forward(); }

  @override
  void didUpdateWidget(BadgeReveal old) {
    super.didUpdateWidget(old);
    if (widget.visible && widget.badge != null) {
      if (!(old.visible && old.badge != null)) _c.forward(from: 0);
    } else {
      _c.value = 0;
    }
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  double _seg(double startMs, double durMs, [Curve curve = Curves.linear]) {
    final t = ((_c.value * 2900 - startMs) / durMs).clampD(0.0, 1.0);
    return curve.transform(t);
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.badge;
    if (!widget.visible || b == null) return const SizedBox.shrink();
    return AnimatedBuilder(animation: _c, builder: (context, _) {
      final overlay = _seg(0, 300);
      final pop = _seg(200, 700, Curves.elasticOut);
      final rot = (-15 * (1 - _seg(200, 600, Curves.easeOutBack))) * 3.14159 / 180;
      final ms = _c.value * 2900;
      // glow: 0.6 → 0.2 → 0.4 → 0.2 over 400/600/600/600 starting at 400ms
      double glowO = 0, glowS = 0.5;
      if (ms >= 400) {
        final g = ms - 400;
        if (g < 400) { final t = g / 400; glowO = 0.6 * t; glowS = 0.5 + (1.4 - 0.5) * Curves.easeOutQuad.transform(t); }
        else if (g < 1000) { final t = (g - 400) / 600; glowO = 0.6 + (0.2 - 0.6) * t; glowS = 1.4 + (1.2 - 1.4) * t; }
        else if (g < 1600) { final t = (g - 1000) / 600; glowO = 0.2 + (0.4 - 0.2) * t; glowS = 1.2 + (1.5 - 1.2) * t; }
        else if (g < 2200) { final t = (g - 1600) / 600; glowO = 0.4 + (0.2 - 0.4) * t; glowS = 1.5 + (1.2 - 1.5) * t; }
        else { glowO = 0.2; glowS = 1.2; }
      }
      final text = _seg(600, 400);
      final textY = 20 * (1 - _seg(600, 500, Curves.easeOutBack));
      final btn = _seg(1000, 300);
      return Positioned.fill(child: Opacity(opacity: overlay, child: Container(
        color: const Color(0xB3000000), padding: const EdgeInsets.all(Sp.xl), alignment: Alignment.center,
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 320), child: Column(mainAxisSize: MainAxisSize.min, children: [
          Opacity(opacity: text, child: Transform.translate(offset: Offset(0, textY), child: Column(children: [
            Text('Badge Unlocked!', textAlign: TextAlign.center, style: Fonts.display(24, color: AppColors.starGold)),
            const SizedBox(height: 2),
            Opacity(opacity: 0.8, child: Text('बैज अनलॉक!', textAlign: TextAlign.center, style: Fonts.body(16, color: AppColors.starGold))),
            const SizedBox(height: Sp.xl),
          ]))),
          SizedBox(width: 140, height: 140, child: Stack(alignment: Alignment.center, children: [
            Opacity(opacity: glowO, child: Transform.scale(scale: glowS, child: Container(width: 140, height: 140,
                decoration: BoxDecoration(color: b.color, shape: BoxShape.circle)))),
            Transform.rotate(angle: rot, child: Transform.scale(scale: pop, child: Container(
              width: 120, height: 120, alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.surface, shape: BoxShape.circle, border: Border.all(color: b.color, width: 4),
                  boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 16, offset: Offset(0, 8))]),
              child: Container(width: 100, height: 100, decoration: BoxDecoration(color: b.color.withAlpha(0x20), shape: BoxShape.circle),
                  child: Icon(ionIcon(b.icon), size: 56, color: b.color)),
            ))),
          ])),
          const SizedBox(height: Sp.xl),
          Opacity(opacity: text, child: Transform.translate(offset: Offset(0, textY), child: Column(children: [
            Text(b.name, textAlign: TextAlign.center, style: Fonts.display(20, color: Colors.white)),
            Opacity(opacity: 0.8, child: Text(b.hindiName, style: Fonts.hindi(16, color: Colors.white))),
            const SizedBox(height: Sp.sm),
            Opacity(opacity: 0.7, child: Text(b.description, textAlign: TextAlign.center, style: Fonts.body(14, color: Colors.white, height: 20 / 14))),
            const SizedBox(height: Sp.xl),
          ]))),
          Opacity(opacity: btn, child: IgnorePointer(ignoring: btn < 0.01, child: GestureDetector(
            onTap: widget.onDismiss,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: Sp.md, horizontal: Sp.xxl),
              decoration: BoxDecoration(color: b.color, borderRadius: BorderRadius.circular(9999)),
              child: Text('Awesome!', style: Fonts.body(18, w: FontWeight.w700, color: Colors.white)),
            ),
          ))),
        ])),
      )));
    });
  }
}
