import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/accounts.dart';
import '../../l10n.dart';
import '../../routes.dart';
import '../../services/cloud_accounts.dart';
import '../../store/app_store.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../../widgets/common.dart';
import '../accounts/account_widgets.dart';
import '../accounts/cloud_sign_in_screen.dart';
import '../accounts/pairing_screens.dart';
import '../accounts/pin_pad.dart';
import 'challenges_screen.dart';
import 'hub_widgets.dart';

/// Parent Hub settings: the parent's account, cloud backup, linking a
/// child by Student ID, and locking the hub.
class ParentSettingsTab extends StatefulWidget {
  const ParentSettingsTab({super.key});
  @override
  State<ParentSettingsTab> createState() => _ParentSettingsTabState();
}

class _ParentSettingsTabState extends State<ParentSettingsTab> {
  final idField = TextEditingController();
  String? linkError;

  @override
  void dispose() { idField.dispose(); super.dispose(); }

  void _linkById(String parentId) {
    final s = context.read<AppStore>();
    final id = AccountIds.normalize(idField.text, AccountIds.student);
    String? err;
    if (id == null) {
      err = tr('That is not a valid Student ID. It looks like HMS-XXXX-XXXX.', 'यह सही Student ID नहीं है। यह HMS-XXXX-XXXX जैसी होती है।');
    } else if (s.studentById(id) == null) {
      err = tr('No learner with $id on this device.', 'इस डिवाइस पर $id वाला कोई विद्यार्थी नहीं है।');
    } else if (s.studentById(id)!.parentIds.contains(parentId)) {
      err = tr('$id is already linked to you.', '$id पहले से आपसे जुड़ा है।');
    }
    setState(() => linkError = err);
    if (err != null) return;
    s.linkParent(id!, parentId);
    idField.clear();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Linked ${s.studentById(id)!.name}', '${s.studentById(id)!.name} जुड़ गए'))));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    final parentId = ParentHubScope.of(context).parentId;
    final p = s.parentById(parentId)!;
    final mine = s.childrenOf(parentId);
    final others = s.learners.where((st) => !st.parentIds.contains(parentId)).toList();
    return SafeArea(bottom: false, child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Sp.md, Sp.md, Sp.md, Sp.xxl),
      child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760), child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(tr('Settings', 'सेटिंग्स'), style: Fonts.display(26, height: 1.1)),
          const SizedBox(height: Sp.md),
          Container(
            padding: const EdgeInsets.all(Sp.lg),
            decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.success, shade(AppColors.success, 0.12)]),
                borderRadius: BorderRadius.circular(Rad.xl2), boxShadow: softShadow(AppColors.success)),
            child: Row(children: [
              learnerAvatar(p.name, '', size: 56, ring: Colors.white),
              const SizedBox(width: Sp.md),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.name, style: Fonts.display(22, color: Colors.white)),
                Text(p.relationship, style: Fonts.body(14, w: FontWeight.w700, color: Colors.white.withOpacity(0.9))),
                const SizedBox(height: 6),
                IdChip(p.id, color: Colors.white),
              ])),
              SoftPill(icon: Icons.edit_rounded, color: Colors.white, onTap: () => openScreen(context, 'ParentSetup', {'parentId': p.id})),
            ]),
          ),
          HubSection(tr('Parent Hub', 'अभिभावक केंद्र')),
          ToyCard(padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.xs), child: Column(children: [
            _Tile(icon: Icons.emoji_events_rounded, label: tr('Challenges & goals', 'चुनौतियाँ और लक्ष्य'),
                onTap: () => pushHub(context, const ChallengesScreen())),
            _Tile(icon: Icons.password_rounded, label: tr('Change PIN', 'पिन बदलें'), onTap: () async {
              final pin = await createPin(context, title: tr('New PIN', 'नया पिन'), parentId: p.id);
              if (pin != null && context.mounted) {
                s.updateParent(p.id, pin: pin);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('PIN changed', 'पिन बदल गया'))));
              }
            }),
            _Tile(icon: Icons.lock_rounded, label: tr('Lock Parent Hub', 'अभिभावक केंद्र लॉक करें'),
                onTap: () => lockParentHub(context)),
          ])),
          HubSection(tr('Parents & guardians', 'अभिभावक'), action: SoftPill(icon: Icons.person_add_alt_1_rounded,
              label: tr('Add parent', 'अभिभावक जोड़ें'), onTap: () => addAnotherParent(context, approvedBy: p))),
          ToyCard(padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.xs), child: Column(children: [
            for (final o in s.parents.where((x) => !x.contactOnly)) Padding(
              padding: const EdgeInsets.symmetric(vertical: Sp.sm),
              child: Row(children: [
                learnerAvatar(o.name, '', size: 40, ring: o.id == p.id ? AppColors.success : null),
                const SizedBox(width: Sp.md),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(o.name, style: Fonts.body(15, w: FontWeight.w800)),
                  Text(tr('${o.relationship} · ${s.childrenOf(o.id).length} children', '${o.relationship} · ${s.childrenOf(o.id).length} बच्चे'),
                      style: Fonts.body(12.5, w: FontWeight.w600, color: AppColors.textSecondary)),
                ])),
                if (o.id == p.id) SoftPill(label: tr('You', 'आप'), color: AppColors.success)
                else if (o.legacyPin) SoftPill(icon: Icons.info_outline_rounded, label: tr('Old PIN', 'पुराना पिन'), color: AppColors.textSecondary),
              ]),
            ),
            Padding(padding: const EdgeInsets.only(bottom: Sp.sm), child: Text(
                tr('Each parent has their own 6-character PIN. A new parent is linked to your children.',
                    'हर अभिभावक का अपना 6 अक्षरों का पिन होता है। नए अभिभावक आपके बच्चों से जुड़ जाते हैं।'),
                style: Fonts.body(12.5, w: FontWeight.w600, color: AppColors.textMuted))),
          ])),
          HubSection(tr('Cloud backup', 'क्लाउड बैकअप')),
          CloudAccountCard(parentId: p.id),
          HubSection(tr('Link a child', 'बच्चा जोड़ें')),
          ToyCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(tr('Enter the Student ID shown in their Profile, under Important information.',
                    'उनकी प्रोफ़ाइल में ज़रूरी जानकारी के नीचे दिखी Student ID डालें।'),
                style: Fonts.body(13, color: AppColors.textSecondary)),
            const SizedBox(height: Sp.sm),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: AccountField(controller: idField, label: tr('Student ID', 'Student ID'), hint: 'HMS-XXXX-XXXX', maxLength: 16)),
              const SizedBox(width: Sp.sm),
              Padding(padding: const EdgeInsets.only(top: 24), child: SizedBox(width: 110,
                  child: ResultButton(label: tr('Link', 'जोड़ें'), icon: Icons.link_rounded, onTap: () => _linkById(parentId)))),
            ]),
            if (linkError != null) Text(linkError!, style: Fonts.body(13, w: FontWeight.w700, color: AppColors.error)),
            if (p.cloudUid.isNotEmpty && CloudAccounts.user?.uid == p.cloudUid) Padding(
              padding: const EdgeInsets.only(top: Sp.sm),
              child: Align(alignment: Alignment.centerLeft, child: SoftPill(icon: Icons.mail_lock_rounded,
                  label: tr('Join with an invite code', 'इनवाइट कोड से जुड़ें'), onTap: () => showJoinInvite(context, p.id))),
            ),
            if (others.isNotEmpty) ...[
              const SizedBox(height: Sp.sm),
              Text(tr('Other learners on this device', 'इस डिवाइस पर अन्य विद्यार्थी'),
                  style: Fonts.body(13, w: FontWeight.w800, color: AppColors.textSecondary)),
              for (final o in others) Padding(
                padding: const EdgeInsets.only(top: Sp.sm),
                child: Row(children: [
                  learnerAvatar(o.name, o.avatar, size: 36), const SizedBox(width: Sp.sm),
                  Expanded(child: Text('${o.name}  ·  ${o.id}', style: Fonts.body(14, w: FontWeight.w700))),
                  SoftPill(icon: Icons.link_rounded, label: tr('Link', 'जोड़ें'), onTap: () => s.linkParent(o.id, parentId)),
                ]),
              ),
            ],
          ])),
          HubSection(tr('This device', 'यह डिवाइस')),
          ToyCard(child: Column(children: [
            InfoRow(icon: Icons.people_alt_rounded, label: tr('Your children', 'आपके बच्चे'), value: '${mine.length}'),
            InfoRow(icon: Icons.school_rounded, label: tr('Learners on device', 'डिवाइस पर विद्यार्थी'), value: '${s.learners.length}'),
            InfoRow(icon: Icons.family_restroom_rounded, label: tr('Parent accounts', 'अभिभावक खाते'), value: '${s.parents.length}'),
          ])),
        ],
      ))),
    ));
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _Tile({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Rad.md),
        child: Padding(padding: const EdgeInsets.symmetric(vertical: 13), child: Row(children: [
          Icon(icon, size: 22, color: AppColors.primaryDark),
          const SizedBox(width: Sp.md),
          Expanded(child: Text(label, style: Fonts.body(15, w: FontWeight.w700))),
          Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ])),
      );
}
