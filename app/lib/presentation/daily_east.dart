import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/providers.dart';
import '../domain/models.dart';
import '../l10n/gen/app_localizations.dart';
import 'design.dart';
import 'layout.dart';
import 'tokens.dart';
import 'widgets/hexagram_card.dart';
import 'widgets/lot_card.dart';
import 'widgets/report_request.dart';

// The picture beside the name: as large as 每日一牌's card (daily_card.dart).
const _artWidth = 44.0;
const _artHeight = 76.0;

/// 今日一卦 / 今日一签 on 首页, under 东方 (S26; owner, 2026-10-30: 「东方系列，我们剋增加今日一卦或者今日一签功能，可以随机
/// 出现」): the account's 东方 draw of the day, a 签 or a 卦 as the server deals it, the same all day. It hides itself when
/// there is none to be had (offline, or neither 求签 nor 算卦 served in the region).
class EastDailyCard extends ConsumerWidget {
  const EastDailyCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chart = ref.watch(eastDailyProvider).value;
    if (chart == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final t = ThemeTokens.of(context);
    final locale = ref.watch(settingsProvider).apiLocaleCode;
    final lot = chart.system == 'qiuqian';
    final String name;
    final Widget art;
    if (lot) {
      // The lot's title and label, as its slip has them: 第八十九籤 · 壬壬.
      final n = chart.qiuqian.lotNumber;
      final found = ref.watch(termsProvider).value?.lots?.lot(n);
      name = found == null ? '$n' : '${found.title(locale)} · ${found.ganzhi}';
      art = LotSlip(label: found?.ganzhi ?? '$n');
    } else {
      // The 本卦 and, when lines move, the 變卦: 第13卦 · 天火同人 → 乾為天.
      final cast = chart.liuyao;
      name = [
        '${l10n.liuyaoNumber(cast.primary.number)} · ${cast.primary.fullName(locale)}',
        if (cast.changed case final changed?) changed.fullName(locale),
      ].join(' → ');
      art = FittedBox(child: HexagramLines(values: cast.values, marks: false, room: 0));
    }
    return AppCard(
      key: const Key('east-daily'),
      title: lot ? l10n.dailyLot : l10n.dailyHexagram,
      icon: Icons.wb_sunny_outlined,
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => EastDailyPage(chart: chart))),
      child: Row(
        children: [
          SizedBox(width: _artWidth, height: _artHeight, child: art),
          const SizedBox(width: Space.l),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, key: const Key('east-daily-name'), style: theme.textTheme.titleMedium),
                const SizedBox(height: Space.xs),
                Text(
                  lot ? l10n.dailyLotHint : l10n.dailyHexagramHint,
                  style: theme.textTheme.bodyMedium?.copyWith(color: t.textSecondary),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: t.textSecondary),
        ],
      ),
    );
  }
}

/// The day's 签 or 卦 as its method shows it, with an AI reading of it: read as that method reads (its own prompts,
/// rule 8), without a question, since nothing was drawn for one.
class EastDailyPage extends ConsumerWidget {
  const EastDailyPage({super.key, required this.chart});
  final ChartResult chart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(settingsProvider).apiLocaleCode;
    final lot = chart.system == 'qiuqian';
    final title = lot ? l10n.dailyLot : l10n.dailyHexagram;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: pagePadding(context),
        children: [
          FadeSlideIn(
            child: lot
                ? LotCard(key: const Key('east-daily-lot'), lotNumber: chart.qiuqian.lotNumber)
                : HexagramCard(key: const Key('east-daily-hexagram'), chart: chart.liuyao),
          ),
          FadeSlideIn(
            index: 1,
            child: ReportRequest(
              chartId: chart.chartId,
              system: chart.system,
              title: lot ? title : '$title · ${chart.liuyao.primary.fullName(locale)}',
            ),
          ),
        ],
      ),
    );
  }
}
