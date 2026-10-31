// S30 (owner, 2026-10-30): the interactions, each where the app has the element. 按压回弹: a button shrinks to 96 %
// while pressed, and when let go springs past 100 % and settles (PressBounce, buttons.dart).
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mingli_app/presentation/buttons.dart';
import 'package:mingli_app/presentation/design.dart';
import 'package:mingli_app/presentation/keyboard.dart';
import 'package:mingli_app/presentation/theme.dart';
import 'package:mingli_app/presentation/widgets/elastic_switch.dart';

import 'keys.dart';
import 'support.dart';

Widget host(Widget child, {bool still = false}) => MaterialApp(
      theme: buildTheme(Brightness.light),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: still),
          child: Scaffold(body: Center(child: SizedBox(width: 240, child: child))),
        ),
      ),
    );

/// The press scale of what [key] names (its PressBounce's).
double scaleOf(WidgetTester tester, Key key) => tester
    .widget<ScaleTransition>(find.descendant(of: find.byKey(key), matching: find.byType(ScaleTransition)).first)
    .scale
    .value;

/// The scale frame by frame for [ms] milliseconds.
Future<List<double>> track(WidgetTester tester, Key key, {int ms = 1000}) async {
  final seen = <double>[];
  for (var t = 0; t < ms; t += 16) {
    await tester.pump(const Duration(milliseconds: 16));
    seen.add(scaleOf(tester, key));
  }
  return seen;
}

void main() {
  const k = Key('b');

  testWidgets('按压回弹: held, a button shrinks to 96 %; let go, it springs past 100 % and comes to rest at 100 %',
      (tester) async {
    await tester.pumpWidget(host(AppFilledButton(key: k, onPressed: () {}, child: const Text('排盘'))));
    final press = await tester.startGesture(tester.getCenter(find.byKey(k)));
    await tester.pump(const Duration(milliseconds: 200)); // the tap's press timeout: now it is pressed
    await tester.pump(const Duration(milliseconds: 200));
    expect(scaleOf(tester, k), closeTo(PressBounce.pressedScale, 1e-3));
    await press.up();
    final seen = await track(tester, k);
    expect(seen.reduce((a, b) => a > b ? a : b), greaterThan(1.005), reason: 'it passes 100 %');
    expect(seen.reduce((a, b) => a > b ? a : b), lessThan(1.03), reason: 'only a little');
    expect(seen.last, 1.0);
  });

  testWidgets('a quick tap still shrinks all the way, then springs back', (tester) async {
    var pressed = 0;
    await tester.pumpWidget(host(AppTextButton(key: k, onPressed: () => pressed++, child: const Text('取消'))));
    await tester.tap(find.byKey(k));
    final seen = await track(tester, k);
    expect(pressed, 1);
    expect(seen.reduce((a, b) => a < b ? a : b), closeTo(PressBounce.pressedScale, 2e-3));
    expect(seen.reduce((a, b) => a > b ? a : b), greaterThan(1.005));
    expect(seen.last, 1.0);
  });

  testWidgets('reduce motion, or a button that is off: no bounce', (tester) async {
    await tester.pumpWidget(host(AppFilledButton(key: k, onPressed: () {}, child: const Text('排盘')), still: true));
    await tester.tap(find.byKey(k));
    expect((await track(tester, k, ms: 400)).every((s) => s == 1.0), isTrue, reason: 'reduce motion');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(host(const AppFilledButton(key: k, onPressed: null, child: Text('排盘'))));
    await tester.tap(find.byKey(k), warnIfMissed: false);
    expect((await track(tester, k, ms: 400)).every((s) => s == 1.0), isTrue, reason: 'disabled');
  });

  testWidgets('every kind of the app\'s buttons bounces, and so do a tappable card and the floating button',
      (tester) async {
    final targets = <Key, Widget>{
      const Key('filled-icon'): AppFilledButton.icon(
        key: const Key('filled-icon'),
        onPressed: () {},
        icon: const Icon(Icons.add),
        label: const Text('新增'),
      ),
      const Key('tonal'): AppFilledButton.tonalIcon(
        key: const Key('tonal'),
        onPressed: () {},
        icon: const Icon(Icons.add),
        label: const Text('新增'),
      ),
      const Key('outlined'): AppOutlinedButton(key: const Key('outlined'), onPressed: () {}, child: const Text('重算')),
      const Key('outlined-icon'): AppOutlinedButton.icon(
        key: const Key('outlined-icon'),
        onPressed: () {},
        icon: const Icon(Icons.refresh),
        label: const Text('重算'),
      ),
      const Key('text-icon'): AppTextButton.icon(
        key: const Key('text-icon'),
        onPressed: () {},
        icon: const Icon(Icons.close),
        label: const Text('关闭'),
      ),
      const Key('icon'): AppIconButton(key: const Key('icon'), onPressed: () {}, icon: const Icon(Icons.menu)),
      const Key('card'): AppCard(key: const Key('card'), onTap: () {}, child: const Text('八字排盘')),
      const Key('fab'): AppFab.extended(
        key: const Key('fab'),
        onPressed: () {},
        icon: const Icon(Icons.forum),
        label: const Text('追问'),
      ),
    };
    for (final MapEntry(key: key, value: widget) in targets.entries) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(host(widget));
      await tester.tap(find.byKey(key));
      final seen = await track(tester, key);
      expect(seen.reduce((a, b) => a < b ? a : b), closeTo(PressBounce.pressedScale, 2e-3), reason: '$key');
      expect(seen.last, 1.0, reason: '$key');
    }
  });

  testWidgets('a card without a tap, and a chart that takes the tap\'s position, stay still', (tester) async {
    await tester.pumpWidget(host(const AppCard(key: k, child: Text('命盘事实'))));
    await tester.tap(find.byKey(k));
    expect((await track(tester, k, ms: 400)).every((s) => s == 1.0), isTrue, reason: 'a plain card');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(host(Pressable(key: k, onTapDown: (_) {}, child: const SizedBox(height: 80))));
    await tester.tap(find.byKey(k));
    expect(find.descendant(of: find.byKey(k), matching: find.byType(ScaleTransition)), findsNothing, reason: 'a chart');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(host(Pressable(key: k, onPressed: () {}, child: const SizedBox(height: 80))));
    await tester.tap(find.byKey(k));
    final seen = await track(tester, k);
    expect(seen.reduce((a, b) => a < b ? a : b), closeTo(PressBounce.pressedScale, 2e-3), reason: 'a button');
  });

  testWidgets('波纹跟手: the ripple grows from where the finger went down and stays centred there', (tester) async {
    await tester.pumpWidget(host(AppFilledButton(key: k, onPressed: () {}, child: const Text('排盘'))));
    final well = find.descendant(of: find.byKey(k), matching: find.byType(InkWell));
    final ink = Material.of(tester.element(well)) as RenderBox;
    final press = await tester.startGesture(tester.getTopLeft(well) + const Offset(24, 12));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
    // Near the button's left end, far from its centre: Material 3's own ripple would have drifted towards the centre.
    expect(ink, paints..circle(x: 24, y: 12));
    await press.up();
  });

  testWidgets('☰ → ✕: the lines turn into a cross as the menu slides in, at the same place, and back as it goes',
      (tester) async {
    await tester.pumpWidget(testApp(FakeApi()));
    await frames(tester, 10);
    double turn(String key) => tester
        .widget<AnimatedIcon>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(AnimatedIcon)))
        .progress
        .value;
    expect(turn('open-menu'), 0);
    final lines = tester.getCenter(find.byKey(const Key('open-menu')));
    await tester.tap(find.byKey(const Key('open-menu')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(turn('open-menu'), inExclusiveRange(0.0, 1.0), reason: 'turning as the menu slides');
    await frames(tester, 10);
    expect(turn('menu-close'), 1);
    expect(tester.getCenter(find.byKey(const Key('menu-close'))), offsetMoreOrLessEquals(lines, epsilon: 0.5));
    await tester.tap(find.byKey(const Key('menu-close')));
    await frames(tester, 10);
    expect(find.byKey(const Key('app-menu')), findsNothing);
    expect(turn('open-menu'), 0);
  });

  group('数字滚动', () {
    Widget number(int value, {bool still = false}) => host(
          RollingNumber<int>(value, format: (v) => '$v 积分', textKey: k),
          still: still,
        );
    int shown(WidgetTester tester) => int.parse(tester.widget<Text>(find.byKey(k)).data!.split(' ').first);

    testWidgets('it starts at its value, then rolls to a new one, slowing down until it stops there', (tester) async {
      await tester.pumpWidget(number(100));
      expect(shown(tester), 100, reason: 'no roll at first');
      await tester.pumpWidget(number(1100));
      final seen = <int>[];
      for (var t = 0; t < 700; t += 50) {
        await tester.pump(const Duration(milliseconds: 50));
        seen.add(shown(tester));
      }
      final steps = [for (var i = 1; i < seen.length; i++) seen[i] - seen[i - 1]];
      expect(steps.every((s) => s >= 0), isTrue, reason: 'only up: $seen');
      expect(steps.first, greaterThan(steps[steps.length ~/ 2]), reason: 'slower as it nears the end: $seen');
      expect(seen.last, 1100);
      expect(tester.getSemantics(find.byType(RollingNumber<int>)), isSemantics(label: '1100 积分'));
    });

    testWidgets('reduce motion: it jumps', (tester) async {
      await tester.pumpWidget(number(100, still: true));
      await tester.pumpWidget(number(1100, still: true));
      await tester.pump();
      expect(shown(tester), 1100);
    });
  });

  group('弹性开关', () {
    Widget tile({bool still = false, required ValueChanged<bool> changed, required bool Function() on}) => host(
          StatefulBuilder(
            builder: (context, set) => AppSwitchTile(
              key: k,
              value: on(),
              onChanged: (v) => set(() => changed(v)),
              title: const Text('真太阳时'),
            ),
          ),
          still: still,
        );
    ElasticPainter painter(WidgetTester tester) => tester
        .widget<CustomPaint>(find.descendant(of: find.byType(ElasticSwitch), matching: find.byType(CustomPaint)))
        .painter! as ElasticPainter;

    testWidgets('the thumb stretches into a capsule on its way and comes to rest round, after a slight rebound',
        (tester) async {
      var on = false;
      await tester.pumpWidget(tile(changed: (v) => on = v, on: () => on));
      await tester.tap(find.byKey(k));
      final positions = <double>[];
      final stretches = <double>[];
      for (var t = 0; t < 800; t += 16) {
        await tester.pump(const Duration(milliseconds: 16));
        positions.add(painter(tester).position);
        stretches.add(ElasticPainter.stretchAt(painter(tester).speed));
      }
      expect(on, isTrue);
      expect(stretches.reduce(math.max), greaterThan(1.3), reason: 'a capsule on its way');
      expect(positions.reduce(math.max), inExclusiveRange(1.0, 1.2), reason: 'a slight rebound past the end');
      expect(positions.last, 1.0);
      expect(stretches.last, 1.0, reason: 'round at rest');
    });

    testWidgets('reduce motion: it jumps, round', (tester) async {
      var on = false;
      await tester.pumpWidget(tile(still: true, changed: (v) => on = v, on: () => on));
      await tester.tap(find.byKey(k));
      await tester.pump();
      expect([painter(tester).position, ElasticPainter.stretchAt(painter(tester).speed)], [1.0, 1.0]);
    });

    testWidgets('its row is one control: one Tab stop, Space and Enter toggle it, and it reads as on or off',
        (tester) async {
      var on = false;
      await tester.pumpWidget(tile(changed: (v) => on = v, on: () => on));
      expect(await tabStops(tester), ['b']);
      await tabTo(tester, 'b');
      await press(tester, LogicalKeyboardKey.space);
      expect(on, isTrue);
      await frames(tester, 10);
      expect(tester.getSemantics(find.byKey(k)), isSemantics(hasToggledState: true, isToggled: true));
      await press(tester, LogicalKeyboardKey.enter);
      expect(on, isFalse);
    });
  });
}
