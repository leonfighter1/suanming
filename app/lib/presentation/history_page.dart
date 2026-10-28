import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../application/providers.dart';
import '../domain/life_report.dart';
import '../domain/models.dart';
import '../l10n/gen/app_localizations.dart';
import 'design.dart';
import 'life_report_page.dart';
import 'report_page.dart';
import 'theme.dart';
import 'widgets/tarot_spread.dart';

/// All earlier readings, newest first. Pull down to refresh.
class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final history = ref.watch(historyProvider);
    final lives = ref.watch(lifeReportsProvider).value ?? const <LifeReportView>[];
    final labels = ref.watch(profilesProvider).value?.chartLabels ?? const {};
    return Scaffold(
      appBar: AppBar(title: Text(l10n.history)),
      body: RefreshIndicator(
        onRefresh: () {
          ref.invalidate(lifeReportsProvider);
          return ref.refresh(historyProvider.future);
        },
        child: history.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(padding: Space.page, children: [Text('$e')]),
          data: (items) => items.isEmpty && lives.isEmpty
              ? ListView(
                  padding: Space.page,
                  children: [
                    const SizedBox(height: 120),
                    Icon(Icons.history_toggle_off, size: 56, color: Theme.of(context).colorScheme.outline),
                    const SizedBox(height: Space.l),
                    Text(l10n.historyEmpty, textAlign: TextAlign.center),
                  ],
                )
              : ListView(
                  padding: Space.page,
                  children: [
                    // 一生运势报告 first: they are the long, kept documents.
                    for (final (i, r) in lives.indexed)
                      FadeSlideIn(
                        index: i,
                        child: AppCard(
                          key: Key('history-life-${r.id}'),
                          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => LifeReportPage(reportId: r.id))),
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.auto_stories),
                            title: Text(labels[r.chartId] == null ? l10n.lifeEntry : l10n.lifeReportOf(labels[r.chartId]!)),
                            subtitle: Text(r.createdAt == null ? '' : DateFormat('yyyy-MM-dd HH:mm').format(r.createdAt!.toLocal())),
                            trailing: const Icon(Icons.chevron_right),
                          ),
                        ),
                      ),
                    for (final (i, it) in items.indexed) FadeSlideIn(index: lives.length + i, child: HistoryTile(item: it)),
                  ],
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
    final room = item.room == null ? null : terms?.fengshui?.roomName(item.room!, locale);
    final surname = item.surname(locale);
    final title = switch (item.system) {
      'bazi' => label == null ? l10n.homeBazi : l10n.chartOf(label),
      'qiuqian' => l10n.homeQiuqian,
      'fengshui' => room == null ? l10n.homeFengshui : '${l10n.homeFengshui} · $room',
      'naming' => surname == null ? l10n.homeNaming : '${l10n.homeNaming} · $surname',
      _ => l10n.homeTarot,
    };
    final lot = item.lotNumber == null ? null : terms?.lots?.lot(item.lotNumber!);
    return AppCard(
      padding: const EdgeInsets.all(Space.l),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ReportPage(
            reportId: item.reportId,
            title: title,
            place: ref.read(profilesProvider).value?.chartPlaces[item.chartId],
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            switch (item.system) {
              'bazi' => Icons.grid_view_rounded,
              'qiuqian' => Icons.temple_buddhist_outlined,
              'fengshui' => Icons.explore_outlined,
              'naming' => Icons.badge_outlined,
              _ => Icons.style_rounded,
            },
            color: scheme.primary,
          ),
          const SizedBox(width: Space.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: Space.xs),
                if (item.fourPillars != null)
                  GanZhiText(item.fourPillars!, size: 15)
                else if (lot != null)
                  // 求籤: the lot's title and label, and the poem's first line.
                  Text(
                    '${lot.title(locale)} · ${lot.ganzhi} · ${lot.poem(locale).first}',
                    key: const Key('history-lot'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                else if (item.cardIds.isNotEmpty) ...[
                  // The cards' art, small (v2.4.0); a reversed card upside down, as it was drawn.
                  Row(
                    key: const Key('history-art'),
                    children: [
                      for (final (i, id) in item.cardIds.take(5).indexed)
                        Padding(
                          padding: const EdgeInsets.only(right: Space.xs),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: RotatedBox(
                              quarterTurns: i < item.cardsReversed.length && item.cardsReversed[i] ? 2 : 0,
                              child: Image.asset(
                                tarotArt(id),
                                width: 22,
                                height: 38,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const SizedBox(width: 22, height: 38),
                              ),
                            ),
                          ),
                        ),
                      if (item.cardIds.length > 5)
                        Text('+${item.cardIds.length - 5}', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                  const SizedBox(height: Space.xs),
                  Text(
                    item.cardIds.map((c) => terms?.card(c, locale) ?? c).join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
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
