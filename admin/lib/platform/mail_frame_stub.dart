import 'package:flutter/material.dart';
import 'package:mingli_app/presentation/design.dart';
import 'package:mingli_app/presentation/tokens.dart';

/// Not on the web: no frame to show the mail's page in, so its text, as a mail program without HTML shows it.
class MailFrame extends StatelessWidget {
  const MailFrame({super.key, required this.html, required this.text, required this.height});
  final String html;
  final String text;
  final double height;

  @override
  Widget build(BuildContext context) {
    final t = ThemeTokens.of(context);
    return Container(
      key: const Key('mail-text'),
      constraints: BoxConstraints(minHeight: height / 2),
      padding: const EdgeInsets.all(Space.l),
      decoration: BoxDecoration(
        color: t.inset,
        borderRadius: BorderRadius.circular(Radii.field),
        border: Border.all(color: t.border),
      ),
      child: SelectableText(text, style: ReadingText.small(context)),
    );
  }
}
