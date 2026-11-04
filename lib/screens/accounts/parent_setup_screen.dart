import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n.dart';
import '../../routes.dart';
import '../../services/cloud.dart';
import '../../services/cloud_accounts.dart';
import '../../store/app_store.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../../widgets/common.dart';
import 'account_widgets.dart';
import 'pin_pad.dart';

/// Creates a parent account (gets a Parent ID and a PIN, and is linked to
/// the current learner), or edits one when `parentId` is given. Pops with
/// the parent.
class ParentSetupScreen extends StatefulWidget {
  final Map<String, dynamic> params;
  const ParentSetupScreen({super.key, this.params = const {}});
  @override
  State<ParentSetupScreen> createState() => _ParentSetupScreenState();
}

class _ParentSetupScreenState extends State<ParentSetupScreen> {
  static const _relations = ['Mother', 'Father', 'Guardian', 'Grandparent', 'Teacher'];
  late final String? editId = widget.params['parentId'] as String?;
  final name = TextEditingController(), phone = TextEditingController(), email = TextEditingController();
  String relationship = 'Mother';
  bool linkCurrent = true, busy = false;
  String? error;
  /// Signed in to the cloud during sign-up: the new parent is connected to it.
  User? cloudUser;

  @override
  void initState() {
    super.initState();
    final p = editId == null ? null : context.read<AppStore>().parentById(editId!);
    if (p != null) {
      name.text = p.name; phone.text = p.phone; email.text = p.email; relationship = p.relationship;
    }
    // A fresh install's placeholder learner (not set up yet) is not a child to link.
    final s = context.read<AppStore>();
    linkCurrent = s.recordOf(s.activeStudentId).onboarded;
  }

  /// A parent who already has a cloud account (e.g. set up on another
  /// device) signs in: they keep their Parent ID. A new account fills in
  /// the form instead.
  Future<void> _signInExisting() async {
    final u = await openScreen<User>(context, 'CloudSignIn');
    if (u == null || !mounted) return;
    final s = context.read<AppStore>();
    setState(() { busy = true; error = null; });
    try {
      final cp = await CloudAccounts.fetchParent();
      if (!mounted) return;
      if (cp == null || cp.parentId.isEmpty) {
        setState(() {
          cloudUser = u;
          if (name.text.trim().isEmpty) name.text = u.displayName ?? '';
          if (email.text.trim().isEmpty) email.text = u.email ?? '';
          if (phone.text.trim().isEmpty) phone.text = u.phoneNumber ?? '';
        });
        return;
      }
      final pin = await createPin(context, title: tr('Choose a PIN for this device', 'इस डिवाइस के लिए पिन चुनें'), parentId: cp.parentId);
      if (pin == null || !mounted) { await CloudAccounts.signOut(); return; }
      final p = s.restoreParent(id: cp.parentId, uid: u.uid, name: cp.name, pin: pin,
          relationship: cp.relationship, phone: cp.phone, email: cp.email);
      if (linkCurrent) s.linkParent(s.activeStudentId, p.id);
      await CloudAccounts.backup(s, p.id);
      if (mounted) Navigator.of(context).pop(s.parentById(p.id));
    } on CloudError catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _save() async {
    final s = context.read<AppStore>();
    final mail = email.text.trim();
    String? err;
    if (name.text.trim().isEmpty) {
      err = tr('Please enter your name.', 'कृपया अपना नाम लिखें।');
    } else if (mail.isNotEmpty && !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(mail)) {
      err = tr('That email does not look right.', 'ईमेल सही नहीं लग रहा।');
    } else if (phone.text.trim().isNotEmpty && phone.text.replaceAll(RegExp(r'\D'), '').length < 7) {
      err = tr('That phone number looks too short.', 'फ़ोन नंबर छोटा लग रहा है।');
    }
    if (err != null) { setState(() => error = err); return; }
    if (editId != null) {
      s.updateParent(editId!, name: name.text, relationship: relationship, phone: phone.text, email: mail);
      Navigator.of(context).pop(s.parentById(editId!));
      return;
    }
    final newPin = await createPin(context);
    if (newPin == null || !mounted) return;
    final p = s.createParent(name: name.text, pin: newPin, relationship: relationship, phone: phone.text, email: mail);
    if (linkCurrent) s.linkParent(s.activeStudentId, p.id);
    var id = p.id;
    if (cloudUser != null) {
      setState(() => busy = true);
      try {
        id = await CloudAccounts.connectParent(s, p.id);
      } on CloudError catch (e) {
        // The parent is created either way; backup can be retried from parent control.
        if (mounted) await showInfoDialog(context, tr('Cloud backup', 'क्लाउड बैकअप'), e.message);
      }
    }
    if (mounted) Navigator.of(context).pop(s.parentById(id));
  }

  Future<void> _changePin() async {
    final p = await createPin(context, title: tr('New PIN', 'नया पिन'), parentId: editId);
    if (p == null || !mounted) return;
    context.read<AppStore>().updateParent(editId!, pin: p);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('PIN changed', 'पिन बदल गया'))));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(bottom: false, child: Column(children: [
        HeaderBar(title: editId == null ? tr('Parent sign-up', 'अभिभावक खाता') : tr('Parent details', 'अभिभावक विवरण'),
            subtitle: editId ?? tr('Get a Parent ID', 'Parent ID पाएँ'), onBack: () => Navigator.of(context).maybePop()),
        Expanded(child: screenScroll(maxWidth: 560, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (editId == null) ToyCard(
            margin: const EdgeInsets.only(bottom: Sp.lg),
            color: AppColors.primary.withOpacity(0.08), borderColor: AppColors.primary.withOpacity(0.3),
            child: Text(tr('With a parent account you can see each child\'s full record, set homework, and lock '
                    'their important information. Your PIN keeps parent control away from little fingers.',
                    'अभिभावक खाते से आप हर बच्चे का पूरा रिकॉर्ड देख सकते हैं, होमवर्क दे सकते हैं और उनकी ज़रूरी '
                    'जानकारी लॉक कर सकते हैं। आपका पिन अभिभावक नियंत्रण को सुरक्षित रखता है।'),
                style: Fonts.body(14, color: AppColors.textSecondary, height: 1.4)),
          ),
          if (editId == null && Cloud.ready) Padding(
            padding: const EdgeInsets.only(bottom: Sp.md),
            child: cloudUser == null
                ? ResultButton(label: tr('Already have a parent account? Sign in', 'पहले से खाता है? साइन इन करें'),
                    icon: Icons.login_rounded, filled: false, onTap: busy ? null : _signInExisting)
                : ToyCard(color: AppColors.success.withOpacity(0.08), borderColor: AppColors.success.withOpacity(0.4), child: Row(children: [
                    Icon(Icons.cloud_done_rounded, color: AppColors.success), const SizedBox(width: Sp.sm),
                    Expanded(child: Text(tr('Signed in as ${cloudUser!.email ?? cloudUser!.phoneNumber ?? ''}. Finish below to get your Parent ID.',
                            '${cloudUser!.email ?? cloudUser!.phoneNumber ?? ''} से साइन इन। Parent ID पाने के लिए नीचे पूरा करें।'),
                        style: Fonts.body(13, w: FontWeight.w700))),
                  ])),
          ),
          AccountField(controller: name, label: tr('Your name', 'आपका नाम'), maxLength: 40),
          Text(tr('You are their…', 'आप उनके…'), style: Fonts.body(13, w: FontWeight.w700, color: AppColors.textSecondary)),
          const SizedBox(height: Sp.xs),
          Wrap(spacing: Sp.xs, runSpacing: Sp.xs, children: [
            for (final r in _relations)
              ChoiceChip(label: Text(r), selected: relationship == r, onSelected: (_) => setState(() => relationship = r)),
          ]),
          const SizedBox(height: Sp.md),
          AccountField(controller: phone, label: tr('Phone (optional)', 'फ़ोन (वैकल्पिक)'), keyboard: TextInputType.phone,
              hint: '+91 98765 43210', maxLength: 20),
          AccountField(controller: email, label: tr('Email (optional)', 'ईमेल (वैकल्पिक)'), keyboard: TextInputType.emailAddress,
              maxLength: 80),
          if (editId == null) ...[
            Padding(padding: const EdgeInsets.only(bottom: Sp.sm), child: Row(children: [
              Icon(Icons.lock_rounded, size: 18, color: AppColors.textSecondary), const SizedBox(width: Sp.sm),
              Expanded(child: Text(tr('Next you’ll create a 6-character PIN (letters and numbers) that keeps the Parent Hub safe.',
                  'इसके बाद आप 6 अक्षरों (अक्षर और अंक) का पिन बनाएँगे जो अभिभावक केंद्र को सुरक्षित रखेगा।'),
                  style: Fonts.body(13, w: FontWeight.w600, color: AppColors.textSecondary))),
            ])),
            if (s.recordOf(s.activeStudentId).onboarded) CheckboxListTile(
              value: linkCurrent, onChanged: (v) => setState(() => linkCurrent = v ?? true),
              contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading,
              title: Text(tr('Link ${s.userName} (${s.activeStudentId}) to me', '${s.userName} (${s.activeStudentId}) को मुझसे जोड़ें'),
                  style: Fonts.body(15, w: FontWeight.w700)),
            ),
          ] else
            Padding(padding: const EdgeInsets.only(bottom: Sp.md), child: ResultButton(
                label: tr('Change PIN', 'पिन बदलें'), icon: Icons.password_rounded, filled: false, onTap: _changePin)),
          if (error != null) Padding(padding: const EdgeInsets.only(bottom: Sp.md),
              child: Text(error!, style: Fonts.body(14, w: FontWeight.w700, color: AppColors.error))),
          ResultButton(label: editId == null ? tr('Create parent account', 'खाता बनाएँ') : tr('Save', 'सेव करें'),
              icon: Icons.check_rounded, onTap: busy ? null : _save),
          if (busy) const Padding(padding: EdgeInsets.only(top: Sp.md), child: Center(child: CircularProgressIndicator())),
          const SizedBox(height: Sp.xxl),
        ]))),
      ])),
    );
  }
}
