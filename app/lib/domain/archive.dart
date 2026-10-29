// 以往记录 (v8.0.0, the owner): every reading and 一生运势报告 as one archive, by year and month (newest first) or by
// person.
import 'life_report.dart';
import 'models.dart';

/// One record of the archive: a reading or a 一生运势报告.
class ArchiveRecord {
  const ArchiveRecord.reading(HistoryItem this.reading) : life = null;
  const ArchiveRecord.life(LifeReportView this.life) : reading = null;

  final HistoryItem? reading;
  final LifeReportView? life;

  bool get isLife => life != null;
  String get id => reading?.reportId ?? life!.id;

  /// Tells the two kinds apart (their ids could meet).
  String get key => isLife ? 'life:$id' : 'report:$id';

  /// The API path its 追问 and document hang off.
  String get path => isLife ? 'life-reports/$id' : 'reports/$id';
  String get chartId => reading?.chartId ?? life!.chartId;
  DateTime get createdAt => (reading?.createdAt ?? life!.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)).toLocal();

  /// bazi, tarot, qiuqian, liuyao, fengshui, naming; `life` for a 一生运势报告.
  String get system => isLife ? 'life' : reading!.system;
  String get status => reading?.status ?? life!.status;
  bool get passed => status == 'passed';

  /// Whose it is, as the server keeps it with the chart.
  ChartPerson? get person => reading?.person ?? life?.person;
}

/// Whose record it is: the person kept with its chart, else this device's label (charts made before v6.2.0).
String? personName(ArchiveRecord r, Map<String, String> deviceLabels) {
  final kept = r.person?.name?.trim();
  if (kept != null && kept.isNotEmpty) return kept;
  final label = deviceLabels[r.chartId]?.trim();
  return label == null || label.isEmpty ? null : label;
}

/// One month of the archive.
class ArchiveMonth {
  const ArchiveMonth(this.year, this.month, this.records);
  final int year;
  final int month;
  final List<ArchiveRecord> records;
}

/// 按时间: months newest first, each month's records newest first (local time).
List<ArchiveMonth> byMonth(Iterable<ArchiveRecord> records) {
  final sorted = [...records]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  final out = <ArchiveMonth>[];
  for (final r in sorted) {
    final d = r.createdAt;
    if (out.isEmpty || out.last.year != d.year || out.last.month != d.month) {
      out.add(ArchiveMonth(d.year, d.month, []));
    }
    out.last.records.add(r);
  }
  return out;
}

/// One person's records.
class ArchivePerson {
  const ArchivePerson(this.name, this.records);

  /// Null: records filed under nobody (未归类).
  final String? name;
  final List<ArchiveRecord> records;
}

/// 按人: one group per person, the one with the latest record first, each group newest first; records filed under
/// nobody last.
List<ArchivePerson> byPerson(Iterable<ArchiveRecord> records, String? Function(ArchiveRecord) nameOf) {
  final sorted = [...records]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  final groups = <String?, List<ArchiveRecord>>{};
  for (final r in sorted) {
    groups.putIfAbsent(nameOf(r), () => []).add(r);
  }
  return [
    for (final e in groups.entries)
      if (e.key != null) ArchivePerson(e.key, e.value),
    if (groups[null] != null) ArchivePerson(null, groups[null]!),
  ];
}
