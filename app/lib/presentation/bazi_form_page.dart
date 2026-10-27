import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../application/providers.dart';
import '../domain/profile.dart';
import '../l10n/gen/app_localizations.dart';
import 'bazi_chart_page.dart';
import 'life_report_page.dart';
import 'design.dart';
import 'keyboard.dart';
import 'profiles_page.dart';
import 'widgets/life_context_fields.dart';

/// 为谁排盘 picker values that are actions, not people.
const _addPerson = '__add__';
const _editPerson = '__edit__';

/// 八字 input, for a chart + reading or a 一生运势报告 (the switch at the top).
/// Starts from the default profile; pick another person from 「为谁排盘」, add or
/// edit people in a pop-up, and adjust any field for this run only.
class BaziFormPage extends ConsumerStatefulWidget {
  const BaziFormPage({super.key, this.lifeReport = false});

  /// Start in 一生运势报告 mode.
  final bool lifeReport;

  @override
  ConsumerState<BaziFormPage> createState() => _BaziFormPageState();
}

class _BaziFormPageState extends ConsumerState<BaziFormPage> {
  late bool _life = widget.lifeReport;
  BirthProfile? _draft;
  String? _profileId;
  bool _busy = false;

  /// Bumped to rebuild the picker (back to the person after an add/edit action)
  /// and the name field (to the newly loaded person's name).
  int _generation = 0;

  BirthProfile _fallback(String name) => sampleProfile(name).copyWith(name: name);

  /// Loads a person into the form: their saved details, no run-only edits.
  void _load(String? id) => setState(() {
        _profileId = id;
        _draft = null;
        _generation++;
      });

  Future<void> _openDialog({BirthProfile? edit}) async {
    final saved = await showProfileDialog(context, profile: edit);
    // Saved: select it and load it into the current form. Cancelled: back to who was picked.
    _load(saved?.id ?? _profileId);
  }

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
      // Name and birthplace stay on the device: label the chart locally for history.
      final locale = ref.read(settingsProvider).apiLocaleCode;
      await ref.read(profilesProvider.notifier).labelChart(chart.chartId, p.name, place: place.label(locale));
      // Left the page meanwhile (after confirming): don't open the result on top of 首页.
      if (!mounted) return;
      if (_life) {
        await startLifeReport(context, ref, chart: chart, profile: p);
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
    final scheme = Theme.of(context).colorScheme;
    final book = ref.watch(profilesProvider).value;
    final profiles = book?.profiles ?? const <BirthProfile>[];
    final selected = profiles.where((p) => p.id == _profileId).firstOrNull ?? book?.defaultProfile;
    final draft = _draft ?? selected ?? _fallback('');

    // Going back drops this run's edits: ask first. Ctrl+Enter = 排盘.
    return LeaveGuard(
      active: _draft != null || _busy,
      message: l10n.leaveFormBody,
      child: SubmitShortcut(
        onSubmit: _busy ? null : () => _submit(draft),
        child: Scaffold(
          appBar: AppBar(title: Text(l10n.homeBazi)),
          body: ListView(
            padding: Space.page,
            children: [
              // 排盘解读 or 一生运势报告: same person, same form.
              FadeSlideIn(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: Space.l),
                  child: SegmentKeys(
                    child: SegmentedButton<bool>(
                      key: const Key('form-mode'),
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(value: false, icon: const Icon(Icons.grid_view_rounded), label: Text(l10n.modeChart)),
                        ButtonSegment(value: true, icon: const Icon(Icons.auto_stories), label: Text(l10n.lifeEntry)),
                      ],
                      selected: {_life},
                      onSelectionChanged: (s) => setState(() => _life = s.first),
                    ),
                  ),
                ),
              ),
              FadeSlideIn(
                index: 1,
                child: AppCard(
                  title: l10n.profileFor,
                  icon: Icons.people_alt_outlined,
                  trailing: TextButton.icon(
                    icon: const Icon(Icons.manage_accounts_outlined, size: 18),
                    label: Text(l10n.profiles),
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ProfilesPage())),
                  ),
                  child: profiles.isEmpty
                      ? OutlinedButton.icon(
                          key: const Key('add-person'),
                          icon: const Icon(Icons.person_add_alt_1),
                          label: Text(l10n.addTester),
                          onPressed: _openDialog,
                        )
                      // A picker, not a text box: names are edited in the form below or in the pop-up.
                      : KeyedSubtree(
                          key: const Key('profile-picker'),
                          child: DropdownMenu<String>(
                            key: ValueKey('profile-picker-$_generation'),
                            expandedInsets: EdgeInsets.zero,
                            initialSelection: selected?.id,
                            requestFocusOnTap: false,
                            enableFilter: false,
                            enableSearch: false,
                            leadingIcon: const Icon(Icons.person_outline),
                            dropdownMenuEntries: [
                              for (final p in profiles)
                                DropdownMenuEntry(
                                  value: p.id,
                                  label: p.name,
                                  trailingIcon: p.id == book?.defaultProfile?.id ? const Icon(Icons.star, size: 16) : null,
                                ),
                              DropdownMenuEntry(
                                value: _addPerson,
                                label: l10n.addTester,
                                leadingIcon: Icon(Icons.person_add_alt_1, color: scheme.primary),
                              ),
                              if (selected != null)
                                DropdownMenuEntry(
                                  value: _editPerson,
                                  label: l10n.editCurrent(selected.name),
                                  leadingIcon: Icon(Icons.edit_outlined, color: scheme.primary),
                                ),
                            ],
                            onSelected: (id) {
                              if (id == _addPerson) {
                                _openDialog();
                              } else if (id == _editPerson) {
                                _openDialog(edit: selected);
                              } else {
                                _load(id); // switching person resets this-run edits
                              }
                            },
                          ),
                        ),
                ),
              ),
              FadeSlideIn(
                index: 2,
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (profiles.isNotEmpty) ...[
                        Text(
                          l10n.profileHint,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: Space.m),
                      ],
                      // Editable for this run; 编辑资料 in the picker saves it for good.
                      TextFormField(
                        key: ValueKey('form-name-$_generation'),
                        initialValue: draft.name,
                        decoration: InputDecoration(labelText: l10n.name, prefixIcon: const Icon(Icons.badge_outlined)),
                        onChanged: (v) => setState(() => _draft = draft.copyWith(name: v)),
                      ),
                      const SizedBox(height: Space.l),
                      BirthFields(value: draft, onChanged: (p) => setState(() => _draft = p)),
                      LifeContextFields(value: draft.life, onChanged: (l) => setState(() => _draft = draft.copyWith(life: l))),
                    ],
                  ),
                ),
              ),
              FadeSlideIn(
                index: 3,
                child: FilledButton.icon(
                  key: const Key('compute-chart'),
                  onPressed: _busy ? null : () => _submit(draft),
                  icon: _busy
                      ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(_life ? Icons.auto_stories : Icons.auto_awesome),
                  label: Text(_life ? l10n.lifeGenerate : l10n.compute),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
