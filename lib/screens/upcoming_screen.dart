import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n.dart';
import '../store/app_store.dart';
import '../theme/app_theme.dart';
import '../theme/palette.dart';
import '../widgets/menu_tiles.dart';
import '../widgets/toy_button.dart';
import 'translation_screen.dart';

class _Feature {
  final String id, emoji, title, hindi, what, why;
  final Color color;
  final bool preview;
  const _Feature(this.id, this.emoji, this.title, this.hindi, this.what, this.why, this.color, {this.preview = false});
}

const _features = [
  _Feature('translation', '🔁', 'Translation', 'अनुवाद',
      'Type or say a sentence in English and see it in Hindi — and back again — with the Devanagari, how to say it, and a listen button.',
      'So you can use Hindi in real life: messages, signs, menus and homework.',
      Color(0xFF1E88E5), preview: true),
  _Feature('languages', '🌏', 'Learn from your language', 'अपनी भाषा से सीखें',
      'Learn Hindi through Marathi, Bengali, Tamil, Telugu, Gujarati, Punjabi, Kannada, Malayalam, Urdu, Odia, Spanish, French, Arabic and more.',
      'Everyone learns best in the language they already know.',
      Color(0xFF00897B)),
  _Feature('handwriting', '🤖', 'Smart handwriting check', 'स्मार्ट लिखावट जाँच',
      'An AI checker that reads whole words you write, not just single strokes, and shows exactly which part to fix.',
      'Faster, friendlier feedback — like a teacher looking over your shoulder.',
      Color(0xFF6E4EDF)),
  _Feature('speech', '🎙️', 'Speak & score', 'बोलो और अंक पाओ',
      'Real pronunciation scoring with the microphone. (Today the Pronunciation Coach is for practice only.)',
      'Speaking is half of a language — this makes it count.',
      Color(0xFFE91E63)),
  _Feature('stories', '📚', 'Story library with audio', 'आवाज़ वाली कहानियाँ',
      'Dozens of short Hindi stories read aloud, with tap-a-word meanings and a quiz after each one.',
      'Reading real stories is the best way to grow vocabulary.',
      Color(0xFFF57C00)),
  _Feature('classes', '🏫', 'Classes & teachers', 'कक्षा और शिक्षक',
      'Class codes, homework, and a teacher dashboard to follow every student.',
      'So schools and tutors can use HindiMitra together.',
      Color(0xFF3949AB)),
  _Feature('sync', '☁️', 'Family accounts & sync', 'परिवार खाता',
      'Sign in to keep progress safe across phones, tablets and the web, with a profile for each child.',
      'Never lose stars and streaks when you change devices.',
      Color(0xFF0288D1)),
  _Feature('certificates', '🏅', 'Certificates', 'प्रमाण पत्र',
      'Finish all tests in a course and get a certificate you can share or print.',
      'A proud moment — and proof of what you have learned.',
      Color(0xFFC0A000)),
];

/// Upcoming tab: what is being built next and why, with "Remind me" toggles
/// and a working preview of Translation.
class UpcomingScreen extends StatelessWidget {
  const UpcomingScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Sp.md, Sp.md, Sp.md, Sp.xxl),
          child: Center(child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              HeroBanner(color: const Color(0xFF3949AB), icon: const Text('🚀', style: TextStyle(fontSize: 28)),
                  title: 'जल्द आ रहा है', subtitle: tr('Coming soon', 'जल्द आ रहा है'),
                  stats: [('${_features.length}', tr('New features', 'नई सुविधाएँ'))]),
              Padding(
                padding: const EdgeInsets.fromLTRB(Sp.xs, Sp.md, Sp.xs, Sp.sm),
                child: Text(
                    tr('HindiMitra keeps growing. Here is what we are building next, what each feature will do, and why it matters. Tap "Remind me" on the ones you want most.',
                        'हिन्दी मित्र लगातार बढ़ रहा है। आगे क्या आ रहा है, वह क्या करेगा और क्यों ज़रूरी है — यहाँ देखें। जो आपको सबसे ज़्यादा चाहिए उस पर "याद दिलाएँ" दबाएँ।'),
                    style: Fonts.body(14, w: FontWeight.w600, color: AppColors.textSecondary, height: 1.45)),
              ),
              LayoutBuilder(builder: (_, c) {
                final cols = c.maxWidth >= 760 ? 2 : 1;
                final w = (c.maxWidth - Sp.md * (cols - 1)) / cols;
                return Wrap(spacing: Sp.md, runSpacing: Sp.md, children: [
                  for (final f in _features) SizedBox(width: w, child: _FeatureCard(f)),
                ]);
              }),
            ]),
          )),
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final _Feature f;
  const _FeatureCard(this.f);
  @override
  Widget build(BuildContext context) {
    final on = context.select<AppStore, bool>((s) => s.notifyFeatures.contains(f.id));
    return Container(
      padding: const EdgeInsets.all(Sp.md),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(Rad.xl),
          border: Border.all(color: f.preview ? f.color.withOpacity(0.55) : AppColors.border, width: f.preview ? 1.5 : 1),
          boxShadow: toyShadow(AppColors.toyShadowColor, 4)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 50, height: 50, alignment: Alignment.center,
              decoration: BoxDecoration(gradient: toneGradient(f.color), borderRadius: BorderRadius.circular(16)),
              child: Text(f.emoji, style: const TextStyle(fontSize: 24))),
          const SizedBox(width: Sp.md),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(f.title, style: Fonts.display(18, height: 1.2)),
            Text(f.hindi, style: Fonts.hindi(13, color: AppColors.textSecondary)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: f.color.withOpacity(0.12), borderRadius: BorderRadius.circular(9999)),
            child: Text(f.preview ? tr('PREVIEW', 'झलक') : tr('SOON', 'जल्द'),
                style: Fonts.body(10, w: FontWeight.w800, color: shade(f.color, 0.1)).copyWith(letterSpacing: 0.5)),
          ),
        ]),
        const SizedBox(height: Sp.sm),
        Text(f.what, style: Fonts.body(13.5, w: FontWeight.w600, height: 1.4)),
        const SizedBox(height: 6),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.lightbulb_outline_rounded, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Expanded(child: Text(f.why, style: Fonts.body(12.5, color: AppColors.textSecondary, height: 1.35))),
        ]),
        const SizedBox(height: Sp.sm),
        Wrap(spacing: Sp.sm, runSpacing: Sp.sm, children: [
          if (f.preview) ToyButton(label: tr('Try the preview', 'झलक देखें'), size: ToySize.sm,
              onPressed: () => Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(builder: (_) => const TranslationScreen())),
              trailing: Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.textOnPrimary)),
          Pressable(
            onTap: () => context.read<AppStore>().toggleNotifyFeature(f.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: on ? f.color.withOpacity(0.12) : AppColors.background,
                borderRadius: BorderRadius.circular(9999),
                border: Border.all(color: on ? f.color : AppColors.border)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(on ? Icons.notifications_active_rounded : Icons.notifications_none_rounded, size: 16,
                    color: on ? f.color : AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(on ? tr('Reminder on', 'याद दिलाएँगे') : tr('Remind me', 'याद दिलाएँ'),
                    style: Fonts.body(13, w: FontWeight.w800, color: on ? shade(f.color, 0.1) : AppColors.textSecondary)),
              ]),
            ),
          ),
        ]),
      ]),
    );
  }
}
