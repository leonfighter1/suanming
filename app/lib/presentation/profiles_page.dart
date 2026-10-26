import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../application/providers.dart';
import '../domain/cities.dart';
import '../domain/profile.dart';
import '../l10n/gen/app_localizations.dart';
import 'design.dart';

/// Profiles kept on this device: the user's own (default ★) and people they help.
class ProfilesPage extends ConsumerWidget {
  const ProfilesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final book = ref.watch(profilesProvider).value;
    final locale = ref.watch(settingsProvider).apiLocaleCode;
    final profiles = book?.profiles ?? const <BirthProfile>[];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.profiles)),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add-profile'),
        icon: const Icon(Icons.person_add_alt_1),
        label: Text(l10n.addProfile),
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ProfileEditPage())),
      ),
      body: profiles.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(Space.xxl),
                child: Text(l10n.noProfileBody, textAlign: TextAlign.center),
              ),
            )
          : ListView.builder(
              padding: Space.page,
              itemCount: profiles.length,
              itemBuilder: (_, i) {
                final p = profiles[i];
                final isDefault = book?.defaultProfile?.id == p.id;
                return FadeSlideIn(
                  index: i,
                  child: Dismissible(
                    key: ValueKey(p.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: Space.xl),
                      margin: const EdgeInsets.only(bottom: Space.m),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(Radii.card),
                      ),
                      child: const Icon(Icons.delete_outline),
                    ),
                    onDismissed: (_) => ref.read(profilesProvider.notifier).remove(p.id),
                    child: AppCard(
                      padding: const EdgeInsets.all(Space.l),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => ProfileEditPage(profile: p)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(child: Text(p.name.isEmpty ? '?' : p.name.characters.first)),
                          const SizedBox(width: Space.m),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Text(p.name, style: Theme.of(context).textTheme.titleMedium),
                                  if (isDefault) ...[const SizedBox(width: Space.s), Pill(l10n.isDefault, icon: Icons.star)],
                                ]),
                                const SizedBox(height: Space.xs),
                                Text(
                                  '${DateFormat('yyyy-MM-dd HH:mm').format(p.birthLocal)} · ${cityByKey(p.cityKey).name(locale)} · ${p.gender == 'male' ? l10n.male : l10n.female}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          if (!isDefault)
                            IconButton(
                              tooltip: l10n.setDefault,
                              icon: const Icon(Icons.star_outline),
                              onPressed: () => ref.read(profilesProvider.notifier).setDefault(p.id),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

/// Create or edit a profile.
class ProfileEditPage extends ConsumerStatefulWidget {
  const ProfileEditPage({super.key, this.profile});
  final BirthProfile? profile;

  @override
  ConsumerState<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends ConsumerState<ProfileEditPage> {
  late BirthProfile _p = widget.profile ??
      BirthProfile(
        id: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
        name: '',
        gender: 'male',
        birthLocal: DateTime(1990, 1, 1, 12),
        cityKey: 'hk',
      );
  late final _name = TextEditingController(text: _p.name);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final navigator = Navigator.of(context);
    await ref.read(profilesProvider.notifier).upsert(_p.copyWith(name: _name.text.trim()));
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.profile == null ? l10n.addProfile : l10n.editProfile),
        actions: [
          if (widget.profile != null)
            IconButton(
              tooltip: l10n.deleteProfile,
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final navigator = Navigator.of(context);
                await ref.read(profilesProvider.notifier).remove(widget.profile!.id);
                navigator.pop();
              },
            ),
        ],
      ),
      body: ListView(
        padding: Space.page,
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  key: const Key('profile-name'),
                  controller: _name,
                  decoration: InputDecoration(labelText: l10n.name, prefixIcon: const Icon(Icons.badge_outlined)),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: Space.l),
                BirthFields(
                  value: _p,
                  onChanged: (p) => setState(() => _p = p),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            key: const Key('save-profile'),
            onPressed: _name.text.trim().isEmpty ? null : _save,
            icon: const Icon(Icons.check),
            label: Text(l10n.save),
          ),
        ],
      ),
    );
  }
}

/// Birth date/time, place, gender and 真太陽時 — shared by the profile editor
/// and the 八字 form. Shows the 農曆 equivalent of the chosen date live.
class BirthFields extends ConsumerWidget {
  const BirthFields({super.key, required this.value, required this.onChanged});
  final BirthProfile value;
  final ValueChanged<BirthProfile> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(settingsProvider).apiLocaleCode;
    final d = value.birthLocal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.birthTime, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: Space.s),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text(DateFormat('yyyy-MM-dd').format(d)),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: d,
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    onChanged(value.copyWith(birthLocal: DateTime(picked.year, picked.month, picked.day, d.hour, d.minute)));
                  }
                },
              ),
            ),
            const SizedBox(width: Space.s),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.schedule, size: 18),
                label: Text(TimeOfDay.fromDateTime(d).format(context)),
                onPressed: () async {
                  final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(d));
                  if (t != null) onChanged(value.copyWith(birthLocal: DateTime(d.year, d.month, d.day, t.hour, t.minute)));
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.s),
        LunarPreview(date: d),
        const SizedBox(height: Space.l),
        DropdownMenu<String>(
          key: const Key('city'),
          expandedInsets: EdgeInsets.zero,
          initialSelection: value.cityKey,
          label: Text(l10n.city),
          leadingIcon: const Icon(Icons.place_outlined),
          dropdownMenuEntries: [for (final c in cities) DropdownMenuEntry(value: c.key, label: c.name(locale))],
          onSelected: (k) => k == null ? null : onChanged(value.copyWith(cityKey: k)),
        ),
        const SizedBox(height: Space.l),
        Text(l10n.gender, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: Space.s),
        SegmentedButton<String>(
          segments: [
            ButtonSegment(value: 'male', label: Text(l10n.male), icon: const Icon(Icons.male)),
            ButtonSegment(value: 'female', label: Text(l10n.female), icon: const Icon(Icons.female)),
          ],
          selected: {value.gender},
          onSelectionChanged: (s) => onChanged(value.copyWith(gender: s.first)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.trueSolarTime),
          value: value.trueSolarTime,
          onChanged: (v) => onChanged(value.copyWith(trueSolarTime: v)),
        ),
      ],
    );
  }
}

/// 「農曆 庚午年二月十九（生肖馬）」 for a date, fading between values.
class LunarPreview extends ConsumerWidget {
  const LunarPreview({super.key, required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(settingsProvider).apiLocaleCode;
    final terms = ref.watch(termsProvider).value;
    final lunar = ref.watch(lunarPreviewProvider(DateTime(date.year, date.month, date.day))).value;
    String chars(String s) => s.characters.map((c) => terms?.t(c, locale) ?? c).join();
    final text = lunar == null
        ? ''
        : '${l10n.lunarLabel} ${lunar.yearGanzhi}年${chars(lunar.monthName)}${lunar.dayName}（${l10n.zodiac}${terms?.t(lunar.shengxiao, locale) ?? lunar.shengxiao}）';
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: text.isEmpty
          ? const SizedBox(height: 20)
          : Align(
              key: ValueKey(text),
              alignment: Alignment.centerLeft,
              child: Pill(text, icon: Icons.nightlight_round),
            ),
    );
  }
}
