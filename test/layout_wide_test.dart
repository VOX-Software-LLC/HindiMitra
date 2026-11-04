import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hindi_mitra/data/models.dart';
import 'package:hindi_mitra/screens/home_screen.dart';
import 'package:hindi_mitra/screens/intro_screen.dart';
import 'package:hindi_mitra/screens/learn_screen.dart';
import 'package:hindi_mitra/screens/practice_screen.dart';
import 'package:hindi_mitra/screens/test_screen.dart';
import 'package:hindi_mitra/screens/translation_screen.dart';
import 'package:hindi_mitra/screens/upcoming_screen.dart';
import 'package:hindi_mitra/screens/profile_screen.dart';
import 'package:hindi_mitra/screens/reading/reading_menu_screen.dart';
import 'package:hindi_mitra/screens/rewards_screen.dart';
import 'package:hindi_mitra/screens/writing/writing_menu_screen.dart';
import 'package:hindi_mitra/routes.dart';
import 'package:hindi_mitra/store/app_store.dart';
import 'package:hindi_mitra/theme/app_theme.dart';

/// Opens every screen at tablet and desktop widths and fails on any layout
/// error (the phone sizes are covered by layout_overflow_test.dart).
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
    'Home': () => const HomeScreen(),
    'Intro': () => IntroScreen(onContinue: () {}),
    'Learn': () => const LearnScreen(),
    'Practice': () => const PracticeScreen(),
    'Test': () => const TestScreen(),
    'Upcoming': () => const UpcomingScreen(),
    'Translation': () => const TranslationScreen(),
    'WriteMenu': () => const WritingMenuScreen(),
    'ReadMenu': () => const ReadingMenuScreen(),
    'Rewards': () => const RewardsScreen(),
    'Profile': () => const ProfileScreen(),
    for (final e in screenRegistry.entries)
      e.key: () => e.value({'letterId': AppData.allLetters.first.id, 'levelNumber': 1}),
  };
  for (final size in const [Size(800, 900), Size(1280, 900)]) {
    for (final e in screens.entries) {
      testWidgets('${e.key} lays out at ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final errs = <String>[];
        final prev = FlutterError.onError;
        FlutterError.onError = (d) => errs.add(
            '${d.exceptionAsString().split('\n').first} @ ${RegExp(r'lib/\S+').stringMatch(d.toString()) ?? ''}');
        await tester.pumpWidget(ChangeNotifierProvider.value(value: store,
            child: MaterialApp(home: Scaffold(body: e.value()))));
        await tester.pump(const Duration(milliseconds: 600));
        FlutterError.onError = prev;
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 5));
        expect(errs, isEmpty);
      });
    }
  }
}
