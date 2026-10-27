import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mingli_app/data/profile_store.dart';
import 'package:mingli_app/domain/life_context.dart';
import 'package:mingli_app/domain/models.dart';
import 'package:mingli_app/domain/places.dart';
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
  await settle(tester);
}

/// Opens the passed fixture report from the history page.
Future<FakeApi> openReport(WidgetTester tester, {bool preload = false}) async {
  tester.view.physicalSize = const Size(1000, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final api = FakeApi(pendingPolls: 0)..preloadRemedies = preload;
  await tester.pumpWidget(testApp(api));
  await settle(tester);
  await tester.tap(find.byKey(const Key('open-history')));
  await settle(tester);
  await tester.tap(find.text('八字排盤').last);
  await settle(tester);
  return api;
}

void main() {
  group('LifeContext', () {
    test('only filled fields are sent; the name only when allowed', () {
      const c = LifeContext(marital: 'married', occupation: '  ', concern: '明年適合轉工嗎？');
      expect(c.toApi(name: '小明', locale: 'zh-Hant'), {'name': '小明', 'marital': 'married', 'concern': '明年適合轉工嗎？'});
      expect(c.copyWith(useName: false).toApi(name: '小明', locale: 'zh-Hant'), {'marital': 'married', 'concern': '明年適合轉工嗎？'});
      expect(const LifeContext(useName: false).toApi(name: '小明', locale: 'zh-Hant'), isNull);
    });

    test('residence is sent as its label; copyWith can clear a field', () {
      const place = BirthPlace(
        country: 'CN',
        countryNames: PlaceNames('中國', '中国', 'China'),
        region: '30',
        regionNames: PlaceNames('廣東', '广东', 'Guangdong'),
        city: PlaceNames('深圳', '深圳', 'Shenzhen'),
        timezone: 'Asia/Shanghai',
        longitude: 114.07,
      );
      final c = const LifeContext(useName: false).copyWith(residence: place, marital: 'single');
      expect(c.toApi(name: '', locale: 'zh-Hans'), {'residence': '中国 · 广东 · 深圳', 'marital': 'single'});
      expect(c.copyWith(marital: null).marital, isNull);
      expect(LifeContext.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>).residence!.city.en, 'Shenzhen');
    });
  });

  testWidgets('the situation entered on the 八字 form goes with the reading request', (tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = FakeApi(email: 'test@mingli.local', pendingPolls: 0);
    await tester.pumpWidget(testApp(api, profiles: InMemoryProfileStore()));
    await settle(tester);
    await tester.tap(find.byKey(const Key('entry-bazi')));
    await settle(tester);

    await scrollAndTap(tester, find.byKey(const Key('life-context')));
    await scrollAndTap(tester, find.byKey(const Key('life-marital')));
    await tester.tap(find.text('已婚').last);
    await settle(tester);
    await tester.scrollUntilVisible(find.byKey(const Key('life-concern')), 300, scrollable: mainScrollable);
    await tester.enterText(find.byKey(const Key('life-occupation')), '軟件工程師');
    await tester.enterText(find.byKey(const Key('life-concern')), '明年適合轉工嗎？');
    await settle(tester);

    await scrollAndTap(tester, find.byKey(const Key('compute-chart')));
    // The chart request never carries the name or the situation.
    final chartBody = jsonDecode(api.requests.lastWhere((r) => r.url.path == '/v1/charts').body) as Map;
    expect(chartBody.containsKey('context'), isFalse);
    expect(chartBody.containsKey('name'), isFalse);

    await scrollAndTap(tester, find.byKey(const Key('generate-report')));
    final body = jsonDecode(api.requests.lastWhere((r) => r.method == 'POST' && r.url.path == '/v1/reports').body) as Map;
    expect(body['context'], {
      'name': '测试用户',
      // Bug fix: the birthplace name reaches the reading (the chart only gets timezone + longitude).
      'birthplace': '香港',
      'marital': 'married',
      'occupation': '軟件工程師',
      'concern': '明年適合轉工嗎？',
    });
    // ...and the report shows it at the top of the facts card.
    await settle(tester);
    await tester.scrollUntilVisible(find.text('出生地：香港'), 300, scrollable: mainScrollable);
    expect(find.text('出生地：香港'), findsOneWidget);
  });

  testWidgets('the birthplace is remembered per chart, so history can show it', (tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = InMemoryProfileStore();
    final api = FakeApi(email: 'test@mingli.local', pendingPolls: 0);
    await tester.pumpWidget(testApp(api, profiles: store));
    await settle(tester);
    await tester.tap(find.byKey(const Key('entry-bazi')));
    await settle(tester);
    await scrollAndTap(tester, find.byKey(const Key('compute-chart')));
    final book = ProfileBook.decode(store.data['u1']);
    final chartId = fixture('chart_bazi')['chart_id'] as String;
    expect(book.chartLabels[chartId], '测试用户');
    expect(book.chartPlaces[chartId], '香港');
  });

  testWidgets('each topic shows its plain 一句話重點, even collapsed', (tester) async {
    await openReport(tester);
    final r = ReportView.fromJson(fixture('report_passed'));
    final second = r.layers!.interpretation[1];
    // The second topic is collapsed, but its summary is visible.
    expect(find.text(second.paragraphs.first.text), findsNothing);
    expect(find.byKey(Key('summary-${second.topic}')), findsOneWidget);
  });

  testWidgets('preloaded 破除運勢 plans show 已備好 and open at once after paying', (tester) async {
    final api = await openReport(tester, preload: true);
    final ready = find.byKey(const Key('remedy-ready-health'));
    await tester.scrollUntilVisible(ready, 300, scrollable: mainScrollable);
    expect(ready, findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('remedy-buy-health')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('remedy-buy-health')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('remedy-pay')));
    await settle(tester);
    expect(api.requests.where((r) => r.method == 'POST' && r.url.path.endsWith('/remedies')), hasLength(1));
    // Content is there straight away: no generating spinner.
    expect(find.byKey(const Key('remedy-generating')), findsNothing);
    expect(find.byKey(const Key('remedy-target')), findsOneWidget);
  });
}
