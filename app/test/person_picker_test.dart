import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mingli_app/application/providers.dart';
import 'package:mingli_app/data/profile_store.dart';
import 'package:mingli_app/domain/profile.dart';

import 'keys.dart';
import 'support.dart';

Future<void> openForm(WidgetTester tester, FakeApi api, InMemoryProfileStore store) async {
  tester.view.physicalSize = const Size(1000, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(testApp(api, profiles: store, locale: zhHans));
  await frames(tester, 12);
  await tester.tap(find.byKey(const Key('entry-bazi')));
  await frames(tester, 12);
}

Future<void> pick(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(const Key('profile-picker')));
  await frames(tester, 12);
  await tester.tap(find.text(label).last);
  await frames(tester, 12);
}

Finder nameField() => find.descendant(of: find.byType(TextFormField), matching: find.byType(EditableText)).first;

Map chartBody(FakeApi api) => jsonDecode(api.requests.lastWhere((r) => r.url.path == '/v1/charts').body) as Map;

void main() {
  testWidgets('bug 1/3: after picking a person, the name and every field stay editable', (tester) async {
    final api = FakeApi(email: 'admin', pendingPolls: 0);
    await openForm(tester, api, InMemoryProfileStore());

    await pick(tester, '测试家人');
    expect(tester.widget<EditableText>(nameField()).controller.text, '测试家人');
    // The picker itself is not a text box.
    expect(tester.widget<EditableText>(find.descendant(of: find.byKey(const Key('profile-picker')), matching: find.byType(EditableText))).readOnly, isTrue);

    await tester.enterText(nameField(), '测试家人（改）');
    await frames(tester, 12);
    // Names never go to the server; the edited name labels the chart locally.
    await scrollTo(tester, const Key('compute-chart'));
    await tester.tap(find.byKey(const Key('compute-chart')));
    await frames(tester, 12);
    expect(chartBody(api).containsKey('name'), isFalse);
    expect(find.text('测试家人（改） 的命盘'), findsWidgets);
  });

  testWidgets('bug 2: 添加新的测试者 opens a pop-up; saving loads the new person into the form', (tester) async {
    final store = InMemoryProfileStore();
    final api = FakeApi(email: 'test@mingli.local');
    await openForm(tester, api, store);

    await pick(tester, '添加新的测试者');
    expect(find.byKey(const Key('profile-dialog')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('dialog-profile-name')), '小王');
    await frames(tester, 12);
    await tester.tap(find.byKey(const Key('dialog-save-profile')));
    await frames(tester, 12);

    expect(find.byKey(const Key('profile-dialog')), findsNothing);
    expect(tester.widget<EditableText>(nameField()).controller.text, '小王');
    final saved = ProfileBook.decode(store.data['u1']).profiles.map((p) => p.name);
    expect(saved, contains('小王'));
  });

  testWidgets('bug 3: 编辑资料 in the picker edits the selected person and reloads the form', (tester) async {
    final store = InMemoryProfileStore();
    final api = FakeApi(email: 'test@mingli.local');
    await openForm(tester, api, store);

    await pick(tester, '编辑“测试用户”的资料');
    expect(find.byKey(const Key('profile-dialog')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('dialog-profile-name')), '测试用户二');
    await frames(tester, 12);
    await tester.tap(find.byKey(const Key('dialog-save-profile')));
    await frames(tester, 12);

    expect(tester.widget<EditableText>(nameField()).controller.text, '测试用户二');
    expect(ProfileBook.decode(store.data['u1']).defaultProfile!.name, '测试用户二');
    // And the form is still editable afterwards.
    await tester.enterText(nameField(), '再改一次');
    await frames(tester, 12);
    expect(tester.widget<EditableText>(nameField()).controller.text, '再改一次');
  });

  testWidgets('cancelling the pop-up keeps the person who was picked', (tester) async {
    final api = FakeApi(email: 'admin');
    await openForm(tester, api, InMemoryProfileStore());
    await pick(tester, '添加新的测试者');
    await tester.tap(find.text('取消'));
    await frames(tester, 12);
    expect(tester.widget<EditableText>(nameField()).controller.text, '管理员');
  });
}
