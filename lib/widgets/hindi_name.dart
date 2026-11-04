import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n.dart';
import '../store/app_store.dart';
import '../theme/app_theme.dart';
import '../theme/palette.dart';
import '../util/transliterate.dart';
import 'toy_button.dart';

/// The user's name in Devanagari: their own correction if they made one,
/// otherwise the automatic spelling of their English name.
String hindiNameOf(AppStore s) => s.hindiName.isNotEmpty ? s.hindiName : toDevanagari(s.userName);

/// The Hindi name with a light ⓘ beside it; tapping opens [showHindiNameSheet]
/// so a wrong automatic spelling can be fixed.
class HindiNameLine extends StatelessWidget {
  final Color color; final double size;
  const HindiNameLine({super.key, required this.color, this.size = 18});
  @override
  Widget build(BuildContext context) {
    final name = context.select<AppStore, String>(hindiNameOf);
    if (name.isEmpty) return const SizedBox.shrink();
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => showHindiNameSheet(context),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Flexible(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: Fonts.hindi(size, color: color, height: 1.3))),
          const SizedBox(width: 6),
          Tooltip(
            message: tr('Wrong spelling? Tap to fix', 'स्पेलिंग गलत है? ठीक करें'),
            child: Icon(Icons.info_outline_rounded, size: size * 0.8, color: color.withOpacity(0.55)),
          ),
        ]),
      ),
    );
  }
}

Future<void> showHindiNameSheet(BuildContext context) {
  final store = context.read<AppStore>();
  final auto = toDevanagari(store.userName);
  final ctrl = TextEditingController(text: hindiNameOf(store));
  return showModalBottomSheet(
    context: context, useRootNavigator: true, isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Rad.xl2))),
    builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
      final current = ctrl.text.trim();
      final options = {auto, ...spellingVariants(auto), if (current.isNotEmpty) current}.toList();
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SafeArea(child: SingleChildScrollView(
          padding: const EdgeInsets.all(Sp.lg),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(tr('Your name in Hindi', 'हिन्दी में आपका नाम'), style: Fonts.display(22)),
            const SizedBox(height: 4),
            Text(tr('We spelled "${store.userName}" in Hindi automatically. Names can be written in more than one way — pick the right one or type it yourself.',
                    'हमने "${store.userName}" को अपने आप हिन्दी में लिखा है। नाम कई तरह से लिखे जा सकते हैं — सही चुनें या खुद लिखें।'),
                style: Fonts.body(13.5, color: AppColors.textSecondary, height: 1.4)),
            const SizedBox(height: Sp.md),
            Center(child: Text(current.isEmpty ? auto : current, style: Fonts.hindi(36, color: AppColors.primaryDark))),
            const SizedBox(height: Sp.md),
            Text(tr('Choose a spelling', 'स्पेलिंग चुनें'), style: Fonts.body(14, w: FontWeight.w800)),
            const SizedBox(height: Sp.sm),
            Wrap(spacing: Sp.sm, runSpacing: Sp.sm, children: [
              for (final o in options) Pressable(
                onTap: () => setSheet(() => ctrl.text = o),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: o == current ? AppColors.primary.withOpacity(0.14) : AppColors.background,
                    borderRadius: BorderRadius.circular(9999),
                    border: Border.all(color: o == current ? AppColors.primary : AppColors.border)),
                  child: Text(o, style: Fonts.hindi(18)),
                ),
              ),
            ]),
            const SizedBox(height: Sp.md),
            Text(tr('Or type it in Hindi', 'या हिन्दी में लिखें'), style: Fonts.body(14, w: FontWeight.w800)),
            const SizedBox(height: Sp.sm),
            TextField(
              controller: ctrl, maxLength: 30, onChanged: (_) => setSheet(() {}),
              style: Fonts.hindi(20),
              decoration: InputDecoration(
                counterText: '', filled: true, fillColor: AppColors.background,
                hintText: auto, hintStyle: Fonts.hindi(20, color: AppColors.textSecondary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.lg), borderSide: BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.lg), borderSide: BorderSide(color: AppColors.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.lg), borderSide: BorderSide(color: AppColors.primary, width: 2)),
              ),
            ),
            const SizedBox(height: Sp.lg),
            Row(children: [
              Expanded(child: ToyButton(label: tr('Use automatic', 'अपने आप'), variant: ToyVariant.outline, fullWidth: true,
                  onPressed: () { store.setHindiName(''); Navigator.of(ctx).pop(); })),
              const SizedBox(width: Sp.md),
              Expanded(child: ToyButton(label: tr('Save', 'सेव करें'), fullWidth: true, onPressed: () {
                final t = ctrl.text.trim();
                store.setHindiName(t == auto ? '' : t);
                Navigator.of(ctx).pop();
              })),
            ]),
          ]),
        )),
      );
    }),
  );
}
