import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/models.dart';
import '../store/app_store.dart';
import '../theme/app_theme.dart';
import '../theme/palette.dart';
import '../widgets/toy_button.dart';
import '../widgets/progress_bar.dart';
import 'app_shell.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<AppStore>().updateStreak());
  }

  @override
  Widget build(BuildContext context) {
    final (userName, currentStreak, totalStars, mastered) = context.select<AppStore, (String, int, int, int)>(
        (s) => (s.userName, s.currentStreak, s.totalStars, s.masteredCount));
    final w = MediaQuery.of(context).size.width;
    final wide = w >= 768;
    final total = AppData.allLetters.length;
    final pct = total > 0 ? mastered / total : 0.0;
    void goRead() => AppShell.of(context)?.goTo(2);
    void goWrite() => AppShell.of(context)?.goTo(1);

    final cards = [
      _ActivityCard(icon: Icons.grid_view_rounded, tone: const Color(0xFF6E4EDF), title: 'Learn Letters',
          hindi: 'वर्णमाला', desc: 'Vowels, consonants & matras with sound', onTap: goRead),
      _ActivityCard(icon: Icons.edit, tone: const Color(0xFF4FB2E6), title: 'Write & Trace',
          hindi: 'लिखो', desc: 'Trace letters with your finger', onTap: goWrite),
      _ActivityCard(icon: Icons.style, tone: const Color(0xFFF26E97), title: 'Word Cards',
          hindi: 'शब्द', desc: 'Flip cards to learn new words', onTap: goRead),
      _ActivityCard(icon: Icons.help_outline_rounded, tone: const Color(0xFF4EC58A), title: 'Play Quiz',
          hindi: 'खेल', desc: 'Fun questions & earn stars', onTap: goRead),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Sp.md, Sp.md, Sp.md, Sp.xxl),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Hero
                Container(
                  width: double.infinity, clipBehavior: Clip.antiAlias,
                  padding: EdgeInsets.all(wide ? Sp.xl : Sp.lg),
                  margin: EdgeInsets.only(bottom: wide ? Sp.lg : Sp.md),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                        colors: [Color(0xFFF7B46E), AppColors.primary, Color(0xFFE5843A)]),
                    borderRadius: BorderRadius.circular(wide ? Rad.xl3 : Rad.xl2),
                    boxShadow: softShadow(AppColors.primary)),
                  child: Stack(children: [
                    Positioned(
                      top: wide ? -28 : -12, right: wide ? -20 : -12,
                      child: Opacity(opacity: wide ? 0.2 : 0.16,
                          child: Text('🐘', style: TextStyle(fontSize: wide ? 180 : 96)))),
                    Padding(
                      padding: const EdgeInsets.only(right: Sp.sm),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: 6),
                            margin: const EdgeInsets.only(bottom: Sp.sm),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.22),
                                borderRadius: BorderRadius.circular(9999)),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.star, size: 14, color: AppColors.textOnPrimary),
                              const SizedBox(width: 6),
                              Flexible(child: Text('Namaste, $userName! नमस्ते',
                                  style: Fonts.body(13, w: FontWeight.w800, color: AppColors.textOnPrimary))),
                            ]),
                          ),
                          Text("Let's learn to read & write Hindi!",
                              style: Fonts.display(wide ? 38 : 28, color: AppColors.textOnPrimary,
                                  height: wide ? 44 / 38 : 34 / 28)),
                          const SizedBox(height: Sp.sm),
                          Text('Tap letters to hear them, trace to write them, and play games to remember them.',
                              style: Fonts.body(15, color: AppColors.textOnPrimary.withOpacity(0.94),
                                  w: FontWeight.w500, height: 21 / 15)),
                          const SizedBox(height: Sp.md),
                          Pressable(
                            onTap: goWrite,
                            child: Container(
                              constraints: const BoxConstraints(minHeight: 48),
                              padding: const EdgeInsets.symmetric(horizontal: Sp.lg, vertical: 14),
                              decoration: BoxDecoration(color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(9999),
                                  boxShadow: toyShadow(const Color(0xFFC46A22), 5)),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Text('Start learning', style: Fonts.body(16, w: FontWeight.w800, color: AppColors.primary)),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward, size: 18, color: AppColors.primary),
                              ]),
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ]),
                ),
                // Stats
                _statsRow(wide, currentStreak, totalStars, mastered, total, pct),
                const SizedBox(height: Sp.md),
                Padding(
                  padding: const EdgeInsets.only(top: Sp.sm, bottom: Sp.md),
                  child: Text('What do you want to do?', style: Fonts.display(26)),
                ),
                if (wide)
                  LayoutBuilder(builder: (_, c) {
                    final cw = (c.maxWidth - Sp.md) / 2;
                    return Wrap(spacing: Sp.md, runSpacing: Sp.md,
                        children: [for (final c2 in cards) SizedBox(width: cw, child: c2)]);
                  })
                else
                  Column(children: [for (final c2 in cards) Padding(padding: const EdgeInsets.only(bottom: Sp.md), child: c2)]),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _statsRow(bool wide, int currentStreak, int totalStars, int mastered, int total, double pct) {
    final a = _StatCard(icon: Icons.local_fire_department, tint: AppColors.primary,
        value: '$currentStreak', label: 'Day streak');
    final b = _StatCard(icon: Icons.star, tint: AppColors.starGold, value: '$totalStars', label: 'Stars earned');
    final c = Container(
      padding: const EdgeInsets.all(Sp.md),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(Rad.xl),
          border: Border.all(color: AppColors.border), boxShadow: toyShadow(AppColors.toyShadowColor, 3)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Letters learned', style: Fonts.body(14, w: FontWeight.w700, color: AppColors.textSecondary)),
          Text('$mastered/$total', style: Fonts.body(14, w: FontWeight.w800)),
        ]),
        const SizedBox(height: Sp.sm),
        HsProgressBar(progress: pct, height: 12),
      ]),
    );
    if (wide) {
      return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(child: a), const SizedBox(width: Sp.sm),
        Expanded(child: b), const SizedBox(width: Sp.sm),
        Expanded(child: c),
      ]);
    }
    return Column(children: [
      IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(child: a), const SizedBox(width: Sp.sm), Expanded(child: b),
      ])),
      const SizedBox(height: Sp.sm), c,
    ]);
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon; final Color tint; final String value, label;
  const _StatCard({required this.icon, required this.tint, required this.value, required this.label});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(Sp.md),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(Rad.xl),
            border: Border.all(color: AppColors.border), boxShadow: toyShadow(AppColors.toyShadowColor, 3)),
        child: Row(children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [tint.withOpacity(0.14), tint.withOpacity(0.30)]),
              borderRadius: BorderRadius.circular(14)), child: Icon(icon, size: 22, color: shade(tint, 0.08))),
          const SizedBox(width: Sp.sm + 4),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: Fonts.display(26, height: 30 / 26)),
            Text(label, maxLines: 1, softWrap: false, overflow: TextOverflow.fade,
                style: Fonts.body(12.5, w: FontWeight.w700, color: AppColors.textSecondary)),
          ])),
        ]),
      );
}

class _ActivityCard extends StatelessWidget {
  final IconData icon; final Color tone; final String title, hindi, desc; final VoidCallback onTap;
  const _ActivityCard({required this.icon, required this.tone, required this.title,
      required this.hindi, required this.desc, required this.onTap});
  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(Sp.md),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(Rad.xl),
              border: Border.all(color: AppColors.border), boxShadow: toyShadow(AppColors.toyShadowColor, 4)),
          child: Row(children: [
            Container(width: 62, height: 62,
                decoration: BoxDecoration(gradient: toneGradient(tone), borderRadius: BorderRadius.circular(20),
                    boxShadow: toyShadow(shade(tone), 4)),
                child: Icon(icon, size: 30, color: AppColors.textOnPrimary)),
            const SizedBox(width: Sp.md),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                Flexible(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Fonts.display(20))),
                const SizedBox(width: 8),
                Text(hindi, maxLines: 1, style: Fonts.hindi(16, color: AppColors.textSecondary)),
              ]),
              const SizedBox(height: 2),
              Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: Fonts.body(13, color: AppColors.textSecondary, w: FontWeight.w500)),
            ])),
            Container(width: 34, height: 34,
                decoration: BoxDecoration(color: tone.withOpacity(0.12), shape: BoxShape.circle),
                child: Icon(Icons.arrow_forward_rounded, size: 18, color: shade(tone, 0.1))),
          ]),
        ),
      );
}
