import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/providers.dart';
import '../l10n/gen/app_localizations.dart';
import 'widgets/four_layer_report.dart';

/// Shows a report, polling until generation finishes.
class ReportPage extends ConsumerWidget {
  const ReportPage({super.key, required this.reportId});
  final String reportId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final report = ref.watch(reportProvider(reportId));
    final layers = report.value?.layers;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.aiReport)),
      bottomNavigationBar: layers == null ? null : ExpectationFooter(expectation: layers.expectation),
      body: report.when(
        loading: () => _Generating(l10n: l10n),
        error: (e, _) => _Message(
          icon: Icons.error_outline,
          text: '${l10n.errorTitle}\n$e',
          action: TextButton(
            onPressed: () => ref.invalidate(reportProvider(reportId)),
            child: Text(l10n.retry),
          ),
        ),
        data: (r) => switch (r.status) {
          'pending' => _Generating(l10n: l10n),
          'passed' => FourLayerReport(layers: r.layers!),
          'blocked' => _Message(icon: Icons.block, text: l10n.statusBlocked),
          'manual_review' => _Message(icon: Icons.hourglass_top, text: l10n.statusReview),
          _ => _Message(icon: Icons.error_outline, text: l10n.statusFailed),
        },
      ),
    );
  }
}

class _Generating extends StatelessWidget {
  const _Generating({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) => _Message(
        icon: null,
        text: '${l10n.generating}\n\n${l10n.generatingHint}',
        leading: const CircularProgressIndicator(),
      );
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.leading, this.action});
  final IconData? icon;
  final String text;
  final Widget? leading;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              leading ?? Icon(icon, size: 48),
              const SizedBox(height: 16),
              Text(text, textAlign: TextAlign.center),
              if (action != null) ...[const SizedBox(height: 12), action!],
            ],
          ),
        ),
      );
}
