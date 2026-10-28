// v1.3.0 on the 命盘 page: 虚岁 on both strips, 神煞 · 空亡 · 胎元, the natal 刑冲合害, and the
// 子时 setting going with the chart request. The fixture chart is 庚午 己卯 己卯 辛未, born 1990.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mingli_app/data/profile_store.dart';
import 'package:mingli_app/domain/profile.dart';

import 'support.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<FakeApi> openChart(WidgetTester tester, {ProfileStore? profiles}) async {
  final api = FakeApi();
  await tester.pumpWidget(testApp(api, profiles: profiles));
  await settle(tester);
  await tester.tap(find.byKey(const Key('entry-bazi')));
  await settle(tester);
  await scrollTo(tester, const Key('compute-chart'));
  await tester.tap(find.byKey(const Key('compute-chart')));
  await settle(tester);
  return api;
}

Map<String, dynamic> chartRequest(FakeApi api) =>
    jsonDecode(api.requests.singleWhere((r) => r.url.path == '/v1/charts').body) as Map<String, dynamic>;

void main() {
  testWidgets('虚岁 on both strips, 神煞 · 空亡 · 胎元 and the natal 刑冲合害', (tester) async {
    await openChart(tester);
    final facts = fixture('chart_bazi')['chart_fact']['facts'] as Map<String, dynamic>;
    final firstCycle = ((facts['dayun'] as Map)['cycles'] as List).first as Map;

    // Cards in page order, scrolling down (the list builds lazily, rule 25).
    // 五行 card: 己土 has 26.8 of 100 support points (月干 己 12, 午 4, 未 10.8): 身弱; the 卯 month's
    // 本气 is 木: 不得令. 喜用 = 印 火, 比劫 土; 忌 = 食伤 金, 财 水, 官杀 木.
    await scrollTo(tester, const Key('strength'));
    for (final pill in ['身弱', '不得令', '喜用：火、土', '忌：金、水、木']) {
      expect(find.descendant(of: find.byKey(const Key('strength')), matching: find.text(pill)), findsOneWidget, reason: pill);
    }
    // 己 日: 禄 午 = 年支; 年支 午: 桃花 卯 = 月, 日; 日支 卯: 华盖 未 = 时. 己卯 in 甲戌旬: 申酉 空.
    // 胎元: 己 + 1 = 庚, 卯 + 3 = 午.
    await scrollTo(tester, const Key('shensha-card'));
    for (final pill in ['祿神 · 年柱', '桃花 · 月柱、日柱', '華蓋 · 時柱', '空亡 申酉', '胎元 庚午']) {
      expect(find.text(pill), findsOneWidget, reason: pill);
    }

    // 午卯 破 ×2, 午未 合 土, 卯未 半合 木 ×2 (亥卯未 with its middle 卯).
    await scrollTo(tester, const Key('relations-card'));
    final card = find.byKey(const Key('relations-card'));
    Finder inCard(String text) => find.descendant(of: card, matching: find.text(text));
    expect(inCard('相破'), findsNWidgets(2));
    expect(inCard('半合'), findsNWidgets(2));
    for (final v in ['年柱午 · 月柱卯', '年柱午 · 日柱卯', '年柱午 · 時柱未（土）', '月柱卯 · 時柱未（木）', '日柱卯 · 時柱未（木）']) {
      expect(inCard(v), findsOneWidget, reason: v);
    }

    // The first 大运 shows its 虚岁 from the civil birth year; 2026 is 虛歲 2026 − 1990 + 1 = 37.
    await scrollTo(tester, const Key('dayun-strip'));
    expect(find.text('虛歲 ${firstCycle['start_year'] - 1990 + 1}'), findsOneWidget);
    await scrollTo(tester, const Key('liunian-strip'));
    expect(find.text('2026 · 虛歲 37'), findsOneWidget);
  });

  testWidgets('子时: the default sends ziHourSect 2; a profile set to 算次日 sends 1', (tester) async {
    expect((chartRequest(await openChart(tester))['options'] as Map)['ziHourSect'], 2);

    final store = InMemoryProfileStore();
    store.data['u1'] = ProfileBook(
      profiles: [
        BirthProfile(id: 'p1', name: '晚子', gender: 'male', birthLocal: DateTime(1990, 3, 15, 23, 30), cityKey: 'hk', ziNextDay: true),
      ],
      defaultId: 'p1',
    ).encode();
    await tester.pumpWidget(const SizedBox.shrink()); // a fresh app (rule 24)
    expect((chartRequest(await openChart(tester, profiles: store))['options'] as Map)['ziHourSect'], 1);
    // The setting survives a save and a reload of the profile book.
    expect(ProfileBook.decode(store.data['u1']).defaultProfile!.ziNextDay, isTrue);
  });
}
