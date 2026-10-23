import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/palette.dart';
import '../util/num_ext.dart';

class HsProgressBar extends StatelessWidget {
  final double progress, height;
  final bool showLabel;
  final Color color, background;
  const HsProgressBar({super.key, required this.progress, this.height = 14,
      this.showLabel = false, this.color = AppColors.success, this.background = AppColors.muted});
  @override
  Widget build(BuildContext context) {
    final p = progress.clampD(0.0, 1.0);
    return Row(children: [
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(height / 2),
          child: Container(
            height: height, color: background,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: p),
              duration: const Duration(milliseconds: 600), curve: Curves.easeOutCubic,
              builder: (_, v, __) => FractionallySizedBox(
                alignment: Alignment.centerLeft, widthFactor: v,
                child: Container(decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [Color.lerp(color, Colors.white, 0.25)!, color]),
                    borderRadius: BorderRadius.circular(height / 2)))),
            ),
          ),
        ),
      ),
      if (showLabel) SizedBox(width: 44, child: Text('${(p * 100).round()}%',
          textAlign: TextAlign.right, style: Fonts.body(12, color: AppColors.textSecondary, w: FontWeight.w500))),
    ]);
  }
}
