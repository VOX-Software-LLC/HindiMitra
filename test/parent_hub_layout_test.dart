import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hindi_mitra/data/accounts.dart';
import 'package:hindi_mitra/data/models.dart';
import 'package:hindi_mitra/screens/home_screen.dart';
import 'package:hindi_mitra/screens/persona_screen.dart';
import 'package:hindi_mitra/screens/accounts/pin_pad.dart';
import 'package:hindi_mitra/screens/accounts/code_pad.dart';
import 'package:hindi_mitra/screens/parent/achievements_screen.dart';
import 'package:hindi_mitra/screens/parent/assign_activity_screen.dart';
import 'package:hindi_mitra/screens/parent/assignment_detail_screen.dart';
import 'package:hindi_mitra/screens/parent/challenges_screen.dart';
import 'package:hindi_mitra/screens/parent/child_analytics_screen.dart';
import 'package:hindi_mitra/screens/parent/hub_widgets.dart';
import 'package:hindi_mitra/screens/parent/parent_shell.dart';
import 'package:hindi_mitra/screens/parent/skill_analytics_screen.dart';
import 'package:hindi_mitra/screens/parent/weekly_summary_screen.dart';
import 'package:hindi_mitra/store/app_store.dart';
import 'package:hindi_mitra/theme/app_theme.dart';

/// Opens every Parent Hub tab and screen, with a parent, two children,
/// practice, homework and a challenge, on small phones with a larger
/// system font, and fails on any overflow or exception.
void main() {
  late AppStore store;
  late String parentId;
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await AppData.load();
    store = await AppStore.load();
    await Fonts.preload();
    store.completeOnboarding('Aarav', 'kid-7-10', 'student');
    final mum = store.createParent(name: 'Sunita Sharma', pin: '1234');
    parentId = mum.id;
    store.linkParent(store.activeStudentId, mum.id);
    store.addStudent('Meera', parentId: mum.id);
    for (final l in AppData.allLetters.take(8)) {
      store.selectLetter(l.id);
      store.recordAttempt(l.id, l.order.isEven ? 3 : 1, accuracy: l.order.isEven ? 92 : 45,
          strokes: const [[0.2, 0.2, 0.5, 0.8, 0.8, 0.2]]);
    }
    store.completeActivityLevel('word-reading', 1);
    store.addPracticeTime(420);
    store.assignHomework(Homework(id: 'hw1', studentId: store.activeStudentId, assignedBy: mum.id, kind: HomeworkKind.letter,
        title: 'Write क well 3 times', target: AppData.allLetters[13].id, goal: 3, category: 'writing', note: 'You can do it!'));
    store.assignHomework(Homework(id: 'hw2', studentId: store.activeStudentId, assignedBy: mum.id, kind: HomeworkKind.level,
        title: 'Word Reading · Level 2', target: 'word-reading', level: 2, goal: 2, category: 'reading', dueDate: '2000-01-01'));
    store.addChallenge(Challenge(id: 'c1', studentId: store.activeStudentId, parentId: mum.id, title: '7-day streak',
        category: 'daily', metric: 'days', target: 7, message: 'Go go go!'));
  });

  final screens = <String, Widget Function()>{
    'Shell': () => const ParentShell(),
    'ChildAnalytics': () => const ChildAnalyticsScreen(),
    'SkillAnalytics': () => const SkillAnalyticsScreen(),
    'AssignStep1': () => const AssignActivityScreen(),
    'AssignStep3': () => AssignActivityScreen(childId: store.activeStudentId, category: 'writing'),
    'AssignDetail': () => const AssignmentDetailScreen(homeworkId: 'hw1'),
    'Challenges': () => const ChallengesScreen(),
    'CreateChallenge': () => const CreateChallengeScreen(),
    'WeeklySummary': () => const WeeklySummaryScreen(),
    'Achievements': () => const AchievementsScreen(),
    'ChildHome': () => const HomeScreen(),
    'Persona': () => const PersonaScreen(),
    'CodePad': () => PinScreen(title: 'Hi Aarav!', subtitle: 'Type your secret code',
        pad: CodePad(onComplete: (_) async => null)),
    'PinPad': () => PinScreen(title: 'Hi Sunita', subtitle: 'Enter your parent PIN', avatarName: 'Sunita',
        pad: PinPad(onComplete: (_) async => null)),
  };
  const sizes = [Size(320, 568), Size(412, 915), Size(1280, 800)];

  for (final size in sizes) {
    for (final e in screens.entries) {
      testWidgets('${e.key} fits at ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final problems = <String>[];
        final prev = FlutterError.onError;
        FlutterError.onError = (d) {
          // Point at the place in lib/ that failed.
          final where = RegExp(r'lib/[\w/]+\.dart:\d+').firstMatch(d.toString())?[0] ??
              RegExp(r'lib/[\w/]+\.dart[ :]\d+').firstMatch(d.stack.toString())?[0] ?? '';
          problems.add('${d.exceptionAsString().split('\n').first} $where');
        };
        final selected = ValueNotifier(store.activeStudentId);
        Widget wrap(Widget w) => const {'Shell', 'ChildHome', 'Persona', 'PinPad', 'CodePad'}.contains(e.key) ? w
            : ParentHubScope(parentId: parentId, selected: selected, child: w);
        await tester.pumpWidget(ChangeNotifierProvider.value(
          value: store,
          child: MaterialApp(
            builder: (c, child) => MediaQuery(
                data: MediaQuery.of(c).copyWith(textScaler: const TextScaler.linear(1.2)), child: child!),
            home: wrap(e.value()),
          ),
        ));
        await tester.pump(const Duration(milliseconds: 800));
        if (e.key == 'Shell') {
          // Visit every tab.
          final shell = tester.state<ParentShellState>(find.byType(ParentShell));
          for (int t = 1; t < 5; t++) {
            shell.goTo(t);
            await tester.pump(const Duration(milliseconds: 800));
          }
        }
        FlutterError.onError = prev;
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 5));
        expect(problems, isEmpty);
      });
    }
  }
}
