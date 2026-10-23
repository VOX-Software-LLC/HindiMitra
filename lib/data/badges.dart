import 'package:flutter/material.dart';
import '../store/app_store.dart';
import '../theme/palette.dart';
import '../widgets/badge_reveal.dart';
import 'models.dart';

/// How far the child is towards a badge: [done] of [goal], plus a short
/// "what's left" line. [tracked] is false for badges the app cannot measure yet.
class BadgeProgress {
  final int done, goal;
  final String left;
  final bool tracked;
  const BadgeProgress(this.done, this.goal, this.left, {this.tracked = true});
  double get fraction => goal <= 0 ? 0 : (done / goal).clamp(0.0, 1.0);
  bool get complete => tracked && done >= goal;
}

class BadgeDef {
  final BadgeInfo info;
  final String category; // Writing | Streaks | Milestones
  final BadgeProgress Function(AppStore) progress;
  const BadgeDef(this.info, this.category, this.progress);
  bool earned(AppStore s) => progress(s).complete;
}

const _violet = Color(0xFF6E4EDF);
const badgeCategories = ['All', 'Writing', 'Streaks', 'Milestones'];

String _unit(int n, String one, [String? many]) => n == 1 ? one : (many ?? '${one}s');

BadgeProgress _count(int done, int goal, String unit, String verb, [String? units]) {
  final left = (goal - done).clamp(0, goal);
  return BadgeProgress(done.clamp(0, goal), goal, left == 0 ? 'Done!' : '$verb $left more ${_unit(left, unit, units)}');
}

int _masteredVowels(AppStore s) => AppData.vowels.where((v) => s.letterProgress[v.id]?.mastered == true).length;

final List<BadgeDef> badgeDefs = [
  BadgeDef(const BadgeInfo('first-letter', 'First Letter', 'पहला अक्षर', 'Complete your first letter practice', 'ribbon', AppColors.primary),
      'Writing', (s) => _count(s.totalStars > 0 ? 1 : 0, 1, 'letter', 'Practise')),
  BadgeDef(const BadgeInfo('vowel-master', 'Vowel Master', 'स्वर गुरु', 'Master all 13 vowels', 'medal', AppColors.readingModule),
      'Writing', (s) => _count(_masteredVowels(s), AppData.vowels.length, 'vowel', 'Master')),
  BadgeDef(const BadgeInfo('speed-writer', 'Speed Writer', 'तेज़ लेखक', 'Complete a letter in under 30s', 'flash', AppColors.secondary),
      'Writing', (s) => const BadgeProgress(0, 1, 'Coming soon', tracked: false)),
  BadgeDef(const BadgeInfo('perfect-score', 'Perfect Score', 'पूर्ण अंक', '3 stars on all 4 stages', 'diamond', _violet),
      'Writing', (s) => const BadgeProgress(0, 1, 'Coming soon', tracked: false)),
  BadgeDef(const BadgeInfo('consonant-master', 'Consonant Pro', 'व्यंजन गुरु', 'Practice all consonant groups', 'shield-checkmark', Color(0xFF8E24AA)),
      'Writing', (s) => _count(s.letterProgress.length, 25, 'letter', 'Practise')),
  BadgeDef(const BadgeInfo('word-wizard', 'Word Wizard', 'शब्द जादूगर', 'Build 20 words correctly', 'construct', Color(0xFF00897B)),
      'Writing', (s) => const BadgeProgress(0, 20, 'Coming soon', tracked: false)),
  BadgeDef(const BadgeInfo('streak-7', 'Streak 7', '7 दिन की लय', '7-day practice streak', 'flame', AppColors.primary),
      'Streaks', (s) => _count(s.currentStreak, 7, 'day', 'Practise')),
  BadgeDef(const BadgeInfo('streak-30', 'Monthly Streak', '30 दिन की लय', '30-day practice streak!', 'bonfire', Color(0xFFE65100)),
      'Streaks', (s) => _count(s.currentStreak, 30, 'day', 'Practise')),
  BadgeDef(const BadgeInfo('night-owl', 'Night Owl', 'रात का उल्लू', 'Practice after 9 PM', 'moon', Color(0xFF5C6BC0)),
      'Streaks', (s) => DateTime.now().hour >= 21
          ? const BadgeProgress(1, 1, 'Done!') : const BadgeProgress(0, 1, 'Practise after 9 PM')),
  BadgeDef(const BadgeInfo('early-bird', 'Early Bird', 'सुबह की चिड़िया', 'Practice before 7 AM', 'sunny', Color(0xFFFF9800)),
      'Streaks', (s) => DateTime.now().hour < 7
          ? const BadgeProgress(1, 1, 'Done!') : const BadgeProgress(0, 1, 'Practise before 7 AM')),
  BadgeDef(const BadgeInfo('100-stars', '100 Stars', '100 तारे', 'Earn 100 stars total', 'star', AppColors.starGold),
      'Milestones', (s) => _count(s.totalStars, 100, 'star', 'Earn')),
  BadgeDef(const BadgeInfo('500-stars', '500 Stars', '500 तारे', 'Earn 500 stars total', 'star-half', Color(0xFFFFC107)),
      'Milestones', (s) => _count(s.totalStars, 500, 'star', 'Earn')),
  BadgeDef(const BadgeInfo('reading-star', 'Reading Star', 'पठन सितारा', 'Complete 10 reading activities', 'book', AppColors.readingModule),
      'Milestones', (s) => _count(s.todayPracticeCount, 10, 'activity', 'Complete', 'activities')),
  BadgeDef(const BadgeInfo('1000-points', 'Point Master', 'अंक राजा', 'Earn 1000 points', 'trophy', AppColors.secondary),
      'Milestones', (s) => _count(s.totalPoints, 1000, 'point', 'Earn')),
];

BadgeDef? badgeById(String id) {
  for (final b in badgeDefs) { if (b.info.id == id) return b; }
  return null;
}
