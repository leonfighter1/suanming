import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/providers.dart';
import '../domain/models.dart';
import '../l10n/gen/app_localizations.dart';
import 'design.dart';
import 'keyboard.dart';
import 'widgets/principles_card.dart';
import 'widgets/recalc_check.dart';
import 'widgets/report_request.dart';

/// 风水 (v4.4.0, tech plan WP6.3, the owner's Phase 3 spec): choose a room and, if known, the way its main
/// window faces; describe it if you like. 看佈局 shows the room's general principles, and the reading
/// relates them to the room. Never a 吉凶 judgement of a home; no address or floor plan is asked for.
class FengshuiPage extends ConsumerStatefulWidget {
  const FengshuiPage({super.key});

  @override
  ConsumerState<FengshuiPage> createState() => _FengshuiPageState();
}

/// A room's icon on its chip.
const _roomIcons = {
  'bedroom': Icons.bed_outlined,
  'study': Icons.desk_outlined,
  'living': Icons.weekend_outlined,
  'kitchen': Icons.kitchen_outlined,
  'entrance': Icons.door_front_door_outlined,
  'dining': Icons.dining_outlined,
  'kids': Icons.child_care_outlined,
};

class _FengshuiPageState extends ConsumerState<FengshuiPage> {
  String _room = 'bedroom';
  String? _facing;
  final _description = TextEditingController();
  ChartResult? _chart;

  /// The description as it was at 看佈局; it goes with the reading.
  String _described = '';
  bool _busy = false;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _look() async {
    // 同名重算 (v10.0.0): the same room description read before? Ask first.
    final name = ref.read(profilesProvider).value?.defaultProfile?.name;
    if (!await confirmRecalc(context, ref, system: 'fengshui', name: name, question: _description.text)) return;
    if (!mounted) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final chart = await ref.read(apiClientProvider).createChart({
        'system': 'fengshui',
        'room': _room,
        'facing': ?_facing,
        // Whose reading it is, for 以往记录 (v8.0.0).
        ...readerPerson(ref.read(profilesProvider).value),
      });
      if (!mounted) return;
      setState(() {
        _chart = chart;
        _described = _description.text.trim();
      });
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// A new choice makes the looked-up room stale.
  void _change(VoidCallback f) => setState(() {
        f();
        _chart = null;
      });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(settingsProvider).apiLocaleCode;
    final table = ref.watch(termsProvider).value?.fengshui;
    final chart = _chart;
    final theme = Theme.of(context);
    return SubmitShortcut(
      onSubmit: _busy ? null : _look,
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.homeFengshui)),
        body: ListView(
          padding: Space.page,
          children: [
            FadeSlideIn(
              child: HeroBanner(title: l10n.homeFengshui, subtitle: l10n.homeFengshuiDesc, icon: Icons.explore_outlined),
            ),
            FadeSlideIn(
              index: 1,
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(l10n.fengshuiRoom, style: theme.textTheme.labelLarge),
                    const SizedBox(height: Space.s),
                    Wrap(
                      spacing: Space.s,
                      runSpacing: Space.s,
                      children: [
                        for (final r in table?.rooms ?? const <String>[])
                          ChoiceChip(
                            key: Key('room-$r'),
                            avatar: Icon(_roomIcons[r] ?? Icons.home_outlined, size: 18),
                            label: Text(table!.roomName(r, locale)),
                            selected: _room == r,
                            onSelected: (_) => _change(() => _room = r),
                          ),
                      ],
                    ),
                    const SizedBox(height: Space.l),
                    Text(l10n.fengshuiFacing, style: theme.textTheme.labelLarge),
                    const SizedBox(height: Space.s),
                    Wrap(
                      spacing: Space.s,
                      runSpacing: Space.s,
                      children: [
                        ChoiceChip(
                          key: const Key('facing-none'),
                          label: Text(l10n.fengshuiFacingUnknown),
                          selected: _facing == null,
                          onSelected: (_) => _change(() => _facing = null),
                        ),
                        for (final f in table?.facings ?? const <String>[])
                          ChoiceChip(
                            key: Key('facing-$f'),
                            label: Text(table!.facing(f, locale).name),
                            selected: _facing == f,
                            onSelected: (on) => _change(() => _facing = on ? f : null),
                          ),
                      ],
                    ),
                    const SizedBox(height: Space.l),
                    TextField(
                      key: const Key('fengshui-description'),
                      controller: _description,
                      maxLines: 3,
                      minLines: 1,
                      inputFormatters: [LengthLimitingTextInputFormatter(300)],
                      decoration: InputDecoration(
                        labelText: l10n.fengshuiDescription,
                        helperText: l10n.fengshuiDescriptionHint,
                        helperMaxLines: 3,
                      ),
                    ),
                    const SizedBox(height: Space.l),
                    FilledButton.icon(
                      key: const Key('look-room'),
                      onPressed: _busy ? null : _look,
                      icon: const Icon(Icons.explore_outlined),
                      label: Text(l10n.fengshuiLook),
                    ),
                  ],
                ),
              ),
            ),
            if (chart != null) ...[
              // 看佈局 brings the room's principles into view (owner, v9.1.0).
              BringIntoView(
                key: ValueKey<String>('principles-${chart.chartId}'),
                child: FadeSlideIn(
                  child: PrinciplesCard(
                    key: const Key('principles-card'),
                    room: chart.fengshui.room,
                    facing: chart.fengshui.facing,
                  ),
                ),
              ),
              FadeSlideIn(
                child: ReportRequest(
                  key: ValueKey<String>('fengshui-request-${chart.chartId}'),
                  chartId: chart.chartId,
                  system: 'fengshui',
                  title: '${l10n.homeFengshui} · ${table?.roomName(chart.fengshui.room, locale) ?? ''}',
                  question: _described,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
