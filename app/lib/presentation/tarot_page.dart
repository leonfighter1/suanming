import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/providers.dart';
import '../domain/models.dart';
import '../l10n/gen/app_localizations.dart';
import 'design.dart';
import 'keyboard.dart';
import 'widgets/report_request.dart';

// A card has the art's own shape, 7:12 (app/assets/tarot, made by `npm run mirror:tarot`).
// Cards and the text around them are drawn at a scale of the first 104-pt card: twice it
// where there is room (owner), less on a phone so that two cards still share a row.
// The corners stay small enough not to cut the gold frame painted 16/700 in from the edge.
const _baseWidth = 104.0;

/// Two cards side by side in [width], at most twice the first size.
double _scaleFor(double width) => ((width - Space.m) / 2 / _baseWidth).clamp(1.0, 2.0);

// The deck's own colours (JingyaoPaint tarot_card.dart), so the back matches the faces
// in light and dark alike, as a real deck would.
const _navy = Color(0xFF1E2546);
const _navyLight = Color(0xFF34407A);
const _gold = Color(0xFFE4BC62);

String _art(String cardId) => 'assets/tarot/$cardId.webp';

class TarotPage extends ConsumerStatefulWidget {
  const TarotPage({super.key});

  @override
  ConsumerState<TarotPage> createState() => _TarotPageState();
}

class _TarotPageState extends ConsumerState<TarotPage> {
  String _spread = 'three_card';
  ChartResult? _chart;
  final Set<int> _revealed = {};
  bool _busy = false;

  Future<void> _draw() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final chart = await ref.read(apiClientProvider).createChart({'system': 'tarot', 'spread': _spread});
      if (!mounted) return; // left the page meanwhile
      setState(() {
        _chart = chart;
        _revealed.clear();
      });
      // Load the pictures while the cards lie face down, so each one is there as it turns.
      for (final c in chart.tarot.cards) {
        precacheImage(AssetImage(_art(c.cardId)), context, onError: (_, _) {});
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final chart = _chart;
    // A draw can't be repeated as it was: once cards are out, ask before leaving.
    return LeaveGuard(
      active: chart != null,
      message: l10n.leaveTarotBody,
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.homeTarot)),
        body: ListView(
          padding: Space.page,
          children: [
            FadeSlideIn(
              child: HeroBanner(title: l10n.homeTarot, subtitle: l10n.homeTarotDesc, icon: Icons.style_rounded),
            ),
            FadeSlideIn(
              index: 1,
              child: AppCard(
                title: l10n.spread,
                icon: Icons.dashboard_customize_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownMenu<String>(
                      key: const Key('spread'),
                      expandedInsets: EdgeInsets.zero,
                      initialSelection: _spread,
                      dropdownMenuEntries: [
                        DropdownMenuEntry(value: 'single', label: l10n.spreadSingle),
                        DropdownMenuEntry(value: 'three_card', label: l10n.spreadThree),
                        DropdownMenuEntry(value: 'celtic_cross', label: l10n.spreadCeltic),
                      ],
                      onSelected: (v) => setState(() => _spread = v ?? _spread),
                    ),
                    const SizedBox(height: Space.l),
                    FilledButton.icon(
                      key: const Key('draw'),
                      onPressed: _busy ? null : _draw,
                      icon: const Icon(Icons.style),
                      label: Text(l10n.draw),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: chart == null
                  ? const SizedBox.shrink()
                  : AppCard(
                      key: ValueKey(chart.chartId),
                      // The hint and every card's captions scale with the cards.
                      child: LayoutBuilder(
                        builder: (context, box) {
                          final scale = _scaleFor(box.maxWidth);
                          return DefaultTextStyle.merge(
                            style: TextStyle(
                              fontSize: (Theme.of(context).textTheme.bodyMedium?.fontSize ?? 14) * scale,
                            ),
                            child: Column(
                              children: [
                                Text(l10n.tapToReveal, textAlign: TextAlign.center),
                                const SizedBox(height: Space.l),
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: Space.m,
                                  runSpacing: Space.l,
                                  children: [
                                    for (final c in chart.tarot.cards)
                                      _FlipCard(
                                        key: Key('tarot-card-${c.position}'),
                                        card: c,
                                        scale: scale,
                                        revealed: _revealed.contains(c.position),
                                        onTap: () => setState(() => _revealed.add(c.position)),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
            ),
            if (chart != null && _revealed.length == chart.tarot.cards.length)
              FadeSlideIn(child: ReportRequest(chartId: chart.chartId, system: 'tarot', title: l10n.homeTarot)),
          ],
        ),
      ),
    );
  }
}

class _FlipCard extends ConsumerWidget {
  const _FlipCard({
    super.key,
    required this.card,
    required this.scale,
    required this.revealed,
    required this.onTap,
  });
  final TarotCardFact card;

  /// Times the first 104-pt card (see [_scaleFor]).
  final double scale;
  final bool revealed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(settingsProvider).apiLocaleCode;
    final terms = ref.watch(termsProvider).value;
    final scheme = Theme.of(context).colorScheme;
    final position = terms?.position(card.positionKey, locale) ?? card.positionKey;
    final name = terms?.card(card.cardId, locale) ?? card.cardId;
    // Rounded down, so two cards that fill a row exactly don't wrap on a rounding error.
    final width = (_baseWidth * scale).floorToDouble();
    final radius = 6 * scale;

    // Tab to a card, Enter or Space turns it over. Face down, only its position is read out.
    return Pressable(
      onPressed: onTap,
      label: revealed
          ? [position, name, if (card.reversed) l10n.reversed].join(locale == 'en' ? ', ' : '，')
          : l10n.cardHidden(position),
      child: Column(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(end: revealed ? 1 : 0),
            duration: const Duration(milliseconds: 500),
            builder: (context, v, _) {
              final showFace = v > 0.5;
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(pi * v),
                child: Container(
                  width: width,
                  height: width * 12 / 7,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius),
                    color: showFace ? scheme.surfaceContainerHighest : null,
                    gradient: showFace ? null : const RadialGradient(colors: [_navyLight, _navy]),
                    border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
                    boxShadow: [
                      BoxShadow(color: scheme.shadow.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 6)),
                    ],
                  ),
                  // Mirror the face back so the art reads correctly after the flip,
                  // and turn it upside down for a reversed card.
                  child: showFace
                      ? Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..rotateY(pi)
                            ..rotateZ(card.reversed ? pi : 0),
                          child: Image.asset(
                            _art(card.cardId),
                            fit: BoxFit.cover,
                            excludeFromSemantics: true, // the card's label says it
                            // Without its picture, a card shows its name.
                            errorBuilder: (_, _, _) => Padding(
                              padding: EdgeInsets.all((Space.s + 2) * scale),
                              child: Center(
                                child: Text(
                                  name,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ),
                        )
                      : Padding(
                          padding: EdgeInsets.all(5 * scale),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border.all(color: _gold.withValues(alpha: 0.8)),
                              borderRadius: BorderRadius.circular(radius - 5 * scale),
                            ),
                            child: Center(child: Icon(Icons.auto_awesome, color: _gold, size: 24 * scale)),
                          ),
                        ),
                ),
              );
            },
          ),
          SizedBox(height: 4 * scale),
          // The name in the reader's language: the art's own is small and in 简体.
          // Read out through the card's label above.
          ExcludeSemantics(
            child: SizedBox(
              width: width,
              child: Column(
                children: [
                  Text(position, textAlign: TextAlign.center),
                  if (revealed)
                    Text(
                      name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  if (revealed && card.reversed)
                    Text(l10n.reversed, style: TextStyle(color: scheme.error, fontSize: 12 * scale)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
