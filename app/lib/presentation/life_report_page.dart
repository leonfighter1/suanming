import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../application/providers.dart';
import '../domain/life_report.dart';
import '../domain/models.dart';
import '../domain/profile.dart';
import '../l10n/gen/app_localizations.dart';
import '../platform/printer.dart';
import 'design.dart';
import 'life_export.dart';
import 'widgets/remedy.dart' show compactButtons;
import 'widgets/trend_chart.dart' show seriesColor;

/// 一生运势报告: polls until ready, then shows the six sections and offers the
/// download package (HTML + Markdown in a ZIP), print / PDF and copy.
class LifeReportPage extends ConsumerWidget {
  const LifeReportPage({super.key, required this.reportId, this.profile, this.chart});
  final String reportId;

  /// For the header (name, birthplace). Optional when opened from history.
  final BirthProfile? profile;
  final ChartResult? chart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(lifeReportProvider(reportId));
    final view = async.value;
    final chart = this.chart ?? (view == null ? null : ref.watch(chartProvider(view.chartId)).value);
    final locale = ref.watch(settingsProvider).apiLocaleCode;
    final hant = locale == 'zh-Hant';
    final names = ref.watch(profilesProvider).value?.chartLabels ?? const {};
    final places = ref.watch(profilesProvider).value?.chartPlaces ?? const {};
    final ready = view != null && view.status == 'passed' && view.layers != null && chart != null;
    final header = ready ? _header(l10n, view, chart, names[view.chartId], places[view.chartId], hant, locale) : null;

    Future<(String, String)> build() async {
      final lunar = chart!.bazi.lunar;
      final html = lifeReportHtml(
        l10n: l10n,
        header: header!,
        report: view!,
        hant: hant,
        lunarMonth: lunar.monthName,
        lunarDay: lunar.dayName,
      );
      final md = lifeReportMarkdown(
        l10n: l10n,
        header: header,
        report: view,
        hant: hant,
        lunarMonth: lunar.monthName,
        lunarDay: lunar.dayName,
      );
      return (html, md);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(header == null ? l10n.lifeEntry : l10n.lifeReportOf(header.name)),
        actions: [
          if (ready) ...[
            IconButton(
              key: const Key('life-download'),
              tooltip: l10n.lifeDownload,
              icon: const Icon(Icons.download_outlined),
              onPressed: () async {
                final (html, md) = await build();
                final name = '${header!.name.isEmpty ? 'mingli' : header.name}-${l10n.lifeEntry}.zip';
                await SharePlus.instance.share(
                  ShareParams(
                    files: [
                      XFile.fromData(
                        lifeReportZip(html: html, markdown: md),
                        mimeType: 'application/zip',
                        name: name,
                      ),
                    ],
                    fileNameOverrides: [name],
                    subject: l10n.lifeReportOf(header.name),
                  ),
                );
              },
            ),
            IconButton(
              key: const Key('life-print'),
              tooltip: l10n.lifePrint,
              icon: const Icon(Icons.print_outlined),
              onPressed: () async {
                final (html, md) = await build();
                if (!await printHtml(html)) await SharePlus.instance.share(ShareParams(text: md, subject: l10n.lifeReportOf(header!.name)));
              },
            ),
            IconButton(
              key: const Key('life-copy'),
              tooltip: l10n.copyAll,
              icon: const Icon(Icons.copy_all_outlined),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final (_, md) = await build();
                await Clipboard.setData(ClipboardData(text: md));
                messenger.showSnackBar(SnackBar(content: Text(l10n.copied)));
              },
            ),
          ],
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: switch (view) {
          null when async.hasError => _Message(text: '${l10n.errorTitle}\n${async.error}'),
          null => const _Pending(stage: null),
          LifeReportView(status: 'pending') => _Pending(stage: view.progressStage),
          LifeReportView(status: 'passed') when ready => _Body(
            key: const ValueKey('life-body'),
            view: view,
            header: header!,
            chart: chart,
            hant: hant,
          ),
          LifeReportView(status: 'passed') => const Center(child: CircularProgressIndicator()),
          LifeReportView(status: 'failed') => _Message(text: l10n.statusFailed),
          _ => _Message(text: l10n.statusReview),
        },
      ),
    );
  }

  LifeHeader _header(AppLocalizations l10n, LifeReportView v, ChartResult chart, String? label, String? place, bool hant, String locale) {
    final b = chart.bazi;
    final f = v.facts!;
    final hour = b.pillars['hour']!.zhi;
    final shi = hant ? '時' : '时';
    final civil = DateTime.parse(b.civilLocal);
    final clock = f.pillarClock.substring(11, 16);
    final range = _shichenRange(hour);
    final gender = (chart.facts['dayun'] as Json)['gender'] == 'male' ? l10n.male : l10n.female;
    String two(int n) => n.toString().padLeft(2, '0');
    return LifeHeader(
      name: profile?.name ?? label ?? '',
      gender: gender,
      lunar:
          '${b.lunar.year} 年 ${b.lunar.yearGanzhi}年 ${b.lunar.isLeapMonth ? (hant ? '閏' : '闰') : ''}${b.lunar.monthName}${b.lunar.dayName} $hour$shi（${hant ? '約' : '约'} ${two(civil.hour)}:${two(civil.minute)}）',
      solar: '${civil.year} 年 ${civil.month} 月 ${civil.day} 日',
      place: profile?.birthPlace.label(locale) ?? place ?? '—',
      trueSolar: f.trueSolar ? '${hant ? '約' : '约'} $clock，${hant ? '屬' : '属'}$hour$shi（$range）' : '—',
      ganzhi: [
        '${b.pillars['year']!.ganzhi}年',
        '${b.pillars['month']!.ganzhi}月',
        '${b.pillars['day']!.ganzhi}日',
        '${b.pillars['hour']!.ganzhi}$shi',
      ].join('　'),
    );
  }

  static String _shichenRange(String zhi) {
    const order = '子丑寅卯辰巳午未申酉戌亥';
    final i = order.indexOf(zhi);
    final start = (i * 2 + 23) % 24;
    String h(int x) => '${x % 24}:00';
    return '${h(start)}–${h(start + 2)}';
  }
}

class _Pending extends StatefulWidget {
  const _Pending({required this.stage});
  final String? stage;
  @override
  State<_Pending> createState() => _PendingState();
}

class _PendingState extends State<_Pending> {
  final _opened = DateTime.now();
  late final Timer _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));

  @override
  void initState() {
    super.initState();
    _tick;
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final secs = DateTime.now().difference(_opened).inSeconds;
    final steps = [('life_methods', l10n.lifeStageMethods), ('life_topics', l10n.lifeStageTopics), ('guard', l10n.stageGuard)];
    // The two writers run in parallel: both show as active until the guard starts.
    final guard = widget.stage == 'guard';
    return ListView(
      key: const Key('life-pending'),
      padding: Space.page,
      children: [
        const SizedBox(height: Space.xxl),
        Icon(Icons.auto_stories, size: 64, color: scheme.primary),
        const SizedBox(height: Space.l),
        Text(l10n.lifeGenerating, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: Space.s),
        Text(l10n.elapsed('${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}'), textAlign: TextAlign.center),
        const SizedBox(height: Space.xl),
        AppCard(
          child: Column(
            children: [
              for (final (key, label) in steps)
                ListTile(
                  leading: (key == 'guard' ? guard : !guard)
                      ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(key == 'guard' ? Icons.circle_outlined : Icons.check_circle, color: scheme.primary),
                  title: Text(label),
                ),
            ],
          ),
        ),
        const SizedBox(height: Space.l),
        Text(l10n.lifeTook, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(Space.xxl),
      child: Text(text, textAlign: TextAlign.center),
    ),
  );
}

// ---------- the report ----------

class _Body extends StatelessWidget {
  const _Body({super.key, required this.view, required this.header, required this.chart, required this.hant});
  final LifeReportView view;
  final LifeHeader header;
  final ChartResult chart;
  final bool hant;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final f = view.facts!;
    final l = view.layers!;
    final body = theme.textTheme.bodyLarge?.copyWith(height: 1.8);
    final lunar = chart.bazi.lunar;
    var i = 0;
    Widget fade(Widget w) => FadeSlideIn(index: i++, child: w);

    return ListView(
      padding: Space.page,
      children: [
        fade(_Hero(title: l10n.lifeReportOf(header.name), subtitle: l10n.lifeSubtitle)),
        fade(AppCard(child: _KeyValues(rows: header.rows(l10n)))),
        fade(_Note(text: l10n.lifeNote)),
        // 一、易经本命卦
        fade(
          _Section(
            key: const Key('life-sec-yijing'),
            title: l10n.lifeSec1,
            children: [
              _Sub(l10n.lifeQigua),
              for (final s in qiguaSteps(f, hant: hant, lunarMonth: lunar.monthName, lunarDay: lunar.dayName)) _Bullet(s),
              const SizedBox(height: Space.l),
              Wrap(
                alignment: WrapAlignment.spaceEvenly,
                spacing: Space.xl,
                runSpacing: Space.l,
                children: [
                  HexagramFigure(hexagram: f.hexagram, caption: l10n.lifeBenGua, moving: f.movingLine),
                  HexagramFigure(hexagram: f.nuclear, caption: l10n.lifeHuGua),
                  HexagramFigure(hexagram: f.changed, caption: l10n.lifeZhiGuaShort),
                ],
              ),
              _Sub(l10n.lifeGuaYi),
              _Quote(f.hexagram.guaCi),
              Text(l.yijingText('meaning'), style: body),
              _Sub(l10n.lifeMingYao),
              _Quote(f.lines[f.movingLine - 1].text),
              Text(l.yijingText('ming_yao'), style: body),
              _Sub(l10n.lifeZhiGua),
              _Quote(f.changed.guaCi),
              Text(l.yijingText('zhi_gua'), style: body),
              _Sub(l10n.lifeSixLines),
              for (final x in f.lines.reversed.toList().reversed)
                _LineRow(line: x, reading: l.stageReading(x.line), mingYao: l10n.lifeMingYao, ageLabel: l10n.lifeAge),
            ],
          ),
        ),
        // 二、梅花易数
        fade(
          _Section(
            key: const Key('life-sec-meihua'),
            title: l10n.lifeSec2,
            children: [
              _MeihuaTable(facts: f),
              const SizedBox(height: Space.m),
              _Labeled(l10n.lifeSeason, l.meihua['season'] as String),
              _Labeled('${l10n.lifeEarly} · ${relationLabel(l10n, f.yong.relation)}', l.meihua['early'] as String),
              _Labeled(l10n.lifeMiddle, l.meihua['middle'] as String),
              _Labeled('${l10n.lifeLate} · ${relationLabel(l10n, f.bian.relation)}', l.meihua['late'] as String),
              _Highlight('${l10n.lifeMhConclusion}：${l.meihua['conclusion']}'),
            ],
          ),
        ),
        // 三、五行八卦
        fade(
          _Section(
            key: const Key('life-sec-wuxing'),
            title: l10n.lifeSec3,
            children: [
              _Sub(l10n.lifeWuxingDist),
              _WuxingBars(scores: chart.bazi.wuxingWeighted),
              const SizedBox(height: Space.m),
              Text(l.wuxing['analysis'] as String, style: body),
              const SizedBox(height: Space.s),
              Wrap(
                spacing: Space.s,
                runSpacing: Space.s,
                children: [
                  for (final x in l.favorable())
                    Pill('${l10n.lifeFavorable} · $x', icon: Icons.add_circle_outline, color: Colors.green.shade700),
                  for (final x in l.unfavorable())
                    Pill('${l10n.lifeUnfavorable} · $x', icon: Icons.remove_circle_outline, color: scheme.error),
                ],
              ),
              const SizedBox(height: Space.xs),
              Text(l.wuxing['note'] as String, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              _Sub(l10n.lifeBazhai),
              Text(
                l10n.lifeKua('${f.kua}', f.trigram(f.kuaTrigram).name, hantTerm(f.kuaGroup, hant), f.kuaWuxing),
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: Space.s),
              Text(l.bazhai['summary'] as String, style: body),
              const SizedBox(height: Space.m),
              BazhaiCompass(facts: f, hant: hant),
              const SizedBox(height: Space.m),
              _Labeled(l10n.lifeDaily, l.bazhai['daily'] as String),
            ],
          ),
        ),
        // 四、分项运势
        fade(
          _Section(
            key: const Key('life-sec-topics'),
            title: l10n.lifeSec4,
            children: [for (final topic in l.topics) _TopicBlock(title: topicLabel(l10n, topic.key), topic: topic)],
          ),
        ),
        // 五、人生阶段总览
        fade(
          _Section(
            key: const Key('life-sec-stages'),
            title: l10n.lifeSec5,
            children: [
              StageChart(stages: l.stages),
              const SizedBox(height: Space.m),
              for (final s in l.stages) _StageRow(stage: s, best: s.score == l.stages.map((x) => x.score).reduce((a, b) => a > b ? a : b)),
            ],
          ),
        ),
        // 六、总评与建议
        fade(
          _Section(
            key: const Key('life-sec-summary'),
            title: l10n.lifeSec6,
            children: [
              Text(l.verdict, style: body),
              const SizedBox(height: Space.m),
              for (final (area, text) in l.advice) _Labeled(area, text),
              _Highlight(l.closing),
            ],
          ),
        ),
        const SizedBox(height: Space.l),
        Text(l.disclaimer, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
        const SizedBox(height: Space.xs),
        Text(l.aiLabel, key: const Key('life-ai-label'), style: theme.textTheme.labelMedium),
      ],
    );
  }
}

// ---------- building blocks ----------

class _Hero extends StatelessWidget {
  const _Hero({required this.title, required this.subtitle});
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: Space.l),
      padding: const EdgeInsets.symmetric(vertical: Space.xl, horizontal: Space.l),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.card),
        gradient: LinearGradient(colors: [scheme.primary, scheme.tertiary], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Column(
        children: [
          Icon(Icons.auto_stories, color: scheme.onPrimary, size: 36),
          const SizedBox(height: Space.s),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(color: scheme.onPrimary, fontWeight: FontWeight.w700, letterSpacing: 2),
          ),
          const SizedBox(height: Space.xs),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onPrimary.withValues(alpha: 0.85), letterSpacing: 1.5),
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: Space.l),
      padding: const EdgeInsets.all(Space.m),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(Radii.field),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: Space.s),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.6))),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({super.key, required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 22,
                decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: Space.s),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(color: scheme.primary, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.s),
          ...children,
        ],
      ),
    );
  }
}

class _Sub extends StatelessWidget {
  const _Sub(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: Space.l, bottom: Space.s),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
  );
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: Space.xs),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 9, right: Space.s),
          child: CircleAvatar(radius: 2.5),
        ),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.7))),
      ],
    ),
  );
}

class _Quote extends StatelessWidget {
  const _Quote(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: Space.s),
      padding: const EdgeInsets.fromLTRB(Space.m, Space.s, Space.m, Space.s),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.35),
        border: Border(left: BorderSide(color: scheme.primary, width: 4)),
      ),
      child: Text(text, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600, height: 1.7)),
    );
  }
}

class _Labeled extends StatelessWidget {
  const _Labeled(this.label, this.text);
  final String label;
  final String text;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.xs + 2),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label：',
              style: TextStyle(fontWeight: FontWeight.w700, color: theme.colorScheme.primary),
            ),
            TextSpan(text: text),
          ],
        ),
        style: theme.textTheme.bodyLarge?.copyWith(height: 1.8),
      ),
    );
  }
}

class _Highlight extends StatelessWidget {
  const _Highlight(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: Space.m),
      padding: const EdgeInsets.all(Space.m),
      decoration: BoxDecoration(color: scheme.tertiaryContainer.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(Radii.field)),
      child: Text(text, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700, height: 1.7)),
    );
  }
}

class _KeyValues extends StatelessWidget {
  const _KeyValues({required this.rows});
  final List<(String, String)> rows;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        for (final (i, (k, v)) in rows.indexed)
          Container(
            color: i.isEven ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35) : null,
            padding: const EdgeInsets.symmetric(vertical: Space.s, horizontal: Space.s),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 96,
                  child: Text(k, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ),
                Expanded(
                  child: Text(v, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Six lines drawn top (上爻) to bottom (初爻); the 命爻 in the accent colour.
class HexagramFigure extends StatelessWidget {
  const HexagramFigure({super.key, required this.hexagram, required this.caption, this.moving});
  final Hexagram hexagram;
  final String caption;
  final int? moving;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      key: Key('hex-${hexagram.id}'),
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 96,
          child: Column(
            children: [
              for (var line = 6; line >= 1; line--)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3.5),
                  child: Row(
                    children: [
                      Expanded(child: _bar(moving == line ? scheme.error : scheme.onSurface)),
                      if (!hexagram.yang(line)) ...[
                        const SizedBox(width: 14),
                        Expanded(child: _bar(moving == line ? scheme.error : scheme.onSurface)),
                      ] else
                        const SizedBox.shrink(),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: Space.s),
        Text(hexagram.fullName, style: Theme.of(context).textTheme.titleSmall),
        Text(caption, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
      ],
    );
  }

  Widget _bar(Color c) => Container(
    height: 11,
    decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2)),
  );
}

class _LineRow extends StatelessWidget {
  const _LineRow({required this.line, required this.reading, required this.mingYao, required this.ageLabel});
  final HexLine line;
  final String reading;
  final String mingYao;
  final String ageLabel;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: Space.s),
      padding: const EdgeInsets.all(Space.m),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.field),
        border: Border.all(color: line.moving ? scheme.error : scheme.outlineVariant, width: line.moving ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(line.position, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(width: Space.s),
              Pill('$ageLabel ${line.ages}', icon: Icons.schedule),
              if (line.moving) ...[const SizedBox(width: Space.s), Pill(mingYao, icon: Icons.star, color: scheme.error)],
            ],
          ),
          const SizedBox(height: Space.s),
          Text(
            line.text.split(RegExp('[：:]')).skip(1).join('：'),
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, height: 1.6),
          ),
          const SizedBox(height: Space.xs),
          Text(reading, style: theme.textTheme.bodyLarge?.copyWith(height: 1.7)),
        ],
      ),
    );
  }
}

class _MeihuaTable extends StatelessWidget {
  const _MeihuaTable({required this.facts});
  final LifeFacts facts;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final f = facts;
    final rows = [
      (l10n.lifeTi, f.trigram(f.ti.trigram), f.ti.wuxing, l10n.lifeSelf, '—'),
      (l10n.lifeYong, f.trigram(f.yong.trigram), f.yong.wuxing, relationLabel(l10n, f.yong.relation), l10n.lifeEarly),
      for (final h in f.hu) (l10n.lifeHu, f.trigram(h.trigram), h.wuxing, relationLabel(l10n, h.relation), l10n.lifeMiddle),
      (l10n.lifeBian, f.trigram(f.bian.trigram), f.bian.wuxing, relationLabel(l10n, f.bian.relation), l10n.lifeLate),
    ];
    return Column(
      children: [
        for (final (role, tri, wx, rel, stage) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.xs),
            child: Row(
              children: [
                SizedBox(
                  width: 72,
                  child: Text(role, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                ),
                CircleAvatar(
                  radius: 18,
                  backgroundColor: _wuxingColor(wx).withValues(alpha: 0.15),
                  child: Text(
                    tri.name,
                    style: TextStyle(color: _wuxingColor(wx), fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: Space.s),
                SizedBox(width: 56, child: Text('${tri.image} · $wx')),
                Expanded(child: Text(rel, style: theme.textTheme.bodyMedium)),
                Text(stage, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
      ],
    );
  }
}

Color _wuxingColor(String wx) => switch (wx) {
  '木' => const Color(0xFF2E7D32),
  '火' => const Color(0xFFC62828),
  '土' => const Color(0xFF8D6E63),
  '金' => const Color(0xFFB8860B),
  _ => const Color(0xFF1565C0),
};

class _WuxingBars extends StatelessWidget {
  const _WuxingBars({required this.scores});
  final Map<String, double> scores;
  @override
  Widget build(BuildContext context) {
    final order = ['木', '火', '土', '金', '水'];
    final max = scores.values.fold<double>(0.01, (a, b) => a > b ? a : b);
    return Column(
      key: const Key('life-wuxing-bars'),
      children: [
        for (final wx in order)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    wx,
                    style: TextStyle(fontWeight: FontWeight.w700, color: _wuxingColor(wx)),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (scores[wx] ?? 0) / max,
                      minHeight: 12,
                      color: _wuxingColor(wx),
                      backgroundColor: _wuxingColor(wx).withValues(alpha: 0.12),
                    ),
                  ),
                ),
                SizedBox(width: 44, child: Text((scores[wx] ?? 0).toStringAsFixed(1), textAlign: TextAlign.end)),
              ],
            ),
          ),
      ],
    );
  }
}

/// 八宅: the eight directions on a 3×3 grid (north at the top), 吉 green, 凶 red.
class BazhaiCompass extends StatelessWidget {
  const BazhaiCompass({super.key, required this.facts, required this.hant});
  final LifeFacts facts;
  final bool hant;

  static const _layout = [
    ['西北', '北', '东北'],
    ['西', '', '东'],
    ['西南', '南', '东南'],
  ];
  static const _hantDir = {'东北': '東北', '东': '東', '东南': '東南'};

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    BazhaiDirection? at(String dir) =>
        facts.directions.where((d) => d.direction == dir || d.direction == (_hantDir[dir] ?? dir)).firstOrNull;
    return Column(
      key: const Key('life-bazhai'),
      children: [
        for (final row in _layout)
          Row(
            children: [
              for (final dir in row)
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 1.25,
                    child: Container(
                      margin: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(Radii.chip),
                        color: dir.isEmpty
                            ? scheme.primaryContainer
                            : (at(dir)!.good ? Colors.green : scheme.error).withValues(alpha: at(dir)!.good ? 0.12 : 0.10),
                      ),
                      child: Center(
                        child: dir.isEmpty
                            ? Text(
                                facts.trigram(facts.kuaTrigram).name,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w800, color: scheme.onPrimaryContainer),
                              )
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(hant ? (_hantDir[dir] ?? dir) : dir, style: Theme.of(context).textTheme.labelMedium),
                                  Text(
                                    hantTerm(at(dir)!.star, hant),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: at(dir)!.good ? Colors.green.shade800 : scheme.error,
                                    ),
                                  ),
                                  Text(at(dir)!.luck, style: Theme.of(context).textTheme.bodySmall),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _TopicBlock extends StatelessWidget {
  const _TopicBlock({required this.title, required this.topic});
  final String title;
  final LifeTopic topic;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      key: Key('life-topic-${topic.key}'),
      padding: const EdgeInsets.only(top: Space.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: Space.xs),
          Text(topic.summary, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700, height: 1.7)),
          for (final (period, text) in topic.points) period.isEmpty ? _Bullet(text) : _Labeled(period, text),
        ],
      ),
    );
  }
}

/// Bars per 大运 (score 0–100); the best period highlighted.
class StageChart extends StatelessWidget {
  const StageChart({super.key, required this.stages});
  final List<LifeStage> stages;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final best = stages.isEmpty ? 0 : stages.map((s) => s.score).reduce((a, b) => a > b ? a : b);
    final color = seriesColor(context, 'overall');
    return SizedBox(
      key: const Key('life-stage-chart'),
      height: 170,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final s in stages)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('${s.score}', style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(height: 2),
                    Container(
                      height: 110 * s.score / 100,
                      decoration: BoxDecoration(
                        color: s.score == best ? scheme.tertiary : color,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(s.ages, style: Theme.of(context).textTheme.labelSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StageRow extends StatelessWidget {
  const _StageRow({required this.stage, required this.best});
  final LifeStage stage;
  final bool best;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: Space.xs),
      padding: const EdgeInsets.symmetric(horizontal: Space.m, vertical: Space.s),
      decoration: BoxDecoration(
        color: best ? scheme.tertiaryContainer.withValues(alpha: 0.6) : scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(Radii.field),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(stage.ages, style: theme.textTheme.titleSmall),
                Text('${stage.years} ${stage.ganzhi}', style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          SizedBox(
            width: 72,
            child: Text(
              '${best ? '★ ' : ''}${stage.label}',
              style: theme.textTheme.titleSmall?.copyWith(color: best ? scheme.tertiary : null),
            ),
          ),
          Expanded(child: Text(stage.focus, style: theme.textTheme.bodyMedium?.copyWith(height: 1.6))),
        ],
      ),
    );
  }
}

/// Starts a life report for a computed chart and opens it.
Future<void> startLifeReport(BuildContext context, WidgetRef ref, {required ChartResult chart, BirthProfile? profile}) async {
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  final locale = ref.read(settingsProvider).apiLocaleCode;
  try {
    final r = await ref
        .read(apiClientProvider)
        .createLifeReport(
          chartId: chart.chartId,
          locale: locale,
          context: profile?.life.toApi(name: profile.name, locale: locale, birthplace: profile.birthPlace.label(locale)),
        );
    ref.invalidate(lifeReportsProvider);
    await navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => LifeReportPage(reportId: r.id, profile: profile, chart: chart),
      ),
    );
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('$e')));
  }
}

/// "生成一生运势报告" for a computed 八字 chart.
class LifeReportButton extends ConsumerStatefulWidget {
  const LifeReportButton({super.key, required this.chart, this.profile});
  final ChartResult chart;
  final BirthProfile? profile;
  @override
  ConsumerState<LifeReportButton> createState() => _LifeReportButtonState();
}

class _LifeReportButtonState extends ConsumerState<LifeReportButton> {
  bool _busy = false;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return compactButtons(
      context,
      FilledButton.tonalIcon(
        key: const Key('life-generate'),
        onPressed: _busy
            ? null
            : () async {
                setState(() => _busy = true);
                await startLifeReport(context, ref, chart: widget.chart, profile: widget.profile);
                if (mounted) setState(() => _busy = false);
              },
        icon: _busy
            ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.auto_stories),
        label: Text(l10n.lifeGenerate),
      ),
    );
  }
}
