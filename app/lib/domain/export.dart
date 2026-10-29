import 'document.dart';
import 'models.dart';

/// A paragraph's three parts as blocks (v6.2.0): the term, the commentary, the example.
List<DocBlock> paragraphBlocks(Paragraph p) => [
      if (p.term != null) DocBlock('term', p.term),
      DocBlock('p', p.text),
      if (p.example != null) DocBlock('example', p.example),
    ];

/// A record's 追问 (v7.0.0): each question as asked, then its answer. Questions not answered (yet) are left out.
List<DocBlock> followUpBlocks(
  List<FollowUpView> followUps, {
  required String heading,
  required String asked,
  required String outOfScope,
}) {
  final answered = followUps.where((f) => f.status == 'passed').toList();
  if (answered.isEmpty) return const [];
  return [
    DocBlock('h2', heading),
    for (final f in answered) ...[
      DocBlock('question', '$asked${f.question}'),
      if (!f.inScope) DocBlock('note', outOfScope),
      for (final p in f.paragraphs) ...paragraphBlocks(p),
    ],
  ];
}

/// 八字's 总结 (v9.3.0) as blocks, before the sections as on the page; none for a reading without one.
List<DocBlock> conclusionBlocks(ReportLayers l, String? heading, String Function(String part) partLabel) => [
      if (l.conclusion.isNotEmpty) DocBlock('h2', heading),
      for (final c in l.conclusion) ...[DocBlock('h3', partLabel(c.part)), DocBlock('p', c.text)],
    ];

/// A passed reading as a document (v8.0.0), for Word and PDF: what its page shows, its 追问, and the AI label and the
/// disclaimer, which every export carries (compliance/ai_disclosure_spec.md §4). [details] are its label–value rows
/// (whose it is, where they were born); [headings] name facts, conclusion, interpretation, actions, trend, total,
/// followups, asked and outOfScope.
Doc reportDocument({
  required ReportView report,
  required String title,
  required String subtitle,
  required List<(String, String)> details,
  required String Function(String topic) topicLabel,
  required String Function(String horizon) horizonLabel,
  required String Function(String part) conclusionLabel,
  required Map<String, String> headings,
  List<FollowUpView> followUps = const [],
}) {
  final l = report.layers!;
  final blocks = <DocBlock>[
    if (details.isNotEmpty) DocBlock.kv(details),
    DocBlock('h2', headings['facts']),
    for (final f in l.facts) DocBlock('bullet', f),
  ];
  final t = l.trend;
  if (t != null) {
    blocks.add(DocBlock('h2', '${headings['trend']}（${headings['total']} ${t.total}/100）'));
    for (final p in [...t.dayun, ...t.liunian]) {
      blocks.add(DocBlock('bullet', '${p.label} ${p.ganzhi}：${p.overall} · ${p.note}'));
    }
    blocks.add(DocBlock('note', t.methodNote));
  }
  blocks
    ..addAll(conclusionBlocks(l, headings['conclusion'], conclusionLabel))
    ..add(DocBlock('h2', headings['interpretation']));
  for (final s in l.interpretation) {
    blocks.add(DocBlock('h3', topicLabel(s.topic)));
    if (s.summary != null) blocks.add(DocBlock('summary', s.summary));
    for (final p in s.paragraphs) {
      blocks.addAll(paragraphBlocks(p));
    }
  }
  if (l.actions.isNotEmpty) {
    blocks.add(DocBlock('h2', headings['actions']));
    for (final a in l.actions) {
      blocks.add(DocBlock('bullet', '${topicLabel(a.topic)} · ${horizonLabel(a.horizon)}：${a.text}'));
    }
  }
  blocks.addAll(
    followUpBlocks(
      followUps,
      heading: headings['followups']!,
      asked: headings['asked']!,
      outOfScope: headings['outOfScope']!,
    ),
  );
  blocks
    ..add(const DocBlock.divider())
    ..add(DocBlock('note', l.expectation.text))
    ..add(DocBlock('note', '${l.expectation.aiLabel}${report.model == null ? '' : '（${report.model}）'}'));
  return Doc(title: title, subtitle: subtitle, blocks: blocks);
}

/// Plain-text (Markdown) export of a passed report. The AI label and the
/// expectation copy are always included: an exported file must disclose the AI
/// content just as the screen does (compliance/ai_disclosure_spec.md §4).
String exportReportMarkdown({
  required ReportView report,
  required String title,
  required String subtitle,
  required String Function(String topic) topicLabel,
  required String Function(String horizon) horizonLabel,
  required String Function(String part) conclusionLabel,
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
  // 八字's 总结 (v9.3.0), before the sections as on the page.
  if (l.conclusion.isNotEmpty) {
    b
      ..writeln()
      ..writeln('## ${headings['conclusion']}');
    for (final c in l.conclusion) {
      b
        ..writeln()
        ..writeln('### ${conclusionLabel(c.part)}')
        ..writeln()
        ..writeln(c.text);
    }
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
    // 术语 → 评论 → 例子 (v6.2.0), as on screen; an older paragraph is its text alone.
    for (final p in s.paragraphs) {
      if (p.term != null) {
        b
          ..writeln('**${p.term}**')
          ..writeln();
      }
      b
        ..writeln(p.text)
        ..writeln();
      if (p.example != null) {
        b
          ..writeln('> ${p.example}')
          ..writeln();
      }
    }
  }
  // 八字 writes no 行动建议 since v9.3.0: the heading only when there are some.
  if (l.actions.isNotEmpty) {
    b
      ..writeln('## ${headings['actions']}')
      ..writeln();
    for (final a in l.actions) {
      b.writeln('- **${topicLabel(a.topic)} · ${horizonLabel(a.horizon)}**：${a.text}');
    }
    b.writeln();
  }
  b
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
