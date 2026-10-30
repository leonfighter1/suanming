import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../application/providers.dart';
import '../../domain/export.dart';
import '../../domain/models.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../platform/printer.dart';
import '../design.dart';
import '../labels.dart';
import 'points.dart';

/// What a plan costs as its button and its pay popup say it: 「约 N 积分」 with 积分 on (v11.0.0), else the
/// placeholder price.
String _price(AppLocalizations l10n, RemedyList l) => l.points == null ? l.priceLabel : l10n.pointsAbout(l.points!.points);

/// 破除運勢: a separate, paid module. One plan per topic, each naming the topic
/// and periods it targets. Payment is a Phase 4 TODO: the pay popup "charges"
/// directly and the server records a placeholder, or (v11.0.0) the plan is paid in 积分.
class RemedyCard extends ConsumerWidget {
  const RemedyCard({super.key, required this.reportId, required this.topics});
  final String reportId;
  final List<String> topics;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final list = ref.watch(remediesProvider(reportId)).value;
    return AppCard(
      key: const Key('remedy-card'),
      title: l10n.remedyTitle,
      icon: Icons.auto_fix_high,
      color: scheme.tertiaryContainer.withValues(alpha: 0.45),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.remedyDesc, style: ReadingText.small(context)),
          const SizedBox(height: Space.s),
          for (final t in topics)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.xs),
              child: Row(
                children: [
                  Expanded(child: Text(l10n.topic(t), style: theme.textTheme.titleSmall)),
                  RemedyButton(reportId: reportId, topic: t, list: list),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The app theme makes buttons full-width; inside rows, wraps and dialogs they
/// must size to their label.
Widget compactButtons(BuildContext context, Widget child) {
  final t = Theme.of(context);
  const size = Size(0, 40);
  return Theme(
    data: t.copyWith(
      filledButtonTheme: FilledButtonThemeData(
        style: (t.filledButtonTheme.style ?? const ButtonStyle()).copyWith(minimumSize: const WidgetStatePropertyAll(size)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: (t.outlinedButtonTheme.style ?? const ButtonStyle()).copyWith(minimumSize: const WidgetStatePropertyAll(size)),
      ),
    ),
    child: child,
  );
}

/// "Unlock · HKD 18" for a topic not bought yet, "View plan" once bought.
class RemedyButton extends ConsumerWidget {
  const RemedyButton({super.key, required this.reportId, required this.topic, this.list, this.compact = false});
  final String reportId;
  final String topic;
  final RemedyList? list;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final l = list ?? ref.watch(remediesProvider(reportId)).value;
    if (l == null) {
      return const SizedBox(
        height: 40,
        width: 40,
        child: Padding(padding: EdgeInsets.all(Space.m), child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    final plan = l.items.where((r) => r.topic == topic && r.status != 'failed').firstOrNull;
    final bought = plan != null && !plan.locked;
    final label = compact
        ? l10n.remedyFor(l10n.topic(topic))
        : bought
        ? l10n.remedyView
        : l10n.remedyUnlock(_price(l10n, l));
    void onPressed() => openRemedy(context, ref, reportId: reportId, topic: topic, list: l);
    final button = compactButtons(
      context,
      bought && !compact
          ? FilledButton.tonalIcon(
              key: Key('remedy-open-$topic'),
              onPressed: onPressed,
              icon: const Icon(Icons.description_outlined),
              label: Text(label),
            )
          : OutlinedButton.icon(
              key: Key(compact ? 'remedy-inline-$topic' : 'remedy-buy-$topic'),
              onPressed: onPressed,
              icon: Icon(bought ? Icons.description_outlined : Icons.lock_open_outlined),
              label: Text(label),
            ),
    );
    // Preloaded and ready: buying opens it at once.
    if (compact || plan == null || !plan.ready) return button;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Pill(l10n.remedyReady, key: Key('remedy-ready-$topic'), icon: Icons.bolt),
        const SizedBox(width: Space.s),
        button,
      ],
    );
  }
}

/// Opens the plan for [topic]: the pay popup first if it isn't bought yet.
Future<void> openRemedy(
  BuildContext context,
  WidgetRef ref, {
  required String reportId,
  required String topic,
  required RemedyList list,
}) async {
  final l10n = AppLocalizations.of(context);
  final topicLabel = l10n.topic(topic);
  var remedy = list.items.where((r) => r.topic == topic && r.status != 'failed').firstOrNull;
  // Not bought yet (absent, or preloaded and locked): pay first; buying a preloaded plan only unlocks it.
  if (remedy == null || remedy.locked) {
    final pay = await showDialog<bool>(
      context: context,
      builder: (ctx) => compactButtons(
        ctx,
        AlertDialog(
          key: const Key('remedy-confirm'),
          icon: const Icon(Icons.auto_fix_high),
          title: Text(l10n.remedyConfirmTitle(topicLabel)),
          content: Text(
            list.points == null
                ? l10n.remedyConfirmBody(topicLabel, list.priceLabel)
                : l10n.remedyConfirmPoints(topicLabel, list.points!.points),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
            // Default action: pay (TODO Phase 4: real store purchase).
            FilledButton(
              key: const Key('remedy-pay'),
              autofocus: true,
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.remedyPay(_price(l10n, list))),
            ),
          ],
        ),
      ),
    );
    if (pay != true || !context.mounted) return;
    try {
      remedy = await ref.read(apiClientProvider).buyRemedy(reportId, topic);
    } catch (e) {
      if (context.mounted && !await showPointsShort(context, e) && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l10n.errorTitle}: $e')));
      }
      return;
    }
    ref.invalidate(remediesProvider(reportId));
    ref.invalidate(pointsProvider);
  }
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (_) => RemedyDialog(remedyId: remedy!.id, topic: topic),
  );
  ref.invalidate(remediesProvider(reportId));
}

/// The plan popup: live while generating, then the plan with save / send / print / copy.
class RemedyDialog extends ConsumerWidget {
  const RemedyDialog({super.key, required this.remedyId, required this.topic});
  final String remedyId;
  final String topic;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final r = ref.watch(remedyProvider(remedyId));
    final remedy = r.value;
    final title = l10n.remedyFor(l10n.topic(topic));

    return compactButtons(
      context,
      Dialog(
        key: const Key('remedy-dialog'),
        insetPadding: const EdgeInsets.all(Space.l),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640, maxHeight: 760),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.xl, Space.l, Space.s, 0),
                child: Row(
                  children: [
                    Icon(Icons.auto_fix_high, color: scheme.primary),
                    const SizedBox(width: Space.s),
                    Expanded(child: Text(title, style: theme.textTheme.titleLarge)),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                  ],
                ),
              ),
              if (remedy?.paymentStatus == 'placeholder')
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.xl),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Pill(l10n.remedyDemoPaid, icon: Icons.receipt_long_outlined),
                  ),
                ),
              Flexible(
                child: switch (remedy) {
                  null when r.hasError => _centered(context, '${l10n.errorTitle}\n${r.error}'),
                  null || RemedyView(status: 'pending') => _Generating(text: l10n.remedyGenerating(l10n.topic(topic))),
                  RemedyView(hasContent: true) => _PlanBody(remedy: remedy),
                  RemedyView(status: 'failed') => _centered(context, l10n.remedyFailed),
                  _ => _centered(context, l10n.remedyHeld),
                },
              ),
              if (remedy != null && remedy.hasContent) _Actions(remedy: remedy, title: title),
            ],
          ),
        ),
      ),
    );
  }

  Widget _centered(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.all(Space.xxl),
    child: Text(text, textAlign: TextAlign.center),
  );
}

class _Generating extends StatelessWidget {
  const _Generating({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    key: const Key('remedy-generating'),
    padding: const EdgeInsets.all(Space.xxl),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: Space.l),
        Text(text, textAlign: TextAlign.center),
      ],
    ),
  );
}

class _PlanBody extends StatelessWidget {
  const _PlanBody({required this.remedy});
  final RemedyView remedy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final body = ReadingText.body(context);
    Widget heading(String s) => Padding(
      padding: const EdgeInsets.only(top: Space.l, bottom: Space.s),
      child: Text(s, style: theme.textTheme.titleMedium?.copyWith(color: scheme.primary)),
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Space.xl, Space.s, Space.xl, Space.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          heading(l10n.remedyTarget),
          Container(
            key: const Key('remedy-target'),
            width: double.infinity,
            padding: const EdgeInsets.all(Space.m),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(Radii.field),
            ),
            child: Text(remedy.target!, style: body?.copyWith(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: Space.s),
          Text(remedy.summary ?? '', style: body),
          if (remedy.focusPeriods.isNotEmpty) ...[
            heading(l10n.remedyFocus),
            Wrap(
              spacing: Space.s,
              runSpacing: Space.s,
              children: [for (final p in remedy.focusPeriods) Pill(p, icon: Icons.event_outlined)],
            ),
          ],
          heading(l10n.remedySteps),
          for (final (i, s) in remedy.steps.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.m),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 13,
                    backgroundColor: scheme.primary,
                    child: Text('${i + 1}', style: theme.textTheme.labelMedium?.copyWith(color: scheme.onPrimary)),
                  ),
                  const SizedBox(width: Space.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${s.title} · ${l10n.horizon(s.horizon)}', style: theme.textTheme.titleSmall),
                        const SizedBox(height: Space.xs),
                        Text(s.text, style: body),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          heading(l10n.remedyBasis),
          Text(remedy.basis ?? '', style: body),
          const SizedBox(height: Space.l),
          Text(remedy.closing ?? '', style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

/// Save (download .md), send (share), print, copy.
class _Actions extends StatelessWidget {
  const _Actions({required this.remedy, required this.title});
  final RemedyView remedy;
  final String title;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final headings = {'target': l10n.remedyTarget, 'focus': l10n.remedyFocus, 'steps': l10n.remedySteps, 'basis': l10n.remedyBasis};
    String md() =>
        exportRemedyMarkdown(remedy: remedy, title: title, aiLabel: l10n.aiBadge, horizonLabel: l10n.horizon, headings: headings);
    final name = 'mingli-remedy-${remedy.topic}-${remedy.id.substring(0, 8)}.md';
    final messenger = ScaffoldMessenger.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.l, 0, Space.l, Space.l),
      child: Wrap(
        alignment: WrapAlignment.end,
        spacing: Space.s,
        runSpacing: Space.s,
        children: [
          OutlinedButton.icon(
            key: const Key('remedy-save'),
            icon: const Icon(Icons.download_outlined),
            label: Text(l10n.remedySave),
            onPressed: () => SharePlus.instance.share(
              ShareParams(
                files: [XFile.fromData(utf8.encode(md()), mimeType: 'text/markdown', name: name)],
                fileNameOverrides: [name],
                subject: title,
              ),
            ),
          ),
          OutlinedButton.icon(
            key: const Key('remedy-send'),
            icon: const Icon(Icons.send_outlined),
            label: Text(l10n.remedySend),
            onPressed: () => SharePlus.instance.share(ShareParams(text: md(), subject: title)),
          ),
          OutlinedButton.icon(
            key: const Key('remedy-print'),
            icon: const Icon(Icons.print_outlined),
            label: Text(l10n.remedyPrint),
            onPressed: () async {
              final html = printableHtml(
                title: title,
                sections: [
                  (l10n.remedyTarget, [remedy.target!, remedy.summary ?? '']),
                  if (remedy.focusPeriods.isNotEmpty) (l10n.remedyFocus, remedy.focusPeriods),
                  (
                    l10n.remedySteps,
                    [for (final (i, s) in remedy.steps.indexed) '${i + 1}. ${s.title}（${l10n.horizon(s.horizon)}）：${s.text}'],
                  ),
                  (l10n.remedyBasis, [remedy.basis ?? '']),
                ],
                footer: '${remedy.closing ?? ''} · ${l10n.aiBadge}',
              );
              // Mobile/desktop: the share sheet offers printing.
              if (!await printHtml(html)) await SharePlus.instance.share(ShareParams(text: md(), subject: title));
            },
          ),
          FilledButton.tonalIcon(
            key: const Key('remedy-copy'),
            icon: const Icon(Icons.copy_all_outlined),
            label: Text(l10n.copyAll),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: md()));
              messenger.showSnackBar(SnackBar(content: Text(l10n.copied)));
            },
          ),
        ],
      ),
    );
  }
}
