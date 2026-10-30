import 'package:flutter/material.dart';

import '../design.dart';

/// The report's title band: whose report it is and the three methods, on the brand gradient.
class LifeHero extends StatelessWidget {
  const LifeHero({super.key, required this.title, required this.subtitle});
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: Space.l),
      padding: const EdgeInsets.symmetric(vertical: Space.xl, horizontal: Space.l),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.card),
        gradient: LinearGradient(colors: [scheme.primary, scheme.tertiary], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Column(
        children: [
          Icon(Icons.auto_stories, color: scheme.onPrimary, size: 36),
          const SizedBox(height: Space.s),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(color: scheme.onPrimary, fontWeight: FontWeight.w700, letterSpacing: 2),
          ),
          const SizedBox(height: Space.xs),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onPrimary.withValues(alpha: 0.85), letterSpacing: 1.5),
          ),
        ],
      ),
    );
  }
}

/// A small boxed note with an info icon (the report's 说明).
class LifeNote extends StatelessWidget {
  const LifeNote({super.key, required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: Space.l),
      padding: const EdgeInsets.all(Space.m),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(Radii.field),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: firstLineInset(ReadingText.caption(context), 18)),
            child: Icon(Icons.info_outline, size: 18, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(width: Space.s),
          Expanded(child: Text(text, style: ReadingText.caption(context))),
        ],
      ),
    );
  }
}

/// One of the report's six numbered sections: a card with a coloured bar before its title.
class LifeSection extends StatelessWidget {
  const LifeSection({super.key, required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 22,
                decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(Radii.xxs)),
              ),
              const SizedBox(width: Space.s),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(color: scheme.primary, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.s),
          ...children,
        ],
      ),
    );
  }
}

/// A sub-heading inside a section.
class LifeSub extends StatelessWidget {
  const LifeSub(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: Space.l, bottom: Space.s),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
  );
}

/// A line with a bullet (the 起卦 steps, a topic's points without a period).
class LifeBullet extends StatelessWidget {
  const LifeBullet(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: Space.xs),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The dot centred on the first line.
        Padding(
          padding: EdgeInsets.only(top: firstLineInset(ReadingText.small(context), 5), right: Space.s),
          child: const CircleAvatar(radius: 2.5),
        ),
        Expanded(child: Text(text, style: ReadingText.small(context))),
      ],
    ),
  );
}

/// Classical text set off by a bar on the left (卦辞, 爻辞).
class LifeQuote extends StatelessWidget {
  const LifeQuote(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: Space.s),
      padding: const EdgeInsets.fromLTRB(Space.m, Space.s, Space.m, Space.s),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.35),
        border: Border(left: BorderSide(color: scheme.primary, width: 4)),
      ),
      child: Text(text, style: ReadingText.body(context)?.copyWith(fontWeight: FontWeight.w600)),
    );
  }
}

/// Text led by its bold, coloured label: 「label：text」.
class LifeLabeled extends StatelessWidget {
  const LifeLabeled(this.label, this.text, {super.key});
  final String label;
  final String text;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.s),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label：',
              style: TextStyle(fontWeight: FontWeight.w700, color: theme.colorScheme.primary),
            ),
            TextSpan(text: text),
          ],
        ),
        style: ReadingText.body(context),
      ),
    );
  }
}

/// A tinted box for a conclusion.
class LifeHighlight extends StatelessWidget {
  const LifeHighlight(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: Space.m),
      padding: const EdgeInsets.all(Space.m),
      decoration: BoxDecoration(color: scheme.tertiaryContainer.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(Radii.field)),
      child: Text(text, style: ReadingText.body(context)?.copyWith(fontWeight: FontWeight.w700)),
    );
  }
}

/// The header table: label and value rows, every other one shaded.
class LifeKeyValues extends StatelessWidget {
  const LifeKeyValues({super.key, required this.rows});
  final List<(String, String)> rows;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        for (final (i, (k, v)) in rows.indexed)
          Container(
            color: i.isEven ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35) : null,
            padding: const EdgeInsets.symmetric(vertical: Space.s, horizontal: Space.s),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 96,
                  child: Text(k, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ),
                Expanded(
                  child: Text(v, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
