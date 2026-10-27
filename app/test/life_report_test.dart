import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mingli_app/application/providers.dart';
import 'package:mingli_app/data/profile_store.dart';
import 'package:mingli_app/domain/life_report.dart';
import 'package:mingli_app/l10n/gen/app_localizations_zh.dart';
import 'package:mingli_app/presentation/life_export.dart';

import 'support.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  final view = LifeReportView.fromJson(fixture('life_passed'));
  final l10n = AppLocalizationsZh();
  const header = LifeHeader(
    name: '吴勇',
    gender: '男',
    lunar: '1987 年 丁卯年 十月初三 寅时（约 03:30）',
    solar: '1987 年 11 月 23 日',
    place: '中国 · 江苏 · 靖江市',
    trueSolar: '约 03:44，属寅时（3:00–5:00）',
    ganzhi: '丁卯年　辛亥月　丙子日　庚寅时',
  );

  test('起卦 steps read exactly like the owner\'s sample report', () {
    final steps = qiguaSteps(view.facts!, hant: false, lunarMonth: '十月', lunarDay: '初三');
    expect(steps, [
      '年支卯 = 4，十月 = 10，初三 = 3；4 + 10 + 3 = 17，17 ÷ 8 余 1 → 上卦乾（天）',
      '寅时 = 3；17 + 3 = 20，20 ÷ 8 余 4 → 下卦震（雷）',
      '20 ÷ 6 余 2 → 第二爻为命爻',
      '得本命卦天雷无妄，二爻变，之卦天泽履。',
    ]);
  });

  test('the download package holds a styled HTML report and a Markdown copy', () {
    final html = lifeReportHtml(l10n: l10n, header: header, report: view, hant: false, lunarMonth: '十月', lunarDay: '初三');
    final md = lifeReportMarkdown(l10n: l10n, header: header, report: view, hant: false, lunarMonth: '十月', lunarDay: '初三');
    final zip = ZipDecoder().decodeBytes(lifeReportZip(html: html, markdown: md));
    expect(zip.files.map((f) => f.name).toList(), ['life-report.html', 'life-report.md', 'README.txt']);
    final h = utf8.decode(zip.files.first.content as List<int>);
    expect(h, startsWith('<!doctype html>'));
    for (final s in ['吴勇 一生运势报告', '一、易经本命卦', '天雷无妄', '六二：不耕获，不菑畬', '二、梅花易数', '八卦命卦（八宅）', '五、人生阶段总览', '六、总评与建议']) {
      expect(h, contains(s));
    }
    // The 命爻 is drawn in the accent colour; print layout is A4.
    expect(h, contains('line yin moving'));
    expect(h, contains('@page{size:A4'));
    // The AI label travels with every export.
    expect(md, contains(view.layers!.aiLabel));
  });

  testWidgets('八字排盘 → switch to 一生运势报告 → the report with all six sections', (tester) async {
    tester.view.physicalSize = const Size(1000, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = FakeApi(email: 'test@mingli.local');
    await tester.pumpWidget(testApp(api, profiles: InMemoryProfileStore(), locale: zhHans));
    await settle(tester);

    // The life report lives inside 八字排盘 now: no separate home card.
    expect(find.byKey(const Key('entry-life')), findsNothing);
    await tester.tap(find.byKey(const Key('entry-bazi')));
    await settle(tester);
    expect(find.text('排盘'), findsOneWidget); // chart mode first
    await tester.tap(find.text('一生运势报告'));
    await settle(tester);
    expect(find.text('生成一生运势报告'), findsOneWidget);
    await tester.scrollUntilVisible(find.byKey(const Key('compute-chart')), 300, scrollable: mainScrollable);
    await tester.tap(find.byKey(const Key('compute-chart')));
    await settle(tester);
    await settle(tester);

    final body = jsonDecode(api.requests.lastWhere((r) => r.url.path == '/v1/life-reports').body) as Map;
    expect(body['locale'], 'zh-Hans');
    expect((body['context'] as Map)['name'], '测试用户');

    expect(find.text('测试用户 一生运势报告'), findsWidgets);
    expect(find.byKey(const Key('hex-100111')), findsOneWidget); // 天雷无妄
    for (final k in ['life-download', 'life-print', 'life-copy']) {
      expect(find.byKey(Key(k)), findsOneWidget);
    }
    for (final k in ['life-sec-meihua', 'life-bazhai', 'life-sec-topics', 'life-stage-chart', 'life-sec-summary']) {
      await tester.scrollUntilVisible(find.byKey(Key(k)), 400, scrollable: mainScrollable);
      expect(find.byKey(Key(k)), findsOneWidget);
    }
    expect(find.byKey(const Key('life-ai-label')), findsOneWidget);
  });
}
