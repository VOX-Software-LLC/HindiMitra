import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../theme/palette.dart';
import '../widgets/common.dart';
import '../widgets/toy_button.dart';

/// ContactSalesScreen.tsx
///
/// The original posts the lead to a Firebase callable. That backend is not part of this port, so
/// "Send to sales team" opens the user's mail client with the form contents pre-filled instead.
class ContactSalesScreen extends StatefulWidget {
  final Map<String, dynamic> params;
  const ContactSalesScreen({super.key, this.params = const {}});
  @override
  State<ContactSalesScreen> createState() => _ContactSalesScreenState();
}

class _ContactSalesScreenState extends State<ContactSalesScreen> {
  final school = TextEditingController(), contact = TextEditingController(), email = TextEditingController(),
      phone = TextEditingController(), students = TextEditingController(), notes = TextEditingController();
  bool submitting = false;

  @override
  void dispose() {
    for (final c in [school, contact, email, phone, students, notes]) { c.dispose(); }
    super.dispose();
  }

  Future<void> _submit() async {
    if (school.text.trim().isEmpty || contact.text.trim().isEmpty || email.text.trim().isEmpty) {
      await showInfoDialog(context, 'Required fields', 'School name, your name, and email are required.');
      return;
    }
    setState(() => submitting = true);
    try {
      final body = [
        'School: ${school.text.trim()}', 'Contact: ${contact.text.trim()}', 'Email: ${email.text.trim()}',
        if (phone.text.trim().isNotEmpty) 'Phone: ${phone.text.trim()}',
        if (students.text.trim().isNotEmpty) 'Approx. students: ${students.text.trim()}',
        if (notes.text.trim().isNotEmpty) 'Notes: ${notes.text.trim()}',
      ].join('\n');
      final url = Uri.parse('mailto:support@hindimitra.app?subject=${Uri.encodeComponent('HindiMitra school / district plan')}&body=${Uri.encodeComponent(body)}');
      final ok = await launchUrl(url);
      if (!mounted) return;
      if (!ok) throw 'no mail client';
      await showInfoDialog(context, 'Thanks!', "We'll be in touch within 1 business day. Check your email for a confirmation.");
      if (mounted) Navigator.of(context).maybePop();
    } catch (_) {
      if (mounted) await showInfoDialog(context, 'Submission failed', 'Could not submit. Please try again.');
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  Widget _label(String t) => Padding(padding: const EdgeInsets.only(top: Sp.sm, bottom: Sp.sm),
      child: Text(t, style: Fonts.body(13, w: FontWeight.w700, color: AppColors.textPrimary)));

  Widget _field(String label, IconData icon, TextEditingController c,
      {String? hint, TextInputType? type, TextCapitalization cap = TextCapitalization.none, bool multiline = false}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _label(label),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.md),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(Rad.lg), border: Border.all(color: AppColors.border)),
          child: Row(crossAxisAlignment: multiline ? CrossAxisAlignment.start : CrossAxisAlignment.center, children: [
            if (!multiline) ...[Icon(icon, size: 20, color: AppColors.textMuted), const SizedBox(width: Sp.sm)],
            Expanded(child: TextField(
              controller: c, enabled: !submitting, keyboardType: multiline ? TextInputType.multiline : type, textCapitalization: cap,
              minLines: multiline ? 5 : 1, maxLines: multiline ? null : 1,
              style: Fonts.body(16, color: AppColors.textPrimary),
              decoration: InputDecoration(isDense: true, border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: Sp.xs),
                  hintText: hint, hintStyle: Fonts.body(16, color: AppColors.textMuted)),
            )),
          ]),
        ),
      ]);

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: AppColors.background, resizeToAvoidBottomInset: true, body: SafeArea(bottom: false, child: screenScroll(
      maxWidth: 720, padding: const EdgeInsets.all(Sp.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Align(alignment: Alignment.centerLeft, child: GestureDetector(onTap: () => Navigator.of(context).maybePop(), child: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: AppColors.surface, shape: BoxShape.circle, border: Border.all(color: AppColors.border), boxShadow: toyShadow(AppColors.toyShadowColor, 3)),
          child: const Icon(Icons.chevron_left, size: 22, color: AppColors.textPrimary)))),
        const SizedBox(height: Sp.lg),
        Container(
          padding: const EdgeInsets.all(Sp.lg),
          decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(Rad.xl2), boxShadow: softShadow(AppColors.primary)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 52, height: 52, margin: const EdgeInsets.only(bottom: Sp.xs + Sp.sm),
                decoration: const BoxDecoration(color: AppColors.primaryDark, shape: BoxShape.circle),
                child: const Icon(Icons.school, size: 26, color: AppColors.textOnPrimary)),
            Text('School / district plans', style: Fonts.display(32, color: AppColors.textOnPrimary, w: FontWeight.w800)),
            const SizedBox(height: Sp.xs + Sp.sm),
            Opacity(opacity: 0.92, child: Text(
              "Tell us about your school and we'll send a custom proposal within 1 business day. Purchase orders and bulk pricing available.",
              style: Fonts.body(16, color: AppColors.textOnPrimary, height: 24 / 16))),
          ]),
        ),
        const SizedBox(height: Sp.lg),
        Container(
          padding: const EdgeInsets.all(Sp.lg),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(Rad.xl), border: Border.all(color: AppColors.border),
              boxShadow: toyShadow(AppColors.toyShadowColor, 4)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _field('School / district name *', Icons.school_outlined, school, cap: TextCapitalization.words),
            _field('Your name *', Icons.person_outline, contact, cap: TextCapitalization.words),
            _field('Email *', Icons.mail_outline, email, type: TextInputType.emailAddress),
            _field('Phone (optional)', Icons.call_outlined, phone, type: TextInputType.phone),
            _field('Approximate # of students', Icons.people_outline, students, hint: 'e.g. 250', type: TextInputType.number),
            _field('Tell us about your needs (optional)', Icons.notes, notes, hint: 'Number of teachers, classrooms, budget, timeline…', multiline: true),
            const SizedBox(height: Sp.lg),
            if (submitting)
              Opacity(opacity: 0.6, child: Container(
                padding: const EdgeInsets.symmetric(vertical: Sp.md, horizontal: Sp.xl),
                decoration: BoxDecoration(gradient: toneGradient(AppColors.primary), borderRadius: BorderRadius.circular(9999), boxShadow: toyShadow(AppColors.primaryDark, 6)),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textOnPrimary)),
                  const SizedBox(width: Sp.sm),
                  Text('Sending…', style: Fonts.body(16, w: FontWeight.w800, color: AppColors.textOnPrimary)),
                ]),
              ))
            else
              ToyButton(label: 'Send to sales team', onPressed: _submit, variant: ToyVariant.primary, size: ToySize.lg, fullWidth: true,
                  trailing: const Icon(Icons.send_outlined, size: 18, color: AppColors.textOnPrimary)),
          ]),
        ),
      ]),
    )));
  }
}
