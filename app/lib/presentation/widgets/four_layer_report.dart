import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;

import '../../domain/models.dart';
import '../../generated/contract.g.dart';
import '../../l10n/gen/app_localizations.dart';
import '../design.dart';
import '../labels.dart';
import 'reading_paragraph.dart';
import 'remedy.dart';
import 'trend_chart.dart';

/// Layers ①–③ of a report, with the 八字 trend chart on top and the paid
/// 破除運勢 module below. Layer ④ (expectation + AI label) is the fixed footer
/// [ExpectationFooter], so it stays visible however far the user scrolls.
class FourLayerReport extends StatefulWidget {
  const FourLayerReport({super.key, required this.layers, this.reportId, this.birthplace, this.header});
  final ReportLayers layers;

  /// Shown above the layers: the reading's chart, a tarot spread (v2.4.0) or the four pillars
  /// (v3.4.0).
  final Widget? header;

  /// Shown first in the facts card when known.
  final String? birthplace;

  /// Enables the 破除運勢 module (needs the report id). Null: hidden.
  final String? reportId;

  @override
  State<FourLayerReport> createState() => _FourLayerReportState();
}

class _FourLayerReportState extends State<FourLayerReport> {
  /// Open topic sections. Only the first starts open.
  late Set<int> _open = {0};

  /// Bumped by expand/collapse all so every tile rebuilds with the new state.
  int _generation = 0;

  bool get _allOpen => _open.length == widget.layers.interpretation.length;

  void _toggleAll() => setState(() {
        _open = _allOpen ? {} : {for (var i = 0; i < widget.layers.interpretation.length; i++) i};
        _generation++;
      });

  /// Where the jump list goes (v3.4.0): each topic section, then 行动建议 (the last one).
  late final _targets = [for (var i = 0; i <= widget.layers.interpretation.length; i++) GlobalKey()];

  /// Focus for a target once jumped to, so Tab goes on from there; Tab itself passes them by.
  late final _targetFocus = [for (final _ in _targets) FocusNode(skipTraversal: true)];

  @override
  void dispose() {
    for (final f in _targetFocus) {
      f.dispose();
    }
    super.dispose();
  }

  /// Opens section [n] (n = the number of sections: 行动建议), brings it into view and moves the
  /// focus to it.
  void _jumpTo(int n) {
    if (n < widget.layers.interpretation.length && !_open.contains(n)) {
      setState(() {
        _open.add(n);
        _generation++;
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _targets[n].currentContext;
      if (!mounted || target == null) return;
      Scrollable.ensureVisible(target, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
      _targetFocus[n].requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final layers = widget.layers;
    final body = theme.textTheme.bodyLarge?.copyWith(height: 1.75);
    var i = 0;
    Widget target(int n, Widget child) =>
        Focus(focusNode: _targetFocus[n], child: KeyedSubtree(key: _targets[n], child: child));

    return ListView(
      padding: Space.page,
      // Every card is built, so the jump list can reach the last one from the top.
      scrollCacheExtent: const ScrollCacheExtent.pixels(100000),
      children: [
        // The jump list (v3.4.0): a chip per section and 行动建议, in one row that scrolls sideways
        // on a phone. Not a lazy list: Tab must reach every chip.
        if (layers.interpretation.length > 1)
          Padding(
            key: const Key('jump-list'),
            padding: const EdgeInsets.only(bottom: Space.m),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Text(l10n.jumpTo, style: theme.textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant)),
                  for (final (n, s) in layers.interpretation.indexed)
                    Padding(
                      padding: const EdgeInsets.only(left: Space.s),
                      child: ActionChip(key: Key('jump-${s.topic}'), label: Text(l10n.topic(s.topic)), onPressed: () => _jumpTo(n)),
                    ),
                  if (layers.actions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: Space.s),
                      child: ActionChip(
                        key: const Key('jump-actions'),
                        label: Text(l10n.jumpActions),
                        onPressed: () => _jumpTo(layers.interpretation.length),
                      ),
                    ),
                ],
              ),
            ),
          ),
        // Takes no stagger slot: the cards below keep their timing.
        if (widget.header != null) FadeSlideIn(child: widget.header!),
        if (layers.trend != null) FadeSlideIn(index: i++, child: TrendCard(trend: layers.trend!)),
        FadeSlideIn(
          index: i++,
          child: AppCard(
            title: l10n.layerFacts,
            icon: Icons.fact_check_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final f in [if (widget.birthplace != null) '${l10n.city}：${widget.birthplace}', ...layers.facts])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: Space.xs),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 7, right: Space.s),
                          child: Container(width: 5, height: 5, decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle)),
                        ),
                        Expanded(child: Text(f, textAlign: TextAlign.start)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        FadeSlideIn(
          index: i++,
          child: AppCard(
            title: l10n.layerInterpretation,
            icon: Icons.auto_awesome,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton.icon(
                  key: const Key('expand-all'),
                  onPressed: _toggleAll,
                  icon: Icon(_allOpen ? Icons.unfold_less : Icons.unfold_more, size: 18),
                  label: Text(_allOpen ? l10n.collapseAll : l10n.expandAll),
                ),
                Badge(label: Text(l10n.aiBadge)),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(Space.l + 4, Space.l + 4, Space.s, Space.s),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (n, s) in layers.interpretation.indexed)
                  target(
                    n,
                    Theme(
                      data: theme.copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        key: ValueKey('topic-$n-$_generation'),
                        initiallyExpanded: _open.contains(n),
                        onExpansionChanged: (open) => setState(() => open ? _open.add(n) : _open.remove(n)),
                        tilePadding: const EdgeInsets.only(right: Space.s),
                        childrenPadding: const EdgeInsets.only(right: Space.m, bottom: Space.s),
                        // Body text reads left-aligned, not centred under the title.
                        expandedAlignment: Alignment.centerLeft,
                        expandedCrossAxisAlignment: CrossAxisAlignment.start,
                        title: Text(l10n.topic(s.topic), style: theme.textTheme.titleMedium?.copyWith(color: scheme.primary)),
                        // 一句話重點: the plain main point, visible even while collapsed.
                        subtitle: s.summary == null
                            ? null
                            : Padding(
                                padding: const EdgeInsets.only(top: Space.xs),
                                child: Text(
                                  s.summary!,
                                  key: Key('summary-${s.topic}'),
                                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, height: 1.5),
                                ),
                              ),
                        children: [
                          // 术语 → 评论 → 例子 (v6.2.0).
                          for (final (j, p) in s.paragraphs.indexed)
                            Padding(
                              padding: const EdgeInsets.only(bottom: Space.l),
                              child: ReadingParagraph(paragraph: p, id: '${s.topic}-$j'),
                            ),
                          // 逐张解读 and 综合解读 have no plan; a tarot plan is on 建议 (contract noPlanTopics).
                          if (widget.reportId != null && !noPlanTopics.contains(s.topic))
                            Padding(
                              padding: const EdgeInsets.only(bottom: Space.s),
                              child: RemedyButton(reportId: widget.reportId!, topic: s.topic, compact: true),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        FadeSlideIn(
          index: i++,
          child: target(
            layers.interpretation.length,
            AppCard(
              title: l10n.layerActions,
              icon: Icons.checklist_rtl,
              trailing: Badge(label: Text(l10n.aiBadge)),
              color: scheme.primaryContainer.withValues(alpha: 0.5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final a in layers.actions)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: Space.s),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.check_circle_outline, color: scheme.primary),
                          const SizedBox(width: Space.m),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(a.text, textAlign: TextAlign.start, style: body),
                                const SizedBox(height: Space.xs),
                                Text(
                                  '${l10n.topic(a.topic)} · ${l10n.horizon(a.horizon)}',
                                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (widget.reportId != null)
          FadeSlideIn(
            index: i++,
            child: RemedyCard(
              reportId: widget.reportId!,
              topics: [
                for (final s in layers.interpretation)
                  if (!noPlanTopics.contains(s.topic)) s.topic,
              ],
            ),
          ),
      ],
    );
  }
}

/// Layer ④: fixed expectation-management copy and the AI label. Not
/// model-generated; where the region requires the label, it is emphasised
/// and cannot be dismissed (compliance/ai_disclosure_spec.md §3).
class ExpectationFooter extends StatelessWidget {
  const ExpectationFooter({super.key, required this.expectation});
  final Expectation expectation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      elevation: 8,
      color: scheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Container(
          decoration: expectation.labelRequired
              ? BoxDecoration(border: Border(top: BorderSide(color: scheme.primary, width: 2)))
              : null,
          padding: const EdgeInsets.fromLTRB(Space.l, Space.m, Space.l, Space.m),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.smart_toy_outlined, size: 18, color: scheme.primary),
                  const SizedBox(width: Space.s),
                  Expanded(
                    child: Text(expectation.aiLabel, key: const Key('ai-label'), style: theme.textTheme.labelLarge),
                  ),
                ],
              ),
              const SizedBox(height: Space.xs),
              Text(expectation.text, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}
