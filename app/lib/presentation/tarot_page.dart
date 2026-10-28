import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/providers.dart';
import '../domain/models.dart';
import '../generated/contract.g.dart';
import '../l10n/gen/app_localizations.dart';
import 'design.dart';
import 'keyboard.dart';
import 'labels.dart';
import 'tarot_glossary_page.dart';
import 'widgets/report_request.dart';
import 'widgets/tarot_ritual.dart';
import 'widgets/tarot_spread.dart';

/// Each spread choice's width: room for its icon and the longest name (凯尔特十字) on one line.
const _spreadChoiceWidth = 84.0;

/// 塔罗 the classic way: think of a question, choose a spread, draw; the cards are laid
/// out as the spread prescribes and turned in dealing order (widgets/tarot_spread.dart).
class TarotPage extends ConsumerStatefulWidget {
  const TarotPage({super.key});

  @override
  ConsumerState<TarotPage> createState() => _TarotPageState();
}

class _TarotPageState extends ConsumerState<TarotPage> {
  String _spread = 'three_card';
  final _question = TextEditingController();
  ChartResult? _chart;

  /// The question as it was when the cards were drawn; it goes with the reading.
  String _asked = '';

  /// The area of life to look at (contract `tarotFocus`), or none; taken at the draw like the question.
  String? _focus;
  String? _askedFocus;

  /// Between 抽牌 and the draw: the user shuffles, cuts and picks (v3.0.0).
  bool _inRitual = false;
  final Set<int> _revealed = {};
  bool _busy = false;

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  /// 抽牌 starts the ritual (v3.0.0): shuffle, cut, pick. A spread already out is put away.
  void _start() => setState(() {
        _chart = null;
        _revealed.clear();
        _inRitual = true;
      });

  /// The draw: with the user's cut and picks from the ritual, or the engine's own pick.
  Future<void> _draw({Map<String, Object?>? ritual}) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final chart = await ref.read(apiClientProvider).createChart({
        'system': 'tarot',
        'spread': _spread,
        'ritual': ?ritual,
      });
      if (!mounted) return; // left the page meanwhile
      setState(() {
        _inRitual = false;
        _chart = chart;
        _asked = _question.text.trim();
        _askedFocus = _focus;
        _revealed.clear();
      });
      // Load the pictures while the cards lie face down, so each one is there as it turns.
      for (final c in chart.tarot.cards) {
        precacheImage(AssetImage(tarotArt(c.cardId)), context, onError: (_, _) {});
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
    final terms = ref.watch(termsProvider).value;
    final locale = ref.watch(settingsProvider).apiLocaleCode;
    final chart = _chart;
    // A draw can't be repeated as it was: once cards are out, ask before leaving.
    return LeaveGuard(
      active: chart != null,
      message: l10n.leaveTarotBody,
      // Ctrl+Enter draws, until cards are out (a second draw would replace them).
      child: SubmitShortcut(
        onSubmit: _busy || chart != null || _inRitual ? null : _start,
        child: Scaffold(
          appBar: AppBar(
            title: Text(l10n.homeTarot),
            actions: [
              // 牌义图鉴: all 78 cards with their art and keywords (v2.7.0).
              IconButton(
                key: const Key('open-glossary'),
                tooltip: l10n.tarotGlossary,
                icon: const Icon(Icons.menu_book_outlined),
                onPressed: () =>
                    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const TarotGlossaryPage())),
              ),
            ],
          ),
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
                      // The classic order: the question first, then the spread and the draw.
                      TextField(
                        key: const Key('tarot-question'),
                        controller: _question,
                        textInputAction: TextInputAction.done,
                        inputFormatters: [LengthLimitingTextInputFormatter(300)],
                        onSubmitted: (_) => _busy ? null : _start(),
                        decoration: InputDecoration(
                          labelText: l10n.tarotQuestion,
                          helperText: l10n.tarotQuestionHint,
                          helperMaxLines: 2,
                        ),
                      ),
                      const SizedBox(height: Space.s),
                      // Example questions: a touch puts one in the field (v2.5.0).
                      Wrap(
                        spacing: Space.s,
                        runSpacing: Space.s,
                        children: [
                          for (final (i, q) in [
                            l10n.tarotExample1,
                            l10n.tarotExample2,
                            l10n.tarotExample3,
                            l10n.tarotExample4,
                          ].indexed)
                            ActionChip(
                              key: Key('example-$i'),
                              label: Text(q),
                              onPressed: () => setState(() => _question.text = q),
                            ),
                        ],
                      ),
                      const SizedBox(height: Space.m),
                      // Beside the question: the area of life the reading should look at (optional).
                      Text(l10n.tarotFocus, style: Theme.of(context).textTheme.labelLarge),
                      const SizedBox(height: Space.s),
                      Wrap(
                        spacing: Space.s,
                        runSpacing: Space.s,
                        children: [
                          ChoiceChip(
                            key: const Key('focus-any'),
                            label: Text(l10n.focusAny),
                            selected: _focus == null,
                            onSelected: (_) => setState(() => _focus = null),
                          ),
                          for (final f in tarotFocus)
                            ChoiceChip(
                              key: Key('focus-$f'),
                              label: Text(l10n.tarotFocusLabel(f)),
                              selected: _focus == f,
                              onSelected: (on) => setState(() => _focus = on ? f : null),
                            ),
                        ],
                      ),
                      const SizedBox(height: Space.l),
                      // Each spread drawn small, then its positions, before the draw (v2.5.0).
                      Text(l10n.spread, style: Theme.of(context).textTheme.labelLarge),
                      const SizedBox(height: Space.s),
                      // Five spreads (v2.8.0) are too many for one segmented row on a phone:
                      // chips wrap, take Tab, Enter and Space, and show the theme's focus border.
                      Wrap(
                        key: const Key('spread'),
                        spacing: Space.s,
                        runSpacing: Space.s,
                        children: [
                          for (final (id, name) in [
                            ('single', l10n.spreadSingleShort),
                            ('three_card', l10n.spreadThreeShort),
                            ('celtic_cross', l10n.spreadCelticShort),
                            ('two_paths', l10n.spreadTwoPathsShort),
                            ('relationship', l10n.spreadRelationshipShort),
                          ])
                            ChoiceChip(
                              key: Key('spread-$id'),
                              showCheckmark: false,
                              selected: _spread == id,
                              onSelected: (_) => setState(() {
                                _spread = id;
                                _inRitual = false; // a ritual is for one spread's count
                              }),
                              // Every choice the same size (owner, v5.4.0): the same square icon, the name below.
                              label: SizedBox(
                                width: _spreadChoiceWidth,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: Space.s),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SpreadIcon(spreadId: id, count: terms?.spreadPositions(id).length ?? 1),
                                      const SizedBox(height: Space.s),
                                      Text(
                                        name,
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: Space.s),
                      Text(
                        [
                          for (final (i, p) in (terms?.spreadPositions(_spread) ?? const <String>[]).indexed)
                            '${i + 1} ${terms!.position(p, locale)}',
                        ].join(' · '),
                        key: const Key('spread-positions'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: Space.l),
                      FilledButton.icon(
                        key: const Key('draw'),
                        onPressed: _busy ? null : _start,
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
                    ? (_inRitual
                        ? TarotRitualSteps(
                            key: ValueKey('ritual-$_spread'),
                            count: terms?.spreadPositions(_spread).length ?? 1,
                            onDone: (cut, picks) => _draw(ritual: {'cut': cut, 'picks': picks}),
                            onSkip: _busy ? () {} : _draw,
                          )
                        : const SizedBox.shrink())
                    : AppCard(
                        key: ValueKey(chart.chartId),
                        child: TarotSpread(
                          chart: chart.tarot,
                          revealed: _revealed,
                          question: _asked,
                          onReveal: (position) => setState(() => _revealed.add(position)),
                        ),
                      ),
              ),
              if (chart != null && _revealed.length == chart.tarot.cards.length)
                FadeSlideIn(
                  child: ReportRequest(
                    chartId: chart.chartId,
                    system: 'tarot',
                    title: l10n.homeTarot,
                    question: _asked,
                    focus: _askedFocus,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
