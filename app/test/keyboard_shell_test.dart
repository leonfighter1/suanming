import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mingli_app/l10n/gen/app_localizations.dart';
import 'package:mingli_app/presentation/keyboard.dart';

import 'keys.dart';

/// The keyboard layer on its own (no API, no fixtures): runs on the VM and with
/// `flutter test --platform chrome test/keyboard_shell_test.dart`.
Widget shellApp(Widget home) => MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (_, navigator) => KeyboardShell(child: navigator!),
      home: home,
    );

void push(BuildContext context, Widget page) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

class Home extends StatelessWidget {
  const Home({super.key, required this.next});
  final Widget next;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('home')),
        body: Center(
          child: TextButton(key: const Key('open'), onPressed: () => push(context, next), child: const Text('open')),
        ),
      );
}

/// A page with a dialog, a popup menu, a dropdown and a text field.
class Busy extends StatelessWidget {
  const Busy({super.key, this.guarded = false, this.onSubmit});
  final bool guarded;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) => LeaveGuard(
        active: guarded,
        child: SubmitShortcut(
          onSubmit: onSubmit,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('page'),
              actions: [
                PopupMenuButton<int>(
                  key: const Key('menu'),
                  itemBuilder: (_) => const [PopupMenuItem(value: 1, child: Text('one'))],
                ),
              ],
            ),
            body: Column(
              children: [
                TextButton(
                  key: const Key('dialog'),
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => const AlertDialog(key: Key('a-dialog'), content: Text('dialog')),
                  ),
                  child: const Text('dialog'),
                ),
                DropdownMenu<int>(
                  key: const Key('dropdown'),
                  dropdownMenuEntries: const [
                    DropdownMenuEntry(value: 1, label: 'first'),
                    DropdownMenuEntry(value: 2, label: 'second'),
                  ],
                ),
                const TextField(key: Key('field')),
              ],
            ),
          ),
        ),
      );
}

final onPage = find.text('page');
final onHome = find.text('home');

void main() {
  testWidgets('Esc goes back one level; on the first page it does nothing', (tester) async {
    await tester.pumpWidget(shellApp(const Home(next: Busy())));
    await press(tester, LogicalKeyboardKey.escape);
    expect(onHome, findsOneWidget);

    await tester.tap(find.byKey(const Key('open')));
    await frames(tester);
    // Nothing on the page has focus yet: Esc still works.
    await press(tester, LogicalKeyboardKey.escape);
    expect(onPage, findsNothing);
    expect(onHome, findsOneWidget);
  });

  testWidgets('Esc closes the topmost layer first: dialog, popup menu, dropdown, then the page', (tester) async {
    await tester.pumpWidget(shellApp(const Home(next: Busy())));
    await tester.tap(find.byKey(const Key('open')));
    await frames(tester);

    await tester.tap(find.byKey(const Key('dialog')));
    await frames(tester);
    expect(find.byKey(const Key('a-dialog')), findsOneWidget);
    await press(tester, LogicalKeyboardKey.escape);
    expect(find.byKey(const Key('a-dialog')), findsNothing);
    expect(onPage, findsOneWidget);

    await tester.tap(find.byKey(const Key('menu')));
    await frames(tester);
    expect(find.text('one'), findsOneWidget);
    await press(tester, LogicalKeyboardKey.escape);
    expect(find.text('one'), findsNothing);
    expect(onPage, findsOneWidget);

    // (A closed DropdownMenu keeps an invisible copy of its entries to size itself.)
    final entry = find.text('second').hitTestable();
    await tester.tap(find.byKey(const Key('dropdown')));
    await frames(tester);
    expect(entry, findsOneWidget);
    await press(tester, LogicalKeyboardKey.escape);
    expect(entry, findsNothing);
    expect(onPage, findsOneWidget);

    // From inside a text field too.
    await tester.tap(find.byKey(const Key('field')));
    await frames(tester);
    await press(tester, LogicalKeyboardKey.escape);
    expect(onHome, findsOneWidget);
  });

  testWidgets('a guarded page asks first: Esc stays, Enter goes back; ← and system back ask too', (tester) async {
    await tester.pumpWidget(shellApp(const Home(next: Busy(guarded: true))));
    await tester.tap(find.byKey(const Key('open')));
    await frames(tester);
    final confirm = find.byKey(const Key('leave-confirm'));

    await press(tester, LogicalKeyboardKey.escape);
    expect(confirm, findsOneWidget);
    expect(find.text('Going back starts over'), findsOneWidget);
    await press(tester, LogicalKeyboardKey.escape); // stay
    expect(confirm, findsNothing);
    expect(onPage, findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await frames(tester);
    expect(confirm, findsOneWidget);
    await tester.tap(find.byKey(const Key('leave-stay')));
    await frames(tester);
    expect(onPage, findsOneWidget);

    await systemBack(tester); // the browser's Back button
    expect(confirm, findsOneWidget);
    // 返回 has the focus: Enter confirms the step the user started.
    expect(focusedKey(), 'leave-go');
    await press(tester, LogicalKeyboardKey.enter);
    expect(confirm, findsNothing);
    expect(onHome, findsOneWidget);
  });

  testWidgets('Ctrl+/ shows the shortcut list; ? does too, but not while typing', (tester) async {
    await tester.pumpWidget(shellApp(const Home(next: Busy())));
    final list = find.byKey(const Key('shortcut-list'));

    await press(tester, LogicalKeyboardKey.slash, control: true);
    expect(list, findsOneWidget);
    expect(find.text('Keyboard shortcuts'), findsOneWidget);
    expect(find.text('Ctrl + Tab'), findsOneWidget);
    await press(tester, LogicalKeyboardKey.slash, control: true); // already open: no second copy
    expect(list, findsOneWidget);
    await press(tester, LogicalKeyboardKey.escape);
    expect(list, findsNothing);

    await press(tester, LogicalKeyboardKey.slash, shift: true, character: '?');
    expect(list, findsOneWidget);
    await press(tester, LogicalKeyboardKey.escape);

    await tester.tap(find.byKey(const Key('open')));
    await frames(tester);
    await tester.tap(find.byKey(const Key('field')));
    await frames(tester);
    final typed = await press(tester, LogicalKeyboardKey.slash, shift: true, character: '?');
    expect(list, findsNothing);
    expect(typed, isFalse, reason: 'the key must reach the text field');
    await press(tester, LogicalKeyboardKey.slash, control: true);
    expect(list, findsOneWidget);
  });

  testWidgets('Ctrl+Enter presses the main button of the page on top, focused or not', (tester) async {
    var pageSubmits = 0;
    var dialogSubmits = 0;
    await tester.pumpWidget(shellApp(Home(next: Busy(onSubmit: () => pageSubmits++))));
    await press(tester, LogicalKeyboardKey.enter, control: true);
    expect(pageSubmits, 0, reason: 'the first page has no main button');

    await tester.tap(find.byKey(const Key('open')));
    await frames(tester);
    await press(tester, LogicalKeyboardKey.enter, control: true);
    expect(pageSubmits, 1);
    await tester.tap(find.byKey(const Key('field')));
    await press(tester, LogicalKeyboardKey.enter, control: true);
    expect(pageSubmits, 2);

    // A dialog with its own main button takes over while it is open.
    showDialog<void>(
      context: tester.element(onPage),
      builder: (_) => SubmitShortcut(onSubmit: () => dialogSubmits++, child: const AlertDialog(content: Text('d'))),
    );
    await frames(tester);
    await press(tester, LogicalKeyboardKey.enter, control: true);
    expect((pageSubmits, dialogSubmits), (2, 1));
  });

  testWidgets('segment rows: ←/→ select the neighbour and move the focus with it', (tester) async {
    var value = 'a';
    await tester.pumpWidget(
      shellApp(
        StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: Center(
              child: SegmentKeys(
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'a', label: Text('A')),
                    ButtonSegment(value: 'b', label: Text('B')),
                    ButtonSegment(value: 'c', label: Text('C')),
                  ],
                  selected: {value},
                  onSelectionChanged: (s) => setState(() => value = s.first),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    Rect focused() => FocusManager.instance.primaryFocus!.rect;
    final b = tester.getRect(find.text('B'));

    await press(tester, LogicalKeyboardKey.tab);
    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(value, 'b');
    expect(focused().contains(b.center), isTrue);
    await press(tester, LogicalKeyboardKey.arrowRight);
    await press(tester, LogicalKeyboardKey.arrowRight); // at the end: stays
    expect(value, 'c');
    await press(tester, LogicalKeyboardKey.arrowLeft);
    expect(value, 'b');
    expect(focused().contains(b.center), isTrue);
  });

  testWidgets('Pressable: Tab, Enter and Space work; the ring shows for the keyboard only', (tester) async {
    var presses = 0;
    final target = find.byKey(const Key('target'));
    await tester.pumpWidget(
      shellApp(
        Scaffold(
          body: Center(
            child: Pressable(
              key: const Key('target'),
              onPressed: () => presses++,
              child: const SizedBox.square(dimension: 80),
            ),
          ),
        ),
      ),
    );
    await tester.tap(target);
    await frames(tester);
    expect(presses, 1);
    expect(ringShown(tester, target), isFalse);
    expect(keyboardInUse, isFalse);

    await press(tester, LogicalKeyboardKey.tab);
    expect(focusedKey(), 'target');
    expect(ringShown(tester, target), isTrue);
    expect(keyboardInUse, isTrue);
    await press(tester, LogicalKeyboardKey.enter);
    await press(tester, LogicalKeyboardKey.space);
    expect(presses, 3);

    await tester.tap(target); // back to touch: the ring goes
    await frames(tester);
    expect(ringShown(tester, target), isFalse);
    expect(keyboardInUse, isFalse);
  });
}
