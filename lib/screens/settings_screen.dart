import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../theme/palette.dart';
import '../widgets/common.dart';

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
    return Scaffold(backgroundColor: AppColors.background, body: SafeArea(bottom: false, child: Column(children: [
      HeaderBar(title: 'Settings', subtitle: 'सेटिंग्स', onBack: () => Navigator.of(context).maybePop()),
      Expanded(child: screenScroll(padding: const EdgeInsets.all(Sp.md), maxWidth: 720, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _section('Notifications'),
        _card(Column(children: [
          if (kIsWeb) Container(
            margin: const EdgeInsets.only(bottom: Sp.sm), padding: const EdgeInsets.all(Sp.sm),
            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(Rad.lg), border: Border.all(color: AppColors.border)),
            child: Row(children: [
              const Icon(Icons.info_outline, size: 16, color: AppColors.textMuted), const SizedBox(width: Sp.xs),
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
        _section('About'),
        _card(Column(children: [
          _about('App Version', '1.0.0'), _divider(), _about('Built with', 'Flutter'),
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
