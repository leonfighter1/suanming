import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../../l10n/gen/app_localizations.dart';
import '../design.dart';
import '../labels.dart';

/// Layers ①–③ of a report. Layer ④ (expectation + AI label) is the fixed footer
/// [ExpectationFooter], so it stays visible however far the user scrolls.
class FourLayerReport extends StatelessWidget {
  const FourLayerReport({super.key, required this.layers});
  final ReportLayers layers;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ListView(
      padding: Space.page,
      children: [
        FadeSlideIn(
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
                        Expanded(child: Text(f)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        FadeSlideIn(
          index: 1,
          child: AppCard(
            title: l10n.layerInterpretation,
            icon: Icons.auto_awesome,
            trailing: Badge(label: Text(l10n.aiBadge)),
            padding: const EdgeInsets.fromLTRB(Space.l + 4, Space.l + 4, Space.s, Space.s),
            child: Column(
              children: [
                for (final s in layers.interpretation)
                  // Collapsible per topic; all start open.
                  Theme(
                    data: theme.copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      initiallyExpanded: true,
                      tilePadding: const EdgeInsets.only(right: Space.s),
                      childrenPadding: const EdgeInsets.only(right: Space.m, bottom: Space.s),
                      title: Text(l10n.topic(s.topic), style: theme.textTheme.titleMedium?.copyWith(color: scheme.primary)),
                      children: [
                        for (final p in s.paragraphs)
                          Padding(
                            padding: const EdgeInsets.only(bottom: Space.m),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.text, style: theme.textTheme.bodyLarge?.copyWith(height: 1.75)),
                                const SizedBox(height: Space.s),
                                Pill(l10n.sourceLevel(p.sourceLevel), icon: Icons.menu_book_outlined),
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
        FadeSlideIn(
          index: 2,
          child: AppCard(
            title: l10n.layerActions,
            icon: Icons.checklist_rtl,
            trailing: Badge(label: Text(l10n.aiBadge)),
            color: scheme.primaryContainer.withValues(alpha: 0.5),
            child: Column(
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
                              Text(a.text, style: theme.textTheme.bodyLarge),
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
