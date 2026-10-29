import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/providers.dart';
import '../domain/models.dart';
import '../l10n/gen/app_localizations.dart';
import 'design.dart';
import 'keyboard.dart';
import 'widgets/lot_card.dart';
import 'widgets/qiuqian_stage.dart';
import 'widgets/recalc_check.dart';
import 'widgets/report_request.dart';

/// 求籤 (v4.3.0, tech plan WP6.1) as temples do it: keep the question in mind, shake the cylinder until
/// a stick falls, then throw the moon blocks. A 聖筊 confirms the stick; a 笑筊 or 陰筊 puts it back
/// and the user shakes again. The server draws every round at once (so a draw replays); the page
/// reveals them one step at a time.
class QiuqianPage extends ConsumerStatefulWidget {
  const QiuqianPage({super.key});

  @override
  ConsumerState<QiuqianPage> createState() => _QiuqianPageState();
}

class _QiuqianPageState extends ConsumerState<QiuqianPage> {
  final _question = TextEditingController();
  ChartResult? _chart;

  /// The question as it was when the lot was drawn; it goes with the reading.
  String _asked = '';

  /// The round on show (0-based) and whether its blocks have been thrown.
  int _round = 0;
  bool _thrown = false;
  bool _busy = false;

  /// The stage at work (v9.1.0): the round's stick still falling, or its blocks in the air.
  bool _shaking = false;
  bool _tossing = false;

  /// 直接看结果: every step's end at once.
  bool _skipped = false;

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  Future<void> _draw() async {
    // 同名重算 (v10.0.0): the same question drawn for before? Ask first.
    final name = ref.read(profilesProvider).value?.defaultProfile?.name;
    if (!await confirmRecalc(context, ref, system: 'qiuqian', name: name, question: _question.text)) return;
    if (!mounted) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final chart = await ref.read(apiClientProvider).createChart({
        'system': 'qiuqian',
        // Whose reading it is, for 以往记录 (v8.0.0).
        ...readerPerson(ref.read(profilesProvider).value),
      });
      if (!mounted) return; // left the page meanwhile
      setState(() {
        _chart = chart;
        _asked = _question.text.trim();
        _round = 0;
        _thrown = false;
        _shaking = true;
        _tossing = false;
        _skipped = false;
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
    final lot = chart?.qiuqian;
    final done = lot != null && _thrown && _round == lot.rounds.length - 1;
    // A lot can't be drawn again as it was: once one is out, ask before leaving.
    return LeaveGuard(
      active: chart != null,
      message: l10n.leaveQiuqianBody,
      // Ctrl+Enter draws, until a lot is out.
      child: SubmitShortcut(
        onSubmit: _busy || chart != null ? null : _draw,
        child: Scaffold(
          appBar: AppBar(title: Text(l10n.homeQiuqian)),
          body: ListView(
            padding: Space.page,
            children: [
              FadeSlideIn(
                child: HeroBanner(
                  title: l10n.homeQiuqian,
                  subtitle: l10n.homeQiuqianDesc,
                  icon: Icons.temple_buddhist_outlined,
                ),
              ),
              FadeSlideIn(
                index: 1,
                child: AppCard(
                  title: l10n.qiuqianQuestion,
                  icon: Icons.edit_note,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        key: const Key('qiuqian-question'),
                        controller: _question,
                        enabled: chart == null,
                        textInputAction: TextInputAction.done,
                        inputFormatters: [LengthLimitingTextInputFormatter(300)],
                        onSubmitted: (_) => _busy || chart != null ? null : _draw(),
                        decoration: InputDecoration(
                          labelText: l10n.qiuqianQuestion,
                          helperText: l10n.qiuqianQuestionHint,
                          helperMaxLines: 3,
                        ),
                      ),
                      const SizedBox(height: Space.s),
                      Wrap(
                        spacing: Space.s,
                        runSpacing: Space.s,
                        children: [
                          for (final (i, q) in [l10n.qiuqianExample1, l10n.qiuqianExample2, l10n.qiuqianExample3].indexed)
                            ActionChip(
                              key: Key('qiuqian-example-$i'),
                              label: Text(q),
                              onPressed: chart != null ? null : () => setState(() => _question.text = q),
                            ),
                        ],
                      ),
                      const SizedBox(height: Space.m),
                      Text(l10n.qiuqianHowTo, style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: Space.l),
                      if (chart == null)
                        FilledButton.icon(
                          key: const Key('draw-lot'),
                          onPressed: _busy ? null : _draw,
                          icon: const Icon(Icons.temple_buddhist_outlined),
                          label: Text(l10n.qiuqianDraw),
                        ),
                    ],
                  ),
                ),
              ),
              if (lot != null)
                // The altar comes into view as the lot is drawn, and stays in view as each step adds a row
                // (owner, v9.1.0).
                BringIntoView(
                  trigger: (_round, _shaking, _thrown),
                  child: FadeSlideIn(
                    child: AppCard(
                      key: ValueKey<String>('rounds-${chart!.chartId}'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          QiuqianStage(
                            key: const Key('qiuqian-stage'),
                            round: _round,
                            blocks: _tossing || _thrown ? lot.rounds[_round].blocks : null,
                            label: l10n.qiuqianCylinder,
                            settled: _skipped,
                            onShaken: (round) {
                              if (round == _round) setState(() => _shaking = false);
                            },
                            onThrown: (round) {
                              if (round == _round) {
                                setState(() {
                                  _tossing = false;
                                  _thrown = true;
                                });
                              }
                            },
                          ),
                          if (_shaking || _tossing)
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                _shaking ? l10n.qiuqianShaking : l10n.qiuqianTossing,
                                key: const Key('qiuqian-busy'),
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          _Rounds(
                            chart: lot,
                            round: _round,
                            thrown: _thrown,
                            shaking: _shaking,
                            tossing: _tossing,
                            onThrow: () => setState(() => _tossing = true),
                            onAgain: () => setState(() {
                              _round++;
                              _thrown = false;
                              _shaking = true;
                            }),
                            onSkip: () => setState(() {
                              _round = lot.rounds.length - 1;
                              _thrown = true;
                              _shaking = false;
                              _tossing = false;
                              _skipped = true;
                            }),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (done) ...[
                BringIntoView(child: FadeSlideIn(child: LotCard(key: const Key('lot-card'), lotNumber: lot.lotNumber))),
                FadeSlideIn(
                  child: ReportRequest(chartId: chart!.chartId, system: 'qiuqian', title: l10n.homeQiuqian, question: _asked),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The rounds so far: each stick that fell and, once thrown, how the blocks landed. The one button
/// takes the next step (throw, or put the stick back and shake again); 直接看结果 shows the rest.
/// While the stage is at work the next step waits for it: the round's row until its stick is [shaking] out, the
/// button while it is, and while the blocks are [tossing].
class _Rounds extends ConsumerWidget {
  const _Rounds({
    required this.chart,
    required this.round,
    required this.thrown,
    required this.shaking,
    required this.tossing,
    required this.onThrow,
    required this.onAgain,
    required this.onSkip,
  });
  final QiuqianChart chart;
  final int round;
  final bool thrown;
  final bool shaking;
  final bool tossing;
  final VoidCallback onThrow;
  final VoidCallback onAgain;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(settingsProvider).apiLocaleCode;
    final lots = ref.watch(termsProvider).value?.lots;
    final theme = Theme.of(context);
    final current = chart.rounds[round];
    final finished = thrown && current.confirmed;
    // The round's row once its stick lies on the floor (its throw once the blocks have landed).
    final rows = shaking ? round : round + 1;
    String title(int n) => lots?.lot(n)?.title(locale) ?? '$n';
    String meaning(String result) => switch (result) {
          'sheng' => l10n.qiuqianSheng,
          'xiao' => l10n.qiuqianXiao,
          _ => l10n.qiuqianYin,
        };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows; i++)
          Padding(
            key: ValueKey<String>('round-$i'),
            padding: const EdgeInsets.symmetric(vertical: Space.s),
            child: Row(
              children: [
                // Which try this is: 1, 2, …
                CircleAvatar(
                  radius: 12,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    '${i + 1}',
                    style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onPrimaryContainer),
                  ),
                ),
                const SizedBox(width: Space.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.qiuqianStickFell(title(chart.rounds[i].lot)), style: theme.textTheme.titleSmall),
                      if (i < round || thrown) ...[
                        const SizedBox(height: Space.xs),
                        Text(
                          meaning(chart.rounds[i].result),
                          key: ValueKey<String>('throw-$i'),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: chart.rounds[i].confirmed ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (i < round || thrown) JiaobeiBlocks(blocks: chart.rounds[i].blocks),
              ],
            ),
          ),
        if (!finished) ...[
          const SizedBox(height: Space.m),
          if (!shaking && !tossing)
            FilledButton.icon(
              key: Key(thrown ? 'shake-again' : 'throw-blocks'),
              autofocus: true,
              onPressed: thrown ? onAgain : onThrow,
              icon: Icon(thrown ? Icons.replay : Icons.back_hand_outlined),
              label: Text(thrown ? l10n.qiuqianAgain : l10n.qiuqianThrow),
            ),
          TextButton(key: const Key('skip-rounds'), onPressed: onSkip, child: Text(l10n.qiuqianSkip)),
        ],
      ],
    );
  }
}
