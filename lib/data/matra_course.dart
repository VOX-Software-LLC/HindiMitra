/// Words for the matra course. Every word is split into blocks (a letter plus
/// its signs counts as one block) and [slot] is the block whose matra the
/// child writes, so the course can show "क _ म" and ask for the missing ा.
class MatraWord {
  final String word, meaning;
  final List<String> units;
  final int slot;
  const MatraWord(this.word, this.meaning, this.units, this.slot);

  /// The block the child completes (की, रा …) and its bare letter (क, र …).
  String get unit => units[slot];
  String get base => units[slot].substring(0, 1);
}

/// Real words for each matra (keyed by [Matra.romanized]). The block in
/// [MatraWord.slot] is a plain consonant + that matra, so the matra canvas
/// can draw the letter and grade only the sign.
const matraWords = <String, List<MatraWord>>{
  'aa': [
    MatraWord('काम', 'Work', ['का', 'म'], 0), MatraWord('नाम', 'Name', ['ना', 'म'], 0),
    MatraWord('माला', 'Garland', ['मा', 'ला'], 0), MatraWord('पापा', 'Papa', ['पा', 'पा'], 0),
    MatraWord('दाल', 'Lentils', ['दा', 'ल'], 0), MatraWord('बाल', 'Hair', ['बा', 'ल'], 0),
  ],
  'i': [
    MatraWord('किताब', 'Book', ['कि', 'ता', 'ब'], 0), MatraWord('दिन', 'Day', ['दि', 'न'], 0),
    MatraWord('दिल', 'Heart', ['दि', 'ल'], 0), MatraWord('मिठाई', 'Sweets', ['मि', 'ठा', 'ई'], 0),
    MatraWord('तितली', 'Butterfly', ['ति', 'त', 'ली'], 0), MatraWord('दिवाली', 'Diwali', ['दि', 'वा', 'ली'], 0),
  ],
  'ee': [
    MatraWord('पानी', 'Water', ['पा', 'नी'], 1), MatraWord('नदी', 'River', ['न', 'दी'], 1),
    MatraWord('मछली', 'Fish', ['म', 'छ', 'ली'], 2), MatraWord('दादी', 'Grandma', ['दा', 'दी'], 1),
    MatraWord('खीर', 'Rice pudding', ['खी', 'र'], 0), MatraWord('चीनी', 'Sugar', ['ची', 'नी'], 0),
  ],
  'u': [
    MatraWord('गुलाब', 'Rose', ['गु', 'ला', 'ब'], 0), MatraWord('तुम', 'You', ['तु', 'म'], 0),
    MatraWord('पुल', 'Bridge', ['पु', 'ल'], 0), MatraWord('बुआ', 'Aunt', ['बु', 'आ'], 0),
    MatraWord('सुबह', 'Morning', ['सु', 'ब', 'ह'], 0), MatraWord('चुप', 'Quiet', ['चु', 'प'], 0),
  ],
  'oo': [
    MatraWord('फूल', 'Flower', ['फू', 'ल'], 0), MatraWord('दूध', 'Milk', ['दू', 'ध'], 0),
    MatraWord('सूरज', 'Sun', ['सू', 'र', 'ज'], 0), MatraWord('पूजा', 'Prayer', ['पू', 'जा'], 0),
    MatraWord('पूरी', 'Puri', ['पू', 'री'], 0), MatraWord('भालू', 'Bear', ['भा', 'लू'], 1),
  ],
  'e': [
    MatraWord('सेब', 'Apple', ['से', 'ब'], 0), MatraWord('मेला', 'Fair', ['मे', 'ला'], 0),
    MatraWord('केला', 'Banana', ['के', 'ला'], 0), MatraWord('पेड़', 'Tree', ['पे', 'ड़'], 0),
    MatraWord('जलेबी', 'Jalebi', ['ज', 'ले', 'बी'], 1), MatraWord('बेटा', 'Son', ['बे', 'टा'], 0),
  ],
  'ai': [
    MatraWord('पैसा', 'Money', ['पै', 'सा'], 0), MatraWord('कैसा', 'How', ['कै', 'सा'], 0),
    MatraWord('बैल', 'Ox', ['बै', 'ल'], 0), MatraWord('भैया', 'Big brother', ['भै', 'या'], 0),
    MatraWord('मैदान', 'Playground', ['मै', 'दा', 'न'], 0), MatraWord('पैर', 'Foot', ['पै', 'र'], 0),
  ],
  'o': [
    MatraWord('मोर', 'Peacock', ['मो', 'र'], 0), MatraWord('रोटी', 'Bread', ['रो', 'टी'], 0),
    MatraWord('होली', 'Holi', ['हो', 'ली'], 0), MatraWord('समोसा', 'Samosa', ['स', 'मो', 'सा'], 1),
    MatraWord('बोल', 'Speak', ['बो', 'ल'], 0), MatraWord('सोना', 'Gold', ['सो', 'ना'], 0),
  ],
  'au': [
    MatraWord('मौसम', 'Weather', ['मौ', 'स', 'म'], 0), MatraWord('कौन', 'Who', ['कौ', 'न'], 0),
    MatraWord('चौक', 'Square', ['चौ', 'क'], 0), MatraWord('नौ', 'Nine', ['नौ'], 0),
    MatraWord('कौआ', 'Crow', ['कौ', 'आ'], 0), MatraWord('दौड़', 'Race', ['दौ', 'ड़'], 0),
  ],
  'ri': [
    MatraWord('मृग', 'Deer', ['मृ', 'ग'], 0), MatraWord('कृपा', 'Kindness', ['कृ', 'पा'], 0),
    MatraWord('पृथ्वी', 'Earth', ['पृ', 'थ्वी'], 0), MatraWord('गृह', 'Home', ['गृ', 'ह'], 0),
  ],
  'an': [
    MatraWord('हंस', 'Swan', ['हं', 'स'], 0), MatraWord('पतंग', 'Kite', ['प', 'तं', 'ग'], 1),
    MatraWord('गंगा', 'Ganga', ['गं', 'गा'], 0), MatraWord('रंग', 'Colour', ['रं', 'ग'], 0),
    MatraWord('बंदर', 'Monkey', ['बं', 'द', 'र'], 0), MatraWord('ठंड', 'Cold', ['ठं', 'ड'], 0),
  ],
  'ah': [
    MatraWord('प्रातः', 'Morning', ['प्रा', 'तः'], 1), MatraWord('नमः', 'Salute', ['न', 'मः'], 1),
    MatraWord('पुनः', 'Again', ['पु', 'नः'], 1), MatraWord('अतः', 'So', ['अ', 'तः'], 1),
  ],
};

/// Two words where changing one matra changes the meaning (कम → काम).
/// [from] is the starting word; the child writes the matra of [to.unit].
class MatraPair {
  final MatraWord from, to;
  const MatraPair(this.from, this.to);
}

const matraPairs = [
  MatraPair(MatraWord('कम', 'Less', ['क', 'म'], 0), MatraWord('काम', 'Work', ['का', 'म'], 0)),
  MatraPair(MatraWord('बल', 'Strength', ['ब', 'ल'], 0), MatraWord('बाल', 'Hair', ['बा', 'ल'], 0)),
  MatraPair(MatraWord('दिल', 'Heart', ['दि', 'ल'], 0), MatraWord('दाल', 'Lentils', ['दा', 'ल'], 0)),
  MatraPair(MatraWord('चोर', 'Thief', ['चो', 'र'], 0), MatraWord('चार', 'Four', ['चा', 'र'], 0)),
  MatraPair(MatraWord('माला', 'Garland', ['मा', 'ला'], 0), MatraWord('मेला', 'Fair', ['मे', 'ला'], 0)),
  MatraPair(MatraWord('पल', 'Moment', ['प', 'ल'], 0), MatraWord('पुल', 'Bridge', ['पु', 'ल'], 0)),
  MatraPair(MatraWord('नाम', 'Name', ['ना', 'म'], 0), MatraWord('नीम', 'Neem tree', ['नी', 'म'], 0)),
  MatraPair(MatraWord('कल', 'Tomorrow', ['क', 'ल'], 0), MatraWord('कील', 'Nail', ['की', 'ल'], 0)),
  MatraPair(MatraWord('शेर', 'Lion', ['शे', 'र'], 0), MatraWord('शोर', 'Noise', ['शो', 'र'], 0)),
  MatraPair(MatraWord('बेल', 'Vine', ['बे', 'ल'], 0), MatraWord('बैल', 'Ox', ['बै', 'ल'], 0)),
  MatraPair(MatraWord('फल', 'Fruit', ['फ', 'ल'], 0), MatraWord('फूल', 'Flower', ['फू', 'ल'], 0)),
];

/// A word with one wrong matra for "Fix the sign": [wrong] has the same
/// blocks as [right] except at [MatraWord.slot].
class MatraFix {
  final List<String> wrong;
  final MatraWord right;
  const MatraFix(this.wrong, this.right);
}

const matraFixes = [
  MatraFix(['की', 'ता', 'ब'], MatraWord('किताब', 'Book', ['कि', 'ता', 'ब'], 0)),
  MatraFix(['पा', 'नि'], MatraWord('पानी', 'Water', ['पा', 'नी'], 1)),
  MatraFix(['सु', 'र', 'ज'], MatraWord('सूरज', 'Sun', ['सू', 'र', 'ज'], 0)),
  MatraFix(['रो', 'टि'], MatraWord('रोटी', 'Bread', ['रो', 'टी'], 1)),
  MatraFix(['मी', 'ठा', 'ई'], MatraWord('मिठाई', 'Sweets', ['मि', 'ठा', 'ई'], 0)),
  MatraFix(['गू', 'ला', 'ब'], MatraWord('गुलाब', 'Rose', ['गु', 'ला', 'ब'], 0)),
  MatraFix(['पै', 'ड़'], MatraWord('पेड़', 'Tree', ['पे', 'ड़'], 0)),
  MatraFix(['मौ', 'र'], MatraWord('मोर', 'Peacock', ['मो', 'र'], 0)),
  MatraFix(['दु', 'ध'], MatraWord('दूध', 'Milk', ['दू', 'ध'], 0)),
  MatraFix(['न', 'दि'], MatraWord('नदी', 'River', ['न', 'दी'], 1)),
];

/// Words from the child's own world for the last level.
const matraThemes = <(String, String, List<MatraWord>)>[
  ('family', '👨‍👩‍👧', [
    MatraWord('मामा', 'Uncle (mum’s brother)', ['मा', 'मा'], 0), MatraWord('दादी', 'Grandma (dad’s mum)', ['दा', 'दी'], 1),
    MatraWord('नानी', 'Grandma (mum’s mum)', ['ना', 'नी'], 1), MatraWord('दीदी', 'Big sister', ['दी', 'दी'], 0),
    MatraWord('भैया', 'Big brother', ['भै', 'या'], 0), MatraWord('बुआ', 'Aunt (dad’s sister)', ['बु', 'आ'], 0),
  ]),
  ('festival', '🪔', [
    MatraWord('दिवाली', 'Diwali', ['दि', 'वा', 'ली'], 0), MatraWord('होली', 'Holi', ['हो', 'ली'], 0),
    MatraWord('राखी', 'Rakhi', ['रा', 'खी'], 1), MatraWord('दीया', 'Clay lamp', ['दी', 'या'], 0),
    MatraWord('मेला', 'Fair', ['मे', 'ला'], 0), MatraWord('पूजा', 'Prayer', ['पू', 'जा'], 0),
  ]),
  ('food', '🍛', [
    MatraWord('रोटी', 'Bread', ['रो', 'टी'], 0), MatraWord('खीर', 'Rice pudding', ['खी', 'र'], 0),
    MatraWord('समोसा', 'Samosa', ['स', 'मो', 'सा'], 1), MatraWord('जलेबी', 'Jalebi', ['ज', 'ले', 'बी'], 1),
    MatraWord('पूरी', 'Puri', ['पू', 'री'], 0), MatraWord('केला', 'Banana', ['के', 'ला'], 0),
  ]),
];

const _signs = {'ा', 'ि', 'ी', 'ु', 'ू', 'ृ', 'े', 'ै', 'ो', 'ौ', 'ं', 'ँ', 'ः'};

/// The matra written in [unit] (the last vowel sign), or '' for none.
String matraOf(String unit) {
  for (int i = unit.length - 1; i > 0; i--) {
    if (_signs.contains(unit[i])) return unit[i];
  }
  return '';
}

/// Splits Devanagari text into written blocks: a letter with its nukta,
/// joined letters (्) and signs counts as one block (कि, क्ष्मी, ड़ी).
List<String> aksharas(String text) {
  final out = <String>[];
  for (final ch in text.split('')) {
    final c = ch.codeUnitAt(0);
    final joins = c == 0x094D || c == 0x093C || _signs.contains(ch) || (c >= 0x0962 && c <= 0x0963);
    final afterHalant = out.isNotEmpty && out.last.endsWith('्');
    if (out.isNotEmpty && (joins || afterHalant) && c >= 0x0900 && c <= 0x097F) {
      out[out.length - 1] += ch;
    } else if (ch.trim().isNotEmpty) {
      out.add(ch);
    }
  }
  return out;
}
