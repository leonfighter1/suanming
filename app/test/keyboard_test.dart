import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mingli_app/application/providers.dart';
import 'package:mingli_app/domain/models.dart';

import 'keys.dart';
import 'support.dart';

/// A tall phone-width view, signed in as a tester with a default profile.
Future<void> start(WidgetTester tester, {Locale? locale = zhHans, double width = 400}) async {
  tester.view.physicalSize = Size(width, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(testApp(FakeApi(email: 'test@mingli.local', pendingPolls: 0), locale: locale));
  await frames(tester);
}

Future<void> tapAndWait(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await frames(tester);
}

final home = find.byKey(const Key('entry-bazi'));
final confirm = find.byKey(const Key('leave-confirm'));

void main() {
  group('区2 · 登录 · 首页', () {
    testWidgets('sign-in: Enter in 邮箱 goes to 密码, Enter in 密码 signs in', (tester) async {
      await tester.pumpWidget(testApp(FakeApi(), signedIn: false, locale: zhHans));
      await frames(tester);
      await openSignIn(tester);
      await tester.enterText(find.byKey(const Key('login')), 'me@example.com');
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await frames(tester);
      expect(focusedKey(), 'password');
      await tester.enterText(find.byKey(const Key('password')), 'long enough pw');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await frames(tester);
      expect(home, findsOneWidget);
    });

    testWidgets('sign-in: Ctrl+Enter signs in from any field', (tester) async {
      await tester.pumpWidget(testApp(FakeApi(), signedIn: false, locale: zhHans));
      await frames(tester);
      await openSignIn(tester);
      await tester.enterText(find.byKey(const Key('password')), 'long enough pw');
      await tester.enterText(find.byKey(const Key('login')), 'me@example.com');
      await press(tester, LogicalKeyboardKey.enter, control: true);
      expect(home, findsOneWidget);
    });

    testWidgets('home: Tab goes along the bar, then the entries; the focused card shows the ring', (tester) async {
      await start(tester);
      final stops = <String?>[];
      for (var i = 0; i < 8; i++) {
        await press(tester, LogicalKeyboardKey.tab);
        stops.add(focusedKey());
      }
      expect(stops, [
        // The bar (v9.1.0): ☰ only, on the right; 历史记录 and the rest are in the menu.
        'open-menu',
        // 東方 (owner, v6.1.0), in the region's order: the default here.
        'entry-bazi',
        'entry-qiuqian', // 求籤 (v4.3.0)
        'entry-liuyao', // 算卦 (v6.0.0), after 求籤
        'entry-fengshui', // 风水 (v4.4.0)
        'east-daily', // 今日一卦 / 今日一籤 (S26), under 東方
        'entry-tarot', // 西方
        'daily-card', // 每日一牌 (v2.6.0)
      ]);
      expect(ringShown(tester, find.byKey(const Key('daily-card'))), isTrue); // the last one Tab reached
      expect(ringShown(tester, home), isFalse);
      // Shift+Tab goes back through 塔罗, the day's 籤, 风水 and 算卦 to 求籤; Enter opens it.
      for (final back in ['entry-tarot', 'east-daily', 'entry-fengshui', 'entry-liuyao', 'entry-qiuqian']) {
        await press(tester, LogicalKeyboardKey.tab, shift: true);
        expect(focusedKey(), back);
      }
      await press(tester, LogicalKeyboardKey.enter);
      expect(find.byKey(const Key('qiuqian-question')), findsOneWidget);
    });
  });

  group('区3 · 八字排盘', () {
    testWidgets('Esc: an untouched form just goes back; after an edit it asks first', (tester) async {
      await start(tester);
      await tapAndWait(tester, home);
      await press(tester, LogicalKeyboardKey.escape);
      expect(home, findsOneWidget);
      expect(confirm, findsNothing);

      await tapAndWait(tester, home);
      await tester.enterText(find.byKey(const ValueKey('form-name-0')), '小明');
      await press(tester, LogicalKeyboardKey.escape);
      expect(find.text('返回将重新开始'), findsOneWidget);
      expect(find.text('本次填写的内容不会保留，返回后需要重新填写。'), findsOneWidget);
      await press(tester, LogicalKeyboardKey.escape); // 继续测算
      expect(confirm, findsNothing);
      expect(find.byKey(const Key('compute-chart')), findsOneWidget);
      await press(tester, LogicalKeyboardKey.escape);
      await press(tester, LogicalKeyboardKey.enter); // 返回 has the focus
      expect(home, findsOneWidget);
    });

    testWidgets('Ctrl+Enter computes; ←/→ scroll 大运; the 命盘 page asks before leaving', (tester) async {
      await start(tester);
      await tapAndWait(tester, home);
      await press(tester, LogicalKeyboardKey.enter, control: true);
      expect(find.text('四柱'), findsOneWidget);

      await tabTo(tester, 'dayun-strip');
      expect(ringShown(tester, find.byKey(const Key('dayun-strip'))), isTrue);
      final strip = tester
          .state<ScrollableState>(find.descendant(of: find.byKey(const Key('dayun-strip')), matching: find.byType(Scrollable)))
          .position;
      // 8 cycles × (96 + 8) − 8 = 824 px of strip in a 400 − 32 − 40 = 328 px card: it scrolls.
      expect(strip.maxScrollExtent, greaterThan(104));
      await press(tester, LogicalKeyboardKey.arrowRight);
      expect(strip.pixels, 104); // one 96-wide item + the 8 px gap
      await press(tester, LogicalKeyboardKey.end);
      expect(strip.pixels, strip.maxScrollExtent);
      await press(tester, LogicalKeyboardKey.home);
      expect(strip.pixels, 0);

      await press(tester, LogicalKeyboardKey.escape);
      expect(find.text('返回后要重新排盘才能再看到这个命盘。已生成的解读会保存在历史记录里。'), findsOneWidget);
      await press(tester, LogicalKeyboardKey.enter);
      expect(find.byKey(const Key('compute-chart')), findsOneWidget);
    });

    testWidgets('←/→ switch an option row; a date opened from the keyboard is typed in', (tester) async {
      await start(tester);
      await tapAndWait(tester, home);
      final compute = find.byKey(const Key('compute-chart'));

      await tabTo(tester, 'form-mode'); // its first segment, 排盘解读
      await press(tester, LogicalKeyboardKey.arrowRight);
      expect(find.descendant(of: compute, matching: find.text('生成一生运势报告')), findsOneWidget);
      await press(tester, LogicalKeyboardKey.arrowLeft);
      expect(find.descendant(of: compute, matching: find.text('排盘')), findsOneWidget);

      await tabTo(tester, 'gregorian');
      await press(tester, LogicalKeyboardKey.enter);
      expect(find.byType(InputDatePickerFormField), findsOneWidget);
      await press(tester, LogicalKeyboardKey.escape);
      expect(find.byType(DatePickerDialog), findsNothing);
      expect(compute, findsOneWidget);

      await tapAndWait(tester, find.byKey(const ValueKey('gregorian'))); // by mouse/touch: the calendar
      expect(find.byType(CalendarDatePicker), findsOneWidget);
      await press(tester, LogicalKeyboardKey.escape);
      expect(find.byType(DatePickerDialog), findsNothing);
    });

    testWidgets('为谁排盘 from the keyboard; the pop-up asks before dropping edits; Ctrl+Enter saves', (tester) async {
      await start(tester);
      await tapAndWait(tester, home);
      await tabTo(tester, 'profile-picker-0'); // the list's arrow button
      await press(tester, LogicalKeyboardKey.enter);
      expect(find.text('添加新的测试者').hitTestable(), findsOneWidget);
      // Entries: the saved person, 添加新的测试者, 编辑…
      await press(tester, LogicalKeyboardKey.arrowDown);
      await press(tester, LogicalKeyboardKey.arrowDown);
      await press(tester, LogicalKeyboardKey.enter);
      final dialog = find.byKey(const Key('profile-dialog'));
      expect(dialog, findsOneWidget);

      await tester.enterText(find.byKey(const Key('dialog-profile-name')), '小红');
      await press(tester, LogicalKeyboardKey.escape);
      expect(find.text('放弃未保存的修改？'), findsOneWidget);
      await press(tester, LogicalKeyboardKey.escape); // 继续编辑
      expect(dialog, findsOneWidget);
      await press(tester, LogicalKeyboardKey.enter, control: true); // 保存
      expect(dialog, findsNothing);
      expect(find.text('小红'), findsWidgets); // picked and loaded into the form
    });
  });

  group('区4 · 塔罗', () {
    testWidgets('Tab to each card, Enter or Space turns it; once drawn, leaving asks first', (tester) async {
      await start(tester, width: 1000);
      final entry = find.byKey(const Key('entry-tarot'));
      await tapAndWait(tester, entry);
      await press(tester, LogicalKeyboardKey.escape); // nothing drawn yet: no question
      expect(entry, findsOneWidget);

      await tapAndWait(tester, entry);
      // 抽牌 waits for the question (v11.1.0): typed in its field first, then Tab on to the button.
      await ask(tester, 'tarot-question', '我们的关系会怎样？');
      await tabTo(tester, 'draw');
      await press(tester, LogicalKeyboardKey.enter);
      // The ritual opens (v3.0.0); the deck picks here (the ritual's keys: tarot_ritual_test.dart).
      await tabTo(tester, 'ritual-skip');
      await press(tester, LogicalKeyboardKey.enter);
      await frames(tester);
      final semantics = tester.ensureSemantics();
      String spoken(int n) => tester.getSemantics(find.byKey(Key('tarot-card-$n'))).label;
      expect(spoken(1), contains('过去，未翻开')); // face down: only the position
      final keys = [LogicalKeyboardKey.enter, LogicalKeyboardKey.space, LogicalKeyboardKey.enter];
      for (final (i, key) in keys.indexed) {
        await tabTo(tester, 'tarot-card-${i + 1}');
        expect(ringShown(tester, find.byKey(Key('tarot-card-${i + 1}'))), isTrue);
        await press(tester, key);
      }
      expect(spoken(1), isNot(contains('未翻开'))); // turned: position and card
      semantics.dispose();
      expect(find.byKey(const Key('generate-report')), findsOneWidget);

      await press(tester, LogicalKeyboardKey.escape);
      expect(find.text('这次抽到的牌不会保留，下次要重新抽牌。已生成的解读会保存在历史记录里。'), findsOneWidget);
      await press(tester, LogicalKeyboardKey.enter);
      expect(entry, findsOneWidget);
    });

    testWidgets('Tab reaches the focus chips after the question, in order; Space picks one', (tester) async {
      await start(tester, width: 1000);
      await tapAndWait(tester, find.byKey(const Key('entry-tarot')));
      await tabTo(tester, 'focus-any');
      final order = <String?>[];
      for (var i = 0; i < 4; i++) {
        await press(tester, LogicalKeyboardKey.tab);
        order.add(focusedKey());
      }
      expect(order, ['focus-career_wealth', 'focus-relationships', 'focus-health', 'focus-personality']);
      await press(tester, LogicalKeyboardKey.space);
      expect(tester.widget<ChoiceChip>(find.byKey(const Key('focus-personality'))).selected, isTrue);
      expect(tester.widget<ChoiceChip>(find.byKey(const Key('focus-any'))).selected, isFalse);
      await press(tester, LogicalKeyboardKey.tab);
      expect(focusedKey(), 'spread-single'); // then the spread chips (v2.8.0) and the draw
    });
  });

  group('区5 · 解读报告', () {
    final report = ReportView.fromJson(fixture('report_passed'));

    testWidgets('trend chart: Home/End/→ pick periods; Enter opens a topic; Esc goes back without asking', (tester) async {
      await start(tester, width: 1000);
      await tapAndWait(tester, find.byKey(const Key('open-menu')));
      await tapAndWait(tester, find.byKey(const Key('menu-history')));
      await tapAndWait(tester, find.text('八字排盘').last);

      await tabTo(tester, 'trend-plot');
      expect(ringShown(tester, find.byKey(const Key('trend-plot'))), isTrue);
      Finder inDetail(String text) =>
          find.descendant(of: find.byKey(const Key('trend-detail')), matching: find.textContaining(text));
      final dayun = report.layers!.trend!.dayun;
      await press(tester, LogicalKeyboardKey.end);
      expect(inDetail('${dayun.last.ganzhi} ·'), findsOneWidget);
      await press(tester, LogicalKeyboardKey.home);
      expect(inDetail('${dayun.first.ganzhi} ·'), findsOneWidget);
      await press(tester, LogicalKeyboardKey.arrowRight);
      expect(inDetail('${dayun[1].ganzhi} ·'), findsOneWidget);

      final second = report.layers!.interpretation[1].paragraphs.first.text;
      expect(find.text(second), findsNothing);
      await tabTo(tester, 'topic-1-0');
      await press(tester, LogicalKeyboardKey.enter);
      expect(find.text(second), findsOneWidget);

      await press(tester, LogicalKeyboardKey.escape); // saved in 历史记录: no question
      expect(confirm, findsNothing);
      expect(find.byKey(const Key('trend-plot')), findsNothing);
      expect(find.widgetWithText(AppBar, '历史记录'), findsOneWidget);
    });
  });

  group('区6 · 个人资料 · 出生地 · 设置', () {
    testWidgets('出生地 from the keyboard: type, Enter takes the first match; Esc clears, then steps back', (tester) async {
      await start(tester, locale: zhHant);
      await tapAndWait(tester, home);
      await tabTo(tester, 'city');
      await press(tester, LogicalKeyboardKey.enter);
      final search = find.byKey(const Key('place-search'));
      expect(focusedKey(), 'place-search');

      await tester.enterText(search, 'hong');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await frames(tester);
      final atHongKong = find.textContaining('香港 ·');
      expect(atHongKong, findsOneWidget); // 香港 · 省／州
      expect(focusedKey(), 'place-search');

      await tester.enterText(search, '沙田');
      await press(tester, LogicalKeyboardKey.escape);
      expect(tester.widget<TextField>(search).controller!.text, isEmpty);
      expect(atHongKong, findsOneWidget);
      await press(tester, LogicalKeyboardKey.escape);
      expect(find.text('國家和地區'), findsOneWidget);
      await press(tester, LogicalKeyboardKey.escape);
      expect(search, findsNothing);
      expect(find.byKey(const Key('compute-chart')), findsOneWidget);
    });

    testWidgets('profile editor: untouched Esc goes back; after an edit it asks; Ctrl+Enter saves', (tester) async {
      await start(tester);
      await tapAndWait(tester, find.byKey(const Key('open-menu')));
      await tapAndWait(tester, find.byKey(const Key('open-profiles')));
      final person = find.byType(CircleAvatar).first;
      await tapAndWait(tester, person);
      await press(tester, LogicalKeyboardKey.escape);
      expect(find.byKey(const Key('add-profile')), findsOneWidget);

      await tapAndWait(tester, person);
      await tester.enterText(find.byKey(const Key('profile-name')), '新名字');
      await press(tester, LogicalKeyboardKey.escape);
      expect(find.text('放弃未保存的修改？'), findsOneWidget);
      await press(tester, LogicalKeyboardKey.escape); // 继续编辑
      await press(tester, LogicalKeyboardKey.enter, control: true); // 保存
      expect(find.byKey(const Key('add-profile')), findsOneWidget);
      expect(find.text('新名字'), findsOneWidget);
    });

    testWidgets('the ☰ menu lists the keyboard shortcuts too', (tester) async {
      await start(tester);
      await tapAndWait(tester, find.byKey(const Key('open-menu')));
      await tapAndWait(tester, find.byKey(const Key('open-shortcuts')));
      expect(find.byKey(const Key('shortcut-list')), findsOneWidget);
      expect(find.text('键盘快捷键'), findsWidgets);
      // The menu closed before the list opened: Esc closes the list and leaves 首页 as it was.
      expect(find.byKey(const Key('app-menu')), findsNothing);
      await press(tester, LogicalKeyboardKey.escape);
      expect(find.byKey(const Key('shortcut-list')), findsNothing);
      expect(home, findsOneWidget);
      await press(tester, LogicalKeyboardKey.escape);
      expect(home, findsOneWidget);
    });
  });

  test('every tap target works from the keyboard: no bare GestureDetector in the screens', () {
    final offenders = [
      for (final f in Directory('lib/presentation').listSync(recursive: true).whereType<File>())
        if (f.path.endsWith('.dart') &&
            !f.path.endsWith('keyboard.dart') &&
            RegExp(r'\b(Raw)?GestureDetector\(').hasMatch(f.readAsStringSync()))
          f.path,
    ];
    expect(offenders, isEmpty, reason: 'use Pressable (lib/presentation/keyboard.dart) so Tab, Enter and Space reach it');
  });
}
