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
    // For the table cells and the strips: English without its pinyin (v4.0.0).
    String brief(String k) => terms?.short(k, locale) ?? k;
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
        child: _PillarGrid(chart: b, t: t, brief: brief),
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
                // The narrow label column takes the brief form; the tip keeps the full name (v4.0.0).
                _KV(
                  brief(r.type),
                  '${r.members.map((m) => '${l10n.pillar(m.$1)}${m.$2}').join(' · ')}'
                      '${r.element == null ? '' : '（${t(r.element!)}）'}',
                  tip: r.type,
                  tipTitle: t(r.type),
                ),
            ],
          ),
        ),
      _DayunCard(chart: b, t: t, brief: brief),
      AppCard(
        title: l10n.liunian,
        icon: Icons.calendar_view_month,
        trailing: TermTipButton('流年', l10n.liunian),
        child: _Timeline(
          key: const Key('liunian-strip'),
          label: l10n.liunian,
          items: [for (final y in b.liunian) _yearStep(y, brief, l10n, b.thisYear, english: locale == 'en')],
        ),
      ),
      // 流月 of the chart's year, from 立春 (facts since v1.3.0, shown since v3.3.0).
      if (b.liuyue.isNotEmpty)
        AppCard(
          key: const Key('liuyue-card'),
          title: l10n.liuyueOf(b.liuyueYear!),
          icon: Icons.date_range,
          trailing: TermTipButton('流月', t('流月')),
          child: _Timeline(
            key: const Key('liuyue-strip'),
            label: t('流月'),
            items: [
              for (final m in b.liuyue)
                // When it begins (the date, 北京时间), the 节 it begins on, its 十神; English gives
                // each 十神 its own line.
                _Step(m.ganzhi, [
                  m.starts.substring(0, 10),
                  brief(m.jie),
                  ...locale == 'en'
                      ? [brief(m.shishenGan), brief(m.shishenZhi)]
                      : ['${t(m.shishenGan)} / ${t(m.shishenZhi)}'],
                ]),
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
  const _KV(this.k, this.v, {this.tip, this.tipTitle});
  final String k;
  final String v;

  /// The term [k] names, when tapping it explains it (a relation type).
  final String? tip;

  /// The tip's title, when [k] is a brief form.
  final String? tipTitle;

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
                : Align(alignment: Alignment.centerLeft, child: TermTip(tip!, k, title: tipTitle, style: style)),
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
  const _PillarGrid({required this.chart, required this.t, required this.brief});
  final BaziChart chart;
  final String Function(String) t;

  /// The cells' form of a term (English without its pinyin); [t] titles its tip.
  final String Function(String) brief;

  @override
  State<_PillarGrid> createState() => _PillarGridState();
}

class _PillarGridState extends State<_PillarGrid> {
  bool _more = false;

  @override
  Widget build(BuildContext context) {
    final chart = widget.chart;
    final t = widget.t;
    // A cell's term: the brief form, the full one as its tip's title, one word never broken.
    Widget term(String k, {TextStyle? style}) =>
        TermTip(k, widget.brief(k), title: t(k), style: style, textAlign: TextAlign.center, shrinkOneWord: true);
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
              row(l10n.rowTenGod, (x) => term(x.shishenGan), tip: '十神'),
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
                    children: [for (final s in x.shishenZhi) term(s, style: small)],
                  ),
                  tip: '十神',
                ),
                row(l10n.rowLifeStage, (x) => term(x.dishi), tip: '十二长生'),
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

/// 大运: the one running now is marked 当前; tapping one opens its ten years under the strip
/// (v3.3.0).
class _DayunCard extends StatefulWidget {
  const _DayunCard({required this.chart, required this.t, required this.brief});
  final BaziChart chart;
  final String Function(String) t;

  /// The strips' form of a term (English without its pinyin).
  final String Function(String) brief;

  @override
  State<_DayunCard> createState() => _DayunCardState();
}

class _DayunCardState extends State<_DayunCard> {
  /// The 大运 whose years are open.
  int? _open;

  @override
  Widget build(BuildContext context) {
    final b = widget.chart;
    final t = widget.t;
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final open = b.cycles.where((c) => c.index == _open).firstOrNull;
    final years = open == null ? const <Liunian>[] : b.yearsOf(open.index);
    return AppCard(
      title: l10n.dayun,
      icon: Icons.timeline,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${t(b.dayunForward ? '顺行' : '逆行')} · ${l10n.dayunFrom(b.dayunStartDate)}',
            style: theme.textTheme.bodySmall,
          ),
          TermTipButton('大运', l10n.dayun),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Timeline(
            key: const Key('dayun-strip'),
            label: l10n.dayun,
            items: [
              for (final c in b.cycles)
                _Step(
                  c.ganzhi,
                  ['${c.startYear}', l10n.age(c.xusui)],
                  badge: c.index == b.currentDayun ? l10n.timelineNow : null,
                  selected: c.index == _open,
                  id: 'dayun-${c.index}',
                  // Charts made before v3.3.0 have no years to open.
                  onTap: b.dayunYears.isEmpty ? null : () => setState(() => _open = _open == c.index ? null : c.index),
                ),
            ],
          ),
          if (open == null && b.dayunYears.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: Space.s),
              child: Text(
                l10n.dayunTapHint,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          if (open != null && years.isNotEmpty) ...[
            const SizedBox(height: Space.m),
            Text(l10n.dayunYears(open.ganzhi, open.startYear, open.startYear + 9), style: theme.textTheme.titleSmall),
            const SizedBox(height: Space.s),
            // Keyed by the 大运, so switching to another starts its strip at its first year.
            _Timeline(
              key: ValueKey('decade-${open.index}'),
              label: l10n.dayunYears(open.ganzhi, open.startYear, open.startYear + 9),
              items: [
                for (final y in years)
                  _yearStep(y, widget.brief, l10n, b.thisYear, english: Localizations.localeOf(context).languageCode == 'en'),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// A 流年 in a strip: 干支, year and 虚岁, its 十神, its 六冲 / 六合 with the chart; 今年 marked.
/// English gives the year, the 虚岁 and each 十神 a line of their own, so none is cut off (v4.0.0).
_Step _yearStep(Liunian y, String Function(String) brief, AppLocalizations l10n, int? thisYear, {required bool english}) {
  // 時柱六合, or Hour Six Harmonies (English read YearSix Clashes before v3.3.0).
  final relations = y.relations.map((r) => l10n.pillarRelation(l10n.pillar(r.pillar), brief(r.type))).join(' ');
  return _Step(
    y.ganzhi,
    [
      ...english
          ? ['${y.year}', l10n.age(y.xusui), brief(y.shishenGan), brief(y.shishenZhi)]
          : ['${y.year} · ${l10n.age(y.xusui)}', '${brief(y.shishenGan)} / ${brief(y.shishenZhi)}'],
      if (relations.isNotEmpty) relations,
    ],
    badge: y.year == thisYear ? l10n.timelineThisYear : null,
  );
}

class _Step {
  const _Step(
    this.ganzhi,
    this.lines, {
    this.badge,
    this.id,
    this.onTap,
    this.selected = false,
  });
  final String ganzhi;

  /// The caption lines under the 干支, at most five (the strip is sized for them).
  final List<String> lines;

  /// A label on the top edge: 当前 (the 大运 running now) or 今年.
  final String? badge;

  /// The key of an item that can be pressed, e.g. dayun-3.
  final String? id;
  final VoidCallback? onTap;

  /// Its details are open below the strip: a primary border.
  final bool selected;
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
    final theme = Theme.of(context);
    final small = theme.textTheme.bodySmall;
    final scheme = theme.colorScheme;
    // Room above the items for a badge on their top edge.
    final top = items.any((s) => s.badge != null) ? 10.0 : 0.0;
    // English words are longer: wider items, so 「nominal age 37」 and 「Indirect Resource」 fit (v4.0.0).
    final width = Localizations.localeOf(context).languageCode == 'en' ? 128.0 : 96.0;
    // One item and its gap: what ←/→ move.
    final step = width + Space.s;
    Widget line(String s) =>
        Text(s, style: small, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis);
    Widget item(_Step s) {
      Widget box = Container(
        width: width,
        // The 2 px border comes out of the padding, so the text keeps its 80 px (2026 · 虛歲 37).
        padding: const EdgeInsets.symmetric(horizontal: Space.s - 2, vertical: Space.m - 2),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(Radii.field),
          // Every item has the border, so opening one doesn't move its text.
          border: Border.all(color: s.selected ? scheme.primary : Colors.transparent, width: 2),
        ),
        child: Column(
          children: [
            GanZhiText(s.ganzhi, size: 22),
            const SizedBox(height: Space.xs),
            for (final text in s.lines)
              if (text.isNotEmpty) line(text),
          ],
        ),
      );
      // ValueKey<String>, not ValueKey<String?>: tests and focusedKey() look for string keys.
      if (s.onTap != null) box = Pressable(key: ValueKey<String>(s.id!), onPressed: s.onTap, child: box);
      if (s.badge == null) return box;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          box,
          Positioned(
            top: -8,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: Space.s - 2, vertical: 1),
                decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(Radii.chip)),
                child: Text(s.badge!, style: theme.textTheme.labelSmall?.copyWith(color: scheme.onPrimary)),
              ),
            ),
          ),
        ],
      );
    }

    // Keyboard users can't swipe: Tab focuses the strip, ←/→ step, Home/End jump; Tab goes on to
    // the items that open (大运).
    return Pressable(
      label: widget.label,
      keys: {
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => _go((p) => p.pixels + step),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _go((p) => p.pixels - step),
        const SingleActivator(LogicalKeyboardKey.home): () => _go((p) => p.minScrollExtent),
        const SingleActivator(LogicalKeyboardKey.end): () => _go((p) => p.maxScrollExtent),
      },
      child: SizedBox(
        // Room for 干支 + up to five caption lines (English 流年: year, age, two 十神, 沖合), and a badge.
        height: 144 + top,
        child: ListView.separated(
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.only(top: top),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(width: Space.s),
          itemBuilder: (_, i) => item(items[i]),
        ),
      ),
    );
  }
}
