import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../application/providers.dart';
import '../domain/document.dart';
import '../domain/life_report.dart';
import '../domain/models.dart';
import '../domain/profile.dart';
import '../l10n/gen/app_localizations.dart';
import '../platform/printer.dart';
import 'archive_actions.dart' show lifeDocumentOf, shareDocuments;
import 'design.dart';
import 'labels.dart';
import 'life_export.dart';
import 'widgets/follow_up.dart';
import 'widgets/life_blocks.dart';
import 'widgets/life_figures.dart';
import 'widgets/life_stages.dart';
import 'widgets/remedy.dart' show compactButtons;

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
    // Whose report: kept with its chart on the server (v6.2.0; 归类到… changes it, v8.0.0), else this device's label,
    // so another device or sign-in names the person and the birthplace too.
    final header = ready
        ? _header(
            l10n,
            view,
            chart,
            view.person?.name ?? chart.person?.name ?? names[view.chartId],
            view.person?.birthplace ?? chart.person?.birthplace ?? places[view.chartId],
            hant,
            locale,
          )
        : null;

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
        title: Text(header == null || header.name.isEmpty ? l10n.lifeEntry : l10n.lifeReportOf(header.name)),
        actions: [
          if (ready) ...[
            // 下载 (v8.0.0): PDF or Word, rendered by the server with the report's 追问; or the HTML and Markdown ZIP.
            PopupMenuButton<String>(
              key: const Key('life-download'),
              tooltip: l10n.lifeDownload,
              icon: const Icon(Icons.download_outlined),
              onSelected: (v) async {
                final messenger = ScaffoldMessenger.of(context);
                if (v == 'zip') {
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
                  return;
                }
                try {
                  final doc = await lifeDocumentOf(
                    ref,
                    l10n,
                    lifeReportId: reportId,
                    person: header!.name.isEmpty ? null : header.name,
                    birthplace: header.place == '—' ? null : header.place,
                  );
                  await shareDocuments(
                    ref,
                    [(doc, docFileName(doc.title, view.createdAt?.toLocal()))],
                    v == 'pdf' ? DocFormat.pdf : DocFormat.docx,
                    subject: doc.title,
                  );
                } catch (_) {
                  messenger.showSnackBar(SnackBar(content: Text(l10n.archiveDocFailed)));
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(key: const Key('life-download-pdf'), value: 'pdf', child: Text(l10n.archiveDownloadPdf)),
                PopupMenuItem(key: const Key('life-download-docx'), value: 'docx', child: Text(l10n.archiveDownloadWord)),
                PopupMenuItem(key: const Key('life-download-zip'), value: 'zip', child: Text(l10n.lifeDownload)),
              ],
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
        // Every state has its own key: opened from history, waiting is followed by loading the chart, and two
        // unkeyed children in the switcher at once are duplicate keys.
        child: switch (view) {
          null when async.hasError => _Message(key: const ValueKey('life-error'), text: '${l10n.errorTitle}\n${async.error}'),
          null => const _Pending(key: ValueKey('life-waiting'), stage: null),
          LifeReportView(status: 'pending') => _Pending(key: const ValueKey('life-waiting'), stage: view.progressStage),
          LifeReportView(status: 'passed') when ready => _Body(
            key: const ValueKey('life-body'),
            view: view,
            header: header!,
            chart: chart,
            hant: hant,
          ),
          LifeReportView(status: 'passed') => const Center(key: ValueKey('life-loading'), child: CircularProgressIndicator()),
          LifeReportView(status: 'failed') => _Message(key: const ValueKey('life-failed'), text: l10n.statusFailed),
          _ => _Message(key: const ValueKey('life-held'), text: l10n.statusReview),
        },
      ),
    );
  }

  LifeHeader _header(AppLocalizations l10n, LifeReportView v, ChartResult chart, String? label, String? place, bool hant, String locale) =>
      lifeHeaderOf(
        l10n: l10n,
        view: v,
        chart: chart,
        name: profile?.name ?? label,
        place: profile?.birthPlace.label(locale) ?? place,
        hant: hant,
      );
}

/// The 项目 / 内容 rows of a 一生运势报告 for [name] born in [place]: the page's cover, and its documents (v8.0.0).
LifeHeader lifeHeaderOf({
  required AppLocalizations l10n,
  required LifeReportView view,
  required ChartResult chart,
  String? name,
  String? place,
  required bool hant,
}) {
  final b = chart.bazi;
  final f = view.facts!;
  final hour = b.pillars['hour']!.zhi;
  final shi = hant ? '時' : '时';
  final civil = DateTime.parse(b.civilLocal);
  final clock = f.pillarClock.substring(11, 16);
  final range = _shichenRange(hour);
  final gender = (chart.facts['dayun'] as Json)['gender'] == 'male' ? l10n.male : l10n.female;
  String two(int n) => n.toString().padLeft(2, '0');
  return LifeHeader(
    name: name ?? '',
    gender: gender,
    lunar:
        '${b.lunar.year} 年 ${b.lunar.yearGanzhi}年 ${b.lunar.isLeapMonth ? (hant ? '閏' : '闰') : ''}${b.lunar.monthName}${b.lunar.dayName} $hour$shi（${hant ? '約' : '约'} ${two(civil.hour)}:${two(civil.minute)}）',
    solar: '${civil.year} 年 ${civil.month} 月 ${civil.day} 日',
    place: place ?? '—',
    trueSolar: f.trueSolar ? '${hant ? '約' : '约'} $clock，${hant ? '屬' : '属'}$hour$shi（$range）' : '—',
    ganzhi: [
      '${b.pillars['year']!.ganzhi}年',
      '${b.pillars['month']!.ganzhi}月',
      '${b.pillars['day']!.ganzhi}日',
      '${b.pillars['hour']!.ganzhi}$shi',
    ].join('　'),
  );
}

String _shichenRange(String zhi) {
  const order = '子丑寅卯辰巳午未申酉戌亥';
  final i = order.indexOf(zhi);
  final start = (i * 2 + 23) % 24;
  String h(int x) => '${x % 24}:00';
  return '${h(start)}–${h(start + 2)}';
}

class _Pending extends StatefulWidget {
  const _Pending({super.key, required this.stage});
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
  const _Message({super.key, required this.text});
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

class _Body extends StatefulWidget {
  const _Body({super.key, required this.view, required this.header, required this.chart, required this.hant});
  final LifeReportView view;
  final LifeHeader header;
  final ChartResult chart;
  final bool hant;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  /// 追问 (v7.0.0): the card after the summary, and the floating button that brings it up.
  final _followUp = FollowUpTarget();

  @override
  void dispose() {
    _followUp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final view = widget.view;
    final header = widget.header;
    final hant = widget.hant;
    final f = view.facts!;
    final l = view.layers!;
    final body = theme.textTheme.bodyLarge?.copyWith(height: 1.8);
    final lunar = widget.chart.bazi.lunar;
    var i = 0;
    Widget fade(Widget w) => FadeSlideIn(index: i++, child: w);

    final list = ListView(
      // Room at the bottom for the floating 继续追问; every card built, so the button can bring up the last one.
      padding: Space.page.copyWith(bottom: Space.xxl + 72),
      scrollCacheExtent: const ScrollCacheExtent.pixels(100000),
      children: [
        fade(LifeHero(title: l10n.lifeReportOf(header.name), subtitle: l10n.lifeSubtitle)),
        fade(AppCard(child: LifeKeyValues(rows: header.rows(l10n)))),
        fade(LifeNote(text: l10n.lifeNote)),
        // 一、易经本命卦
        fade(
          LifeSection(
            key: const Key('life-sec-yijing'),
            title: l10n.lifeSec1,
            children: [
              LifeSub(l10n.lifeQigua),
              for (final s in qiguaSteps(f, hant: hant, lunarMonth: lunar.monthName, lunarDay: lunar.dayName)) LifeBullet(s),
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
              LifeSub(l10n.lifeGuaYi),
              LifeQuote(f.hexagram.guaCi),
              Text(l.yijingText('meaning'), style: body),
              LifeSub(l10n.lifeMingYao),
              LifeQuote(f.lines[f.movingLine - 1].text),
              Text(l.yijingText('ming_yao'), style: body),
              LifeSub(l10n.lifeZhiGua),
              LifeQuote(f.changed.guaCi),
              Text(l.yijingText('zhi_gua'), style: body),
              LifeSub(l10n.lifeSixLines),
              for (final x in f.lines.reversed.toList().reversed)
                LifeLineRow(line: x, reading: l.stageReading(x.line), mingYao: l10n.lifeMingYao, ageLabel: l10n.lifeAge),
            ],
          ),
        ),
        // 二、梅花易数
        fade(
          LifeSection(
            key: const Key('life-sec-meihua'),
            title: l10n.lifeSec2,
            children: [
              MeihuaTable(facts: f),
              const SizedBox(height: Space.m),
              LifeLabeled(l10n.lifeSeason, l.meihua['season'] as String),
              LifeLabeled('${l10n.lifeEarly} · ${relationLabel(l10n, f.yong.relation)}', l.meihua['early'] as String),
              LifeLabeled(l10n.lifeMiddle, l.meihua['middle'] as String),
              LifeLabeled('${l10n.lifeLate} · ${relationLabel(l10n, f.bian.relation)}', l.meihua['late'] as String),
              LifeHighlight('${l10n.lifeMhConclusion}：${l.meihua['conclusion']}'),
            ],
          ),
        ),
        // 三、五行八卦
        fade(
          LifeSection(
            key: const Key('life-sec-wuxing'),
            title: l10n.lifeSec3,
            children: [
              LifeSub(l10n.lifeWuxingDist),
              LifeWuxingBars(scores: widget.chart.bazi.wuxingWeighted),
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
              LifeSub(l10n.lifeBazhai),
              Text(
                l10n.lifeKua('${f.kua}', f.trigram(f.kuaTrigram).name, hantTerm(f.kuaGroup, hant), f.kuaWuxing),
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: Space.s),
              Text(l.bazhai['summary'] as String, style: body),
              const SizedBox(height: Space.m),
              BazhaiCompass(facts: f, hant: hant),
              const SizedBox(height: Space.m),
              LifeLabeled(l10n.lifeDaily, l.bazhai['daily'] as String),
            ],
          ),
        ),
        // 四、分项运势
        fade(
          LifeSection(
            key: const Key('life-sec-topics'),
            title: l10n.lifeSec4,
            children: [for (final topic in l.topics) LifeTopicBlock(title: topicLabel(l10n, topic.key), topic: topic)],
          ),
        ),
        // 五、人生阶段总览
        fade(
          LifeSection(
            key: const Key('life-sec-stages'),
            title: l10n.lifeSec5,
            children: [
              StageChart(stages: l.stages),
              const SizedBox(height: Space.m),
              for (final s in l.stages) LifeStageRow(stage: s, best: s.score == l.stages.map((x) => x.score).reduce((a, b) => a > b ? a : b)),
            ],
          ),
        ),
        // 六、总评与建议
        fade(
          LifeSection(
            key: const Key('life-sec-summary'),
            title: l10n.lifeSec6,
            children: [
              Text(l.verdict, style: body),
              const SizedBox(height: Space.m),
              for (final (area, text) in l.advice) LifeLabeled(area, text),
              LifeHighlight(l.closing),
            ],
          ),
        ),
        // 追问 (v7.0.0): right after the summary, the report's last section.
        fade(FollowUpCard(parent: 'life-reports/${view.id}', target: _followUp, starters: l10n.followUpStarters('life'))),
        const SizedBox(height: Space.l),
        Text(l.disclaimer, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
        const SizedBox(height: Space.xs),
        Text(l.aiLabel, key: const Key('life-ai-label'), style: theme.textTheme.labelMedium),
      ],
    );
    // 「继续追问」 floats at the bottom right, over the report (the owner: 显眼的位置).
    return Stack(
      children: [
        Positioned.fill(child: FollowUpScope(target: _followUp, child: list)),
        Positioned(right: Space.l, bottom: Space.l, child: FollowUpButton(target: _followUp)),
      ],
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
