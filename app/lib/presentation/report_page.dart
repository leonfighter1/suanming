import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../application/providers.dart';
import '../domain/export.dart';
import '../domain/models.dart';
import '../l10n/gen/app_localizations.dart';
import 'design.dart';
import 'labels.dart';
import 'widgets/four_layer_report.dart';
import 'widgets/tarot_spread.dart';

/// Shows a report, polling until generation finishes. While pending it shows
/// the pipeline stage the server reports; when passed it can be exported.
class ReportPage extends ConsumerWidget {
  const ReportPage({super.key, required this.reportId, this.title, this.place});
  final String reportId;
  final String? title;

  /// Birthplace label (device data: the server only has timezone + longitude).
  final String? place;

  String _export(AppLocalizations l10n, ReportView r) => exportReportMarkdown(
        report: r,
        title: l10n.reportTitle,
        subtitle: [title, if (r.createdAt != null) r.createdAt!.toLocal().toString().substring(0, 16)]
            .whereType<String>()
            .join(' · '),
        topicLabel: l10n.topic,
        horizonLabel: l10n.horizon,
        headings: {
          'facts': l10n.layerFacts,
          'interpretation': l10n.layerInterpretation,
          'actions': l10n.layerActions,
          'trend': l10n.trendTitle,
          'total': l10n.trendTotal,
        },
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final report = ref.watch(reportProvider(reportId));
    final r = report.value;
    final layers = r?.layers;

    return Scaffold(
      appBar: AppBar(
        title: Text(title ?? l10n.aiReport),
        actions: [
          if (r != null && layers != null)
            PopupMenuButton<String>(
              key: const Key('report-menu'),
              tooltip: l10n.more,
              position: PopupMenuPosition.under,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.field)),
              onSelected: (v) async {
                final text = _export(l10n, r);
                final messenger = ScaffoldMessenger.of(context);
                if (v == 'copy') {
                  await Clipboard.setData(ClipboardData(text: text));
                  messenger.showSnackBar(SnackBar(content: Text(l10n.copied)));
                } else {
                  // Share sheet on mobile; a file download on web/desktop browsers.
                  final name = 'mingli-reading-${r.id.substring(0, 8)}.md';
                  await SharePlus.instance.share(
                    ShareParams(
                      files: [XFile.fromData(utf8.encode(text), mimeType: 'text/markdown', name: name)],
                      fileNameOverrides: [name],
                      subject: l10n.reportTitle,
                    ),
                  );
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  key: const Key('download-report'),
                  value: 'download',
                  child: Row(children: [const Icon(Icons.download_outlined), const SizedBox(width: Space.m), Text(l10n.download)]),
                ),
                PopupMenuItem(
                  key: const Key('copy-report'),
                  value: 'copy',
                  child: Row(children: [const Icon(Icons.copy_all_outlined), const SizedBox(width: Space.m), Text(l10n.copyAll)]),
                ),
              ],
            ),
        ],
      ),
      bottomNavigationBar: layers == null ? null : ExpectationFooter(expectation: layers.expectation),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        switchInCurve: Curves.easeOutCubic,
        child: report.when(
          loading: () => const _Generating(key: ValueKey('loading'), report: null),
          error: (e, _) => _Message(
            key: const ValueKey('error'),
            icon: Icons.error_outline,
            text: '${l10n.errorTitle}\n$e',
            action: TextButton(onPressed: () => ref.invalidate(reportProvider(reportId)), child: Text(l10n.retry)),
          ),
          data: (r) => switch (r.status) {
            'pending' => _Generating(key: const ValueKey('pending'), report: r),
            'passed' => FourLayerReport(
                key: const ValueKey('passed'),
                layers: r.layers!,
                reportId: r.id,
                birthplace: place,
                header: r.chartId == null ? null : ReadingSpread(chartId: r.chartId!),
              ),
            'blocked' => _Message(key: const ValueKey('blocked'), icon: Icons.block, text: l10n.statusBlocked),
            'manual_review' => _Message(key: const ValueKey('review'), icon: Icons.hourglass_top, text: l10n.statusReview),
            _ => _Message(key: const ValueKey('failed'), icon: Icons.error_outline, text: l10n.statusFailed),
          },
        ),
      ),
    );
  }
}

/// A tarot reading's spread with its art, every card turned (v2.4.0). Other charts show nothing
/// here: their facts are in the layers.
class ReadingSpread extends ConsumerWidget {
  const ReadingSpread({super.key, required this.chartId});
  final String chartId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chart = ref.watch(chartProvider(chartId)).value;
    if (chart == null || chart.system != 'tarot') return const SizedBox.shrink();
    final tarot = chart.tarot;
    return AppCard(
      key: const Key('reading-spread'),
      title: AppLocalizations.of(context).spread,
      icon: Icons.style_rounded,
      child: TarotSpread(chart: tarot, revealed: {for (final c in tarot.cards) c.position}, onReveal: (_) {}),
    );
  }
}

const _stages = ['narrative', 'action', 'guard'];

/// "AI is analysing in depth": pulsing mark, elapsed time and the live stage.
class _Generating extends StatefulWidget {
  const _Generating({super.key, required this.report});
  final ReportView? report;

  @override
  State<_Generating> createState() => _GeneratingState();
}

class _GeneratingState extends State<_Generating> with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
  final _opened = DateTime.now();
  late final Timer _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));

  @override
  void initState() {
    super.initState();
    _tick; // start the clock
  }

  @override
  void dispose() {
    _tick.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final started = widget.report?.createdAt?.toLocal() ?? _opened;
    final secs = DateTime.now().difference(started).inSeconds.clamp(0, 359999);
    final elapsed = '${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}';
    final stage = widget.report?.progressStage;
    final active = stage == null ? -1 : _stages.indexOf(stage);
    final attempt = widget.report?.progressAttempt ?? 1;
    final stageLabel = {'narrative': l10n.stageNarrative, 'action': l10n.stageAction, 'guard': l10n.stageGuard};

    return ListView(
      padding: Space.page,
      children: [
        const SizedBox(height: Space.xl),
        Center(
          child: ScaleTransition(
            scale: Tween(begin: 0.9, end: 1.08).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [scheme.primary, scheme.tertiary]),
                boxShadow: [BoxShadow(color: scheme.primary.withValues(alpha: 0.35), blurRadius: 28)],
              ),
              child: Icon(Icons.auto_awesome, size: 44, color: scheme.onPrimary),
            ),
          ),
        ),
        const SizedBox(height: Space.xl),
        Text(
          l10n.analyzing,
          key: const Key('analyzing'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: Space.s),
        Text(l10n.elapsed(elapsed), textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: Space.xl),
        AppCard(
          child: Column(
            children: [
              for (var i = 0; i < _stages.length; i++)
                _StageRow(
                  label: stageLabel[_stages[i]]!,
                  state: i < active ? _StepState.done : (i == active ? _StepState.active : _StepState.upcoming),
                ),
              if (active == -1) _StageRow(label: l10n.stageWaiting, state: _StepState.active),
            ],
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: attempt > 1
              ? Pill(l10n.retrying(attempt), key: ValueKey(attempt), icon: Icons.refresh, color: scheme.tertiary)
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: Space.l),
        Text(
          l10n.generatingHint,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

enum _StepState { done, active, upcoming }

class _StageRow extends StatelessWidget {
  const _StageRow({required this.label, required this.state});
  final String label;
  final _StepState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (state) {
      _StepState.done => scheme.primary,
      _StepState.active => scheme.tertiary,
      _StepState.upcoming => scheme.outlineVariant,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.s),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 28,
            height: 28,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: switch (state) {
              _StepState.done => Icon(Icons.check, size: 18, color: color),
              _StepState.active => Padding(
                  padding: const EdgeInsets.all(6),
                  child: CircularProgressIndicator(strokeWidth: 2, color: color),
                ),
              _StepState.upcoming => Icon(Icons.circle_outlined, size: 14, color: color),
            },
          ),
          const SizedBox(width: Space.m),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: state == _StepState.upcoming ? scheme.onSurfaceVariant : scheme.onSurface,
                  fontWeight: state == _StepState.active ? FontWeight.w600 : null,
                ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({super.key, required this.icon, required this.text, this.action});
  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(Space.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 52, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: Space.l),
              Text(text, textAlign: TextAlign.center),
              if (action != null) ...[const SizedBox(height: Space.m), action!],
            ],
          ),
        ),
      );
}
