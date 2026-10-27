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
  final t = l.trend;
  if (t != null && headings['trend'] != null) {
    b
      ..writeln()
      ..writeln('## ${headings['trend']}（${headings['total']} ${t.total}/100）')
      ..writeln();
    for (final p in [...t.dayun, ...t.liunian]) {
      b.writeln('- ${p.label} ${p.ganzhi}：${p.overall} · ${p.note}');
    }
    b
      ..writeln()
      ..writeln(t.methodNote);
  }
  b
    ..writeln()
    ..writeln('## ${headings['interpretation']}');
  for (final s in l.interpretation) {
    b
      ..writeln()
      ..writeln('### ${topicLabel(s.topic)}')
      ..writeln();
    if (s.summary != null) {
      b
        ..writeln('**${s.summary}**')
        ..writeln();
    }
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

/// Plain-text (Markdown) export of a 破除運勢 plan, with the AI label.
String exportRemedyMarkdown({
  required RemedyView remedy,
  required String title,
  required String aiLabel,
  required String Function(String horizon) horizonLabel,
  required Map<String, String> headings,
}) {
  final b = StringBuffer()
    ..writeln('# $title')
    ..writeln()
    ..writeln('> $aiLabel')
    ..writeln()
    ..writeln('## ${headings['target']}')
    ..writeln()
    ..writeln(remedy.target)
    ..writeln()
    ..writeln(remedy.summary)
    ..writeln();
  if (remedy.focusPeriods.isNotEmpty) {
    b
      ..writeln('## ${headings['focus']}')
      ..writeln();
    for (final p in remedy.focusPeriods) {
      b.writeln('- $p');
    }
    b.writeln();
  }
  b
    ..writeln('## ${headings['steps']}')
    ..writeln();
  var i = 1;
  for (final s in remedy.steps) {
    b
      ..writeln('${i++}. **${s.title}**（${horizonLabel(s.horizon)}）')
      ..writeln('   ${s.text}');
  }
  b
    ..writeln()
    ..writeln('## ${headings['basis']}')
    ..writeln()
    ..writeln(remedy.basis)
    ..writeln()
    ..writeln('---')
    ..writeln()
    ..writeln(remedy.closing);
  return b.toString();
}
