import 'models.dart';

/// Plain-text (Markdown) export of a passed report. The AI label and the
/// expectation copy are always included: an exported file must disclose the AI
/// content just as the screen does (compliance/ai_disclosure_spec.md §4).
String exportReportMarkdown({
  required ReportView report,
  required String title,
  required String subtitle,
  required String Function(String topic) topicLabel,
  required String Function(String horizon) horizonLabel,
  required Map<String, String> headings,
}) {
  final l = report.layers!;
  final b = StringBuffer()
    ..writeln('# $title')
    ..writeln()
    ..writeln(subtitle)
    ..writeln()
    ..writeln('> ${l.expectation.aiLabel}')
    ..writeln()
    ..writeln('## ${headings['facts']}')
    ..writeln();
  for (final f in l.facts) {
    b.writeln('- $f');
  }
  b
    ..writeln()
    ..writeln('## ${headings['interpretation']}');
  for (final s in l.interpretation) {
    b
      ..writeln()
      ..writeln('### ${topicLabel(s.topic)}')
      ..writeln();
    for (final p in s.paragraphs) {
      b
        ..writeln(p.text)
        ..writeln();
    }
  }
  b
    ..writeln('## ${headings['actions']}')
    ..writeln();
  for (final a in l.actions) {
    b.writeln('- **${topicLabel(a.topic)} · ${horizonLabel(a.horizon)}**：${a.text}');
  }
  b
    ..writeln()
    ..writeln('---')
    ..writeln()
    ..writeln(l.expectation.text)
    ..writeln()
    ..writeln('${l.expectation.aiLabel}${report.model == null ? '' : ' (${report.model})'}');
  return b.toString();
}
