import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mingli_app/application/providers.dart';
import 'package:mingli_app/data/profile_store.dart';
import 'package:mingli_app/domain/models.dart';

import 'keys.dart';
import 'reading_page_test.dart' show openTarotReading;
import 'support.dart';

/// Opens the history's 八字 reading (report_passed) on a phone-sized screen.
Future<FakeApi> openReading(WidgetTester tester, {FakeApi? api}) async {
  tester.view.physicalSize = const Size(412, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final fake = api ?? FakeApi(pendingPolls: 0);
  await tester.pumpWidget(testApp(fake, locale: zhHans));
  await frames(tester, 12);
  await openFromMenu(tester, 'menu-history');
  await frames(tester, 12);
  await tester.tap(find.text('八字排盘').last);
  await frames(tester, 12);
  return fake;
}

Map<String, dynamic> lastAsk(FakeApi api) =>
    jsonDecode(api.requests.lastWhere((r) => r.method == 'POST' && r.url.path.endsWith('/followups')).body)
        as Map<String, dynamic>;

void main() {
  testWidgets('a passed reading floats 继续追问, and the button brings the card up with the cursor in it', (tester) async {
    await openReading(tester);
    final fab = find.byKey(const Key('followup-fab'));
    expect(fab, findsOneWidget);
    expect(find.descendant(of: fab, matching: find.text('继续追问')), findsOneWidget);
    // The jump list starts with 追问.
    final jump = find.byKey(const Key('jump-followup'));
    expect(jump, findsOneWidget);
    expect(tester.getTopLeft(jump).dx, lessThan(tester.getTopLeft(find.byKey(const Key('jump-wuxing'))).dx));

    expect(fab.hitTestable(), findsOneWidget);
    await tester.tap(fab);
    await frames(tester, 12);
    final field = find.byKey(const Key('followup-field'));
    expect(field.hitTestable(), findsOneWidget);
    expect(tester.widget<TextField>(field).focusNode!.hasFocus, isTrue);
    // With the field on screen the button steps aside, so it never covers 发送.
    expect(find.byKey(const Key('followup-send')).hitTestable(), findsOneWidget);
    expect(fab.hitTestable(), findsNothing);
    // The method's starters, before anything is asked.
    expect(find.text('我适合什么样的工作？'), findsOneWidget);
  });

  testWidgets('the card comes right after the reading, before 行动建议', (tester) async {
    // 八字 writes no 行动建议 since v9.3.0; a tarot reading still has them.
    await openTarotReading(tester);
    // Every card of a reading is built (the jump list needs them), so their places can be compared unscrolled.
    final report = ReportView.fromJson(fixture('report_tarot_passed'));
    // Below the fold they count as offstage to a finder, so look past that.
    final reading = tester.getTopLeft(find.byKey(const Key('expand-all'), skipOffstage: false)).dy;
    final card = tester.getTopLeft(find.byKey(const Key('followup-card'), skipOffstage: false)).dy;
    final actions = tester.getTopLeft(find.text(report.layers!.actions.first.text, skipOffstage: false)).dy;
    expect(reading, lessThan(card));
    expect(card, lessThan(actions));
  });

  testWidgets('asking: Enter sends, the answer comes in three parts, and a suggestion asks the next', (tester) async {
    final api = await openReading(tester);
    await tester.tap(find.byKey(const Key('followup-fab')));
    await frames(tester, 12);
    await tester.enterText(find.byKey(const Key('followup-field')), '明年我的事业怎么样？');
    // Enter in the field: the web performs its action, as receiveAction does here.
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await frames(tester, 12);
    expect(lastAsk(api), {'question': '明年我的事业怎么样？'});
    await scrollTo(tester, const ValueKey<String>('followup-question-0'));
    expect(find.text('明年我的事业怎么样？'), findsOneWidget);

    await frames(tester, 12);
    await scrollTo(tester, const ValueKey<String>('followup-answer-0'));
    final answer = fixture('followup_passed')['answer'] as Map<String, dynamic>;
    final p = (answer['paragraphs'] as List).first as Map<String, dynamic>;
    expect(tester.widget<Text>(find.byKey(const ValueKey<String>('term-followup-0-0'))).data, p['term']);
    expect(find.text(p['text'] as String), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('example-followup-0-0')), findsOneWidget);

    final next = (answer['suggestions'] as List).first as String;
    await scrollTo(tester, const ValueKey<String>('followup-suggestion-0'));
    expect(find.text(next), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('followup-suggestion-0')));
    await frames(tester, 12);
    expect(lastAsk(api), {'question': next});
  });

  testWidgets('a reply to a question the reading can\'t answer says so', (tester) async {
    final api = FakeApi(pendingPolls: 0)..followUpInScope = false;
    await openReading(tester, api: api);
    await tester.tap(find.byKey(const Key('followup-fab')));
    await frames(tester, 12);
    await tester.enterText(find.byKey(const Key('followup-field')), '我家的猫会好起来吗？');
    await tester.tap(find.byKey(const Key('followup-send')));
    await frames(tester, 12);
    await frames(tester, 12);
    await scrollTo(tester, const ValueKey<String>('followup-out-of-scope-0'));
    expect(find.text('超出这次结果能回答的范围'), findsOneWidget);
  });

  testWidgets('busy, the limit and the day\'s cap each get their own message', (tester) async {
    final api = await openReading(tester);
    await tester.tap(find.byKey(const Key('followup-fab')));
    await frames(tester, 12);
    for (final (status, code, text) in [
      (409, 'followup_pending', '上一个追问还在回答，请稍候'),
      (409, 'followup_limit', '这次结果的追问次数已用完'),
      (429, null, '今天的 AI 次数已用完，请明天再来'),
    ]) {
      api.followUpError = {'title': 'x', 'status': status, 'code': ?code};
      await tester.enterText(find.byKey(const Key('followup-field')), '问题');
      await tester.tap(find.byKey(const Key('followup-send')));
      await frames(tester, 12);
      expect(find.text(text), findsOneWidget, reason: '$status $code');
      ScaffoldMessenger.of(tester.element(find.byKey(const Key('followup-card')))).removeCurrentSnackBar();
      await frames(tester, 12);
    }
  });

  testWidgets('at the limit the field says so and nothing can be sent', (tester) async {
    final api = FakeApi(pendingPolls: 0)..followUpLimit = 1;
    await openReading(tester, api: api);
    await tester.tap(find.byKey(const Key('followup-fab')));
    await frames(tester, 12);
    await tester.enterText(find.byKey(const Key('followup-field')), '第一问');
    await tester.tap(find.byKey(const Key('followup-send')));
    await frames(tester, 12);
    await frames(tester, 12);
    await scrollTo(tester, const Key('followup-send'));
    expect(tester.widget<FilledButton>(find.byKey(const Key('followup-send'))).onPressed, isNull);
    expect(tester.widget<TextField>(find.byKey(const Key('followup-field'))).enabled, isFalse);
    expect(find.text('这次结果的追问次数已用完'), findsOneWidget);
  });

  testWidgets('Tab reaches the field and the send button', (tester) async {
    await openReading(tester);
    await tester.tap(find.byKey(const Key('followup-fab')));
    await frames(tester, 12);
    expect(focusedKey(), 'followup-field');
    await tester.enterText(find.byKey(const Key('followup-field')), '问题');
    await press(tester, LogicalKeyboardKey.tab);
    expect(focusedKey(), 'followup-send');
  });

  testWidgets('every method\'s reading has 追问', (tester) async {
    for (final (fixtureName, starter) in [
      ('report_tarot_passed', '这组牌最想提醒我什么？'),
      ('report_qiuqian_passed', '签诗里哪一句最要紧？'),
      ('report_liuyao_passed', '动爻在提醒我什么？'),
      ('report_fengshui_passed', '我先改哪一处最容易？'),
    ]) {
      await tester.pumpWidget(const SizedBox());
      final api = FakeApi(pendingPolls: 0, finalReport: fixture(fixtureName));
      await openReading(tester, api: api);
      expect(find.byKey(const Key('followup-fab')), findsOneWidget, reason: fixtureName);
      await tester.tap(find.byKey(const Key('followup-fab')));
      await frames(tester, 12);
      expect(find.text(starter), findsOneWidget, reason: fixtureName);
    }
  });

  testWidgets('the 一生运势报告 has 追问 too', (tester) async {
    tester.view.physicalSize = const Size(412, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = FakeApi(pendingPolls: 0);
    await tester.pumpWidget(testApp(api, profiles: InMemoryProfileStore(), locale: zhHans));
    await frames(tester, 12);
    await openFromMenu(tester, 'menu-history');
    await frames(tester, 12);
    await tester.tap(find.text('一生运势报告'));
    await frames(tester, 12);
    await frames(tester, 12);
    await tester.tap(find.byKey(const Key('followup-fab')));
    await frames(tester, 12);
    expect(find.text('我哪个阶段最需要用心？'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('followup-field')), '我哪个阶段最需要用心？');
    await tester.tap(find.byKey(const Key('followup-send')));
    await frames(tester, 12);
    expect(api.requests.last.url.path, matches(RegExp(r'^/v1/life-reports/[^/]+/followups$')));
  });
}
