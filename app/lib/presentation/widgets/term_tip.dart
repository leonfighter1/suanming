import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../l10n/gen/app_localizations.dart';
import '../design.dart';
import '../keyboard.dart';

/// What a 八字 term means, for the reader's script ('' if it has no tip).
String _tipOf(WidgetRef ref, String term) =>
    ref.watch(termsProvider).value?.tip(term, ref.watch(settingsProvider).apiLocaleCode) ?? '';

/// The tip in a dialog titled with the term as the page shows it. Esc or 关闭 closes it.
Future<void> showTermTip(BuildContext context, String title, String tip) => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('term-tip'),
        title: Text(title),
        content: Text(tip),
        // A TextButton sizes to its label (the theme widens only filled and outlined ones, rule 7).
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(AppLocalizations.of(context).close))],
      ),
    );

/// A term on the 命盘 the reader can tap, or reach with Tab and press Enter on, for what it means
/// (term_tips.json, synced from src/ai/term-tips.ts). It is underlined with dots; a term without a
/// tip stays plain text.
class TermTip extends ConsumerWidget {
  const TermTip(this.term, this.label, {super.key, this.title, this.style, this.textAlign, this.pill = false});

  /// The term as the engine writes it (simplified), e.g. 七杀.
  final String term;

  /// What the page shows, e.g. 七殺 or 桃花 · 月柱、日柱.
  final String label;

  /// The dialog's title: [label] unless the label carries more than the term.
  final String? title;
  final TextStyle? style;
  final TextAlign? textAlign;

  /// Shown as a [Pill] (旺衰, 神煞, 空亡, 胎元).
  final bool pill;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tip = _tipOf(ref, term);
    if (tip.isEmpty) return pill ? Pill(label) : Text(label, style: style, textAlign: textAlign);
    return Pressable(
      key: Key('tip-$term'),
      onPressed: () => showTermTip(context, title ?? label, tip),
      child: pill
          ? Pill(label, dotted: true)
          : Text(
              label,
              textAlign: textAlign,
              style: (style ?? const TextStyle()).copyWith(
                decoration: TextDecoration.underline,
                decorationStyle: TextDecorationStyle.dotted,
              ),
            ),
    );
  }
}

/// A card's 什么是…？ button, for the term the card is about (五行, 神煞, 大运, 流年).
class TermTipButton extends ConsumerWidget {
  const TermTipButton(this.term, this.title, {super.key});
  final String term;

  /// The term as the page names it, for the dialog and the tooltip.
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tip = _tipOf(ref, term);
    if (tip.isEmpty) return const SizedBox.shrink();
    return IconButton(
      key: Key('tip-$term'),
      tooltip: AppLocalizations.of(context).termTipAbout(title),
      visualDensity: VisualDensity.compact,
      icon: const Icon(Icons.help_outline, size: 20),
      onPressed: () => showTermTip(context, title, tip),
    );
  }
}
