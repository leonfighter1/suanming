import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../application/providers.dart';
import '../domain/profile.dart';
import '../l10n/gen/app_localizations.dart';
import 'bazi_chart_page.dart';
import 'life_report_page.dart';
import 'design.dart';
import 'profiles_page.dart';
import 'widgets/life_context_fields.dart';

/// 八字 input. Starts from the default profile; pick another person from
/// 「為誰排盤」, and adjust fields for this chart only.
class BaziFormPage extends ConsumerStatefulWidget {
  const BaziFormPage({super.key, this.lifeReport = false});

  /// The 一生运势报告 entry: same form, then the life report instead of the chart page.
  final bool lifeReport;

  @override
  ConsumerState<BaziFormPage> createState() => _BaziFormPageState();
}

class _BaziFormPageState extends ConsumerState<BaziFormPage> {
  BirthProfile? _draft;
  String? _profileId;
  bool _busy = false;

  BirthProfile _fallback(String name) => sampleProfile(name).copyWith(name: name);

  Future<void> _submit(BirthProfile p) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final place = p.birthPlace;
      final chart = await ref.read(apiClientProvider).createChart({
        'system': 'bazi',
        'local': DateFormat("yyyy-MM-dd'T'HH:mm").format(p.birthLocal),
        'timezone': place.timezone,
        'longitude': place.longitude,
        'gender': p.gender,
        'options': {'trueSolarTime': p.trueSolarTime, 'inputBasis': p.inputBasis},
      });
      // The name stays on the device: label the chart locally for history.
      if (p.name.isNotEmpty) await ref.read(profilesProvider.notifier).labelChart(chart.chartId, p.name);
      if (widget.lifeReport) {
        if (mounted) await startLifeReport(context, ref, chart: chart, profile: p);
        return;
      }
      await navigator.push(MaterialPageRoute<void>(builder: (_) => BaziChartPage(chart: chart, personName: p.name, profile: p)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final book = ref.watch(profilesProvider).value;
    final profiles = book?.profiles ?? const <BirthProfile>[];
    final selected = profiles.where((p) => p.id == _profileId).firstOrNull ?? book?.defaultProfile;
    final draft = _draft ?? selected ?? _fallback('');

    return Scaffold(
      appBar: AppBar(title: Text(widget.lifeReport ? l10n.lifeEntry : l10n.homeBazi)),
      body: ListView(
        padding: Space.page,
        children: [
          FadeSlideIn(
            child: AppCard(
              title: l10n.profileFor,
              icon: Icons.people_alt_outlined,
              trailing: TextButton.icon(
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text(l10n.profiles),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ProfilesPage())),
              ),
              child: profiles.isEmpty
                  ? OutlinedButton.icon(
                      icon: const Icon(Icons.person_add_alt_1),
                      label: Text(l10n.createProfile),
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ProfileEditPage())),
                    )
                  : DropdownMenu<String>(
                      key: const Key('profile-picker'),
                      expandedInsets: EdgeInsets.zero,
                      initialSelection: selected?.id,
                      leadingIcon: const Icon(Icons.person_outline),
                      dropdownMenuEntries: [
                        for (final p in profiles)
                          DropdownMenuEntry(
                            value: p.id,
                            label: p.name,
                            trailingIcon: p.id == book?.defaultProfile?.id ? const Icon(Icons.star, size: 16) : null,
                          ),
                      ],
                      onSelected: (id) => setState(() {
                        _profileId = id;
                        _draft = null; // switching person resets this-run edits
                      }),
                    ),
            ),
          ),
          FadeSlideIn(
            index: 1,
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (profiles.isNotEmpty) ...[
                    Text(
                      l10n.profileHint,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: Space.m),
                  ],
                  BirthFields(value: draft, onChanged: (p) => setState(() => _draft = p)),
                  LifeContextFields(value: draft.life, onChanged: (l) => setState(() => _draft = draft.copyWith(life: l))),
                ],
              ),
            ),
          ),
          FadeSlideIn(
            index: 2,
            child: FilledButton.icon(
              key: const Key('compute-chart'),
              onPressed: _busy ? null : () => _submit(draft),
              icon: _busy
                  ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.auto_awesome),
              label: Text(widget.lifeReport ? l10n.lifeGenerate : l10n.compute),
            ),
          ),
        ],
      ),
    );
  }
}
