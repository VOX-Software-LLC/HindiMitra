import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hindi_mitra/data/models.dart';
import 'package:hindi_mitra/screens/app_shell.dart';
import 'package:hindi_mitra/store/app_store.dart';
import 'package:hindi_mitra/theme/app_theme.dart';

/// Hidden tabs skip updates while hidden but show the latest data again as
/// soon as they are opened.
void main() {
  late AppStore store;
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await AppData.load();
    store = await AppStore.load();
    await Fonts.preload();
    store.completeOnboarding('Aarav', 'kid-7-10', 'student');
  });

  testWidgets('a hidden tab catches up when shown', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ChangeNotifierProvider.value(value: store, child: const MaterialApp(home: AppShell())));
    await tester.pump(const Duration(milliseconds: 500));
    final stars = store.totalStars;
    expect(find.text('$stars'), findsWidgets);

    final shell = tester.state<AppShellState>(find.byType(AppShell));
    shell.goTo(2);
    await tester.pump(const Duration(milliseconds: 500));
    store.addStars(7);
    await tester.pump();
    // Home is hidden: it has not rebuilt yet.
    expect(find.text('${stars + 7}', skipOffstage: false), findsNothing);

    shell.goTo(0);
    await tester.pump();
    expect(find.text('${stars + 7}'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
}
