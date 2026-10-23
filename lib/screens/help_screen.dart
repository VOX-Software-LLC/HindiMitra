import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/reading_data.dart';
import '../theme/app_theme.dart';
import '../theme/palette.dart';
import '../widgets/common.dart';

IconData _icon(String n) => const {
      'rocket-outline': Icons.rocket_launch_outlined,
      'pencil-outline': Icons.edit_outlined,
      'book-outline': Icons.menu_book_outlined,
      'trophy-outline': Icons.emoji_events_outlined,
      'settings-outline': Icons.settings_outlined,
    }[n] ?? Icons.circle_outlined;

/// HelpScreen.tsx
class HelpScreen extends StatelessWidget {
  final Map<String, dynamic> params;
  const HelpScreen({super.key, this.params = const {}});

  @override
  Widget build(BuildContext context) {
    final sections = faqData.cast<Map>();
    return Scaffold(backgroundColor: AppColors.background, body: SafeArea(bottom: false, child: Column(children: [
      HeaderBar(title: 'Help & Support', subtitle: 'सहायता', onBack: () => Navigator.of(context).maybePop()),
      Expanded(child: screenScroll(padding: const EdgeInsets.all(Sp.md), maxWidth: 720, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          margin: const EdgeInsets.only(bottom: Sp.lg), padding: const EdgeInsets.all(Sp.md),
          decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(Rad.xl2), boxShadow: softShadow(AppColors.primary)),
          child: Row(children: [
            Container(width: 48, height: 48, decoration: const BoxDecoration(color: Color(0x38FFFFFF), shape: BoxShape.circle),
                child: const Icon(Icons.mail, size: 28, color: Colors.white)),
            const SizedBox(width: Sp.md),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Need more help?', style: Fonts.display(16, color: AppColors.textOnPrimary, w: FontWeight.w800)),
              Text('support@hindimitra.app', style: Fonts.body(12, w: FontWeight.w500, color: const Color(0xD9FEFCF4))),
            ])),
            const SizedBox(width: Sp.md),
            GestureDetector(
              onTap: () => launchUrl(Uri.parse('mailto:support@hindimitra.app?subject=HindiMitra%20Support')),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.sm),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(9999), boxShadow: toyShadow(AppColors.toyShadowColor, 3)),
                child: Text('Email Us', style: Fonts.body(13, w: FontWeight.w800, color: AppColors.primaryDark)),
              ),
            ),
          ]),
        ),
        for (final s in sections) ...[
          Padding(padding: const EdgeInsets.only(top: Sp.md, bottom: Sp.sm), child: Row(children: [
            Container(width: 32, height: 32, decoration: BoxDecoration(color: hexColor(s['color']).withAlpha(0x20), shape: BoxShape.circle),
                child: Icon(_icon(s['icon']), size: 18, color: hexColor(s['color']))),
            const SizedBox(width: Sp.sm),
            Text(s['title'], style: Fonts.display(16, color: AppColors.textPrimary, w: FontWeight.w700)),
          ])),
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(Rad.xl), border: Border.all(color: AppColors.border),
                boxShadow: toyShadow(AppColors.toyShadowColor, 4)),
            child: Column(children: [
              for (int i = 0; i < (s['items'] as List).length; i++) ...[
                if (i > 0) Container(height: 1, color: AppColors.border),
                _FaqItem(q: (s['items'] as List)[i]['q'], a: (s['items'] as List)[i]['a']),
              ],
            ]),
          ),
        ],
        Padding(padding: const EdgeInsets.symmetric(vertical: Sp.xl), child: Column(children: [
          Text('HindiMitra v1.0.0', style: Fonts.body(12, w: FontWeight.w600, color: AppColors.textMuted)),
          const SizedBox(height: Sp.xs),
          Text('Made with love for Hindi learners everywhere', style: Fonts.body(11, color: AppColors.textMuted)),
        ])),
        const SizedBox(height: Sp.xxl * 2),
      ]))),
    ])));
  }
}

class _FaqItem extends StatefulWidget {
  final String q, a;
  const _FaqItem({required this.q, required this.a});
  @override
  State<_FaqItem> createState() => _FaqItemState();
}

class _FaqItemState extends State<_FaqItem> {
  bool open = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => open = !open),
        child: Padding(padding: const EdgeInsets.all(Sp.md), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(widget.q, style: Fonts.body(16, w: FontWeight.w700, color: AppColors.textPrimary))),
            const SizedBox(width: Sp.sm),
            Icon(open ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 18, color: AppColors.textMuted),
          ]),
          if (open) Padding(padding: const EdgeInsets.only(top: Sp.sm),
              child: Text(widget.a, style: Fonts.body(16, color: AppColors.textSecondary, height: 22 / 16))),
        ])),
      );
}
