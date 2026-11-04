import 'package:flutter_test/flutter_test.dart';
import 'package:hindi_mitra/util/transliterate.dart';

void main() {
  test('common names get a sensible first spelling', () {
    expect(toDevanagari('Priya'), 'प्रिया');
    expect(toDevanagari('Rohan'), 'रोहन');
    expect(toDevanagari('Neha'), 'नेहा');
    expect(toDevanagari('Anjali'), 'अंजली');
    expect(toDevanagari('Amit Sharma'), 'अमित शर्मा');
  });
  test('variants include the other sh sound', () {
    expect(spellingVariants(toDevanagari('Abhishek')), contains('अभिषेक'));
  });
}
