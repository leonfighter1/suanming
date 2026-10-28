import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mingli_app/presentation/design.dart';

/// Keyboard helpers for widget tests (no dart:io, so they also run with
/// `flutter test --platform chrome`, where Enter and the arrows act as on the web).

/// Pumps a few frames: enough for a route or dialog to open or close.
Future<void> frames(WidgetTester tester, [int n = 8]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Presses [key], holding Ctrl and/or Shift if asked, then lets the app react.
/// A frame goes first, as one always does between a person's inputs: enterText
/// doesn't pump, and a key right after it would meet the page before its rebuild.
Future<bool> press(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  bool control = false,
  bool shift = false,
  String? character,
}) async {
  await tester.pump();
  if (control) await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  final handled = await tester.sendKeyDownEvent(key, character: character);
  await tester.sendKeyUpEvent(key);
  if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  if (control) await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await frames(tester);
  return handled;
}

/// The browser's (or the phone's) back: the engine's popRoute message.
Future<void> systemBack(WidgetTester tester) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/navigation',
    const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute')),
    (_) {},
  );
  await frames(tester);
}

/// Presses Tab until [key] has the focus (named as [focusedKey] names it).
Future<void> tabTo(WidgetTester tester, String key, {int max = 60}) async {
  for (var i = 0; i < max && focusedKey() != key; i++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await frames(tester, 3);
  }
  expect(focusedKey(), key, reason: 'Tab never reached $key');
}

/// The nearest string key above the focused node: how tests name a Tab stop.
String? focusedKey() {
  final context = FocusManager.instance.primaryFocus?.context;
  String? found;
  context?.visitAncestorElements((e) {
    final k = e.widget.key;
    if (k is ValueKey<String>) {
      found = k.value;
      return false;
    }
    return true;
  });
  return found;
}

/// Presses Tab until the focus comes back round (or [max] presses), returning
/// each stop's [focusedKey] ('?' for a stop without a key).
Future<List<String>> tabStops(WidgetTester tester, {int max = 60}) async {
  final stops = <String>[];
  for (var i = 0; i < max; i++) {
    await press(tester, LogicalKeyboardKey.tab);
    final node = FocusManager.instance.primaryFocus;
    final name = focusedKey() ?? '?';
    if (stops.isNotEmpty && node == _first) break;
    if (stops.isEmpty) _first = node;
    stops.add(name);
  }
  _first = null;
  return stops;
}

FocusNode? _first;

/// Whether the keyboard focus ring is drawn at [finder] (or inside it).
bool ringShown(WidgetTester tester, Finder finder) {
  final rings = find.descendant(of: finder, matching: find.byType(FocusRing), matchRoot: true);
  return tester.stateList<FocusRingState>(rings).any((r) => r.shown);
}
