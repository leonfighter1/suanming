import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/providers.dart';
import '../domain/models.dart';
import '../l10n/gen/app_localizations.dart';
import 'labels.dart';
import 'theme.dart';
import 'widgets/report_request.dart';

/// 四柱卡片 · 五行 · 大運時間軸 · 流年, then the AI reading request.
class BaziChartPage extends ConsumerWidget {
  const BaziChartPage({super.key, required this.chart});
  final ChartResult chart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(settingsProvider).apiLocaleCode;
    final terms = ref.watch(termsProvider).value;
    final b = chart.bazi;
    String t(String k) => terms?.t(k, locale) ?? k;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.homeBazi)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.fourPillars, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _PillarGrid(chart: b, t: t),
                  const SizedBox(height: 8),
                  Text('${l10n.dayMaster}：${b.dayMasterGan}${t(b.dayMasterWuxing)}（${t(b.dayMasterYinYang)}）'),
                ],
              ),
            ),
          ),
          _Section(
            title: l10n.wuxingWeighted,
            child: Column(children: [for (final e in b.wuxingWeighted.entries) _WuxingBar(e.key, e.value, t(e.key))]),
          ),
          _Section(
            title: '${l10n.dayun} · ${t(b.dayunForward ? '顺行' : '逆行')} · ${l10n.dayunFrom(b.dayunStartDate)}',
            child: _Timeline(
              items: [
                for (final c in b.cycles)
                  _Step(c.ganzhi, '${c.startYear}', l10n.age(c.startAge)),
              ],
            ),
          ),
          _Section(
            title: l10n.liunian,
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
          ReportRequest(chartId: chart.chartId, system: 'bazi'),
        ],
      ),
    );
  }
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
    TableRow row(String label, Widget Function(Pillar) cell) => TableRow(
          children: [
            Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(label, style: small)),
            for (final x in p) Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: cell(x))),
          ],
        );
    return Table(
      columnWidths: const {0: IntrinsicColumnWidth()},
      children: [
        row('', (x) => Text(l10n.pillar(BaziChart.pillarOrder[p.indexOf(x)]), style: small)),
        row(l10n.rowTenGod, (x) => Text(t(x.shishenGan))),
        row(l10n.rowStem, (x) => GanZhiText(x.gan, size: 28)),
        row(l10n.rowBranch, (x) => GanZhiText(x.zhi, size: 28)),
        row(l10n.rowHidden, (x) => GanZhiText(x.hiddenGan.join(), size: 14)),
        row(l10n.rowTenGod, (x) => Text(x.shishenZhi.map(t).join(' '), style: small, textAlign: TextAlign.center)),
        row(l10n.rowLifeStage, (x) => Text(t(x.dishi))),
        row(l10n.rowNayin, (x) => Text(t(x.nayin), style: small)),
      ],
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
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(width: 48, child: Text(label, style: TextStyle(color: wuxingColor(element)))),
            Expanded(
              child: LinearProgressIndicator(
                value: (score / 4).clamp(0, 1).toDouble(),
                color: wuxingColor(element),
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            SizedBox(width: 40, child: Text(score.toStringAsFixed(1), textAlign: TextAlign.end)),
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
    Widget line(String s) => Text(s, style: small, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis);
    return SizedBox(
      // Room for 干支 + three caption lines (流年: year·age, 十神, 沖合).
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final s = items[i];
          return Container(
            width: 92,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                GanZhiText(s.ganzhi, size: 20),
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

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              child,
            ],
          ),
        ),
      );
}
