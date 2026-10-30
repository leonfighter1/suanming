import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../../l10n/gen/app_localizations.dart';
import '../design.dart';
import '../labels.dart';

/// One paragraph of an AI reading, as the owner asked (v6.2.0, 术语在前，评论在后): the term first, then the plain
/// commentary, then an everyday example in a tinted box. A paragraph written before v6.2.0 has only its text.
/// Readings and 追问 answers both show their paragraphs with it.
class ReadingParagraph extends StatelessWidget {
  const ReadingParagraph({super.key, required this.paragraph, this.id, this.showSource = true});
  final Paragraph paragraph;

  /// Names the parts' keys, `term-$id` and `example-$id`, for tests.
  final String? id;

  /// The source-level pill under the paragraph.
  final bool showSource;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final p = paragraph;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (p.term != null) ...[
          Text(
            p.term!,
            key: id == null ? null : ValueKey<String>('term-$id'),
            textAlign: TextAlign.start,
            style: theme.textTheme.titleSmall?.copyWith(color: scheme.primary, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: Space.xs),
        ],
        Text(p.text, textAlign: TextAlign.start, style: ReadingText.body(context)),
        if (p.example != null) ...[
          const SizedBox(height: Space.s),
          Container(
            key: id == null ? null : ValueKey<String>('example-$id'),
            width: double.infinity,
            padding: const EdgeInsets.all(Space.m),
            decoration: BoxDecoration(
              color: scheme.secondaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(Radii.field),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The bulb centred on the example's first line.
                Padding(
                  padding: EdgeInsets.only(top: firstLineInset(ReadingText.small(context), 18)),
                  child: Icon(Icons.lightbulb_outline, size: 18, color: scheme.secondary),
                ),
                const SizedBox(width: Space.s),
                Expanded(
                  child: Text(p.example!, textAlign: TextAlign.start, style: ReadingText.small(context)),
                ),
              ],
            ),
          ),
        ],
        if (showSource) ...[
          const SizedBox(height: Space.s),
          Pill(AppLocalizations.of(context).sourceLevel(p.sourceLevel), icon: Icons.menu_book_outlined),
        ],
      ],
    );
  }
}
