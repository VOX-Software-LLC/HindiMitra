import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/feedback.dart';
import '../store/app_store.dart';
import '../theme/app_theme.dart';
import '../theme/palette.dart';
import '../widgets/toy_button.dart';

const _roles = [
  ('student', '🎓', 'I want to learn Hindi', 'Practice reading, writing & speaking'),
  ('parent', '👨‍👩‍👧', "I'm setting up for my child", 'Monitor progress & set goals'),
  ('teacher', '👩‍🏫', "I'm a teacher", 'Manage students & track classroom'),
];
const _goals = [
  ('casual', 5, '5 min / day', '🌱', 'Casual — Just getting started'),
  ('regular', 10, '10 min / day', '🌿', 'Regular — Steady progress'),
  ('serious', 15, '15 min / day', '🌳', 'Serious — Fast learner'),
  ('intense', 20, '20 min / day', '🔥', 'Intense — Dedicated student'),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with SingleTickerProviderStateMixin {
  int step = 0;
  String? role;
  String selectedGoal = 'regular';
  final nameCtrl = TextEditingController();
  late final AnimationController _bounce =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);

  @override
  void dispose() { _bounce.dispose(); nameCtrl.dispose(); super.dispose(); }

  Widget _mascot(double size) => RepaintBoundary(child: AnimatedBuilder(
        animation: _bounce,
        builder: (_, __) => Transform.translate(
          offset: Offset(0, -12 * Curves.easeInOut.transform(_bounce.value)),
          child: Text('🦜', style: TextStyle(fontSize: size)),
        ),
      ));

  void _finish() {
    hapticSuccess();
    final name = nameCtrl.text.trim().isEmpty ? 'Student' : nameCtrl.text.trim();
    final g = _goals.firstWhere((x) => x.$1 == selectedGoal);
    final age = role == 'parent' ? 'kid-7-10' : 'adult';
    context.read<AppStore>().completeOnboarding(name, age, role, goal: (g.$2 / 3).ceil());
  }

  Widget _optionCard({required bool selected, required String emoji, required String label,
      required String desc, required VoidCallback onTap, double emojiSize = 34}) {
    return GestureDetector(
      onTap: () { hapticLight(); onTap(); },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(Sp.md),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withOpacity(0.06) : AppColors.surface,
          borderRadius: BorderRadius.circular(Rad.xl),
          border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: selected ? 2 : 1),
          boxShadow: toyShadow(AppColors.toyShadowColor, 4),
        ),
        child: Row(children: [
          Text(emoji, style: TextStyle(fontSize: emojiSize)),
          const SizedBox(width: Sp.md),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: Fonts.body(15, w: FontWeight.w700,
                color: selected ? AppColors.primaryDark : AppColors.textPrimary)),
            Text(desc, style: Fonts.body(12, color: AppColors.textSecondary, height: 1.35)),
          ])),
          Container(
            width: 24, height: 24,
            decoration: BoxDecoration(shape: BoxShape.circle,
                border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: 2)),
            child: selected ? Center(child: Container(width: 12, height: 12,
                decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle))) : null,
          ),
        ]),
      ),
    );
  }

  Widget _title(String t, [String? sub]) => Column(children: [
        Text(t, textAlign: TextAlign.center, style: Fonts.display(26, height: 1.3)),
        if (sub != null) ...[
          const SizedBox(height: 4),
          Text(sub, textAlign: TextAlign.center,
              style: Fonts.body(16, color: AppColors.textSecondary, w: FontWeight.w500)),
        ],
        const SizedBox(height: Sp.xl),
      ]);

  @override
  Widget build(BuildContext context) {
    final progress = step / 3;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(children: [
          if (step > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(Sp.md, Sp.sm, Sp.md, 0),
              child: Row(children: [
                IconButton(onPressed: () => setState(() => step = step - 1),
                    icon: const Icon(Icons.close, size: 28, color: AppColors.textSecondary)),
                Expanded(child: ClipRRect(
                  borderRadius: BorderRadius.circular(9999),
                  child: Container(height: 14, color: AppColors.border, alignment: Alignment.centerLeft,
                    child: AnimatedFractionallySizedBox(
                      duration: const Duration(milliseconds: 300), widthFactor: progress,
                      child: Container(color: AppColors.success)),
                  ),
                )),
              ]),
            ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(Sp.lg),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    child: KeyedSubtree(key: ValueKey(step), child: _stepBody()),
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _stepBody() {
    switch (step) {
      case 0:
        return Column(children: [
          _mascot(104),
          const SizedBox(height: Sp.md),
          Text('HindiMitra', style: Fonts.display(44)),
          Text('हिंदी सीखो', style: Fonts.hindi(30, color: AppColors.primary, height: 1.3)),
          const SizedBox(height: Sp.sm),
          Text('Learn Hindi the fun way', textAlign: TextAlign.center,
              style: Fonts.body(18, color: AppColors.textSecondary, w: FontWeight.w500)),
          const SizedBox(height: Sp.xxl),
          ToyButton(label: 'GET STARTED', size: ToySize.lg, fullWidth: true, onPressed: () => setState(() => step = 1)),
          const SizedBox(height: Sp.md),
          ToyButton(label: 'I ALREADY HAVE AN ACCOUNT', variant: ToyVariant.outline, fullWidth: true,
              onPressed: () => setState(() => step = 1)),
        ]);
      case 1:
        return Column(children: [
          _title('How will you use HindiMitra?'),
          for (final r in _roles)
            _optionCard(selected: role == r.$1, emoji: r.$2, label: r.$3, desc: r.$4,
                onTap: () => setState(() => role = r.$1)),
          const SizedBox(height: Sp.md),
          ToyButton(label: 'CONTINUE', size: ToySize.lg, fullWidth: true,
              onPressed: role == null ? null : () => setState(() => step = 2)),
        ]);
      case 2:
        final name = nameCtrl.text.trim();
        return Column(children: [
          _mascot(56),
          const SizedBox(height: Sp.md),
          _title(role == 'parent' ? "What's your child's name?" : "What's your name?",
              role == 'parent' ? "We'll personalize lessons for them" : 'So we can personalize your experience'),
          TextField(
            controller: nameCtrl, autofocus: true, maxLength: 20, textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
            style: Fonts.body(20, w: FontWeight.w600),
            decoration: InputDecoration(
              counterText: '', filled: true, fillColor: AppColors.surface,
              hintText: role == 'parent' ? "Child's name" : 'Your name',
              hintStyle: Fonts.body(20, color: AppColors.textSecondary, w: FontWeight.w600),
              contentPadding: const EdgeInsets.symmetric(horizontal: Sp.lg, vertical: Sp.md),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.lg),
                  borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.lg),
                  borderSide: const BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.lg),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2)),
            ),
          ),
          const SizedBox(height: Sp.lg),
          if (name.isNotEmpty)
            Container(
              width: double.infinity, margin: const EdgeInsets.only(bottom: Sp.lg),
              padding: const EdgeInsets.all(Sp.md),
              decoration: BoxDecoration(
                color: Palette.light.sunny.withOpacity(0.2),
                borderRadius: BorderRadius.circular(Rad.xl),
                border: Border.all(color: AppColors.border),
                boxShadow: toyShadow(AppColors.toyShadowColor, 3)),
              child: Row(children: [
                const Text('🦜', style: TextStyle(fontSize: 32)),
                const SizedBox(width: Sp.md),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('नमस्ते, $name! 🙏', style: Fonts.hindi(22, height: 1.4)),
                  Text('Nice to meet you!', style: Fonts.body(12, color: AppColors.textSecondary, w: FontWeight.w500)),
                ])),
              ]),
            ),
          ToyButton(label: name.isNotEmpty ? 'CONTINUE' : 'SKIP', size: ToySize.lg, fullWidth: true,
              onPressed: () => setState(() => step = 3)),
        ]);
      default:
        return Column(children: [
          _title('Set a daily goal', 'Consistent practice is the key to learning!'),
          for (final g in _goals)
            _optionCard(selected: selectedGoal == g.$1, emoji: g.$4, label: g.$3, desc: g.$5,
                emojiSize: 26, onTap: () => setState(() => selectedGoal = g.$1)),
          Padding(
            padding: const EdgeInsets.only(bottom: Sp.xl),
            child: Text('You can change this later in Settings',
                style: Fonts.body(12, color: AppColors.textSecondary, w: FontWeight.w500)),
          ),
          ToyButton(label: 'START LEARNING', variant: ToyVariant.success, size: ToySize.lg,
              fullWidth: true, onPressed: _finish),
        ]);
    }
  }
}
