// A record as a document (v8.0.0, the owner: 下载后可以生成Word文档和PDF). The app builds it from what it shows; the
// server renders it to Word or PDF (POST /v1/documents, src/export/document.ts has the same block types).

/// Word or PDF.
enum DocFormat {
  pdf('pdf', 'application/pdf'),
  docx('docx', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document');

  const DocFormat(this.ext, this.mime);
  final String ext;
  final String mime;
}

/// One block: h2, h3, meta, p, summary, term, example, quote, bullet, kv, note, question or divider.
class DocBlock {
  const DocBlock(this.type, [this.text]) : rows = null;
  const DocBlock.kv(List<(String, String)> this.rows) : type = 'kv', text = null;
  const DocBlock.divider() : type = 'divider', text = null, rows = null;

  final String type;
  final String? text;
  final List<(String, String)>? rows;

  Map<String, Object?> toJson() => {
        'type': type,
        'text': ?text,
        if (rows != null) 'rows': [for (final (k, v) in rows!) [k, v]],
      };
}

class Doc {
  const Doc({required this.title, this.subtitle, required this.blocks});
  final String title;
  final String? subtitle;
  final List<DocBlock> blocks;

  Map<String, Object?> toJson() => {
        'title': title,
        'subtitle': ?subtitle,
        'blocks': [for (final b in blocks) b.toJson()],
      };
}

/// The file's name without its extension: `命理大师-title-date`, with characters a file name can't hold left out
/// (the server checks it again).
String docFileName(String title, DateTime? at) {
  String two(int n) => n.toString().padLeft(2, '0');
  final day = at == null ? '' : '-${at.year}-${two(at.month)}-${two(at.day)}';
  final clean = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), ' ').replaceAll(RegExp(r'\s+'), '-');
  return '命理大师-$clean$day';
}
