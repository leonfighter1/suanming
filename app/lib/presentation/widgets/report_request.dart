import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../generated/contract.g.dart';
import '../../l10n/gen/app_localizations.dart';
import '../design.dart';
import '../labels.dart';
import '../report_page.dart';

/// Topic picker + "generate AI reading" button for a computed chart.
class ReportRequest extends ConsumerStatefulWidget {
  const ReportRequest({super.key, required this.chartId, required this.system, this.title, this.context});
  final String chartId;
  final String system;

  /// What the user told us about their life (POST /v1/reports `context`).
  final Map<String, Object?>? context;

  /// Shown on the report page and in exports (e.g. 「小明 的命盤」).
  final String? title;

  @override
  ConsumerState<ReportRequest> createState() => _ReportRequestState();
}

class _ReportRequestState extends ConsumerState<ReportRequest> {
  late final List<String> _available = topicsBySystem[widget.system] ?? const [];
  late final Set<String> _selected = {..._available};
  bool _busy = false;

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
            context: widget.context,
          );
      ref.invalidate(historyProvider);
      await navigator.push(
        MaterialPageRoute<void>(builder: (_) => ReportPage(reportId: report.id, title: widget.title)),
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
          const SizedBox(height: Space.l),
          FilledButton.icon(
            key: const Key('generate-report'),
            onPressed: _busy || _selected.isEmpty ? null : _generate,
            icon: _busy
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.auto_awesome),
            label: Text(l10n.generate),
          ),
          const SizedBox(height: Space.s),
          Text(l10n.disclaimerShort, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
