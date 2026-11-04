import 'package:flutter_test/flutter_test.dart';
import 'package:hindi_mitra/util/transliterate.dart';

void main() {
  test('pronunciation guide for common words', () {
    const cases = {
      'नमस्ते': 'namaste', 'किताब': 'kitaab', 'कमल': 'kamal', 'मछली': 'machhlee', 'पानी': 'paanee',
      'घर': 'ghar', 'सड़क': 'sarak', 'धन्यवाद': 'dhanyavaad', 'अनार': 'anaar', 'हाथी': 'haathee',
      'मेरा नाम': 'meraa naam', 'अंगूर': 'angoor', 'बहन': 'bahan', 'आम': 'aam',
    };
    for (final e in cases.entries) {
      expect(toRoman(e.key), e.value, reason: e.key);
    }
  });
}
