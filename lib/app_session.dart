import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'store/app_store.dart';

/// Who is using the app right now. Every launch starts on the "Who's using
/// HindiMitra?" screen; picking a learner opens their app, and "Switch
/// user" brings the chooser back.
class AppSession {
  /// True while a learner's app is open; false shows the chooser.
  static final inLearnerApp = ValueNotifier<bool>(false);

  /// Opens the app for learner [id] (closing anything open above it).
  static void enterLearner(BuildContext context, String id) {
    final s = context.read<AppStore>();
    Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
    s.switchStudent(id);
    inLearnerApp.value = true;
  }

  /// Back to the chooser.
  static void chooseAgain(BuildContext context) {
    Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
    inLearnerApp.value = false;
  }
}
