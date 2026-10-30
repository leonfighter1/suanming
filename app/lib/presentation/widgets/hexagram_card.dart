import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../domain/models.dart';
import '../../l10n/gen/app_localizations.dart';
import '../design.dart';

// A hexagram's drawing: its own geometry, not the interface's spacing (the ui-design skill). Each line is 9 high with
// 3.5 above and below, so six make 96; the moving mark has room at the right, and as much at the left keeps the lines
// centred. The arrow between 本卦 and 變卦 sits level with the lines' middle, below the sides' titles.
const _lineGap = 3.5;
const _markRoom = 18.0;
const _arrowDrop = 64.0;

/// A line's name: 初九, 六二 … 上六 (yang 九, yin 六); 7 is 用九 / 用六.
String lineName(int position, bool yang) {
  const places = ['初', '二', '三', '四', '五', '上'];
  final n = yang ? '九' : '六';
  if (position == 7) return '用$n';
  return position == 1 || position == 6 ? '${places[position - 1]}$n' : '$n${places[position - 1]}';
}

/// 算卦 (v6.0.0): the cast at a glance. The 本卦 and, when lines move, the 變卦, drawn from the 上爻 down with
/// the moving lines marked; their numbers, names and trigrams; the cast time and its 干支; then the texts the
/// reading rests on (朱熹), each with its 直說, said straight out as the owner asks.
class HexagramCard extends ConsumerWidget {
  const HexagramCard({super.key, required this.chart});
  final LiuyaoChart chart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(settingsProvider).apiLocaleCode;
    final table = ref.watch(termsProvider).value?.liuyao;
    final theme = Theme.of(context);
    final changed = chart.changed;
    final moving = [
      for (final (i, v) in chart.values.indexed)
        if (LiuyaoChart.moving(v)) lineName(i + 1, LiuyaoChart.yang(v)),
    ];
    Widget side(String label, LiuyaoHexagram h, List<int> values, {required bool marks}) => Column(
          children: [
            Text(label, style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),
            const SizedBox(height: Space.s),
            HexagramLines(values: values, marks: marks),
            const SizedBox(height: Space.s),
            Text(l10n.liuyaoNumber(h.number), style: theme.textTheme.bodySmall),
            Text(h.fullName(locale), style: theme.textTheme.titleMedium),
            Text(
              l10n.liuyaoTrigrams(table?.trigram(h.upper, locale) ?? h.upper, table?.trigram(h.lower, locale) ?? h.lower),
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        );
    final g = chart.ganzhi;
    return AppCard(
      title: l10n.topicLiuyaoHexagram,
      icon: Icons.toll_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                key: const Key('hexagram-primary'),
                child: side(l10n.liuyaoPrimary, chart.primary, chart.values, marks: true),
              ),
              if (changed != null) ...[
                Padding(
                  padding: const EdgeInsets.only(top: _arrowDrop),
                  child: Icon(Icons.arrow_forward, color: theme.colorScheme.outline),
                ),
                Expanded(
                  key: const Key('hexagram-changed'),
                  child: side(
                    l10n.liuyaoChanged,
                    changed,
                    [for (final c in changed.id.split('')) c == '1' ? 7 : 8],
                    marks: false,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: Space.m),
          Text(
            l10n.liuyaoCastAt(chart.castLocal.replaceFirst('T', ' '), g.year, g.month, g.day, g.hour),
            key: const Key('liuyao-cast-at'),
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: Space.xs),
          Text(
            moving.isEmpty ? l10n.liuyaoStill : l10n.liuyaoMoving(moving.join('、')),
            key: const Key('liuyao-moving'),
            style: theme.textTheme.bodyMedium,
          ),
          for (final (i, t) in chart.focus.indexed)
            Padding(
              key: ValueKey<String>('liuyao-focus-$i'),
              padding: const EdgeInsets.only(top: Space.m),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${t.ofChanged ? l10n.liuyaoChanged : l10n.liuyaoPrimary} · ${t.main ? l10n.liuyaoMain : l10n.liuyaoAlso}',
                    style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary),
                  ),
                  const SizedBox(height: Space.xs),
                  Text(t.text(locale), style: theme.textTheme.titleSmall),
                  if (table?.plain((t.ofChanged ? changed! : chart.primary).id, t.line, locale) case final plain?) ...[
                    const SizedBox(height: Space.xs),
                    Text(
                      '${l10n.liuyaoPlain}：$plain',
                      key: ValueKey<String>('liuyao-plain-$i'),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Six lines drawn from the 上爻 (top) down to the 初爻: yang one bar, yin two. With [marks], a moving line is
/// in the accent colour with ○ (老陽) or × (老陰) beside it. [values] are 初爻 first, 6–9; fewer than six while a
/// cast is being revealed.
class HexagramLines extends StatelessWidget {
  const HexagramLines({super.key, required this.values, this.marks = true, this.width = 72, this.room = _markRoom});
  final List<int> values;
  final bool marks;
  final double width;

  /// The room at each side for a moving line's mark; none for a picture without marks (今日一卦 on 首页, S26).
  final double room;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget bar(double w, Color c) =>
        Container(width: w, height: 9, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(Radii.xxs)));
    Widget line(int v) {
      final moves = marks && LiuyaoChart.moving(v);
      final colour = moves ? scheme.primary : scheme.onSurface;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: _lineGap),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: room),
            if (LiuyaoChart.yang(v))
              bar(width, colour)
            else ...[
              bar(width * 0.42, colour),
              SizedBox(width: width * 0.16),
              bar(width * 0.42, colour),
            ],
            SizedBox(
              width: room,
              child: moves
                  ? Text(v == 9 ? '○' : '×', textAlign: TextAlign.center, style: TextStyle(color: scheme.primary))
                  : null,
            ),
          ],
        ),
      );
    }

    return ExcludeSemantics(
      child: Column(
        key: const Key('hexagram-lines'),
        mainAxisSize: MainAxisSize.min,
        // The 上爻 at the top: the first value is drawn last, at the bottom.
        children: [for (final v in values.reversed) line(v)],
      ),
    );
  }
}
