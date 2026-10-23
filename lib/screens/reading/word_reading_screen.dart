import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/speech_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../../widgets/common.dart';
import '../../widgets/progress_bar.dart';
import '../../widgets/quiz_common.dart';
import '../../util/num_ext.dart';

class _Syl {
  final String text, romanized;
  const _Syl(this.text, this.romanized);
}

class _Word {
  final String word, meaning, difficulty;
  final List<_Syl> syllables;
  const _Word(this.word, this.meaning, this.syllables, this.difficulty);
}

const _words = <_Word>[
  _Word('कमल', 'Lotus', [_Syl('क', 'ka'), _Syl('म', 'ma'), _Syl('ल', 'la')], 'easy'),
  _Word('नमक', 'Salt', [_Syl('न', 'na'), _Syl('म', 'ma'), _Syl('क', 'ka')], 'easy'),
  _Word('घर', 'House', [_Syl('घ', 'gha'), _Syl('र', 'ra')], 'easy'),
  _Word('पानी', 'Water', [_Syl('पा', 'paa'), _Syl('नी', 'nee')], 'easy'),
  _Word('खरगोश', 'Rabbit', [_Syl('ख', 'kha'), _Syl('र', 'ra'), _Syl('गो', 'go'), _Syl('श', 'sha')], 'medium'),
  _Word('तरबूज', 'Watermelon', [_Syl('त', 'ta'), _Syl('र', 'ra'), _Syl('बू', 'boo'), _Syl('ज', 'ja')], 'medium'),
  _Word('किताब', 'Book', [_Syl('कि', 'ki'), _Syl('ता', 'taa'), _Syl('ब', 'ba')], 'medium'),
  _Word('सपेरा', 'Snake charmer', [_Syl('स', 'sa'), _Syl('पे', 'pe'), _Syl('रा', 'raa')], 'medium'),
  _Word('हाथी', 'Elephant', [_Syl('हा', 'haa'), _Syl('थी', 'thee')], 'easy'),
  _Word('मछली', 'Fish', [_Syl('म', 'ma'), _Syl('छ', 'chha'), _Syl('ली', 'lee')], 'medium'),
  _Word('तितली', 'Butterfly', [_Syl('ति', 'ti'), _Syl('त', 'ta'), _Syl('ली', 'lee')], 'medium'),
  _Word('चम्मच', 'Spoon', [_Syl('च', 'cha'), _Syl('म्म', 'mma'), _Syl('च', 'cha')], 'hard'),
];

/// WordReadingScreen.tsx — tap syllables, play the full word, reveal the meaning.
class WordReadingScreen extends StatefulWidget {
  final Map<String, dynamic> params;
  const WordReadingScreen({super.key, this.params = const {}});
  @override
  State<WordReadingScreen> createState() => _WordReadingScreenState();
}

class _WordReadingScreenState extends State<WordReadingScreen> {
  int idx = 0;
  int? active;
  Set<int> revealed = {};
  bool showMeaning = false;
  Timer? _iv, _clear;

  @override
  void dispose() { _iv?.cancel(); _clear?.cancel(); super.dispose(); }

  _Word get word => _words[idx.clampI(0, _words.length - 1)];

  void _tap(int i) {
    setState(() { active = i; revealed = {...revealed, i}; });
    speakHindi(word.syllables[i].text, rate: 0.6);
    _clear?.cancel();
    _clear = Timer(const Duration(milliseconds: 600), () { if (mounted) setState(() => active = null); });
  }

  void _playWord() {
    final w = word;
    speakSyllables(w.syllables.map((s) => s.text).toList(), delayMs: 600);
    int i = 0;
    _iv?.cancel();
    _iv = Timer.periodic(const Duration(milliseconds: 600), (t) {
      if (!mounted) { t.cancel(); return; }
      if (i < w.syllables.length) {
        final cur = i;
        setState(() { active = cur; revealed = {...revealed, cur}; });
        i++;
      } else {
        setState(() => active = null);
        t.cancel();
        Timer(const Duration(milliseconds: 300), () => speakHindi(w.word, rate: 0.8));
      }
    });
  }

  void _go(int d) {
    final n = idx + d;
    if (n < 0 || n >= _words.length) return;
    _iv?.cancel();
    setState(() { idx = n; active = null; revealed = {}; showMeaning = false; });
  }

  @override
  Widget build(BuildContext context) {
    final w = word;
    final all = revealed.length == w.syllables.length;
    final accents = [Palette.light.purple, Palette.light.green, Palette.light.sky, Palette.light.pink, Palette.light.sunny];
    final diffColor = w.difficulty == 'easy' ? AppColors.success : w.difficulty == 'medium' ? AppColors.warning : AppColors.error;

    return ScreenScaffold(child: Column(children: [
      HeaderBar(title: 'Word Reading', subtitle: 'शब्द पढ़ना', onBack: () => Navigator.of(context).maybePop()),
      HsProgressBar(progress: (idx + 1) / _words.length, height: 4),
      Expanded(child: screenScroll(
        padding: const EdgeInsets.all(Sp.md),
        child: Column(children: [
          Padding(padding: const EdgeInsets.only(bottom: Sp.md), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.xs),
              decoration: BoxDecoration(color: diffColor.withOpacity(0.13), borderRadius: BorderRadius.circular(9999),
                  border: Border.all(color: diffColor.withOpacity(0.33))),
              child: Text(w.difficulty.toUpperCase(), style: Fonts.body(12, w: FontWeight.w800, color: AppColors.textPrimary).copyWith(letterSpacing: 0.6)),
            ),
            Text('${idx + 1} / ${_words.length}', style: Fonts.body(12, w: FontWeight.w700, color: AppColors.textSecondary)),
          ])),
          Container(
            key: ValueKey(idx), width: double.infinity, padding: const EdgeInsets.all(Sp.xl),
            margin: const EdgeInsets.only(bottom: Sp.lg),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(Rad.xl),
                border: Border.all(color: AppColors.border), boxShadow: toyShadow(AppColors.toyShadowColor, 4)),
            child: Column(children: [
              Padding(padding: const EdgeInsets.only(bottom: Sp.lg),
                  child: Text('Tap each syllable to hear it', textAlign: TextAlign.center,
                      style: Fonts.body(16, w: FontWeight.w500, color: AppColors.textSecondary))),
              Padding(padding: const EdgeInsets.only(bottom: Sp.xl), child: Wrap(spacing: Sp.md, runSpacing: Sp.md, alignment: WrapAlignment.center, children: [
                for (int i = 0; i < w.syllables.length; i++) _syllable(i, w.syllables[i], accents[i % accents.length]),
              ])),
              GestureDetector(
                onTap: _playWord,
                child: Container(
                  margin: const EdgeInsets.only(bottom: Sp.md),
                  padding: const EdgeInsets.symmetric(horizontal: Sp.lg, vertical: Sp.sm + 2),
                  decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.09), borderRadius: BorderRadius.circular(9999),
                      border: Border.all(color: AppColors.primary.withOpacity(0.33))),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.play_circle_fill, size: 28, color: AppColors.primary), const SizedBox(width: Sp.sm),
                    Text('Play full word', style: Fonts.body(14, w: FontWeight.w800, color: AppColors.primaryDark)),
                  ]),
                ),
              ),
              if (all) GestureDetector(
                onTap: showMeaning ? null : () => setState(() => showMeaning = true),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: Sp.md, horizontal: Sp.xl),
                  decoration: BoxDecoration(color: AppColors.readingModule.withOpacity(0.06), borderRadius: BorderRadius.circular(Rad.lg),
                      border: Border.all(color: AppColors.readingModule.withOpacity(0.4), width: 2)),
                  child: showMeaning
                      ? Column(children: [
                          Text('MEANING:', style: Fonts.body(12, w: FontWeight.w700, color: AppColors.textSecondary).copyWith(letterSpacing: 0.6)),
                          const SizedBox(height: Sp.xs),
                          Text(w.meaning, style: Fonts.display(20, color: AppColors.readingModule)),
                        ])
                      : Text('Tap to reveal meaning', style: Fonts.body(16, w: FontWeight.w700, color: AppColors.readingModule)),
                ),
              ),
            ]),
          ),
          Row(children: [
            Expanded(child: GestureDetector(
              onTap: idx == 0 ? null : () => _go(-1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: Sp.md),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(9999), border: Border.all(color: AppColors.primary, width: 2)),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.chevron_left, size: 24, color: idx > 0 ? AppColors.primary : AppColors.disabled),
                  Text('Previous', style: Fonts.body(16, w: FontWeight.w800, color: idx == 0 ? AppColors.disabled : AppColors.primary)),
                ]),
              ),
            )),
            const SizedBox(width: Sp.md),
            Expanded(child: GestureDetector(
              onTap: idx >= _words.length - 1 ? null : () => _go(1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: Sp.md),
                decoration: BoxDecoration(gradient: toneGradient(AppColors.primary), borderRadius: BorderRadius.circular(9999),
                    border: Border.all(color: AppColors.primary, width: 2), boxShadow: toyShadow(AppColors.primaryDark, 6)),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('Next Word', style: Fonts.body(16, w: FontWeight.w800, color: AppColors.textOnPrimary)),
                  const Icon(Icons.chevron_right, size: 24, color: Colors.white),
                ]),
              ),
            )),
          ]),
        ]),
      )),
    ]));
  }

  Widget _syllable(int i, _Syl s, Color accent) {
    final isActive = active == i, isRev = revealed.contains(i);
    return GestureDetector(
      onTap: () => _tap(i),
      child: AnimatedScale(
        scale: isActive ? 1.1 : 1, duration: const Duration(milliseconds: 150),
        child: Container(
          constraints: const BoxConstraints(minWidth: 80),
          padding: const EdgeInsets.symmetric(vertical: Sp.md, horizontal: Sp.lg),
          decoration: BoxDecoration(
            color: isActive ? accent : isRev ? accent.withOpacity(0.09) : AppColors.surface,
            borderRadius: BorderRadius.circular(9999),
            border: Border.all(color: isRev || isActive ? accent : AppColors.border, width: 2),
            boxShadow: isActive || isRev ? toyShadow(accent, 3) : null),
          child: Column(children: [
            Text(s.text, style: Fonts.hindi(40, color: isActive ? Colors.white : AppColors.textPrimary, height: 48 / 40)),
            if (isRev) Padding(padding: const EdgeInsets.only(top: Sp.xs),
                child: Text(s.romanized, style: Fonts.body(12, w: FontWeight.w800, color: isActive ? Colors.white : accent).copyWith(letterSpacing: 0.4))),
          ]),
        ),
      ),
    );
  }
}
