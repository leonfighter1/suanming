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
  /// A page of reading and forms: about 40 characters of body text to a line.
  static const reading = 720.0;

  /// A page that sets things side by side: a tarot spread.
  static const wide = 1200.0;

  /// The width of [span] of [columns] columns across [width], with the gutters between them.
  static double span(double width, int span, {required int columns, required double gutter}) =>
      (width - gutter * (columns - 1)) / columns * span + gutter * (span - 1);
}

/// A page's padding (the ui-design skill): the window class's margin at the sides, and on a wide window enough to keep
/// the content in a centred column at most [maxWidth] wide; [top] and [bottom] as given. For a page's scrolling list,
/// so its scrollbar stays at the window's edge.
EdgeInsets pagePadding(
  BuildContext context, {
  double maxWidth = Grid.reading,
  double top = Space.m,
  double bottom = Space.xxl,
}) {
  final width = MediaQuery.sizeOf(context).width;
  final side = math.max(WindowClass.of(width).margin, (width - maxWidth) / 2);
  return EdgeInsets.fromLTRB(side, top, side, bottom);
}
