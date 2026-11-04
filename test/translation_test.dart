import 'package:flutter_test/flutter_test.dart';
import 'package:hindi_mitra/screens/translation_screen.dart';

void main() {
  final d = Dict();

  test('every meaning of a word is kept, not just the first one found', () {
    final water = d.word('water').map((s) => s.text).toList();
    expect(water, containsAll(['पानी', 'जल']));
    expect(d.hiToEn['कल']!.map((s) => s.text.toLowerCase()), containsAll(['tomorrow', 'yesterday']));
  });

  test('gendered words come with all forms and a note', () {
    final my = d.word('my');
    expect(my.map((s) => s.text), ['मेरा', 'मेरी', 'मेरे']);
    expect(my.first.note, contains('f.'));
  });

  test('plurals and two-word phrases are looked up', () {
    expect(d.word('apples').map((s) => s.text), contains('सेब'));
    expect(d.tokens('thank you friend'), ['thank you', 'friend']);
    expect(d.word('thank you').first.text, 'धन्यवाद');
  });

  test('whole sentences only come from checked lesson pairs', () {
    expect(d.sentences[Dict.norm('My name is Ram')], 'मेरा नाम राम है');
    expect(d.sentences[Dict.norm('My name is Rahul.')], 'मेरा नाम राहुल है');
    expect(d.sentences[Dict.norm('the dog eats a red apple')], isNull);
  });

  test('unknown words are reported as unknown, never guessed', () {
    expect(d.word('xylophone'), isEmpty);
  });
}
