import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../data/accounts.dart';
import '../../l10n.dart';
import '../../routes.dart';
import '../../store/app_store.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../../widgets/common.dart';
import '../../widgets/toy_button.dart';
import 'code_pad.dart';
import 'pin_pad.dart';
import '../../app_session.dart';

/// Labelled text field in the app's card style.
class AccountField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboard;
  final bool obscure;
  final int? maxLength, maxLines;
  final List<TextInputFormatter>? formatters;
  final ValueChanged<String>? onSubmitted;
  const AccountField({super.key, required this.controller, required this.label, this.hint, this.keyboard,
      this.obscure = false, this.maxLength, this.maxLines = 1, this.formatters, this.onSubmitted});

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder b(Color c) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.lg), borderSide: BorderSide(color: c, width: 1.5));
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(bottom: Sp.xs),
            child: Text(label, style: Fonts.body(13, w: FontWeight.w700, color: AppColors.textSecondary))),
        TextField(
          controller: controller, keyboardType: keyboard, obscureText: obscure, maxLength: maxLength,
          maxLines: maxLines, inputFormatters: formatters, onSubmitted: onSubmitted, style: Fonts.body(16, color: AppColors.textPrimary),
          decoration: InputDecoration(
            counterText: '', hintText: hint, hintStyle: Fonts.body(15, color: AppColors.textMuted),
            filled: true, fillColor: AppColors.surface, isDense: true, contentPadding: const EdgeInsets.all(Sp.md),
            border: b(AppColors.border), enabledBorder: b(AppColors.border), focusedBorder: b(AppColors.primary),
          ),
        ),
      ]),
    );
  }
}

/// An account ID in monospace with a copy button.
class IdChip extends StatelessWidget {
  final String id;
  final Color? color;
  const IdChip(this.id, {super.key, this.color});
  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primaryDark;
    return Pressable(
      onTap: () {
        Clipboard.setData(ClipboardData(text: id));
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(tr('Copied $id', '$id कॉपी हुआ'))));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(9999),
            border: Border.all(color: c.withOpacity(0.25))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: Text(id,
              style: TextStyle(fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.w700, color: c, letterSpacing: 0.5)))),
          const SizedBox(width: 6),
          Icon(Icons.copy_rounded, size: 14, color: c),
        ]),
      ),
    );
  }
}

/// Label on the left, value (or a widget) on the right.
class InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final Widget? trailing;
  const InfoRow({super.key, required this.icon, required this.label, this.value, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Icon(icon, size: 18, color: AppColors.textMuted),
          const SizedBox(width: Sp.sm),
          Text(label, style: Fonts.body(14, color: AppColors.textSecondary)),
          const SizedBox(width: Sp.sm),
          Expanded(child: Align(alignment: Alignment.centerRight,
              child: trailing != null ? FittedBox(fit: BoxFit.scaleDown, child: trailing) :
              Text(value == null || value!.isEmpty ? '—' : value!, textAlign: TextAlign.right,
                  style: Fonts.body(14, w: FontWeight.w700, color: value == null || value!.isEmpty ? AppColors.textMuted : AppColors.textPrimary)))),
        ]),
      );
}

/// Section title used on the account screens.
Widget accountSection(String t, {Widget? action}) => Padding(
      padding: const EdgeInsets.only(top: Sp.lg, bottom: Sp.sm),
      child: Row(children: [
        Expanded(child: Text(t, style: Fonts.display(17))),
        if (action != null) action,
      ]),
    );

/// Round avatar: the emoji, or the name's first letter.
Widget learnerAvatar(String name, String avatar, {double size = 44, Color? ring}) => Container(
      width: size, height: size, alignment: Alignment.center,
      decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), shape: BoxShape.circle,
          border: Border.all(color: ring ?? AppColors.border, width: 2)),
      child: avatar.isNotEmpty
          ? Text(avatar, style: TextStyle(fontSize: size * 0.5))
          : Text(name.isEmpty ? '?' : name[0].toUpperCase(), style: Fonts.display(size * 0.42, color: AppColors.primaryDark)),
    );

/// Asks for a PIN on the full-screen pad. With [check] it keeps asking
/// until the PIN passes (or the parent goes back) and returns it; without,
/// it asks twice for a new PIN and refuses easy ones.
Future<String?> showPinDialog(BuildContext context, {required String title, bool Function(String pin)? check}) =>
    check == null ? createPin(context, title: title) : checkPinScreen(context, title: title, check: check);

/// Asks a parent to unlock parent mode and returns them, or null. Parents
/// linked to [forStudentId] are offered first (any parent if none is
/// linked); with no parent on the device yet, the parent sign-up opens.
Future<ParentAccount?> requireParent(BuildContext context, {String? forStudentId}) async {
  final s = context.read<AppStore>();
  final withPin = s.parents.where((p) => !p.contactOnly).toList();
  if (withPin.isEmpty) {
    // On a child's paired device the parents are known, but parent control
    // lives on their own phone.
    final known = s.parents.where((p) => p.contactOnly).toList();
    if (known.isNotEmpty) {
      await showInfoDialog(context, tr('Parent control', 'अभिभावक नियंत्रण'),
          tr('This device is paired to a child. ${known.first.name} manages homework and details from their own phone. '
                  'To use parent control here, sign in as that parent.',
              'यह डिवाइस बच्चे से जुड़ा है। ${known.first.name} अपने फ़ोन से होमवर्क और जानकारी संभालते हैं। '
                  'यहाँ अभिभावक नियंत्रण के लिए उसी अभिभावक के रूप में साइन इन करें।'),
          actions: [(tr('Not now', 'अभी नहीं'), null)]);
      return null;
    }
    return await openScreen<ParentAccount>(context, 'ParentSetup');
  }
  final linked = forStudentId == null ? <ParentAccount>[] : s.parentsOf(forStudentId).where((p) => !p.contactOnly).toList();
  final options = linked.isNotEmpty ? linked : withPin;
  ParentAccount? who = options.length == 1 ? options.first : null;
  if (who == null) {
    who = await showModalBottomSheet<ParentAccount>(
      context: context, useRootNavigator: true, backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Rad.xl2))),
      builder: (ctx) => SafeArea(child: Padding(padding: const EdgeInsets.all(Sp.lg), child: Column(
        mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(tr('Who is this?', 'आप कौन हैं?'), style: Fonts.display(20)),
          const SizedBox(height: Sp.md),
          for (final p in options) ToyCard(
            margin: const EdgeInsets.only(bottom: Sp.sm), onTap: () => Navigator.of(ctx).pop(p),
            child: Row(children: [
              learnerAvatar(p.name, ''), const SizedBox(width: Sp.md),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.name, style: Fonts.body(16, w: FontWeight.w800)),
                Text('${p.relationship} · ${p.id}', style: Fonts.body(12, color: AppColors.textSecondary)),
              ])),
              Icon(Icons.chevron_right, color: AppColors.textMuted),
            ]),
          ),
        ],
      ))),
    );
    if (who == null || !context.mounted) return null;
  }
  final p = who;
  return await verifyParentPin(context, p) ? p : null;
}

/// Bottom sheet listing every learner on the device: switch to one, add a
/// learner, or open parent control.
Future<void> showLearnerSwitcher(BuildContext context) => showModalBottomSheet(
      context: context, useRootNavigator: true, isScrollControlled: true, backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Rad.xl2))),
      builder: (ctx) {
        final s = ctx.watch<AppStore>();
        return SafeArea(child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.8),
          child: SingleChildScrollView(padding: const EdgeInsets.all(Sp.lg), child: Column(
            mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(tr("Who's learning?", 'कौन सीख रहा है?'), style: Fonts.display(22)),
              Text(tr('${s.learners.length} learner${s.learners.length == 1 ? '' : 's'} on this device',
                  'इस डिवाइस पर ${s.learners.length} विद्यार्थी'), style: Fonts.body(14, color: AppColors.textSecondary)),
              const SizedBox(height: Sp.md),
              for (final st in s.learners) Builder(builder: (_) {
                final active = st.id == s.activeStudentId;
                return ToyCard(
                  margin: const EdgeInsets.only(bottom: Sp.sm),
                  borderColor: active ? AppColors.primary : null, borderWidth: active ? 2 : 1,
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    if (active) return;
                    // Each learner's profile opens with their own code.
                    if (!await verifyStudentCode(context, st.id) || !context.mounted) return;
                    Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
                    s.switchStudent(st.id);
                  },
                  child: Row(children: [
                    learnerAvatar(st.name, st.avatar, ring: active ? AppColors.primary : null),
                    const SizedBox(width: Sp.md),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(st.name, style: Fonts.body(16, w: FontWeight.w800)),
                      Text(st.id, style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: AppColors.textSecondary)),
                    ])),
                    if (active) SoftPill(icon: Icons.check_rounded, label: tr('Active', 'चालू'), color: AppColors.success),
                  ]),
                );
              }),
              const SizedBox(height: Sp.sm),
              Row(children: [
                Expanded(child: ResultButton(label: tr('Add learner', 'विद्यार्थी जोड़ें'), icon: Icons.person_add_alt_1_rounded,
                    filled: false, onTap: () async {
                      Navigator.of(ctx).pop();
                      final st = await showAddLearnerDialog(context);
                      if (st != null && context.mounted) await showStudentCode(context, st);
                      if (st != null && context.mounted) {
                        Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
                        context.read<AppStore>().switchStudent(st.id);
                      }
                    })),
                const SizedBox(width: Sp.sm),
                Expanded(child: ResultButton(label: tr('Parent control', 'अभिभावक नियंत्रण'), icon: Icons.shield_rounded,
                    onTap: () { Navigator.of(ctx).pop(); openParentControl(context); })),
              ]),
              TextButton.icon(
                onPressed: () { Navigator.of(ctx).pop(); AppSession.chooseAgain(context); },
                icon: Icon(Icons.people_alt_rounded, color: AppColors.primary),
                label: Text(tr("Switch user (Who's using?)", 'उपयोगकर्ता बदलें'),
                    style: Fonts.body(14, w: FontWeight.w700, color: AppColors.primary)),
              ),
              TextButton.icon(
                onPressed: () { Navigator.of(ctx).pop(); openScreen(context, 'PairDevice'); },
                icon: Icon(Icons.link_rounded, color: AppColors.primary),
                label: Text(tr('Join with a code from a parent', 'अभिभावक के कोड से जुड़ें'),
                    style: Fonts.body(14, w: FontWeight.w700, color: AppColors.primary)),
              ),
            ],
          )),
        ));
      },
    );

/// Unlocks and opens the parent control centre.
Future<void> openParentControl(BuildContext context) async {
  final p = await requireParent(context, forStudentId: context.read<AppStore>().activeStudentId);
  if (p != null && context.mounted) openScreen(context, 'ParentHub', {'parentId': p.id});
}

/// Adds another parent or guardian. While a parent with a PIN exists, one
/// of them must approve with their PIN first ([approvedBy] skips that when
/// they are already signed in to the Parent Hub), so a child cannot make
/// themselves a parent account. The new parent is linked to the approving
/// parent's children. Returns the new parent, or null.
Future<ParentAccount?> addAnotherParent(BuildContext context, {ParentAccount? approvedBy}) async {
  final s = context.read<AppStore>();
  var approver = approvedBy;
  if (approver == null && s.parents.any((p) => !p.contactOnly)) {
    final go = await confirmDialog(context, title: tr('Add a parent', 'अभिभावक जोड़ें'),
        message: tr('A parent already on this device needs to approve with their PIN.',
            'इस डिवाइस पर पहले से मौजूद अभिभावक को अपने पिन से मंज़ूरी देनी होगी।'),
        confirmLabel: tr('Continue', 'आगे'), cancelLabel: tr('Cancel', 'रद्द करें'));
    if (!go || !context.mounted) return null;
    approver = await requireParent(context);
    if (approver == null || !context.mounted) return null;
  }
  final added = await openScreen<ParentAccount>(context, 'ParentSetup');
  if (added == null || !context.mounted) return null;
  if (approver != null) {
    for (final k in s.childrenOf(approver.id)) { s.linkParent(k.id, added.id); }
  }
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(
      tr('${added.name} added as a parent', '${added.name} अभिभावक के रूप में जुड़े'))));
  return added;
}

/// Asks for a new learner's name and age, adds them (linked to [parentId]
/// when given) and returns them.
Future<StudentAccount?> showAddLearnerDialog(BuildContext context, {String? parentId}) {
  final name = TextEditingController();
  String age = 'kid-7-10';
  const ages = [('kid-4-6', '4–6'), ('kid-7-10', '7–10'), ('teen', '11–16'), ('adult', '17+')];
  return showDialog<StudentAccount>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, set) => AlertDialog(
    backgroundColor: AppColors.surface,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rad.xl)),
    title: Text(tr('Add a learner', 'विद्यार्थी जोड़ें'), style: Fonts.display(20)),
    content: SizedBox(width: 320, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      AccountField(controller: name, label: tr("Learner's name", 'विद्यार्थी का नाम'), hint: tr('e.g. Aarav', 'जैसे Aarav'), maxLength: 30),
      Text(tr('Age', 'उम्र'), style: Fonts.body(13, w: FontWeight.w700, color: AppColors.textSecondary)),
      const SizedBox(height: Sp.xs),
      Wrap(spacing: Sp.xs, runSpacing: Sp.xs, children: [
        for (final a in ages) ChoiceChip(label: Text(a.$2), selected: age == a.$1, onSelected: (_) => set(() => age = a.$1)),
      ]),
      const SizedBox(height: Sp.sm),
      Text(tr('A Student ID is created for them. Their progress is kept separately.',
              'उनके लिए एक Student ID बनेगी। उनकी प्रगति अलग से सेव होगी।'),
          style: Fonts.body(13, color: AppColors.textSecondary)),
    ])),
    actions: [
      TextButton(onPressed: () => Navigator.of(ctx).pop(),
          child: Text(tr('Cancel', 'रद्द करें'), style: Fonts.body(15, w: FontWeight.w800, color: AppColors.textSecondary))),
      TextButton(onPressed: () {
        if (name.text.trim().isEmpty) return;
        Navigator.of(ctx).pop(context.read<AppStore>().addStudent(name.text, ageGroup: age, parentId: parentId));
      }, child: Text(tr('Add', 'जोड़ें'), style: Fonts.body(15, w: FontWeight.w800, color: AppColors.primary))),
    ],
  )));
}

/// Short date (e.g. 3 Nov 2026) from an ISO date or timestamp.
String shortDate(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final d = DateTime.tryParse(iso)?.toLocal();
  if (d == null) return iso;
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${m[d.month - 1]} ${d.year}';
}
