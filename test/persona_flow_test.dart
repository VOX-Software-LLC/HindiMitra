import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hindi_mitra/app_session.dart';
import 'package:hindi_mitra/data/models.dart';
import 'package:hindi_mitra/screens/parent/parent_shell.dart';
import 'package:hindi_mitra/screens/persona_screen.dart';
import 'package:hindi_mitra/store/app_store.dart';
import 'package:hindi_mitra/theme/app_theme.dart';

/// The "Who's using?" screen: a parent gets into the Parent Hub only with
/// the right PIN, and a learner goes straight to their app.
void main() {
  late AppStore store;
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await AppData.load();
    store = await AppStore.load();
    await Fonts.preload();
    store.completeOnboarding('Aarav', 'kid-7-10', 'student');
    store.createParent(name: 'Sunita', pin: 'STAR58');
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ChangeNotifierProvider.value(value: store, child: const MaterialApp(home: PersonaScreen())));
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> enter(WidgetTester tester, String pin) async {
    for (final d in pin.split('')) {
      // The code keyboard shows letters or numbers (ABC / 123); the PIN pad only numbers.
      if (find.text('ABC').evaluate().isNotEmpty) {
        await tester.tap(find.text(RegExp(r'\d').hasMatch(d) ? '123' : 'ABC'));
        await tester.pump(const Duration(milliseconds: 300));
      }
      await tester.tap(find.text(d).last);
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('parent needs the right PIN', (tester) async {
    await pump(tester);
    expect(find.text("Who's using HindiMitra?"), findsOneWidget);
    await tester.ensureVisible(find.text('Sunita'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Sunita'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Enter your 6-character parent PIN'), findsOneWidget);

    await enter(tester, 'STAR59');
    expect(find.text('Wrong PIN, try again.'), findsOneWidget);
    expect(find.byType(ParentShell), findsNothing);

    await enter(tester, 'STAR58');
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(ParentShell), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a learner needs their own code', (tester) async {
    await pump(tester);
    AppSession.inLearnerApp.value = false;
    await tester.tap(find.text('Aarav'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Type your secret code'), findsOneWidget);

    // A wrong code keeps them out.
    final code = store.student!.loginCode;
    final wrong = code.substring(0, 5) + (code[5] == '2' ? '3' : '2');
    await enter(tester, wrong);
    expect(find.text('Not quite! Try again.'), findsOneWidget);
    expect(AppSession.inLearnerApp.value, isFalse);

    await enter(tester, code);
    await tester.pump(const Duration(milliseconds: 300));
    expect(AppSession.inLearnerApp.value, isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('another parent can be added only with a parent\'s PIN', (tester) async {
    final mum = store.parents.first;
    store.linkParent(store.activeStudentId, mum.id);
    await pump(tester);
    final add = find.text('Add');
    await tester.ensureVisible(add);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(add);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    // Sunita approves with her PIN.
    expect(find.text('Enter your 6-character parent PIN'), findsOneWidget);
    await enter(tester, 'STAR58');
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Parent sign-up'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Raj');
    await tester.ensureVisible(find.text('Create parent account'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Create parent account'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await enter(tester, 'RAJ472');
    await enter(tester, 'RAJ472');
    await tester.pump(const Duration(seconds: 1));

    final raj = store.parents.firstWhere((p) => p.name == 'Raj');
    expect(raj.checkPin('RAJ472'), isTrue);
    expect(store.childrenOf(raj.id).map((k) => k.id), contains(store.activeStudentId));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('remember me skips the code next time', (tester) async {
    store.setRemembered(store.activeStudentId, false);
    await pump(tester);
    AppSession.inLearnerApp.value = false;
    await tester.tap(find.text('Aarav'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Remember me on this phone'));
    await tester.pump(const Duration(milliseconds: 300));
    await enter(tester, store.student!.loginCode);
    await tester.pump(const Duration(seconds: 1));
    expect(AppSession.inLearnerApp.value, isTrue);
    expect(store.isRemembered(store.activeStudentId), isTrue);

    // Next time: straight in, no code screen.
    await pump(tester);
    AppSession.inLearnerApp.value = false;
    await tester.tap(find.text('Aarav'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Type your secret code'), findsNothing);
    expect(AppSession.inLearnerApp.value, isTrue);
    store.setRemembered(store.activeStudentId, false);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
}
