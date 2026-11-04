import 'package:flutter/material.dart';
import '../../data/models.dart';
import '../../services/speech_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../../widgets/common.dart';
import '../../widgets/toy_button.dart';

/// Letter flashcards: one plain study card at a time with everything to
/// remember on it (letter, sound, example word). Swipe or use Back / Next.
class FlashcardsScreen extends StatefulWidget {
  final Map<String, dynamic> params;
  const FlashcardsScreen({super.key, this.params = const {}});
  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen> {
  static const _sections = [('all', 'All'), ('vowel', 'स्वर'), ('consonant', 'व्यंजन'), ('special', 'विशेष')];
  /// Joined letters क्ष त्र ज्ञ (the last three in letters.json); व्यंजन is the 33 before them.
  static const _specialCount = 3;

  final _pages = PageController();
  int index = 0;
  bool speaking = false;
  late String filter = switch (widget.params['pool']) {
    'vowels' => 'vowel',
    'consonants' => 'consonant',
    'special' => 'special',
    _ => 'all',
  };

  List<HindiLetter> get letters {
    final cons = AppData.consonants;
    return switch (filter) {
      'vowel' => AppData.vowels,
      'consonant' => cons.sublist(0, cons.length - _specialCount),
      'special' => cons.sublist(cons.length - _specialCount),
      _ => AppData.allLetters,
    };
  }

  @override
  void dispose() { _pages.dispose(); super.dispose(); }

  void _setSection(String g) {
    if (g == filter) return;
    setState(() { filter = g; index = 0; });
    _pages.jumpToPage(0);
  }

  /// Next card; after the last one, back to the first (every button always works).
  void _goNext() {
    if (index < letters.length - 1) {
      _pages.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    } else {
      _pages.jumpToPage(0);
    }
  }

  /// Previous card; on the first one, the last card.
  void _goPrev() {
    if (index > 0) {
      _pages.previousPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    } else {
      _pages.jumpToPage(letters.length - 1);
    }
  }

  /// Plays the letter and its example; the Listen button is highlighted while it speaks.
  void _listen(HindiLetter l) {
    speakLetterWithGuide(l.character, l.pronunciation, l.exampleWord);
    setState(() => speaking = true);
    Future.delayed(const Duration(milliseconds: 1600), () { if (mounted) setState(() => speaking = false); });
  }

  @override
  Widget build(BuildContext context) {
    final ls = letters;
    final letter = ls[index.clamp(0, ls.length - 1)];
    final last = index >= ls.length - 1;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(bottom: false, child: Column(children: [
        HeaderBar(title: 'Flashcards', subtitle: 'फ्लैशकार्ड', onBack: () => Navigator.of(context).maybePop()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Sp.md),
          child: _SectionTabs(sections: _sections, value: filter, onChanged: _setSection),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: Sp.sm),
          child: Text.rich(TextSpan(style: Fonts.body(13, w: FontWeight.w600, color: AppColors.textSecondary), children: [
            TextSpan(text: '${index + 1}', style: Fonts.body(13, w: FontWeight.w800, color: AppColors.textPrimary)),
            TextSpan(text: ' / ${ls.length}'),
          ])),
        ),
        Expanded(child: PageView.builder(
          controller: _pages,
          itemCount: ls.length,
          onPageChanged: (i) => setState(() => index = i),
          itemBuilder: (_, i) => Center(child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: Sp.lg, vertical: Sp.sm),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: _StudyCard(letter: ls[i], onListen: () => _listen(ls[i])),
            ),
          )),
        )),
        Padding(
          padding: const EdgeInsets.fromLTRB(Sp.md, Sp.sm, Sp.md, Sp.lg),
          child: Center(child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Row(children: [
              Expanded(child: _BarButton(icon: Icons.arrow_back_rounded, label: 'Back', onTap: _goPrev)),
              const SizedBox(width: Sp.sm),
              Expanded(child: _BarButton(icon: speaking ? Icons.graphic_eq_rounded : Icons.volume_up_rounded,
                  label: 'Listen', active: speaking, onTap: () => _listen(letter))),
              const SizedBox(width: Sp.sm),
              Expanded(child: _BarButton(icon: last ? Icons.replay_rounded : Icons.arrow_forward_rounded,
                  label: last ? 'Start over' : 'Next', filled: true, iconAfter: !last, onTap: _goNext)),
            ]),
          )),
        ),
      ])),
    );
  }
}

/// Segmented control for the four sections.
class _SectionTabs extends StatelessWidget {
  final List<(String, String)> sections;
  final String value;
  final ValueChanged<String> onChanged;
  const _SectionTabs({required this.sections, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(Rad.lg),
            border: Border.all(color: AppColors.border)),
        child: Row(children: [
          for (final (g, label) in sections) Expanded(child: Semantics(
            button: true, selected: value == g, label: label,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(g),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: Sp.sm),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: value == g ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(Rad.lg - 3)),
                child: Text(label, maxLines: 1, style: Fonts.body(13, w: FontWeight.w800,
                    color: value == g ? AppColors.textOnPrimary : AppColors.textSecondary)),
              ),
            ),
          )),
        ]),
      );
}

/// The card: letter, how it sounds, and the example word to remember.
class _StudyCard extends StatelessWidget {
  final HindiLetter letter;
  final VoidCallback onListen;
  const _StudyCard({required this.letter, required this.onListen});
  @override
  Widget build(BuildContext context) {
    final l = letter;
    final group = l.group == 'vowel' ? 'स्वर · Vowel' : 'व्यंजन · Consonant';
    Text label(String s) => Text(s.toUpperCase(),
        style: Fonts.body(11, w: FontWeight.w700, color: AppColors.textMuted).copyWith(letterSpacing: 0.8));
    return Container(
      padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.md, Sp.lg, Sp.lg),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(Rad.xl2),
          border: Border.all(color: AppColors.border), boxShadow: softShadow()),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: label(group)),
          IconButton(onPressed: onListen, tooltip: 'Listen', color: AppColors.primary,
              icon: const Icon(Icons.volume_up_rounded)),
        ]),
        Center(child: Text(l.character, style: Fonts.hindi(120, color: AppColors.textPrimary, height: 1.35))),
        const SizedBox(height: Sp.xs),
        Center(child: Text(l.romanized, style: Fonts.body(22, w: FontWeight.w800, color: AppColors.primaryDark))),
        const SizedBox(height: 2),
        Center(child: Text('"${l.pronunciation}"', textAlign: TextAlign.center,
            style: Fonts.body(14, w: FontWeight.w600, color: AppColors.textSecondary))),
        Padding(padding: const EdgeInsets.symmetric(vertical: Sp.md), child: Divider(height: 1, color: AppColors.border)),
        label('Example'),
        const SizedBox(height: Sp.xs),
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Text(l.exampleWord, style: Fonts.hindi(30, color: AppColors.textPrimary, height: 1.35)),
          const SizedBox(width: Sp.md),
          Expanded(child: Text(l.exampleMeaning,
              style: Fonts.body(15, w: FontWeight.w600, color: AppColors.textSecondary))),
        ]),
      ]),
    );
  }
}

/// A plain labelled button in the bar under the card; [filled] is the main action.
class _BarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled, active, iconAfter;
  final VoidCallback onTap;
  const _BarButton({required this.icon, required this.label, required this.onTap,
      this.filled = false, this.active = false, this.iconAfter = false});
  @override
  Widget build(BuildContext context) {
    final fg = filled ? AppColors.textOnPrimary : AppColors.primaryDark;
    final i = Icon(icon, size: 20, color: fg);
    return Semantics(
      button: true, label: label,
      child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: Sp.sm),
          decoration: BoxDecoration(
            color: filled ? AppColors.primary : active ? AppColors.primary.withOpacity(0.12) : AppColors.surface,
            borderRadius: BorderRadius.circular(Rad.lg),
            border: Border.all(color: filled || active ? AppColors.primary : AppColors.border)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (!iconAfter) ...[i, const SizedBox(width: 6)],
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: Fonts.body(14, w: FontWeight.w800, color: fg))),
            if (iconAfter) ...[const SizedBox(width: 6), i],
          ]),
        ),
      ),
    );
  }
}
