import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/providers.dart';
import '../domain/models.dart';
import '../l10n/gen/app_localizations.dart';
import 'design.dart';
import 'layout.dart';
import 'tokens.dart';
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
    final locale = ref.watch(settingsProvider).apiLocaleCode;
    final terms = ref.watch(termsProvider).value;
    final c = chart.tarot.cards.first;
    return DayCardTile(
      cardKey: const Key('daily-card'),
      title: l10n.dailyCard,
      art: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.xs),
        // Reversed upside down, as it was drawn.
        child: RotatedBox(
          quarterTurns: c.reversed ? 2 : 0,
          child: Image.asset(
            tarotArt(c.cardId),
            width: _artWidth,
            height: _artHeight,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const SizedBox(width: _artWidth, height: _artHeight),
          ),
        ),
      ),
      name: [terms?.card(c.cardId, locale) ?? c.cardId, if (c.reversed) l10n.reversed].join(' · '),
      nameKey: const Key('daily-card-name'),
      hint: l10n.dailyCardHint,
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => DailyCardPage(chart: chart))),
    );
  }
}

// A card of the day's picture: a tarot card's size.
const _artWidth = 44.0;
const _artHeight = 76.0;

/// A card of the day on 首页 (S28: 今日一牌 and 今日一卦 / 今日一签 had a copy each): its picture, its name and what to do
/// with it, opening its page. [cardKey] is the card's own, as tests and Tab find it.
class DayCardTile extends StatelessWidget {
  const DayCardTile({
    super.key,
    required this.cardKey,
    required this.title,
    required this.art,
    required this.name,
    required this.nameKey,
    required this.hint,
    required this.onTap,
  });
  final Key cardKey;
  final String title;
  final Widget art;
  final String name;
  final Key nameKey;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = ThemeTokens.of(context);
    return AppCard(
      key: cardKey,
      title: title,
      icon: Icons.wb_sunny_outlined,
      onTap: onTap,
      child: Row(
        children: [
          SizedBox(width: _artWidth, height: _artHeight, child: art),
          const SizedBox(width: Space.l),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, key: nameKey, style: theme.textTheme.titleMedium),
                const SizedBox(height: Space.xs),
                Text(hint, style: theme.textTheme.bodyMedium?.copyWith(color: t.textSecondary)),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: t.textSecondary),
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
        padding: pagePadding(context),
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
