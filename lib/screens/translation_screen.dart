import 'package:flutter/material.dart';
import '../data/lexicon.dart';
import '../data/reading_data.dart';
import '../data/word_bank.dart';
import '../l10n.dart';
import '../services/speech_service.dart';
import '../theme/app_theme.dart';
import '../util/transliterate.dart';
import '../theme/palette.dart';
import '../widgets/common.dart';
import '../widgets/toy_button.dart';

/// One translation of a word: the Hindi (or English) text, plus a usage note.
class Sense {
  final String text, note;
  const Sense(this.text, [this.note = '']);
}

/// English ⇄ Hindi dictionary built from HindiMitra's own lesson data and the
/// hand-checked [coreLexicon] (offline). Every meaning is kept — "water" gives
/// both पानी and जल, "कल" both yesterday and tomorrow — instead of the first
/// one found. Whole sentences come only from verified lesson pairs.
class Dict {
  final Map<String, List<Sense>> enToHi = {}, hiToEn = {};
  final Map<String, String> sentences = {};
  /// English headwords from the core lexicon that span two words ("thank you").
  final Set<String> phrases = {};

  Dict() {
    void add(Object? en, Object? hi, [String note = '']) {
      if (en == null || hi == null) return;
      final e = norm('$en'), h = '$hi'.trim();
      if (e.isEmpty || h.isEmpty) return;
      final list = enToHi[e] ??= [];
      if (!list.any((x) => x.text == h)) list.add(Sense(h, note));
      final back = hiToEn[h] ??= [];
      final en2 = '$en'.trim();
      if (!back.any((x) => x.text.toLowerCase() == en2.toLowerCase())) back.add(Sense(en2));
    }

    // The core lexicon goes first so its notes (gender, number) lead.
    for (final l in coreLexicon) {
      for (final en in l.english) {
        if (en.contains(' ')) phrases.add(en);
        for (int i = 0; i < l.hindi.length; i++) { add(en, l.hindi[i], i == 0 ? l.note : ''); }
      }
    }
    for (final w in practiceWords) { add(w.meaning, w.word); }
    for (final c in vocabCategoriesData) {
      for (final w in (c['words'] as List)) { add(w['english'], w['hindi']); }
    }
    for (final w in wordSpeedData) { add(w['english'], w['hindi']); }
    for (final w in pictureMatchData) { add(w['meaning'], w['word']); }
    for (final w in wordBuilderData) { add(w['meaning'], w['word']); }
    for (final n in hindiNumbersData) { add(n['english'], n['hindiWord']); }
    for (final st in storiesData) {
      for (final sent in (st['sentences'] as List)) {
        // Proper names and function words in stories are glossed elsewhere.
        for (final w in (sent['words'] as List)) {
          final m = '${w['meaning']}';
          if (m.isNotEmpty && m[0] == m[0].toLowerCase()) add(m, w['hindi']);
        }
        if (sent['english'] != null && sent['fullHindi'] != null) sentences[norm(sent['english'])] = sent['fullHindi'];
      }
    }
    for (final f in fillBlankData) {
      sentences[norm(f['english'])] = (f['sentence'] as String).replaceAll('___', f['blank'] as String);
    }
  }

  static String norm(String s) => s.toLowerCase().replaceAll(RegExp(r"[^a-z0-9' ]"), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

  /// Every Hindi sense of an English word (plural -s/-es tried too), or empty.
  List<Sense> word(String en) {
    final e = norm(en);
    if (e.isEmpty) return const [];
    for (final c in [e, if (e.endsWith('es')) e.substring(0, e.length - 2), if (e.endsWith('s')) e.substring(0, e.length - 1)]) {
      final h = enToHi[c];
      if (h != null) return h;
    }
    return const [];
  }

  /// [text] split into dictionary units: two-word phrases ("thank you") stay together.
  List<String> tokens(String text) {
    final words = text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final out = <String>[];
    for (int i = 0; i < words.length; i++) {
      if (i + 1 < words.length && phrases.contains(norm('${words[i]} ${words[i + 1]}'))) {
        out.add('${words[i]} ${words[i + 1]}');
        i++;
      } else {
        out.add(words[i]);
      }
    }
    return out;
  }
}

final _dict = Dict();

/// Translation preview (from the Upcoming tab): word-by-word English ⇄ Hindi
/// using the words HindiMitra already teaches. Full-sentence translation is
/// the upcoming feature; this shows how it will look.
class TranslationScreen extends StatefulWidget {
  const TranslationScreen({super.key});
  @override
  State<TranslationScreen> createState() => _TranslationScreenState();
}

class _TranslationScreenState extends State<TranslationScreen> {
  final _ctrl = TextEditingController();
  bool _hiToEn = false;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  static const _examples = ['My name is Ram', 'apple banana mango', 'red blue green', 'mother father', 'water house book'];

  @override
  Widget build(BuildContext context) {
    final text = _ctrl.text.trim();
    final full = _hiToEn ? null : _dict.sentences[Dict.norm(text)];
    final words = text.isEmpty ? <String>[] : _hiToEn ? text.split(RegExp(r'\s+')) : _dict.tokens(text);
    final pairs = [
      for (final w in words)
        (w, _hiToEn ? (_dict.hiToEn[w.replaceAll(RegExp(r'[।,.!?]'), '')] ?? const <Sense>[]) : _dict.word(w)),
    ];
    final unknown = pairs.where((p) => p.$2.isEmpty).length;
    return Scaffold(
      body: SafeArea(bottom: false, child: Column(children: [
        HeaderBar(title: tr('Translation', 'अनुवाद'), subtitle: tr('Preview · झलक', 'झलक'),
            onBack: () => Navigator.of(context).maybePop()),
        Expanded(child: screenScroll(maxWidth: 720, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.all(Sp.md),
            decoration: BoxDecoration(color: const Color(0xFF1E88E5).withOpacity(0.10), borderRadius: BorderRadius.circular(Rad.lg),
                border: Border.all(color: const Color(0xFF1E88E5).withOpacity(0.35))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF1565C0)),
              const SizedBox(width: Sp.sm),
              Expanded(child: Text(
                  tr('Uses HindiMitra\'s checked word list (${_dict.enToHi.length} English words) and works offline. '
                          'Whole sentences are shown only when they are a checked lesson sentence; otherwise you get each word '
                          'with every meaning — words it doesn\'t know are marked, never guessed.',
                      'हिन्दी मित्र की जाँची हुई शब्द-सूची (${_dict.enToHi.length} शब्द) से, बिना इंटरनेट। पूरा वाक्य तभी दिखता है जब वह '
                          'पाठ का जाँचा हुआ वाक्य हो; नहीं तो हर शब्द के सभी अर्थ। अनजान शब्द चिह्नित होते हैं, अनुमान नहीं लगाया जाता।'),
                  style: Fonts.body(13, w: FontWeight.w600, color: AppColors.textPrimary, height: 1.4))),
            ]),
          ),
          const SizedBox(height: Sp.md),
          Row(children: [
            Expanded(child: Text(_hiToEn ? 'हिन्दी → English' : 'English → हिन्दी', style: Fonts.display(20))),
            PillButton(label: tr('Swap', 'बदलें'), icon: Icons.swap_horiz_rounded,
                onTap: () => setState(() { _hiToEn = !_hiToEn; _ctrl.clear(); })),
          ]),
          const SizedBox(height: Sp.sm),
          TextField(
            controller: _ctrl, minLines: 2, maxLines: 4, onChanged: (_) => setState(() {}),
            style: Fonts.body(18, w: FontWeight.w600),
            decoration: InputDecoration(
              hintText: _hiToEn ? 'जैसे: सेब पानी घर' : tr('Type in English, e.g. apple water house', 'अंग्रेज़ी में लिखें, जैसे: apple water house'),
              hintStyle: Fonts.body(16, color: AppColors.textSecondary),
              filled: true, fillColor: AppColors.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.lg), borderSide: BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.lg), borderSide: BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.lg), borderSide: BorderSide(color: AppColors.primary, width: 2)),
            ),
          ),
          if (!_hiToEn && text.isEmpty) ...[
            const SizedBox(height: Sp.sm),
            Wrap(spacing: Sp.sm, runSpacing: Sp.sm, children: [
              for (final e in _examples) PillButton(label: e, onTap: () => setState(() => _ctrl.text = e)),
            ]),
          ],
          if (full != null) ...[
            const SizedBox(height: Sp.md),
            _resultCard(full, big: true),
          ],
          if (pairs.isNotEmpty) ...[
            const SizedBox(height: Sp.md),
            Text(tr('Word by word', 'शब्द-दर-शब्द'), style: Fonts.display(18)),
            if (!_hiToEn && full == null && words.length > 1) Text(
                tr('Hindi puts the verb last (मैं दूध पीता हूँ = I milk drink), so the words below are not yet a sentence.',
                    'हिन्दी में क्रिया अंत में आती है, इसलिए नीचे के शब्द अभी वाक्य नहीं हैं।'),
                style: Fonts.body(12.5, w: FontWeight.w600, color: AppColors.textSecondary)),
            if (unknown > 0) Text(
                tr('$unknown not in the word list yet (shown as ?).', '$unknown शब्द अभी सूची में नहीं (? से दिखाए गए)।'),
                style: Fonts.body(12.5, w: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: Sp.sm),
            Wrap(spacing: Sp.sm, runSpacing: Sp.sm, children: [
              for (final (src, out) in pairs) _wordChip(src, out),
            ]),
          ],
          const SizedBox(height: Sp.xxl),
        ]))),
      ])),
    );
  }

  Widget _resultCard(String hindi, {bool big = false}) => Container(
        padding: const EdgeInsets.all(Sp.md),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(Rad.xl),
            border: Border.all(color: AppColors.success.withOpacity(0.6), width: 1.5), boxShadow: toyShadow(AppColors.toyShadowColor, 4)),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(hindi, style: Fonts.hindi(big ? 26 : 20, height: 1.4)),
            Text(toRoman(hindi), style: Fonts.body(13, w: FontWeight.w600, color: AppColors.textSecondary)),
          ])),
          IconButton(onPressed: () => speakDevice(hindi), icon: Icon(Icons.volume_up_rounded, color: AppColors.primary)),
        ]),
      );

  Widget _wordChip(String src, List<Sense> senses) {
    final known = senses.isNotEmpty;
    final first = known ? senses.first : null;
    final hindiOut = !_hiToEn;
    final speakText = hindiOut ? first?.text : src;
    final note = first?.note ?? '';
    return Pressable(
      onTap: known && speakText != null ? () => speakDevice(speakText) : null,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 260),
        padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.sm),
        decoration: BoxDecoration(
          color: known ? AppColors.surface : AppColors.muted,
          borderRadius: BorderRadius.circular(Rad.lg),
          border: Border.all(color: known ? AppColors.border : Colors.transparent),
          boxShadow: known ? toyShadow(AppColors.toyShadowColor, 2) : null),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_hiToEn ? '$src · ${toRoman(src)}' : src,
              style: Fonts.body(13, w: FontWeight.w700, color: AppColors.textSecondary)),
          if (!known)
            Text('?', style: Fonts.body(17, w: FontWeight.w800, color: AppColors.textSecondary))
          else if (hindiOut) ...[
            Text(first!.text, style: Fonts.hindi(20)),
            Text(toRoman(first.text), style: Fonts.body(12, w: FontWeight.w600, color: AppColors.textSecondary)),
            if (senses.length > 1) Text('also: ${senses.skip(1).map((x) => x.text).join(' · ')}',
                style: Fonts.hindi(14, color: AppColors.textSecondary)),
          ] else
            Text(senses.map((x) => x.text).join(' · '), style: Fonts.body(16, w: FontWeight.w800)),
          if (note.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2),
              child: Text(note, style: Fonts.body(11, w: FontWeight.w600, color: AppColors.textMuted))),
          if (!hindiOut && senses.length > 1) Text('meaning depends on the sentence',
              style: Fonts.body(11, w: FontWeight.w600, color: AppColors.textMuted)),
        ]),
      ),
    );
  }
}
