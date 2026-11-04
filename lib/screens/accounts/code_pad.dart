import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../data/accounts.dart';
import '../../l10n.dart';
import '../../store/app_store.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../../widgets/common.dart';
import '../../widgets/toy_button.dart';
import 'account_widgets.dart';
import 'pin_pad.dart';

/// A secret-code pad that looks like a phone keyboard: big slots at the top
/// (a dash in the middle of a 6-character code), then a keyboard with the
/// number row 1-0 and every letter in QWERTY order. A pressed key shows its
/// letter in a bubble above it, like a real keyboard. Typing on a computer
/// keyboard works too.
///
/// [onComplete] runs when the last character is in. It returns an error to
/// show (the slots shake red and clear) or null when the code is right; then
/// the slots turn green with a tick and, after a moment, [onAccepted] runs.
class CodePad extends StatefulWidget {
  final Future<String?> Function(String code) onComplete;
  final VoidCallback? onAccepted;
  final DateTime? lockedUntil;
  final String? message;
  /// Show what is typed (choosing a code) instead of dots (logging in). With
  /// dots, each character shows for a moment and an eye button reveals all.
  final bool visible;
  /// Characters in the code, and whether it is digits only (an old PIN).
  final int length;
  final bool digitsOnly;
  /// Kept for older callers: the keyboard now shows letters and numbers together.
  final bool autoNumbers;
  const CodePad({super.key, required this.onComplete, this.onAccepted, this.lockedUntil, this.message, this.visible = true,
      this.length = StudentCodes.length, this.digitsOnly = false, this.autoNumbers = false});
  @override
  State<CodePad> createState() => CodePadState();
}

class CodePadState extends State<CodePad> with SingleTickerProviderStateMixin {
  String code = '';
  String? error;
  bool busy = false, reveal = false, success = false;
  /// Index of the character shown briefly before it turns into a dot.
  int? _peek;
  Timer? _tick, _peekTimer;
  late final AnimationController _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));

  bool get locked => widget.lockedUntil != null && widget.lockedUntil!.isAfter(DateTime.now());

  @override
  void initState() { super.initState(); _syncTimer(); }

  @override
  void didUpdateWidget(CodePad oldWidget) { super.didUpdateWidget(oldWidget); _syncTimer(); }

  // Redraws each second while locked, so the countdown moves and the pad unlocks.
  void _syncTimer() {
    _tick?.cancel();
    if (!locked) return;
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      if (!locked) { _tick?.cancel(); error = null; }
    });
  }

  @override
  void dispose() { _tick?.cancel(); _peekTimer?.cancel(); _shake.dispose(); super.dispose(); }

  /// Clears the slots (e.g. when a flow moves to its next step).
  void reset([String? message]) => setState(() { code = ''; error = message; _peek = null; success = false; });

  bool _allowed(String c) => widget.digitsOnly
      ? StudentCodes.digits.contains(c)
      : StudentCodes.letters.contains(c) || StudentCodes.digits.contains(c);

  Future<void> _add(String c) async {
    if (busy || locked || success || code.length >= widget.length || !_allowed(c)) return;
    HapticFeedback.selectionClick();
    setState(() { code += c; error = null; _peek = code.length - 1; });
    _peekTimer?.cancel();
    _peekTimer = Timer(const Duration(milliseconds: 700), () { if (mounted) setState(() => _peek = null); });
    if (code.length < widget.length) return;
    setState(() => busy = true);
    // Decided now: a flow that moves to its next step inside onComplete
    // (e.g. "enter it again") must not celebrate the first entry.
    final accepted = widget.onAccepted;
    await Future.delayed(const Duration(milliseconds: 180));
    final err = await widget.onComplete(code);
    if (!mounted) return;
    setState(() => busy = false);
    if (err != null) {
      HapticFeedback.heavyImpact();
      _shake.forward(from: 0);
      setState(() { error = err; code = ''; _peek = null; });
      return;
    }
    if (accepted == null) return;
    HapticFeedback.mediumImpact();
    setState(() => success = true);
    await Future.delayed(const Duration(milliseconds: 650));
    if (mounted) accepted();
  }

  void _back() {
    if (busy || locked || success || code.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() { code = code.substring(0, code.length - 1); _peek = null; });
  }

  void _clear() {
    if (busy || locked || success || code.isEmpty) return;
    HapticFeedback.mediumImpact();
    setState(() { code = ''; _peek = null; });
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final ch = e.character?.toUpperCase();
    if (ch != null && ch.length == 1 && _allowed(ch)) { _add(ch); return KeyEventResult.handled; }
    if (e.logicalKey == LogicalKeyboardKey.backspace) { _back(); return KeyEventResult.handled; }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final width = math.min(MediaQuery.sizeOf(context).width - Sp.md * 2, 460.0);
    return Focus(
      autofocus: true, onKeyEvent: _onKey,
      child: SizedBox(width: width, child: Column(mainAxisSize: MainAxisSize.min, children: [
        _slots(width),
        const SizedBox(height: Sp.sm),
        SizedBox(height: 40, child: Center(child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (c, a) => ScaleTransition(scale: a, child: FadeTransition(opacity: a, child: c)),
          child: success ? _note(tr('Welcome!', 'स्वागत है!'), AppColors.success, Icons.check_circle_rounded)
              : locked ? const SizedBox.shrink(key: ValueKey('none'))
              : error != null ? _note(error!, AppColors.error, Icons.error_outline_rounded)
              : widget.message != null ? _note(widget.message!, AppColors.textSecondary, Icons.info_outline_rounded)
              : _progressDots(),
        ))),
        const SizedBox(height: Sp.sm),
        _keyboard(width),
      ])),
    );
  }

  Widget _note(String text, Color c, IconData icon) => Container(
        key: ValueKey(text),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(9999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: c),
          const SizedBox(width: 6),
          Flexible(child: Text(text, textAlign: TextAlign.center, maxLines: 2,
              style: Fonts.body(13, w: FontWeight.w800, color: c))),
        ]),
      );

  // "3 of 6" as small dots that fill in: a quiet hint while typing.
  Widget _progressDots() => Row(key: const ValueKey('progress'), mainAxisSize: MainAxisSize.min, children: [
        for (int i = 0; i < widget.length; i++) AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: i < code.length ? 18 : 6, height: 6,
          decoration: BoxDecoration(color: i < code.length ? AppColors.primary : AppColors.border,
              borderRadius: BorderRadius.circular(3)),
        ),
      ]);

  // ── Slots ─────────────────────────────────────────────────────────────

  Widget _slots(double width) {
    final n = widget.length;
    final dash = n == 6;
    final eye = !widget.visible;
    final spare = (dash ? 22 : 0) + (eye ? 44 : 0);
    final w = ((width - spare) / n - 8).clamp(30.0, 56.0);
    final shown = widget.visible || reveal;
    final isError = error != null;
    final tone = success ? AppColors.success : isError ? AppColors.error : AppColors.primary;

    Widget slot(int i) {
      final filled = i < code.length;
      final current = i == code.length && !locked && !busy && !success;
      final ch = filled ? code[i] : '';
      final showChar = filled && (shown || i == _peek);
      return AnimatedContainer(
        duration: Duration(milliseconds: success ? 120 + i * 60 : 180), curve: Curves.easeOut,
        width: w, height: w * 1.2,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: success ? AppColors.success.withOpacity(0.14)
              : isError ? AppColors.error.withOpacity(0.06) : filled ? AppColors.primary.withOpacity(0.08) : AppColors.surface,
          borderRadius: BorderRadius.circular(w * 0.3),
          border: Border.all(
              width: current || success ? 2.5 : 1.5,
              color: success || isError ? tone : current ? AppColors.primary : filled ? AppColors.primaryLight : AppColors.border),
          boxShadow: current
              ? [BoxShadow(color: AppColors.primary.withOpacity(0.25), blurRadius: 14, spreadRadius: 1)]
              : toyShadow(AppColors.toyShadowColor, 2)),
        child: !filled
            ? (current ? _Caret(height: w * 0.5) : null)
            : TweenAnimationBuilder<double>(
                key: ValueKey('$i$ch${showChar ? 'c' : 'd'}$success'),
                tween: Tween(begin: 0.5, end: 1), duration: const Duration(milliseconds: 260), curve: Curves.easeOutBack,
                builder: (_, s, child) => Transform.scale(scale: s, child: child),
                child: success && !shown
                    ? Icon(Icons.check_rounded, size: w * 0.55, color: AppColors.successDark)
                    : showChar
                        ? Text(ch, style: Fonts.display(w * 0.55, color: success ? AppColors.successDark : AppColors.primaryDark, height: 1))
                        : Container(width: w * 0.28, height: w * 0.28,
                            decoration: BoxDecoration(color: AppColors.primaryDark, shape: BoxShape.circle)),
              ),
      );
    }

    return AnimatedBuilder(
      animation: _shake,
      builder: (_, child) => Transform.translate(
          offset: Offset(math.sin(_shake.value * math.pi * 6) * 12 * (1 - _shake.value), 0), child: child),
      child: Semantics(
        label: tr('${code.length} of $n characters typed', '$n में से ${code.length} अक्षर'),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (int i = 0; i < (dash ? 3 : n); i++) slot(i),
          if (dash) ...[
            Container(width: 10, height: 3, margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
            for (int i = 3; i < 6; i++) slot(i),
          ],
          if (eye) SizedBox(width: 40, child: IconButton(
            tooltip: reveal ? tr('Hide', 'छुपाएँ') : tr('Show', 'दिखाएँ'),
            onPressed: () => setState(() => reveal = !reveal),
            icon: Icon(reveal ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20, color: AppColors.textSecondary),
          )),
        ]),
      ),
    );
  }

  // ── Keyboard ──────────────────────────────────────────────────────────

  static const _rows = ['QWERTYUIOP', 'ASDFGHJKL', 'ZXCVBNM'];

  Widget _keyboard(double width) {
    const gap = 6.0, pad = 8.0;
    // Panel padding and 1px border, less a hair for rounding: 10 keys fill a row.
    final inner = width - pad * 2 - 2 - 0.5;
    final left = locked ? widget.lockedUntil!.difference(DateTime.now()).inSeconds + 1 : 0;

    Widget row(List<Widget> keys) => Padding(
          padding: const EdgeInsets.only(bottom: gap),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (int i = 0; i < keys.length; i++) ...[if (i > 0) const SizedBox(width: gap), keys[i]],
          ]),
        );

    final List<Widget> rows;
    if (widget.digitsOnly) {
      // An old 4-digit PIN: a phone dial pad.
      final kw = ((inner - gap * 2) / 3).floorToDouble();
      Widget k(String c) => _Key(label: c, width: kw, height: 56, big: true, onTap: () => _add(c));
      rows = [
        row([k('1'), k('2'), k('3')]), row([k('4'), k('5'), k('6')]), row([k('7'), k('8'), k('9')]),
        row([_Key(label: tr('Clear', 'साफ़'), width: kw, height: 56, special: true, onTap: _clear), k('0'),
            _Key(icon: Icons.backspace_rounded, width: kw, height: 56, special: true, onTap: _back, onLongPress: _clear)]),
      ];
    } else {
      final kw = ((inner - gap * 9) / 10).floorToDouble();
      Widget k(String c, {bool digit = false}) =>
          _Key(label: c, width: kw, height: digit ? 42 : 48, digit: digit, onTap: () => _add(c));
      rows = [
        row([for (final c in '1234567890'.split('')) k(c, digit: true)]),
        row([for (final c in _rows[0].split('')) k(c)]),
        row([for (final c in _rows[1].split('')) k(c)]),
        row([
          _Key(label: tr('Clear', 'साफ़'), width: kw * 1.5 + gap / 2, height: 48, special: true, onTap: _clear),
          for (final c in _rows[2].split('')) k(c),
          _Key(icon: Icons.backspace_rounded, width: kw * 1.5 + gap / 2, height: 48, special: true, onTap: _back, onLongPress: _clear),
        ]),
      ];
    }

    return Container(
      width: width,
      padding: const EdgeInsets.fromLTRB(pad, pad + 2, pad, pad - gap + 4),
      decoration: BoxDecoration(
        color: AppColors.muted.withOpacity(0.75),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Stack(clipBehavior: Clip.none, children: [
        IgnorePointer(
          ignoring: locked || success,
          child: AnimatedOpacity(duration: const Duration(milliseconds: 200), opacity: locked ? 0.25 : 1,
              child: Column(mainAxisSize: MainAxisSize.min, children: rows)),
        ),
        if (locked) Positioned.fill(child: Center(child: Container(
          padding: const EdgeInsets.symmetric(horizontal: Sp.lg, vertical: Sp.md),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(Rad.xl),
              boxShadow: softShadow(AppColors.error)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.lock_clock_rounded, color: AppColors.error, size: 30),
            const SizedBox(height: 6),
            Text(tr('Too many wrong tries', 'बहुत बार गलत'), style: Fonts.display(17)),
            Text(tr('Try again in ${left < 60 ? '${left}s' : '${left ~/ 60}:${(left % 60).toString().padLeft(2, '0')}'}',
                    '${left < 60 ? '$left सेकंड' : '${left ~/ 60}:${(left % 60).toString().padLeft(2, '0')}'} बाद फिर कोशिश करें'),
                style: Fonts.body(14, w: FontWeight.w800, color: AppColors.error)),
          ]),
        ))),
      ]),
    );
  }
}

/// One keyboard key. While pressed it darkens, sinks a little and (for a
/// letter or number) shows the character in a bubble above it.
class _Key extends StatefulWidget {
  final String? label;
  final IconData? icon;
  final double width, height;
  final bool digit, special, big;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  const _Key({this.label, this.icon, required this.width, required this.height, this.digit = false, this.special = false,
      this.big = false, required this.onTap, this.onLongPress});
  @override
  State<_Key> createState() => _KeyState();
}

class _KeyState extends State<_Key> {
  bool down = false;
  void _set(bool v) { if (v != down) setState(() => down = v); }

  @override
  Widget build(BuildContext context) {
    final bubble = down && widget.label != null && !widget.special && !widget.big;
    final fg = widget.special ? AppColors.textSecondary : widget.digit ? shade(AppColors.secondary, 0.1) : AppColors.textPrimary;
    final key = AnimatedContainer(
      duration: const Duration(milliseconds: 90),
      width: widget.width, height: widget.height,
      transform: Matrix4.translationValues(0, down ? 2 : 0, 0),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: down ? AppColors.primary.withOpacity(0.18) : widget.special ? AppColors.surface.withOpacity(0.55) : AppColors.surface,
        borderRadius: BorderRadius.circular(widget.big ? 18 : 9),
        boxShadow: down ? null : [BoxShadow(color: AppColors.toyShadowColor.withOpacity(0.35), offset: const Offset(0, 2))],
      ),
      child: widget.icon != null
          ? Icon(widget.icon, size: 20, color: fg)
          : FittedBox(fit: BoxFit.scaleDown, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: Text(widget.label!,
              style: widget.special ? Fonts.body(13, w: FontWeight.w800, color: fg)
                  : Fonts.display(widget.big ? 26 : widget.height * 0.42, color: fg, height: 1)))),
    );
    return Semantics(
      button: true, label: widget.label ?? tr('Delete', 'मिटाएँ'),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _set(true),
          onTapUp: (_) => _set(false),
          onTapCancel: () => _set(false),
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          child: Stack(clipBehavior: Clip.none, alignment: Alignment.bottomCenter, children: [
            key,
            // The pressed character, larger, above the finger (like a phone keyboard).
            if (bubble) Positioned(
              bottom: widget.height + 4,
              child: IgnorePointer(child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.6, end: 1), duration: const Duration(milliseconds: 120), curve: Curves.easeOutBack,
                builder: (_, s, child) => Transform.scale(scale: s, alignment: Alignment.bottomCenter, child: child),
                child: Container(
                  width: widget.width * 1.5, height: widget.height * 1.15, alignment: Alignment.center,
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withOpacity(0.5), width: 1.5),
                      boxShadow: softShadow(AppColors.primary)),
                  child: Text(widget.label!, style: Fonts.display(widget.height * 0.62, color: AppColors.primaryDark, height: 1)),
                ),
              )),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Blinking text caret in the slot that takes the next character.
class _Caret extends StatefulWidget {
  final double height;
  const _Caret({required this.height});
  @override
  State<_Caret> createState() => _CaretState();
}

class _CaretState extends State<_Caret> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat();
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _c.drive(TweenSequence([
          TweenSequenceItem(tween: ConstantTween(1.0), weight: 1),
          TweenSequenceItem(tween: ConstantTween(0.0), weight: 1),
        ])),
        child: Container(width: 2.5, height: widget.height,
            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2))),
      );
}

/// Asks learner [studentId] for their code. True when it is right. A
/// learner who chose "Remember me on this phone" goes straight in.
Future<bool> verifyStudentCode(BuildContext context, String studentId) async {
  final s = context.read<AppStore>();
  if (s.isRemembered(studentId)) {
    s.markLastUser(studentId);
    return true;
  }
  final ok = await Navigator.of(context, rootNavigator: true).push<bool>(MaterialPageRoute(
      builder: (_) => _VerifyCode(studentId: studentId), settings: const RouteSettings(name: 'StudentCode')));
  if (ok == true) s.markLastUser(studentId);
  return ok ?? false;
}

class _VerifyCode extends StatefulWidget {
  final String studentId;
  const _VerifyCode({required this.studentId});
  @override
  State<_VerifyCode> createState() => _VerifyCodeState();
}

class _VerifyCodeState extends State<_VerifyCode> {
  bool remember = false;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    final st = s.studentById(widget.studentId);
    if (st == null) return const SizedBox.shrink();
    return PinScreen(
      title: tr('Hi ${st.name}!', 'नमस्ते ${st.name}!'),
      subtitle: tr('Type your secret code', 'अपना गुप्त कोड लिखो'),
      avatar: learnerAvatar(st.name, st.avatar, size: 76, ring: AppColors.primary),
      pad: CodePad(
        visible: true,
        lockedUntil: s.pinLockedUntil(widget.studentId),
        onComplete: (code) async => switch (s.checkStudentCode(widget.studentId, code)) {
          PinCheck.ok => null,
          PinCheck.locked => tr('Too many wrong tries.', 'बहुत बार गलत।'),
          PinCheck.wrong => tr('Not quite! Try again.', 'सही नहीं! फिर कोशिश करो।'),
        },
        onAccepted: () {
          s.setRemembered(widget.studentId, remember);
          Navigator.of(context).pop(true);
        },
      ),
      footer: Column(mainAxisSize: MainAxisSize.min, children: [
        RememberSwitch(
          value: remember, onChanged: (v) => setState(() => remember = v),
          label: tr('Remember me on this phone', 'इस फ़ोन पर मुझे याद रखो'),
          hint: tr('Next time, tap your picture and go straight in.', 'अगली बार अपनी फ़ोटो दबाओ और सीधे अंदर जाओ।'),
        ),
        TextButton(
          onPressed: () => showInfoDialog(context, tr('Forgot your code?', 'कोड भूल गए?'),
              tr('Ask your mum, dad or teacher. They can see your code in the Parent Hub, under Children.',
                  'अपने मम्मी, पापा या टीचर से पूछो। वे इसे अभिभावक केंद्र में बच्चे के नीचे देख सकते हैं।')),
          child: Text(tr('Forgot your code?', 'कोड भूल गए?'), style: Fonts.body(14, w: FontWeight.w800, color: AppColors.primaryDark)),
        ),
      ]),
    );
  }
}

/// A friendly on/off row under a code pad ("Remember me on this phone").
class RememberSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;
  final String? hint;
  const RememberSwitch({super.key, required this.value, required this.onChanged, required this.label, this.hint});
  @override
  Widget build(BuildContext context) => Pressable(
        onTap: () { HapticFeedback.selectionClick(); onChanged(!value); },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(top: Sp.sm),
          padding: const EdgeInsets.fromLTRB(Sp.md, 8, 8, 8),
          decoration: BoxDecoration(
            color: value ? AppColors.success.withOpacity(0.1) : AppColors.surface,
            borderRadius: BorderRadius.circular(Rad.lg),
            border: Border.all(color: value ? AppColors.success.withOpacity(0.5) : AppColors.border)),
          child: Row(children: [
            Icon(value ? Icons.lock_open_rounded : Icons.lock_outline_rounded, size: 20,
                color: value ? AppColors.successDark : AppColors.textSecondary),
            const SizedBox(width: Sp.sm),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: Fonts.body(14, w: FontWeight.w800)),
              if (hint != null) Text(hint!, style: Fonts.body(11.5, w: FontWeight.w600, color: AppColors.textSecondary)),
            ])),
            Switch(value: value, onChanged: onChanged, activeColor: AppColors.success),
          ]),
        ),
      );
}

/// Shows a learner their code in big, friendly letters (after it is made).
Future<void> showStudentCode(BuildContext context, StudentAccount st, {String? title}) => showDialog(
      context: context, useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rad.xl)),
        title: Text(title ?? tr('${st.name}’s secret code', '${st.name} का गुप्त कोड'), textAlign: TextAlign.center, style: Fonts.display(21)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          learnerAvatar(st.name, st.avatar, size: 60),
          const SizedBox(height: Sp.md),
          StudentCodeChip(code: st.loginCode, big: true),
          const SizedBox(height: Sp.md),
          Text(tr('Use it to open your profile. Keep it secret from your brothers and sisters!',
                  'इससे अपनी प्रोफ़ाइल खोलो। इसे भाई-बहनों से छुपाकर रखो!'),
              textAlign: TextAlign.center, style: Fonts.body(14, color: AppColors.textSecondary)),
        ]),
        actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(),
            child: Text(tr('Got it!', 'समझ गया!'), style: Fonts.body(15, w: FontWeight.w800, color: AppColors.primary)))],
      ),
    );

/// A code as `KAT-482` in a tinted pill; tap to copy.
class StudentCodeChip extends StatelessWidget {
  final String code;
  final bool big, hidden;
  const StudentCodeChip({super.key, required this.code, this.big = false, this.hidden = false});
  @override
  Widget build(BuildContext context) => Pressable(
        onTap: hidden ? null : () {
          Clipboard.setData(ClipboardData(text: StudentCodes.format(code)));
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(tr('Code copied', 'कोड कॉपी हुआ'))));
        },
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: big ? 20 : 10, vertical: big ? 10 : 4),
          decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(big ? Rad.lg : 9999),
              border: Border.all(color: AppColors.primary.withOpacity(0.3), width: big ? 2 : 1)),
          child: Text(hidden ? '•••-•••' : StudentCodes.format(code),
              style: Fonts.display(big ? 32 : 15, color: AppColors.primaryDark, height: 1.1).copyWith(letterSpacing: big ? 4 : 1.5)),
        ),
      );
}
