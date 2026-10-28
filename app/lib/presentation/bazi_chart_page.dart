import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/providers.dart';
import '../domain/models.dart';
import '../domain/profile.dart';
import '../l10n/gen/app_localizations.dart';
import 'design.dart';
import 'keyboard.dart';
import 'labels.dart';
import 'theme.dart';
import 'life_report_page.dart';
import 'widgets/report_request.dart';
import 'widgets/term_tip.dart';

/// 四柱 · 農曆對照 · 五行 · 大運 · 流年, then the AI reading request.
class BaziChartPage extends ConsumerWidget {
  const BaziChartPage({super.key, required this.chart, this.personName = '', this.profile});
  final ChartResult chart;
  final String personName;

  /// The profile the chart was computed for: its life context goes with the reading.
  final BirthProfile? profile;

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
        trailing: TermTipButton('五行', t('五行')),
        child: Column(
          children: [
            for (final e in b.wuxingWeighted.entries) _WuxingBar(e.key, e.value, t(e.key)),
            // 日主旺衰 + 喜用 by the engine's simplified 扶抑法 (charts since v2.0.0).
            if (b.strength case final s?) ...[
              const SizedBox(height: Space.s),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  key: const Key('strength'),
                  spacing: Space.s,
                  runSpacing: Space.s,
                  children: [
                    TermTip(s.verdict, t(s.verdict), pill: true),
                    TermTip('得令', s.deLing ? t('得令') : l10n.notDeLing, pill: true),
                    if (s.special != null)
                      TermTip(s.special!, '${t(s.special!)} · ${l10n.specialNote}', title: t(s.special!), pill: true)
                    else if (s.favorable.isNotEmpty) ...[
                      // One tip explains both 喜用 and 忌.
                      TermTip('喜用', l10n.favorableIs(s.favorable.map(t).join('、')), pill: true),
                      TermTip('喜用', l10n.unfavorableIs(s.unfavorable.map(t).join('、')), pill: true),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      // 神煞 with the pillars that hold them, 空亡 and 胎元 (charts since v1.3.0).
      if (b.kongwang != null)
        AppCard(
          key: const Key('shensha-card'),
          title: l10n.shenshaTitle,
          icon: Icons.auto_awesome_outlined,
          trailing: TermTipButton('神煞', l10n.shenshaName),
          child: Wrap(
            spacing: Space.s,
            runSpacing: Space.s,
            children: [
              for (final s in b.shensha)
                TermTip(s.name, '${t(s.name)} · ${s.pillars.map(l10n.pillar).join('、')}', title: t(s.name), pill: true),
              TermTip(
                '空亡',
                '${t('空亡')} ${b.kongwang}${b.kongwangPillars.isEmpty ? '' : ' · ${b.kongwangPillars.map(l10n.pillar).join('、')}'}',
                title: t('空亡'),
                pill: true,
              ),
              if (b.taiyuan != null) TermTip('胎元', '${t('胎元')} ${b.taiyuan}', title: t('胎元'), pill: true),
            ],
          ),
        ),
      if (b.relations.isNotEmpty)
        AppCard(
          key: const Key('relations-card'),
          title: l10n.relationsTitle,
          icon: Icons.compare_arrows,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final r in b.relations)
                _KV(
                  t(r.type),
                  '${r.members.map((m) => '${l10n.pillar(m.$1)}${m.$2}').join(' · ')}'
                      '${r.element == null ? '' : '（${t(r.element!)}）'}',
                  tip: r.type,
                ),
            ],
          ),
        ),
      AppCard(
        title: l10n.dayun,
        icon: Icons.timeline,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${t(b.dayunForward ? '顺行' : '逆行')} · ${l10n.dayunFrom(b.dayunStartDate)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            TermTipButton('大运', l10n.dayun),
          ],
        ),
        child: _Timeline(
          key: const Key('dayun-strip'),
          label: l10n.dayun,
          items: [for (final c in b.cycles) _Step(c.ganzhi, '${c.startYear}', l10n.age(c.xusui))],
        ),
      ),
      AppCard(
        title: l10n.liunian,
        icon: Icons.calendar_view_month,
        trailing: TermTipButton('流年', l10n.liunian),
        child: _Timeline(
          key: const Key('liunian-strip'),
          label: l10n.liunian,
          items: [
            for (final y in b.liunian)
              _Step(
                y.ganzhi,
                '${y.year} · ${l10n.age(y.xusui)}',
                '${t(y.shishenGan)} / ${t(y.shishenZhi)}',
                y.relations.map((r) => '${l10n.pillar(r.pillar)}${t(r.type)}').join(' '),
              ),
          ],
        ),
      ),
      ReportRequest(
        chartId: chart.chartId,
        system: 'bazi',
        title: title,
        place: profile?.birthPlace.label(ref.watch(settingsProvider).apiLocaleCode),
        context: profile?.life.toApi(
          name: profile!.name,
          locale: ref.watch(settingsProvider).apiLocaleCode,
          birthplace: profile!.birthPlace.label(ref.watch(settingsProvider).apiLocaleCode),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(top: Space.m),
        child: Center(child: LifeReportButton(chart: chart, profile: profile)),
      ),
    ];

    // Only readings are kept in 历史记录: leaving drops the chart, so ask first.
    return LeaveGuard(
      active: true,
      message: l10n.leaveChartBody,
      child: Scaffold(
        appBar: AppBar(title: Text(title)),
        body: ListView(
          padding: Space.page,
          children: [for (var i = 0; i < sections.length; i++) FadeSlideIn(index: i, child: sections[i])],
        ),
      ),
    );
  }
}

class _KV extends StatelessWidget {
  const _KV(this.k, this.v, {this.tip});
  final String k;
  final String v;

  /// The term [k] names, when tapping it explains it (a relation type).
  final String? tip;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.xs),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: tip == null
                ? Text(k, style: style)
                : Align(alignment: Alignment.centerLeft, child: TermTip(tip!, k, style: style)),
          ),
          Expanded(child: Text(v, style: Theme.of(context).textTheme.bodyLarge)),
        ],
      ),
    );
  }
}

/// The four pillars: 十神, 天干 and 地支 always; 藏干, its 十神, 长生 and 纳音 under 更多 (v3.1.0),
/// so the first look is the chart itself.
class _PillarGrid extends StatefulWidget {
  const _PillarGrid({required this.chart, required this.t});
  final BaziChart chart;
  final String Function(String) t;

  @override
  State<_PillarGrid> createState() => _PillarGridState();
}

class _PillarGridState extends State<_PillarGrid> {
  bool _more = false;

  @override
  Widget build(BuildContext context) {
    final chart = widget.chart;
    final t = widget.t;
    final l10n = AppLocalizations.of(context);
    final p = [for (final k in BaziChart.pillarOrder) chart.pillars[k]!];
    final small = Theme.of(context).textTheme.bodySmall;
    final scheme = Theme.of(context).colorScheme;
    // [tip]: the term the row label names, so tapping the label explains the row.
    TableRow row(String label, Widget Function(Pillar) cell, {String? tip, bool shaded = false}) => TableRow(
          decoration: shaded ? BoxDecoration(color: scheme.surfaceContainerHighest.withValues(alpha: 0.5)) : null,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.s - 2, horizontal: Space.xs),
              child: tip == null ? Text(label, style: small) : TermTip(tip, label, style: small),
            ),
            for (final x in p)
              Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: Space.s - 2), child: cell(x))),
          ],
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(Radii.field),
          child: Table(
            key: const Key('pillar-grid'),
            columnWidths: const {0: IntrinsicColumnWidth()},
            children: [
              row('', (x) => Text(l10n.pillar(BaziChart.pillarOrder[p.indexOf(x)]), style: small), shaded: true),
              // Each 十神 and 长生 opens its tip (v3.2.0); the day pillar's own cell is 日主.
              row(l10n.rowTenGod, (x) => TermTip(x.shishenGan, t(x.shishenGan), textAlign: TextAlign.center), tip: '十神'),
              row(l10n.rowStem, (x) => GanZhiText(x.gan, size: 30), tip: '天干'),
              row(l10n.rowBranch, (x) => GanZhiText(x.zhi, size: 30), tip: '地支'),
              // Coloured 藏干 lie on the card itself, not a shaded row: small text keeps its contrast.
              if (_more) ...[
                row(l10n.rowHidden, (x) => GanZhiText(x.hiddenGan.join(), size: 14), tip: '藏干'),
                row(
                  l10n.rowTenGod,
                  (x) => Wrap(
                    alignment: WrapAlignment.center,
                    spacing: Space.xs,
                    children: [for (final s in x.shishenZhi) TermTip(s, t(s), style: small, textAlign: TextAlign.center)],
                  ),
                  tip: '十神',
                ),
                row(l10n.rowLifeStage, (x) => TermTip(x.dishi, t(x.dishi), textAlign: TextAlign.center), tip: '十二长生'),
                row(l10n.rowNayin, (x) => Text(t(x.nayin), style: small), tip: '纳音'),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: Space.s),
          child: Text(l10n.termTipHint, style: small?.copyWith(color: scheme.onSurfaceVariant)),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            key: const Key('pillar-more'),
            onPressed: () => setState(() => _more = !_more),
            icon: Icon(_more ? Icons.expand_less : Icons.expand_more),
            label: Text(_more ? l10n.pillarLess : l10n.pillarMore),
          ),
        ),
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
        padding: const EdgeInsets.symmetric(vertical: Space.xs),
        child: Row(
          children: [
            SizedBox(width: 56, child: Text(label, style: TextStyle(color: wuxingColorOf(context, element), fontWeight: FontWeight.w600))),
            Expanded(
              // Bars grow in on first paint.
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: (score / 4).clamp(0, 1).toDouble()),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (_, v, _) => LinearProgressIndicator(
                  value: v,
                  color: wuxingColorOf(context, element),
                  backgroundColor: wuxingColorOf(context, element).withValues(alpha: 0.12),
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

class _Timeline extends StatefulWidget {
  const _Timeline({super.key, required this.items, required this.label});
  final List<_Step> items;

  /// What a screen reader calls the strip (大运 / 流年).
  final String label;

  @override
  State<_Timeline> createState() => _TimelineState();
}

class _TimelineState extends State<_Timeline> {
  final _scroll = ScrollController();

  /// One item and its gap.
  static const _step = 96.0 + Space.s;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _go(double Function(ScrollPosition p) to) {
    final p = _scroll.position;
    _scroll.animateTo(
      to(p).clamp(p.minScrollExtent, p.maxScrollExtent),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final small = Theme.of(context).textTheme.bodySmall;
    final scheme = Theme.of(context).colorScheme;
    Widget line(String s) =>
        Text(s, style: small, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis);
    // Keyboard users can't swipe: Tab focuses the strip, ←/→ step, Home/End jump.
    return Pressable(
      label: widget.label,
      keys: {
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => _go((p) => p.pixels + _step),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _go((p) => p.pixels - _step),
        const SingleActivator(LogicalKeyboardKey.home): () => _go((p) => p.minScrollExtent),
        const SingleActivator(LogicalKeyboardKey.end): () => _go((p) => p.maxScrollExtent),
      },
      child: SizedBox(
        // Room for 干支 + three caption lines (流年: year·age, 十神, 沖合).
        height: 144,
        child: ListView.separated(
          controller: _scroll,
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
      ),
    );
  }
}
