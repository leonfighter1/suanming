import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/providers.dart';
import '../domain/terms.dart';
import '../l10n/gen/app_localizations.dart';
import 'buttons.dart';
import 'design.dart';
import 'keyboard.dart';
import 'layout.dart';
import 'widgets/tarot_spread.dart';

/// 牌义图鉴 (v2.7.0): all 78 cards with their art and the three keywords painted on each,
/// in deck order: the major arcana, then wands, cups, swords and pentacles.
class TarotGlossaryPage extends ConsumerWidget {
  const TarotGlossaryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final terms = ref.watch(termsProvider).value;
    final locale = ref.watch(settingsProvider).apiLocaleCode;
    final ids = terms?.cardIds ?? const <String>[];
    final groups = [
      (l10n.glossaryMajor, ids.where((id) => id.startsWith('major_')).toList()),
      for (final (suit, name) in [
        ('wands', l10n.glossaryWands),
        ('cups', l10n.glossaryCups),
        ('swords', l10n.glossarySwords),
        ('pentacles', l10n.glossaryPentacles),
      ])
        (name, ids.where((id) => id.startsWith('${suit}_')).toList()),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tarotGlossary)),
      body: ListView(
        padding: pagePadding(context),
        children: [
          for (final (name, cards) in groups)
            AppCard(
              key: Key('glossary-group-${cards.isEmpty ? name : cards.first.split('_').first}'),
              title: '$name · ${cards.length}',
              icon: Icons.style_outlined,
              child: Wrap(
                spacing: Space.s,
                runSpacing: Space.m,
                children: [
                  for (final id in cards)
                    if (terms != null) _Tile(id: id, terms: terms, locale: locale),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.id, required this.terms, required this.locale});
  final String id;
  final Terms terms;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final name = terms.card(id, locale);
    return Pressable(
      key: Key('glossary-$id'),
      label: name,
      onPressed: () => showDialog<void>(
        context: context,
        builder: (_) => _CardMeaning(id: id, name: name, keywords: terms.keywords(id, locale)),
      ),
      child: SizedBox(
        width: 76,
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(Radii.xs),
              child: Image.asset(
                tarotArt(id),
                width: 76,
                height: 130,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox(width: 76, height: 130),
              ),
            ),
            const SizedBox(height: Space.xs),
            Text(name, textAlign: TextAlign.center, maxLines: 2, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

/// One card large, with its three keywords. Esc or 关闭 closes it.
class _CardMeaning extends StatelessWidget {
  const _CardMeaning({required this.id, required this.name, required this.keywords});
  final String id;
  final String name;
  final List<String> keywords;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      key: const Key('glossary-card'),
      title: Text(name, textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.chip),
            child: Image.asset(
              tarotArt(id),
              width: 200,
              height: 343,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox(width: 200, height: 343),
            ),
          ),
          const SizedBox(height: Space.l),
          Text(l10n.glossaryKeywords, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: Space.s),
          Wrap(
            key: const Key('glossary-keywords'),
            alignment: WrapAlignment.center,
            spacing: Space.s,
            runSpacing: Space.s,
            children: [for (final w in keywords) Pill(w)],
          ),
        ],
      ),
      // A TextButton sizes to its label (the theme widens only filled and outlined ones, rule 7).
      actions: [AppTextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.close))],
    );
  }
}
