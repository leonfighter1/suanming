import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';
import '../design.dart';
import '../keyboard.dart';
import 'tarot_spread.dart';

/// 洗牌 → 切牌 → 选牌 (v3.0.0). The engine shuffles the whole deck from the draw id; here the
/// user shuffles (a gesture), cuts it, choosing one of three piles to go on top, and picks
/// [count] cards face down. [onDone] gets the cut and the picks (places in the cut deck);
/// [onSkip], offered at every step, lets the deck pick as before.
class TarotRitualSteps extends StatefulWidget {
  const TarotRitualSteps({super.key, required this.count, required this.onDone, required this.onSkip});
  final int count;
  final void Function(int cut, List<int> picks) onDone;
  final VoidCallback onSkip;

  /// The deck, 78 cards; a pile is a third of it.
  static const deck = 78, pile = 26;

  @override
  State<TarotRitualSteps> createState() => _TarotRitualStepsState();
}

class _TarotRitualStepsState extends State<TarotRitualSteps> {
  int _step = 0; // 0 shuffle, 1 cut, 2 pick
  bool _shuffling = false;
  int _cut = 0;
  final List<int> _picks = [];

  Future<void> _shuffle() async {
    setState(() => _shuffling = true);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() {
      _shuffling = false;
      _step = 1;
    });
  }

  void _cutAt(int pile) => setState(() {
        _cut = pile * TarotRitualSteps.pile;
        _step = 2;
      });

  void _pick(int place) {
    if (_picks.contains(place) || _picks.length == widget.count) return;
    setState(() => _picks.add(place));
    if (_picks.length == widget.count) widget.onDone(_cut, List.of(_picks));
  }

  /// Three cards fanned a little: a deck, or a pile.
  Widget _stack(double width, {double turn = 0}) => SizedBox(
        width: width * 1.5,
        height: width * 12 / 7 * 1.15,
        child: Stack(
          children: [
            for (var i = 0; i < 3; i++)
              Positioned(
                left: i * width * 0.18,
                top: i * width * 0.05,
                child: AnimatedRotation(
                  turns: turn * (i - 1),
                  duration: const Duration(milliseconds: 350),
                  child: CardBack(width: width),
                ),
              ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final step = switch (_step) {
      0 => Column(
          children: [
            Text(l10n.ritualShuffleHint, textAlign: TextAlign.center),
            const SizedBox(height: Space.m),
            _stack(64, turn: _shuffling ? 0.04 : 0),
            const SizedBox(height: Space.m),
            FilledButton.icon(
              key: const Key('ritual-shuffle'),
              onPressed: _shuffling ? null : _shuffle,
              icon: const Icon(Icons.shuffle),
              label: Text(l10n.ritualShuffle),
            ),
          ],
        ),
      1 => Column(
          children: [
            Text(l10n.ritualCutHint, textAlign: TextAlign.center),
            const SizedBox(height: Space.m),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: Space.l,
              runSpacing: Space.m,
              children: [
                for (var i = 0; i < 3; i++)
                  Pressable(
                    key: Key('ritual-cut-$i'),
                    label: l10n.ritualPile(i + 1),
                    onPressed: () => _cutAt(i),
                    child: Padding(
                      padding: const EdgeInsets.all(Space.s),
                      child: Column(
                        children: [_stack(52), const SizedBox(height: Space.xs), Text(l10n.ritualPile(i + 1))],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      _ => Column(
          children: [
            Text(
              l10n.ritualPickHint(widget.count, _picks.length),
              key: const Key('ritual-pick-hint'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Space.m),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: Space.xs,
              runSpacing: Space.xs,
              children: [
                for (var p = 0; p < TarotRitualSteps.deck; p++)
                  Pressable(
                    key: Key('ritual-pick-$p'),
                    label: l10n.ritualCard(p + 1),
                    radius: 4,
                    onPressed: _picks.contains(p) ? null : () => _pick(p),
                    child: Opacity(
                      opacity: _picks.contains(p) ? 1 : 0.85,
                      child: CardBack(
                        width: 30,
                        label: _picks.contains(p) ? '${_picks.indexOf(p) + 1}' : null,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
    };
    // Each step stays in view as it changes: the 78 cards to pick from, after the cut, from the top (owner, v9.1.0).
    return BringIntoView(
      trigger: _step,
      child: AppCard(
        key: const Key('tarot-ritual'),
        title: l10n.ritualTitle,
        icon: Icons.back_hand_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedSwitcher(duration: const Duration(milliseconds: 250), child: KeyedSubtree(key: ValueKey(_step), child: step)),
            const SizedBox(height: Space.s),
            Center(
              child: TextButton(key: const Key('ritual-skip'), onPressed: widget.onSkip, child: Text(l10n.ritualSkip)),
            ),
            Text(l10n.ritualNote, textAlign: TextAlign.center, style: text.bodySmall),
          ],
        ),
      ),
    );
  }
}
