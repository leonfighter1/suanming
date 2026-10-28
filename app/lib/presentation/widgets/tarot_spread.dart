import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../domain/models.dart';
import '../../l10n/gen/app_localizations.dart';
import '../design.dart';
import '../keyboard.dart';
import 'remedy.dart' show compactButtons;

// Tarot only: nothing here is shared with another method.
//
// A card has the art's own shape, 7:12 (app/assets/tarot, made by `npm run mirror:tarot`).
// Its corners stay small enough not to cut the gold frame painted 16/700 in from the edge.
const _ratio = 12 / 7;

/// Below this width a card is a thumbnail: touching it opens it large, to be turned there.
const _thumbnail = 96.0;

// The deck's own colours (JingyaoPaint tarot_card.dart), so the back matches the faces
// in light and dark alike, as a real deck would. 算卦's covered coins share them (design.dart).
const _navy = FaceDown.navy;
const _navyLight = FaceDown.navyLight;
const _gold = FaceDown.gold;

String tarotArt(String cardId) => 'assets/tarot/$cardId.webp';

/// Text in the card area: twice the body size where there is room (owner), less on a phone.
double _textScale(double width) => ((width - Space.m) / 2 / 104).clamp(1.0, 2.0);

/// Celtic Cross in card widths w: three cross columns 0.5 w apart (card 2 lies across
/// card 1 and sticks out 5/14 w on each side), 0.6 w to the staff, 0.1 w between rows.
const _gx = 0.5, _gs = 0.6, _gy = 0.1;
const _celticWide = 4 + 2 * _gx + _gs;
const _celticTall = 4 * _ratio + 3 * _gy;

/// Where each card of a Celtic Cross lies, by position, for card width [w]: the cross
/// (1 centre, 2 across it, 3 below, 4 behind, 5 the crown above, 6 ahead) and the staff
/// (7 at the bottom up to 10 at the top). The cross sits halfway up the taller staff.
Map<int, Rect> celticRects(double w) {
  final h = w * _ratio;
  final height = _celticTall * w;
  final crossTop = (height - (3 * h + 2 * _gy * w)) / 2;
  final midX = (1 + _gx) * w;
  final rowY = crossTop + h + _gy * w;
  final centre = Rect.fromLTWH(midX, rowY, w, h);
  return {
    1: centre,
    2: Rect.fromCenter(center: centre.center, width: h, height: w),
    3: Rect.fromLTWH(midX, rowY + h + _gy * w, w, h),
    4: Rect.fromLTWH(0, rowY, w, h),
    5: Rect.fromLTWH(midX, crossTop, w, h),
    6: Rect.fromLTWH((2 + 2 * _gx) * w, rowY, w, h),
    for (var i = 0; i < 4; i++) 7 + i: Rect.fromLTWH((3 + 2 * _gx + _gs) * w, height - (i + 1) * h - i * _gy * w, w, h),
  };
}

/// A card face down in the deck's own colours, [width] wide; [label] (a pick's number) on it.
class CardBack extends StatelessWidget {
  const CardBack({super.key, required this.width, this.label});
  final double width;
  final String? label;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: width * _ratio,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_navyLight, _navy],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(width * 0.08),
          border: Border.all(color: _gold, width: max(1, width * 0.03)),
        ),
        child: label == null
            ? null
            : Text(label!, style: TextStyle(color: _gold, fontWeight: FontWeight.w700, fontSize: width * 0.4)),
      );
}

/// The gap between columns of 二选一 and 关系牌阵, in card widths.
const _gp = 0.25;

/// Spreads laid out in two dimensions, wide and tall in card widths (the others lie in a row).
const _spreadWide = {'celtic_cross': _celticWide, 'two_paths': 3 + 2 * _gp, 'relationship': 3 + 2 * _gp};
const _spreadTall = {
  'celtic_cross': _celticTall,
  'two_paths': 3 * _ratio + 2 * _gy,
  'relationship': 2 * _ratio + _gy,
};

/// Where each card of a two-dimensional spread lies, by position, for card width [w] (null for
/// the spreads in a row: one card, three cards). 二选一 is a V: card 1, where you stand, at the
/// bottom, path A rising on the left (2, then 4) and path B on the right (3, then 5). 关系牌阵 is
/// two rows: you (1), the bond (3) and the other person (2); then what stands between (4), the
/// direction (6) and what helps (5).
Map<int, Rect>? spreadRects(String spreadId, double w) {
  final h = w * _ratio;
  double x(int column) => column * (1 + _gp) * w;
  double y(int row) => row * (h + _gy * w);
  return switch (spreadId) {
    'celtic_cross' => celticRects(w),
    'two_paths' => {
        1: Rect.fromLTWH(x(1), y(2), w, h),
        2: Rect.fromLTWH(x(0), y(1), w, h),
        3: Rect.fromLTWH(x(2), y(1), w, h),
        4: Rect.fromLTWH(x(0), y(0), w, h),
        5: Rect.fromLTWH(x(2), y(0), w, h),
      },
    'relationship' => {
        1: Rect.fromLTWH(x(0), y(0), w, h),
        3: Rect.fromLTWH(x(1), y(0), w, h),
        2: Rect.fromLTWH(x(2), y(0), w, h),
        4: Rect.fromLTWH(x(0), y(1), w, h),
        6: Rect.fromLTWH(x(1), y(1), w, h),
        5: Rect.fromLTWH(x(2), y(1), w, h),
      },
    _ => null,
  };
}

/// [rects] in painting order: card 2 of a Celtic Cross last, so it lies on top of card 1.
List<MapEntry<int, Rect>> _painted(Map<int, Rect> rects) =>
    rects.entries.toList()..sort((a, b) => (a.key == 2 ? 99 : a.key).compareTo(b.key == 2 ? 99 : b.key));

/// A spread drawn small, before the draw (v2.5.0): each card an outline where it will lie, card 2
/// of a Celtic Cross across card 1. The same geometry as [TarotSpread] ([spreadRects]).
/// A spread's diagram in a square of [size] (v5.4.0, the owner): every spread's icon is the same size,
/// one card or ten, with its cards as large as the square allows, so the choices line up.
class SpreadIcon extends StatelessWidget {
  const SpreadIcon({super.key, required this.spreadId, required this.count, this.size = 56});
  final String spreadId;
  final int count;
  final double size;

  @override
  Widget build(BuildContext context) {
    // The diagram in card widths: a row of cards, or a laid-out spread.
    final row = spreadRects(spreadId, 1) == null;
    final wide = row ? (count - 1) * 1.4 + 1 : _spreadWide[spreadId]!;
    final tall = row ? _ratio : _spreadTall[spreadId]!;
    return SizedBox.square(
      dimension: size,
      child: Center(
        child: SpreadDiagram(spreadId: spreadId, count: count, cardWidth: min(size / wide, size / tall)),
      ),
    );
  }
}

class SpreadDiagram extends StatelessWidget {
  const SpreadDiagram({super.key, required this.spreadId, required this.count, this.cardWidth = 8});
  final String spreadId;

  /// How many cards (deck SPREADS, via Terms.spreadPositions).
  final int count;
  final double cardWidth;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final w = cardWidth;
    final h = w * _ratio;
    final laid = spreadRects(spreadId, w);
    final rects = laid == null
        ? [for (var i = 0; i < count; i++) Rect.fromLTWH(i * w * 1.4, 0, w, h)]
        : [for (final e in _painted(laid)) e.value];
    return ExcludeSemantics(
      child: SizedBox(
        width: laid == null ? (count - 1) * w * 1.4 + w : _spreadWide[spreadId]! * w,
        height: laid == null ? h : _spreadTall[spreadId]! * w,
        child: Stack(
          children: [
            for (final r in rects)
              Positioned.fromRect(
                rect: r,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    border: Border.all(color: scheme.primary, width: 1.2),
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A drawn spread, laid out the classic way and turned in dealing order:
/// one card in the middle; three in a row, past → present → future; or the Celtic Cross,
/// sized so the whole cross and staff fit the screen. Touching any face-down card turns
/// the next one. A thumbnail (a phone's Celtic Cross) opens large and is turned there;
/// a turned card opens large with its position's meaning.
class TarotSpread extends ConsumerWidget {
  const TarotSpread({super.key, required this.chart, required this.revealed, required this.onReveal, this.question = ''});
  final TarotChart chart;
  final Set<int> revealed;
  final ValueChanged<int> onReveal;

  /// What the user asked before drawing ('' if nothing).
  final String question;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final locale = ref.watch(settingsProvider).apiLocaleCode;
    final terms = ref.watch(termsProvider).value;
    String position(TarotCardFact c) => terms?.position(c.positionKey, locale) ?? c.positionKey;
    String meaning(TarotCardFact c) => terms?.positionMeaning(c.positionKey, locale) ?? '';
    String name(TarotCardFact c) => terms?.card(c.cardId, locale) ?? c.cardId;
    String slot(TarotCardFact c) => l10n.tarotSlot(c.position, position(c));
    const sep = '，';
    final next = chart.cards.where((c) => !revealed.contains(c.position)).firstOrNull;
    final celtic = chart.spreadId == 'celtic_cross';

    return LayoutBuilder(
      builder: (context, box) {
        final scale = _textScale(box.maxWidth);
        final body = (Theme.of(context).textTheme.bodyMedium?.fontSize ?? 14) * scale;
        // The position list under a two-dimensional spread is read card by card: at least 1.5×
        // text, even on a phone (v2.5.0).
        final listBody = (Theme.of(context).textTheme.bodyMedium?.fontSize ?? 14) * max(scale, 1.5);
        final count = chart.cards.length;
        // A two-dimensional spread (the Celtic Cross, 二选一, 关系牌阵) is sized so it fits the screen.
        final wide = _spreadWide[chart.spreadId];
        final tall = _spreadTall[chart.spreadId];
        final width = wide != null && tall != null
            ? min(box.maxWidth / wide, (MediaQuery.sizeOf(context).height - 160) / tall)
                .clamp(36.0, 150.0)
                .floorToDouble()
            : ((box.maxWidth - (count - 1) * Space.m) / count).clamp(56.0, 208.0).floorToDouble();
        final rects = spreadRects(chart.spreadId, width);
        final thumbnails = width < _thumbnail;

        Future<void> open(TarotCardFact c, {required bool turn}) => showDialog<void>(
              context: context,
              builder: (_) => _CardDialog(
                card: c,
                slot: slot(c),
                meaning: meaning(c),
                name: name(c),
                turnable: turn,
                onTurn: () => onReveal(c.position),
              ),
            );

        void tap(TarotCardFact c) {
          if (revealed.contains(c.position)) {
            open(c, turn: false);
          } else if (next != null) {
            thumbnails ? open(next, turn: true) : onReveal(next.position);
          }
        }

        Widget card(TarotCardFact c, {bool captions = false}) {
          final shown = revealed.contains(c.position);
          final isNext = c.position == next?.position;
          return _SpreadCard(
            key: Key('tarot-card-${c.position}'),
            card: c,
            width: width,
            name: name(c),
            revealed: shown,
            next: isNext,
            crossing: celtic && c.position == 2,
            // Tab reaches the turned cards and the next one; the rest wait their turn.
            focusable: shown || isNext,
            label: shown
                ? [slot(c), name(c), if (c.reversed) l10n.reversed].join(sep)
                : [l10n.tarotSlot(c.position, l10n.cardHidden(position(c))), if (isNext) l10n.tarotNextShort].join(sep),
            onTap: () => tap(c),
            captions: captions
                ? [position(c), if (shown) name(c), if (shown && c.reversed) l10n.reversed]
                : null,
            textSize: body,
          );
        }

        final layout = rects != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: SizedBox(
                      width: wide! * width,
                      height: tall! * width,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Card 2 of a Celtic Cross last, so it lies on top of card 1.
                          for (final MapEntry(key: n, value: rect) in _painted(rects))
                            Positioned.fromRect(rect: rect, child: card(chart.cards[n - 1])),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: Space.l),
                  // Every position in dealing order, with what it stands for. A turned
                  // card's row opens it large: card 1 mostly lies under card 2. Not Tab
                  // stops: the cards above already are.
                  for (final c in chart.cards)
                    ExcludeFocus(
                      child: Pressable(
                        key: Key('tarot-slot-${c.position}'),
                        onPressed: revealed.contains(c.position) ? () => open(c, turn: false) : null,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: Space.xs),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                [
                                  slot(c),
                                  if (revealed.contains(c.position)) name(c),
                                  if (revealed.contains(c.position) && c.reversed) l10n.reversed,
                                ].join(' · '),
                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: listBody),
                              ),
                              if (meaning(c).isNotEmpty)
                                Text(meaning(c), style: TextStyle(fontSize: listBody * 0.75, color: scheme.onSurfaceVariant)),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (i, c) in chart.cards.indexed) ...[
                    if (i > 0) const SizedBox(width: Space.m),
                    card(c, captions: true),
                  ],
                ],
              );

        return DefaultTextStyle.merge(
          style: TextStyle(fontSize: body),
          child: FocusTraversalGroup(
            policy: OrderedTraversalPolicy(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (question.isNotEmpty) ...[
                  Text(l10n.tarotQuestionShown(question), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: Space.s),
                ],
                Text(next == null ? l10n.tarotAllTurned : l10n.tarotNext(slot(next)), textAlign: TextAlign.center),
                if (thumbnails && next != null)
                  Text(
                    l10n.tarotZoomHint,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: body * 0.75, color: scheme.onSurfaceVariant),
                  ),
                const SizedBox(height: Space.l),
                layout,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// One card of the spread, as a keyboard-ready tap target, with its captions in a row spread.
class _SpreadCard extends StatelessWidget {
  const _SpreadCard({
    super.key,
    required this.card,
    required this.width,
    required this.name,
    required this.revealed,
    required this.next,
    required this.crossing,
    required this.focusable,
    required this.label,
    required this.onTap,
    required this.textSize,
    this.captions,
  });

  final TarotCardFact card;
  final double width;
  final String name;
  final bool revealed;
  final bool next;
  final bool crossing;
  final bool focusable;
  final String label;
  final VoidCallback onTap;
  final double textSize;

  /// Lines under the card (row spreads): position, then the card's name and 逆位 once turned.
  final List<String>? captions;

  @override
  Widget build(BuildContext context) {
    final lines = captions;
    final error = Theme.of(context).colorScheme.error;
    return ExcludeFocus(
      excluding: !focusable,
      child: FocusTraversalOrder(
        order: NumericFocusOrder(card.position.toDouble()),
        child: Pressable(
          onPressed: onTap,
          label: label,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _CardView(card: card, width: width, name: name, revealed: revealed, next: next, crossing: crossing),
              if (lines != null) ...[
                SizedBox(height: textSize * 4 / 14),
                // Read out through the card's label above.
                ExcludeSemantics(
                  child: SizedBox(
                    width: width,
                    child: Column(
                      children: [
                        for (final (i, line) in lines.indexed)
                          Text(
                            line,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: i == 0
                                ? null
                                : i == 1
                                    ? const TextStyle(fontWeight: FontWeight.w600)
                                    : TextStyle(color: error, fontSize: textSize * 12 / 14),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The card itself: the deck's back, or the face (upside down when reversed), turning
/// over when [revealed] changes; its position number in a corner; a gold glow on the card
/// to turn next. [crossing]: lies sideways, as card 2 of the Celtic Cross.
class _CardView extends StatelessWidget {
  const _CardView({
    required this.card,
    required this.width,
    required this.name,
    required this.revealed,
    this.next = false,
    this.crossing = false,
    this.number = true,
  });

  final TarotCardFact card;
  final double width;
  final String name;
  final bool revealed;
  final bool next;
  final bool crossing;
  final bool number;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final w = width;
    // In proportion to the first 104-pt card: corners 6, frame inset 5, star 24.
    final unit = w / 104;
    final body = TweenAnimationBuilder<double>(
      tween: Tween(end: revealed ? 1 : 0),
      duration: const Duration(milliseconds: 500),
      builder: (context, v, _) {
        final showFace = v > 0.5;
        final glow = next && !showFace;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(pi * v),
          child: Container(
            width: w,
            height: w * _ratio,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6 * unit),
              color: showFace ? scheme.surfaceContainerHighest : null,
              gradient: showFace ? null : const RadialGradient(colors: [_navyLight, _navy]),
              border: Border.all(
                color: glow ? _gold : scheme.outlineVariant.withValues(alpha: 0.6),
                width: glow ? 2 : 1,
              ),
              boxShadow: [
                if (glow) BoxShadow(color: _gold.withValues(alpha: 0.7), blurRadius: 14),
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
                      tarotArt(card.cardId),
                      fit: BoxFit.cover,
                      excludeFromSemantics: true, // the card's label says it
                      // Without its picture, a card shows its name.
                      errorBuilder: (_, _, _) => Padding(
                        padding: EdgeInsets.all(10 * unit),
                        child: Center(
                          child: Text(name, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                  )
                : Padding(
                    padding: EdgeInsets.all(5 * unit),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: _gold.withValues(alpha: 0.8)),
                        borderRadius: BorderRadius.circular(unit),
                      ),
                      child: Center(child: Icon(Icons.auto_awesome, color: _gold, size: 24 * unit)),
                    ),
                  ),
          ),
        );
      },
    );
    final d = (w * 0.26).clamp(16.0, 28.0);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        RotatedBox(quarterTurns: crossing ? 1 : 0, child: body),
        if (number)
          Positioned(
            left: d * 0.25,
            top: d * 0.25,
            child: ExcludeSemantics(
              child: Container(
                width: d,
                height: d,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _navy.withValues(alpha: 0.9),
                  border: Border.all(color: _gold),
                ),
                child: Text(
                  '${card.position}',
                  style: TextStyle(color: _gold, fontSize: d * 0.55, fontWeight: FontWeight.w700, height: 1),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// A card opened large: its position and what it stands for, the card, and once turned
/// its name. [turnable]: still face down; touching it (or Enter) turns it here.
class _CardDialog extends StatefulWidget {
  const _CardDialog({
    required this.card,
    required this.slot,
    required this.meaning,
    required this.name,
    required this.turnable,
    required this.onTurn,
  });

  final TarotCardFact card;
  final String slot;
  final String meaning;
  final String name;
  final bool turnable;
  final VoidCallback onTurn;

  @override
  State<_CardDialog> createState() => _CardDialogState();
}

class _CardDialogState extends State<_CardDialog> {
  late bool _revealed = !widget.turnable;

  void _turn() {
    setState(() => _revealed = true);
    widget.onTurn();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    final width = min(min(size.width - 136, (size.height - 330) / _ratio), 320.0).clamp(120.0, 320.0).floorToDouble();
    final card = widget.card;
    const sep = '，';
    return compactButtons(
      context,
      AlertDialog(
        key: const Key('tarot-card-view'),
        scrollable: true,
        title: Text(widget.slot, textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.meaning.isNotEmpty)
              Text(
                widget.meaning,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            const SizedBox(height: Space.m),
            Pressable(
              key: const Key('tarot-card-view-card'),
              autofocus: !_revealed,
              onPressed: _revealed ? null : _turn,
              label: _revealed
                  ? [widget.slot, widget.name, if (card.reversed) l10n.reversed].join(sep)
                  : [widget.slot, l10n.tarotTapToTurn].join(sep),
              child: _CardView(card: card, width: width, name: widget.name, revealed: _revealed, next: !_revealed, number: false),
            ),
            const SizedBox(height: Space.m),
            Text(
              _revealed ? [widget.name, if (card.reversed) l10n.reversed].join(' · ') : l10n.tarotTapToTurn,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
          ],
        ),
        actions: [
          TextButton(
            key: const Key('tarot-card-view-close'),
            autofocus: _revealed,
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }
}
