import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../data/api_client.dart';
import '../../generated/contract.g.dart';
import '../../l10n/gen/app_localizations.dart';
import '../design.dart';
import '../inquiry_page.dart';
import '../labels.dart';
import '../report_page.dart';
import 'inquiry_goal_dialog.dart';

/// Topic picker + "generate AI reading" button for a computed chart.
class ReportRequest extends ConsumerStatefulWidget {
  const ReportRequest({
    super.key,
    required this.chartId,
    required this.system,
    this.title,
    this.context,
    this.place,
    this.question,
    this.focus,
  });
  final String chartId;
  final String system;

  /// 塔罗, 求籤: what the user asked before drawing (POST /v1/reports `question`).
  final String? question;

  /// 塔罗: the area of life the reading looks at (POST /v1/reports `focus`, contract `tarotFocus`).
  final String? focus;

  /// What the user told us about their life (POST /v1/reports `context`).
  final Map<String, Object?>? context;

  /// Shown on the report page and in exports (e.g. 「小明 的命盤」).
  final String? title;

  /// Birthplace label, shown on the report.
  final String? place;

  @override
  ConsumerState<ReportRequest> createState() => _ReportRequestState();
}

class _ReportRequestState extends ConsumerState<ReportRequest> {
  late final List<String> _available = topicsBySystem[widget.system] ?? const [];
  late final Set<String> _selected = {..._available};
  bool _busy = false;

  /// 深度分析 (v10.0.0): the master asks first, then the reading reads the conversation. It needs a goal: what was asked
  /// before the draw, or for 八字 the profile's 想了解的事; without one, the reminder asks for it.
  Future<void> _inquire() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    var goal = (widget.question ?? widget.context?['concern'] as String? ?? '').trim();
    if (goal.characters.length < inquiryGoalMin) {
      final asked = await askInquiryGoal(context, initial: goal);
      if (asked == null || !mounted) return;
      goal = asked;
    }
    setState(() => _busy = true);
    try {
      final topics = _available.where(_selected.contains).toList();
      final inquiry = await ref.read(apiClientProvider).startInquiry(
            chartId: widget.chartId,
            locale: ref.read(settingsProvider).apiLocaleCode,
            goal: goal,
            question: widget.question,
            focus: widget.focus,
            context: widget.context,
          );
      if (!mounted) return;
      await navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => InquiryPage(
            inquiryId: inquiry.id,
            reading: InquiryReading(
              chartId: widget.chartId,
              system: widget.system,
              topics: topics,
              question: widget.question,
              focus: widget.focus,
              context: widget.context,
              title: widget.title,
              place: widget.place,
            ),
          ),
        ),
      );
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.code == 'goal_required' ? l10n.inquiryGoalShort : '$e')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _generate() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final settings = ref.read(settingsProvider);
      final report = await ref.read(apiClientProvider).createReport(
            chartId: widget.chartId,
            locale: settings.apiLocaleCode,
            topics: _available.where(_selected.contains).toList(),
            question: widget.question,
            focus: widget.focus,
            context: widget.context,
          );
      ref.invalidate(historyProvider);
      await navigator.push(
        MaterialPageRoute<void>(builder: (_) => ReportPage(reportId: report.id, title: widget.title, place: widget.place)),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      title: l10n.aiReport,
      icon: Icons.auto_awesome,
      color: scheme.primaryContainer.withValues(alpha: 0.45),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // A tarot reading's sections are fixed (v2.3.0): card by card, the whole spread, the advice;
          // so are a 求籤 reading's (v4.3.0): the poem, the question, the advice.
          if (widget.system == 'tarot')
            Text(l10n.tarotSections, key: const Key('tarot-sections'), style: Theme.of(context).textTheme.bodyMedium)
          else if (widget.system == 'qiuqian')
            Text(l10n.qiuqianSections, key: const Key('qiuqian-sections'), style: Theme.of(context).textTheme.bodyMedium)
          else if (widget.system == 'fengshui')
            Text(l10n.fengshuiSections, key: const Key('fengshui-sections'), style: Theme.of(context).textTheme.bodyMedium)
          else if (widget.system == 'liuyao')
            Text(l10n.liuyaoSections, key: const Key('liuyao-sections'), style: Theme.of(context).textTheme.bodyMedium)
          else if (widget.system == 'naming')
            Text(l10n.namingSections, key: const Key('naming-sections'), style: Theme.of(context).textTheme.bodyMedium)
          else ...[
            Text(l10n.chooseTopics, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: Space.s),
            Wrap(
              spacing: Space.s,
              runSpacing: Space.s,
              children: [
                for (final t in _available)
                  FilterChip(
                    label: Text(l10n.topic(t)),
                    selected: _selected.contains(t),
                    onSelected: (on) => setState(() => on ? _selected.add(t) : _selected.remove(t)),
                  ),
              ],
            ),
          ],
          const SizedBox(height: Space.l),
          FilledButton.icon(
            key: const Key('generate-report'),
            onPressed: _busy || _selected.isEmpty ? null : _generate,
            icon: _busy
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.auto_awesome),
            // 八字 (v9.3.0, the owner): the engine has read the chart already; this asks the AI for its own reading.
            label: Text(widget.system == 'bazi' ? l10n.generateBazi : l10n.generate),
          ),
          // 深度分析 (v10.0.0): the master asks about the user's situation first, for the methods that have it.
          if (inquirySystems.contains(widget.system)) ...[
            const SizedBox(height: Space.s),
            OutlinedButton.icon(
              key: const Key('inquiry-start'),
              onPressed: _busy || _selected.isEmpty ? null : _inquire,
              icon: const Icon(Icons.record_voice_over_outlined),
              label: Text(l10n.inquiryButton),
            ),
            const SizedBox(height: Space.xs),
            Text(
              l10n.inquiryButtonNote(inquiryMaxQuestions),
              key: const Key('inquiry-note'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: Space.s),
          Text(l10n.disclaimerShort, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
