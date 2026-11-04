import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models.dart';
import '../../data/parent_hub.dart';
import '../../l10n.dart';
import '../../store/app_store.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../../widgets/common.dart';
import 'assign_activity_screen.dart';
import 'assignment_widgets.dart';
import 'hub_widgets.dart';

/// Letter by letter, matra by matra: accuracy bands, strong and weak
/// letters, weak areas found automatically and what to practise next.
class SkillAnalyticsScreen extends StatefulWidget {
  const SkillAnalyticsScreen({super.key});
  @override
  State<SkillAnalyticsScreen> createState() => _SkillAnalyticsScreenState();
}

class _SkillAnalyticsScreenState extends State<SkillAnalyticsScreen> {
  int tab = 0; // letters, matras, reading

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    final scope = ParentHubScope.of(context);
    final i = selectedInsights(context);
    if (i == null) return HubPage(title: tr('Skills', 'कौशल'), body: const SizedBox.shrink());
    final kids = hubChildren(s, scope.parentId);
    final weak = i.weakAreas;

    return HubPage(
      title: tr('Skill analytics', 'कौशल विश्लेषण'), subtitle: i.student.name,
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (kids.length > 1) ...[
          ChildSelector(kids: kids, selected: i.student.id, onSelect: (id) => scope.selected.value = id),
          const SizedBox(height: Sp.md),
        ],
        // Weak areas first: what a parent can act on.
        Text(tr('Needs attention', 'ध्यान दें'), style: Fonts.display(19)),
        const SizedBox(height: Sp.sm),
        if (weak.isEmpty)
          ToyCard(color: AppColors.success.withOpacity(0.07), borderColor: AppColors.success.withOpacity(0.35), child: Row(children: [
            const Text('🌟', style: TextStyle(fontSize: 26)),
            const SizedBox(width: Sp.sm),
            Expanded(child: Text(i.started ? tr('No weak areas found. ${i.student.name} is doing well!', 'कोई कमज़ोरी नहीं मिली। ${i.student.name} अच्छा कर रहे हैं!')
                : tr('Weak areas show here once ${i.student.name} has practised a little.', '${i.student.name} के थोड़ा अभ्यास करने पर कमज़ोरियाँ यहाँ दिखेंगी।'),
                style: Fonts.body(14, w: FontWeight.w700))),
          ]))
        else
          for (final w in weak) WeakAreaTile(w, childId: i.student.id),
        const SizedBox(height: Sp.md),
        HubSegmented(options: [tr('Letters', 'अक्षर'), tr('Matras', 'मात्राएँ'), tr('Reading', 'पढ़ना')],
            selected: tab, onChanged: (v) => setState(() => tab = v)),
        const SizedBox(height: Sp.md),
        const BandLegend(),
        const SizedBox(height: Sp.sm),
        switch (tab) {
          0 => _letters(i),
          1 => _matras(i),
          _ => _reading(i),
        },
      ]),
    );
  }

  Widget _letters(ChildInsights i) {
    final counts = {for (final b in SkillBand.values) b: AppData.allLetters.where((l) => i.letterBand(l.id) == b).length};
    void assign(String id) => pushHub(context, AssignActivityScreen(childId: i.student.id, category: 'writing', letterId: id));
    Widget grid(String title, List<dynamic> letters) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          HubSection(title),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final l in letters) LetterTile(character: l.character, band: i.letterBand(l.id), accuracy: i.letterAccuracy(l.id),
                onTap: () => assign(l.id)),
          ]),
        ]);
    final strong = i.strongLetters.take(8).toList(), weakL = i.weakLetters.take(8).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      HubGrid(children: [
        for (final b in SkillBand.values) ToyCard(shadow: 2, padding: const EdgeInsets.all(Sp.sm + 2), child: Row(children: [
          Icon(b.icon, color: b.color, size: 22),
          const SizedBox(width: Sp.sm),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${counts[b]}', style: Fonts.display(20, height: 1.1)),
            Text(tr(b.label, b.hindi), maxLines: 1, overflow: TextOverflow.ellipsis,
                style: Fonts.body(11.5, w: FontWeight.w700, color: AppColors.textSecondary)),
          ])),
        ])),
      ]),
      if (strong.isNotEmpty || weakL.isNotEmpty) ...[
        const SizedBox(height: Sp.md),
        HubGrid(cols: 2, narrowCols: 1, gap: Sp.md, children: [
          _letterList(tr('Strongest letters', 'सबसे मज़बूत अक्षर'), '💪', strong, i, SkillBand.excellent),
          _letterList(tr('Weakest letters', 'सबसे कमज़ोर अक्षर'), '🎯', weakL, i, SkillBand.needsPractice),
        ]),
      ],
      grid(tr('Vowels · स्वर', 'स्वर'), AppData.vowels),
      grid(tr('Consonants · व्यंजन', 'व्यंजन'), AppData.consonants),
      const SizedBox(height: Sp.sm),
      Text(tr('Tap a letter to assign practice for it.', 'अभ्यास देने के लिए किसी अक्षर को दबाएँ।'),
          style: Fonts.body(12.5, w: FontWeight.w600, color: AppColors.textMuted)),
    ]);
  }

  Widget _letterList(String title, String emoji, List<String> ids, ChildInsights i, SkillBand band) => ToyCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('$emoji  $title', style: Fonts.display(16)),
          const SizedBox(height: Sp.sm),
          if (ids.isEmpty) Text(tr('None yet', 'अभी कोई नहीं'), style: Fonts.body(13, color: AppColors.textMuted)),
          for (final id in ids) ProgressRow(
            label: AppData.letterById(id)?.character ?? id, value: '${i.letterAccuracy(id)}%',
            fraction: (i.letterAccuracy(id) ?? 0) / 100, color: band.color,
          ),
        ]),
      );

  Widget _matras(ChildInsights i) {
    final perf = i.matraPerformance;
    return ToyCard(child: Column(children: [
      for (final m in AppData.matras) Builder(builder: (_) {
        final p = perf[m.id]!;
        final band = i.matraBand(p);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Container(width: 46, height: 46, alignment: Alignment.center,
                decoration: BoxDecoration(color: band.color.withOpacity(0.1), borderRadius: BorderRadius.circular(Rad.md),
                    border: Border.all(color: band.color.withOpacity(0.35))),
                child: Text('क${m.symbol}', style: Fonts.hindi(20, height: 1.2))),
            const SizedBox(width: Sp.md),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m.name, style: Fonts.body(14.5, w: FontWeight.w800)),
              const SizedBox(height: 4),
              ClipRRect(borderRadius: BorderRadius.circular(9999), child: LinearProgressIndicator(
                  value: (p.$1 ?? (p.$2 ? 70 : 0)) / 100, minHeight: 7, color: band.color, backgroundColor: AppColors.muted)),
            ])),
            const SizedBox(width: Sp.md),
            SizedBox(width: 120, child: Align(alignment: Alignment.centerRight, child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(p.$1 == null ? (p.$2 ? tr('Quiz passed', 'क्विज़ पास') : '—') : '${p.$1}%', style: Fonts.body(14, w: FontWeight.w800)),
              BandChip(band),
            ]))),
          ]),
        );
      }),
    ]));
  }

  Widget _reading(ChildInsights i) {
    final (ws, wn) = i.wordSkill;
    final reading = [...activitiesIn('reading'), ...activitiesIn('listening'), ...activitiesIn('quiz'), ...activitiesIn('speaking')];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      HubGrid(children: [
        KpiTile(icon: Icons.menu_book_rounded, color: AppColors.success, value: '${i.readingScore}%', label: tr('Reading progress', 'पढ़ने की प्रगति')),
        KpiTile(icon: Icons.spellcheck_rounded, color: const Color(0xFF4FB2E6), value: ws == null ? '—' : '$ws%',
            label: tr('Word recognition', 'शब्द पहचान'), note: tr('$wn words', '$wn शब्द')),
        KpiTile(icon: Icons.headphones_rounded, color: AppColors.secondary, value: '${i.v.counters['listens'] ?? 0}',
            label: tr('Listening passes', 'सुनने के पास')),
        KpiTile(icon: Icons.mic_rounded, color: AppColors.primary, value: '${i.v.counters['speaks'] ?? 0}', label: tr('Speaking passes', 'बोलने के पास')),
      ]),
      HubSection(tr('Activity levels', 'गतिविधि स्तर')),
      ToyCard(child: Column(children: [
        for (final a in reading) Builder(builder: (_) {
          final done = i.v.activityProgress[a.id] ?? 0;
          final band = done == 0 ? SkillBand.notStarted : done >= a.levels.length * 0.7 ? SkillBand.excellent
              : SkillBand.good;
          return ProgressRow(label: a.title, value: '$done/${a.levels.length}', fraction: done / a.levels.length,
              color: hubCategory(categoryOfActivity(a.id)).color, leading: Icon(band.icon, size: 16, color: band.color));
        }),
      ])),
    ]);
  }
}
