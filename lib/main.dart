import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'data/models.dart';
import 'services/crash_reporter.dart';
import 'services/speech_service.dart';
import 'store/app_store.dart';
import 'theme/app_theme.dart';
import 'screens/onboarding_screen.dart';
import 'screens/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  CrashReporter.install();
  final (_, store, _) = await (AppData.load(), AppStore.load(), Fonts.preload()).wait;
  SpeechService.init();
  SpeechService.muted = !store.soundOn;
  store.addListener(() => SpeechService.muted = !store.soundOn);
  runApp(ChangeNotifierProvider.value(value: store, child: const HindiMitraApp()));
}

class HindiMitraApp extends StatelessWidget {
  const HindiMitraApp({super.key});
  @override
  Widget build(BuildContext context) {
    final (themePref, onboardingComplete) =
        context.select<AppStore, (String, bool)>((store) => (store.themePref, store.onboardingComplete));
    final mode = {'light': ThemeMode.light, 'dark': ThemeMode.dark}[themePref] ?? ThemeMode.system;
    return MaterialApp(
      title: 'HindiMitra',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: mode,
      // Cap very large system font sizes so the kid-sized layouts don't overflow.
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(data: mq.copyWith(textScaler: mq.textScaler.clamp(maxScaleFactor: 1.2)), child: child!);
      },
      home: onboardingComplete ? const AppShell() : const OnboardingScreen(),
    );
  }
}
