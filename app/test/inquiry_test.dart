// 深度分析 (v10.0.0, S19 WP19.2–19.4; the owner's requests 2026-10-29): the master asks before the reading, the page
// says 「大师现在有问题要问你」 and that the final reading comes after the questions; a goal first (一定要给出个明确的目标);
// the mic types what is said (麦克风输入); and a 测算 done before for the same person asks 是否还要重新再算一次.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mingli_app/application/providers.dart';
import 'package:mingli_app/platform/speech.dart';

import 'keys.dart';
import 'support.dart';

Future<void> settle(WidgetTester tester) async {
  // Progress indicators animate forever, so pumpAndSettle would time out; 900 ms covers BringIntoView (rule 61).
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Speech recognition that hears [heard] at once, or fails with [error].
class FakeSpeech implements SpeechInput {
  FakeSpeech({this.heard = '我想換一份能學東西的工作', this.error});
  final String heard;
  final String? error;
  String? lang;

  @override
  bool get available => true;

  @override
  Future<String?> listen({required String lang, required void Function(String text) onText}) async {
    this.lang = lang;
    if (error == null) onText(heard);
    return error;
  }

  @override
  void stop() {}
}

/// The test account: a default profile named 测试用户 (whose readings these are).
const me = '测试用户';

/// A fresh app on a phone, on the 塔羅 page with [question] asked and one card drawn and turned, so the AI reading
/// card is there.
Future<FakeApi> drawTarot(
  WidgetTester tester, {
  String question = '',
  FakeApi? api,
  FakeSpeech? speech,
}) async {
  tester.view.physicalSize = const Size(412, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final fake = api ?? FakeApi(email: 'test@mingli.local', pendingPolls: 0, finalReport: fixture('report_tarot_passed'));
  await tester.pumpWidget(const SizedBox.shrink()); // a fresh app (rule 24)
  await tester.pumpWidget(
    testApp(fake, overrides: [if (speech != null) speechInputProvider.overrideWithValue(speech)]),
  );
  await settle(tester);
  await openEntry(tester, 'tarot');
  await settle(tester);
  if (question.isNotEmpty) {
    await tester.enterText(find.byKey(const Key('tarot-question')), question);
    await tester.pump(); // rule 19
  }
  await scrollTo(tester, const Key('spread-single'));
  // The segment's button takes the touch; its label isn't in the hit path, hence no warning.
  await tester.tap(find.byKey(const Key('spread-single')), warnIfMissed: false);
  await settle(tester);
  await scrollTo(tester, const Key('draw'));
  await tester.tap(find.byKey(const Key('draw')));
  await settle(tester);
  await scrollTo(tester, const Key('ritual-skip'));
  await tester.tap(find.byKey(const Key('ritual-skip')));
  await settle(tester);
  await scrollTo(tester, const Key('tarot-card-1'));
  await tester.tap(find.byKey(const Key('tarot-card-1')));
  await settle(tester);
  return fake;
}

/// Presses 深度分析 under the AI button.
Future<void> startInquiry(WidgetTester tester) async {
  await scrollTo(tester, const Key('inquiry-start'));
  await tester.tap(find.byKey(const Key('inquiry-start')));
  await settle(tester);
}

Map<String, dynamic> lastPost(FakeApi api, String path) =>
    jsonDecode(api.requests.lastWhere((r) => r.method == 'POST' && r.url.path == path).body) as Map<String, dynamic>;

Future<void> answer(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(const Key('inquiry-field')), text);
  await tester.pump(); // rule 19
  await tester.tap(find.byKey(const Key('inquiry-send')));
  await settle(tester);
}

void main() {
  testWidgets('深度分析 sits under the AI button, saying what it does', (tester) async {
    await drawTarot(tester, question: '我們的關係會往哪裡走？');
    await scrollTo(tester, const Key('inquiry-start'));
    expect(find.descendant(of: find.byKey(const Key('inquiry-start')), matching: find.text('深度分析')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('inquiry-note'))).data,
      '大師先問你幾個問題（最多 6 個），再給出更貼合你的最終解答',
    );
    // Right under the main button.
    expect(
      tester.getTopLeft(find.byKey(const Key('inquiry-start'))).dy,
      greaterThan(tester.getTopLeft(find.byKey(const Key('generate-report'))).dy),
    );
  });

  testWidgets('without a goal the reminder asks for one first, and a short one is not enough', (tester) async {
    final api = await drawTarot(tester);
    await startInquiry(tester);
    expect(find.byKey(const Key('inquiry-goal-dialog')), findsOneWidget);
    expect(find.text('使用深度分析，一定要先給出一個明確的目標：你最想透過這次測算知道什麼？'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('inquiry-goal-field')), '看看');
    await tester.pump();
    await tester.tap(find.byKey(const Key('inquiry-goal-start')));
    await settle(tester);
    expect(find.text('目標太短了，請寫清楚你最想知道什麼'), findsOneWidget);
    expect(api.inquiries, isEmpty);
    await tester.enterText(find.byKey(const Key('inquiry-goal-field')), '明年適不適合換工作？');
    await tester.pump();
    await tester.tap(find.byKey(const Key('inquiry-goal-start')));
    await settle(tester);
    expect(lastPost(api, '/v1/inquiries')['goal'], '明年適不適合換工作？');
    expect(find.text('大師現在有問題要問你'), findsOneWidget);
  });

  testWidgets('the master asks, each answer brings the next question into view, and the reading reads them all', (tester) async {
    final api = FakeApi(
      email: 'test@mingli.local',
      pendingPolls: 0,
      finalReport: {...fixture('report_tarot_passed'), 'inquiry_id': '99999999-9999-4999-8999-000000000001'},
    );
    await drawTarot(tester, question: '我們還有可能嗎？', api: api);
    await startInquiry(tester);
    // The asked question is the goal: no reminder.
    expect(find.byKey(const Key('inquiry-goal-dialog')), findsNothing);
    expect(lastPost(api, '/v1/inquiries'), containsPair('goal', '我們還有可能嗎？'));
    expect(find.text('大師現在有問題要問你'), findsOneWidget);
    expect(find.text('回答完這些問題，大師才能給你最終解答。'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('inquiry-goal'))).data, '你的目標：我們還有可能嗎？');
    expect(find.text('（示範）大師的第1個問題？'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('inquiry-progress'))).data, '第 1 個問題 · 大師打算問 2 個（最多 6 個）');

    await answer(tester, '她知道我想分手');
    expect(find.text('她知道我想分手'), findsOneWidget);
    expect(find.text('（示範）大師的第2個問題？'), findsOneWidget);
    // The next question's field is on a phone's screen without scrolling (the owner's rule, MISTAKES 59).
    expect(find.byKey(const Key('inquiry-send')).hitTestable(), findsOneWidget);
    await answer(tester, '我只想知道分開以後還能不能找到對象');

    // Done: its last words, what it understood, and the start of the final reading, in view.
    expect(find.text('（示範）好，我了解了，現在給你做最終解答。'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('inquiry-understanding'))).data, '大師的理解：（示範）你最想知道的事');
    expect(find.byKey(const Key('inquiry-start-reading')).hitTestable(), findsOneWidget);
    expect(find.text('大師現在有問題要問你'), findsNothing);
    await tester.tap(find.byKey(const Key('inquiry-start-reading')));
    await settle(tester);
    final asked = lastPost(api, '/v1/reports');
    expect(asked['inquiry_id'], '99999999-9999-4999-8999-000000000001');
    expect(asked['question'], '我們還有可能嗎？');

    // The reading shows its conversation, folded.
    final recap = find.byKey(const Key('inquiry-recap'), skipOffstage: false);
    expect(recap, findsOneWidget);
    expect(find.descendant(of: recap, matching: find.text('深度分析 · 大師問了你 2 個問題')), findsOneWidget);
    expect(find.byKey(const Key('inquiry-field')), findsNothing); // the page was replaced
  });

  testWidgets('Enter answers; 跳過 goes to the reading with what was said', (tester) async {
    final api = await drawTarot(tester, question: '我們還有可能嗎？');
    await startInquiry(tester);
    await tester.enterText(find.byKey(const Key('inquiry-field')), '她知道我想分手');
    // Enter in the field: the web performs its action, as receiveAction does here.
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await settle(tester);
    expect(lastPost(api, '/v1/inquiries/99999999-9999-4999-8999-000000000001/answers'), {'answer': '她知道我想分手'});
    expect(find.text('（示範）大師的第2個問題？'), findsOneWidget);
    await tester.tap(find.byKey(const Key('inquiry-skip')));
    await settle(tester);
    expect(lastPost(api, '/v1/reports')['inquiry_id'], '99999999-9999-4999-8999-000000000001');
  });

  testWidgets('a first question that never came offers to start again', (tester) async {
    final api = FakeApi(email: 'test@mingli.local', pendingPolls: 0, finalReport: fixture('report_tarot_passed'))
      ..inquiryFails = true;
    await drawTarot(tester, question: '我們還有可能嗎？', api: api);
    await startInquiry(tester);
    expect(find.byKey(const Key('inquiry-failed')), findsOneWidget);
    expect(find.text('大師現在有問題要問你'), findsNothing);
    api.inquiryFails = false;
    await tester.tap(find.byKey(const Key('inquiry-retry')));
    await settle(tester);
    expect(api.inquiries, hasLength(2));
    expect(find.text('（示範）大師的第1個問題？'), findsOneWidget);
  });

  testWidgets('the mic types what is said into the answer, in the reader\'s Chinese', (tester) async {
    final speech = FakeSpeech();
    await drawTarot(tester, question: '我們還有可能嗎？', speech: speech);
    await startInquiry(tester);
    await tester.tap(find.byKey(const Key('mic-inquiry')));
    await settle(tester);
    expect(tester.widget<TextField>(find.byKey(const Key('inquiry-field'))).controller!.text, '我想換一份能學東西的工作');
    expect(speech.lang, 'zh-TW'); // the test app reads 繁體
  });

  testWidgets('the mic says when the browser may not listen, and is not there where nothing can', (tester) async {
    await drawTarot(tester, question: '我們還有可能嗎？', speech: FakeSpeech(error: 'not-allowed'));
    await startInquiry(tester);
    await tester.tap(find.byKey(const Key('mic-inquiry')));
    await settle(tester);
    expect(find.text('需要允許使用麥克風，才能語音輸入'), findsOneWidget);

    // The test VM can't listen, as a phone app can't: no button, beside a field that is there (rule 43).
    await drawTarot(tester, question: '我們還有可能嗎？');
    await startInquiry(tester);
    expect(find.byKey(const Key('inquiry-field')), findsOneWidget);
    expect(find.byKey(const Key('mic-inquiry')), findsNothing);
  });

  testWidgets('a 卦 asked before for the same person asks 是否還要重新再算一次', (tester) async {
    final earlier = fixture('report_tarot_passed');
    final api = FakeApi(
      email: 'test@mingli.local',
      pendingPolls: 0,
      finalReport: earlier,
      history: [
        {
          'report_id': earlier['report_id'],
          'chart_id': earlier['chart_id'],
          'status': 'passed',
          // Midday UTC: the dialog shows the reader's own date, the 25th from UTC−11 to UTC+11.
          'created_at': '2026-10-25T12:00:00.000Z',
          'updated_at': '2026-10-25T12:00:00.000Z',
          'locale': 'zh-Hant',
          'topics': ['tarot_cards', 'tarot_synthesis', 'tarot_advice'],
          'chart': {'system': 'tarot', 'spread': 'three_card', 'cards': []},
          'person': {'name': me},
          'question': '我們的關係會往哪裡走？',
        },
      ],
    );
    tester.view.physicalSize = const Size(412, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(api));
    await settle(tester);
    await openEntry(tester, 'tarot');
    await settle(tester);

    // Another question: no dialog, the ritual starts.
    await tester.enterText(find.byKey(const Key('tarot-question')), '工作順利嗎？');
    await tester.pump();
    await scrollTo(tester, const Key('draw'));
    await tester.tap(find.byKey(const Key('draw')));
    await settle(tester);
    expect(find.byKey(const Key('recalc-dialog')), findsNothing);
    expect(find.byKey(const Key('ritual-skip')), findsOneWidget);

    // The same question, punctuated otherwise: asked first.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(testApp(api));
    await settle(tester);
    await openEntry(tester, 'tarot');
    await settle(tester);
    await tester.enterText(find.byKey(const Key('tarot-question')), '我們的關係會往哪裡走');
    await tester.pump();
    await scrollTo(tester, const Key('draw'));
    await tester.tap(find.byKey(const Key('draw')));
    await settle(tester);
    expect(find.byKey(const Key('recalc-dialog')), findsOneWidget);
    expect(find.text('「$me」在 2026-10-25 已經算過塔羅，問的是「我們的關係會往哪裡走？」。是否還要重新再算一次？'), findsOneWidget);
    // 查看之前的 opens the earlier reading, and no new draw starts.
    await tester.tap(find.byKey(const Key('recalc-view')));
    await settle(tester);
    expect(find.byKey(const Key('ritual-skip')), findsNothing);
    expect(find.byKey(const Key('jump-list'), skipOffstage: false), findsOneWidget);

    // Back, and 重新再算 goes on to the draw.
    await systemBack(tester);
    await settle(tester);
    await scrollTo(tester, const Key('draw'));
    await tester.tap(find.byKey(const Key('draw')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('recalc-again')));
    await settle(tester);
    expect(find.byKey(const Key('ritual-skip')), findsOneWidget);
  });

  testWidgets('keyboard: Esc on the 深度分析 asks before it ends; Tab reaches the field, 跳過 and 回答', (tester) async {
    await drawTarot(tester, question: '我們還有可能嗎？');
    await startInquiry(tester);
    final stops = await tabStops(tester);
    expect(stops.indexOf('inquiry-field'), greaterThanOrEqualTo(0));
    expect(stops.indexOf('inquiry-field'), lessThan(stops.indexOf('inquiry-skip')));
    expect(stops.indexOf('inquiry-skip'), lessThan(stops.indexOf('inquiry-send')));
    await press(tester, LogicalKeyboardKey.escape);
    await settle(tester);
    expect(find.byKey(const Key('leave-confirm')), findsOneWidget);
    expect(find.text('深度分析還沒做完，返回後這次的問答就結束了。'), findsOneWidget);
    await tester.tap(find.byKey(const Key('leave-stay')));
    await settle(tester);
    expect(find.text('大師現在有問題要問你'), findsOneWidget);
  });

  testWidgets('a 八字 chart read before for the same person asks first; 重新再算 goes on to 排盤', (tester) async {
    tester.view.physicalSize = const Size(412, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = FakeApi(email: 'test@mingli.local', pendingPolls: 0)..person = {'name': me};
    await tester.pumpWidget(testApp(api));
    await settle(tester);
    await openEntry(tester, 'bazi');
    await settle(tester);
    await scrollTo(tester, const Key('compute-chart'));
    await tester.tap(find.byKey(const Key('compute-chart')));
    await settle(tester);
    expect(find.byKey(const Key('recalc-dialog')), findsOneWidget);
    expect(find.textContaining('「$me」在 '), findsOneWidget);
    expect(find.textContaining('已經算過八字排盤。是否還要重新再算一次？'), findsOneWidget);
    expect(api.requests.where((r) => r.method == 'POST' && r.url.path == '/v1/charts'), isEmpty);
    await tester.tap(find.byKey(const Key('recalc-again')));
    await settle(tester);
    expect(api.requests.where((r) => r.method == 'POST' && r.url.path == '/v1/charts'), hasLength(1));
    expect(find.text('$me 的命盤'), findsWidgets);
  });

  testWidgets('追問 takes the mic too, where the device can listen', (tester) async {
    tester.view.physicalSize = const Size(412, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testApp(FakeApi(pendingPolls: 0), overrides: [speechInputProvider.overrideWithValue(FakeSpeech(heard: '明年工作怎麼樣？'))]),
    );
    await settle(tester);
    await openFromMenu(tester, 'menu-history');
    await settle(tester);
    await tester.tap(find.text('八字排盤').last);
    await settle(tester);
    await tester.tap(find.byKey(const Key('followup-fab')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('mic-followup')));
    await settle(tester);
    expect(tester.widget<TextField>(find.byKey(const Key('followup-field'))).controller!.text, '明年工作怎麼樣？');
  });

  testWidgets('on a 360 × 740 phone each new question, and then 開始最終解答, come into view by themselves', (tester) async {
    // The owner's standing rule (MISTAKES 59): five questions run past the screen; without BringIntoView the field
    // and the start button would stay below it and these taps would miss.
    final api = FakeApi(email: 'test@mingli.local', pendingPolls: 0, finalReport: fixture('report_tarot_passed'))
      ..inquiryPlanned = 5;
    await drawTarot(tester, question: '我們還有可能嗎？', api: api);
    tester.view.physicalSize = const Size(360, 740);
    await settle(tester);
    await startInquiry(tester);
    for (var n = 1; n <= 5; n++) {
      expect(find.byKey(const Key('inquiry-send')).hitTestable(), findsOneWidget, reason: 'question $n');
      await answer(tester, '第$n個回答，說得長一點，好讓對話超過一個手機螢幕的高度。');
    }
    expect(find.byKey(const Key('inquiry-start-reading')).hitTestable(), findsOneWidget);
    expect(api.inquiries.values.single['turns'], hasLength(5));
  });
}
