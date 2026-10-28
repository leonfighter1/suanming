import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mingli_app/application/providers.dart';
import 'package:mingli_app/presentation/review_page.dart';

import 'support.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  test('the content view lists AI text only, labelled, without engine data', () {
    final texts = reviewTexts(fixture('review_report')['content']);
    expect(texts, isNotEmpty);
    // No chart-facts restatement or ids, only what the model wrote.
    expect(texts.any((t) => t.$2.startsWith('四柱')), isFalse);
    expect(texts.any((t) => t.$1.contains('career_wealth')), isTrue);
  });

  testWidgets('only reviewers see 内容审核', (tester) async {
    await tester.pumpWidget(testApp(FakeApi(email: 'test@mingli.local'), locale: zhHans));
    await settle(tester);
    await tester.tap(find.byKey(const Key('open-settings')));
    await settle(tester);
    expect(find.text('邮箱'), findsOneWidget);
    expect(find.byKey(const Key('open-review')), findsNothing);
  });

  testWidgets('a reviewer opens a held report, sees why, and releases it', (tester) async {
    tester.view.physicalSize = const Size(1000, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = FakeApi(email: 'admin');
    await tester.pumpWidget(testApp(api, locale: zhHans));
    await settle(tester);

    await tester.tap(find.byKey(const Key('open-settings')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('open-review')));
    await settle(tester);
    expect(find.text('内容审核'), findsOneWidget);

    final id = fixture('review_report')['id'];
    await tester.tap(find.byKey(Key('review-$id')));
    await settle(tester);
    // Why: the reason and the AI reviewer's finding with the quoted sentence.
    expect(find.textContaining('guard: 1 issue(s) flagged'), findsOneWidget);
    expect(find.byKey(const Key('guard-finding')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('review-note')), '表述可接受');
    await scrollTo(tester, const Key('review-approve'));
    await tester.tap(find.byKey(const Key('review-approve')));
    await settle(tester);

    final post = api.requests.lastWhere((r) => r.method == 'POST' && r.url.path.startsWith('/v1/admin/reviews/'));
    expect(jsonDecode(post.body), {'decision': 'approve', 'note': '表述可接受'});
    expect(find.text('已通过并发布给用户'), findsOneWidget);
    expect(find.text('目前没有待审核的内容。'), findsOneWidget);
  });
}
