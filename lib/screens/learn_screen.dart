import 'package:flutter/material.dart';
import '../l10n.dart';
import '../theme/app_theme.dart';
import '../theme/palette.dart';
import 'reading/reading_menu_screen.dart';
import 'writing/writing_menu_screen.dart';

/// Learn tab: the Write and Read courses side by side behind a toggle.
class LearnScreen extends StatefulWidget {
  const LearnScreen({super.key});

  /// 0 = Write, 1 = Read. Set before switching to the tab to open a course.
  static final segment = ValueNotifier<int>(0);

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ValueListenableBuilder<int>(
          valueListenable: LearnScreen.segment,
          builder: (_, seg, __) => Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Sp.md, Sp.md, Sp.md, 0),
              child: Center(child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(9999),
                      border: Border.all(color: AppColors.border), boxShadow: toyShadow(AppColors.toyShadowColor, 3)),
                  child: Row(children: [
                    _seg(0, seg, '✍️', tr('Write', 'लिखो')),
                    _seg(1, seg, '📖', tr('Read', 'पढ़ो')),
                  ]),
                ),
              )),
            ),
            Expanded(child: IndexedStack(index: seg, children: const [WritingMenuScreen(), ReadingMenuScreen()])),
          ]),
        ),
      ),
    );
  }

  Widget _seg(int i, int seg, String emoji, String label) {
    final on = i == seg;
    final c = i == 0 ? AppColors.primary : AppColors.readingModule;
    return Expanded(child: MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => LearnScreen.segment.value = i,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220), curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(gradient: on ? toneGradient(c) : null, borderRadius: BorderRadius.circular(9999),
              boxShadow: on ? toyShadow(shade(c), 3) : null),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(label, style: Fonts.body(15, w: FontWeight.w800, color: on ? Colors.white : AppColors.textSecondary)),
          ]),
        ),
      ),
    ));
  }
}
