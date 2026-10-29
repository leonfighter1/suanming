// S14 (the owner, 2026-10-28): 以往记录 — by year and month, newest first; by person; download as PDF or Word; send the
// selected; file under a person; delete.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mingli_app/application/providers.dart' show shareProvider, zhHans;
import 'package:mingli_app/domain/archive.dart';
import 'package:mingli_app/domain/models.dart';
import 'package:share_plus/share_plus.dart';

import 'keys.dart';
import 'support.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

const c1 = 'c1c1c1c1-0000-4000-8000-000000000001';
const c2 = 'c2c2c2c2-0000-4000-8000-000000000002';
const c3 = 'c3c3c3c3-0000-4000-8000-000000000003';
const c4 = 'c4c4c4c4-0000-4000-8000-000000000004';
const c5 = 'c5c5c5c5-0000-4000-8000-000000000005';
const r1 = 'a1a1a1a1-0000-4000-8000-000000000001';
const r2 = 'a2a2a2a2-0000-4000-8000-000000000002';
const r3 = 'a3a3a3a3-0000-4000-8000-000000000003';
const r4 = 'a4a4a4a4-0000-4000-8000-000000000004';
const r5 = 'a5a5a5a5-0000-4000-8000-000000000005';

Map<String, dynamic> item(String id, String chart, String at, Map<String, dynamic> summary, {String? person, String status = 'passed'}) => {
      'report_id': id,
      'chart_id': chart,
      'status': status,
      // Noon UTC: the same calendar day in any time zone a test runs in.
      'created_at': '${at}T12:00:00.000Z',
      'updated_at': '${at}T12:00:00.000Z',
      'locale': 'zh-Hans',
      'topics': ['wuxing'],
      'chart': summary,
      if (person != null) 'person': {'name': person},
    };

/// Four readings over two years and three people (one filed under nobody), with the 一生运势报告 (2026-10-25, filed
/// under nobody) from life_passed.
List<Map<String, dynamic>> history({bool pending = false}) => [
      item(r1, c1, '2026-10-20', {'system': 'bazi', 'four_pillars': '庚午 己卯 己卯 辛未'}, person: '徐梅'),
      item(r2, c2, '2026-10-05', {'system': 'tarot', 'spread': 'single', 'cards': []}, person: '徐梅'),
      item(r3, c3, '2026-09-12', {'system': 'qiuqian', 'lot': 1, 'ganzhi': '甲子'}, person: '测试家人'),
      item(r4, c4, '2025-12-30', {'system': 'liuyao', 'mode': 'auto'}),
      if (pending) item(r5, c5, '2026-10-26', {'system': 'tarot', 'spread': 'single', 'cards': []}, status: 'pending'),
    ];

/// Opens 以往记录 on a tall screen, with every record built.
Future<(FakeApi, List<ShareParams>)> openArchive(
  WidgetTester tester, {
  bool pending = false,
  bool verified = false,
  Map<String, dynamic>? finalReport,
  Size size = const Size(1000, 2600),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final api = FakeApi(pendingPolls: 0, history: history(pending: pending), emailVerified: verified, finalReport: finalReport);
  final shared = <ShareParams>[];
  await tester.pumpWidget(
    testApp(api, locale: zhHans, overrides: [shareProvider.overrideWithValue((p) async => shared.add(p))]),
  );
  await settle(tester);
  await tester.tap(find.byKey(const Key('open-history')));
  await settle(tester);
  return (api, shared);
}

Finder menuOf(String id, {bool life = false}) => find.byKey(ValueKey<String>('record-menu-${life ? 'life' : 'report'}:$id'));
double top(WidgetTester tester, Finder f) => tester.getTopLeft(f).dy;

Future<void> pickFromMenu(WidgetTester tester, String id, String entry) async {
  await tester.tap(menuOf(id));
  await settle(tester);
  await tester.tap(find.text(entry).last);
  await settle(tester);
}

void main() {
  final lifeId = fixture('life_passed')['life_report_id'] as String;

  test('by month: newest month first, each newest first; by person: the latest person first, nobody last', () {
    final records = [
      for (final h in history()) ArchiveRecord.reading(HistoryItem.fromJson(h)),
    ];
    final months = byMonth(records);
    expect([for (final m in months) '${m.year}-${m.month}'], ['2026-10', '2026-9', '2025-12']);
    expect([for (final r in months.first.records) r.id], [r1, r2]);
    final people = byPerson(records, (r) => personName(r, const {}));
    expect([for (final g in people) g.name], ['徐梅', '测试家人', null]);
    expect([for (final r in people.first.records) r.id], [r1, r2]);
    // A device label names a record the server keeps no person for (charts made before v6.2.0).
    expect(personName(records[3], {c4: '小明'}), '小明');
    expect(personName(records[0], {c1: '旧名'}), '徐梅'); // the server's person wins: 归类到… changes it
  });

  testWidgets('按时间: years, then months, newest first; the 一生运势报告 sits among the readings by date', (tester) async {
    await openArchive(tester);
    final order = [
      find.byKey(const ValueKey<String>('archive-year-2026')),
      find.byKey(const ValueKey<String>('archive-month-2026-10')),
      menuOf(lifeId, life: true), // 10-25
      menuOf(r1), // 10-20
      menuOf(r2), // 10-05
      find.byKey(const ValueKey<String>('archive-month-2026-9')),
      menuOf(r3),
      find.byKey(const ValueKey<String>('archive-year-2025')),
      find.byKey(const ValueKey<String>('archive-month-2025-12')),
      menuOf(r4),
    ];
    for (final f in order) {
      expect(f, findsOneWidget);
    }
    for (var i = 1; i < order.length; i++) {
      expect(top(tester, order[i - 1]), lessThan(top(tester, order[i])), reason: '$i');
    }
    expect(find.text('2026 年'), findsOneWidget);
    expect(find.text('10 月'), findsOneWidget);
  });

  testWidgets('按人: one group per person, the latest first, records filed under nobody last', (tester) async {
    await openArchive(tester);
    await tester.tap(find.text('按人'));
    await settle(tester);
    final order = [
      find.byKey(const ValueKey<String>('archive-person-徐梅')),
      menuOf(r1),
      menuOf(r2),
      find.byKey(const ValueKey<String>('archive-person-测试家人')),
      menuOf(r3),
      find.byKey(const ValueKey<String>('archive-person--')),
      menuOf(lifeId, life: true),
      menuOf(r4),
    ];
    for (var i = 1; i < order.length; i++) {
      expect(top(tester, order[i - 1]), lessThan(top(tester, order[i])), reason: '$i');
    }
    expect(find.text('未归类'), findsOneWidget);
  });

  testWidgets('a record downloads as PDF: its document, rendered by the server, shared as a .pdf', (tester) async {
    final (api, shared) = await openArchive(tester);
    await pickFromMenu(tester, r1, '下载 PDF');
    final sent = api.documents.single;
    expect(sent['format'], 'pdf');
    expect((sent['filename'] as String), startsWith('命理大师-徐梅-的命盘-2026-10-20'));
    final doc = sent['document'] as Map<String, dynamic>;
    expect(doc['title'], '徐梅 的命盘');
    final blocks = (doc['blocks'] as List).cast<Map<String, dynamic>>();
    expect(blocks.first, {
      'type': 'kv',
      'rows': [
        ['姓名', '徐梅'],
        ['类型', '八字排盘'],
        ['时间', anything],
      ],
    });
    // The reading in its three parts, and the AI label last.
    expect(blocks.map((b) => b['type']), containsAll(['h2', 'h3', 'term', 'p', 'example', 'bullet', 'note']));
    expect(blocks.last['type'], 'note');
    expect(shared.single.fileNameOverrides!.single, endsWith('.pdf'));
  });

  testWidgets('选择: tick several, 发送 asks PDF or Word, then shares them all', (tester) async {
    final (api, shared) = await openArchive(tester);
    await tester.tap(find.byKey(const Key('archive-select')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey<String>('pick-report:$r1')));
    await tester.tap(find.byKey(const ValueKey<String>('pick-report:$r3')));
    await settle(tester);
    expect(find.text('已选 2 项'), findsOneWidget);
    await tester.tap(find.byKey(const Key('archive-send')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('format-docx')));
    await settle(tester);
    expect(api.documents.map((d) => d['format']), ['docx', 'docx']);
    expect(shared.single.files, hasLength(2));
    expect(shared.single.fileNameOverrides!.every((n) => n.endsWith('.docx')), isTrue);
  });

  testWidgets('删除 asks first; cancelled, nothing goes; confirmed, the record leaves the list', (tester) async {
    final (api, _) = await openArchive(tester);
    await pickFromMenu(tester, r2, '删除');
    expect(find.text('删除这些记录？'), findsOneWidget);
    await tester.tap(find.byKey(const Key('delete-cancel')));
    await settle(tester);
    expect(api.deleted, isEmpty);
    await pickFromMenu(tester, r2, '删除');
    await tester.tap(find.byKey(const Key('delete-confirm')));
    await settle(tester);
    expect(api.deleted, [r2]);
    expect(menuOf(r1), findsOneWidget); // the list is there
    expect(menuOf(r2), findsNothing); // without the deleted one
  });

  testWidgets('归类到… files a record under a name typed in; 按人 then shows it there', (tester) async {
    final (api, _) = await openArchive(tester);
    await pickFromMenu(tester, r4, '归类到…');
    await tester.enterText(find.byKey(const Key('file-name')), '小明');
    await tester.pump();
    await tester.tap(find.byKey(const Key('file-save')));
    await settle(tester);
    expect(api.filed, {c4: '小明'});
    await tester.tap(find.text('按人'));
    await settle(tester);
    expect(find.byKey(const ValueKey<String>('archive-person-小明')), findsOneWidget);
  });

  testWidgets('a record still being written can\'t be downloaded yet', (tester) async {
    final (api, shared) = await openArchive(tester, pending: true);
    await pickFromMenu(tester, r5, '下载 PDF');
    expect(find.text('只有已完成的记录能下载或发送'), findsOneWidget);
    expect(api.documents, isEmpty);
    expect(shared, isEmpty);
  });

  testWidgets('the keyboard reaches the view switch, each record\'s menu and 选择; Enter opens a menu', (tester) async {
    await openArchive(tester);
    final stops = await tabStops(tester);
    expect(stops, containsAll(['archive-select', 'archive-view', 'record-menu-report:$r1', 'record-menu-report:$r4']));
    // In page order: 选择 in the bar, then the switch, then the records.
    expect(stops.indexOf('archive-view'), lessThan(stops.indexOf('record-menu-report:$r1')));
    await tabTo(tester, 'record-menu-report:$r1');
    await press(tester, LogicalKeyboardKey.enter);
    await settle(tester);
    expect(find.text('下载 PDF').hitTestable(), findsOneWidget);
  });

  testWidgets('the reading page and the 一生运势 page download PDF and Word too', (tester) async {
    final (api, shared) = await openArchive(tester);
    await tester.tap(find.text('徐梅 的命盘'));
    await settle(tester);
    await tester.tap(find.byKey(const Key('report-menu')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('download-docx')));
    await settle(tester);
    expect(api.documents.single['format'], 'docx');
    expect((api.documents.single['document'] as Map)['title'], '徐梅 的命盘');

    Navigator.of(tester.element(find.byKey(const Key('report-menu')))).pop();
    await settle(tester);
    await tester.tap(find.byKey(Key('history-life-$lifeId')));
    await settle(tester);
    await settle(tester);
    await tester.tap(find.byKey(const Key('life-download')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('life-download-pdf')));
    await settle(tester);
    expect(api.documents.last['format'], 'pdf');
    final blocks = ((api.documents.last['document'] as Map)['blocks'] as List).cast<Map<String, dynamic>>();
    expect(blocks.first['type'], 'kv'); // the report's 项目 / 内容 rows
    expect(shared, hasLength(2));
  });

  // 发到邮箱 (v9.0.0, tech plan WP15.4).
  testWidgets('发到邮箱 without a verified email says to verify it first, and sends nothing', (tester) async {
    final (api, _) = await openArchive(tester);
    await pickFromMenu(tester, r1, '发到邮箱');
    expect(find.text('先在“设置”里验证邮箱，才能发到邮箱'), findsOneWidget);
    expect(find.byKey(const Key('format-pdf')), findsNothing);
    expect(api.emailed, isEmpty);
  });

  testWidgets('发到邮箱 asks PDF or Word, then mails the record to the verified email', (tester) async {
    final (api, shared) = await openArchive(tester, verified: true);
    await pickFromMenu(tester, r1, '发到邮箱');
    await tester.tap(find.byKey(const Key('format-pdf')));
    await settle(tester);
    final body = api.emailed.single;
    expect(body['format'], 'pdf');
    final docs = (body['documents'] as List).cast<Map<String, dynamic>>();
    expect(docs.map((d) => (d['document'] as Map)['title']), ['徐梅 的命盘']);
    // As a download is named (docFileName): the title with dashes for spaces, then the day.
    expect(docs.single['filename'], '命理大师-徐梅-的命盘-2026-10-20');
    expect(find.text('已发到 m***@example.com（测试环境：写在服务器的 .outbox 文件夹里）'), findsOneWidget);
    // Mail, not the share sheet.
    expect(shared, isEmpty);
  });

  testWidgets('选择 then 发邮箱 mails every chosen record in one message; the bar fits a 360-wide phone', (tester) async {
    final (api, _) = await openArchive(tester, verified: true, size: const Size(360, 2600));
    await tester.tap(find.byKey(const Key('archive-select')));
    await settle(tester);
    for (final key in ['archive-download', 'archive-send', 'archive-email', 'archive-delete']) {
      final r = tester.getRect(find.byKey(Key(key)));
      expect(r.left >= 0 && r.right <= 360, isTrue, reason: '$key at $r');
    }
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey<String>('pick-report:$r1')));
    await tester.tap(find.byKey(const ValueKey<String>('pick-report:$r3')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('archive-email')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('format-docx')));
    await settle(tester);
    final body = api.emailed.single;
    expect(body['format'], 'docx');
    expect((body['documents'] as List), hasLength(2));
    // Done: the selection ends.
    expect(find.byKey(const Key('archive-email')), findsNothing);
  });

  testWidgets('a reading mailed when it was done says so on its page', (tester) async {
    final mailed = {...fixture('report_passed'), 'mail': {'status': 'sent', 'at': '2026-10-29T01:30:00.000Z'}};
    await openArchive(tester, finalReport: mailed);
    await tester.tap(find.text('徐梅 的命盘'));
    await settle(tester);
    expect(tester.widget<Text>(find.byKey(const Key('report-mail'))).data, '这份报告已发到你的邮箱');
  });

  testWidgets('a reading never mailed shows no line about mail', (tester) async {
    await openArchive(tester);
    await tester.tap(find.text('徐梅 的命盘'));
    await settle(tester);
    // A positive anchor first (rule 43): the reading is open, and the line that would sit over it is absent.
    expect(find.byKey(const Key('report-menu')), findsOneWidget);
    expect(find.byKey(const Key('report-mail')), findsNothing);
  });
}
