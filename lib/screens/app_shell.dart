import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/palette.dart';
import '../l10n.dart';
import '../widgets/quiet_when_hidden.dart';
import 'home_screen.dart';
import 'learn_screen.dart';
import 'practice_screen.dart';
import 'test_screen.dart';
import 'upcoming_screen.dart';

/// Tabs: Home · Learn (Write + Read) · Practice · Test · Upcoming. Profile and
/// Rewards open from the Home header. Bottom tabs on mobile, top pill nav on desktop (>=1024px).
/// Each tab owns its own Navigator so back-stacks persist like RN stack-in-tab.
class AppShell extends StatefulWidget {
  const AppShell({super.key});
  static AppShellState? of(BuildContext c) => c.findAncestorStateOfType<AppShellState>();
  @override
  State<AppShell> createState() => AppShellState();
}

class AppShellState extends State<AppShell> {
  int index = 0;
  /// Tabs opened so far: each is built on first visit, then kept.
  final _visited = <int>{0};
  void goTo(int i) {
    if (i == index) {
      // tapping the active tab pops to its root (like RN tab behaviour)
      _keys[i].currentState?.popUntil((r) => r.isFirst);
    }
    setState(() { index = i; _visited.add(i); });
  }

  /// Opens the Learn tab on Write (0) or Read (1).
  void goLearn(int segment) {
    LearnScreen.segment.value = segment;
    goTo(1);
  }

  static List<(String, IconData, IconData)> get _items => [
    (tr('Home', 'होम'), Icons.home_outlined, Icons.home_rounded),
    (tr('Learn', 'सीखो'), Icons.school_outlined, Icons.school_rounded),
    (tr('Practice', 'अभ्यास'), Icons.fitness_center_outlined, Icons.fitness_center_rounded),
    (tr('Test', 'परीक्षा'), Icons.quiz_outlined, Icons.quiz_rounded),
    (tr('Upcoming', 'जल्द'), Icons.rocket_launch_outlined, Icons.rocket_launch_rounded),
  ];

  final _keys = List.generate(5, (_) => GlobalKey<NavigatorState>());

  // Hidden tabs keep their screens (and back stacks) but ignore store
  // changes until they are shown again, so a change rebuilds only the open tab.
  Widget _tab(int i, Widget root) => !_visited.contains(i) ? const SizedBox.shrink() : Offstage(
        offstage: index != i,
        child: TickerMode(
          enabled: index == i,
          child: QuietWhenHidden(
            active: index == i,
            child: Navigator(
              key: _keys[i],
              onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => root),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 1024;
    final body = Stack(children: [
      _tab(0, const HomeScreen()),
      _tab(1, const LearnScreen()),
      _tab(2, const PracticeScreen()),
      _tab(3, const TestScreen()),
      _tab(4, const UpcomingScreen()),
    ]);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final nav = _keys[index].currentState;
        if (nav != null && nav.canPop()) {
          nav.pop();
        } else if (index != 0) {
          setState(() => index = 0);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: wide
            ? Column(children: [
                _TopNav(index: index, onTap: goTo),
                Expanded(child: Center(child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1240), child: body))),
              ])
            : body,
        bottomNavigationBar: wide
            ? null
            : Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(Rad.lg)),
                  boxShadow: [BoxShadow(color: AppColors.toyShadowColor.withOpacity(0.12), offset: const Offset(0, -4), blurRadius: 18)],
                ),
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    height: 68,
                    child: Row(children: [
                      for (int i = 0; i < _items.length; i++)
                        Expanded(child: MouseRegion(cursor: SystemMouseCursors.click, child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => goTo(i),
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            // The active tab sits on a soft orange pill that grows in.
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 240), curve: Curves.easeOutCubic,
                              padding: EdgeInsets.symmetric(horizontal: index == i ? 18 : 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: index == i ? AppColors.primary.withOpacity(0.16) : Colors.transparent,
                                borderRadius: BorderRadius.circular(9999)),
                              child: Icon(index == i ? _items[i].$3 : _items[i].$2, size: 24,
                                  color: index == i ? AppColors.primaryDark : AppColors.textSecondary),
                            ),
                            const SizedBox(height: 3),
                            Text(_items[i].$1, style: Fonts.body(11, w: index == i ? FontWeight.w800 : FontWeight.w600,
                                color: index == i ? AppColors.primaryDark : AppColors.textSecondary)),
                          ]),
                        ))),
                    ]),
                  ),
                ),
              ),
      ),
    );
  }
}

class _TopNav extends StatefulWidget {
  final int index; final ValueChanged<int> onTap;
  const _TopNav({required this.index, required this.onTap});
  @override
  State<_TopNav> createState() => _TopNavState();
}

class _TopNavState extends State<_TopNav> {
  int? _hover;
  @override
  Widget build(BuildContext context) {
    final index = widget.index, onTap = widget.onTap;
    return Container(
      decoration: BoxDecoration(color: AppColors.surface, border: Border(bottom: BorderSide(color: AppColors.border))),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: Sp.lg),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1240),
          child: Row(children: [
            Container(
              width: 40, height: 40, alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(14),
                  boxShadow: toyShadow(AppColors.primaryDark, 3)),
              child: const Text('🦜', style: TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 10),
            Text('HindiMitra', style: Fonts.display(22)),
            const Spacer(),
            for (int i = 0; i < AppShellState._items.length; i++)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onEnter: (_) => setState(() => _hover = i),
                  onExit: (_) => setState(() => _hover = null),
                  child: GestureDetector(
                    onTap: () => onTap(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                      decoration: BoxDecoration(
                        gradient: index == i ? toneGradient(AppColors.primary) : null,
                        color: index != i && _hover == i ? AppColors.primary.withOpacity(0.12) : null,
                        boxShadow: index == i ? toyShadow(AppColors.primaryDark, 3) : null,
                        borderRadius: BorderRadius.circular(9999)),
                      child: Row(children: [
                        Icon(index == i ? AppShellState._items[i].$3 : AppShellState._items[i].$2, size: 18,
                            color: index == i ? AppColors.textOnPrimary
                                : _hover == i ? AppColors.primaryDark : AppColors.textSecondary),
                        const SizedBox(width: 6),
                        Text(AppShellState._items[i].$1, style: Fonts.body(14, w: FontWeight.w800,
                            color: index == i ? AppColors.textOnPrimary
                                : _hover == i ? AppColors.primaryDark : AppColors.textSecondary)),
                      ]),
                    ),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
