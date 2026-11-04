import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_session.dart';
import '../data/accounts.dart';
import '../l10n.dart';
import '../routes.dart';
import '../store/app_store.dart';
import '../theme/app_theme.dart';
import '../theme/palette.dart';
import '../widgets/common.dart';
import '../widgets/toy_button.dart';
import 'accounts/account_widgets.dart';
import 'accounts/code_pad.dart';
import 'accounts/pin_pad.dart';

/// First screen on every launch: "Who's using HindiMitra?". A learner taps
/// their avatar to open their app; a parent enters their PIN to open the
/// Parent Hub (or sets up a parent account the first time).
class PersonaScreen extends StatelessWidget {
  const PersonaScreen({super.key});

  Future<void> _openParent(BuildContext context, [ParentAccount? who]) async {
    final s = context.read<AppStore>();
    final ParentAccount? p;
    if (who != null) {
      p = await verifyParentPin(context, who) ? who : null;
    } else {
      p = await requireParent(context);
    }
    if (p != null && context.mounted && s.parentById(p.id) != null) {
      openScreen(context, 'ParentHub', {'parentId': p.id});
    }
  }

  Future<void> _newLearner(BuildContext context) async {
    final st = await showAddLearnerDialog(context);
    if (st == null || !context.mounted) return;
    await showStudentCode(context, context.read<AppStore>().studentById(st.id) ?? st);
    if (context.mounted) AppSession.enterLearner(context, st.id);
  }

  Future<void> _openLearner(BuildContext context, String id) async {
    if (await verifyStudentCode(context, id) && context.mounted) AppSession.enterLearner(context, id);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    // Whoever used the app last comes first.
    int lastFirst(String a, String b) => (b == s.lastUserId ? 1 : 0) - (a == s.lastUserId ? 1 : 0);
    final learners = s.learners.where((k) => s.recordOf(k.id).onboarded).toList()..sort((a, b) => lastFirst(a.id, b.id));
    final parents = s.parents.where((p) => !p.contactOnly).toList()..sort((a, b) => lastFirst(a.id, b.id));
    final wide = MediaQuery.of(context).size.width >= 720;

    final student = _PersonaCard(
      tone: AppColors.primary, emoji: '🧒', title: tr("I'm a Student", 'मैं विद्यार्थी हूँ'), hindi: 'विद्यार्थी',
      blurb: tr('Learn letters, play games and earn stars', 'अक्षर सीखो, खेलो और सितारे जीतो'),
      badge: (Icons.key_rounded, tr('Your secret code', 'तुम्हारा गुप्त कोड')),
      child: learners.isEmpty
          ? ToyButton(label: tr('Start learning', 'सीखना शुरू करें'), fullWidth: true, variant: ToyVariant.outline,
              onPressed: () => AppSession.enterLearner(context, s.activeStudentId),
              trailing: Icon(Icons.arrow_forward_rounded, size: 18, color: AppColors.primary))
          : Wrap(spacing: Sp.md, runSpacing: Sp.md, alignment: WrapAlignment.center, children: [
              for (final k in learners) _AvatarButton(
                name: k.name, avatar: k.avatar, ring: Colors.white,
                note: tr('${s.recordOf(k.id).totalStars} ⭐', '${s.recordOf(k.id).totalStars} ⭐'),
                onTap: () => _openLearner(context, k.id), locked: !s.isRemembered(k.id), last: k.id == s.lastUserId,
              ),
              _AvatarButton(name: tr('New', 'नया'), icon: Icons.add_rounded, ring: Colors.white, onTap: () => _newLearner(context)),
            ]),
    );

    final parent = _PersonaCard(
      tone: AppColors.success, emoji: '👨‍👩‍👧', title: tr("I'm a Parent", 'मैं अभिभावक हूँ'), hindi: 'अभिभावक',
      blurb: tr('See progress, set homework and challenges', 'प्रगति देखें, होमवर्क और चुनौतियाँ दें'),
      badge: (Icons.lock_rounded, tr('PIN protected', 'पिन से सुरक्षित')),
      child: parents.isEmpty
          ? ToyButton(label: tr('Set up parent account', 'अभिभावक खाता बनाएँ'), fullWidth: true, variant: ToyVariant.outline,
              onPressed: () => _openParent(context),
              trailing: Icon(Icons.arrow_forward_rounded, size: 18, color: AppColors.primary))
          : Wrap(spacing: Sp.md, runSpacing: Sp.md, alignment: WrapAlignment.center, children: [
              for (final p in parents) _AvatarButton(
                name: p.name.split(' ').first, avatar: '', ring: Colors.white, locked: true,
                note: p.relationship, onTap: () => _openParent(context, p), last: p.id == s.lastUserId,
                unlockedFor: s.parentStillUnlocked(p.id),
              ),
              _AvatarButton(name: tr('Add', 'जोड़ें'), icon: Icons.person_add_alt_1_rounded, ring: Colors.white,
                  onTap: () async {
                    final p = await addAnotherParent(context);
                    if (p != null && context.mounted) openScreen(context, 'ParentHub', {'parentId': p.id});
                  }),
            ]),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Sp.md, Sp.lg, Sp.md, Sp.xl),
        child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 900), child: Column(children: [
          PopIn(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(width: 48, height: 48, alignment: Alignment.center,
                decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(16),
                    boxShadow: toyShadow(AppColors.primaryDark, 3)),
                child: const Text('🦜', style: TextStyle(fontSize: 26))),
            const SizedBox(width: Sp.sm + 2),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('HindiMitra', style: Fonts.display(26, height: 1.05)),
              Text('हिन्दी मित्र', style: Fonts.hindi(15, color: AppColors.textSecondary, height: 1.2)),
            ]),
          ])),
          const SizedBox(height: Sp.lg),
          Text(tr("Who's using HindiMitra?", 'आज कौन इस्तेमाल कर रहा है?'), textAlign: TextAlign.center, style: Fonts.display(28, height: 1.15)),
          const SizedBox(height: 4),
          Text(tr('Choose to continue', 'आगे बढ़ने के लिए चुनें'), style: Fonts.body(15, w: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: Sp.lg),
          if (wide)
            IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(child: PopIn(delayMs: 80, child: student)),
              const SizedBox(width: Sp.md),
              Expanded(child: PopIn(delayMs: 160, child: parent)),
            ]))
          else ...[
            PopIn(delayMs: 80, child: student),
            const SizedBox(height: Sp.md),
            PopIn(delayMs: 160, child: parent),
          ],
          const SizedBox(height: Sp.lg),
          TextButton.icon(
            onPressed: () => openScreen(context, 'PairDevice'),
            icon: Icon(Icons.link_rounded, color: AppColors.primaryDark),
            label: Text(tr('Join with a code from a parent', 'अभिभावक के कोड से जुड़ें'),
                style: Fonts.body(14, w: FontWeight.w800, color: AppColors.primaryDark)),
          ),
        ]))),
      )),
    );
  }
}

class _PersonaCard extends StatelessWidget {
  final Color tone;
  final String emoji, title, hindi, blurb;
  final (IconData, String) badge;
  final Widget child;
  const _PersonaCard({required this.tone, required this.emoji, required this.title, required this.hindi,
      required this.blurb, required this.badge, required this.child});
  @override
  Widget build(BuildContext context) => Container(
        clipBehavior: Clip.antiAlias,
        padding: const EdgeInsets.all(Sp.lg),
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color.lerp(tone, Colors.white, 0.16)!, tone, shade(tone, 0.08)]),
          borderRadius: BorderRadius.circular(Rad.xl2), boxShadow: softShadow(tone)),
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned(right: -14, top: -22, child: Opacity(opacity: 0.18, child: Text(emoji, style: const TextStyle(fontSize: 92)))),
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.24), borderRadius: BorderRadius.circular(9999)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(badge.$1, size: 14, color: Colors.white),
                  const SizedBox(width: 5),
                  Text(badge.$2, style: Fonts.body(12, w: FontWeight.w800, color: Colors.white)),
                ]),
              ),
            ]),
            const SizedBox(height: Sp.sm),
            Text(title, style: Fonts.display(26, color: Colors.white, height: 1.1)),
            Text(hindi, style: Fonts.hindi(16, color: Colors.white.withOpacity(0.92), height: 1.3)),
            const SizedBox(height: 4),
            Text(blurb, style: Fonts.body(14, w: FontWeight.w600, color: Colors.white.withOpacity(0.94))),
            const SizedBox(height: Sp.lg),
            child,
          ]),
        ]),
      );
}

/// A round avatar with a name under it (a lock badge for a parent).
class _AvatarButton extends StatelessWidget {
  final String name;
  final String avatar;
  final String? note;
  final IconData? icon;
  final Color ring;
  /// [locked]: a code or PIN is asked; otherwise (remembered) an open lock shows.
  final bool locked, last, unlockedFor;
  final VoidCallback onTap;
  const _AvatarButton({required this.name, this.avatar = '', this.note, this.icon, required this.ring, this.locked = false,
      this.last = false, this.unlockedFor = false, required this.onTap});
  @override
  Widget build(BuildContext context) => Semantics(
        button: true, label: locked ? tr('$name, needs PIN', '$name, पिन चाहिए') : name,
        child: Pressable(
          onTap: onTap,
          child: SizedBox(width: 84, child: Column(children: [
            Stack(clipBehavior: Clip.none, children: [
              Container(
                width: 68, height: 68, alignment: Alignment.center,
                decoration: BoxDecoration(color: AppColors.surface, shape: BoxShape.circle,
                    border: Border.all(color: ring, width: 3), boxShadow: toyShadow(AppColors.toyShadowColor, 3)),
                child: icon != null ? Icon(icon, size: 30, color: AppColors.primaryDark)
                    : avatar.isNotEmpty ? Text(avatar, style: const TextStyle(fontSize: 32))
                    : Text(name.isEmpty ? '?' : name[0].toUpperCase(), style: Fonts.display(28, color: AppColors.primaryDark)),
              ),
              if (icon == null) Positioned(right: -2, bottom: -2, child: Container(width: 26, height: 26,
                  decoration: BoxDecoration(color: locked && !unlockedFor ? AppColors.surface : AppColors.success,
                      shape: BoxShape.circle, border: Border.all(color: AppColors.surface, width: 2)),
                  child: Icon(locked && !unlockedFor ? Icons.lock_rounded : Icons.lock_open_rounded, size: 13,
                      color: locked && !unlockedFor ? AppColors.primaryDark : Colors.white))),
              // A soft ring and a tag on whoever used the app last.
              if (last) Positioned(top: -8, left: 0, right: 0, child: Center(child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(9999),
                    boxShadow: toyShadow(AppColors.toyShadowColor, 2)),
                child: Text(tr('Last used', 'पिछली बार'), style: Fonts.body(9.5, w: FontWeight.w800, color: AppColors.primaryDark)),
              ))),
            ]),
            const SizedBox(height: 6),
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                style: Fonts.body(14, w: FontWeight.w800, color: Colors.white)),
            if (note != null) Text(note!, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: Fonts.body(11.5, w: FontWeight.w700, color: Colors.white.withOpacity(0.88))),
          ])),
        ),
      );
}
