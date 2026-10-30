// v11.1.0 (the owner, 2026-10-29): 「求签和算卦 算法必须要有所问之问题之后才能去求。也就是说问题不能为空 是必须要有所求才能去求」,
// then 「塔罗牌也是一样」. On 求籤, 算卦 and 塔羅 every way to draw waits for the question (the button, Enter in the field,
// Ctrl+Enter), the page says why, and the draw carries the question.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'keys.dart';
import 'support.dart';

Future<FakeApi> open(WidgetTester tester, String system) async {
  tester.view.physicalSize = const Size(412, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final api = FakeApi();
  await tester.pumpWidget(testApp(api));
  await frames(tester, 10);
  await openEntry(tester, system);
  await frames(tester, 10);
  return api;
}

bool enabled(WidgetTester tester, String key) => tester.widget<ButtonStyleButton>(find.byKey(Key(key))).enabled;

Iterable<Map<String, dynamic>> draws(FakeApi api) => api.requests
    .where((r) => r.method == 'POST' && r.url.path == '/v1/charts')
    .map((r) => jsonDecode(r.body) as Map<String, dynamic>);

void main() {
  testWidgets('求籤: nothing is drawn before something is asked', (tester) async {
    final api = await open(tester, 'qiuqian');
    expect(enabled(tester, 'draw-lot'), isFalse);
    expect(find.text('先寫下所求之事，才能求籤'), findsOneWidget);
    // Enter in the empty field, Ctrl+Enter and spaces alone draw nothing.
    await tester.tap(find.byKey(const Key('qiuqian-question')));
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await press(tester, LogicalKeyboardKey.enter, control: true);
    await ask(tester, 'qiuqian-question', '   ');
    expect(enabled(tester, 'draw-lot'), isFalse);
    await frames(tester);
    expect(draws(api), isEmpty);

    await ask(tester, 'qiuqian-question', '今年適合換工作嗎？');
    expect(enabled(tester, 'draw-lot'), isTrue);
    expect(find.byKey(const Key('qiuqian-question-missing')), findsNothing);
    await press(tester, LogicalKeyboardKey.enter, control: true);
    await frames(tester, 6);
    expect(draws(api).single, containsPair('question', '今年適合換工作嗎？'));
  });

  testWidgets('算卦: no coin is cast, or laid out, before something is asked', (tester) async {
    final api = await open(tester, 'liuyao');
    expect(enabled(tester, 'liuyao-toss'), isFalse);
    expect(find.text('先寫下想問的事，才能起卦'), findsOneWidget);
    await press(tester, LogicalKeyboardKey.enter, control: true);
    await frames(tester);
    expect(draws(api), isEmpty);
    // 自己挑幣: laying the coins out begins the cast; it waits too.
    await tester.tap(find.descendant(of: find.byKey(const Key('liuyao-mode')), matching: find.text('自己挑幣')));
    await frames(tester);
    expect(enabled(tester, 'liuyao-lay-out'), isFalse);
    await tester.tap(find.descendant(of: find.byKey(const Key('liuyao-mode')), matching: find.text('自動擲幣')));
    await frames(tester);

    await ask(tester, 'liuyao-question', '這個項目能不能做成？');
    expect(find.byKey(const Key('liuyao-question-missing')), findsNothing);
    expect(enabled(tester, 'liuyao-toss'), isTrue);
    await tester.tap(find.byKey(const Key('liuyao-toss')));
    await frames(tester, 6);
    expect(draws(api).single, containsPair('question', '這個項目能不能做成？'));
  });

  testWidgets('塔羅: no card is drawn before something is asked; the question stays as asked through the ritual',
      (tester) async {
    final api = await open(tester, 'tarot');
    expect(enabled(tester, 'draw'), isFalse);
    expect(find.text('先寫下你想問的問題，才能抽牌'), findsOneWidget);
    await press(tester, LogicalKeyboardKey.enter, control: true);
    await frames(tester);
    expect(find.byKey(const Key('tarot-ritual')), findsNothing);

    // An example question asks it with one touch.
    await scrollTo(tester, const Key('example-0'));
    await tester.tap(find.byKey(const Key('example-0')));
    await frames(tester);
    expect(enabled(tester, 'draw'), isTrue);
    final asked = tester.widget<TextField>(find.byKey(const Key('tarot-question'))).controller!.text;
    expect(asked.trim(), isNotEmpty);
    await scrollTo(tester, const Key('draw'));
    await tester.tap(find.byKey(const Key('draw')));
    await frames(tester, 8);
    expect(find.byKey(const Key('tarot-ritual')), findsOneWidget);
    // While the deck is shuffled, cut and picked, the question can't change.
    expect(tester.widget<TextField>(find.byKey(const Key('tarot-question'))).enabled, isFalse);
    await scrollTo(tester, const Key('ritual-skip'));
    await tester.tap(find.byKey(const Key('ritual-skip')));
    await frames(tester, 8);
    expect(draws(api).single, containsPair('question', asked));
    expect(tester.widget<TextField>(find.byKey(const Key('tarot-question'))).enabled, isTrue);
  });
}
