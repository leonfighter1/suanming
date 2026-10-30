// What a tap brings up comes into view by itself (owner, v9.1.0: 「这类新生成的component 要避免用户下滑后再点击。最好点
// 击的时候自动集中到当前的UI component」): BringIntoView on its own, then each page where a tap makes something below
// the button, on a phone. Before v9.1.0 each of these parts opened below the fold.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mingli_app/presentation/design.dart';
import 'package:mingli_app/presentation/widgets/qiuqian_stage.dart' show QiuqianStage;
import 'package:mingli_app/presentation/widgets/report_request.dart' show ReportRequest;
import 'package:mingli_app/presentation/widgets/tarot_spread.dart' show TarotSpread;

import 'keys.dart';
import 'support.dart';

/// [height] of other content, a 50 px button, then (once pressed) a part [part] tall, [rows] times over, and 400 px
/// below it, in a list on the test screen (800 × 600).
class _Page extends StatefulWidget {
  const _Page({required this.above, required this.part, this.still = false});
  final double above;
  final double part;

  /// The system's animations off.
  final bool still;

  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> {
  var shown = false;
  var rows = 1;

  /// The part grows by a row, as a card does at each step.
  void grow() => setState(() => rows++);

  @override
  Widget build(BuildContext context) => MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: widget.still),
          child: child!,
        ),
        home: Scaffold(
          body: ListView(
            padding: EdgeInsets.zero,
            children: [
              SizedBox(height: widget.above),
              SizedBox(
                height: 50,
                child: TextButton(key: const Key('make'), onPressed: () => setState(() => shown = true), child: const Text('make')),
              ),
              if (shown)
                BringIntoView(trigger: rows, child: SizedBox(key: const Key('part'), height: widget.part * rows)),
              const SizedBox(height: 400),
            ],
          ),
        ),
      );
}

double _offset(WidgetTester tester) => tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels;

/// A 360 × 740 phone.
void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 740);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// [part] is on screen whole, or, when taller than the page's view, from its top.
void _expectInView(WidgetTester tester, Finder part) {
  final view = tester.getRect(mainScrollable);
  final box = tester.getRect(part);
  final where = '$part at $box, the view $view';
  if (box.height + 2 * Space.l <= view.height) {
    expect(box.top >= view.top && box.bottom <= view.bottom, isTrue, reason: where);
  } else {
    expect(box.top, inInclusiveRange(view.top, view.top + Space.l + 1), reason: where);
  }
}

void main() {
  group('BringIntoView', () {
    testWidgets('a new part below the fold: just far enough for all of it, 16 px clear of the bottom', (tester) async {
      await tester.pumpWidget(const _Page(above: 500, part: 200));
      await tester.tap(find.byKey(const Key('make')));
      await frames(tester, 6);
      // The part spans 550–750 in the list, the view 600: its bottom 16 px above the view's, 750 + 16 − 600 = 166.
      expect(_offset(tester), 166);
      expect(tester.getRect(find.byKey(const Key('part'))).bottom, 600 - Space.l);
    });

    testWidgets('a part taller than the view comes to the top, 16 px below it', (tester) async {
      await tester.pumpWidget(const _Page(above: 500, part: 700));
      await tester.tap(find.byKey(const Key('make')));
      await frames(tester, 6);
      // Its top at 550 in the list, 16 px below the view's top: 550 − 16 = 534.
      expect(_offset(tester), 534);
      expect(tester.getRect(find.byKey(const Key('part'))).top, Space.l);
    });

    testWidgets('a part in view already: nothing moves', (tester) async {
      await tester.pumpWidget(const _Page(above: 0, part: 200));
      await tester.tap(find.byKey(const Key('make')));
      await frames(tester, 6);
      expect(find.byKey(const Key('part')), findsOneWidget);
      expect(_offset(tester), 0);
    });

    testWidgets('a part that grows: a new trigger brings it into view again, once it has grown', (tester) async {
      await tester.pumpWidget(const _Page(above: 500, part: 200));
      await tester.tap(find.byKey(const Key('make')));
      await frames(tester, 6);
      expect(_offset(tester), 166);
      tester.state<_PageState>(find.byType(_Page)).grow();
      await tester.pump();
      expect(_offset(tester), 166); // it waits for AppCard's growth (BringIntoView.settle)
      await frames(tester, 9);
      // Now 400 tall, 550–950: 950 + 16 − 600 = 366.
      expect(_offset(tester), 366);
    });

    testWidgets('with the system animations off it jumps', (tester) async {
      await tester.pumpWidget(const _Page(above: 500, part: 200, still: true));
      await tester.tap(find.byKey(const Key('make')));
      await tester.pump(); // the part is built, and brought into view at the frame's end
      await tester.pump();
      expect(_offset(tester), 166);
    });
  });

  group('on a phone', () {
    testWidgets('塔羅: 抽牌 brings up 洗牌 · 切牌 · 選牌, then the spread, then the reading once the last card turns', (tester) async {
      _phone(tester);
      await tester.pumpWidget(testApp(FakeApi()));
      await frames(tester, 10);
      await openEntry(tester, 'tarot');
      await frames(tester, 10);
      await ask(tester, 'tarot-question'); // drawn only for a question (v11.1.0)
      await scrollTo(tester, const Key('draw'));
      await tester.tap(find.byKey(const Key('draw')));
      await frames(tester, 8);
      final ritual = find.byKey(const Key('tarot-ritual'));
      _expectInView(tester, ritual);
      // 洗牌, then 切牌: the 78 cards to pick from, taller than a phone's screen, come up from their top.
      await tester.tap(find.byKey(const Key('ritual-shuffle')));
      await frames(tester, 10);
      await tester.tap(find.byKey(const Key('ritual-cut-1')));
      await frames(tester, 9);
      expect(find.byKey(const Key('ritual-pick-hint')), findsOneWidget);
      _expectInView(tester, ritual);

      await scrollTo(tester, const Key('ritual-skip'));
      await tester.tap(find.byKey(const Key('ritual-skip')));
      await frames(tester, 10);
      _expectInView(tester, find.byType(TarotSpread));

      // On a phone a touch on a card still face down opens the next one large; touching it there turns it.
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byKey(const Key('tarot-card-3')));
        await frames(tester, 4);
        await tester.tap(find.byKey(const Key('tarot-card-view-card')));
        await frames(tester, 7);
        await tester.tap(find.byKey(const Key('tarot-card-view-close')));
        await frames(tester, 4);
      }
      await frames(tester, 8);
      _expectInView(tester, find.byType(ReportRequest));
    });

    testWidgets('風水: 看佈局 brings up the room’s principles', (tester) async {
      _phone(tester);
      await tester.pumpWidget(testApp(FakeApi()));
      await frames(tester, 10);
      await openEntry(tester, 'fengshui');
      await frames(tester, 10);
      await scrollTo(tester, const Key('look-room'));
      await tester.tap(find.byKey(const Key('look-room')));
      await frames(tester, 10);
      _expectInView(tester, find.byKey(const Key('principles-card')));
    });

    testWidgets('求籤: the altar comes up as the lot is drawn, and the lot once the 聖筊 lands', (tester) async {
      _phone(tester);
      await tester.pumpWidget(testApp(FakeApi()));
      await frames(tester, 10);
      await openEntry(tester, 'qiuqian');
      await frames(tester, 10);
      await ask(tester, 'qiuqian-question', '今年適合換工作嗎？');
      await scrollTo(tester, const Key('draw-lot'));
      await tester.tap(find.byKey(const Key('draw-lot')));
      await frames(tester, 6);
      final rounds = find.byKey(ValueKey<String>('rounds-${fixture('chart_qiuqian')['chart_id']}'));
      _expectInView(tester, find.byType(QiuqianStage));
      final steps = QiuqianStage.shake.inMilliseconds ~/ 100 + 2;
      final throws = QiuqianStage.toss.inMilliseconds ~/ 100 + 2;
      // The fixture's draw: a 陰筊, then the 聖筊. Each step's button stays in view as the card grows.
      await frames(tester, steps);
      _expectInView(tester, rounds);
      await tester.tap(find.byKey(const Key('throw-blocks')));
      await frames(tester, throws + 6);
      _expectInView(tester, rounds);
      await tester.tap(find.byKey(const Key('shake-again')));
      await frames(tester, steps + 6);
      await tester.tap(find.byKey(const Key('throw-blocks')));
      await frames(tester, throws + 8);
      _expectInView(tester, find.byKey(const Key('lot-card')));
    });

    testWidgets('算卦: the tosses come up, and the hexagram once the last coins land', (tester) async {
      _phone(tester);
      await tester.pumpWidget(testApp(FakeApi()));
      await frames(tester, 10);
      await openEntry(tester, 'liuyao');
      await frames(tester, 10);
      await ask(tester, 'liuyao-question', '這個項目能不能做成？');
      await scrollTo(tester, const Key('liuyao-toss'));
      await tester.tap(find.byKey(const Key('liuyao-toss')));
      await frames(tester, 8);
      final tosses = find.byKey(ValueKey<String>('tosses-${fixture('chart_liuyao')['chart_id']}'));
      _expectInView(tester, tosses);
      for (var i = 0; i < 6; i++) {
        await tester.tap(find.byKey(const Key('liuyao-next')));
        await frames(tester, 8);
        _expectInView(tester, tosses);
      }
      await frames(tester, 12);
      _expectInView(tester, find.byKey(const Key('hexagram-card')));
    });
  });
}
