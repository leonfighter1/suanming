import 'buttons.dart';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../application/providers.dart';
import '../domain/archive.dart';
import '../domain/document.dart';
import '../domain/export.dart';
import '../domain/models.dart';
import '../domain/terms.dart';
import '../l10n/gen/app_localizations.dart';
import 'design.dart';
import 'labels.dart';
import 'life_export.dart';
import 'life_report_page.dart' show lifeHeaderOf;
import 'widgets/remedy.dart' show compactButtons;

/// What 以往记录 does with a record (v8.0.0): its title, its document as Word or PDF, sending, filing under a person,
/// deleting. The history page, the reading page and the 一生运势 page share it.

/// The headings a reading's document is written under.
Map<String, String> readingHeadings(AppLocalizations l10n) => {
      'facts': l10n.layerFacts,
      'conclusion': l10n.layerConclusion,
      'interpretation': l10n.layerInterpretation,
      'actions': l10n.layerActions,
      'trend': l10n.trendTitle,
      'total': l10n.trendTotal,
      'followups': l10n.followUpTitle,
      'asked': l10n.followUpAsked,
      'outOfScope': l10n.followUpOutOfScope,
    };

/// A record's title, as history shows it: 「徐梅 的命盘」, 「算卦 · 天雷无妄」, 「徐梅 一生运势报告」…
String recordTitle(AppLocalizations l10n, ArchiveRecord r, {String? person, Terms? terms, required String locale}) {
  if (r.isLife) return person == null ? l10n.lifeEntry : l10n.lifeReportOf(person);
  final item = r.reading!;
  final room = item.room == null ? null : terms?.fengshui?.roomName(item.room!, locale);
  final surname = item.surname(locale);
  final hexagram = item.hexagram(locale);
  return switch (item.system) {
    'bazi' => person == null ? l10n.homeBazi : l10n.chartOf(person),
    'qiuqian' => l10n.homeQiuqian,
    'fengshui' => room == null ? l10n.homeFengshui : '${l10n.homeFengshui} · $room',
    'naming' => surname == null ? l10n.homeNaming : '${l10n.homeNaming} · $surname',
    'liuyao' => hexagram == null ? l10n.homeLiuyao : '${l10n.homeLiuyao} · $hexagram',
    _ => l10n.homeTarot,
  };
}

final _when = DateFormat('yyyy-MM-dd HH:mm');

/// A passed reading's document, from the reading itself (fetched again, with its 追问).
Future<Doc> readingDocumentOf(
  WidgetRef ref,
  AppLocalizations l10n, {
  required ReportView report,
  required String title,
  required String method,
  String? person,
  String? birthplace,
}) async {
  final followUps = (await ref.read(apiClientProvider).listFollowUps('reports/${report.id}')).items;
  final at = report.createdAt?.toLocal();
  return reportDocument(
    report: report,
    title: title,
    subtitle: [l10n.aiReport, if (at != null) _when.format(at)].join(' · '),
    details: [
      if (person != null) (l10n.name, person),
      if (birthplace != null) (l10n.city, birthplace),
      (l10n.archiveMethod, method),
      if (at != null) (l10n.archiveTime, _when.format(at)),
    ],
    topicLabel: l10n.topic,
    horizonLabel: l10n.horizon,
    conclusionLabel: l10n.conclusionPart,
    headings: readingHeadings(l10n),
    followUps: followUps,
  );
}

/// A 一生运势报告's document, with its 追问.
Future<Doc> lifeDocumentOf(
  WidgetRef ref,
  AppLocalizations l10n, {
  required String lifeReportId,
  String? person,
  String? birthplace,
}) async {
  final api = ref.read(apiClientProvider);
  final view = await api.getLifeReport(lifeReportId);
  final chart = await api.getChart(view.chartId);
  final followUps = (await api.listFollowUps('life-reports/$lifeReportId')).items;
  final hant = ref.read(settingsProvider).apiLocaleCode == 'zh-Hant';
  final lunar = chart.bazi.lunar;
  return lifeReportDocument(
    l10n: l10n,
    header: lifeHeaderOf(
      l10n: l10n,
      view: view,
      chart: chart,
      name: person ?? view.person?.name,
      place: birthplace ?? view.person?.birthplace,
      hant: hant,
    ),
    report: view,
    hant: hant,
    lunarMonth: lunar.monthName,
    lunarDay: lunar.dayName,
    followUps: followUps,
  );
}

/// A history record's document and its file name.
Future<(Doc, String)> recordDocument(WidgetRef ref, AppLocalizations l10n, ArchiveRecord r) async {
  final book = ref.read(profilesProvider).value;
  final locale = ref.read(settingsProvider).apiLocaleCode;
  final person = personName(r, book?.chartLabels ?? const {});
  final birthplace = r.person?.birthplace ?? book?.chartPlaces[r.chartId];
  final title = recordTitle(l10n, r, person: person, terms: ref.read(termsProvider).value, locale: locale);
  final doc = r.isLife
      ? await lifeDocumentOf(ref, l10n, lifeReportId: r.id, person: person, birthplace: birthplace)
      : await readingDocumentOf(
          ref,
          l10n,
          report: await ref.read(apiClientProvider).getReport(r.id),
          title: title,
          method: l10n.methodLabel(r.system),
          person: person,
          birthplace: birthplace,
        );
  return (doc, docFileName(title, r.createdAt));
}

/// Renders [docs] (each with its file name) as [format] on the server, then shares them: the system share sheet; on
/// the web, the browser's share where it can share files, else a download.
Future<void> shareDocuments(
  WidgetRef ref,
  List<(Doc, String)> docs,
  DocFormat format, {
  required String subject,
}) async {
  final api = ref.read(apiClientProvider);
  final locale = ref.read(settingsProvider).apiLocaleCode;
  final files = <(Uint8List, String)>[];
  for (final (doc, name) in docs) {
    files.add((await api.document(doc, format, fileName: name, locale: locale), '$name.${format.ext}'));
  }
  await ref.read(shareProvider)(
    ShareParams(
      files: [for (final (bytes, name) in files) XFile.fromData(bytes, mimeType: format.mime, name: name)],
      fileNameOverrides: [for (final (_, name) in files) name],
      subject: subject,
    ),
  );
}

/// PDF or Word, or null when the reader closes the question.
Future<DocFormat?> chooseFormat(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return showDialog<DocFormat>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(l10n.archiveFormatTitle),
      children: [
        SimpleDialogOption(
          key: const Key('format-pdf'),
          onPressed: () => Navigator.pop(context, DocFormat.pdf),
          child: Row(children: [const Icon(Icons.picture_as_pdf_outlined), const SizedBox(width: Space.m), Text(l10n.archiveFormatPdf)]),
        ),
        SimpleDialogOption(
          key: const Key('format-docx'),
          onPressed: () => Navigator.pop(context, DocFormat.docx),
          child: Row(children: [const Icon(Icons.description_outlined), const SizedBox(width: Space.m), Text(l10n.archiveFormatWord)]),
        ),
      ],
    ),
  );
}

/// Asks before deleting [count] records: it can't be undone.
Future<bool> confirmDelete(BuildContext context, int count) async {
  final l10n = AppLocalizations.of(context);
  final yes = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.archiveDeleteTitle),
      content: Text(l10n.archiveDeleteBody(count)),
      actions: [
        compactButtons(
          context,
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextButton(key: const Key('delete-cancel'), onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
              const SizedBox(width: Space.s),
              AppFilledButton(
                key: const Key('delete-confirm'),
                style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.archiveDelete),
              ),
            ],
          ),
        ),
      ],
    ),
  );
  return yes ?? false;
}

/// 归类到…: a person's name for a record ('' = filed under nobody), or null when the reader closes the question. Offers
/// the profiles on this device and any name typed in.
Future<String?> chooseFiling(BuildContext context, {required List<String> names, String? current}) {
  final l10n = AppLocalizations.of(context);
  final typed = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.archiveFile),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final name in names)
              ListTile(
                key: ValueKey<String>('file-$name'),
                leading: Icon(name == current ? Icons.radio_button_checked : Icons.radio_button_unchecked),
                title: Text(name),
                onTap: () => Navigator.pop(context, name),
              ),
            ListTile(
              key: const Key('file-none'),
              leading: Icon(current == null ? Icons.radio_button_checked : Icons.radio_button_unchecked),
              title: Text(l10n.archiveFileNone),
              onTap: () => Navigator.pop(context, ''),
            ),
            const SizedBox(height: Space.s),
            TextField(
              key: const Key('file-name'),
              controller: typed,
              maxLength: 40,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(labelText: l10n.archiveFileHint),
              onSubmitted: (v) => v.trim().isEmpty ? null : Navigator.pop(context, v.trim()),
            ),
          ],
        ),
      ),
      actions: [
        compactButtons(
          context,
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
              const SizedBox(width: Space.s),
              AppFilledButton(
                key: const Key('file-save'),
                onPressed: () => typed.text.trim().isEmpty ? null : Navigator.pop(context, typed.text.trim()),
                child: Text(l10n.save),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
