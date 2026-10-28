import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/providers.dart';
import '../domain/models.dart';
import '../l10n/gen/app_localizations.dart';
import 'design.dart';
import 'keyboard.dart';
import 'widgets/report_request.dart';
import 'widgets/tarot_spread.dart';

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
  final Set<int> _revealed = {};
  bool _busy = false;

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  Future<void> _draw() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final chart = await ref.read(apiClientProvider).createChart({'system': 'tarot', 'spread': _spread});
      if (!mounted) return; // left the page meanwhile
      setState(() {
        _chart = chart;
        _asked = _question.text.trim();
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
    final chart = _chart;
    // A draw can't be repeated as it was: once cards are out, ask before leaving.
    return LeaveGuard(
      active: chart != null,
      message: l10n.leaveTarotBody,
      // Ctrl+Enter draws, until cards are out (a second draw would replace them).
      child: SubmitShortcut(
        onSubmit: _busy || chart != null ? null : _draw,
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
                      // The classic order: the question first, then the spread and the draw.
                      TextField(
                        key: const Key('tarot-question'),
                        controller: _question,
                        textInputAction: TextInputAction.done,
                        inputFormatters: [LengthLimitingTextInputFormatter(300)],
                        onSubmitted: (_) => _busy ? null : _draw(),
                        decoration: InputDecoration(
                          labelText: l10n.tarotQuestion,
                          helperText: l10n.tarotQuestionHint,
                          helperMaxLines: 2,
                        ),
                      ),
                      const SizedBox(height: Space.l),
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
                  child: ReportRequest(chartId: chart.chartId, system: 'tarot', title: l10n.homeTarot, question: _asked),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
