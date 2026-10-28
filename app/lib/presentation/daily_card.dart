import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/providers.dart';
import '../domain/models.dart';
import '../l10n/gen/app_localizations.dart';
import 'design.dart';
import 'widgets/report_request.dart';
import 'widgets/tarot_spread.dart';

/// 每日一牌 on 首页 (v2.6.0): the account's card of the day, the same all day. It hides itself
/// when there is none to be had (offline, or tarot not served in the region).
class DailyCard extends ConsumerWidget {
  const DailyCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chart = ref.watch(dailyCardProvider).value;
    if (chart == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final locale = ref.watch(settingsProvider).apiLocaleCode;
    final terms = ref.watch(termsProvider).value;
    final c = chart.tarot.cards.first;
    return AppCard(
      key: const Key('daily-card'),
      title: l10n.dailyCard,
      icon: Icons.wb_sunny_outlined,
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => DailyCardPage(chart: chart))),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            // Reversed upside down, as it was drawn.
            child: RotatedBox(
              quarterTurns: c.reversed ? 2 : 0,
              child: Image.asset(
                tarotArt(c.cardId),
                width: 44,
                height: 76,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox(width: 44, height: 76),
              ),
            ),
          ),
          const SizedBox(width: Space.l),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  [terms?.card(c.cardId, locale) ?? c.cardId, if (c.reversed) l10n.reversed].join(' · '),
                  key: const Key('daily-card-name'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: Space.xs),
                Text(l10n.dailyCardHint, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
        ],
      ),
    );
  }
}

/// The day's card large, as a one-card spread, with an AI reading of it.
class DailyCardPage extends StatelessWidget {
  const DailyCardPage({super.key, required this.chart});
  final ChartResult chart;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tarot = chart.tarot;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.dailyCard)),
      body: ListView(
        padding: Space.page,
        children: [
          FadeSlideIn(
            child: AppCard(
              key: const Key('daily-card-spread'),
              child: TarotSpread(chart: tarot, revealed: {for (final c in tarot.cards) c.position}, onReveal: (_) {}),
            ),
          ),
          FadeSlideIn(index: 1, child: ReportRequest(chartId: chart.chartId, system: 'tarot', title: l10n.dailyCard)),
        ],
      ),
    );
  }
}
