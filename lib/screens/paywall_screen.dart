import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../routes.dart';
import '../services/billing.dart';
import '../store/app_store.dart';
import '../theme/app_theme.dart';
import '../theme/palette.dart';
import '../widgets/common.dart';

String _tierLabel(String t) => t == 'family' ? 'Family' : t == 'teacher' ? 'Teacher' : 'Individual';

/// PaywallScreen.tsx
///
/// Billing note: the original talks to a MockBillingProvider (Cloud Function) in dev builds and to
/// RevenueCat / Stripe in production. Neither backend is reachable from this port, so "Start
/// subscription" uses a local mock that just flips `isPremium` (same effect as the original mock).
class PaywallScreen extends StatefulWidget {
  final Map<String, dynamic> params;
  const PaywallScreen({super.key, this.params = const {}});
  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  String tier = 'individual', cycle = 'yearly';
  bool purchasing = false;

  Future<void> _purchase(PlanDescriptor plan) async {
    setState(() => purchasing = true);
    try {
      context.read<AppStore>().setPremium(true); // local mock billing
      if (!mounted) return;
      await showInfoDialog(context, 'Welcome to Premium! 🎉', 'Your account has been upgraded. Enjoy!');
      if (mounted) Navigator.of(context).maybePop();
    } catch (e) {
      if (mounted) await showInfoDialog(context, 'Purchase failed', 'Try again later.');
    } finally {
      if (mounted) setState(() => purchasing = false);
    }
  }

  Future<void> _restore() async {
    setState(() => purchasing = true);
    await showInfoDialog(context, 'Done', 'Mock provider has nothing to restore.');
    if (mounted) setState(() => purchasing = false);
  }

  @override
  Widget build(BuildContext context) {
    const availableTiers = ['individual', 'family', 'teacher'];
    final tierPlans = plansForTier(tier);
    final selected = tierPlans.firstWhere((p) => p.cycle == cycle, orElse: () => tierPlans.first);

    return Scaffold(backgroundColor: AppColors.background, body: SafeArea(bottom: false, child: screenScroll(
      maxWidth: 720, padding: const EdgeInsets.all(Sp.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          GestureDetector(onTap: () => Navigator.of(context).maybePop(), child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: AppColors.surface, shape: BoxShape.circle, border: Border.all(color: AppColors.border),
                boxShadow: toyShadow(AppColors.toyShadowColor, 3)),
            child: const Icon(Icons.chevron_left, size: 24, color: AppColors.textPrimary))),
          const SizedBox(width: Sp.sm),
          Expanded(child: Text('Unlock everything', style: Fonts.display(28, color: AppColors.textPrimary, w: FontWeight.w800))),
        ]),
        const SizedBox(height: Sp.md),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(9999), border: Border.all(color: AppColors.border)),
          child: Row(children: [
            for (int i = 0; i < availableTiers.length; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(child: GestureDetector(
                onTap: () => setState(() => tier = availableTiers[i]),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: Sp.sm), alignment: Alignment.center,
                  decoration: BoxDecoration(color: tier == availableTiers[i] ? AppColors.primary : null, borderRadius: BorderRadius.circular(9999),
                      boxShadow: tier == availableTiers[i] ? toyShadow(AppColors.primaryDark, 4) : null),
                  child: Text(_tierLabel(availableTiers[i]), style: Fonts.body(13, w: tier == availableTiers[i] ? FontWeight.w800 : FontWeight.w700,
                      color: tier == availableTiers[i] ? AppColors.textOnPrimary : AppColors.textSecondary)),
                ),
              )),
            ],
          ]),
        ),
        const SizedBox(height: Sp.md),
        Padding(padding: const EdgeInsets.only(top: Sp.xs), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final c in const ['monthly', 'yearly']) ...[
            if (c == 'yearly') const SizedBox(width: Sp.md),
            Expanded(child: _planCard(tierPlans.where((x) => x.cycle == c).firstOrNull, c)),
          ],
        ])),
        const SizedBox(height: Sp.md),
        Container(
          margin: const EdgeInsets.only(top: Sp.sm), padding: const EdgeInsets.all(Sp.md),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(Rad.xl), border: Border.all(color: AppColors.border),
              boxShadow: toyShadow(AppColors.toyShadowColor, 4)),
          child: Column(children: [
            _benefit('All 49+ letters unlocked'),
            _benefit(tier == 'teacher' ? 'Up to 30 students per class'
                : '${selected.maxChildren ?? 1} child profile${(selected.maxChildren ?? 1) > 1 ? 's' : ''}'),
            _benefit('AI tips & assignment reports'),
            _benefit('Sentence & word writing'),
            _benefit('Reading comprehension'),
            _benefit('Cancel anytime', last: true),
          ]),
        ),
        const SizedBox(height: Sp.md),
        Opacity(opacity: purchasing ? 0.6 : 1, child: GestureDetector(
          onTap: purchasing ? null : () => _purchase(selected),
          child: Container(
            margin: const EdgeInsets.only(top: Sp.md), padding: const EdgeInsets.symmetric(vertical: Sp.md),
            decoration: BoxDecoration(gradient: toneGradient(AppColors.primary), borderRadius: BorderRadius.circular(9999), boxShadow: toyShadow(AppColors.primaryDark, 6)),
            child: purchasing
                ? const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textOnPrimary)))
                : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('Start subscription', style: Fonts.body(16, w: FontWeight.w800, color: AppColors.textOnPrimary)),
                    const SizedBox(width: Sp.xs),
                    const Icon(Icons.arrow_forward, size: 18, color: AppColors.textOnPrimary),
                  ]),
          ),
        )),
        const SizedBox(height: Sp.md),
        GestureDetector(onTap: purchasing ? null : _restore, child: Padding(padding: const EdgeInsets.only(top: Sp.sm),
            child: Text('Restore purchases', textAlign: TextAlign.center, style: Fonts.body(13, w: FontWeight.w700, color: AppColors.primary)))),
        const SizedBox(height: Sp.md),
        Padding(padding: const EdgeInsets.only(top: Sp.md), child: Text(
          "Subscriptions auto-renew. Cancel anytime in your device's account settings.",
          textAlign: TextAlign.center, style: Fonts.body(12, color: AppColors.textMuted))),
        const SizedBox(height: Sp.md),
        GestureDetector(onTap: () => openScreen(context, 'ContactSales'), child: Padding(padding: const EdgeInsets.only(top: 8),
            child: Text('Need a school / district plan? Contact sales', textAlign: TextAlign.center,
                style: Fonts.body(13, w: FontWeight.w700, color: AppColors.primary)))),
      ]),
    )));
  }

  Widget _benefit(String t, {bool last = false}) => Padding(
        padding: EdgeInsets.only(bottom: last ? 0 : Sp.sm),
        child: Row(children: [
          const Icon(Icons.check, size: 18, color: AppColors.success), const SizedBox(width: Sp.sm),
          Expanded(child: Text(t, style: Fonts.body(14, color: AppColors.textPrimary))),
        ]),
      );

  Widget _planCard(PlanDescriptor? p, String c) {
    if (p == null) return const SizedBox.shrink();
    final sel = cycle == c;
    return GestureDetector(
      onTap: () => setState(() => cycle = c),
      child: Stack(clipBehavior: Clip.none, alignment: Alignment.topCenter, children: [
        Container(
          width: double.infinity, padding: const EdgeInsets.all(Sp.md),
          decoration: BoxDecoration(color: sel ? AppColors.primary : AppColors.surface, borderRadius: BorderRadius.circular(Rad.xl2),
              border: Border.all(color: sel ? AppColors.primaryDark : AppColors.border),
              boxShadow: sel ? softShadow(AppColors.primary) : toyShadow(AppColors.toyShadowColor, 4)),
          child: Column(children: [
            Opacity(opacity: sel ? 0.85 : 1, child: Text(c == 'yearly' ? 'YEARLY' : 'MONTHLY',
                style: Fonts.body(12, w: FontWeight.w700, color: sel ? AppColors.textOnPrimary : AppColors.textSecondary).copyWith(letterSpacing: 0.5))),
            const SizedBox(height: 4),
            Text(p.priceLabel, style: Fonts.display(28, color: sel ? AppColors.textOnPrimary : AppColors.textPrimary, w: FontWeight.w800)),
            const SizedBox(height: 4),
            Opacity(opacity: sel ? 0.85 : 1, child: Text(p.cycleLabel, style: Fonts.body(11, color: sel ? AppColors.textOnPrimary : AppColors.textMuted))),
            if (p.savings != null) Padding(padding: const EdgeInsets.only(top: 4),
                child: Text(p.savings!, style: Fonts.body(11, w: FontWeight.w700, color: sel ? AppColors.textOnPrimary : AppColors.success))),
          ]),
        ),
        if (p.popular) Positioned(top: -10, child: Container(
          padding: const EdgeInsets.symmetric(horizontal: Sp.sm, vertical: 3),
          decoration: BoxDecoration(color: sel ? AppColors.textOnPrimary : AppColors.secondary, borderRadius: BorderRadius.circular(9999)),
          child: Text('POPULAR', style: Fonts.body(10, w: FontWeight.w800, color: sel ? AppColors.primaryDark : AppColors.textOnPrimary).copyWith(letterSpacing: 0.5)),
        )),
      ]),
    );
  }
}
