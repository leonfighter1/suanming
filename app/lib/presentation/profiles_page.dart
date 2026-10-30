import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../application/providers.dart';
import '../domain/profile.dart';
import '../l10n/gen/app_localizations.dart';
import 'design.dart';
import 'keyboard.dart';
import 'layout.dart';
import 'widgets/birth_fields.dart';
import 'widgets/life_context_fields.dart';
import 'widgets/remedy.dart' show compactButtons;

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
              padding: pagePadding(context),
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
                                  '${DateFormat('yyyy-MM-dd HH:mm').format(p.birthLocal)} · ${p.birthPlace.label(locale)} · ${p.gender == 'male' ? l10n.male : l10n.female}',
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

  /// Changed since the page opened: Esc and ← ask before dropping it.
  bool _dirty = false;

  void _edit(BirthProfile p) => setState(() {
        _p = p;
        _dirty = true;
      });

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
    return LeaveGuard(
      kind: LeaveKind.edits,
      active: _dirty,
      child: SubmitShortcut(
        onSubmit: _name.text.trim().isEmpty ? null : _save,
        child: Scaffold(
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
            padding: pagePadding(context),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      key: const Key('profile-name'),
                      controller: _name,
                      decoration: InputDecoration(labelText: l10n.name, prefixIcon: const Icon(Icons.badge_outlined)),
                      onChanged: (_) => setState(() => _dirty = true),
                    ),
                    const SizedBox(height: Space.l),
                    BirthFields(value: _p, onChanged: _edit),
                    LifeContextFields(value: _p.life, onChanged: (l) => _edit(_p.copyWith(life: l))),
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
        ),
      ),
    );
  }
}

/// Opens the profile editor as a pop-up over the current page. Returns the saved
/// person (already stored), or null when cancelled.
Future<BirthProfile?> showProfileDialog(BuildContext context, {BirthProfile? profile}) =>
    showDialog<BirthProfile>(context: context, builder: (_) => ProfileDialog(profile: profile));

/// Add or edit a person without leaving the page (the 八字 form's 为谁排盘).
class ProfileDialog extends ConsumerStatefulWidget {
  const ProfileDialog({super.key, this.profile});
  final BirthProfile? profile;

  @override
  ConsumerState<ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends ConsumerState<ProfileDialog> {
  late BirthProfile _p = widget.profile ??
      BirthProfile(
        id: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
        name: '',
        gender: 'male',
        birthLocal: DateTime(1990, 1, 1, 12),
        cityKey: 'hk',
      );
  late final _name = TextEditingController(text: _p.name);
  bool _busy = false;

  /// Changed since the pop-up opened: Esc and tapping outside ask first.
  bool _dirty = false;

  void _edit(BirthProfile p) => setState(() {
        _p = p;
        _dirty = true;
      });

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final navigator = Navigator.of(context);
    final saved = _p.copyWith(name: _name.text.trim());
    await ref.read(profilesProvider.notifier).upsert(saved);
    navigator.pop(saved);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return LeaveGuard(
      kind: LeaveKind.edits,
      active: _dirty && !_busy,
      child: SubmitShortcut(
        onSubmit: _busy || _name.text.trim().isEmpty ? null : _save,
        child: Dialog(
          key: const Key('profile-dialog'),
          insetPadding: const EdgeInsets.all(Space.l),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 640, maxHeight: MediaQuery.sizeOf(context).height * 0.9),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(Space.xl, Space.l, Space.s, 0),
                  child: Row(children: [
                    Icon(widget.profile == null ? Icons.person_add_alt_1 : Icons.edit_outlined, color: theme.colorScheme.primary),
                    const SizedBox(width: Space.s),
                    Expanded(child: Text(widget.profile == null ? l10n.addTester : l10n.editProfile, style: theme.textTheme.titleLarge)),
                    IconButton(tooltip: l10n.cancel, onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                  ]),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(Space.xl, Space.m, Space.xl, Space.m),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      TextField(
                        key: const Key('dialog-profile-name'),
                        controller: _name,
                        autofocus: widget.profile == null,
                        decoration: InputDecoration(labelText: l10n.name, prefixIcon: const Icon(Icons.badge_outlined)),
                        onChanged: (_) => setState(() => _dirty = true),
                      ),
                      const SizedBox(height: Space.l),
                      BirthFields(value: _p, onChanged: _edit),
                      LifeContextFields(value: _p.life, onChanged: (l) => _edit(_p.copyWith(life: l))),
                    ]),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(Space.l, 0, Space.l, Space.l),
                  child: compactButtons(
                    context,
                    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
                      const SizedBox(width: Space.s),
                      FilledButton.icon(
                        key: const Key('dialog-save-profile'),
                        onPressed: _busy || _name.text.trim().isEmpty ? null : _save,
                        icon: const Icon(Icons.check),
                        label: Text(l10n.save),
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
