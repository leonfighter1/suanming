import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../domain/models.dart';
import '../../l10n/gen/app_localizations.dart';
import '../design.dart';
import '../theme.dart';

/// 起名 (v4.5.0): the candidate names, each with its pinyin and its characters' 五行 and meanings, the elements
/// they serve, and the note that a name decides no one's fate (and, until the owner's review, that the 字义库
/// still awaits it).
class NamesCard extends ConsumerWidget {
  const NamesCard({super.key, required this.chart});
  final NamingChart chart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(settingsProvider).apiLocaleCode;
    final library = ref.watch(termsProvider).value?.naming;
    final theme = Theme.of(context);
    final surname = chart.surname(locale);
    return AppCard(
      title: l10n.namingCandidates,
      icon: Icons.badge_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            chart.basis == 'balance' ? l10n.namingBalance : l10n.namingElements(chart.elements.join('、')),
            key: const Key('naming-elements'),
            style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary),
          ),
          const SizedBox(height: Space.m),
          for (final (i, c) in chart.candidates.indexed)
            Padding(
              key: ValueKey<String>('candidate-$i'),
              padding: const EdgeInsets.only(bottom: Space.m),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('$surname${c.given(locale)}', style: theme.textTheme.headlineSmall?.copyWith(letterSpacing: 2)),
                      const SizedBox(width: Space.m),
                      Flexible(child: Text(c.pinyin, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant))),
                    ],
                  ),
                  const SizedBox(height: Space.xs),
                  Wrap(
                    spacing: Space.m,
                    runSpacing: Space.xs,
                    children: [
                      for (final ch in c.given(locale).split(''))
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '$ch ${library?.char(ch)?.element ?? ''} ',
                                style: TextStyle(
                                  color: wuxingColorOf(context, library?.char(ch)?.element ?? ''),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              TextSpan(text: library?.char(ch)?.meaning(locale) ?? ''),
                            ],
                          ),
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          // Until the owner has reviewed the 字义库, the card says so.
          Text(
            chart.reviewed ? l10n.namingNote : '${l10n.namingDraft}${l10n.namingNote}',
            key: const Key('naming-note'),
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
