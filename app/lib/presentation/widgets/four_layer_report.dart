import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../../l10n/gen/app_localizations.dart';
import '../design.dart';
import '../labels.dart';
import 'remedy.dart';
import 'trend_chart.dart';

/// Layers ①–③ of a report, with the 八字 trend chart on top and the paid
/// 破除運勢 module below. Layer ④ (expectation + AI label) is the fixed footer
/// [ExpectationFooter], so it stays visible however far the user scrolls.
class FourLayerReport extends StatefulWidget {
  const FourLayerReport({super.key, required this.layers, this.reportId});
  final ReportLayers layers;

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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final layers = widget.layers;
    final body = theme.textTheme.bodyLarge?.copyWith(height: 1.75);
    var i = 0;

    return ListView(
      padding: Space.page,
      children: [
        if (layers.trend != null) FadeSlideIn(index: i++, child: TrendCard(trend: layers.trend!)),
        FadeSlideIn(
          index: i++,
          child: AppCard(
            title: l10n.layerFacts,
            icon: Icons.fact_check_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final f in layers.facts)
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
                      children: [
                        for (final p in s.paragraphs)
                          Padding(
                            padding: const EdgeInsets.only(bottom: Space.m),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.text, textAlign: TextAlign.start, style: body),
                                const SizedBox(height: Space.s),
                                Pill(l10n.sourceLevel(p.sourceLevel), icon: Icons.menu_book_outlined),
                              ],
                            ),
                          ),
                        if (widget.reportId != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: Space.s),
                            child: RemedyButton(reportId: widget.reportId!, topic: s.topic, compact: true),
                          ),
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
        if (widget.reportId != null)
          FadeSlideIn(
            index: i++,
            child: RemedyCard(reportId: widget.reportId!, topics: [for (final s in layers.interpretation) s.topic]),
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
