import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hindi_mitra/data/models.dart';
import 'package:hindi_mitra/routes.dart';
import 'package:hindi_mitra/screens/home_screen.dart';
import 'package:hindi_mitra/screens/onboarding_screen.dart';
import 'package:hindi_mitra/screens/profile_screen.dart';
import 'package:hindi_mitra/screens/reading/reading_menu_screen.dart';
import 'package:hindi_mitra/screens/rewards_screen.dart';
import 'package:hindi_mitra/screens/writing/writing_menu_screen.dart';
import 'package:hindi_mitra/store/app_store.dart';
import 'package:hindi_mitra/theme/app_theme.dart';

/// Opens every screen on small phones (with a slightly enlarged system font)
/// and fails if any widget overflows its box.
void main() {
  late AppStore store;
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await AppData.load();
    store = await AppStore.load();
    await Fonts.preload();
  });

  final screens = <String, Widget Function()>{
    'Onboarding': () => const OnboardingScreen(),
    'Home': () => const HomeScreen(),
    'WriteMenu': () => const WritingMenuScreen(),
    'ReadMenu': () => const ReadingMenuScreen(),
    'Rewards': () => const RewardsScreen(),
    'Profile': () => const ProfileScreen(),
    for (final e in screenRegistry.entries)
      e.key: () => e.value({'letterId': AppData.allLetters.first.id, 'levelNumber': 1}),
  };
  const sizes = [Size(320, 568), Size(360, 690), Size(412, 915)];

  for (final size in sizes) {
    for (final e in screens.entries) {
      testWidgets('${e.key} fits at ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final overflows = <String>[];
        final prev = FlutterError.onError;
        FlutterError.onError = (d) {
          final msg = d.exceptionAsString();
          if (!msg.contains('overflowed')) return;          // Point at the widget in lib/ that overflowed.
          final where = (d.informationCollector?.call() ?? const [])
              .map((e) => e.toString()).firstWhere((s) => s.contains('lib/'), orElse: () => '');
          overflows.add('${msg.split('\n').first} ${RegExp(r'lib/\S+').stringMatch(where) ?? ''}');
        };
        await tester.pumpWidget(ChangeNotifierProvider.value(
          value: store,
          child: MaterialApp(
            builder: (c, child) => MediaQuery(
                data: MediaQuery.of(c).copyWith(textScaler: const TextScaler.linear(1.2)), child: child!),
            home: Scaffold(body: e.value()),
          ),
        ));
        await tester.pump(const Duration(milliseconds: 600));
        FlutterError.onError = prev;
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 5));
        expect(overflows, isEmpty);
      });
    }
  }
}
