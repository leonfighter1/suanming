/// HTML and CSS in 内容 (S33 WP33.4; the owner: 「同时可以让当前的改动支持HTML和CSS，不仅仅只是resource」): a text staff
/// wrote with tags, read. The server checks a change against the subset (src/content/rich.ts); here it is read
/// tolerantly all the same: a tag the app doesn't show is left out with its words kept, one not closed closes at the
/// end. ContentText (presentation/content_text.dart) shows it; everywhere else its words alone ([plainOf]).
library;

/// A piece of a text's HTML: an element, or words.
sealed class RichNode {
  const RichNode();
}

class RichElement extends RichNode {
  const RichElement(this.tag, this.attributes, this.children);
  final String tag;
  final Map<String, String> attributes;
  final List<RichNode> children;
}

class RichWords extends RichNode {
  const RichWords(this.text);
  final String text;
}

/// Whether [text] holds HTML: a tag or an entity (the server's hasMarkup).
bool hasMarkup(String text) => RegExp(r'</?[A-Za-z][^>]*>|&(?:[A-Za-z]+|#\d+);').hasMatch(text);

final _entities = {'amp': '&', 'lt': '<', 'gt': '>', 'quot': '"', 'apos': "'", 'nbsp': String.fromCharCode(0xa0)};

/// [text]'s entities as the characters they stand for.
String _decode(String text) => text.replaceAllMapped(RegExp(r'&(#\d+|[A-Za-z]+);'), (m) {
      final e = m[1]!;
      if (e.startsWith('#')) return String.fromCharCode(int.parse(e.substring(1)));
      return _entities[e] ?? m[0]!;
    });

/// [text] made safe to stand in HTML: a value put into staff's HTML (a placeholder's).
String escapeHtml(String text) =>
    text.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');

const _void = {'br'};
const _blocks = {'p', 'ul', 'ol', 'li'};

/// [html] read into its pieces.
List<RichNode> parseRich(String html) {
  final root = <RichNode>[];
  // What is open, innermost last, each with its children so far.
  final open = <(String, Map<String, String>, List<RichNode>)>[];
  List<RichNode> here() => open.isEmpty ? root : open.last.$3;
  void close() {
    final (tag, attributes, children) = open.removeLast();
    here().add(RichElement(tag, attributes, children));
  }

  final token = RegExp(r'''<(/?)([A-Za-z][\w-]*)((?:\s+[^\s=>]+(?:\s*=\s*(?:"[^"]*"|'[^']*'|[^\s>]+))?)*)\s*(/?)>''');
  var at = 0;
  for (final m in token.allMatches(html)) {
    if (m.start > at) here().add(RichWords(_decode(html.substring(at, m.start))));
    at = m.end;
    final tag = m[2]!.toLowerCase();
    if (m[1]!.isNotEmpty) {
      // A closing tag closes what was opened since its own; one never opened is passed over.
      if (open.any((o) => o.$1 == tag)) {
        while (open.last.$1 != tag) {
          close();
        }
        close();
      }
      continue;
    }
    final attributes = <String, String>{
      for (final a in RegExp(r'''([^\s=>]+)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+)))?''').allMatches(m[3]!))
        a[1]!.toLowerCase(): _decode(a[2] ?? a[3] ?? a[4] ?? ''),
    };
    if (_void.contains(tag) || m[4]!.isNotEmpty) {
      here().add(RichElement(tag, attributes, const []));
    } else {
      open.add((tag, attributes, []));
    }
  }
  if (at < html.length) here().add(RichWords(_decode(html.substring(at))));
  while (open.isNotEmpty) {
    close();
  }
  return root;
}

/// A style attribute's declarations: {color: var(--accent), font-weight: bold}.
Map<String, String> styleOf(String? style) => {
      for (final d in (style ?? '').split(';'))
        if (d.contains(':')) d.substring(0, d.indexOf(':')).trim().toLowerCase(): d.substring(d.indexOf(':') + 1).trim(),
    };

/// [html]'s words alone, for a place that shows words (a title, a button): a <br>, a paragraph's or an item's end
/// is a new line, an item starts with a dot.
String plainOf(String html) {
  final out = StringBuffer();
  void walk(List<RichNode> nodes) {
    for (final n in nodes) {
      switch (n) {
        case RichWords(:final text):
          out.write(text);
        case RichElement(tag: 'br'):
          out.write('\n');
        case RichElement(:final tag, :final children):
          if (tag == 'li') out.write('• ');
          walk(children);
          if (_blocks.contains(tag) && !out.toString().endsWith('\n')) out.write('\n');
      }
    }
  }

  walk(parseRich(html));
  return out.toString().trimRight();
}
