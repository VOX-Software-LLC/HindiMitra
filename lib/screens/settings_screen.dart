import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../theme/palette.dart';
import '../theme/themes.dart';
import 'package:provider/provider.dart';
import '../l10n.dart';
import '../store/app_store.dart';
import '../widgets/common.dart';
import '../widgets/hindi_name.dart';
import '../widgets/profile_sections.dart';
import '../widgets/toy_button.dart';

const _times = <(String, int, int)>[
  ('Morning (8 AM)', 8, 0), ('Afternoon (1 PM)', 13, 0), ('Evening (6 PM)', 18, 0), ('Night (8 PM)', 20, 0),
];

/// SettingsScreen.tsx (Delete Account is hidden: it is only shown when Firebase is configured)
class SettingsScreen extends StatefulWidget {
  final Map<String, dynamic> params;
  const SettingsScreen({super.key, this.params = const {}});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool reminders = false, streakAlerts = false;
  int selectedTime = 2;

  Future<void> _toggleReminders(bool v) async {
    if (v) {
      final granted = await requestNotificationPermissions();
      if (!granted) {
        if (mounted) showInfoDialog(context, 'Permissions Required', 'Please enable notifications in your device settings to receive practice reminders.');
        return;
      }
      final t = _times[selectedTime];
      await scheduleDailyReminder(t.$2, t.$3);
    } else {
      await cancelDailyReminder();
    }
    if (mounted) setState(() => reminders = v);
  }

  Future<void> _toggleStreak(bool v) async {
    if (v) {
      final granted = await requestNotificationPermissions();
      if (!granted) {
        if (mounted) showInfoDialog(context, 'Permissions Required', 'Please enable notifications in your device settings to receive streak alerts.');
        return;
      }
      await scheduleStreakWarning();
    } else {
      await cancelStreakWarning();
    }
    if (mounted) setState(() => streakAlerts = v);
  }

  Future<void> _timeChange(int i) async {
    setState(() => selectedTime = i);
    if (reminders) await scheduleDailyReminder(_times[i].$2, _times[i].$3);
  }

  Widget _switch(bool value, ValueChanged<bool> onChanged) => Switch(
        value: value, onChanged: kIsWeb ? null : onChanged,
        activeTrackColor: AppColors.primary, inactiveTrackColor: AppColors.border,
        thumbColor: WidgetStatePropertyAll(value ? AppColors.surface : const Color(0xFFF4F3F4)),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      );

  Widget _card(Widget child) => Container(
        width: double.infinity, padding: const EdgeInsets.all(Sp.md),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(Rad.xl), border: Border.all(color: AppColors.border),
            boxShadow: toyShadow(AppColors.toyShadowColor, 4)),
        child: child,
      );

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.only(left: Sp.xs, top: Sp.lg, bottom: Sp.sm),
        child: Text(t, style: Fonts.display(20, color: AppColors.textPrimary, w: FontWeight.w800, height: 28 / 20)),
      );

  Widget _row(Color bg, IconData icon, Color ic, String label, String desc, bool v, ValueChanged<bool> cb) => Padding(
        padding: const EdgeInsets.symmetric(vertical: Sp.sm),
        child: Row(children: [
          Expanded(child: Row(children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(color: bg, shape: BoxShape.circle), child: Icon(icon, size: 20, color: ic)),
            const SizedBox(width: Sp.md),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: Fonts.body(15, w: FontWeight.w700, color: AppColors.textPrimary, height: 20 / 15)),
              Text(desc, style: Fonts.body(12, color: AppColors.textSecondary)),
            ])),
          ])),
          _switch(v, cb),
        ]),
      );

  Widget _divider() => Container(height: 1, margin: const EdgeInsets.symmetric(vertical: Sp.sm), color: AppColors.border);

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: Colors.transparent, body: SafeArea(bottom: false, child: Column(children: [
      HeaderBar(title: 'Settings', subtitle: 'सेटिंग्स', onBack: () => Navigator.of(context).maybePop()),
      Expanded(child: screenScroll(padding: const EdgeInsets.all(Sp.md), maxWidth: 720, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _section(tr('Appearance', 'रूप-रंग')),
        _card(const _ThemePicker()),
        _section(tr('Language', 'भाषा')),
        _card(const _LanguagePicker()),
        _section(tr('Your name', 'आपका नाम')),
        _card(const _NameSettings()),
        _section(tr('Learning', 'सीखना')),
        const ProfileSettings(),
        _section(tr('Notifications', 'सूचनाएँ')),
        _card(Column(children: [
          if (kIsWeb) Container(
            margin: const EdgeInsets.only(bottom: Sp.sm), padding: const EdgeInsets.all(Sp.sm),
            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(Rad.lg), border: Border.all(color: AppColors.border)),
            child: Row(children: [
              Icon(Icons.info_outline, size: 16, color: AppColors.textMuted), const SizedBox(width: Sp.xs),
              Expanded(child: Text('Push notifications are available on mobile devices only.', style: Fonts.body(12, color: AppColors.textMuted))),
            ]),
          ),
          _row(AppColors.primary.withAlpha(0x22), Icons.notifications_none, AppColors.primaryDark, 'Daily Reminder', 'Get reminded to practice Hindi', reminders, _toggleReminders),
          if (reminders) Padding(
            padding: const EdgeInsets.only(left: 52, bottom: Sp.sm),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(padding: const EdgeInsets.only(bottom: Sp.xs), child: Text('Reminder time:', style: Fonts.body(12, color: AppColors.textMuted))),
              Wrap(spacing: Sp.xs, runSpacing: Sp.xs, children: [
                for (int i = 0; i < _times.length; i++) GestureDetector(
                  onTap: () => _timeChange(i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: 6),
                    decoration: BoxDecoration(
                      color: selectedTime == i ? AppColors.primary : AppColors.surface, borderRadius: BorderRadius.circular(9999),
                      border: Border.all(color: selectedTime == i ? AppColors.primary : AppColors.border),
                      boxShadow: selectedTime == i ? toyShadow(AppColors.toyShadowColor, 4) : null),
                    child: Text(_times[i].$1, style: Fonts.body(12, w: selectedTime == i ? FontWeight.w800 : FontWeight.w700,
                        color: selectedTime == i ? AppColors.textOnPrimary : AppColors.textSecondary, height: 16 / 12)),
                  ),
                ),
              ]),
            ]),
          ),
          _divider(),
          _row(const Color(0xFFFF7043).withAlpha(0x22), Icons.local_fire_department_outlined, const Color(0xFFFF7043), 'Streak Alerts', 'Warning when streak is in danger', streakAlerts, _toggleStreak),
        ])),
        _section(tr('About', 'जानकारी')),
        _card(Column(children: [
          _about(tr('App Version', 'संस्करण'), '1.0.0'), _divider(), _about(tr('Built with', 'बनाया गया'), 'Flutter'),
          _divider(), _about(tr('Made in', 'निर्माण'), 'India 🇮🇳'),
        ])),
        const SizedBox(height: Sp.xxl * 2),
      ]))),
    ])));
  }

  Widget _about(String l, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: Sp.sm),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(l, style: Fonts.body(16, color: AppColors.textPrimary)),
          Text(v, style: Fonts.body(16, color: AppColors.textSecondary)),
        ]),
      );
}

/// Grid of themes, each drawn as a small preview in its own colours.
class _ThemePicker extends StatelessWidget {
  const _ThemePicker();
  @override
  Widget build(BuildContext context) {
    final selected = context.select<AppStore, String>((s) => s.themeId);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(tr('Pick a look for the whole app — day, night, or a fun background!',
              'पूरे ऐप का रूप चुनें — दिन, रात या मज़ेदार बैकग्राउंड!'),
          style: Fonts.body(13, color: AppColors.textSecondary)),
      const SizedBox(height: Sp.md),
      LayoutBuilder(builder: (_, c) {
        final cols = c.maxWidth >= 560 ? 4 : c.maxWidth >= 380 ? 3 : 2;
        final w = (c.maxWidth - Sp.sm * (cols - 1)) / cols;
        return Wrap(spacing: Sp.sm, runSpacing: Sp.sm, children: [
          for (final t in AppThemes.all) SizedBox(width: w, child: _ThemeTile(t, selected: t.id == selected)),
        ]);
      }),
    ]);
  }
}

class _ThemeTile extends StatelessWidget {
  final AppThemeDef t; final bool selected;
  const _ThemeTile(this.t, {required this.selected});
  @override
  Widget build(BuildContext context) => Pressable(
        onTap: () => context.read<AppStore>().setThemeId(t.id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Rad.lg),
            border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: selected ? 3 : 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(height: 72, child: Stack(fit: StackFit.expand, children: [
              DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: t.backdrop))),
              CustomPaint(painter: ThemePatternPainter(t)),
              Positioned(left: 10, right: 10, bottom: 10, child: Container(
                height: 26, padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  Container(width: 14, height: 14, decoration: BoxDecoration(color: t.primary, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Expanded(child: Container(height: 5, decoration: BoxDecoration(
                      color: t.textSecondary.withOpacity(0.5), borderRadius: BorderRadius.circular(3)))),
                ]),
              )),
              Positioned(top: 6, left: 8, child: Text(t.emoji, style: const TextStyle(fontSize: 20))),
              if (selected) Positioned(top: 6, right: 6, child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                child: Icon(Icons.check_rounded, size: 14, color: AppColors.textOnPrimary))),
            ])),
            Container(
              color: AppColors.surface, padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Fonts.body(13, w: FontWeight.w800)),
                Text(t.hindiName, maxLines: 1, style: Fonts.hindi(12, color: AppColors.textSecondary)),
              ]),
            ),
          ]),
        ),
      );
}

/// App language: English and Hindi now, more languages marked "coming soon".
class _LanguagePicker extends StatelessWidget {
  const _LanguagePicker();
  @override
  Widget build(BuildContext context) {
    final lang = context.select<AppStore, String>((s) => s.appLanguage);
    Widget chip(String code, String native, String english, {bool soon = false}) {
      final on = code == lang;
      return Pressable(
        onTap: soon
            ? () => showInfoDialog(context, '$native · ${tr('coming soon', 'जल्द आ रही है')}',
                tr('$english is on the way. See the Upcoming tab for what is coming next.',
                    '$english जल्द आ रही है। आगे क्या आ रहा है, "जल्द" टैब में देखें।'))
            : () => context.read<AppStore>().setAppLanguage(code),
        child: Opacity(
          opacity: soon ? 0.6 : 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: on ? AppColors.primary : AppColors.background,
              borderRadius: BorderRadius.circular(9999),
              border: Border.all(color: on ? AppColors.primary : AppColors.border)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(native, style: Fonts.body(14, w: FontWeight.w800,
                  color: on ? AppColors.textOnPrimary : AppColors.textPrimary)),
              if (soon) ...[
                const SizedBox(width: 6),
                Text(tr('soon', 'जल्द'), style: Fonts.body(10, w: FontWeight.w800, color: AppColors.textSecondary)),
              ],
            ]),
          ),
        ),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(tr('App language', 'ऐप की भाषा'), style: Fonts.body(14, w: FontWeight.w800)),
      const SizedBox(height: Sp.sm),
      Wrap(spacing: Sp.sm, runSpacing: Sp.sm, children: [
        for (final (c, n, e) in AppLang.live) chip(c, n, e),
      ]),
      const SizedBox(height: Sp.md),
      Text(tr('Coming soon', 'जल्द आ रही हैं'), style: Fonts.body(14, w: FontWeight.w800)),
      const SizedBox(height: Sp.sm),
      Wrap(spacing: Sp.sm, runSpacing: Sp.sm, children: [
        for (final (c, n, e) in AppLang.upcoming) chip(c, n, e, soon: true),
      ]),
    ]);
  }
}

/// English name (editable) and its Hindi spelling (with the ⓘ correction).
class _NameSettings extends StatelessWidget {
  const _NameSettings();
  @override
  Widget build(BuildContext context) {
    final name = context.select<AppStore, String>((s) => s.userName);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr('Name', 'नाम'), style: Fonts.body(12, w: FontWeight.w700, color: AppColors.textSecondary)),
          Text(name, style: Fonts.display(20)),
        ])),
        PillButton(label: tr('Edit', 'बदलें'), icon: Icons.edit_outlined, onTap: () => _editName(context)),
      ]),
      Container(height: 1, margin: const EdgeInsets.symmetric(vertical: Sp.sm), color: AppColors.border),
      Text(tr('In Hindi', 'हिन्दी में'), style: Fonts.body(12, w: FontWeight.w700, color: AppColors.textSecondary)),
      Align(alignment: Alignment.centerLeft, child: HindiNameLine(color: AppColors.textPrimary, size: 22)),
      Text(tr('Tap ⓘ if the Hindi spelling looks wrong.', 'हिन्दी स्पेलिंग गलत लगे तो ⓘ दबाएँ।'),
          style: Fonts.body(12, color: AppColors.textSecondary)),
    ]);
  }

  Future<void> _editName(BuildContext context) async {
    final store = context.read<AppStore>();
    final ctrl = TextEditingController(text: store.userName);
    final saved = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(tr('Edit name', 'नाम बदलें'), style: Fonts.display(22)),
      content: TextField(controller: ctrl, autofocus: true, maxLength: 30, style: Fonts.body(16),
          decoration: InputDecoration(hintText: tr('Enter your name', 'अपना नाम लिखें'))),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(tr('Cancel', 'रद्द करें'))),
        ToyButton(label: tr('Save', 'सेव करें'), size: ToySize.sm, onPressed: () => Navigator.of(ctx).pop(true)),
      ],
    ));
    final t = ctrl.text.trim();
    if (saved == true && t.isNotEmpty) store.setUserName(t);
  }
}
