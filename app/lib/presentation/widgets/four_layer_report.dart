import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../../l10n/gen/app_localizations.dart';
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
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _LayerCard(
          title: l10n.layerFacts,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final f in layers.facts)
                Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text('• $f')),
            ],
          ),
        ),
        _LayerCard(
          title: l10n.layerInterpretation,
          badge: l10n.aiBadge,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final s in layers.interpretation) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 4),
                  child: Text(
                    l10n.topic(s.topic),
                    style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary),
                  ),
                ),
                for (final p in s.paragraphs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.text, style: const TextStyle(height: 1.7)),
                        const SizedBox(height: 4),
                        Chip(
                          label: Text(l10n.sourceLevel(p.sourceLevel)),
                          visualDensity: VisualDensity.compact,
                          labelStyle: theme.textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
        _LayerCard(
          title: l10n.layerActions,
          badge: l10n.aiBadge,
          color: theme.colorScheme.primaryContainer,
          child: Column(
            children: [
              for (final a in layers.actions)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(Icons.check_circle_outline),
                  title: Text(a.text),
                  subtitle: Text('${l10n.topic(a.topic)} · ${l10n.horizon(a.horizon)}'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LayerCard extends StatelessWidget {
  const _LayerCard({required this.title, required this.child, this.badge, this.color});
  final String title;
  final String? badge;
  final Color? color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: theme.textTheme.labelLarge)),
                if (badge != null) Badge(label: Text(badge!)),
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
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
    return Material(
      elevation: 8,
      color: theme.colorScheme.surfaceContainerHighest,
      child: SafeArea(
        top: false,
        child: Container(
          decoration: expectation.labelRequired
              ? BoxDecoration(border: Border(top: BorderSide(color: theme.colorScheme.primary, width: 2)))
              : null,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.smart_toy_outlined, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      expectation.aiLabel,
                      key: const Key('ai-label'),
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(expectation.text, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
