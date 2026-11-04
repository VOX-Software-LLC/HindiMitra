import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n.dart';
import '../../routes.dart';
import '../../services/cloud.dart';
import '../../services/cloud_accounts.dart';
import '../../services/sync_service.dart';
import '../../store/app_store.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../../widgets/common.dart';
import 'account_widgets.dart';

/// Parent sign-in for cloud backup: Google, phone (SMS code) or email and
/// password. Pops with the signed-in [User].
class CloudSignInScreen extends StatefulWidget {
  final Map<String, dynamic> params;
  const CloudSignInScreen({super.key, this.params = const {}});
  @override
  State<CloudSignInScreen> createState() => _CloudSignInScreenState();
}

class _CloudSignInScreenState extends State<CloudSignInScreen> {
  String method = 'phone'; // phone | email
  final phone = TextEditingController(text: '+91 '), code = TextEditingController(),
      email = TextEditingController(), password = TextEditingController();
  PhoneSignIn? pending;
  bool creating = false, busy = false;
  String? error;

  Future<void> _go(Future<User> Function() f) async {
    setState(() { busy = true; error = null; });
    try {
      final u = await f();
      if (mounted) Navigator.of(context).pop(u);
    } on CloudError catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _sendCode() async {
    setState(() { busy = true; error = null; });
    try {
      final p = await CloudAccounts.startPhoneSignIn(phone.text);
      if (mounted) setState(() => pending = p);
    } on CloudError catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget tab(String id, IconData icon, String label) => Expanded(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: ResultButton(label: label, icon: icon, filled: method == id,
              onTap: busy ? null : () => setState(() { method = id; error = null; })),
        ));
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(bottom: false, child: Column(children: [
        HeaderBar(title: tr('Parent sign-in', 'अभिभावक साइन-इन'), subtitle: tr('Cloud backup', 'क्लाउड बैकअप'),
            onBack: () => Navigator.of(context).maybePop()),
        Expanded(child: screenScroll(maxWidth: 480, child: !Cloud.ready
            ? ToyCard(child: Text(tr('Cloud backup is not set up in this version of the app.', 'इस ऐप में क्लाउड बैकअप अभी चालू नहीं है।'),
                style: Fonts.body(15, color: AppColors.textSecondary)))
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(tr('Sign in to back up your children\'s progress and see it from your own phone.',
                        'बच्चों की प्रगति का बैकअप लेने और अपने फ़ोन से देखने के लिए साइन इन करें।'),
                    textAlign: TextAlign.center, style: Fonts.body(15, color: AppColors.textSecondary, height: 1.4)),
                const SizedBox(height: Sp.lg),
                ResultButton(label: tr('Continue with Google', 'Google से जारी रखें'), icon: Icons.account_circle_rounded,
                    filled: false, onTap: busy ? null : () => _go(CloudAccounts.signInWithGoogle)),
                Padding(padding: const EdgeInsets.symmetric(vertical: Sp.md), child: Row(children: [
                  Expanded(child: Divider(color: AppColors.border)),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: Sp.sm),
                      child: Text(tr('or', 'या'), style: Fonts.body(13, color: AppColors.textMuted))),
                  Expanded(child: Divider(color: AppColors.border)),
                ])),
                Row(children: [
                  tab('phone', Icons.phone_rounded, tr('Phone', 'फ़ोन')),
                  tab('email', Icons.mail_rounded, tr('Email', 'ईमेल')),
                ]),
                const SizedBox(height: Sp.lg),
                if (method == 'phone' && pending == null) ...[
                  AccountField(controller: phone, label: tr('Mobile number with country code', 'देश कोड सहित मोबाइल नंबर'),
                      keyboard: TextInputType.phone, maxLength: 20),
                  ResultButton(label: tr('Send code', 'कोड भेजें'), icon: Icons.sms_rounded, onTap: busy ? null : _sendCode),
                ],
                if (method == 'phone' && pending != null) ...[
                  Text(tr('Enter the 6-digit code sent to ${phone.text.trim()}', '${phone.text.trim()} पर भेजा गया 6 अंकों का कोड डालें'),
                      style: Fonts.body(14, w: FontWeight.w700)),
                  const SizedBox(height: Sp.sm),
                  AccountField(controller: code, label: tr('SMS code', 'SMS कोड'), keyboard: TextInputType.number, maxLength: 6),
                  ResultButton(label: tr('Verify', 'पुष्टि करें'), icon: Icons.check_rounded,
                      onTap: busy ? null : () => _go(() => pending!.confirm(code.text))),
                  TextButton(onPressed: busy ? null : () => setState(() { pending = null; code.clear(); }),
                      child: Text(tr('Change number', 'नंबर बदलें'), style: Fonts.body(14, w: FontWeight.w700, color: AppColors.primary))),
                ],
                if (method == 'email') ...[
                  AccountField(controller: email, label: tr('Email', 'ईमेल'), keyboard: TextInputType.emailAddress, maxLength: 80),
                  AccountField(controller: password, label: tr('Password', 'पासवर्ड'), obscure: true, maxLength: 64,
                      hint: creating ? tr('At least 6 characters', 'कम से कम 6 अक्षर') : null),
                  ResultButton(label: creating ? tr('Create account', 'खाता बनाएँ') : tr('Sign in', 'साइन इन'),
                      icon: Icons.login_rounded,
                      onTap: busy ? null : () => _go(() => CloudAccounts.signInWithEmail(email.text, password.text, create: creating))),
                  TextButton(onPressed: busy ? null : () => setState(() { creating = !creating; error = null; }),
                      child: Text(creating ? tr('I already have an account', 'मेरा खाता पहले से है') : tr('New here? Create an account', 'नए हैं? खाता बनाएँ'),
                          style: Fonts.body(14, w: FontWeight.w700, color: AppColors.primary))),
                ],
                if (busy) const Padding(padding: EdgeInsets.only(top: Sp.md), child: Center(child: CircularProgressIndicator())),
                if (error != null) Padding(padding: const EdgeInsets.only(top: Sp.md),
                    child: Text(error!, textAlign: TextAlign.center, style: Fonts.body(14, w: FontWeight.w700, color: AppColors.error))),
                const SizedBox(height: Sp.lg),
                Text(tr('Only parents sign in. Children never need an account.', 'केवल अभिभावक साइन इन करते हैं। बच्चों को खाते की ज़रूरत नहीं।'),
                    textAlign: TextAlign.center, style: Fonts.body(12, color: AppColors.textMuted)),
                const SizedBox(height: Sp.xxl),
              ]))),
      ])),
    );
  }
}

/// Cloud backup status for a parent (in the parent hub): sign in, back up
/// now, last backup time, sign out.
class CloudAccountCard extends StatefulWidget {
  final String parentId;
  const CloudAccountCard({super.key, required this.parentId});
  @override
  State<CloudAccountCard> createState() => _CloudAccountCardState();
}

class _CloudAccountCardState extends State<CloudAccountCard> {
  bool busy = false;

  Future<void> _work(Future<String> Function() f) async {
    setState(() => busy = true);
    try {
      final msg = await f();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } on CloudError catch (e) {
      if (mounted) showInfoDialog(context, tr('Cloud backup', 'क्लाउड बैकअप'), e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _signIn(String parentId) async {
    final u = await openScreen<User>(context, 'CloudSignIn');
    if (u == null || !mounted) return;
    final s = context.read<AppStore>();
    await _work(() async {
      await CloudAccounts.connectParent(s, parentId);
      return tr('Signed in and backed up', 'साइन इन हुआ और बैकअप हो गया');
    });
  }

  // Firebase restores a saved sign-in shortly after launch: follow it.
  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
        stream: CloudAccounts.changes, initialData: CloudAccounts.user, builder: (_, __) => _card(context));

  Widget _card(BuildContext context) {
    final s = context.watch<AppStore>();
    final pa = s.parentById(widget.parentId) ?? s.parents.where((p) => p.cloudUid.isNotEmpty).firstOrNull;
    if (pa == null) return const SizedBox.shrink();
    final u = CloudAccounts.user;
    final signedIn = Cloud.ready && pa.cloudUid.isNotEmpty && u?.uid == pa.cloudUid;
    final who = u == null ? '' : [u.displayName, u.email, u.phoneNumber].whereType<String>().where((x) => x.isNotEmpty).join(' · ');

    return ToyCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Icon(signedIn ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
            color: signedIn ? AppColors.success : AppColors.textMuted),
        const SizedBox(width: Sp.sm),
        Expanded(child: Text(signedIn ? tr('Backed up to the cloud', 'क्लाउड पर बैकअप') : tr('Not backed up', 'बैकअप नहीं'),
            style: Fonts.display(17))),
        if (busy) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5)),
      ]),
      const SizedBox(height: Sp.xs),
      if (!Cloud.ready)
        Text(tr('Cloud backup is not set up in this version of the app. Everything is saved on this device.',
                'इस ऐप में क्लाउड बैकअप अभी चालू नहीं है। सब कुछ इसी डिवाइस पर सेव है।'),
            style: Fonts.body(13, color: AppColors.textSecondary))
      else if (!signedIn) ...[
        Text(pa.cloudUid.isNotEmpty
                ? tr('You were signed out. Sign in again to keep backing up.', 'आप साइन आउट हो गए। बैकअप जारी रखने के लिए फिर से साइन इन करें।')
                : tr('Progress is only on this device. Sign in to back it up and keep it if this device is lost.',
                    'प्रगति सिर्फ़ इसी डिवाइस पर है। बैकअप के लिए साइन इन करें, ताकि डिवाइस खोने पर भी सुरक्षित रहे।'),
            style: Fonts.body(13, color: AppColors.textSecondary)),
        const SizedBox(height: Sp.md),
        ResultButton(label: tr('Sign in to back up', 'बैकअप के लिए साइन इन करें'), icon: Icons.cloud_upload_rounded,
            onTap: busy ? null : () => _signIn(pa.id)),
      ] else ...[
        if (who.isNotEmpty) InfoRow(icon: Icons.account_circle_rounded, label: tr('Account', 'खाता'), value: who),
        ValueListenableBuilder<SyncStatus>(valueListenable: SyncService.status, builder: (_, st, __) {
          final at = st.lastSync == null ? '' : ' · ${_time(st.lastSync!.toUtc().toIso8601String())}';
          final (icon, color, text) = switch (st.state) {
            SyncState.synced => (Icons.check_circle_rounded, AppColors.success, tr('Up to date$at', 'अप टू डेट$at')),
            SyncState.syncing => (Icons.sync_rounded, AppColors.primary, tr('Syncing…', 'सिंक हो रहा है…')),
            SyncState.offline => (Icons.cloud_off_rounded, AppColors.textMuted,
                tr('Offline: uploads when back online', 'ऑफ़लाइन: इंटरनेट आने पर अपलोड होगा')),
            SyncState.error => (Icons.error_outline_rounded, AppColors.error, st.message ?? tr('Sync problem', 'सिंक में दिक्कत')),
            SyncState.off => (Icons.sync_disabled_rounded, AppColors.textMuted, tr('Not syncing', 'सिंक बंद')),
          };
          return InfoRow(icon: Icons.sync_rounded, label: tr('Auto-sync', 'ऑटो-सिंक'), trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 16, color: color), const SizedBox(width: 4),
            Text(text, style: Fonts.body(13, w: FontWeight.w700, color: color)),
          ]));
        }),
        InfoRow(icon: Icons.history_rounded, label: tr('Last full backup', 'आखिरी पूरा बैकअप'),
            value: pa.lastBackupAt == null ? '' : '${shortDate(pa.lastBackupAt)} ${_time(pa.lastBackupAt!)}'),
        const SizedBox(height: Sp.sm),
        Row(children: [
          Expanded(child: ResultButton(label: tr('Back up now', 'अभी बैकअप लें'), icon: Icons.cloud_sync_rounded,
              onTap: busy ? null : () => _work(() async {
                final n = await CloudAccounts.backup(s, pa.id);
                await SyncService.syncNow();
                return tr('Backed up $n ${n == 1 ? 'child' : 'children'}', '$n बच्चों का बैकअप हुआ');
              }))),
          const SizedBox(width: Sp.sm),
          Expanded(child: ResultButton(label: tr('Sign out', 'साइन आउट'), icon: Icons.logout_rounded, filled: false,
              onTap: busy ? null : () async {
                final ok = await confirmDialog(context, title: tr('Sign out of the cloud?', 'क्लाउड से साइन आउट करें?'),
                    message: tr('Everything stays on this device. Backups stop until you sign in again.',
                        'सब कुछ इस डिवाइस पर रहेगा। दोबारा साइन इन करने तक बैकअप रुक जाएगा।'),
                    confirmLabel: tr('Sign out', 'साइन आउट'));
                if (!ok) return;
                await CloudAccounts.signOut();
                s.setParentCloud(pa.id, '');
              })),
        ]),
      ],
    ]));
  }

  static String _time(String iso) {
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return '';
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}
