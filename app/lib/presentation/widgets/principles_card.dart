import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../l10n/gen/app_localizations.dart';
import '../content_text.dart';
import '../design.dart';

/// 风水 (v4.4.0): what to look at in a room, as general principles of space with their everyday reasons,
/// and the facing's traditional association when one was given. Never a 吉凶 judgement of a home.
class PrinciplesCard extends ConsumerWidget {
  const PrinciplesCard({super.key, required this.room, this.facing});
  final String room;
  final String? facing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(settingsProvider).apiLocaleCode;
    final table = ref.watch(termsProvider).value?.fengshui;
    if (table == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final f = facing == null ? null : table.facing(facing!, locale);
    return AppCard(
      title: '${table.roomName(room, locale)} · ${l10n.fengshuiPrinciples}',
      icon: Icons.explore_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (f != null) ...[
            Text(
              l10n.fengshuiDirection(f.name, f.trigram, f.element),
              key: const Key('fengshui-direction'),
              style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary),
            ),
            const SizedBox(height: Space.m),
          ],
          for (final (i, p) in table.principles(room).indexed)
            Padding(
              key: ValueKey<String>('principle-${p.id}'),
              padding: const EdgeInsets.only(bottom: Space.m),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StepNumber(i + 1),
                  const SizedBox(width: Space.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.text(locale), style: theme.textTheme.titleSmall),
                        const SizedBox(height: Space.xs),
                        Text(
                          p.why(locale),
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ContentText(l10n.fengshuiNote, contentKey: 'fengshuiNote', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
