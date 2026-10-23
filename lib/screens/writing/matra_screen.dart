import 'package:flutter/material.dart';
import '../../data/models.dart';
import '../../services/speech_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../../widgets/common.dart';

class MatraScreen extends StatefulWidget {
  final Map<String, dynamic> params;
  const MatraScreen({super.key, this.params = const {}});
  @override
  State<MatraScreen> createState() => _MatraScreenState();
}

class _MatraScreenState extends State<MatraScreen> {
  late Matra selected = AppData.matras.first;
  static final _accents = [Palette.light.purple, Palette.light.green, Palette.light.sky, Palette.light.pink, Palette.light.sunny];

  @override
  Widget build(BuildContext context) {
    final combos = AppData.combinationsFor(selected.id);
    final examples = AppData.matraExamples[selected.id] ?? [];
    Widget label(String t) => Padding(
        padding: const EdgeInsets.only(top: Sp.lg, bottom: Sp.sm), child: Text(t, style: Fonts.display(18)));
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          HeaderBar(title: 'Matra Practice', subtitle: 'मात्रा अभ्यास', onBack: () => Navigator.of(context).maybePop()),
          Expanded(child: screenScroll(
            padding: const EdgeInsets.all(Sp.md),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              label('Select a Matra'),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(top: Sp.xs, bottom: Sp.md),
                child: Row(children: [
                  for (int i = 0; i < AppData.matras.length; i++) ...[
                    if (i > 0) const SizedBox(width: Sp.sm),
                    _chip(AppData.matras[i], _accents[i % _accents.length]),
                  ],
                ]),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Container(
                  key: ValueKey(selected.id),
                  width: double.infinity, padding: const EdgeInsets.all(Sp.lg),
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(Rad.xl2),
                      boxShadow: softShadow(AppColors.primary)),
                  child: Row(children: [
                    Column(children: [
                      Text(selected.symbol, style: Fonts.hindi(72, color: AppColors.textOnPrimary, height: 88 / 72)),
                      Text('from ${selected.vowelBase}', style: Fonts.body(12, w: FontWeight.w600, color: AppColors.textOnPrimary.withOpacity(0.85))),
                    ]),
                    const SizedBox(width: Sp.lg),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(selected.name, style: Fonts.display(18, color: AppColors.textOnPrimary)),
                      Padding(padding: const EdgeInsets.only(bottom: Sp.sm),
                          child: Text(selected.pronunciation, style: Fonts.body(16, w: FontWeight.w600, color: AppColors.textOnPrimary.withOpacity(0.9)))),
                      GestureDetector(
                        onTap: () => speakHindi(selected.vowelBase, rate: 0.6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: 6),
                          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(9999),
                              boxShadow: toyShadow(AppColors.toyShadowColor, 3)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.volume_up, size: 18, color: AppColors.primary),
                            const SizedBox(width: Sp.xs),
                            Text('Listen', style: Fonts.body(12, w: FontWeight.w800, color: AppColors.primary)),
                          ]),
                        ),
                      ),
                    ])),
                  ]),
                ),
              ),
              label('Consonant + ${selected.symbol}'),
              Wrap(spacing: Sp.sm, runSpacing: Sp.sm + 4, children: [for (final c in combos) _combo(c)]),
              if (examples.isNotEmpty) ...[
                label('Example Words'),
                for (final ex in examples)
                  GestureDetector(
                    onTap: () => speakHindi(ex['word']!, rate: 0.7),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: Sp.sm + 4), padding: const EdgeInsets.all(Sp.md),
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(Rad.xl),
                          border: Border.all(color: AppColors.border), boxShadow: toyShadow(AppColors.toyShadowColor, 4)),
                      child: Row(children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(ex['word']!, style: Fonts.hindi(28, height: 40 / 28)),
                          Text(ex['meaning']!, style: Fonts.body(16, w: FontWeight.w600, color: AppColors.textSecondary)),
                        ])),
                        const Icon(Icons.volume_up_outlined, size: 20, color: AppColors.primary),
                      ]),
                    ),
                  ),
              ],
              const SizedBox(height: Sp.xxl * 2),
            ]),
          )),
        ]),
      ),
    );
  }

  Widget _chip(Matra m, Color accent) {
    final active = selected.id == m.id;
    return GestureDetector(
      onTap: () => setState(() => selected = m),
      child: Container(
        constraints: const BoxConstraints(minWidth: 64),
        padding: const EdgeInsets.symmetric(horizontal: Sp.lg, vertical: Sp.sm),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : accent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(9999),
          border: Border.all(color: active ? AppColors.primary : accent.withOpacity(0.33), width: 2),
          boxShadow: active ? toyShadow(AppColors.primaryDark, 4) : null),
        child: Column(children: [
          Text(m.symbol.isEmpty ? '(none)' : m.symbol,
              style: Fonts.hindi(28, color: active ? AppColors.textOnPrimary : accent, height: 36 / 28)),
          Padding(padding: const EdgeInsets.only(top: 2),
              child: Text(m.romanized, style: Fonts.body(10, w: FontWeight.w800,
                  color: active ? AppColors.textOnPrimary.withOpacity(0.9) : AppColors.textSecondary))),
        ]),
      ),
    );
  }

  Widget _combo(MatraCombination c) => GestureDetector(
        onTap: () => speakHindi(c.combined, rate: 0.6),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: Sp.sm, horizontal: Sp.md),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(Rad.xl),
              border: Border.all(color: AppColors.border), boxShadow: toyShadow(AppColors.toyShadowColor, 4)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(c.consonant, style: Fonts.hindi(22)),
            const SizedBox(width: 4),
            Text('+', style: Fonts.body(12, w: FontWeight.w700, color: AppColors.textSecondary)),
            const SizedBox(width: 4),
            Text(c.matra, style: Fonts.hindi(22, color: AppColors.primaryDark)),
            const SizedBox(width: 4),
            Text('=', style: Fonts.body(12, w: FontWeight.w700, color: AppColors.textSecondary)),
            const SizedBox(width: 4),
            Text(c.combined, style: Fonts.hindi(24, color: AppColors.primaryDark)),
            const SizedBox(width: 6),
            Text(c.romanized, style: Fonts.body(12, w: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(width: 4),
            const Icon(Icons.volume_down, size: 14, color: AppColors.textSecondary),
          ]),
        ),
      );
}
