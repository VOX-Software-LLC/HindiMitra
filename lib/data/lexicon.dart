/// Hand-checked core Hindi vocabulary for the translator: pronouns, the verb
/// "to be", question words, common adjectives and verbs — the words a lesson
/// word list doesn't cover but every sentence needs. Each entry lists every
/// common form, so the translator never has to guess gender or number.
class LexEntry {
  /// English headwords (lower case) this entry answers.
  final List<String> english;
  /// Hindi forms, most common first.
  final List<String> hindi;
  /// Grammar or usage note shown under the word, e.g. "m. / f. / pl.".
  final String note;
  const LexEntry(this.english, this.hindi, [this.note = '']);
}

const coreLexicon = <LexEntry>[
  // Pronouns
  LexEntry(['i'], ['मैं']),
  LexEntry(['you'], ['आप', 'तुम'], 'आप polite · तुम friends and children'),
  LexEntry(['he', 'she', 'it', 'that'], ['वह'], 'वह = he / she / it / that'),
  LexEntry(['this'], ['यह']),
  LexEntry(['we'], ['हम']),
  LexEntry(['they', 'those'], ['वे']),
  LexEntry(['my', 'mine'], ['मेरा', 'मेरी', 'मेरे'], 'मेरा m. · मेरी f. · मेरे pl. — matches the thing owned'),
  LexEntry(['your', 'yours'], ['आपका', 'आपकी', 'आपके'], 'आपका m. · आपकी f. · आपके pl. (polite)'),
  LexEntry(['our', 'ours'], ['हमारा', 'हमारी', 'हमारे'], 'हमारा m. · हमारी f. · हमारे pl.'),
  LexEntry(['his', 'her', 'its'], ['उसका', 'उसकी', 'उसके'], 'उसका m. · उसकी f. · उसके pl. — matches the thing owned'),
  // To be
  LexEntry(['is'], ['है']),
  LexEntry(['are'], ['हैं'], 'हैं for plural or polite आप'),
  LexEntry(['am'], ['हूँ']),
  LexEntry(['was'], ['था', 'थी'], 'था m. · थी f.'),
  LexEntry(['were'], ['थे', 'थीं'], 'थे m. · थीं f.'),
  // Questions
  LexEntry(['what'], ['क्या']),
  LexEntry(['where'], ['कहाँ']),
  LexEntry(['who'], ['कौन']),
  LexEntry(['how'], ['कैसे', 'कैसा', 'कैसी'], 'कैसे how (manner) · कैसा/कैसी what kind'),
  LexEntry(['why'], ['क्यों']),
  LexEntry(['when'], ['कब']),
  LexEntry(['how much', 'how many'], ['कितना', 'कितनी', 'कितने'], 'कितना m. · कितनी f. · कितने pl.'),
  // Small words
  LexEntry(['yes'], ['हाँ']),
  LexEntry(['no', 'not'], ['नहीं']),
  LexEntry(['and'], ['और']),
  LexEntry(['but'], ['लेकिन', 'पर']),
  LexEntry(['or'], ['या']),
  LexEntry(['in', 'inside'], ['में'], 'comes after the noun: घर में = in the house'),
  LexEntry(['on'], ['पर'], 'comes after the noun: मेज़ पर = on the table'),
  LexEntry(['from'], ['से'], 'comes after the noun'),
  LexEntry(['with'], ['के साथ', 'से'], 'comes after the noun'),
  LexEntry(['very'], ['बहुत']),
  LexEntry(['also', 'too'], ['भी']),
  LexEntry(['now'], ['अब']),
  LexEntry(['here'], ['यहाँ']),
  LexEntry(['there'], ['वहाँ']),
  LexEntry(['today'], ['आज']),
  LexEntry(['tomorrow', 'yesterday'], ['कल'], 'कल = both yesterday and tomorrow; the verb tense tells which'),
  // Greetings
  LexEntry(['hello', 'hi', 'namaste'], ['नमस्ते']),
  LexEntry(['thank you', 'thanks'], ['धन्यवाद', 'शुक्रिया']),
  LexEntry(['please'], ['कृपया']),
  LexEntry(['sorry'], ['माफ़ कीजिए', 'सॉरी'], 'माफ़ कीजिए polite'),
  LexEntry(['goodbye', 'bye'], ['अलविदा', 'फिर मिलेंगे']),
  // Adjectives (forms: m. / f. / pl.)
  LexEntry(['good', 'nice'], ['अच्छा', 'अच्छी', 'अच्छे'], 'अच्छा m. · अच्छी f. · अच्छे pl.'),
  LexEntry(['bad'], ['बुरा', 'बुरी', 'बुरे'], 'बुरा m. · बुरी f. · बुरे pl.'),
  LexEntry(['big', 'large'], ['बड़ा', 'बड़ी', 'बड़े'], 'बड़ा m. · बड़ी f. · बड़े pl.'),
  LexEntry(['small', 'little'], ['छोटा', 'छोटी', 'छोटे'], 'छोटा m. · छोटी f. · छोटे pl.'),
  LexEntry(['new'], ['नया', 'नई', 'नए'], 'नया m. · नई f. · नए pl.'),
  LexEntry(['old'], ['पुराना', 'पुरानी', 'पुराने'], 'for things; बूढ़ा / बूढ़ी for people'),
  LexEntry(['hot'], ['गर्म']),
  LexEntry(['cold'], ['ठंडा', 'ठंडी', 'ठंडे'], 'ठंडा m. · ठंडी f. · ठंडे pl.'),
  LexEntry(['beautiful', 'pretty'], ['सुंदर']),
  LexEntry(['happy'], ['ख़ुश']),
  // Verbs (dictionary form)
  LexEntry(['eat', 'to eat'], ['खाना'], 'खाना also means "food"'),
  LexEntry(['drink', 'to drink'], ['पीना']),
  LexEntry(['go', 'to go'], ['जाना']),
  LexEntry(['come', 'to come'], ['आना']),
  LexEntry(['write', 'to write'], ['लिखना']),
  LexEntry(['read', 'to read', 'study'], ['पढ़ना']),
  LexEntry(['play', 'to play'], ['खेलना']),
  LexEntry(['sleep', 'to sleep'], ['सोना'], 'सोना also means "gold"'),
  LexEntry(['speak', 'say', 'to speak'], ['बोलना']),
  LexEntry(['listen', 'hear', 'to listen'], ['सुनना']),
  LexEntry(['see', 'look', 'watch', 'to see'], ['देखना']),
  LexEntry(['like'], ['पसंद'], 'मुझे … पसंद है = I like …'),
  // People
  LexEntry(['friend'], ['दोस्त', 'मित्र']),
  LexEntry(['teacher'], ['शिक्षक', 'शिक्षिका'], 'शिक्षक m. · शिक्षिका f.'),
  LexEntry(['mother', 'mom', 'mum'], ['माँ', 'माता']),
  LexEntry(['child', 'children'], ['बच्चा', 'बच्ची', 'बच्चे'], 'बच्चा boy · बच्ची girl · बच्चे children'),
];
