import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../store/app_store.dart';

/// Provides the [AppStore] to a tab of a tab bar, passing its change notices
/// on only while the tab is shown. Hidden tabs would otherwise rebuild on
/// every change (a star, a saved practice) though nobody sees them. A hidden
/// tab that missed a change is brought up to date as soon as it is shown.
class QuietWhenHidden extends StatefulWidget {
  final bool active;
  final Widget child;
  const QuietWhenHidden({super.key, required this.active, required this.child});
  @override
  State<QuietWhenHidden> createState() => _QuietWhenHiddenState();
}

class _QuietWhenHiddenState extends State<QuietWhenHidden> {
  InheritedContext<AppStore?>? _element;
  bool _missed = false;

  @override
  void didUpdateWidget(QuietWhenHidden oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && _missed) {
      _missed = false;
      _element?.markNeedsNotifyDependents();
    }
  }

  @override
  Widget build(BuildContext context) => InheritedProvider<AppStore>.value(
        value: context.read<AppStore>(),
        startListening: (e, store) {
          _element = e;
          void changed() {
            if (widget.active) {
              e.markNeedsNotifyDependents();
            } else {
              _missed = true;
            }
          }
          store.addListener(changed);
          return () => store.removeListener(changed);
        },
        child: widget.child,
      );
}
