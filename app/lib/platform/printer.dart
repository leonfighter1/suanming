/// Printing a document: the browser print dialog on web; elsewhere returns false
/// so the caller can fall back to the share sheet (which offers print on mobile).
library;

export 'printer_stub.dart' if (dart.library.js_interop) 'printer_web.dart';

/// A minimal printable HTML page (system fonts render CJK).
String printableHtml({required String title, required List<(String, List<String>)> sections, required String footer}) {
  String esc(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
  final body = StringBuffer();
  for (final (heading, paras) in sections) {
    if (heading.isNotEmpty) body.write('<h2>${esc(heading)}</h2>');
    for (final p in paras) {
      body.write('<p>${esc(p)}</p>');
    }
  }
  return '<!doctype html><html><head><meta charset="utf-8"><title>${esc(title)}</title>'
      '<style>body{font-family:system-ui,"PingFang TC","Microsoft JhengHei","Noto Sans CJK TC",sans-serif;'
      'max-width:720px;margin:32px auto;padding:0 16px;line-height:1.75;color:#222;text-align:left}'
      'h1{font-size:22px}h2{font-size:17px;margin-top:24px}footer{margin-top:32px;font-size:12px;color:#666}</style>'
      '</head><body><h1>${esc(title)}</h1>$body<footer>${esc(footer)}</footer></body></html>';
}
