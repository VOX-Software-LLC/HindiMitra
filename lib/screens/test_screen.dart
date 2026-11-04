import 'package:flutter/material.dart';
import '../l10n.dart';
import 'activity_hub.dart';

/// Test tab: scored quizzes to check what has been learned.
class TestScreen extends StatelessWidget {
  const TestScreen({super.key});
  @override
  Widget build(BuildContext context) => ActivityHub(
        color: const Color(0xFF6E4EDF),
        icon: Icons.quiz_rounded,
        title: 'परीक्षा',
        subtitle: tr('Test yourself', 'अपनी जाँच करें'),
        intro: tr('Each test gives a score and stars. Start at Level 1 and climb up — try to get 3 stars on every level!',
            'हर परीक्षा में अंक और सितारे मिलते हैं। स्तर 1 से शुरू करें और हर स्तर पर 3 सितारे पाएँ!'),
        groups: [
          (tr('Letter tests', 'अक्षर परीक्षा'), [
            HubItem('MatchingQuiz', '🔤', tr('Letter Quiz', 'अक्षर प्रश्नोत्तरी'), 'अक्षर प्रश्नोत्तरी', tr('Match letters to their sounds', 'अक्षर को उसकी ध्वनि से मिलाएँ'), const Color(0xFFE65100)),
            HubItem('LetterSoundQuiz', '🔊', tr('Letter Sound Quiz', 'अक्षर ध्वनि प्रश्नोत्तरी'), 'अक्षर ध्वनि', tr('Hear a sound, find the letter', 'आवाज़ सुनें, अक्षर खोजें'), const Color(0xFF7B1FA2)),
            HubItem('LetterPairsQuiz', '👯', tr('Letter Pairs', 'अक्षर जोड़ी'), 'अक्षर जोड़ी', tr('क or ख? Spot the right one', 'क या ख? सही चुनें'), const Color(0xFFD32F2F)),
            HubItem('MatraQuiz', 'ा', tr('Matra Quiz', 'मात्रा प्रश्नोत्तरी'), 'मात्रा प्रश्नोत्तरी', tr('Pick the right vowel sign', 'सही मात्रा चुनें'), const Color(0xFF7B1FA2)),
          ]),
          (tr('Word tests', 'शब्द परीक्षा'), [
            HubItem('PictureMatch', '🖼️', tr('Picture Match', 'चित्र मिलान'), 'चित्र मिलान', tr('Match each word to its picture', 'शब्द को चित्र से मिलाएँ'), const Color(0xFFE91E63)),
            HubItem('OddOneOut', '🔎', tr('Odd One Out', 'अलग शब्द खोजें'), 'अलग शब्द खोजें', tr('Find the word that does not belong', 'जो शब्द अलग है उसे खोजें'), const Color(0xFF0277BD)),
            HubItem('RhymingWords', '🎵', tr('Rhyming Words', 'तुकांत शब्द'), 'तुकांत शब्द', tr('Which words rhyme?', 'कौन से शब्द तुक मिलाते हैं?'), const Color(0xFF6A1B9A)),
            HubItem('FillBlank', '✏️', tr('Fill in the Blank', 'रिक्त स्थान भरें'), 'रिक्त स्थान भरें', tr('Complete the sentence', 'वाक्य पूरा करें'), const Color(0xFF5C6BC0)),
            HubItem('Numbers', '🔢', tr('Hindi Numbers', 'हिन्दी अंक'), 'हिन्दी अंक', tr('१, २, ३… read and count', '१, २, ३… पढ़ें और गिनें'), const Color(0xFFE65100)),
          ]),
        ],
      );
}
