import 'package:flutter/material.dart';
import 'screens/contact_sales_screen.dart';
import 'screens/help_screen.dart';
import 'screens/leaderboard_screen.dart';
import 'screens/parent_dashboard_screen.dart';
import 'screens/paywall_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/reading/dialogue_reading_screen.dart';
import 'screens/reading/fill_blank_screen.dart';
import 'screens/reading/flashcards_screen.dart';
import 'screens/reading/letter_pairs_quiz_screen.dart';
import 'screens/reading/letter_sound_quiz_screen.dart';
import 'screens/reading/matching_quiz_screen.dart';
import 'screens/reading/numbers_screen.dart';
import 'screens/reading/odd_one_out_screen.dart';
import 'screens/reading/picture_match_screen.dart';
import 'screens/reading/pronunciation_coach_screen.dart';
import 'screens/reading/rhyming_words_screen.dart';
import 'screens/reading/sentence_build_screen.dart';
import 'screens/reading/story_reading_screen.dart';
import 'screens/reading/vocab_category_screen.dart';
import 'screens/reading/word_builder_screen.dart';
import 'screens/reading/word_reading_screen.dart';
import 'screens/reading/word_speed_reading_screen.dart';
import 'screens/writing/conjunct_practice_screen.dart';
import 'screens/writing/dictation_screen.dart';
import 'screens/writing/letter_comparison_screen.dart';
import 'screens/writing/matra_quiz_screen.dart';
import 'screens/writing/matra_screen.dart';
import 'screens/writing/random_drill_screen.dart';
import 'screens/writing/rough_pad_screen.dart';
import 'screens/writing/speed_challenge_screen.dart';
import 'screens/writing/word_writing_screen.dart';
import 'screens/writing/writing_canvas_screen.dart';

typedef ScreenBuilder = Widget Function(Map<String, dynamic> params);

/// Mirrors the React Navigation route names used by the original app.
final Map<String, ScreenBuilder> screenRegistry = {
  // Home / Profile stacks
  'Leaderboard': (p) => LeaderboardScreen(params: p),
  'Settings': (p) => SettingsScreen(params: p),
  'Paywall': (p) => PaywallScreen(params: p),
  'ParentDashboard': (p) => ParentDashboardScreen(params: p),
  'HelpSupport': (p) => HelpScreen(params: p),
  'ContactSales': (p) => ContactSalesScreen(params: p),
  // Writing stack
  'WritingCanvas': (p) => WritingCanvasScreen(params: p),
  'MatraPractice': (p) => MatraScreen(params: p),
  'MatraQuiz': (p) => MatraQuizScreen(params: p),
  'WordWriting': (p) => WordWritingScreen(params: p),
  'SpeedChallenge': (p) => SpeedChallengeScreen(params: p),
  'Dictation': (p) => DictationScreen(params: p),
  'LetterComparison': (p) => LetterComparisonScreen(params: p),
  'RandomDrill': (p) => RandomDrillScreen(params: p),
  'ConjunctPractice': (p) => ConjunctPracticeScreen(params: p),
  'RoughPad': (p) => RoughPadScreen(params: p),
  // Reading stack
  'Flashcards': (p) => FlashcardsScreen(params: p),
  'MatchingQuiz': (p) => MatchingQuizScreen(params: p),
  'WordReading': (p) => WordReadingScreen(params: p),
  'SentenceBuild': (p) => SentenceBuildScreen(params: p),
  'StoryReading': (p) => StoryReadingScreen(params: p),
  'PronunciationCoach': (p) => PronunciationCoachScreen(params: p),
  'PictureMatch': (p) => PictureMatchScreen(params: p),
  'WordBuilder': (p) => WordBuilderScreen(params: p),
  'FillBlank': (p) => FillBlankScreen(params: p),
  'Numbers': (p) => NumbersScreen(params: p),
  'LetterSoundQuiz': (p) => LetterSoundQuizScreen(params: p),
  'LetterPairsQuiz': (p) => LetterPairsQuizScreen(params: p),
  'WordSpeedReading': (p) => WordSpeedReadingScreen(params: p),
  'RhymingWords': (p) => RhymingWordsScreen(params: p),
  'OddOneOut': (p) => OddOneOutScreen(params: p),
  'DialogueReading': (p) => DialogueReadingScreen(params: p),
  'VocabCategory': (p) => VocabCategoryScreen(params: p),
};

/// navigation.navigate(name, params)
Future<T?> openScreen<T>(BuildContext context, String name, [Map<String, dynamic> params = const {}]) {
  final b = screenRegistry[name];
  if (b == null) {
    debugPrint('openScreen: unknown route $name');
    return Future.value(null);
  }
  return Navigator.of(context).push<T>(MaterialPageRoute<T>(builder: (_) => b(params), settings: RouteSettings(name: name)));
}
