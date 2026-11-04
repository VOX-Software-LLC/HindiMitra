import 'package:flutter/material.dart';
import '../l10n.dart';
import 'activity_hub.dart';

/// Practice tab: free practice with no pass/fail, grouped by skill.
class PracticeScreen extends StatelessWidget {
  const PracticeScreen({super.key});
  @override
  Widget build(BuildContext context) => ActivityHub(
        color: const Color(0xFF13A89E),
        icon: Icons.fitness_center_rounded,
        title: 'अभ्यास',
        subtitle: tr('Practice', 'अभ्यास करें'),
        intro: tr('Warm up and build speed. Practice as much as you like — nothing here can be failed.',
            'अभ्यास करें और तेज़ बनें। यहाँ कोई फ़ेल नहीं होता।'),
        groups: [
          (tr('Writing practice', 'लिखने का अभ्यास'), [
            HubItem('RoughPad', '📝', tr('Rough Pad', 'रफ़ पैड'), 'रफ़ पैड', tr('Free drawing board to try any letter', 'कोई भी अक्षर लिखकर देखें'), const Color(0xFF8D6E63)),
            HubItem('RandomDrill', '🎲', tr('Random Drill', 'रैंडम ड्रिल'), 'अभ्यास ड्रिल', tr('Mixed letters, one after another', 'मिले-जुले अक्षर, एक के बाद एक'), const Color(0xFF00897B)),
            HubItem('SpeedChallenge', '⚡', tr('Speed Challenge', 'गति चुनौती'), 'गति चुनौती', tr('Write as many letters as you can in time', 'समय में ज़्यादा से ज़्यादा अक्षर लिखें'), const Color(0xFFE53935)),
            HubItem('Dictation', '🎧', tr('Dictation', 'श्रुतलेख'), 'श्रुतलेख', tr('Listen, then write what you hear', 'सुनें और लिखें'), const Color(0xFF1565C0)),
            HubItem('LetterComparison', '⚖️', tr('Letter Comparison', 'अक्षर तुलना'), 'अक्षर तुलना', tr('Tell look-alike letters apart', 'मिलते-जुलते अक्षर पहचानें'), const Color(0xFFF57C00)),
            HubItem('MatraNameCard', '🪪', tr('Write My Name', 'अपना नाम लिखो'), 'अपना नाम', tr('Trace your name in Hindi and share a name card', 'अपना नाम हिंदी में लिखें और नाम कार्ड बनाएँ'), const Color(0xFFE65100)),
            HubItem('ConjunctPractice', '🔗', tr('Conjuncts', 'संयुक्त अक्षर'), 'संयुक्त अक्षर', tr('Joined letters like क्र and त्र', 'क्र, त्र जैसे जुड़े अक्षर'), const Color(0xFFC62828)),
          ]),
          (tr('Reading & speaking practice', 'पढ़ने और बोलने का अभ्यास'), [
            HubItem('Flashcards', '🃏', tr('Flashcards', 'फ्लैशकार्ड'), 'फ्लैशकार्ड', tr('Flip cards to learn new words', 'कार्ड पलटकर नए शब्द सीखें'), const Color(0xFF2E7D32)),
            HubItem('WordSpeedReading', '🏃', tr('Speed Reading', 'तेज़ पढ़ना'), 'तेजी से पढ़ना', tr('Read words fast and pick the meaning', 'जल्दी पढ़ें, सही अर्थ चुनें'), const Color(0xFFF57C00)),
            HubItem('PronunciationCoach', '🎤', tr('Pronunciation Coach', 'उच्चारण कोच'), 'उच्चारण कोच', tr('Say it out loud and compare', 'बोलकर देखें'), const Color(0xFF00897B)),
            HubItem('WordBuilder', '🧩', tr('Word Builder', 'शब्द निर्माण'), 'शब्द निर्माण', tr('Build words from letter blocks', 'अक्षरों से शब्द बनाएँ'), const Color(0xFF00897B)),
            HubItem('VocabCategory', '🎨', tr('Vocabulary', 'शब्दावली'), 'शब्दावली', tr('Colours, animals, family and more', 'रंग, जानवर, परिवार और भी'), const Color(0xFFC62828)),
          ]),
        ],
      );
}
