import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/accounts.dart';
import '../../l10n.dart';
import '../../routes.dart';
import '../../services/cloud.dart';
import '../../store/app_store.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../../widgets/common.dart';
import 'account_widgets.dart';
import 'code_pad.dart';

/// The old 4-digit parent PIN pad: a [CodePad] with only the numbers.
class PinPad extends StatelessWidget {
  final int length;
  final Future<String?> Function(String pin) onComplete;
  final DateTime? lockedUntil;
  final String? message;
  final VoidCallback? onAccepted;
  const PinPad({super.key, this.length = 4, required this.onComplete, this.onAccepted, this.lockedUntil, this.message});
  @override
  Widget build(BuildContext context) => CodePad(length: length, digitsOnly: true, visible: false,
      onComplete: onComplete, onAccepted: onAccepted, lockedUntil: lockedUntil, message: message);
}

/// Full-screen page around a [CodePad], laid out like a phone lock screen:
/// the avatar (or a shield), title and subtitle at the top, the pad's slots
/// and keyboard at the bottom, and an optional link (e.g. "Forgot PIN?").
class PinScreen extends StatelessWidget {
  final String title;
  final String? subtitle, avatarName;
  final Widget pad;
  final Widget? footer, avatar;
  const PinScreen({super.key, required this.title, this.subtitle, this.avatarName, this.avatar, required this.pad, this.footer});
  @override
  Widget build(BuildContext context) {
    final top = Column(mainAxisSize: MainAxisSize.min, children: [
      Stack(clipBehavior: Clip.none, children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.surface, boxShadow: softShadow(AppColors.primary)),
          child: avatar ?? (avatarName != null ? learnerAvatar(avatarName!, '', size: 80, ring: AppColors.success)
              : Container(width: 80, height: 80, decoration: BoxDecoration(gradient: toneGradient(AppColors.success),
                  shape: BoxShape.circle), child: const Icon(Icons.shield_rounded, color: Colors.white, size: 38))),
        ),
        Positioned(right: -2, bottom: -2, child: Container(width: 32, height: 32,
            decoration: BoxDecoration(gradient: toneGradient(AppColors.primary), shape: BoxShape.circle,
                border: Border.all(color: AppColors.surface, width: 2.5)),
            child: const Icon(Icons.lock_rounded, size: 16, color: Colors.white))),
      ]),
      const SizedBox(height: Sp.md),
      Text(title, textAlign: TextAlign.center, style: Fonts.display(26, height: 1.15)),
      if (subtitle != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(subtitle!, textAlign: TextAlign.center,
          style: Fonts.body(15, w: FontWeight.w600, color: AppColors.textSecondary, height: 1.35))),
    ]);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(child: Column(children: [
        HeaderBar(title: '', onBack: () => Navigator.of(context).maybePop()),
        Expanded(child: LayoutBuilder(builder: (_, c) => SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: Sp.md),
          child: ConstrainedBox(
            // At least the screen's height: the title sits at the top, the
            // pad at the bottom near the thumbs, like a phone lock screen.
            constraints: BoxConstraints(minHeight: c.maxHeight),
            child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 460), child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Padding(padding: const EdgeInsets.only(top: Sp.sm, bottom: Sp.lg), child: PopIn(child: top)),
                Padding(padding: const EdgeInsets.only(bottom: Sp.md), child: Column(mainAxisSize: MainAxisSize.min, children: [
                  pad,
                  if (footer != null) Padding(padding: const EdgeInsets.only(top: Sp.xs), child: footer!),
                ])),
              ],
            ))),
          ),
        ))),
      ])),
    );
  }
}

/// Asks [p] for their PIN on a full screen. True once it is right. Wrong
/// PINs count towards the lock in [AppStore.checkParentPin]. An old 4-digit
/// PIN still opens, then the parent is asked for a 6-character one.
Future<bool> verifyParentPin(BuildContext context, ParentAccount p) async {
  final s = context.read<AppStore>();
  // "Stay unlocked" chosen a little while ago on this device.
  if (!p.legacyPin && s.parentStillUnlocked(p.id)) {
    s.markLastUser(p.id);
    return true;
  }
  final ok = await Navigator.of(context, rootNavigator: true).push<bool>(MaterialPageRoute(
      builder: (_) => _VerifyPin(parentId: p.id), settings: const RouteSettings(name: 'ParentPin')));
  if (ok != true || !context.mounted) return false;
  s.markLastUser(p.id);
  if (p.legacyPin) await _upgradePin(context, p);
  return true;
}

/// Moves a parent from an old 4-digit PIN to a 6-character one. If they
/// go back, they are asked again next time.
Future<void> _upgradePin(BuildContext context, ParentAccount p) async {
  final go = await confirmDialog(context, title: tr('New: a stronger PIN', 'नया: मज़बूत पिन'),
      message: tr('Parent PINs are now 6 letters and numbers (like STAR58), much harder for little ones to guess. '
              'Set yours now?',
          'अभिभावक पिन अब 6 अक्षर और अंक के होते हैं (जैसे STAR58), जिन्हें बच्चे आसानी से नहीं जान सकते। अभी बनाएँ?'),
      confirmLabel: tr('Set new PIN', 'नया पिन बनाएँ'), cancelLabel: tr('Later', 'बाद में'));
  if (!go || !context.mounted) return;
  final pin = await createPin(context, parentId: p.id);
  if (pin == null || !context.mounted) return;
  context.read<AppStore>().updateParent(p.id, pin: pin);
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(tr('New PIN saved', 'नया पिन सेव हुआ'))));
}

class _VerifyPin extends StatefulWidget {
  final String parentId;
  const _VerifyPin({required this.parentId});
  @override
  State<_VerifyPin> createState() => _VerifyPinState();
}

class _VerifyPinState extends State<_VerifyPin> {
  bool stay = false;
  /// Minutes "Stay unlocked" keeps the Parent Hub open on this device.
  static const stayMinutes = 15;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    final parentId = widget.parentId;
    final p = s.parentById(parentId);
    if (p == null) return const SizedBox.shrink();
    final left = AppStore.pinFreeTries - s.pinFailures(parentId);
    Future<String?> check(String pin) async => switch (s.checkParentPin(parentId, pin)) {
          PinCheck.ok => null,
          PinCheck.locked => tr('Too many wrong PINs.', 'बहुत बार गलत पिन।'),
          PinCheck.wrong => left - 1 <= 2
              ? tr('Wrong PIN. ${left - 1} ${left - 1 == 1 ? 'try' : 'tries'} left before a short lock.', 'गलत पिन। लॉक से पहले ${left - 1} कोशिश बाकी।')
              : tr('Wrong PIN, try again.', 'गलत पिन, फिर कोशिश करें।'),
        };
    void accepted() {
      s.keepParentUnlocked(parentId, stay ? stayMinutes : 0);
      Navigator.of(context).pop(true);
    }
    return PinScreen(
      title: tr('Hi ${p.name.split(' ').first}', 'नमस्ते ${p.name.split(' ').first}'),
      subtitle: p.legacyPin ? tr('Enter your 4-digit parent PIN', 'अपना 4 अंकों का अभिभावक पिन डालें')
          : tr('Enter your 6-character parent PIN', 'अपना 6 अक्षरों का अभिभावक पिन डालें'),
      avatarName: p.name,
      pad: p.legacyPin
          ? PinPad(lockedUntil: s.pinLockedUntil(parentId), onComplete: check, onAccepted: accepted)
          // Dots, not letters: someone looking over a parent's shoulder sees nothing.
          : CodePad(visible: false, lockedUntil: s.pinLockedUntil(parentId), onComplete: check, onAccepted: accepted),
      footer: Column(mainAxisSize: MainAxisSize.min, children: [
        if (!p.legacyPin) RememberSwitch(
          value: stay, onChanged: (v) => setState(() => stay = v),
          label: tr('Stay unlocked for $stayMinutes minutes', '$stayMinutes मिनट तक खुला रखें'),
          hint: tr('Come back to the Parent Hub without the PIN. Tap Lock to end it early.',
              'बिना पिन के अभिभावक केंद्र में लौटें। पहले बंद करने के लिए लॉक दबाएँ।'),
        ),
        TextButton(
          onPressed: () => _forgotPin(context, p),
          child: Text(tr('Forgot PIN?', 'पिन भूल गए?'), style: Fonts.body(14, w: FontWeight.w800, color: AppColors.primaryDark)),
        ),
      ]),
    );
  }
}

/// A forgotten PIN is reset by signing in to the parent's cloud account
/// again. Without one it cannot be recovered on this device, by design:
/// otherwise a child could reset it too.
Future<void> _forgotPin(BuildContext context, ParentAccount p) async {
  final canCloud = Cloud.ready && p.cloudUid.isNotEmpty;
  if (!canCloud) {
    await showInfoDialog(context, tr('Forgot PIN', 'पिन भूल गए'),
        tr('For your child’s safety, the PIN can only be reset by signing in to your HindiMitra parent account. '
                'This parent has no cloud account on this device, so ask the person who set the PIN, or turn on cloud backup next time.',
            'बच्चे की सुरक्षा के लिए पिन केवल अभिभावक खाते में साइन इन करके बदला जा सकता है। '
                'इस अभिभावक का इस डिवाइस पर क्लाउड खाता नहीं है, इसलिए पिन बनाने वाले से पूछें।'));
    return;
  }
  final go = await confirmDialog(context, title: tr('Reset your PIN', 'पिन बदलें'),
      message: tr('Sign in to your parent account (${p.email.isNotEmpty ? p.email : p.phone}) to choose a new PIN.',
          'नया पिन चुनने के लिए अपने अभिभावक खाते में साइन इन करें।'),
      confirmLabel: tr('Sign in', 'साइन इन'), cancelLabel: tr('Cancel', 'रद्द करें'));
  if (!go || !context.mounted) return;
  final u = await openScreen<User>(context, 'CloudSignIn');
  if (u == null || !context.mounted) return;
  if (u.uid != p.cloudUid) {
    await showInfoDialog(context, tr('Different account', 'दूसरा खाता'),
        tr('That is not ${p.name}’s account. The PIN was not changed.', 'यह ${p.name} का खाता नहीं है। पिन नहीं बदला।'));
    return;
  }
  final pin = await createPin(context, title: tr('Choose a new PIN', 'नया पिन चुनें'), parentId: p.id);
  if (pin == null || !context.mounted) return;
  context.read<AppStore>().updateParent(p.id, pin: pin);
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(tr('PIN changed. Enter it to continue.', 'पिन बदल गया। आगे बढ़ने के लिए डालें।'))));
}

/// Asks for a new 6-character parent PIN (letters and numbers) twice.
/// Easy ones (AAA222, ABC234) and ones matching a child's code or another
/// parent's PIN are refused ([AppStore.parentPinProblem]). Returns the PIN,
/// or null if the parent went back. [parentId] is the parent changing theirs.
Future<String?> createPin(BuildContext context, {String? title, String? parentId}) => Navigator.of(context, rootNavigator: true)
    .push<String>(MaterialPageRoute(builder: (_) => _CreatePin(title: title, parentId: parentId),
        settings: const RouteSettings(name: 'CreatePin')));

class _CreatePin extends StatefulWidget {
  final String? title, parentId;
  const _CreatePin({this.title, this.parentId});
  @override
  State<_CreatePin> createState() => _CreatePinState();
}

class _CreatePinState extends State<_CreatePin> {
  String? first;
  final _pad = GlobalKey<CodePadState>();

  static String problemMessage(String reason) => switch (reason) {
        'mix' => tr('Use letters and numbers, like STAR58.', 'अक्षर और अंक दोनों रखें, जैसे STAR58।'),
        'same' => tr('Use at least 3 different characters.', 'कम से कम 3 अलग अक्षर/अंक रखें।'),
        'sequence' => tr('Letters and numbers in a row (like ABC234) are too easy.', 'क्रम वाले अक्षर और अंक (जैसे ABC234) आसान हैं।'),
        'taken' => tr('That’s a child’s code or another parent’s PIN. Pick another.', 'यह किसी बच्चे का कोड या दूसरे अभिभावक का पिन है। दूसरा चुनें।'),
        _ => tr('That PIN can’t be used. Pick another.', 'यह पिन नहीं चल सकता। दूसरा चुनें।'),
      };

  @override
  Widget build(BuildContext context) => PinScreen(
        title: first == null ? (widget.title ?? tr('Create a parent PIN', 'अभिभावक पिन बनाएँ')) : tr('Enter it again', 'फिर से डालें'),
        subtitle: first == null
            ? tr('6 letters and numbers your child doesn’t know, like STAR58. You’ll use it to open the Parent Hub.',
                '6 अक्षर और अंक जो बच्चे को न पता हों, जैसे STAR58। इससे अभिभावक केंद्र खुलेगा।')
            : tr('To make sure it’s right', 'पक्का करने के लिए'),
        pad: CodePad(
          key: _pad,
          onComplete: (pin) async {
            if (first == null) {
              final problem = context.read<AppStore>().parentPinProblem(pin, parentId: widget.parentId);
              if (problem != null) return problemMessage(problem);
              setState(() => first = pin);
              _pad.currentState?.reset();
              return null;
            }
            if (pin != first) {
              setState(() => first = null);
              _pad.currentState?.reset();
              return tr("The PINs didn't match. Start again.", 'पिन मेल नहीं खाए। फिर से शुरू करें।');
            }
            Navigator.of(context).pop(pin);
            return null;
          },
        ),
        footer: Padding(
          padding: const EdgeInsets.only(top: Sp.sm),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            for (int i = 0; i < 2; i++) Container(margin: const EdgeInsets.symmetric(horizontal: 4), width: i == (first == null ? 0 : 1) ? 22 : 8,
                height: 8, decoration: BoxDecoration(color: i == (first == null ? 0 : 1) ? AppColors.primary : AppColors.border,
                    borderRadius: BorderRadius.circular(9999))),
          ]),
        ),
      );
}

/// A PIN check against [check] with no lock (kept for older callers).
Future<String?> checkPinScreen(BuildContext context, {required String title, required bool Function(String) check}) =>
    Navigator.of(context, rootNavigator: true).push<String>(MaterialPageRoute(builder: (ctx) => PinScreen(
      title: title,
      pad: CodePad(visible: false, onComplete: (pin) async {
        if (!check(pin)) return tr('Wrong PIN, try again.', 'गलत पिन, फिर कोशिश करें।');
        Navigator.of(ctx).pop(pin);
        return null;
      }),
    )));
