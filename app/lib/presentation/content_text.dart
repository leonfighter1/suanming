import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/rich_text.dart';
import '../generated/content_l10n.dart';
import '../generated/content_rich.dart';
import '../l10n/gen/app_localizations.dart';
import '../platform/open_link.dart';
import 'keyboard.dart';
import 'tokens.dart';

/// A text of 内容 shown as content (S33 WP33.4; the owner: 「同时可以让当前的改动支持HTML和CSS」): staff's HTML where
/// they wrote some (bold, the theme's colours, lists, links), else its words. [plain] is what l10n gives, a tag never
/// in it; [contentKey] is its key written out (`contentKey: 'homeBaziDesc'`), which tells the server the text may hold
/// HTML (src/content/usage.ts). A widget that shows a text for its callers (EmptyState, HeroBanner) takes the key so too.
class ContentText extends StatelessWidget {
  const ContentText(
    this.plain, {
    super.key,
    required this.contentKey,
    this.style,
    this.textAlign,
    this.values = const {},
  });
  final String plain;
  final String contentKey;
  final TextStyle? style;
  final TextAlign? textAlign;

  /// The placeholders' values, as l10n's method for the text takes them.
  final Map<String, Object> values;

  @override
  Widget build(BuildContext context) {
    final l10n = Localizations.of<AppLocalizations>(context, AppLocalizations);
    final html = l10n is ContentLocalizations ? l10n.richOf(contentKey, values) : null;
    if (html == null) return Text(plain, style: style, textAlign: textAlign);
    final base = DefaultTextStyle.of(context).style.merge(style);
    return Text.rich(TextSpan(children: richSpans(context, parseRich(html), base)), style: style, textAlign: textAlign);
  }
}

/// [nodes] as spans over [base]: what each tag and inline style says, the colours from the theme (light or dark as it
/// is), a link as a control of its own (Tab reaches it, Enter opens it).
List<InlineSpan> richSpans(BuildContext context, List<RichNode> nodes, TextStyle base) {
  final t = ThemeTokens.of(context);
  final spans = <InlineSpan>[];
  var ended = true;
  void words(String text, TextStyle style) {
    if (text.isEmpty) return;
    spans.add(TextSpan(text: text, style: style));
    ended = text.endsWith('\n');
  }

  void line() {
    if (!ended) words('\n', base);
  }

  TextStyle styled(String tag, Map<String, String> attributes, TextStyle s) {
    var out = switch (tag) {
      'b' || 'strong' => s.copyWith(fontWeight: FontWeight.w700),
      'i' || 'em' => s.copyWith(fontStyle: FontStyle.italic),
      'u' => s.copyWith(decoration: TextDecoration.underline),
      's' => s.copyWith(decoration: TextDecoration.lineThrough),
      'small' => s.copyWith(fontSize: (s.fontSize ?? 14) * 12 / 14),
      _ => s,
    };
    for (final MapEntry(:key, :value) in styleOf(attributes['style']).entries) {
      final token = RegExp(r'^var\(--([a-z-]+)\)$').firstMatch(value)?[1];
      final color = token == null ? null : richColor(token, t);
      final px = double.tryParse(RegExp(r'^(\d+(?:\.\d+)?)px$').firstMatch(value)?[1] ?? '');
      final weight = value == 'bold' ? 700 : (value == 'normal' ? 400 : int.tryParse(value));
      out = switch (key) {
        'color' when color != null => out.copyWith(color: color),
        'background-color' when color != null => out.copyWith(backgroundColor: color),
        'font-weight' when weight != null && weight >= 100 && weight <= 900 =>
          out.copyWith(fontWeight: FontWeight.values[weight ~/ 100 - 1]),
        'font-style' => out.copyWith(fontStyle: value == 'italic' ? FontStyle.italic : FontStyle.normal),
        'font-size' when px != null => out.copyWith(fontSize: px.clamp(richFontSizeMin, richFontSizeMax)),
        'text-decoration' => out.copyWith(
            decoration: switch (value) {
              'underline' => TextDecoration.underline,
              'line-through' => TextDecoration.lineThrough,
              _ => TextDecoration.none,
            },
          ),
        _ => out,
      };
    }
    return out;
  }

  void walk(List<RichNode> nodes, TextStyle style) {
    for (final n in nodes) {
      switch (n) {
        case RichWords(:final text):
          words(text, style);
        case RichElement(tag: 'br'):
          words('\n', style);
        case RichElement(tag: 'a', :final attributes, :final children):
          final label = plainOf(children.map(_html).join());
          final href = attributes['href'] ?? '';
          spans.add(WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: Pressable(
              label: label,
              onPressed: () => _openLink(context, href),
              child: Text(label, style: styled('a', attributes, style).copyWith(color: t.accent, decoration: TextDecoration.underline)),
            ),
          ));
          ended = false;
        case RichElement(tag: final tag && ('ul' || 'ol'), :final children):
          line();
          var number = 0;
          for (final item in children.whereType<RichElement>().where((e) => e.tag == 'li')) {
            line();
            words(tag == 'ol' ? '${++number}. ' : '• ', style);
            walk(item.children, styled('li', item.attributes, style));
          }
          line();
        case RichElement(tag: 'p', :final attributes, :final children):
          line();
          walk(children, styled('p', attributes, style));
          line();
        case RichElement(:final tag, :final attributes, :final children):
          walk(children, styled(tag, attributes, style));
      }
    }
  }

  walk(nodes, base);
  // No new line after the last words.
  while (spans.isNotEmpty && spans.last is TextSpan && (spans.last as TextSpan).text == '\n') {
    spans.removeLast();
  }
  return spans;
}

/// A piece back as HTML, for a link's words.
String _html(RichNode n) => switch (n) {
      RichWords(:final text) => escapeHtml(text),
      RichElement(:final tag, :final children) => '<$tag>${children.map(_html).join()}</$tag>',
    };

/// A link opened in a new tab; where there is none (the app off the web), its address copied, and a line says so.
Future<void> _openLink(BuildContext context, String url) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final copied = AppLocalizations.of(context).copied;
  if (await openInNewTab(url)) return;
  await Clipboard.setData(ClipboardData(text: url));
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text('$copied：$url')));
}
