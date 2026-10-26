import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../application/providers.dart';
import '../domain/models.dart';
import '../l10n/gen/app_localizations.dart';
import 'design.dart';
import 'report_page.dart';
import 'theme.dart';

/// All earlier readings, newest first. Pull down to refresh.
class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final history = ref.watch(historyProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.history)),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(historyProvider.future),
        child: history.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(padding: Space.page, children: [Text('$e')]),
          data: (items) => items.isEmpty
              ? ListView(
                  padding: Space.page,
                  children: [
                    const SizedBox(height: 120),
                    Icon(Icons.history_toggle_off, size: 56, color: Theme.of(context).colorScheme.outline),
                    const SizedBox(height: Space.l),
                    Text(l10n.historyEmpty, textAlign: TextAlign.center),
                  ],
                )
              : ListView.builder(
                  padding: Space.page,
                  itemCount: items.length,
                  itemBuilder: (_, i) => FadeSlideIn(index: i, child: HistoryTile(item: items[i])),
                ),
        ),
      ),
    );
  }
}

/// The latest three readings on the home screen.
class RecentHistory extends ConsumerWidget {
  const RecentHistory({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final items = ref.watch(historyProvider).value ?? const [];
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: items.isEmpty
          ? const SizedBox.shrink()
          : Column(
              key: ValueKey(items.length),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(Space.xs, Space.l, Space.xs, Space.s),
                  child: Row(
                    children: [
                      Expanded(child: Text(l10n.recent, style: Theme.of(context).textTheme.titleMedium)),
                      TextButton(
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const HistoryPage())),
                        child: Text(l10n.viewAll),
                      ),
                    ],
                  ),
                ),
                for (final it in items.take(3)) HistoryTile(item: it),
              ],
            ),
    );
  }
}

class HistoryTile extends ConsumerWidget {
  const HistoryTile({super.key, required this.item});
  final HistoryItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(settingsProvider).apiLocaleCode;
    final terms = ref.watch(termsProvider).value;
    final label = ref.watch(profilesProvider).value?.chartLabels[item.chartId];
    final scheme = Theme.of(context).colorScheme;
    final (statusText, statusColor) = switch (item.status) {
      'passed' => (l10n.aiReport, scheme.primary),
      'pending' => (l10n.analyzing, scheme.tertiary),
      'failed' => (l10n.statusFailed, scheme.error),
      _ => (l10n.statusReview, scheme.outline),
    };
    final title = item.system == 'bazi'
        ? (label == null ? l10n.homeBazi : l10n.chartOf(label))
        : l10n.homeTarot;
    return AppCard(
      padding: const EdgeInsets.all(Space.l),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => ReportPage(reportId: item.reportId, title: title)),
      ),
      child: Row(
        children: [
          Icon(item.system == 'bazi' ? Icons.grid_view_rounded : Icons.style_rounded, color: scheme.primary),
          const SizedBox(width: Space.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: Space.xs),
                if (item.fourPillars != null)
                  GanZhiText(item.fourPillars!, size: 15)
                else if (item.cardIds.isNotEmpty)
                  Text(
                    item.cardIds.map((c) => terms?.card(c, locale) ?? c).join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: Space.xs),
                Text(
                  DateFormat('yyyy-MM-dd HH:mm').format(item.createdAt.toLocal()),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Pill(statusText, color: statusColor),
        ],
      ),
    );
  }
}
