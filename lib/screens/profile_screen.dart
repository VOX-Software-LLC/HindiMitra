import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../routes.dart';
import '../store/app_store.dart';
import '../theme/app_theme.dart';
import '../theme/palette.dart';
import '../widgets/common.dart';
import '../widgets/profile_sections.dart';
import 'app_shell.dart';

const _feedbackEmail = 'shahi.aditya@gmail.com';
const _appVersion = '1.0.0';

/// ProfileScreen.tsx (local / offline mode — Firebase is not configured, so no account e-mail or guest badge).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<void> _signOut() async {
    final ok = await confirmDialog(context,
        title: 'Sign Out', message: 'Your progress will be saved to your account. Continue?',
        confirmLabel: 'Sign Out', destructive: true);
    if (!ok || !mounted) return;
    // Clear identity only; local progress is kept (same as the original).
    context.read<AppStore>().setPremium(false);
  }

  Future<void> _sendFeedback() async {
    final store = context.read<AppStore>();
    try {
      final platform = defaultTargetPlatform.name;
      final subject = 'HindiMitra feedback — v$_appVersion ($platform)';
      final body = [
        'What went wrong (please describe):', '', '',
        '— Diagnostic info (please leave this) —',
        'User: ${store.userName}',
        'App version: $_appVersion',
        'Device: ? · $platform ?',
      ].join('\n');
      final url = Uri.parse('mailto:$_feedbackEmail?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}');
      if (!await canLaunchUrl(url)) {
        if (mounted) showInfoDialog(context, 'Email not configured', 'Please send your feedback to $_feedbackEmail.');
        return;
      }
      await launchUrl(url);
    } catch (_) {
      if (mounted) showInfoDialog(context, 'Could not open email', 'Please email $_feedbackEmail directly.');
    }
  }

  Future<void> _editProfile() async {
    final store = context.read<AppStore>();
    final ctrl = TextEditingController(text: store.userName);
    await showDialog(context: context, builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent, insetPadding: const EdgeInsets.all(Sp.lg),
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 360), child: Container(
        padding: const EdgeInsets.all(Sp.xl),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(Rad.xl2),
            border: Border.all(color: AppColors.border), boxShadow: toyShadow(AppColors.toyShadowColor, 6)),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Edit Profile', textAlign: TextAlign.center, style: Fonts.display(24, color: AppColors.textPrimary, w: FontWeight.w800)),
          const SizedBox(height: Sp.lg),
          Padding(padding: const EdgeInsets.only(bottom: Sp.xs), child: Text('Your Name', style: Fonts.body(14, w: FontWeight.w700, color: AppColors.textSecondary))),
          TextField(
            controller: ctrl, autofocus: true, maxLength: 30,
            style: Fonts.body(16, color: AppColors.textPrimary),
            decoration: InputDecoration(
              counterText: '', hintText: 'Enter your name', hintStyle: Fonts.body(16, color: AppColors.textMuted),
              filled: true, fillColor: AppColors.surface, contentPadding: const EdgeInsets.all(Sp.md),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.lg), borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.lg), borderSide: const BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.lg), borderSide: const BorderSide(color: AppColors.border)),
            ),
          ),
          const SizedBox(height: Sp.lg),
          Row(children: [
            Expanded(child: GestureDetector(onTap: () => Navigator.of(ctx).pop(), child: Container(
              padding: const EdgeInsets.symmetric(vertical: Sp.sm), alignment: Alignment.center,
              decoration: BoxDecoration(border: Border.all(color: AppColors.primary, width: 2), borderRadius: BorderRadius.circular(9999)),
              child: Text('Cancel', style: Fonts.body(16, w: FontWeight.w800, color: AppColors.primary))))),
            const SizedBox(width: Sp.md),
            Expanded(child: GestureDetector(
              onTap: () {
                final t = ctrl.text.trim();
                if (t.isEmpty) { showInfoDialog(ctx, 'Invalid Name', 'Please enter a name.'); return; }
                store.setUserName(t);
                Navigator.of(ctx).pop();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: Sp.sm), alignment: Alignment.center,
                decoration: BoxDecoration(gradient: toneGradient(AppColors.primary), borderRadius: BorderRadius.circular(9999), boxShadow: toyShadow(AppColors.primaryDark, 6)),
                child: Text('Save', style: Fonts.body(16, w: FontWeight.w800, color: AppColors.textOnPrimary))),
            )),
          ]),
        ]),
      )),
    ));
  }

  static const _avatars = ['🦜', '🐯', '🐘', '🦚', '🐒', '🦁', '🐼', '🦋', '🌸', '🚀', '⭐', '🐢'];

  Future<void> _pickAvatar() async {
    final store = context.read<AppStore>();
    await showModalBottomSheet(
      context: context, useRootNavigator: true, backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Rad.xl2))),
      builder: (ctx) => SafeArea(child: Padding(
        padding: const EdgeInsets.all(Sp.lg),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Choose your avatar', style: Fonts.display(20)),
          const SizedBox(height: Sp.md),
          Wrap(spacing: Sp.sm, runSpacing: Sp.sm, alignment: WrapAlignment.center, children: [
            for (final a in ['', ..._avatars]) GestureDetector(
              onTap: () { store.setAvatar(a); Navigator.of(ctx).pop(); },
              child: Container(width: 56, height: 56, alignment: Alignment.center,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.background,
                      border: Border.all(color: store.avatar == a ? AppColors.primary : AppColors.border, width: 2)),
                  child: a.isEmpty
                      ? Text(store.userName.isEmpty ? '?' : store.userName[0].toUpperCase(), style: Fonts.display(22))
                      : Text(a, style: const TextStyle(fontSize: 28))),
            ),
          ]),
        ]),
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final (userName, userLevel, isPremium, avatar) =
        context.select<AppStore, (String, int, bool, String)>(
            (store) => (store.userName, store.userLevel, store.isPremium, store.avatar));
    final menu = <(IconData, String)>[
      (Icons.person_outline, 'Edit Profile'),
      (Icons.notifications_none, 'Notifications'),
      (Icons.people_outline, 'Family / Classroom'),
      (Icons.bar_chart, 'Detailed Progress'),
      (Icons.diamond_outlined, isPremium ? 'Manage Subscription' : 'Go Premium'),
      (Icons.mail_outline, 'Send Feedback'),
      (Icons.help_outline, 'Help & Support'),
    ];
    void tap(String label) {
      switch (label) {
        case 'Edit Profile': _editProfile(); break;
        case 'Notifications': openScreen(context, 'Settings'); break;
        case 'Go Premium':
        case 'Manage Subscription': openScreen(context, 'Paywall'); break;
        case 'Family / Classroom':
        case 'Detailed Progress': openScreen(context, 'ParentDashboard'); break;
        case 'Send Feedback': _sendFeedback(); break;
        case 'Help & Support': openScreen(context, 'HelpSupport'); break;
      }
    }

    return Container(color: AppColors.background, child: SafeArea(bottom: false, child: SingleChildScrollView(
      padding: const EdgeInsets.all(Sp.md),
      child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          margin: const EdgeInsets.only(bottom: Sp.lg),
          padding: const EdgeInsets.symmetric(vertical: Sp.xl, horizontal: Sp.lg),
          decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(Rad.xl2), boxShadow: softShadow(AppColors.primary)),
          child: Column(children: [
            GestureDetector(
              onTap: _pickAvatar,
              child: Stack(clipBehavior: Clip.none, children: [
                Container(
                  width: 88, height: 88, alignment: Alignment.center, margin: const EdgeInsets.only(bottom: Sp.md),
                  decoration: BoxDecoration(color: AppColors.surface, shape: BoxShape.circle,
                      border: Border.all(color: AppColors.textOnPrimary, width: 3), boxShadow: toyShadow(AppColors.toyShadowColor, 6)),
                  child: avatar.isNotEmpty
                      ? Text(avatar, style: const TextStyle(fontSize: 44))
                      : Text(userName.isEmpty ? '' : userName[0].toUpperCase(),
                          style: Fonts.display(32, color: AppColors.primaryDark, w: FontWeight.w800)),
                ),
                const Positioned(right: -2, bottom: Sp.md - 2, child: CircleAvatar(radius: 13, backgroundColor: AppColors.primaryDark,
                    child: Icon(Icons.edit, size: 14, color: Colors.white))),
              ]),
            ),
            Text(userName, style: Fonts.display(24, color: AppColors.textOnPrimary, w: FontWeight.w800)),
            Opacity(opacity: 0.92, child: Text('Level $userLevel', style: Fonts.body(16, w: FontWeight.w700, color: AppColors.textOnPrimary))),
          ]),
        ),
        const ProfileProgressSummary(),
        const ProfileWeakLetters(),
        const ProfileWeeklyChart(),
        ProfileBadgeShowcase(onOpenRewards: () => AppShell.of(context)?.goTo(3)),
        const ProfileSettings(),
        const ProfileParentReport(),
        const SizedBox(height: Sp.sm),
        for (final m in menu) GestureDetector(
          onTap: () => tap(m.$2),
          child: Container(
            margin: const EdgeInsets.only(bottom: Sp.sm), padding: const EdgeInsets.all(Sp.md),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(Rad.xl), border: Border.all(color: AppColors.border),
                boxShadow: toyShadow(AppColors.toyShadowColor, 4)),
            child: Row(children: [
              Icon(m.$1, size: 22, color: AppColors.textPrimary), const SizedBox(width: Sp.md),
              Expanded(child: Text(m.$2, style: Fonts.body(16, w: FontWeight.w600, color: AppColors.textPrimary))),
              const Icon(Icons.chevron_right, size: 20, color: AppColors.textMuted),
            ]),
          ),
        ),
        GestureDetector(
          onTap: _signOut,
          child: Container(
            margin: const EdgeInsets.only(top: Sp.lg), padding: const EdgeInsets.symmetric(vertical: Sp.md),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(9999),
                border: Border.all(color: AppColors.error, width: 2), boxShadow: toyShadow(AppColors.toyShadowColor, 4)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.logout, size: 22, color: AppColors.error), const SizedBox(width: Sp.sm),
              Text('Sign Out', style: Fonts.body(16, w: FontWeight.w800, color: AppColors.error)),
            ]),
          ),
        ),
      ]))))
    ));
  }
}
