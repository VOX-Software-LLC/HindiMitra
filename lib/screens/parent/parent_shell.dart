import 'package:flutter/material.dart';
import '../../widgets/quiet_when_hidden.dart';
import 'package:provider/provider.dart';
import '../../l10n.dart';
import '../../store/app_store.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import 'assignments_tab.dart';
import 'children_tab.dart';
import 'dashboard_tab.dart';
import 'hub_widgets.dart';
import 'parent_settings_tab.dart';
import 'reports_tab.dart';

/// The Parent Hub (opened after the parent's PIN): its own tab bar of Home,
/// Children, Assignments, Reports and Settings, above the child's app.
class ParentShell extends StatefulWidget {
  final Map<String, dynamic> params;
  const ParentShell({super.key, this.params = const {}});
  static ParentShellState? of(BuildContext c) => c.findAncestorStateOfType<ParentShellState>();
  @override
  State<ParentShell> createState() => ParentShellState();
}

class ParentShellState extends State<ParentShell> {
  int index = 0;
  /// Tabs opened so far: each is built on first visit, then kept.
  final _visited = <int>{0};
  late final String parentId;
  late final ValueNotifier<String> selected;

  @override
  void initState() {
    super.initState();
    parentId = (widget.params['parentId'] as String?) ??
        (context.read<AppStore>().parents.where((p) => !p.contactOnly).firstOrNull?.id ?? '');
    selected = ValueNotifier(_firstChild());
  }

  String _firstChild() {
    final s = context.read<AppStore>();
    final kids = hubChildren(s, parentId);
    return kids.any((k) => k.id == s.activeStudentId) ? s.activeStudentId : kids.firstOrNull?.id ?? '';
  }

  void goTo(int i) => setState(() { index = i; _visited.add(i); });

  static List<(String, IconData, IconData)> get _items => [
        (tr('Home', 'होम'), Icons.space_dashboard_outlined, Icons.space_dashboard_rounded),
        (tr('Children', 'बच्चे'), Icons.people_outline_rounded, Icons.people_rounded),
        (tr('Assignments', 'काम'), Icons.assignment_outlined, Icons.assignment_rounded),
        (tr('Reports', 'रिपोर्ट'), Icons.insights_outlined, Icons.insights_rounded),
        (tr('Settings', 'सेटिंग्स'), Icons.settings_outlined, Icons.settings_rounded),
      ];

  @override
  void dispose() {
    selected.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.select<AppStore, bool>((s) => s.parentById(parentId) != null);
    if (!p) return const Scaffold(body: SizedBox.shrink());
    final wide = MediaQuery.of(context).size.width >= 1024;
    const tabs = [DashboardTab(), ChildrenTab(), AssignmentsTab(), ReportsTab(), ParentSettingsTab()];
    // A tab is built when first opened and kept (switching back is instant,
    // scroll position and filters stay). Hidden tabs ignore store changes
    // until they are shown again, so a change rebuilds only the open tab.
    final body = IndexedStack(index: index, children: [
      for (int i = 0; i < tabs.length; i++)
        _visited.contains(i)
            ? QuietWhenHidden(active: index == i, child: TickerMode(enabled: index == i, child: tabs[i]))
            : const SizedBox.shrink(),
    ]);
    return ParentHubScope(
      parentId: parentId, selected: selected,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: wide ? Column(children: [_TopNav(index: index, onTap: goTo), Expanded(child: body)]) : body,
        bottomNavigationBar: wide ? null : _BottomNav(index: index, onTap: goTo),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.index, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final items = ParentShellState._items;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(Rad.lg)),
        boxShadow: [BoxShadow(color: AppColors.toyShadowColor.withOpacity(0.12), offset: const Offset(0, -4), blurRadius: 18)],
      ),
      child: SafeArea(top: false, child: SizedBox(height: 68, child: Row(children: [
        for (int i = 0; i < items.length; i++) Expanded(child: Semantics(
          button: true, selected: index == i, label: items[i].$1,
          child: MouseRegion(cursor: SystemMouseCursors.click, child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onTap(i),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 240), curve: Curves.easeOutCubic,
                padding: EdgeInsets.symmetric(horizontal: index == i ? 18 : 10, vertical: 4),
                decoration: BoxDecoration(
                  color: index == i ? AppColors.primary.withOpacity(0.16) : Colors.transparent,
                  borderRadius: BorderRadius.circular(9999)),
                child: Icon(index == i ? items[i].$3 : items[i].$2, size: 24,
                    color: index == i ? AppColors.primaryDark : AppColors.textSecondary),
              ),
              const SizedBox(height: 3),
              Text(items[i].$1, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: Fonts.body(11, w: index == i ? FontWeight.w800 : FontWeight.w600,
                      color: index == i ? AppColors.primaryDark : AppColors.textSecondary)),
            ]),
          )),
        )),
      ]))),
    );
  }
}

class _TopNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const _TopNav({required this.index, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final items = ParentShellState._items;
    return Container(
      decoration: BoxDecoration(color: AppColors.surface, border: Border(bottom: BorderSide(color: AppColors.border))),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: Sp.lg),
      child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1240),
        child: Row(children: [
          Container(width: 40, height: 40, alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.success, borderRadius: BorderRadius.circular(14),
                  boxShadow: toyShadow(shade(AppColors.success), 3)),
              child: const Icon(Icons.shield_rounded, color: Colors.white, size: 22)),
          const SizedBox(width: 10),
          Text(tr('Parent Hub', 'अभिभावक केंद्र'), style: Fonts.display(22)),
          const Spacer(),
          for (int i = 0; i < items.length; i++) Padding(
            padding: const EdgeInsets.only(left: 6),
            child: MouseRegion(cursor: SystemMouseCursors.click, child: GestureDetector(
              onTap: () => onTap(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  gradient: index == i ? toneGradient(AppColors.primary) : null,
                  boxShadow: index == i ? toyShadow(AppColors.primaryDark, 3) : null,
                  borderRadius: BorderRadius.circular(9999)),
                child: Row(children: [
                  Icon(index == i ? items[i].$3 : items[i].$2, size: 18,
                      color: index == i ? AppColors.textOnPrimary : AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(items[i].$1, style: Fonts.body(14, w: FontWeight.w800,
                      color: index == i ? AppColors.textOnPrimary : AppColors.textSecondary)),
                ]),
              ),
            )),
          ),
          const SizedBox(width: Sp.md),
          Tooltip(message: tr('Lock and return to the app', 'लॉक करके ऐप पर लौटें'), child: IconButton(
              onPressed: () => lockParentHub(context),
              icon: Icon(Icons.lock_rounded, color: AppColors.textSecondary))),
        ]),
      )),
    );
  }
}

/// Scrolling body of a hub tab, centred and width-limited.
class HubTabBody extends StatelessWidget {
  final List<Widget> children;
  const HubTabBody({super.key, required this.children});
  @override
  Widget build(BuildContext context) => SafeArea(bottom: false, child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Sp.md, Sp.md, Sp.md, Sp.xxl),
        child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 900),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children))),
      ));
}
