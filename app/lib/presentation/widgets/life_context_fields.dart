import 'package:flutter/material.dart';

import '../../domain/life_context.dart';
import '../../l10n/gen/app_localizations.dart';
import '../content_text.dart';
import '../design.dart';
import '../place_picker.dart';
import 'elastic_switch.dart';

/// 個人情況（選填）: residence, relationship, children, work, family and the user's
/// question. Shared by the profile editor and the 八字 form.
class LifeContextFields extends StatelessWidget {
  const LifeContextFields({super.key, required this.value, required this.onChanged});
  final LifeContext value;
  final ValueChanged<LifeContext> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final marital = {
      'single': l10n.maritalSingle,
      'dating': l10n.maritalDating,
      'married': l10n.maritalMarried,
      'separated': l10n.maritalSeparated,
      'divorced': l10n.maritalDivorced,
      'widowed': l10n.maritalWidowed,
    };
    final children = {'none': l10n.childrenNone, 'has': l10n.childrenHas};

    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: const Key('life-context'),
        tilePadding: EdgeInsets.zero,
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        leading: const Icon(Icons.person_search_outlined),
        title: Text(l10n.lifeTitle, style: theme.textTheme.titleSmall),
        subtitle: ContentText(l10n.lifeHint, contentKey: 'lifeHint', style: theme.textTheme.bodySmall),
        childrenPadding: const EdgeInsets.only(bottom: Space.m),
        children: [
          AppSwitchTile(
            key: const Key('life-use-name'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.lifeUseName),
            value: value.useName,
            onChanged: (v) => onChanged(value.copyWith(useName: v)),
          ),
          const SizedBox(height: Space.s),
          PlaceField(
            fieldKey: const Key('life-residence'),
            label: l10n.lifeResidence,
            value: value.residence,
            showDetail: false,
            onChanged: (p) => onChanged(value.copyWith(residence: p)),
            onClear: () => onChanged(value.copyWith(residence: null)),
          ),
          const SizedBox(height: Space.l),
          DropdownMenu<String>(
            key: const Key('life-marital'),
            expandedInsets: EdgeInsets.zero,
            label: Text(l10n.lifeMarital),
            initialSelection: value.marital ?? '',
            dropdownMenuEntries: [
              DropdownMenuEntry(value: '', label: l10n.lifeNotSet),
              for (final e in marital.entries) DropdownMenuEntry(value: e.key, label: e.value),
            ],
            onSelected: (v) => onChanged(value.copyWith(marital: (v == null || v.isEmpty) ? null : v)),
          ),
          const SizedBox(height: Space.l),
          DropdownMenu<String>(
            key: const Key('life-children'),
            expandedInsets: EdgeInsets.zero,
            label: Text(l10n.lifeChildren),
            initialSelection: value.children ?? '',
            dropdownMenuEntries: [
              DropdownMenuEntry(value: '', label: l10n.lifeNotSet),
              for (final e in children.entries) DropdownMenuEntry(value: e.key, label: e.value),
            ],
            onSelected: (v) => onChanged(value.copyWith(children: (v == null || v.isEmpty) ? null : v)),
          ),
          const SizedBox(height: Space.l),
          TextFormField(
            key: const Key('life-occupation'),
            initialValue: value.occupation,
            maxLength: 40,
            decoration: InputDecoration(labelText: l10n.lifeOccupation, prefixIcon: const Icon(Icons.work_outline)),
            onChanged: (v) => onChanged(value.copyWith(occupation: v)),
          ),
          TextFormField(
            key: const Key('life-family'),
            initialValue: value.family,
            maxLength: 200,
            minLines: 1,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: l10n.lifeFamily,
              hintText: l10n.lifeFamilyHint,
              prefixIcon: const Icon(Icons.family_restroom),
            ),
            onChanged: (v) => onChanged(value.copyWith(family: v)),
          ),
          TextFormField(
            key: const Key('life-concern'),
            initialValue: value.concern,
            maxLength: 300,
            minLines: 1,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: l10n.lifeConcern,
              hintText: l10n.lifeConcernHint,
              prefixIcon: const Icon(Icons.help_outline),
            ),
            onChanged: (v) => onChanged(value.copyWith(concern: v)),
          ),
        ],
      ),
    );
  }
}
