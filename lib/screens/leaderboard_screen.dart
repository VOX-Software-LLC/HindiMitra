import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../store/app_store.dart';
import '../theme/app_theme.dart';
import '../theme/palette.dart';

class _Entry {
  final String id, name; final int stars, streak, level; final bool isMe;
  const _Entry(this.id, this.name, this.stars, this.streak, this.level, [this.isMe = false]);
}

const _mock = <_Entry>[
  _Entry('1', 'Priya', 156, 21, 8), _Entry('2', 'Rahul', 132, 15, 7), _Entry('3', 'Ananya', 118, 12, 6),
  _Entry('4', 'Vikram', 95, 9, 5), _Entry('5', 'Neha', 87, 7, 5), _Entry('6', 'Arjun', 72, 6, 4),
  _Entry('7', 'Kavita', 65, 5, 4), _Entry('8', 'Amit', 48, 3, 3), _Entry('9', 'Deepa', 34, 2, 2),
  _Entry('10', 'Suresh', 22, 1, 2),
];

/// LeaderboardScreen.tsx (mock data, as in the original)
class LeaderboardScreen extends StatefulWidget {
  final Map<String, dynamic> params;
  const LeaderboardScreen({super.key, this.params = const {}});
  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  String tab = 'stars';

  @override
  Widget build(BuildContext context) {
    final (userName, totalStars, currentStreak, userLevel) = context.select<AppStore, (String, int, int, int)>(
        (store) => (store.userName, store.totalStars, store.currentStreak, store.userLevel));
    final all = [..._mock, _Entry('me', userName, totalStars, currentStreak, userLevel, true)];
    // stable descending sort (JS Array.sort is stable)
    final idx = {for (int i = 0; i < all.length; i++) all[i].id: i};
    int Function(_Entry) key = tab == 'stars' ? (e) => e.stars : (e) => e.streak;
    final sorted = [...all]..sort((a, b) { final c = key(b).compareTo(key(a)); return c != 0 ? c : idx[a.id]!.compareTo(idx[b.id]!); });
    final rank = sorted.indexWhere((e) => e.isMe) + 1;
    final medals = [Palette.light.sunny, Palette.light.purple, Palette.light.pink];

    return Scaffold(backgroundColor: AppColors.background, body: SafeArea(bottom: false, child: Column(children: [
      Padding(padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.sm), child: Row(children: [
        SizedBox(width: 40, height: 40, child: IconButton(padding: EdgeInsets.zero,
            icon: const Icon(Icons.chevron_left, size: 24, color: AppColors.textPrimary), onPressed: () => Navigator.of(context).maybePop())),
        Expanded(child: Column(children: [
          Text('Leaderboard', style: Fonts.display(20, color: AppColors.textPrimary, w: FontWeight.w800)),
          Text('लीडरबोर्ड', style: Fonts.hindi(12, color: AppColors.textSecondary)),
        ])),
        const SizedBox(width: 40),
      ])),
      Expanded(child: SingleChildScrollView(padding: const EdgeInsets.symmetric(horizontal: Sp.md), child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            margin: const EdgeInsets.fromLTRB(Sp.lg, 0, Sp.lg, Sp.md), padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(9999), border: Border.all(color: AppColors.border)),
            child: Row(children: [
              Expanded(child: _tab('stars', Icons.star, 'Stars')), const SizedBox(width: 4),
              Expanded(child: _tab('streak', Icons.local_fire_department, 'Streak')),
            ]),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(Sp.md, 0, Sp.md, Sp.md), padding: const EdgeInsets.all(Sp.lg),
            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(Rad.xl2), boxShadow: softShadow(AppColors.primary)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Opacity(opacity: 0.9, child: Text('Your Rank', style: Fonts.body(12, w: FontWeight.w700, color: AppColors.textOnPrimary))),
              const SizedBox(height: Sp.xs),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('#$rank', style: Fonts.display(34, color: AppColors.textOnPrimary, w: FontWeight.w800)),
                Row(children: [
                  const Icon(Icons.star, size: 14, color: AppColors.starGold), const SizedBox(width: 4),
                  Text('$totalStars', style: Fonts.body(14, w: FontWeight.w700, color: AppColors.textOnPrimary)),
                  const SizedBox(width: Sp.md),
                  const Icon(Icons.local_fire_department, size: 14, color: Color(0xFFFF7043)), const SizedBox(width: 4),
                  Text('$currentStreak days', style: Fonts.body(14, w: FontWeight.w700, color: AppColors.textOnPrimary)),
                ]),
              ]),
            ]),
          ),
          for (int i = 0; i < sorted.length; i++) _row(sorted[i], i, medals),
          const SizedBox(height: Sp.xxl),
        ]),
      )))),
    ])));
  }

  Widget _tab(String id, IconData icon, String label) {
    final active = tab == id;
    return GestureDetector(
      onTap: () => setState(() => tab = id),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: Sp.sm),
        decoration: BoxDecoration(color: active ? AppColors.primary : Colors.transparent, borderRadius: BorderRadius.circular(9999),
            boxShadow: active ? toyShadow(AppColors.toyShadowColor, 4) : null),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 16, color: active ? AppColors.textOnPrimary : AppColors.textMuted), const SizedBox(width: Sp.xs),
          Text(label, style: Fonts.body(14, w: active ? FontWeight.w800 : FontWeight.w500, color: active ? AppColors.textOnPrimary : AppColors.textSecondary)),
        ]),
      ),
    );
  }

  Widget _row(_Entry e, int i, List<Color> medals) => Container(
        margin: const EdgeInsets.only(bottom: Sp.md), padding: const EdgeInsets.all(Sp.md),
        decoration: BoxDecoration(
          color: e.isMe ? Color.alphaBlend(AppColors.primary.withAlpha(0x12), AppColors.surface) : AppColors.surface,
          borderRadius: BorderRadius.circular(Rad.xl),
          border: Border.all(color: e.isMe ? AppColors.primary : AppColors.border),
          boxShadow: toyShadow(AppColors.toyShadowColor, 4)),
        child: Row(children: [
          SizedBox(width: 36, child: Center(child: i < 3
              ? Container(width: 34, height: 34, decoration: BoxDecoration(color: medals[i], shape: BoxShape.circle, boxShadow: toyShadow(AppColors.toyShadowColor, 3)),
                  child: const Icon(Icons.emoji_events, size: 16, color: AppColors.textOnPrimary))
              : Text('${i + 1}', style: Fonts.body(16, w: FontWeight.w700, color: AppColors.textSecondary)))),
          const SizedBox(width: Sp.sm),
          Container(width: 36, height: 36, alignment: Alignment.center,
              decoration: BoxDecoration(color: e.isMe ? AppColors.primaryDark : AppColors.border, shape: BoxShape.circle),
              child: Text(e.name.isEmpty ? '' : e.name[0], style: Fonts.body(14, w: FontWeight.w700, color: AppColors.textOnPrimary))),
          const SizedBox(width: Sp.sm),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${e.name} ${e.isMe ? '(You)' : ''}',
                style: e.isMe ? Fonts.body(16, w: FontWeight.w700, color: AppColors.primaryDark) : Fonts.body(16, color: AppColors.textPrimary)),
            Text('Level ${e.level}', style: Fonts.body(12, color: AppColors.textSecondary)),
          ])),
          const SizedBox(width: Sp.sm),
          Text('${tab == 'stars' ? e.stars : e.streak}', style: Fonts.body(18, w: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(width: 4),
          Text(tab == 'stars' ? '⭐' : '🔥', style: const TextStyle(fontSize: 14)),
        ]),
      );
}
