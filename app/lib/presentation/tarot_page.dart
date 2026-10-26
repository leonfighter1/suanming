import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/providers.dart';
import '../domain/models.dart';
import '../l10n/gen/app_localizations.dart';
import 'widgets/report_request.dart';

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
      setState(() {
        _chart = chart;
        _revealed.clear();
      });
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
    return Scaffold(
      appBar: AppBar(title: Text(l10n.homeTarot)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            initialValue: _spread,
            decoration: InputDecoration(labelText: l10n.spread),
            items: [
              DropdownMenuItem(value: 'single', child: Text(l10n.spreadSingle)),
              DropdownMenuItem(value: 'three_card', child: Text(l10n.spreadThree)),
              DropdownMenuItem(value: 'celtic_cross', child: Text(l10n.spreadCeltic)),
            ],
            onChanged: (v) => setState(() => _spread = v ?? _spread),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            key: const Key('draw'),
            onPressed: _busy ? null : _draw,
            icon: const Icon(Icons.style),
            label: Text(l10n.draw),
          ),
          if (chart != null) ...[
            const SizedBox(height: 16),
            Text(l10n.tapToReveal, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final c in chart.tarot.cards)
                  _FlipCard(
                    card: c,
                    revealed: _revealed.contains(c.position),
                    onTap: () => setState(() => _revealed.add(c.position)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_revealed.length == chart.tarot.cards.length)
              ReportRequest(chartId: chart.chartId, system: 'tarot'),
          ],
        ],
      ),
    );
  }
}

class _FlipCard extends ConsumerWidget {
  const _FlipCard({required this.card, required this.revealed, required this.onTap});
  final TarotCardFact card;
  final bool revealed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(settingsProvider).apiLocaleCode;
    final terms = ref.watch(termsProvider).value;
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
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
                  width: 96,
                  height: 150,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: showFace ? scheme.surfaceContainerHigh : scheme.primary,
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  // Mirror the face back so text reads correctly after the flip,
                  // and turn it upside down for a reversed card.
                  child: showFace
                      ? Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..rotateY(pi)
                            ..rotateZ(card.reversed ? pi : 0),
                          child: Center(
                            child: Text(
                              terms?.card(card.cardId, locale) ?? card.cardId,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        )
                      : Icon(Icons.auto_awesome, color: scheme.onPrimary),
                ),
              );
            },
          ),
          const SizedBox(height: 4),
          Text(terms?.position(card.positionKey, locale) ?? card.positionKey),
          if (revealed && card.reversed)
            Text(l10n.reversed, style: TextStyle(color: scheme.error, fontSize: 12)),
        ],
      ),
    );
  }
}
