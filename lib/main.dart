import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'data/models.dart';
import 'services/cloud.dart';
import 'services/sync_service.dart';
import 'services/crash_reporter.dart';
import 'services/ink_recognizer.dart';
import 'services/speech_service.dart';
import 'store/app_store.dart';
import 'theme/app_theme.dart';
import 'screens/onboarding_screen.dart';
import 'screens/app_shell.dart';
import 'screens/intro_screen.dart';
import 'screens/persona_screen.dart';
import 'app_session.dart';
import 'l10n.dart';
import 'theme/themes.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  CrashReporter.install();
  final (_, store, _, _) = await (AppData.load(), AppStore.load(), Fonts.preload(), Cloud.init()).wait;
  AppThemes.current = AppThemes.byId(store.themeId);
  AppLang.code = store.appLanguage;
  SyncService.start(store);
  SpeechService.init();
  // Download the on-device Hindi handwriting model in the background (first launch only).
  InkModel.prepare();
  SpeechService.muted = !store.soundOn;
  SpeechService.voice = store.voice;
  store.addListener(() {
    SpeechService.muted = !store.soundOn;
    SpeechService.voice = store.voice;
  });
  runApp(ChangeNotifierProvider.value(value: store, child: const HindiMitraApp()));
}

class HindiMitraApp extends StatefulWidget {
  const HindiMitraApp({super.key});
  @override
  State<HindiMitraApp> createState() => _HindiMitraAppState();
}

class _HindiMitraAppState extends State<HindiMitraApp> {
  bool _introDone = false;

  @override
  Widget build(BuildContext context) {
    final (themeId, onboardingComplete, studentId) = context.select<AppStore, (String, bool, String)>(
        (store) => (store.themeId, store.onboardingComplete, store.activeStudentId));
    return MaterialApp(
      title: 'HindiMitra',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      // Cap very large system font sizes so the kid-sized layouts don't overflow.
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(data: mq.copyWith(textScaler: mq.textScaler.clamp(maxScaleFactor: 1.2)), child: child!);
      },
      home: !_introDone
          ? IntroScreen(autoContinue: onboardingComplete, onContinue: () => setState(() => _introDone = true))
          // Who's using the app? Then, a new key per learner: switching profile starts the tabs afresh.
          : ValueListenableBuilder<bool>(
              valueListenable: AppSession.inLearnerApp,
              builder: (_, inApp, __) => !inApp ? const PersonaScreen()
                  : onboardingComplete ? AppShell(key: ValueKey(studentId)) : const OnboardingScreen(),
            ),
    );
  }
}
