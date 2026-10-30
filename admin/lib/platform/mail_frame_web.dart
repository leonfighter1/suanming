import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:mingli_app/presentation/design.dart';
import 'package:mingli_app/presentation/tokens.dart';
import 'package:web/web.dart' as web;

/// Web: the mail's own page (the server's HTML, light or dark as the preview asked) in a frame [height] tall, as a
/// mail program shows it. The frame is sandboxed (no scripts, an origin of its own); a new [html] replaces the page.
class MailFrame extends StatefulWidget {
  const MailFrame({super.key, required this.html, required this.text, required this.height});
  final String html;
  final String text;
  final double height;

  @override
  State<MailFrame> createState() => _MailFrameState();
}

class _MailFrameState extends State<MailFrame> {
  web.HTMLIFrameElement? _frame;

  @override
  void didUpdateWidget(MailFrame old) {
    super.didUpdateWidget(old);
    if (old.html != widget.html) _frame?.srcdoc = widget.html.toJS;
  }

  @override
  Widget build(BuildContext context) {
    final t = ThemeTokens.of(context);
    return Container(
      height: widget.height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.field),
        border: Border.all(color: t.border),
      ),
      child: HtmlElementView.fromTagName(
        key: const Key('mail-frame'),
        tagName: 'iframe',
        onElementCreated: (element) {
          final frame = element as web.HTMLIFrameElement;
          frame
            ..setAttribute('sandbox', '')
            ..title = '邮件预览'
            ..srcdoc = widget.html.toJS;
          frame.style
            ..border = 'none'
            ..width = '100%'
            ..height = '100%';
          _frame = frame;
        },
      ),
    );
  }
}
