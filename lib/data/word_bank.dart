/// Words for the writing practice. [units] are the written blocks (akshara)
/// in order — a consonant with its matra counts as one block (की, रा).
class PracticeWord {
  final String word, meaning;
  final List<String> units;
  final Set<String> tags;
  const PracticeWord(this.word, this.meaning, this.units, this.tags);
}

const practiceWords = <PracticeWord>[
  // Two letters, no matras
  PracticeWord('कम', 'Less', ['क', 'म'], {'easy', 'len2'}),
  PracticeWord('नल', 'Tap', ['न', 'ल'], {'easy', 'len2'}),
  PracticeWord('घर', 'House', ['घ', 'र'], {'easy', 'len2'}),
  PracticeWord('चल', 'Walk', ['च', 'ल'], {'easy', 'len2'}),
  PracticeWord('जल', 'Water', ['ज', 'ल'], {'easy', 'len2'}),
  PracticeWord('फल', 'Fruit', ['फ', 'ल'], {'easy', 'len2'}),
  PracticeWord('बस', 'Bus', ['ब', 'स'], {'easy', 'len2'}),
  PracticeWord('रथ', 'Chariot', ['र', 'थ'], {'easy', 'len2'}),
  PracticeWord('हल', 'Plough', ['ह', 'ल'], {'easy', 'len2'}),
  // Three letters, no matras
  PracticeWord('कमल', 'Lotus', ['क', 'म', 'ल'], {'easy', 'len3'}),
  PracticeWord('नमक', 'Salt', ['न', 'म', 'क'], {'easy', 'len3'}),
  PracticeWord('कलम', 'Pen', ['क', 'ल', 'म'], {'easy', 'len3'}),
  PracticeWord('मगर', 'Crocodile', ['म', 'ग', 'र'], {'easy', 'len3'}),
  PracticeWord('पलक', 'Eyelid', ['प', 'ल', 'क'], {'medium', 'len3'}),
  PracticeWord('बतख', 'Duck', ['ब', 'त', 'ख'], {'medium', 'len3', 'animals'}),
  PracticeWord('सड़क', 'Road', ['स', 'ड़', 'क'], {'medium', 'len3'}),
  PracticeWord('शहर', 'City', ['श', 'ह', 'र'], {'medium', 'len3'}),
  PracticeWord('समय', 'Time', ['स', 'म', 'य'], {'medium', 'len3'}),
  // Animals
  PracticeWord('मोर', 'Peacock', ['मो', 'र'], {'animals'}),
  PracticeWord('गाय', 'Cow', ['गा', 'य'], {'animals'}),
  PracticeWord('शेर', 'Lion', ['शे', 'र'], {'animals'}),
  PracticeWord('हिरन', 'Deer', ['हि', 'र', 'न'], {'animals'}),
  PracticeWord('हाथी', 'Elephant', ['हा', 'थी'], {'animals'}),
  // Fruits
  PracticeWord('आम', 'Mango', ['आ', 'म'], {'fruits'}),
  PracticeWord('केला', 'Banana', ['के', 'ला'], {'fruits'}),
  PracticeWord('सेब', 'Apple', ['से', 'ब'], {'fruits'}),
  PracticeWord('अनार', 'Pomegranate', ['अ', 'ना', 'र'], {'fruits'}),
  PracticeWord('पपीता', 'Papaya', ['प', 'पी', 'ता'], {'fruits'}),
  // Colours
  PracticeWord('लाल', 'Red', ['ला', 'ल'], {'colors'}),
  PracticeWord('हरा', 'Green', ['ह', 'रा'], {'colors'}),
  PracticeWord('नीला', 'Blue', ['नी', 'ला'], {'colors'}),
  PracticeWord('पीला', 'Yellow', ['पी', 'ला'], {'colors'}),
  PracticeWord('काला', 'Black', ['का', 'ला'], {'colors'}),
  // Family
  PracticeWord('पिता', 'Father', ['पि', 'ता'], {'family'}),
  PracticeWord('भाई', 'Brother', ['भा', 'ई'], {'family'}),
  PracticeWord('बहन', 'Sister', ['ब', 'ह', 'न'], {'family'}),
  PracticeWord('दादा', 'Grandfather', ['दा', 'दा'], {'family'}),
  PracticeWord('नाना', "Mother's father", ['ना', 'ना'], {'family'}),
  PracticeWord('चाचा', 'Uncle', ['चा', 'चा'], {'family'}),
  // Matra words
  PracticeWord('पानी', 'Water', ['पा', 'नी'], {'matra'}),
  PracticeWord('रोटी', 'Bread', ['रो', 'टी'], {'matra'}),
  PracticeWord('किताब', 'Book', ['कि', 'ता', 'ब'], {'matra'}),
  PracticeWord('मछली', 'Fish', ['म', 'छ', 'ली'], {'matra'}),
  PracticeWord('तितली', 'Butterfly', ['ति', 'त', 'ली'], {'matra'}),
  PracticeWord('घड़ी', 'Clock', ['घ', 'ड़ी'], {'matra'}),
  // Four letters
  PracticeWord('खटमल', 'Bedbug', ['ख', 'ट', 'म', 'ल'], {'hard', 'len4'}),
  PracticeWord('कसरत', 'Exercise', ['क', 'स', 'र', 'त'], {'hard', 'len4'}),
  PracticeWord('हलचल', 'Movement', ['ह', 'ल', 'च', 'ल'], {'hard', 'len4'}),
  PracticeWord('झटपट', 'Quickly', ['झ', 'ट', 'प', 'ट'], {'hard', 'len4'}),
  PracticeWord('अदरक', 'Ginger', ['अ', 'द', 'र', 'क'], {'hard', 'len4'}),
  PracticeWord('बरतन', 'Utensil', ['ब', 'र', 'त', 'न'], {'hard', 'len4'}),
  // Expert
  PracticeWord('कबूतर', 'Pigeon', ['क', 'बू', 'त', 'र'], {'expert'}),
  PracticeWord('मिठाई', 'Sweets', ['मि', 'ठा', 'ई'], {'expert'}),
  PracticeWord('अखबार', 'Newspaper', ['अ', 'ख', 'बा', 'र'], {'expert'}),
  PracticeWord('चिड़िया', 'Bird', ['चि', 'ड़ि', 'या'], {'expert'}),
  PracticeWord('तरबूज़', 'Watermelon', ['त', 'र', 'बू', 'ज़'], {'expert'}),
];

/// Words for a Word Writing level, from its params (difficulty / wordLength /
/// category). Falls back to every word when nothing matches.
List<PracticeWord> wordsForLevel(Map<String, dynamic> params) {
  final cat = params['category'] as String?;
  final diff = params['difficulty'] as String?;
  final len = params['wordLength'] as int?;
  bool match(PracticeWord w) {
    if (cat != null) return w.tags.contains(cat);
    if (len != null && !w.tags.contains('len$len')) return false;
    if (diff != null && diff != 'easy') return w.tags.contains(diff);
    if (diff == 'easy') return w.tags.contains('easy') || w.tags.contains('medium');
    return true;
  }
  final list = practiceWords.where(match).toList();
  return list.isEmpty ? [...practiceWords] : list;
}
