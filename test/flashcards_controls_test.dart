import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hindi_mitra/data/models.dart';
import 'package:hindi_mitra/screens/reading/flashcards_screen.dart';
import 'package:hindi_mitra/store/app_store.dart';
import 'package:hindi_mitra/theme/app_theme.dart';

/// The flashcard buttons are named and always work: Back on the first card
/// goes to the last, Next on the last starts over.
void main() {
  late AppStore store;
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await AppData.load();
    store = await AppStore.load();
    await Fonts.preload();
  });

  testWidgets('labelled buttons that wrap around', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ChangeNotifierProvider.value(value: store,
        child: const MaterialApp(home: FlashcardsScreen())));
    await tester.pump(const Duration(milliseconds: 500));
    final total = AppData.allLetters.length;
    for (final l in ['Back', 'Listen', 'Next']) {
      expect(find.text(l), findsOneWidget, reason: l);
    }
    Finder at(int n) => find.text('$n / $total', findRichText: true);
    expect(at(1), findsOneWidget);

    // Back on the first card: the last card.
    await tester.tap(find.text('Back'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(at(total), findsOneWidget);
    expect(find.text('Start over'), findsOneWidget);

    // Next on the last card: the first again.
    await tester.tap(find.text('Start over'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(at(1), findsOneWidget);

    // Everything to remember is on the card itself: letter, sound and example.
    final first = AppData.allLetters.first;
    for (final t in [first.romanized, first.exampleWord, first.exampleMeaning]) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });

  // The four levels (All, स्वर, व्यंजन, विशेष) open their own deck, on a small phone too.
  for (final (pool, count) in const [('all', 49), ('vowels', 13), ('consonants', 33), ('special', 3)]) {
    testWidgets('level pool $pool has $count cards', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ChangeNotifierProvider.value(value: store,
          child: MaterialApp(home: FlashcardsScreen(params: {'pool': pool}))));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
      expect(find.text('1 / $count', findRichText: true), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    });
  }

  test('flashcards has exactly the four levels', () {
    final fc = AppData.readingActivities.firstWhere((a) => a.id == 'flashcards');
    expect([for (final l in fc.levels) l.params['pool']], ['all', 'vowels', 'consonants', 'special']);
  });
}
