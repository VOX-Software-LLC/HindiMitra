import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/matra_course.dart';
import '../../data/models.dart';
import '../../routes.dart';
import '../../services/matra_checker.dart';
import '../../services/speech_service.dart';
import '../../store/app_store.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../../widgets/common.dart';
import '../../widgets/toy_button.dart';
import '../writing/matra_screen.dart';
import 'matra_round.dart';
import 'matra_text.dart';

const matraActivityId = 'matra-practice';

/// Signs a child knows after finishing [levelsDone] matra levels.
int matrasKnownAfter(int levelsDone) => const [0, 2, 5, 7, 9, 12][math.min(levelsDone, 5)];

/// Matra Practice: each of the 10 levels is its own game, and every round
/// runs See → Write → Use ([MatraRoundView]). Opened without a level it shows
/// the matra browser.
class MatraLevelScreen extends StatelessWidget {
  final Map<String, dynamic> params;
  const MatraLevelScreen({super.key, this.params = const {}});

  @override
  Widget build(BuildContext context) {
    final n = params['levelNumber'];
    final activity = AppData.writingActivities.where((a) => a.id == matraActivityId);
    if (n is! int || activity.isEmpty) return MatraScreen(params: params);
    final lvl = activity.first.levels.firstWhere((l) => l.level == n, orElse: () => activity.first.levels.first);
    return _MatraLevel(level: lvl);
  }
}

class _MatraLevel extends StatefulWidget {
  final LevelDef level;
  const _MatraLevel({required this.level});
  @override
  State<_MatraLevel> createState() => _MatraLevelState();
}

enum _Stage { intro, play, results }

class _MatraLevelState extends State<_MatraLevel> {
  _Stage stage = _Stage.intro;
  late List<MatraRound> rounds;
  final results = <RoundResult>[];
  int index = 0, secondsLeft = 0;
  bool parentOpen = false;
  Timer? _timer;

  LevelDef get lvl => widget.level;
  Map<String, dynamic> get p => lvl.params;
  String get game => p['game'] as String? ?? 'where';
  int get timeLimit => (p['timeLimit'] as num?)?.toInt() ?? 0;
  bool get timed => timeLimit > 0;

  List<Matra> get pool {
    final m = p['matras'];
    final all = [for (final x in AppData.matras) if (matraWords.containsKey(x.romanized)) x];
    if (m is List) return [for (final r in m) ...all.where((x) => x.romanized == r)];
    return all;
  }

  Matra _bySign(String s) => AppData.matras.firstWhere((m) => m.symbol == s);

  /// Only rounds whose letter can be drawn on the matra canvas.
  bool _drawable(MatraRound r) => MatraGlyph.of(r.base, r.sign) != null;

  List<MatraRound> _buildRounds() {
    final count = (p['count'] as num?)?.toInt() ?? (timed ? 40 : 6);
    final List<MatraRound> out;
    switch (game) {
      case 'magic':
        out = [for (final x in AppData.deck(matraPairs, count)) MatraRound(_bySign(matraOf(x.to.unit)), x.to, from: x.from)];
      case 'fix':
        out = [for (final x in AppData.deck(matraFixes, count))
          MatraRound(_bySign(matraOf(x.right.unit)), x.right, wrong: x.wrong)];
      case 'world':
        final per = math.max(1, count ~/ matraThemes.length);
        out = [
          for (final t in matraThemes)
            for (final w in AppData.deck(t.$3, per)) MatraRound(_bySign(matraOf(w.unit)), w),
        ];
      default:
        out = [
          for (final m in AppData.deck(pool, count))
            MatraRound(m, matraWords[m.romanized]![AppData.rng.nextInt(matraWords[m.romanized]!.length)]),
        ];
    }
    return out.where(_drawable).toList();
  }

  void _start() {
    _timer?.cancel();
    setState(() {
      rounds = _buildRounds();
      results.clear();
      index = 0;
      stage = _Stage.play;
      secondsLeft = timeLimit;
    });
    if (timed) {
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        setState(() => secondsLeft--);
        if (secondsLeft <= 0) {
          t.cancel();
          speakEnglish(MT.timesUp);
          _finish();
        }
      });
    }
  }

  void _roundDone(RoundResult r) {
    results.add(r);
    if (index + 1 < rounds.length) {
      setState(() => index++);
    } else {
      _finish();
    }
  }

  int get accuracy {
    if (results.isEmpty) return 0;
    final mean = results.fold<int>(0, (a, r) => a + r.accuracy) / results.length;
    final slips = results.fold<int>(0, (a, r) => a + r.mistakes);
    return (mean - slips * 3).round().clamp(0, 100);
  }

  int get passedCount => results.where((r) => r.passed).length;

  int get stars {
    if (timed) return passedCount >= 8 ? 3 : passedCount >= 5 ? 2 : passedCount >= 2 ? 1 : 0;
    return accuracy >= 85 ? 3 : accuracy >= 65 ? 2 : accuracy >= 40 ? 1 : 0;
  }

  void _finish() {
    _timer?.cancel();
    if (!mounted || stage == _Stage.results) return;
    final s = context.read<AppStore>();
    if (stars > 0) s.completeActivityLevel(matraActivityId, lvl.level);
    s.recordLevelAccuracy(lvl.id, accuracy);
    s.addPoints(passedCount * 10);
    setState(() => stage = _Stage.results);
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(bottom: false, child: Column(children: [
        HeaderBar(
          title: lvl.name, subtitle: '${MT.levelN(lvl.level)} · ${lvl.hindiName}',
          onBack: () => Navigator.of(context).maybePop(),
          rightAction: stage == _Stage.play && timed
              ? SoftPill(icon: Icons.timer_outlined, label: MT.timeLeft(math.max(0, secondsLeft)), color: secondsLeft <= 10 ? AppColors.error : AppColors.primary)
              : null,
        ),
        Expanded(child: switch (stage) {
          _Stage.intro => _intro(),
          _Stage.play => _play(),
          _Stage.results => _results(),
        }),
      ])),
    );
  }

  Widget _intro() {
    final signs = const {'magic', 'fix', 'world'}.contains(game) ? <Matra>[] : pool;
    return screenScroll(maxWidth: 620, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PopIn(child: Container(
        padding: const EdgeInsets.all(Sp.lg),
        decoration: BoxDecoration(gradient: toneGradient(AppColors.primary), borderRadius: BorderRadius.circular(Rad.xl2),
            boxShadow: softShadow(AppColors.primary)),
        child: Column(children: [
          Text(lvl.emoji, style: const TextStyle(fontSize: 52)),
          const SizedBox(height: Sp.sm),
          Text(lvl.name, textAlign: TextAlign.center, style: Fonts.display(26, color: AppColors.textOnPrimary)),
          Text(lvl.hindiName, style: Fonts.hindi(18, color: AppColors.textOnPrimary.withOpacity(0.9))),
          const SizedBox(height: Sp.sm),
          Text(lvl.description, textAlign: TextAlign.center,
              style: Fonts.body(15, w: FontWeight.w600, color: AppColors.textOnPrimary.withOpacity(0.92))),
        ]),
      )),
      const SizedBox(height: Sp.md),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (final (e, t) in [('👀', MT.stepSee), ('✍️', MT.stepWrite), ('🧩', MT.stepUse)]) ...[
          if (e != '👀') Icon(Icons.arrow_forward_rounded, size: 18, color: AppColors.textSecondary),
          Padding(padding: const EdgeInsets.symmetric(horizontal: Sp.sm),
              child: Text('$e $t', style: Fonts.body(16, w: FontWeight.w800))),
        ],
      ]),
      Padding(
        padding: const EdgeInsets.only(top: Sp.xs),
        child: Text(MT.howItWorks, textAlign: TextAlign.center,
            style: Fonts.body(14, w: FontWeight.w600, color: AppColors.textSecondary)),
      ),
      if (signs.isNotEmpty) ...[
        Padding(padding: const EdgeInsets.only(top: Sp.lg, bottom: Sp.sm), child: Text(MT.inThisLevel, style: Fonts.display(18))),
        if (signs.length <= 4)
          for (final m in signs) _signCard(m)
        else
          Wrap(spacing: Sp.sm, runSpacing: Sp.sm, children: [
            for (final m in signs) Pressable(
              onTap: () => speakHindi('क${m.symbol}', rate: 0.5),
              child: ToyCard(padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.xs),
                  child: Text('◌${m.symbol}', style: Fonts.hindi(30, height: 1.3))),
            ),
          ]),
      ],
      const SizedBox(height: Sp.md),
      _parentsCorner(),
      const SizedBox(height: Sp.lg),
      ResultButton(label: MT.start, icon: Icons.play_arrow_rounded, onTap: _start),
      const SizedBox(height: Sp.sm),
      TextButton(onPressed: () => openScreen(context, 'MatraExplorer'),
          child: Text(MT.browseAll, style: Fonts.body(15, w: FontWeight.w700, color: AppColors.primary))),
      const SizedBox(height: Sp.xl),
    ]));
  }

  Widget _signCard(Matra m) => ToyCard(
        margin: const EdgeInsets.only(bottom: Sp.sm),
        onTap: () => speakHindi('क${m.symbol}', rate: 0.5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 64, child: Text('क${m.symbol}', textAlign: TextAlign.center,
              style: Fonts.hindi(38, color: AppColors.primaryDark, height: 1.3))),
          const SizedBox(width: Sp.sm),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('◌${m.symbol}  ${m.name}', style: Fonts.hindi(17, height: 1.4)),
            Text(MT.soundsLike(m.anchor), style: Fonts.body(14, w: FontWeight.w700)),
            Text('📍 ${MT.placeHint(m.symbol, m.position)}', style: Fonts.body(13, w: FontWeight.w600, color: AppColors.textSecondary)),
            if (m.hinglish.isNotEmpty) Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('🔤 ${m.hinglish}', style: Fonts.body(13, w: FontWeight.w500, color: AppColors.textSecondary)),
            ),
          ])),
          Icon(Icons.volume_up_rounded, color: AppColors.primary),
        ]),
      );

  Widget _parentsCorner() => ToyCard(
        color: AppColors.secondary.withOpacity(0.08), borderColor: AppColors.secondary.withOpacity(0.35),
        onTap: () => setState(() => parentOpen = !parentOpen),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('👪', style: TextStyle(fontSize: 22)),
            const SizedBox(width: Sp.sm),
            Expanded(child: Text(MT.parentsCorner, style: Fonts.display(16))),
            Icon(parentOpen ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: AppColors.textSecondary),
          ]),
          if (parentOpen) Padding(
            padding: const EdgeInsets.only(top: Sp.sm),
            child: Text(MT.parentTip(lvl.level), style: Fonts.body(14, w: FontWeight.w500, height: 1.4)),
          ),
        ]),
      );

  Widget _play() {
    if (rounds.isEmpty) return const SizedBox.shrink();
    final r = rounds[index];
    return screenScroll(maxWidth: 620, child: Column(children: [
      if (!timed) ...[
        ClipRRect(borderRadius: BorderRadius.circular(9999), child: LinearProgressIndicator(
            value: (index + 1) / rounds.length, minHeight: 10,
            backgroundColor: AppColors.border, color: AppColors.success)),
        const SizedBox(height: Sp.xs),
        Text(MT.round(index + 1, rounds.length), style: Fonts.body(14, w: FontWeight.w700, color: AppColors.textSecondary)),
      ] else
        Text('✅ $passedCount', style: Fonts.display(20, color: AppColors.success)),
      const SizedBox(height: Sp.sm),
      MatraRoundView(key: ValueKey('${r.syllable}-$index'), round: r, game: game, guided: lvl.level <= 5,
          onDone: _roundDone),
      const SizedBox(height: Sp.xxl),
    ]));
  }

  Widget _results() => Stack(children: [
        SessionCompleteCard(
          emoji: lvl.emoji, title: MT.levelDone, stars: stars,
          stats: [
            (timed ? '$passedCount' : '${results.length}', timed ? MT.statWritten : MT.statRounds),
            ('$accuracy%', MT.statAccuracy),
          ],
          message: MT.resultMessage(stars),
          retryLabel: MT.playAgainLevel, doneLabel: MT.backToMenu,
          onRetry: _start, onDone: () => Navigator.of(context).maybePop(),
          extra: game == 'world'
              ? ResultButton(label: MT.writeMyName, icon: Icons.badge_rounded, color: AppColors.secondary,
                  onTap: () => openScreen(context, 'MatraNameCard'))
              : null,
        ),
        IgnorePointer(child: Confetti(visible: stars >= 2)),
      ]);
}
