/// Rough English → Devanagari spelling for names ("Abhishek" → "अभिशेक").
/// Names often have more than one correct spelling, so the result is a first
/// guess the user can correct (see [spellingVariants]).
String toDevanagari(String input) =>
    input.trim().split(RegExp(r'\s+')).map(_word).where((w) => w.isNotEmpty).join(' ');

const _consonants = <String, String>{
  'ksh': 'क्ष', 'chh': 'छ', 'kh': 'ख', 'gh': 'घ', 'ch': 'च', 'jh': 'झ', 'th': 'थ', 'dh': 'ध', 'ph': 'फ',
  'bh': 'भ', 'sh': 'श', 'gy': 'ज्ञ', 'k': 'क', 'g': 'ग', 'c': 'क', 'j': 'ज', 'z': 'ज़', 't': 'त', 'd': 'द',
  'n': 'न', 'p': 'प', 'f': 'फ़', 'b': 'ब', 'm': 'म', 'y': 'य', 'r': 'र', 'l': 'ल', 'v': 'व', 'w': 'व',
  's': 'स', 'h': 'ह', 'q': 'क', 'x': 'क्स',
};
const _vowels = <String, (String, String)>{
  // spelling: (letter on its own, matra after a consonant)
  'aa': ('आ', 'ा'), 'ai': ('ऐ', 'ै'), 'au': ('औ', 'ौ'), 'ee': ('ई', 'ी'), 'ii': ('ई', 'ी'),
  'oo': ('ऊ', 'ू'), 'uu': ('ऊ', 'ू'), 'a': ('अ', ''), 'i': ('इ', 'ि'), 'u': ('उ', 'ु'), 'e': ('ए', 'े'),
  'o': ('ओ', 'ो'),
};
const _halant = '्';

String? _match(Map<String, Object> m, String s, int i) {
  for (final len in [3, 2, 1]) {
    if (i + len <= s.length && m.containsKey(s.substring(i, i + len))) return s.substring(i, i + len);
  }
  return null;
}

String _word(String raw) {
  final s = raw.toLowerCase().replaceAll(RegExp('[^a-z]'), '');
  final out = StringBuffer();
  int i = 0;
  while (i < s.length) {
    final c = _match(_consonants, s, i);
    if (c != null) {
      i += c.length;
      final v = _match(_vowels, s, i);
      final nextIsConsonant = v == null && i < s.length;
      // "n" before another consonant is usually the nasal dot: Anjali → अंजलि.
      if (c == 'n' && nextIsConsonant && !'yhvrn'.contains(s[i])) {
        out.write('ं');
        continue;
      }
      out.write(_consonants[c]);
      if (v != null) {
        i += v.length;
        final atEnd = i >= s.length;
        // Names ending in -a / -i are usually long: Priya → प्रिया, Lakshmi → लक्ष्मी.
        if (atEnd && v == 'a') {
          out.write('ा');
        } else if (atEnd && v == 'i') {
          out.write('ी');
        } else {
          out.write(_vowels[v]!.$2);
        }
      } else if (nextIsConsonant) {
        out.write(_halant);
      }
      continue;
    }
    final v = _match(_vowels, s, i);
    if (v != null) {
      out.write(_vowels[v]!.$1);
      i += v.length;
      continue;
    }
    i++;
  }
  return out.toString();
}

const _romanCons = <String, String>{
  'क': 'k', 'ख': 'kh', 'ग': 'g', 'घ': 'gh', 'ङ': 'ng', 'च': 'ch', 'छ': 'chh', 'ज': 'j', 'झ': 'jh', 'ञ': 'ny',
  'ट': 't', 'ठ': 'th', 'ड': 'd', 'ढ': 'dh', 'ण': 'n', 'त': 't', 'थ': 'th', 'द': 'd', 'ध': 'dh', 'न': 'n',
  'प': 'p', 'फ': 'ph', 'ब': 'b', 'भ': 'bh', 'म': 'm', 'य': 'y', 'र': 'r', 'ल': 'l', 'व': 'v', 'श': 'sh',
  'ष': 'sh', 'स': 's', 'ह': 'h',
};
/// Consonant + nukta.
const _romanNukta = <String, String>{'क': 'q', 'ख': 'kh', 'ग': 'g', 'ज': 'z', 'ड': 'r', 'ढ': 'rh', 'फ': 'f'};
const _romanVowels = <String, String>{
  'अ': 'a', 'आ': 'aa', 'इ': 'i', 'ई': 'ee', 'उ': 'u', 'ऊ': 'oo', 'ऋ': 'ri', 'ए': 'e', 'ऐ': 'ai', 'ओ': 'o', 'औ': 'au',
};
const _romanMatras = <String, String>{
  'ा': 'aa', 'ि': 'i', 'ी': 'ee', 'ु': 'u', 'ू': 'oo', 'ृ': 'ri', 'े': 'e', 'ै': 'ai', 'ो': 'o', 'ौ': 'au',
};

/// Simple pronunciation guide for Devanagari ("मछली" → "machhlee"), in the
/// same spelling the app uses for letters (aa, ee, oo …). The inherent "a"
/// is dropped at the end of a word and between a sounded syllable and a
/// consonant that carries its own vowel, as Hindi speakers do; it's a reading
/// aid, not a strict transliteration standard.
String toRoman(String hindi) => hindi.split(RegExp(r'(\s+)')).map(_romanWord).join(' ');

String _romanWord(String w) {
  // Syllables: (consonant sound, vowel) — vowel null = inherent "a", '' = none (virama).
  final syl = <(String, String?)>[];
  final cs = w.split('');
  final tail = StringBuffer();
  for (int i = 0; i < cs.length; i++) {
    final c = cs[i];
    if (_romanCons.containsKey(c)) {
      var cons = _romanCons[c]!;
      if (i + 1 < cs.length && cs[i + 1] == '़') { cons = _romanNukta[c] ?? cons; i++; }
      String? v;
      if (i + 1 < cs.length && _romanMatras.containsKey(cs[i + 1])) { v = _romanMatras[cs[i + 1]]; i++; }
      else if (i + 1 < cs.length && cs[i + 1] == '्') { v = ''; i++; }
      syl.add((cons, v));
    } else if (_romanVowels.containsKey(c)) {
      syl.add(('', _romanVowels[c]));
    } else if (c == 'ं' || c == 'ँ') {
      syl.add(('n', ''));
    } else if (c == 'ः') {
      syl.add(('h', ''));
    } else if (c != '़') {
      tail.write(c);
    }
  }
  // Schwa deletion: last syllable, and medially in V C(a) C V.
  final out = [for (final s in syl) s.$2];
  for (int k = 0; k < syl.length; k++) {
    if (syl[k].$2 != null || syl[k].$1.isEmpty) continue;
    final last = k == syl.length - 1;
    final prevVowel = k > 0 && (out[k - 1] ?? 'a').isNotEmpty;
    final nextFull = k + 1 < syl.length && syl[k + 1].$1.isNotEmpty && syl[k + 1].$2 != '' &&
        !(k + 1 == syl.length - 1 && syl[k + 1].$2 == null);
    if ((last && syl.length > 1) || (prevVowel && nextFull && k > 0)) out[k] = '';
  }
  final b = StringBuffer();
  for (int k = 0; k < syl.length; k++) {
    b..write(syl[k].$1)..write(out[k] ?? 'a');
  }
  return '$b$tail';
}

/// Other likely spellings of [hindi], one look-alike sound changed at a time
/// (श/ष/स, त/ट, द/ड, ि/ी, ु/ू …), for quick correction.
List<String> spellingVariants(String hindi, {int max = 8}) {
  const groups = [['श', 'ष', 'स'], ['त', 'ट'], ['थ', 'ठ'], ['द', 'ड'], ['ध', 'ढ'], ['न', 'ण'], ['ि', 'ी'], ['ु', 'ू'], ['व', 'ब']];
  final out = <String>{};
  for (int i = 0; i < hindi.length && out.length < max; i++) {
    for (final g in groups) {
      if (!g.contains(hindi[i])) continue;
      for (final alt in g) {
        if (alt == hindi[i]) continue;
        out.add(hindi.substring(0, i) + alt + hindi.substring(i + 1));
        if (out.length >= max) break;
      }
    }
  }
  out.remove(hindi);
  return out.toList();
}
