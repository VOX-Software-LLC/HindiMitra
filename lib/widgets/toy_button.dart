import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/palette.dart';

enum ToyVariant { primary, secondary, outline, ghost, success }
enum ToySize { sm, md, lg }

/// Tap target that sinks a little and shrinks slightly while pressed, then
/// springs back — the shared "press" feel of every button and tile.
class Pressable extends StatefulWidget {
  final Widget child; final VoidCallback? onTap; final double depth;
  const Pressable({super.key, required this.child, this.onTap, this.depth = 3});
  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  void _set(bool v) { if (widget.onTap != null && v != _down) setState(() => _down = v); }
  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? 0.97 : 1,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          child: AnimatedSlide(
            offset: Offset(0, _down ? widget.depth / 100 : 0),
            duration: const Duration(milliseconds: 110),
            child: widget.child,
          ),
        ),
      );
}

/// Port of ToyButton.tsx — gradient pill with a crisp 3D edge that presses down.
class ToyButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final ToyVariant variant;
  final ToySize size;
  final bool fullWidth;
  final Widget? leading, trailing;
  const ToyButton({super.key, required this.label, this.onPressed,
      this.variant = ToyVariant.primary, this.size = ToySize.md,
      this.fullWidth = false, this.leading, this.trailing});

  @override
  Widget build(BuildContext context) {
    final Color? fill = switch (variant) {
      ToyVariant.primary => AppColors.primary,
      ToyVariant.secondary => AppColors.secondary,
      ToyVariant.success => AppColors.success,
      _ => null,
    };
    final fg = fill != null ? AppColors.textOnPrimary : variant == ToyVariant.outline ? AppColors.primary : AppColors.textSecondary;
    final pv = {ToySize.sm: Sp.xs, ToySize.md: Sp.sm, ToySize.lg: Sp.md}[size]!;
    final ph = {ToySize.sm: Sp.md, ToySize.md: Sp.lg, ToySize.lg: Sp.xl}[size]!;
    final fs = {ToySize.sm: 14.0, ToySize.md: 16.0, ToySize.lg: 18.0}[size]!;
    final disabled = onPressed == null;
    return Opacity(
      opacity: disabled ? 0.45 : 1,
      child: Pressable(
        onTap: onPressed,
        child: Container(
          width: fullWidth ? double.infinity : null,
          padding: EdgeInsets.symmetric(vertical: pv + 6, horizontal: ph),
          decoration: BoxDecoration(
            gradient: fill != null ? toneGradient(fill) : null,
            color: fill == null && variant == ToyVariant.outline ? AppColors.surface : null,
            borderRadius: BorderRadius.circular(9999),
            border: variant == ToyVariant.outline ? Border.all(color: AppColors.primary, width: 2) : null,
            boxShadow: fill != null ? toyShadow(shade(fill), 5) : null,
          ),
          child: Row(
            mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 8)],
              Flexible(child: Text(label, textAlign: TextAlign.center,
                  style: Fonts.body(fs, color: fg, w: FontWeight.w800).copyWith(letterSpacing: 0.2))),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}
