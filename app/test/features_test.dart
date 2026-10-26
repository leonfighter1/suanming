import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mingli_app/data/profile_store.dart';
import 'package:mingli_app/domain/export.dart';
import 'package:mingli_app/domain/models.dart';
import 'package:mingli_app/domain/profile.dart';

import 'support.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> scrollAndTap(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 300, scrollable: mainScrollable);
  await tester.ensureVisible(finder);
  await settle(tester);
  await tester.tap(finder);
}

void main() {
  testWidgets('test account gets an editable default profile used by the 八字 form', (tester) async {
    final profiles = InMemoryProfileStore();
    final api = FakeApi(email: 'test@mingli.local');
    await tester.pumpWidget(testApp(api, profiles: profiles));
    await settle(tester);

    expect(find.text('你好，測試用戶'), findsOneWidget);
    final book = ProfileBook.decode(profiles.data['u1']);
    expect(book.defaultProfile!.name, '測試用戶');

    await tester.tap(find.byKey(const Key('entry-bazi')));
    await settle(tester);
    expect(find.byKey(const Key('profile-picker')), findsOneWidget);
    // 農曆 preview for the profile's birth date
    expect(find.textContaining('農曆 庚午年二月十九'), findsOneWidget);

    await scrollAndTap(tester, find.byKey(const Key('compute-chart')));
    await settle(tester);
    final body = jsonDecode(api.requests.lastWhere((r) => r.url.path == '/v1/charts').body) as Map;
    expect(body['local'], '1990-03-15T14:30');
    expect(body.containsKey('name'), isFalse, reason: 'names never leave the device');

    expect(find.text('測試用戶 的命盤'), findsWidgets);
    await tester.scrollUntilVisible(find.byKey(const Key('lunar-card')), 300, scrollable: mainScrollable);
    expect(find.textContaining('庚午年二月十九 · 未時'), findsOneWidget);
    expect(find.text('馬'), findsOneWidget);
    // The chart is labelled locally for history.
    expect(ProfileBook.decode(profiles.data['u1']).chartLabels.values, contains('測試用戶'));
  });

  testWidgets('accounts without a profile are prompted to create one', (tester) async {
    final profiles = InMemoryProfileStore();
    await tester.pumpWidget(testApp(FakeApi(), profiles: profiles));
    await settle(tester);
    expect(find.byKey(const Key('create-profile-prompt')), findsOneWidget);

    await tester.tap(find.byKey(const Key('create-profile-prompt')));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('profile-name')), '小明');
    await settle(tester);
    await scrollAndTap(tester, find.byKey(const Key('save-profile')));
    await settle(tester);

    expect(ProfileBook.decode(profiles.data['u1']).defaultProfile!.name, '小明');
    expect(find.text('你好，小明'), findsOneWidget);
  });

  testWidgets('while pending, the live pipeline stage is shown', (tester) async {
    final api = FakeApi(pendingPolls: -1, pendingStage: 'action');
    await tester.pumpWidget(testApp(api, pollInterval: const Duration(seconds: 5)));
    await settle(tester);
    await tester.tap(find.byKey(const Key('entry-bazi')));
    await settle(tester);
    await scrollAndTap(tester, find.byKey(const Key('compute-chart')));
    await settle(tester);
    await scrollAndTap(tester, find.byKey(const Key('generate-report')));
    await settle(tester);

    expect(find.byKey(const Key('analyzing')), findsOneWidget);
    expect(find.text('AI 正在深度分析中'), findsOneWidget);
    expect(find.text('整理行動建議'), findsOneWidget);
    expect(find.textContaining('已用時'), findsOneWidget);
    // Leave the page so the poller and timers stop, then let the last poll delay elapse.
    Navigator.of(tester.element(find.byKey(const Key('analyzing')))).pop();
    await settle(tester);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('history lists earlier readings and opens them', (tester) async {
    await tester.pumpWidget(testApp(FakeApi(pendingPolls: 0)));
    await settle(tester);
    await tester.tap(find.byKey(const Key('open-history')));
    await settle(tester);
    expect(find.text('歷史紀錄'), findsOneWidget);
    expect(find.text('八字排盤'), findsWidgets);
    await tester.tap(find.text('八字排盤').last);
    await settle(tester);
    expect(find.byKey(const Key('ai-label')), findsOneWidget);
    expect(find.byKey(const Key('report-menu')), findsOneWidget);
  });

  test('export always carries the AI label and the disclaimer', () {
    final r = ReportView.fromJson(fixture('report_passed'));
    final md = exportReportMarkdown(
      report: r,
      title: '命理大師 AI 解讀',
      subtitle: '測試用戶 的命盤',
      topicLabel: (t) => t,
      horizonLabel: (h) => h,
      headings: {'facts': '命盤事實', 'interpretation': '解讀', 'actions': '行動建議'},
    );
    expect(md, startsWith('# 命理大師 AI 解讀'));
    expect(md, contains(r.layers!.expectation.aiLabel));
    expect(md, contains(r.layers!.expectation.text));
    expect(md, contains('- 四柱：庚午 己卯 己卯 辛未'));
    for (final s in r.layers!.interpretation) {
      expect(md, contains(s.paragraphs.first.text));
    }
  });
}
