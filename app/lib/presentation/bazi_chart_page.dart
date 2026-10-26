import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/providers.dart';
import '../domain/models.dart';
import '../l10n/gen/app_localizations.dart';
import 'design.dart';
import 'labels.dart';
import 'theme.dart';
import 'widgets/report_request.dart';

/// 四柱 · 農曆對照 · 五行 · 大運 · 流年, then the AI reading request.
class BaziChartPage extends ConsumerWidget {
  const BaziChartPage({super.key, required this.chart, this.personName = ''});
  final ChartResult chart;
  final String personName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(settingsProvider).apiLocaleCode;
    final terms = ref.watch(termsProvider).value;
    final b = chart.bazi;
    String t(String k) => terms?.t(k, locale) ?? k;
    String chars(String s) => s.characters.map(t).join();
    final title = personName.isEmpty ? l10n.homeBazi : l10n.chartOf(personName);

    final sections = <Widget>[
      HeroBanner(
        title: title,
        subtitle: '${l10n.dayMaster} ${b.dayMasterGan}${t(b.dayMasterWuxing)}（${t(b.dayMasterYinYang)}）',
        trailing: GanZhiText(b.pillars['day']!.ganzhi, size: 34),
      ),
      AppCard(
        title: l10n.fourPillars,
        icon: Icons.grid_view_rounded,
        child: _PillarGrid(chart: b, t: t),
      ),
      AppCard(
        key: const Key('lunar-card'),
        title: l10n.lunarCompare,
        icon: Icons.nightlight_round,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _KV(l10n.gregorian, b.civilLocal.substring(0, 16).replaceFirst('T', ' ')),
            _KV(
              l10n.lunarLabel,
              '${b.lunar.yearGanzhi}年${chars(b.lunar.monthName)}${b.lunar.dayName} · ${b.pillars['hour']!.zhi}${t('时')}',
            ),
            _KV(l10n.zodiac, t(b.lunar.shengxiao)),
            if (b.lunar.yearGanzhi != b.pillars['year']!.ganzhi)
              Padding(
                padding: const EdgeInsets.only(top: Space.s),
                child: Pill(l10n.lunarYearNote, icon: Icons.info_outline, color: Theme.of(context).colorScheme.tertiary),
              ),
          ],
        ),
      ),
      AppCard(
        title: l10n.wuxingWeighted,
        icon: Icons.donut_large,
        child: Column(children: [for (final e in b.wuxingWeighted.entries) _WuxingBar(e.key, e.value, t(e.key))]),
      ),
      AppCard(
        title: l10n.dayun,
        icon: Icons.timeline,
        trailing: Text(
          '${t(b.dayunForward ? '顺行' : '逆行')} · ${l10n.dayunFrom(b.dayunStartDate)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        child: _Timeline(items: [for (final c in b.cycles) _Step(c.ganzhi, '${c.startYear}', l10n.age(c.startAge))]),
      ),
      AppCard(
        title: l10n.liunian,
        icon: Icons.calendar_view_month,
        child: _Timeline(
          items: [
            for (final y in b.liunian)
              _Step(
                y.ganzhi,
                '${y.year} · ${l10n.age(y.age)}',
                '${t(y.shishenGan)} / ${t(y.shishenZhi)}',
                y.relations.map((r) => '${l10n.pillar(r.pillar)}${t(r.type)}').join(' '),
              ),
          ],
        ),
      ),
      ReportRequest(chartId: chart.chartId, system: 'bazi', title: title),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: Space.page,
        children: [for (var i = 0; i < sections.length; i++) FadeSlideIn(index: i, child: sections[i])],
      ),
    );
  }
}

class _KV extends StatelessWidget {
  const _KV(this.k, this.v);
  final String k;
  final String v;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.xs),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              child: Text(k, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
            Expanded(child: Text(v, style: Theme.of(context).textTheme.bodyLarge)),
          ],
        ),
      );
}

class _PillarGrid extends StatelessWidget {
  const _PillarGrid({required this.chart, required this.t});
  final BaziChart chart;
  final String Function(String) t;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = [for (final k in BaziChart.pillarOrder) chart.pillars[k]!];
    final small = Theme.of(context).textTheme.bodySmall;
    final scheme = Theme.of(context).colorScheme;
    TableRow row(String label, Widget Function(Pillar) cell, {bool shaded = false}) => TableRow(
          decoration: shaded ? BoxDecoration(color: scheme.surfaceContainerHighest.withValues(alpha: 0.5)) : null,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.s - 2, horizontal: Space.xs),
              child: Text(label, style: small),
            ),
            for (final x in p)
              Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: Space.s - 2), child: cell(x))),
          ],
        );
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.field),
      child: Table(
        columnWidths: const {0: IntrinsicColumnWidth()},
        children: [
          row('', (x) => Text(l10n.pillar(BaziChart.pillarOrder[p.indexOf(x)]), style: small), shaded: true),
          row(l10n.rowTenGod, (x) => Text(t(x.shishenGan))),
          row(l10n.rowStem, (x) => GanZhiText(x.gan, size: 30)),
          row(l10n.rowBranch, (x) => GanZhiText(x.zhi, size: 30)),
          row(l10n.rowHidden, (x) => GanZhiText(x.hiddenGan.join(), size: 14), shaded: true),
          row(l10n.rowTenGod, (x) => Text(x.shishenZhi.map(t).join(' '), style: small, textAlign: TextAlign.center), shaded: true),
          row(l10n.rowLifeStage, (x) => Text(t(x.dishi))),
          row(l10n.rowNayin, (x) => Text(t(x.nayin), style: small)),
        ],
      ),
    );
  }
}

class _WuxingBar extends StatelessWidget {
  const _WuxingBar(this.element, this.score, this.label);
  final String element;
  final double score;
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.xs),
        child: Row(
          children: [
            SizedBox(width: 56, child: Text(label, style: TextStyle(color: wuxingColor(element), fontWeight: FontWeight.w600))),
            Expanded(
              // Bars grow in on first paint.
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: (score / 4).clamp(0, 1).toDouble()),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (_, v, _) => LinearProgressIndicator(
                  value: v,
                  color: wuxingColor(element),
                  backgroundColor: wuxingColor(element).withValues(alpha: 0.12),
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
            SizedBox(width: 44, child: Text(score.toStringAsFixed(1), textAlign: TextAlign.end)),
          ],
        ),
      );
}

class _Step {
  const _Step(this.ganzhi, this.line1, [this.line2 = '', this.line3 = '']);
  final String ganzhi;
  final String line1;
  final String line2;
  final String line3;
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.items});
  final List<_Step> items;

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.bodySmall;
    final scheme = Theme.of(context).colorScheme;
    Widget line(String s) =>
        Text(s, style: small, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis);
    return SizedBox(
      // Room for 干支 + three caption lines (流年: year·age, 十神, 沖合).
      height: 144,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: Space.s),
        itemBuilder: (_, i) {
          final s = items[i];
          return Container(
            width: 96,
            padding: const EdgeInsets.symmetric(horizontal: Space.s, vertical: Space.m),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(Radii.field),
            ),
            child: Column(
              children: [
                GanZhiText(s.ganzhi, size: 22),
                const SizedBox(height: Space.xs),
                line(s.line1),
                if (s.line2.isNotEmpty) line(s.line2),
                if (s.line3.isNotEmpty) line(s.line3),
              ],
            ),
          );
        },
      ),
    );
  }
}
