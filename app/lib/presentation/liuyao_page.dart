import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/providers.dart';
import '../data/api_client.dart';
import '../domain/dates.dart';
import '../domain/models.dart';
import '../l10n/gen/app_localizations.dart';
import '../platform/time_zone.dart';
import 'buttons.dart';
import 'design.dart';
import 'keyboard.dart';
import 'layout.dart';
import 'widgets/copper_coin.dart';
import 'widgets/hexagram_card.dart';
import 'widgets/recalc_check.dart';
import 'widgets/report_request.dart';

/// 算卦 (v6.0.0, tech plan S10, the owner's request): 六爻 by three coins, cast three ways. A reminder comes first.
/// - 自動擲幣: the server tosses; the six tosses are shown one at a time, the 初爻 first.
/// - 自己挑幣: 24 coins are laid out face down on the server before the reader picks 18 of them; the order of the
///   picks makes the lines (picks 1–3 the 初爻).
/// - 自己擲、自己填: the reader's own coins, entered by counting the 背 or by the line, with the time of the toss.
/// Then the hexagram card, its texts said straight out (直說), and the AI reading.
class LiuyaoPage extends ConsumerStatefulWidget {
  const LiuyaoPage({super.key});

  @override
  ConsumerState<LiuyaoPage> createState() => _LiuyaoPageState();
}

/// The coins of a toss leave the hand one after another; a reveal turns the picked coins over in pick order
/// (owner, v6.1.0: the coins turn over like the tarot cards).
const _tossStagger = Duration(milliseconds: 120);
const _revealStagger = Duration(milliseconds: 90);

/// The three coins a manual line stands for, by the classical count (背 3, 字 2).
const _coinsOf = {
  6: ['zi', 'zi', 'zi'],
  7: ['bei', 'zi', 'zi'],
  8: ['bei', 'bei', 'zi'],
  9: ['bei', 'bei', 'bei'],
};

class _LiuyaoPageState extends ConsumerState<LiuyaoPage> {
  final _question = TextEditingController();
  String _mode = 'auto';
  ChartResult? _chart;

  /// The question as it was when the cast was made; it goes with the reading.
  String _asked = '';
  bool _busy = false;

  /// auto: how many of the six tosses are on show.
  int _shown = 0;

  /// pick: the layout's id, and the coins picked so far, in order.
  String? _layoutId;
  final _picks = <int>[];

  /// manual: the time of the toss, and the six lines (初爻 first), entered by coins or by line.
  DateTime? _time;
  bool _byLines = false;
  final _rows = List<int?>.filled(6, null);

  /// 算卦必须要有所问之问题之后才能去求 (owner, v11.1.0): no coin is cast, or laid out, before something is asked.
  bool _asking = false;

  @override
  void initState() {
    super.initState();
    watchQuestion(_question, (asking) => setState(() => _asking = asking));
  }

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  bool get _manualReady => _time != null && _rows.every((r) => r != null);

  Future<void> _cast(Map<String, Object?> request) async {
    if (!_asking) return;
    // 同名重算 (v10.0.0): the same question cast for before? Ask first.
    final name = ref.read(profilesProvider).value?.defaultProfile?.name;
    if (!await confirmRecalc(context, ref, system: 'liuyao', name: name, question: _question.text)) return;
    if (!mounted) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    try {
      final chart = await ref.read(apiClientProvider).createChart({
        'system': 'liuyao',
        'timezone': deviceTimeZone(),
        // The coins are cast for it (v11.1.0); its reading answers it.
        'question': _question.text.trim(),
        ...request,
        // Whose reading it is, for 以往记录 (v8.0.0).
        ...readerPerson(ref.read(profilesProvider).value),
      });
      if (!mounted) return; // left the page meanwhile
      setState(() {
        _chart = chart;
        _asked = _question.text.trim();
        _shown = _mode == 'auto' ? 0 : 6;
      });
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e is ApiException && e.code == 'question_required' ? l10n.liuyaoQuestionMissing : '$e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _castAuto() => _cast({'mode': 'auto'});
  void _castPick() => _cast({'mode': 'pick', 'draw_id': _layoutId, 'picks': [..._picks]});
  void _castManual() => _cast({
        'mode': 'manual',
        'local': localMinute(_time!),
        'lines': [
          for (final v in _rows) _byLines ? {'value': v} : {'coins': _coinsOf[v]},
        ],
      });

  Future<void> _layOut() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final id = await ref.read(apiClientProvider).liuyaoLayout();
      if (!mounted) return;
      setState(() {
        _layoutId = id;
        _picks.clear();
      });
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _time ?? now,
      firstDate: DateTime(1900),
      lastDate: now,
      initialEntryMode: keyboardInUse ? DatePickerEntryMode.input : DatePickerEntryMode.calendar,
    );
    if (date == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_time ?? now),
      initialEntryMode: keyboardInUse ? TimePickerEntryMode.input : TimePickerEntryMode.dial,
    );
    if (t == null || !mounted) return;
    setState(() => _time = DateTime(date.year, date.month, date.day, t.hour, t.minute));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(settingsProvider).apiLocaleCode;
    final theme = Theme.of(context);
    final chart = _chart;
    final cast = chart?.liuyao;
    final done = cast != null && _shown >= 6;
    // The way to cast that is ready, for its button and for Ctrl+Enter; none before the question is asked.
    final VoidCallback? cast_ = chart != null || _busy || !_asking
        ? null
        : switch (_mode) {
            'pick' => _layoutId != null && _picks.length == 18 ? _castPick : null,
            'manual' => _manualReady ? _castManual : null,
            _ => _castAuto,
          };
    return LeaveGuard(
      active: chart != null,
      message: l10n.leaveLiuyaoBody,
      child: SubmitShortcut(
        onSubmit: cast_,
        child: Scaffold(
          appBar: AppBar(title: Text(l10n.homeLiuyao)),
          body: ListView(
            padding: pagePadding(context),
            children: [
              FadeSlideIn(
                child: HeroBanner(title: l10n.homeLiuyao, subtitle: l10n.homeLiuyaoDesc, icon: Icons.toll_outlined),
              ),
              FadeSlideIn(
                index: 1,
                child: AppCard(
                  title: l10n.liuyaoQuestion,
                  icon: Icons.edit_note,
                  child: TextField(
                    key: const Key('liuyao-question'),
                    controller: _question,
                    enabled: chart == null,
                    textInputAction: TextInputAction.done,
                    inputFormatters: [LengthLimitingTextInputFormatter(300)],
                    decoration: InputDecoration(labelText: l10n.liuyaoQuestion, helperText: l10n.liuyaoQuestionHint),
                  ),
                ),
              ),
              // The owner: remind the reader before the coins are tossed.
              FadeSlideIn(
                index: 2,
                child: AppCard(
                  key: const Key('liuyao-remind'),
                  title: l10n.liuyaoRemind,
                  icon: Icons.self_improvement,
                  color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
                  child: Text(l10n.liuyaoRemindBody),
                ),
              ),
              FadeSlideIn(
                index: 3,
                child: AppCard(
                  title: l10n.liuyaoMode,
                  icon: Icons.toll_outlined,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SegmentKeys<String>(
                        child: SegmentedButton<String>(
                          key: const Key('liuyao-mode'),
                          segments: [
                            ButtonSegment(value: 'auto', label: Text(l10n.liuyaoModeAuto)),
                            ButtonSegment(value: 'pick', label: Text(l10n.liuyaoModePick)),
                            ButtonSegment(value: 'manual', label: Text(l10n.liuyaoModeManual)),
                          ],
                          selected: {_mode},
                          showSelectedIcon: false,
                          onSelectionChanged: chart != null ? null : (s) => setState(() => _mode = s.first),
                        ),
                      ),
                      const SizedBox(height: Space.m),
                      if (chart == null && !_asking)
                        Padding(
                          padding: const EdgeInsets.only(bottom: Space.s),
                          child: Text(
                            l10n.liuyaoQuestionMissing,
                            key: const Key('liuyao-question-missing'),
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                          ),
                        ),
                      ...switch (_mode) {
                        'pick' => _pickPanel(l10n, cast, cast_),
                        'manual' => _manualPanel(l10n, theme, chart != null, cast_),
                        _ => [
                            Text(l10n.liuyaoAutoHow),
                            if (chart == null) ...[
                              const SizedBox(height: Space.m),
                              AppFilledButton.icon(
                                key: const Key('liuyao-toss'),
                                onPressed: cast_,
                                icon: const Icon(Icons.toll_outlined),
                                label: Text(l10n.liuyaoToss),
                              ),
                            ],
                          ],
                      },
                    ],
                  ),
                ),
              ),
              if (cast != null && _mode == 'auto')
                // Each toss adds a row and moves 擲下一爻 down: the card stays in view (owner, v9.1.0).
                BringIntoView(
                  trigger: _shown,
                  child: FadeSlideIn(
                    child: AppCard(
                      key: ValueKey<String>('tosses-${chart!.chartId}'),
                      child: _Tosses(
                        chart: cast,
                        shown: _shown,
                        onNext: () => setState(() => _shown++),
                        onSkip: () => setState(() => _shown = 6),
                      ),
                    ),
                  ),
                ),
              if (done) ...[
                // The hexagram comes into view once the coins that make it have landed or turned.
                BringIntoView(
                  delay: switch (_mode) {
                    'auto' => _tossStagger * 2 + CopperCoin.spin,
                    'pick' => _revealStagger * 17 + CopperCoin.turn,
                    _ => Duration.zero,
                  },
                  child: FadeSlideIn(child: HexagramCard(key: const Key('hexagram-card'), chart: cast)),
                ),
                FadeSlideIn(
                  child: ReportRequest(
                    chartId: chart!.chartId,
                    system: 'liuyao',
                    title: '${l10n.homeLiuyao} · ${cast.primary.fullName(locale)}',
                    question: _asked,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _pickPanel(AppLocalizations l10n, LiuyaoChart? cast, VoidCallback? reveal) => [
        Text(l10n.liuyaoPickHow),
        const SizedBox(height: Space.m),
        if (_layoutId == null)
          AppFilledButton.icon(
            key: const Key('liuyao-lay-out'),
            // Laying the coins out begins the cast: it waits for the question too.
            onPressed: _busy || !_asking ? null : _layOut,
            icon: const Icon(Icons.grid_view),
            label: Text(l10n.liuyaoPickStart),
          )
        else
          // The coins laid out come into view, 揭示 below them (owner, v9.1.0), once the card has grown round them.
          BringIntoView(
            delay: BringIntoView.settle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CoinGrid(
                  picks: _picks,
                  cast: cast,
                  onPick: cast != null || _picks.length >= 18 ? null : (i) => setState(() => _picks.add(i)),
                ),
                const SizedBox(height: Space.s),
                Text(l10n.liuyaoPicked(_picks.length), key: const Key('liuyao-picked')),
                if (cast == null) ...[
                  const SizedBox(height: Space.m),
                  AppFilledButton.icon(
                    key: const Key('liuyao-reveal'),
                    onPressed: reveal,
                    icon: const Icon(Icons.visibility_outlined),
                    label: Text(l10n.liuyaoReveal),
                  ),
                  AppTextButton(
                    key: const Key('liuyao-pick-again'),
                    onPressed: _picks.isEmpty ? null : () => setState(_picks.clear),
                    child: Text(l10n.liuyaoPickAgain),
                  ),
                ],
              ],
            ),
          ),
      ];

  List<Widget> _manualPanel(AppLocalizations l10n, ThemeData theme, bool cast, VoidCallback? submit) {
    final labels = _byLines
        ? [l10n.liuyaoOldYin, l10n.liuyaoYoungYang, l10n.liuyaoYoungYin, l10n.liuyaoOldYang]
        : [l10n.liuyaoBei0, l10n.liuyaoBei1, l10n.liuyaoBei2, l10n.liuyaoBei3];
    final places = [l10n.liuyaoLine1, l10n.liuyaoLine2, l10n.liuyaoLine3, l10n.liuyaoLine4, l10n.liuyaoLine5, l10n.liuyaoLine6];
    final time = _time;
    return [
      Text(l10n.liuyaoManualHow),
      const SizedBox(height: Space.m),
      Text(l10n.liuyaoTime, style: theme.textTheme.labelLarge),
      const SizedBox(height: Space.xs),
      Wrap(
        spacing: Space.s,
        runSpacing: Space.s,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          AppOutlinedButton.icon(
            key: const Key('liuyao-time'),
            onPressed: cast ? null : _pickTime,
            icon: const Icon(Icons.schedule),
            label: Text(time == null ? l10n.liuyaoTimePick : localMinute(time).replaceFirst('T', ' ')),
          ),
          AppTextButton(
            key: const Key('liuyao-time-now'),
            onPressed: cast
                ? null
                : () {
                    final n = DateTime.now();
                    setState(() => _time = DateTime(n.year, n.month, n.day, n.hour, n.minute));
                  },
            child: Text(l10n.liuyaoTimeNow),
          ),
        ],
      ),
      if (time == null)
        Text(
          l10n.liuyaoTimeMissing,
          key: const Key('liuyao-time-missing'),
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
        ),
      const SizedBox(height: Space.m),
      Text(l10n.liuyaoEnterBy, style: theme.textTheme.labelLarge),
      const SizedBox(height: Space.xs),
      SegmentKeys<bool>(
        child: SegmentedButton<bool>(
          key: const Key('liuyao-enter-by'),
          segments: [
            ButtonSegment(value: false, label: Text(l10n.liuyaoByCoins)),
            ButtonSegment(value: true, label: Text(l10n.liuyaoByLines)),
          ],
          selected: {_byLines},
          showSelectedIcon: false,
          onSelectionChanged: cast ? null : (s) => setState(() => _byLines = s.first),
        ),
      ),
      const SizedBox(height: Space.s),
      // The 上爻 at the top, as a hexagram is read; the first toss is the 初爻 at the bottom.
      for (final position in [6, 5, 4, 3, 2, 1])
        Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.xs),
          child: Row(
            children: [
              SizedBox(width: 48, child: Text(places[position - 1], style: theme.textTheme.labelLarge)),
              Expanded(
                child: SegmentKeys<int>(
                  child: SegmentedButton<int>(
                    key: ValueKey<String>('liuyao-row-$position'),
                    segments: [
                      for (final (i, v) in [6, 7, 8, 9].indexed) ButtonSegment(value: v, label: Text(labels[i])),
                    ],
                    selected: {if (_rows[position - 1] != null) _rows[position - 1]!},
                    emptySelectionAllowed: true,
                    showSelectedIcon: false,
                    onSelectionChanged: cast
                        ? null
                        : (s) => setState(() => _rows[position - 1] = s.isEmpty ? null : s.first),
                  ),
                ),
              ),
            ],
          ),
        ),
      if (!cast) ...[
        const SizedBox(height: Space.m),
        AppFilledButton.icon(
          key: const Key('liuyao-cast'),
          onPressed: submit,
          icon: const Icon(Icons.toll_outlined),
          label: Text(l10n.liuyaoCast),
        ),
      ],
    ];
  }
}

/// An auto cast revealed one toss at a time, 初爻 first: the hexagram grows from the bottom, each toss with its
/// three coins and its line. 擲下一爻 shows the next; 直接看卦 shows them all. Each toss's coins are thrown and
/// land on their faces, and then its line shows (owner, v6.1.0).
class _Tosses extends StatelessWidget {
  const _Tosses({required this.chart, required this.shown, required this.onNext, required this.onSkip});
  final LiuyaoChart chart;
  final int shown;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final places = [l10n.liuyaoLine1, l10n.liuyaoLine2, l10n.liuyaoLine3, l10n.liuyaoLine4, l10n.liuyaoLine5, l10n.liuyaoLine6];
    String kind(int v) => switch (v) {
          6 => l10n.liuyaoOldYin,
          7 => l10n.liuyaoYoungYang,
          8 => l10n.liuyaoYoungYin,
          _ => l10n.liuyaoOldYang,
        };
    String coin(String c) => c == 'bei' ? l10n.liuyaoCoinBei : l10n.liuyaoCoinZi;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: HexagramLines(values: chart.values.take(shown).toList())),
        const SizedBox(height: Space.m),
        // The newest toss on top, as the lines build upward.
        for (var i = shown - 1; i >= 0; i--)
          Padding(
            key: ValueKey<String>('toss-$i'),
            padding: const EdgeInsets.symmetric(vertical: Space.xs),
            child: Row(
              children: [
                // The line below says what the coins show.
                ExcludeSemantics(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final (j, face) in (chart.coins[i] ?? const <String>[]).indexed)
                        Padding(
                          padding: const EdgeInsets.only(right: Space.s),
                          child: CopperCoin(face: face, size: 40, toss: true, delay: _tossStagger * j),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: Space.xs),
                Expanded(
                  child: _AfterLanding(
                    child: Text(
                      '${places[i]}：${(chart.coins[i] ?? const <String>[]).map(coin).join(' ')} → ${kind(chart.values[i])}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (shown < 6) ...[
          const SizedBox(height: Space.m),
          AppFilledButton.icon(
            key: const Key('liuyao-next'),
            autofocus: true,
            onPressed: onNext,
            icon: const Icon(Icons.toll_outlined),
            label: Text(l10n.liuyaoTossNext),
          ),
          AppTextButton(key: const Key('liuyao-skip'), onPressed: onSkip, child: Text(l10n.liuyaoSkip)),
        ],
      ],
    );
  }
}

/// A toss's line, shown once its coins have landed.
class _AfterLanding extends StatelessWidget {
  const _AfterLanding({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final landed = _tossStagger * 2 + CopperCoin.spin;
    final total = landed + const Duration(milliseconds: 200);
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: still ? Duration.zero : total,
      curve: Interval(landed.inMicroseconds / total.inMicroseconds, 1),
      builder: (context, v, child) => Opacity(opacity: v, child: child),
      child: child,
    );
  }
}

/// The 24 coins laid out face down. A picked coin glows and carries its number. Once cast, the picked coins turn
/// over one after another in the order picked, each to the face its toss gave it, and the others step back.
class _CoinGrid extends StatelessWidget {
  const _CoinGrid({required this.picks, required this.cast, required this.onPick});
  final List<int> picks;
  final LiuyaoChart? cast;
  final ValueChanged<int>? onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    String name(String face) => face == 'bei' ? l10n.liuyaoCoinBei : l10n.liuyaoCoinZi;
    return Wrap(
      key: const Key('liuyao-coins'),
      spacing: Space.s,
      runSpacing: Space.s,
      children: [
        for (var i = 0; i < 24; i++)
          () {
            final order = picks.indexOf(i);
            final picked = order >= 0;
            // The face, once cast: the order picked gives the toss (3 per line) and the coin in it.
            final toss = picked ? cast?.coins[order ~/ 3] : null;
            final face = toss == null ? null : toss[order % 3];
            return Pressable(
              key: ValueKey<String>('coin-$i'),
              radius: 22,
              label: face == null ? l10n.liuyaoCoin(i + 1) : l10n.liuyaoCoinFace(i + 1, name(face)),
              onPressed: picked || onPick == null ? null : () => onPick!(i),
              child: AnimatedOpacity(
                opacity: cast != null && !picked ? 0.35 : 1,
                duration: CopperCoin.turn,
                child: CopperCoin(
                  face: face,
                  number: picked ? order + 1 : null,
                  glow: picked,
                  delay: _revealStagger * (picked ? order : 0),
                ),
              ),
            );
          }(),
      ],
    );
  }
}
