import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/providers.dart';
import '../domain/models.dart';
import '../l10n/gen/app_localizations.dart';
import 'design.dart';
import 'keyboard.dart';
import 'widgets/names_card.dart';
import 'widgets/report_request.dart';

/// 起名 (v4.5.0, tech plan WP6.4) for one 八字 chart: the surname and the given name's length, then candidate
/// names that serve the chart's 喜用 (or keep a balance), with their sound checked, and a reading of them.
/// Offered only where the region has 起名 on (off until the owner has checked its 字义库).
class NamingPage extends ConsumerStatefulWidget {
  const NamingPage({super.key, required this.baziChartId});
  final String baziChartId;

  @override
  ConsumerState<NamingPage> createState() => _NamingPageState();
}

class _NamingPageState extends ConsumerState<NamingPage> {
  final _surname = TextEditingController();
  int _length = 2;
  ChartResult? _chart;
  bool _busy = false;

  @override
  void dispose() {
    _surname.dispose();
    super.dispose();
  }

  bool get _valid => RegExp(r'^\p{Script=Han}{1,2}$', unicode: true).hasMatch(_surname.text.trim());

  Future<void> _suggest() async {
    if (!_valid) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final chart = await ref.read(apiClientProvider).createChart({
        'system': 'naming',
        'bazi_chart_id': widget.baziChartId,
        'surname': _surname.text.trim(),
        'length': _length,
      });
      if (!mounted) return;
      setState(() => _chart = chart);
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
    return SubmitShortcut(
      onSubmit: _busy || !_valid ? null : _suggest,
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.homeNaming)),
        body: ListView(
          padding: Space.page,
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    key: const Key('naming-surname'),
                    controller: _surname,
                    inputFormatters: [LengthLimitingTextInputFormatter(2)],
                    onChanged: (_) => setState(() => _chart = null),
                    onSubmitted: (_) => _busy ? null : _suggest(),
                    decoration: InputDecoration(labelText: l10n.namingSurname, helperText: l10n.namingSurnameHint),
                  ),
                  const SizedBox(height: Space.l),
                  Text(l10n.namingLength, style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: Space.s),
                  Wrap(
                    spacing: Space.s,
                    children: [
                      for (final (n, label) in [(1, l10n.namingOne), (2, l10n.namingTwo)])
                        ChoiceChip(
                          key: Key('naming-length-$n'),
                          label: Text(label),
                          selected: _length == n,
                          onSelected: (_) => setState(() {
                            _length = n;
                            _chart = null;
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: Space.l),
                  FilledButton.icon(
                    key: const Key('naming-suggest'),
                    onPressed: _busy || !_valid ? null : _suggest,
                    icon: const Icon(Icons.badge_outlined),
                    label: Text(l10n.namingSuggest),
                  ),
                ],
              ),
            ),
            if (chart != null) ...[
              FadeSlideIn(child: NamesCard(key: const Key('names-card'), chart: chart.naming)),
              FadeSlideIn(
                child: ReportRequest(
                  key: ValueKey<String>('naming-request-${chart.chartId}'),
                  chartId: chart.chartId,
                  system: 'naming',
                  title: '${l10n.homeNaming} · ${chart.naming.surname(ref.watch(settingsProvider).apiLocaleCode)}',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
