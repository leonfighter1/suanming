import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'design.dart';

/// Window classes (Material 3; tech plan S24, the ui-design skill), by the window's width. Each has its columns, its
/// margin (the room at the window's sides) and its gutter (between columns), all on the 4-point scale.
enum WindowClass {
  /// Below 600: a phone.
  compact(columns: 4, margin: Space.l, gutter: Space.l),

  /// 600 to 840: a small tablet, a phone on its side.
  medium(columns: 8, margin: Space.xl, gutter: Space.xl),

  /// 840 to 1200: a tablet on its side, a small window.
  expanded(columns: 12, margin: Space.xl, gutter: Space.xl),

  /// 1200 and wider: a desktop.
  large(columns: 12, margin: Space.xxl, gutter: Space.xl);

  const WindowClass({required this.columns, required this.margin, required this.gutter});
  final int columns;
  final double margin;
  final double gutter;

  static WindowClass of(double width) => width < 600
      ? compact
      : width < 840
          ? medium
          : width < 1200
              ? expanded
              : large;

  /// The class of the window round [context].
  static WindowClass ofContext(BuildContext context) => of(MediaQuery.sizeOf(context).width);
}

/// The widths content may take (the ui-design skill).
abstract final class Grid {
  /// A column of reading: about 40 characters of body text to a line.
  static const reading = 720.0;

  /// The app's container (owner, 2026-10-30: 「大于 1620px 时要设置一个max-width 1620px。本体可以是fluid」, then
  /// 「对于所有的页面，基本框架在大屏时都要有这个尺寸限制（包括设置页面）」): every page fills it ([pagePadding]). Fluid on a
  /// phone and a tablet; on a wider window at most this wide, centred, the window class's margin inside it.
  static const container = 1620.0;

  /// The width of [span] of [columns] columns across [width], with the gutters between them.
  static double span(double width, int span, {required int columns, required double gutter}) =>
      (width - gutter * (columns - 1)) / columns * span + gutter * (span - 1);
}

/// A page's parts in two columns on a desktop window (the large class; S35, the owner: 「八字摆盘现在的UI太挤，尤其是desktop
/// … 根据我的ui desgin principal，以app为主，重新排版」): [main] at the left, eight of the twelve columns, the page's
/// anchor and what is read at length; [side] at the right, the other four, compact facts; each column stacks from the
/// top. On a phone and a tablet one column, the app's own order: [side] after the first [sideAfter] parts of [main].
/// Tab goes down the main column, then the side.
class SideColumns extends StatelessWidget {
  const SideColumns({super.key, required this.main, required this.side, this.sideAfter = 1});
  final List<Widget> main;
  final List<Widget> side;
  final int sideAfter;

  @override
  Widget build(BuildContext context) {
    final window = WindowClass.ofContext(context);
    Widget column(List<Widget> parts) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: parts);
    if (window != WindowClass.large) {
      return column([...main.take(sideAfter), ...side, ...main.skip(sideAfter)]);
    }
    return LayoutBuilder(
      builder: (context, box) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: column(main)),
          SizedBox(width: window.gutter),
          SizedBox(
            key: const Key('side-column'),
            width: Grid.span(box.maxWidth, 4, columns: window.columns, gutter: window.gutter),
            child: column(side),
          ),
        ],
      ),
    );
  }
}

/// A page's padding (the ui-design skill): the app's container ([Grid.container]). The window class's margin at the
/// sides and, on a window wider than the container, the room beyond it, so the container is centred with the margin
/// inside it; on a phone and a tablet only the margin (「在tablet和mobile device 可以不用有这限制了」). Without [margin],
/// only the room beyond the container: for a list whose rows carry their own inset (设置's tiles). [top] and [bottom]
/// as given. For a page's scrolling list, so its scrollbar stays at the window's edge.
EdgeInsets pagePadding(
  BuildContext context, {
  double top = Space.m,
  double bottom = Space.xxl,
  bool margin = true,
}) {
  final width = MediaQuery.sizeOf(context).width;
  final side = math.max(0.0, (width - Grid.container) / 2) + (margin ? WindowClass.of(width).margin : 0);
  return EdgeInsets.fromLTRB(side, top, side, bottom);
}

/// Cards side by side on a desktop window (the large class; owner, 2026-10-30: 「在超大屏幕布局时可以采用2X2布局。如果
/// 只有一个那就采用1x1」): two to a row with the gutter between, each row as tall as its tallest card, and a card alone in
/// its row across the whole row. One column on a phone and a tablet. Each card keeps its own gap below (an `AppCard`'s),
/// and Tab goes row by row.
class CardGrid extends StatelessWidget {
  const CardGrid({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final window = WindowClass.ofContext(context);
    if (window != WindowClass.large) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i += 2)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: children[i]),
                if (i + 1 < children.length) ...[SizedBox(width: window.gutter), Expanded(child: children[i + 1])],
              ],
            ),
          ),
      ],
    );
  }
}
