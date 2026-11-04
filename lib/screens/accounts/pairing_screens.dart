import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n.dart';
import '../../services/cloud.dart';
import '../../services/cloud_accounts.dart';
import '../../store/app_store.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../../widgets/common.dart';
import 'account_widgets.dart';

String _defaultDeviceName() {
  if (kIsWeb) return 'Web browser';
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => 'Android device',
    TargetPlatform.iOS => 'iPhone / iPad',
    TargetPlatform.windows => 'Windows PC',
    TargetPlatform.macOS => 'Mac',
    _ => 'Device',
  };
}

/// A child's own device joins their record with a pairing code from a
/// parent: no account or password, and their progress syncs from then on.
class PairDeviceScreen extends StatefulWidget {
  final Map<String, dynamic> params;
  const PairDeviceScreen({super.key, this.params = const {}});
  @override
  State<PairDeviceScreen> createState() => _PairDeviceScreenState();
}

class _PairDeviceScreenState extends State<PairDeviceScreen> {
  final code = TextEditingController(), name = TextEditingController(text: _defaultDeviceName());
  bool busy = false;
  String? error;

  Future<void> _join() async {
    setState(() { busy = true; error = null; });
    final s = context.read<AppStore>();
    try {
      await CloudAccounts.joinAsDevice(s, code.text, name.text.trim().isEmpty ? _defaultDeviceName() : name.text.trim());
      if (!mounted) return;
      final who = s.userName;
      Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(tr('Paired! Welcome back, $who', 'जुड़ गया! फिर से स्वागत है, $who'))));
    } on CloudError catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(bottom: false, child: Column(children: [
          HeaderBar(title: tr('Join with a code', 'कोड से जुड़ें'), subtitle: tr('Pair this device', 'यह डिवाइस जोड़ें'),
              onBack: () => Navigator.of(context).maybePop()),
          Expanded(child: screenScroll(maxWidth: 480, child: !Cloud.ready
              ? ToyCard(child: Text(tr('Pairing needs the cloud, which is not set up in this version of the app.',
                      'जोड़ने के लिए क्लाउड चाहिए, जो इस ऐप में अभी चालू नहीं है।'),
                  style: Fonts.body(15, color: AppColors.textSecondary)))
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Text('🔗', textAlign: TextAlign.center, style: TextStyle(fontSize: 48)),
                  const SizedBox(height: Sp.sm),
                  Text(tr('Ask your parent to open Parent control → your record → Pair a device, then type the code here.',
                          'अपने अभिभावक से कहें: अभिभावक नियंत्रण → आपका रिकॉर्ड → डिवाइस जोड़ें। फिर वह कोड यहाँ लिखें।'),
                      textAlign: TextAlign.center, style: Fonts.body(15, color: AppColors.textSecondary, height: 1.4)),
                  const SizedBox(height: Sp.lg),
                  AccountField(controller: code, label: tr('Pairing code', 'जोड़ने का कोड'), hint: 'K7M2-9XQD', maxLength: 12,
                      onSubmitted: (_) => busy ? null : _join()),
                  AccountField(controller: name, label: tr('Name this device', 'इस डिवाइस का नाम'),
                      hint: tr("e.g. Aarav's tablet", 'जैसे Aarav का टैबलेट'), maxLength: 30),
                  ResultButton(label: tr('Join', 'जुड़ें'), icon: Icons.link_rounded, onTap: busy ? null : _join),
                  if (busy) const Padding(padding: EdgeInsets.only(top: Sp.md), child: Center(child: CircularProgressIndicator())),
                  if (error != null) Padding(padding: const EdgeInsets.only(top: Sp.md),
                      child: Text(error!, textAlign: TextAlign.center, style: Fonts.body(14, w: FontWeight.w700, color: AppColors.error))),
                  const SizedBox(height: Sp.lg),
                  Text(tr('Parents: set up the app here first, then sign in from Parent control.',
                          'अभिभावक: पहले यहाँ ऐप सेट करें, फिर अभिभावक नियंत्रण से साइन इन करें।'),
                      textAlign: TextAlign.center, style: Fonts.body(12, color: AppColors.textMuted)),
                ]))),
        ])),
      );
}

/// Shows a fresh one-time code for [studentId] (`device` to pair a child's
/// device, `parent` to invite another parent), counts down to its expiry
/// and says when it has been used.
Future<void> showPairingCode(BuildContext context, {required String studentId, required String childName, required String kind}) async {
  (String, DateTime) created;
  try {
    created = await CloudAccounts.createCode(studentId, kind);
  } on CloudError catch (e) {
    if (context.mounted) showInfoDialog(context, tr('Cloud', 'क्लाउड'), e.message);
    return;
  }
  if (!context.mounted) return;
  final (code, expires) = created;
  var used = false;
  await showDialog<void>(context: context, barrierDismissible: false, builder: (ctx) {
    Timer? tick;
    StreamSubscription<bool>? sub;
    return StatefulBuilder(builder: (ctx, set) {
      tick ??= Timer.periodic(const Duration(seconds: 1), (_) { if (ctx.mounted) set(() {}); });
      sub ??= CloudAccounts.codeUsed(code).listen((_) { if (ctx.mounted) set(() => used = true); });
      final left = expires.difference(DateTime.now());
      final expired = left.isNegative;
      void close() { tick?.cancel(); sub?.cancel(); Navigator.of(ctx).pop(); }
      final device = kind == 'device';
      return AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rad.xl)),
        title: Text(device ? tr('Pair $childName\'s device', '$childName का डिवाइस जोड़ें') : tr('Invite another parent', 'दूसरे अभिभावक को बुलाएँ'),
            style: Fonts.display(20)),
        content: SizedBox(width: 340, child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (used) ...[
            Icon(Icons.check_circle_rounded, size: 56, color: AppColors.success),
            const SizedBox(height: Sp.sm),
            Text(device ? tr('Paired! $childName\'s progress now syncs from that device.', 'जुड़ गया! अब उस डिवाइस से $childName की प्रगति सिंक होगी।')
                    : tr('Joined! They can now follow $childName from their phone.', 'जुड़ गए! अब वे अपने फ़ोन से $childName को देख सकते हैं।'),
                textAlign: TextAlign.center, style: Fonts.body(15, w: FontWeight.w700)),
          ] else ...[
            Text(device
                    ? tr('On $childName\'s device: open HindiMitra → "Join with a code" and type:', '$childName के डिवाइस पर: HindiMitra → "कोड से जुड़ें" खोलें और लिखें:')
                    : tr('The other parent signs in, opens Parent control → "Join with an invite code" and types:',
                        'दूसरे अभिभावक साइन इन करके अभिभावक नियंत्रण → "इनवाइट कोड से जुड़ें" में लिखें:'),
                textAlign: TextAlign.center, style: Fonts.body(14, color: AppColors.textSecondary)),
            const SizedBox(height: Sp.md),
            SelectableText(code, style: TextStyle(fontFamily: 'monospace', fontSize: 34, fontWeight: FontWeight.w800,
                letterSpacing: 4, color: expired ? AppColors.textMuted : AppColors.primaryDark)),
            const SizedBox(height: Sp.sm),
            Text(expired ? tr('This code has expired.', 'यह कोड खत्म हो गया।')
                    : tr('Works once · expires in ${left.inMinutes}:${(left.inSeconds % 60).toString().padLeft(2, '0')}',
                        'एक बार चलेगा · ${left.inMinutes}:${(left.inSeconds % 60).toString().padLeft(2, '0')} में खत्म'),
                style: Fonts.body(13, w: FontWeight.w700, color: expired ? AppColors.error : AppColors.textMuted)),
            if (!expired) const Padding(padding: EdgeInsets.only(top: Sp.md), child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))),
          ],
        ])),
        actions: [
          TextButton(onPressed: () {
            if (!used) CloudAccounts.cancelCode(code);
            close();
          }, child: Text(used ? tr('Done', 'हो गया') : tr('Cancel', 'रद्द करें'),
              style: Fonts.body(15, w: FontWeight.w800, color: AppColors.primary))),
        ],
      );
    });
  });
}

/// The signed-in parent types an invite code from another parent.
Future<void> showJoinInvite(BuildContext context, String parentId) {
  final code = TextEditingController();
  String? error;
  var busy = false;
  return showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
    Future<void> join() async {
      set(() { busy = true; error = null; });
      final s = context.read<AppStore>();
      try {
        await CloudAccounts.joinAsParent(s, code.text, parentId);
        if (ctx.mounted) Navigator.of(ctx).pop();
        if (context.mounted) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(tr('Joined. The child appears in a moment.', 'जुड़ गए। बच्चा थोड़ी देर में दिखेगा।'))));
        }
      } on CloudError catch (e) {
        set(() { error = e.message; busy = false; });
      }
    }
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rad.xl)),
      title: Text(tr('Join with an invite code', 'इनवाइट कोड से जुड़ें'), style: Fonts.display(20)),
      content: SizedBox(width: 320, child: Column(mainAxisSize: MainAxisSize.min, children: [
        AccountField(controller: code, label: tr('Invite code from the other parent', 'दूसरे अभिभावक का इनवाइट कोड'),
            hint: 'K7M2-9XQD', maxLength: 12, onSubmitted: (_) => busy ? null : join()),
        if (busy) const CircularProgressIndicator(),
        if (error != null) Text(error!, style: Fonts.body(14, w: FontWeight.w700, color: AppColors.error)),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(),
            child: Text(tr('Cancel', 'रद्द करें'), style: Fonts.body(15, w: FontWeight.w800, color: AppColors.textSecondary))),
        TextButton(onPressed: busy ? null : join,
            child: Text(tr('Join', 'जुड़ें'), style: Fonts.body(15, w: FontWeight.w800, color: AppColors.primary))),
      ],
    );
  }));
}
