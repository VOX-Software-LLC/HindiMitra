import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hindi_mitra/data/audio_qa.dart';
import 'package:hindi_mitra/data/lexicon.dart';
import 'package:hindi_mitra/data/models.dart';
import 'package:hindi_mitra/data/reading_data.dart';
import 'package:hindi_mitra/data/word_bank.dart';
import 'package:hindi_mitra/services/stroke_evaluator.dart';

/// Automated Hindi content and audio QA. Every check is recorded as PASS,
/// WARN or FAIL in docs/qa/content_qa_report.md (regenerated on every run);
/// the test fails on any FAIL. Listening checks a machine cannot do are
/// listed in docs/qa/QA_CHECKLIST.md.
class _Item {
  final String area, item, check, status, note;
  const _Item(this.area, this.item, this.check, this.status, [this.note = '']);
}

final _items = <_Item>[];
void _rec(String area, String item, String check, bool ok, {String note = '', bool warnOnly = false}) =>
    _items.add(_Item(area, item, check, ok ? 'PASS' : (warnOnly ? 'WARN' : 'FAIL'), note));

// ── Devanagari rules ──────────────────────────────────────────────────────
bool _isConsonant(int c) => (c >= 0x0915 && c <= 0x0939) || (c >= 0x0958 && c <= 0x095F);
bool _isIndependentVowel(int c) => (c >= 0x0904 && c <= 0x0914) || c == 0x0960 || c == 0x0961;
bool _isMatra(int c) => (c >= 0x093E && c <= 0x094C) || c == 0x0962 || c == 0x0963;
const _virama = 0x094D, _nukta = 0x093C, _anusvara = 0x0902, _candrabindu = 0x0901, _visarga = 0x0903;
bool _isDevanagari(int c) => c >= 0x0900 && c <= 0x097F;
final _punct = RegExp(r'''[\s।॥,.!?'"–—:;()…0-9/·=+]''');

/// Problems with one Devanagari word, or empty when it is well formed.
List<String> devanagariProblems(String word) {
  final out = <String>[];
  // A matra or sign on its own ("ा") or as a suffix ("-ाल") is how the app
  // names it, not a misspelling.
  final suffix = word.startsWith('-');
  final cs = (suffix ? word.substring(1) : word).runes.toList();
  if (cs.isEmpty || word == '-') return out;
  if (cs.length == 1 && !_isConsonant(cs.first) && !_isIndependentVowel(cs.first)) return out;
  if (cs.any((c) => !_isDevanagari(c)) && cs.any(_isDevanagari)) out.add('mixes scripts');
  final first = cs.first;
  if (!suffix && _isMatra(first) || first == _virama || first == _nukta || first == _anusvara || first == _candrabindu ||
      first == _visarga) {
    out.add('starts with a combining sign');
  }
  for (int i = 1; i < cs.length; i++) {
    final c = cs[i], p = cs[i - 1];
    if (_isMatra(c) && !(_isConsonant(p) || p == _nukta)) out.add('matra after ${String.fromCharCode(p)}');
    if (c == _nukta && !_isConsonant(p)) out.add('nukta not after a consonant');
    if (c == _virama && !(_isConsonant(p) || p == _nukta)) out.add('virama not after a consonant');
    if ((c == _anusvara || c == _candrabindu) && p == _virama) out.add('nasal sign after virama');
    if (_isMatra(c) && _isMatra(p)) out.add('two matras in a row');
  }
  if (cs.length > 1 && cs.last == _virama) out.add('ends with virama');
  if (cs.any((c) => c >= 0x0958 && c <= 0x095F)) out.add('precomposed nukta letter (use consonant + ़)');
  if (cs.any((c) => c == 0x200C || c == 0x200D)) out.add('zero-width joiner');
  return out;
}

/// Every Devanagari string anywhere inside [v], with a path to it.
Iterable<(String, String)> _hindiStrings(Object? v, String path) sync* {
  if (v is String) {
    if (v.runes.any(_isDevanagari)) yield (path, v);
  } else if (v is List) {
    for (int i = 0; i < v.length; i++) { yield* _hindiStrings(v[i], '$path[$i]'); }
  } else if (v is Map) {
    for (final e in v.entries) { yield* _hindiStrings(e.value, '$path.${e.key}'); }
  }
}

/// The rhyming part of a word: its last consonant + matra, or last matra +
/// consonant, or the last consonant with its inherent "a".
String rime(String w) {
  final cs = w.runes.toList();
  if (cs.length < 2) return w;
  final last = cs.last, prev = cs[cs.length - 2];
  if (_isMatra(last) || _isMatra(prev)) return String.fromCharCodes(cs.sublist(cs.length - 2));
  return 'अ${String.fromCharCode(last)}';
}

// ── MP3 ────────────────────────────────────────────────────────────────────
const _br1 = [0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320];
const _br2 = [0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160];

/// Duration in seconds of an MPEG Layer III file, or null when no valid frames.
double? mp3Seconds(List<int> b) {
  int i = 0;
  if (b.length > 10 && b[0] == 0x49 && b[1] == 0x44 && b[2] == 0x33) {
    i = 10 + ((b[6] & 0x7f) << 21 | (b[7] & 0x7f) << 14 | (b[8] & 0x7f) << 7 | (b[9] & 0x7f));
  }
  double secs = 0;
  int frames = 0;
  while (i + 4 <= b.length) {
    if (b[i] != 0xFF || (b[i + 1] & 0xE0) != 0xE0) { i++; continue; }
    final ver = (b[i + 1] >> 3) & 3, layer = (b[i + 1] >> 1) & 3;
    final bri = (b[i + 2] >> 4) & 15, sri = (b[i + 2] >> 2) & 3, pad = (b[i + 2] >> 1) & 1;
    if (layer != 1 || bri == 0 || bri == 15 || sri == 3 || ver == 1) { i++; continue; }
    final mpeg1 = ver == 3;
    final sr = (mpeg1 ? [44100, 48000, 32000] : ver == 2 ? [22050, 24000, 16000] : [11025, 12000, 8000])[sri];
    final br = (mpeg1 ? _br1 : _br2)[bri] * 1000;
    final len = (mpeg1 ? 144 : 72) * br ~/ sr + pad;
    if (len < 4) { i++; continue; }
    secs += (mpeg1 ? 1152 : 576) / sr;
    frames++;
    i += len;
  }
  return frames == 0 ? null : secs;
}

const _numberWords = ['शून्य', 'एक', 'दो', 'तीन', 'चार', 'पाँच', 'छह', 'सात', 'आठ', 'नौ', 'दस', 'ग्यारह', 'बारह', 'तेरह',
  'चौदह', 'पंद्रह', 'सोलह', 'सत्रह', 'अठारह', 'उन्नीस', 'बीस'];

void main() {
  late List<Map<String, dynamic>> catalog, letters;
  late Map<String, dynamic> matras;

  setUpAll(() {
    final st = json.decode(File('assets/data/stroke_templates.json').readAsStringSync()) as Map;
    AppData.strokeTemplates = st.map((k, v) => MapEntry(k as String, StrokeTemplate.fromJson(v)));
    catalog = (json.decode(File('assets/data/audio_catalog.json').readAsStringSync()) as List).cast<Map<String, dynamic>>();
    final l = json.decode(File('assets/data/letters.json').readAsStringSync()) as Map;
    letters = [...(l['vowels'] as List), ...(l['consonants'] as List)].cast<Map<String, dynamic>>();
    matras = json.decode(File('assets/data/matras.json').readAsStringSync()) as Map<String, dynamic>;
  });

  test('Hindi content and audio QA', () {
    // 1. Audio catalog ↔ files.
    final files = {for (final f in Directory('assets/audio').listSync().whereType<File>()) f.uri.pathSegments.last};
    final byId = <String, Map<String, dynamic>>{}, idsByText = <String, Set<String>>{};
    for (final e in catalog) {
      final id = e['id'] as String, text = e['text'] as String;
      _rec('Audio catalog', id, 'listed once', !byId.containsKey(id), note: 'duplicate entry for "$text"', warnOnly: true);
      byId[id] = e;
      (idsByText[text] ??= {}).add(id);
    }
    for (final t in idsByText.entries) {
      _rec('Audio catalog', t.key, 'one clip per text', t.value.length == 1, note: t.value.join(', '));
    }
    final bytesById = <String, List<int>>{};
    for (final e in byId.values) {
      final id = e['id'] as String, text = e['text'] as String;
      final f = File('assets/audio/$id.mp3');
      final exists = f.existsSync();
      _rec('Audio file', '$id ($text)', 'file exists', exists);
      if (!exists) continue;
      final b = f.readAsBytesSync();
      bytesById[id] = b;
      final secs = mp3Seconds(b);
      _rec('Audio file', '$id ($text)', 'valid MP3', secs != null);
      if (secs != null) {
        final cat = e['category'];
        final lo = cat == 'phrase' ? 0.6 : 0.25, hi = cat == 'phrase' ? 8.0 : 4.0;
        _rec('Audio file', '$id ($text)', 'duration ${secs.toStringAsFixed(2)} s in $lo-$hi s', secs >= lo && secs <= hi);
      }
      _rec('Audio file', '$id ($text)', 'passed listening QA', !audioClipsFailedQa.contains(id),
          note: 'replaced at runtime by the device Hindi voice; needs re-recording', warnOnly: true);
    }
    for (final f in files.where((f) => f.endsWith('.mp3'))) {
      _rec('Audio file', f, 'listed in catalog', byId.containsKey(f.replaceAll('.mp3', '')), warnOnly: true);
    }
    // The same recording used for two different texts means one is wrong.
    // A matra sounds exactly like its vowel, so sharing the recording is fine.
    final soundsAlike = <String>{
      for (final m in (matras['matras'] as List)) '${m['vowelBase']}|${m['symbol']}',
      'ऋ|ृ', 'अं|ं', 'अः|ः',
    };
    final ids = bytesById.keys.toList();
    for (int i = 0; i < ids.length; i++) {
      for (int j = i + 1; j < ids.length; j++) {
        final a = bytesById[ids[i]]!, b = bytesById[ids[j]]!;
        final ta = byId[ids[i]]!['text'], tb = byId[ids[j]]!['text'];
        if (a.length == b.length && _same(a, b) && ta != tb && !soundsAlike.contains('$ta|$tb') &&
            !soundsAlike.contains('$tb|$ta')) {
          _rec('Audio file', '${ids[i]} / ${ids[j]}', 'distinct recordings for distinct texts', false,
              note: 'byte-identical: "${byId[ids[i]]!['text']}" and "${byId[ids[j]]!['text']}"');
        }
      }
    }

    // 2. Letters: audio, example word, stroke template, transliteration.
    for (final l in letters) {
      final id = l['id'] as String, ch = l['character'] as String, ex = l['exampleWord'] as String;
      _rec('Letter', '$id $ch', 'letter audio matches text', byId['letter_$id']?['text'] == ch,
          note: 'catalog has "${byId['letter_$id']?['text']}"');
      _rec('Letter', '$id $ch', 'example word audio', idsByText.containsKey(ex), note: ex);
      final starts = ex.startsWith(ch) || (ch == 'अः' && ex.contains('ः'));
      _rec('Letter', '$id $ch', 'example word contains the letter', starts || ex.contains(ch), note: ex);
      final t = AppData.strokeTemplates[id];
      _rec('Letter', '$id $ch', 'stroke template', t != null && t.character == ch);
      if (t != null) {
        _rec('Letter', '$id $ch', 'stroke count ${l['strokeCount']} = template ${t.strokes.length}',
            t.strokes.length == l['strokeCount']);
      }
      _rec('Letter', '$id $ch', 'romanized + pronunciation present',
          (l['romanized'] as String).isNotEmpty && (l['pronunciation'] as String).isNotEmpty);
    }
    final roman = {for (final l in letters) l['character'] as String: l['romanized'] as String};
    for (final m in (matras['matras'] as List)) {
      _rec('Matra', '${m['symbol']}', 'audio', idsByText.containsKey(m['symbol']), warnOnly: true);
      _rec('Matra', '${m['symbol']}', 'romanized matches its vowel ${m['vowelBase']}', roman[m['vowelBase']] == m['romanized'],
          note: 'vowel is "${roman[m['vowelBase']]}"');
    }

    // 3. Spelling: every Devanagari string in the app's content.
    final sources = <String, Object?>{
      'practiceWords': [for (final w in practiceWords) {'word': w.word, 'units': w.units}],
      'letters': letters, 'matras': matras, 'audioCatalog': catalog,
      'stories': storiesData, 'practiceItems': practiceItemsData, 'pictureMatch': pictureMatchData,
      'wordBuilder': wordBuilderData, 'fillBlank': fillBlankData, 'numbers': hindiNumbersData,
      'letterSound': letterSoundData, 'letterPairs': letterPairsData, 'wordSpeed': wordSpeedData,
      'rhymes': rhymeSetsData, 'oddOneOut': oddOneOutData, 'dialogues': dialoguesData, 'vocab': vocabCategoriesData,
      'coreLexicon': [for (final l in coreLexicon) {'hindi': l.hindi, 'note': l.note}],
    };
    final seen = <String>{};
    for (final src in sources.entries) {
      for (final (path, text) in _hindiStrings(src.value, src.key)) {
        for (final w in text.split(_punct)) {
          if (w.isEmpty || !seen.add(w)) continue;
          final p = devanagariProblems(w);
          _rec('Spelling', w, 'well-formed Devanagari', p.isEmpty, note: p.isEmpty ? path : '${p.join('; ')} ($path)');
        }
      }
    }

    // 4. Practice words: blocks spell the word and can be graded.
    for (final w in practiceWords) {
      _rec('Practice word', w.word, 'blocks join to the word', w.units.join() == w.word, note: w.units.join(' + '));
      for (final u in w.units) {
        _rec('Practice word', '${w.word} · $u', 'block has a writing model', strokesForText(u) != null, warnOnly: true);
      }
    }
    for (final w in wordBuilderData) {
      _rec('Word builder', w['word'], 'pieces join to the word', (w['letters'] as List).join() == w['word']);
    }

    // 5. Quizzes: the right answer is offered once, options are distinct.
    for (final f in fillBlankData) {
      final o = (f['options'] as List).cast<String>();
      _rec('Fill blank', f['sentence'], 'answer among options', o.contains(f['blank']));
      _rec('Fill blank', f['sentence'], 'options distinct', o.toSet().length == o.length);
    }
    for (final q in oddOneOutData) {
      final w = (q['words'] as List).cast<String>();
      _rec('Odd one out', w.join(' '), 'words distinct', w.toSet().length == w.length);
      final odd = w[q['oddIndex'] as int];
      _rec('Odd one out', w.join(' '), 'explanation names the odd word', (q['explanation'] as String).contains(odd),
          note: 'odd = $odd');
    }
    for (final r in rhymeSetsData) {
      final base = rime(r['word'] as String);
      for (final x in (r['rhymes'] as List).cast<String>()) {
        _rec('Rhymes', '${r['word']} ~ $x', 'shares the ending ${base.replaceAll('अ', '-')}', rime(x) == base);
      }
      for (final x in (r['nonRhymes'] as List).cast<String>()) {
        _rec('Rhymes', '${r['word']} ≠ $x', 'does not share the ending', rime(x) != base);
      }
    }
    for (final q in letterSoundData) {
      final o = (q['options'] as List).cast<String>();
      _rec('Letter sound', q['letter'], 'answer among options', o.contains(q['correct']));
      _rec('Letter sound', q['letter'], 'answer = letter romanization "${roman[q['letter']]}"',
          roman[q['letter']] == null || roman[q['letter']] == q['correct'] || '${roman[q['letter']]}' == '${q['correct']}a',
          note: 'quiz says "${q['correct']}"');
    }
    final hints = <String, String>{};
    for (final p in letterPairsData) {
      final pair = (p['pair'] as List).cast<String>(), h = (p['hints'] as List).cast<String>();
      for (int i = 0; i < 2; i++) {
        final prev = hints[h[i]];
        _rec('Letter pairs', pair[i], 'hint unique', prev == null || prev == pair[i], note: '"${h[i]}" also used for $prev');
        hints[h[i]] = pair[i];
      }
    }
    for (final n in hindiNumbersData) {
      final v = n['english'] as int;
      _rec('Numbers', '${n['digit']}', 'word for $v', v < _numberWords.length && _numberWords[v] == n['hindiWord'],
          note: '${n['hindiWord']}');
      final digits = '$v'.split('').map((d) => String.fromCharCode(0x0966 + int.parse(d))).join();
      _rec('Numbers', '${n['digit']}', 'Devanagari digit for $v', digits == n['digit']);
    }

    _writeReport();
    final fails = _items.where((i) => i.status == 'FAIL').toList();
    expect(fails.map((f) => '${f.area} | ${f.item} | ${f.check} | ${f.note}').toList(), isEmpty);
  });
}

bool _same(List<int> a, List<int> b) {
  for (int i = 0; i < a.length; i++) { if (a[i] != b[i]) return false; }
  return true;
}

void _writeReport() {
  final dir = Directory('docs/qa')..createSync(recursive: true);
  final count = {for (final s in ['PASS', 'WARN', 'FAIL']) s: _items.where((i) => i.status == s).length};
  final b = StringBuffer()
    ..writeln('# Hindi content & audio QA report')
    ..writeln()
    ..writeln('Generated by `flutter test test/content_qa_test.dart` — do not edit by hand.')
    ..writeln()
    ..writeln('**${_items.length} checks:** ${count['PASS']} pass · ${count['WARN']} warn · ${count['FAIL']} fail')
    ..writeln()
    ..writeln('Listening (does each clip *sound* right?) cannot be automated — see [QA_CHECKLIST.md](QA_CHECKLIST.md).')
    ..writeln();
  for (final status in ['FAIL', 'WARN']) {
    final list = _items.where((i) => i.status == status).toList();
    b.writeln('## $status (${list.length})');
    b.writeln();
    if (list.isEmpty) b.writeln('None.');
    if (list.isNotEmpty) {
      b.writeln('| Area | Item | Check | Note |');
      b.writeln('|---|---|---|---|');
      for (final i in list) { b.writeln('| ${i.area} | ${i.item} | ${i.check} | ${i.note.replaceAll('|', '/')} |'); }
    }
    b.writeln();
  }
  final areas = <String, List<_Item>>{};
  for (final i in _items) { (areas[i.area] ??= []).add(i); }
  b.writeln('## Summary by area');
  b.writeln();
  b.writeln('| Area | Checks | Pass | Warn | Fail |');
  b.writeln('|---|---|---|---|---|');
  for (final a in areas.entries) {
    int n(String s) => a.value.where((i) => i.status == s).length;
    b.writeln('| ${a.key} | ${a.value.length} | ${n('PASS')} | ${n('WARN')} | ${n('FAIL')} |');
  }
  File('${dir.path}/content_qa_report.md').writeAsStringSync(b.toString());
}
