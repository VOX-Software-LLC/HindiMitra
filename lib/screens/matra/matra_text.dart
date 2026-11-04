import '../../l10n.dart';

/// Every instruction and message the matra course shows, in one place so it
/// can be translated without touching the screens. Hindi words and signs
/// shown to the child are passed in as arguments, never translated.
class MT {
  MT._();

  // ── Course & level intro ──
  static String get course => tr('Matra Course', 'मात्रा कोर्स');
  static String levelN(int n) => tr('Level $n', 'स्तर $n');
  static String get inThisLevel => tr('Signs in this level', 'इस स्तर की मात्राएँ');
  static String get howItWorks => tr('Every round: See it, write it, use it in a real word.',
      'हर राउंड में: देखो, लिखो, और असली शब्द में लगाओ।');
  static String get start => tr("Let's go!", 'चलो शुरू करें!');
  static String get browseAll => tr('Browse all matras', 'सभी मात्राएँ देखें');
  static String soundsLike(String anchor) => tr('Sounds like $anchor', 'अंग्रेज़ी में $anchor जैसी आवाज़');
  static String get hinglishTip => tr('If you read Hinglish', 'अगर आप Hinglish पढ़ते हैं');
  static String get parentsCorner => tr("Parent's corner", 'अभिभावकों के लिए');

  // ── Round steps ──
  static String get stepSee => tr('See', 'देखो');
  static String get stepWrite => tr('Write', 'लिखो');
  static String get stepUse => tr('Use', 'लगाओ');
  static String round(int i, int n) => tr('Round $i of $n', 'राउंड $i / $n');

  // See
  static String watch(String sign, String base) =>
      tr('Watch $sign join $base', 'देखो, $sign कैसे $base से जुड़ती है');
  static String get listenFirst => tr('Listen carefully', 'ध्यान से सुनो');
  static String get playAgain => tr('Hear it again', 'फिर से सुनो');
  static String get myTurn => tr('My turn to write!', 'अब मेरी बारी!');
  static String get ready => tr("I'm ready", 'मैं तैयार हूँ');

  // Write
  static String writeOnly(String sign, String base) =>
      tr('Write only $sign on $base, in the right spot', '$base पर सिर्फ़ $sign लिखो, सही जगह पर');
  static String get writeWhatYouHeard => tr('Write the sign you heard', 'जो सुना, वह मात्रा लिखो');
  static String get check => tr('Check', 'जाँचो');
  static String get undo => tr('Undo', 'वापस');
  static String get clear => tr('Clear', 'मिटाओ');
  static String get showMe => tr('Show me', 'दिखाओ');
  static String get checking => tr('Checking…', 'जाँच रहे हैं…');
  static String get drawFirst => tr('Draw the sign first!', 'पहले मात्रा बनाओ!');
  static String get greatPlace => tr('Perfect spot!', 'बिल्कुल सही जगह!');
  static String get nearlyShape =>
      tr('Right spot! Now copy the shape a little closer. Try again!', 'जगह सही है! आकार थोड़ा और मिलाओ। फिर से कोशिश करो!');
  static String looksLike(String other) =>
      tr('That looks like $other. Watch once more!', 'यह $other जैसा लग रहा है। एक बार और देखो!');
  static String get letsMoveOn => tr("Good try! Let's use it in a word.", 'अच्छी कोशिश! चलो इसे शब्द में लगाएँ।');
  static String get useIt => tr('Use it!', 'शब्द में लगाओ!');

  /// The friendly placement hint (instead of a red ✗).
  static String placeHint(String sign, String position) => switch (position) {
        'left' => tr('$sign goes before the letter!', '$sign अक्षर से पहले आती है!'),
        'right' => tr('$sign goes after the letter!', '$sign अक्षर के बाद आती है!'),
        'top' => tr('$sign sits on top of the line!', '$sign रेखा के ऊपर बैठती है!'),
        _ => tr('$sign hangs below the letter!', '$sign अक्षर के नीचे लटकती है!'),
      };
  static String placeName(String position) => switch (position) {
        'left' => tr('Before', 'पहले'),
        'right' => tr('After', 'बाद में'),
        'top' => tr('On top', 'ऊपर'),
        _ => tr('Below', 'नीचे'),
      };

  // Use
  static String completeWord(String meaning) => tr('Complete the word for "$meaning"', '"$meaning" वाला शब्द पूरा करो');
  static String get tapTheSign => tr('Tap the sign that fits', 'सही मात्रा पर टैप करो');
  static String get notThatOne => tr('Not that one. Say the word out loud and try again!', 'यह नहीं। शब्द बोलकर देखो, फिर कोशिश करो!');
  static String get nextRound => tr('Next', 'आगे');
  static String get finish => tr('Finish', 'पूरा करो');

  // ── Level games ──
  static String whereGoes(String sign) => tr('Where does $sign go?', '$sign कहाँ लगेगी?');
  static String get shortOrLong => tr('Short or long? Listen and pick.', 'छोटी या बड़ी? सुनो और चुनो।');
  static String get shortLabel => tr('Short', 'छोटी');
  static String get longLabel => tr('Long', 'बड़ी');
  static String get oneOrTwoFlags => tr('One flag or two? Listen and pick.', 'एक झंडा या दो? सुनो और चुनो।');
  static String get oneFlag => tr('One flag', 'एक झंडा');
  static String get twoFlags => tr('Two flags', 'दो झंडे');
  static String matraMaths(String a, String b) => tr('What do you get from $a + $b?', '$a + $b से क्या बनेगा?');
  static String get whichSignHeard => tr('Which sign do you hear in this word?', 'इस शब्द में कौन-सी मात्रा सुनाई दी?');
  static String magicGoal(String fromMeaning, String toMeaning) =>
      tr('Change ONE matra to turn "$fromMeaning" into "$toMeaning"', 'एक मात्रा बदलो: "$fromMeaning" को "$toMeaning" बनाओ');
  static String get tapSyllableToChange => tr('Tap the part to change', 'बदलने वाला हिस्सा टैप करो');
  static String get pickNewSign => tr('Which sign goes there?', 'वहाँ कौन-सी मात्रा आएगी?');
  static String fixGoal(String meaning) =>
      tr('One sign is wrong in "$meaning". Find it!', '"$meaning" में एक मात्रा गलत है। ढूँढो!');
  static String get pickRightSign => tr('Pick the right sign', 'सही मात्रा चुनो');
  static String get notThisPart => tr('That part is fine. Look again!', 'यह हिस्सा ठीक है। फिर से देखो!');
  static String get listenToWord => tr('Listen to the word', 'शब्द सुनो');
  static String timeLeft(int s) => tr('${s}s', '$s से.');
  static String get timesUp => tr("Time's up!", 'समय खत्म!');
  static String themeName(String id) => switch (id) {
        'family' => tr('Family', 'परिवार'),
        'festival' => tr('Festivals', 'त्योहार'),
        _ => tr('Food', 'खाना'),
      };
  static String get tryAgainFriendly => tr('Almost! Try again.', 'लगभग! फिर से कोशिश करो।');

  // ── Name card ──
  static String get writeMyName => tr('Write my name', 'अपना नाम लिखो');
  static String get traceYourName => tr('Trace your name in Hindi', 'अपना नाम हिंदी में लिखो');
  static String get fixSpelling => tr('Wrong spelling? Tap your name to fix it.', 'स्पेलिंग गलत है? नाम पर टैप करके ठीक करो।');
  static String get noNameYet => tr('Add your name in your profile first.', 'पहले प्रोफ़ाइल में अपना नाम लिखो।');
  static String get makeCard => tr('Make my name card', 'मेरा नाम कार्ड बनाओ');
  static String get share => tr('Share', 'शेयर करो');
  static String get shareText => tr('I can write my name in Hindi!', 'मैं अपना नाम हिंदी में लिख सकता/सकती हूँ!');
  static String matrasIKnow(int n) => tr('I know $n matras', 'मुझे $n मात्राएँ आती हैं');
  static String get nameCardTitle => tr('My Hindi Name', 'मेरा हिंदी नाम');
  static String get shareFailed => tr('Could not share. Take a screenshot instead!', 'शेयर नहीं हो पाया। स्क्रीनशॉट ले लो!');

  // ── Results ──
  static String get levelDone => tr('Level complete!', 'स्तर पूरा!');
  static String get playAgainLevel => tr('Play again', 'फिर से खेलो');
  static String get backToMenu => tr('Back', 'वापस');
  static String get statRounds => tr('Rounds', 'राउंड');
  static String get statAccuracy => tr('Writing', 'लिखावट');
  static String get statWritten => tr('Signs written', 'मात्राएँ लिखीं');
  static String resultMessage(int stars) => switch (stars) {
        3 => tr('Matra master! Every sign in the right place.', 'मात्रा मास्टर! हर मात्रा सही जगह पर।'),
        2 => tr('Great work! A little more practice and it will be perfect.', 'बहुत बढ़िया! थोड़ा और अभ्यास, फिर एकदम सही।'),
        1 => tr('Good start! Play again to earn more stars.', 'अच्छी शुरुआत! और तारे पाने के लिए फिर खेलो।'),
        _ => tr('Every try helps. Watch the signs again and have another go!', 'हर कोशिश से सीखते हैं। फिर से देखो और खेलो!'),
      };

  /// What a parent can do at home for each level (1-10).
  static String parentTip(int level) => switch (level) {
        1 => tr('Point at ा and ि on packets and signs. ि is written first but said after the letter: "क-ि = कि".',
            'पैकेट और बोर्ड पर ा और ि दिखाइए। ि पहले लिखी जाती है पर अक्षर के बाद बोली जाती है: "क-ि = कि"।'),
        2 => tr('Clap once for a short sound (कि) and twice for a long one (की). Children who read Hinglish often mix these up.',
            'छोटी आवाज़ (कि) पर एक ताली, लंबी (की) पर दो ताली। Hinglish पढ़ने वाले बच्चे इन्हें अक्सर मिला देते हैं।'),
        3 => tr('Draw े and ै as flags on a pole. Say "मेला" and "मैला" slowly together.',
            'े और ै को डंडे पर झंडे की तरह बनाइए। "मेला" और "मैला" साथ में धीरे बोलिए।'),
        4 => tr('Show that ो is just ा with a flag (े). Building signs from parts helps them stick.',
            'दिखाइए कि ो बस ा पर एक झंडा (े) है। हिस्सों से मात्रा बनाना याद रखने में मदद करता है।'),
        5 => tr('Hum together for ं (हंस, रंग). Say "नमः" with a little breath at the end for ः.',
            'ं के लिए साथ में गुनगुनाइए (हंस, रंग)। ः के लिए "नमः" के अंत में हल्की साँस छोड़िए।'),
        6 => tr('Play word swaps at the table: कम → काम, फल → फूल. Ask what each one means.',
            'खाने की मेज़ पर शब्द बदलने का खेल खेलिए: कम → काम, फल → फूल। हर शब्द का मतलब पूछिए।'),
        7 => tr('Write a word with one wrong matra on paper and let your child play teacher.',
            'कागज़ पर एक गलत मात्रा वाला शब्द लिखिए और बच्चे को टीचर बनने दीजिए।'),
        8 => tr('Say a family word aloud and let your child write it. Praise the right spot before the perfect shape.',
            'परिवार का कोई शब्द बोलिए और बच्चे को लिखने दीजिए। पहले सही जगह की तारीफ़ कीजिए, फिर आकार की।'),
        9 => tr('Short timed games keep it fun. Stop while they still want more.',
            'छोटे, समय वाले खेल मज़ेदार रहते हैं। तब रुकिए जब बच्चा और खेलना चाहे।'),
        _ => tr('Print or share the name card with grandparents. Writing to family makes Hindi feel like theirs.',
            'नाम कार्ड दादा-दादी, नाना-नानी को भेजिए। परिवार को लिखना हिंदी को अपना बनाता है।'),
      };
}
