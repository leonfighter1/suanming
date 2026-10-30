import 'package:flutter/material.dart';

import '../../domain/life_report.dart';
import '../../l10n/gen/app_localizations.dart';
import '../design.dart';
import '../life_export.dart';
import '../theme.dart' show wuxingColorOf;
import '../tokens.dart';

// A hexagram's drawing: its own geometry, not the interface's spacing (the ui-design skill). Each line is 11 high with
// 3.5 above and below; a broken line's halves leave 14 between them.
const _lineGap = 3.5;
const _breakWidth = 14.0;

/// Six lines drawn top (上爻) to bottom (初爻); the 命爻 in the accent colour.
class HexagramFigure extends StatelessWidget {
  const HexagramFigure({super.key, required this.hexagram, required this.caption, this.moving});
  final Hexagram hexagram;
  final String caption;
  final int? moving;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      key: Key('hex-${hexagram.id}'),
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 96,
          child: Column(
            children: [
              for (var line = 6; line >= 1; line--)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: _lineGap),
                  child: Row(
                    children: [
                      Expanded(child: _bar(moving == line ? scheme.error : scheme.onSurface)),
                      if (!hexagram.yang(line)) ...[
                        const SizedBox(width: _breakWidth),
                        Expanded(child: _bar(moving == line ? scheme.error : scheme.onSurface)),
                      ] else
                        const SizedBox.shrink(),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: Space.s),
        Text(hexagram.fullName, style: Theme.of(context).textTheme.titleSmall),
        Text(caption, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
      ],
    );
  }

  Widget _bar(Color c) => Container(
    height: 11,
    decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(Radii.xxs)),
  );
}

/// One line (爻) of the 本命卦: its position, ages, text and reading; the 命爻 outlined.
class LifeLineRow extends StatelessWidget {
  const LifeLineRow({super.key, required this.line, required this.reading, required this.mingYao, required this.ageLabel});
  final HexLine line;
  final String reading;
  final String mingYao;
  final String ageLabel;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: Space.s),
      padding: const EdgeInsets.all(Space.m),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.field),
        border: Border.all(color: line.moving ? scheme.error : scheme.outlineVariant, width: line.moving ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(line.position, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(width: Space.s),
              Pill('$ageLabel ${line.ages}', icon: Icons.schedule),
              if (line.moving) ...[const SizedBox(width: Space.s), Pill(mingYao, icon: Icons.star, color: scheme.error)],
            ],
          ),
          const SizedBox(height: Space.s),
          Text(
            line.text.split(RegExp('[：:]')).skip(1).join('：'),
            style: ReadingText.small(context)?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: Space.xs),
          Text(reading, style: ReadingText.body(context)),
        ],
      ),
    );
  }
}

/// 梅花易数: 体, 用, 互 and 变卦, each with its 五行, its relation to the 体 and its stage of life.
class MeihuaTable extends StatelessWidget {
  const MeihuaTable({super.key, required this.facts});
  final LifeFacts facts;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final f = facts;
    final rows = [
      (l10n.lifeTi, f.trigram(f.ti.trigram), f.ti.wuxing, l10n.lifeSelf, '—'),
      (l10n.lifeYong, f.trigram(f.yong.trigram), f.yong.wuxing, relationLabel(l10n, f.yong.relation), l10n.lifeEarly),
      for (final h in f.hu) (l10n.lifeHu, f.trigram(h.trigram), h.wuxing, relationLabel(l10n, h.relation), l10n.lifeMiddle),
      (l10n.lifeBian, f.trigram(f.bian.trigram), f.bian.wuxing, relationLabel(l10n, f.bian.relation), l10n.lifeLate),
    ];
    return Column(
      children: [
        for (final (role, tri, wx, rel, stage) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.xs),
            child: Row(
              children: [
                SizedBox(
                  width: 72,
                  child: Text(role, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                ),
                CircleAvatar(
                  radius: 18,
                  backgroundColor: wuxingColorOf(context, wx).withValues(alpha: 0.15),
                  child: Text(
                    tri.name,
                    style: TextStyle(color: wuxingColorOf(context, wx), fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: Space.s),
                SizedBox(width: 56, child: Text('${tri.image} · $wx')),
                Expanded(child: Text(rel, style: theme.textTheme.bodyMedium)),
                Text(stage, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
      ],
    );
  }
}

/// The 五行 distribution as bars, each in its element's colour.
class LifeWuxingBars extends StatelessWidget {
  const LifeWuxingBars({super.key, required this.scores});
  final Map<String, double> scores;
  @override
  Widget build(BuildContext context) {
    final order = ['木', '火', '土', '金', '水'];
    final max = scores.values.fold<double>(0.01, (a, b) => a > b ? a : b);
    return Column(
      key: const Key('life-wuxing-bars'),
      children: [
        for (final wx in order)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.xs),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    wx,
                    style: TextStyle(fontWeight: FontWeight.w700, color: wuxingColorOf(context, wx)),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(Radii.xs),
                    child: LinearProgressIndicator(
                      value: (scores[wx] ?? 0) / max,
                      minHeight: 12,
                      color: wuxingColorOf(context, wx),
                      backgroundColor: wuxingColorOf(context, wx).withValues(alpha: 0.12),
                    ),
                  ),
                ),
                SizedBox(width: 44, child: Text((scores[wx] ?? 0).toStringAsFixed(1), textAlign: TextAlign.end)),
              ],
            ),
          ),
      ],
    );
  }
}

/// 八宅: the eight directions on a 3×3 grid (north at the top), 吉 green, 凶 red.
class BazhaiCompass extends StatelessWidget {
  const BazhaiCompass({super.key, required this.facts, required this.hant});
  final LifeFacts facts;
  final bool hant;

  static const _layout = [
    ['西北', '北', '东北'],
    ['西', '', '东'],
    ['西南', '南', '东南'],
  ];
  static const _hantDir = {'东北': '東北', '东': '東', '东南': '東南'};

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // A good direction in the success colours, a bad one in danger's; the star and 吉 or 凶 say it in words too.
    final t = ThemeTokens.of(context);
    BazhaiDirection? at(String dir) =>
        facts.directions.where((d) => d.direction == dir || d.direction == (_hantDir[dir] ?? dir)).firstOrNull;
    return Column(
      key: const Key('life-bazhai'),
      children: [
        for (final row in _layout)
          Row(
            children: [
              for (final dir in row)
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 1.25,
                    child: Container(
                      margin: const EdgeInsets.all(Space.xs),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(Radii.chip),
                        color: dir.isEmpty
                            ? scheme.primaryContainer
                            : at(dir)!.good
                                ? t.successSoft
                                : t.dangerSoft,
                      ),
                      child: Center(
                        child: dir.isEmpty
                            ? Text(
                                facts.trigram(facts.kuaTrigram).name,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w800, color: scheme.onPrimaryContainer),
                              )
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(hant ? (_hantDir[dir] ?? dir) : dir, style: Theme.of(context).textTheme.labelMedium),
                                  Text(
                                    hantTerm(at(dir)!.star, hant),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: at(dir)!.good ? t.success : t.danger,
                                    ),
                                  ),
                                  Text(at(dir)!.luck, style: Theme.of(context).textTheme.bodySmall),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
