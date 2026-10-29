import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mingli_app/application/providers.dart';

import 'support.dart';

// v8.2.0 (tech plan WP15.3), the owner: 用户可以用用户名或者邮箱登录或者手机号登录，手机号需要绑定用户本人.

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> openSettings(WidgetTester tester) async {
  await openFromMenu(tester, 'open-settings');
  await settle(tester);
}

String subtitle(WidgetTester tester, String key) =>
    (tester.widget<ListTile>(find.byKey(Key(key))).subtitle! as Text).data!;

Map<String, dynamic> lastBody(FakeApi api, String path) =>
    jsonDecode(api.requests.lastWhere((r) => r.url.path == path).body) as Map<String, dynamic>;

void main() {
  testWidgets('the menu and 设置 show the username; it changes in its dialog, a taken one refused', (tester) async {
    final api = FakeApi(email: 'test@mingli.local', username: 'leon');
    await tester.pumpWidget(testApp(api, locale: zhHans));
    await settle(tester);
    await tester.tap(find.byKey(const Key('open-menu')));
    await settle(tester);
    expect(tester.widget<Text>(find.byKey(const Key('menu-account'))).data, 'leon');
    await tester.tap(find.byKey(const Key('open-settings')));
    await settle(tester);
    expect(subtitle(tester, 'settings-username'), 'leon');

    await tester.tap(find.byKey(const Key('settings-username')));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('username-field')), 'taken');
    await settle(tester);
    await tester.tap(find.byKey(const Key('username-save')));
    await settle(tester);
    expect(find.text('这个用户名已被使用'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('username-field')), '新名字');
    await settle(tester);
    await tester.tap(find.byKey(const Key('username-save')));
    await settle(tester);
    expect(lastBody(api, '/v1/account/username'), {'username': '新名字'});
    expect(find.text('用户名已保存'), findsOneWidget);
    expect(subtitle(tester, 'settings-username'), '新名字');
  });

  testWidgets('binding a phone: the code goes out, a wrong code is refused, the right one binds it', (tester) async {
    final api = FakeApi(email: 'test@mingli.local');
    await tester.pumpWidget(testApp(api, locale: zhHans));
    await settle(tester);
    await openSettings(tester);
    expect(subtitle(tester, 'settings-phone'), '未绑定，点此绑定');

    await tester.tap(find.byKey(const Key('settings-phone')));
    await settle(tester);
    expect(find.text('绑定手机号'), findsOneWidget);
    expect(find.byKey(const Key('contact-code')), findsNothing);
    await tester.enterText(find.byKey(const Key('contact-value')), '9123 4567');
    await tester.tap(find.byKey(const Key('contact-send')));
    await settle(tester);
    expect(lastBody(api, '/v1/account/phone'), {'phone': '9123 4567'});
    expect(tester.widget<Text>(find.byKey(const Key('code-sent'))).data, '验证码已发送到 +852 ****4567，10 分钟内有效');
    // No provider yet: the dialog says the code stays on the server.
    expect(find.byKey(const Key('outbox-notice')), findsOneWidget);

    // 绑定 waits for six digits.
    await tester.enterText(find.byKey(const Key('contact-code')), '12');
    await settle(tester);
    expect(tester.widget<FilledButton>(find.byKey(const Key('contact-confirm'))).onPressed, isNull);
    await tester.enterText(find.byKey(const Key('contact-code')), '000000');
    await settle(tester);
    await tester.tap(find.byKey(const Key('contact-confirm')));
    await settle(tester);
    expect(tester.widget<Text>(find.byKey(const Key('contact-error'))).data, '验证码不对，请再看一下');
    await tester.enterText(find.byKey(const Key('contact-code')), FakeApi.code);
    await settle(tester);
    await tester.tap(find.byKey(const Key('contact-confirm')));
    await settle(tester);
    expect(lastBody(api, '/v1/account/phone/verify'), {'phone': '9123 4567', 'code': FakeApi.code});
    expect(find.text('绑定手机号'), findsNothing);
    expect(find.text('手机号已绑定'), findsOneWidget);
    expect(subtitle(tester, 'settings-phone'), '+85291234567');
  });

  testWidgets('a number bound to another account is refused', (tester) async {
    await tester.pumpWidget(testApp(FakeApi(email: 'test@mingli.local'), locale: zhHans));
    await settle(tester);
    await openSettings(tester);
    await tester.tap(find.byKey(const Key('settings-phone')));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('contact-value')), '+85200000000');
    await tester.tap(find.byKey(const Key('contact-send')));
    await settle(tester);
    expect(tester.widget<Text>(find.byKey(const Key('contact-error'))).data, '这个手机号已绑定其他账号');
    expect(find.byKey(const Key('contact-code')), findsNothing);
  });

  testWidgets('the email from sign-up is verified by a code; then it shows 已验证', (tester) async {
    final api = FakeApi(email: 'me@example.com');
    await tester.pumpWidget(testApp(api, locale: zhHans));
    await settle(tester);
    await openSettings(tester);
    expect(subtitle(tester, 'settings-email'), 'me@example.com · 未验证，点此验证');
    await tester.tap(find.byKey(const Key('settings-email')));
    await settle(tester);
    expect(find.text('验证邮箱'), findsOneWidget);
    // The account's email is filled in: sending verifies it.
    expect(tester.widget<TextField>(find.byKey(const Key('contact-value'))).controller!.text, 'me@example.com');
    await tester.tap(find.byKey(const Key('contact-send')));
    await settle(tester);
    expect(tester.widget<Text>(find.byKey(const Key('code-sent'))).data, '验证码已发送到 m***@example.com，10 分钟内有效');
    await tester.enterText(find.byKey(const Key('contact-code')), FakeApi.code);
    await settle(tester);
    await tester.tap(find.byKey(const Key('contact-confirm')));
    await settle(tester);
    expect(find.text('邮箱已验证'), findsOneWidget);
    expect(subtitle(tester, 'settings-email'), 'me@example.com · 已验证');
  });

  testWidgets('from the keyboard: Enter sends the code, Enter in the code binds', (tester) async {
    final api = FakeApi(email: 'test@mingli.local');
    await tester.pumpWidget(testApp(api, locale: zhHans));
    await settle(tester);
    await openSettings(tester);
    await tester.tap(find.byKey(const Key('settings-phone')));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('contact-value')), '+65 9123 4567');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await settle(tester);
    expect(find.byKey(const Key('code-sent')), findsOneWidget);
    // The code field took the focus: typing goes straight into it.
    expect(tester.widget<TextField>(find.byKey(const Key('contact-code'))).focusNode!.hasFocus, isTrue);
    await tester.enterText(find.byKey(const Key('contact-code')), FakeApi.code);
    await settle(tester);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    expect(subtitle(tester, 'settings-phone'), '+6591234567');
  });

  testWidgets('a provider delivering: no 测试环境 notice', (tester) async {
    final api = FakeApi(email: 'test@mingli.local')..delivery = 'some-provider';
    await tester.pumpWidget(testApp(api, locale: zhHans));
    await settle(tester);
    await openSettings(tester);
    await tester.tap(find.byKey(const Key('settings-phone')));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('contact-value')), '9123 4567');
    await tester.tap(find.byKey(const Key('contact-send')));
    await settle(tester);
    // A positive anchor first (rule 43): the code went out, and the notice that sits under it is absent.
    expect(find.byKey(const Key('code-sent')), findsOneWidget);
    expect(find.byKey(const Key('outbox-notice')), findsNothing);
  });

  testWidgets('unbinding the phone asks first, then the row offers binding again', (tester) async {
    final api = FakeApi(email: 'test@mingli.local')..phone = '+85291234567';
    await tester.pumpWidget(testApp(api, locale: zhHans));
    await settle(tester);
    await openSettings(tester);
    expect(subtitle(tester, 'settings-phone'), '+85291234567');
    await tester.tap(find.byKey(const Key('unbind-phone')));
    await settle(tester);
    expect(find.text('解绑？'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm-remove')));
    await settle(tester);
    expect(api.requests.any((r) => r.method == 'DELETE' && r.url.path == '/v1/account/phone'), isTrue);
    expect(find.text('手机号已解绑'), findsOneWidget);
    expect(subtitle(tester, 'settings-phone'), '未绑定，点此绑定');
  });

  // 测算完成后发到邮箱 (v9.0.0, WP15.4; the owner: 默认为否，改为是后自动发送).
  SwitchListTile reportsSwitch(WidgetTester tester) => tester.widget<SwitchListTile>(find.byKey(const Key('email-reports')));

  testWidgets('报告: 否 by default; the switch waits for a verified email; the outbox is named', (tester) async {
    await tester.pumpWidget(testApp(FakeApi(email: 'me@example.com'), locale: zhHans));
    await settle(tester);
    await openSettings(tester);
    await scrollTo(tester, const Key('email-reports'));
    expect(reportsSwitch(tester).value, isFalse);
    expect(reportsSwitch(tester).onChanged, isNull);
    expect(find.text('先在上面验证邮箱，才能开启'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('mail-delivery-notice'))).data,
      '测试环境：还没有接入邮件服务，邮件写在服务器的 .outbox 文件夹里，不会真的发出。',
    );
  });

  testWidgets('报告: with a verified email the switch turns on, and the server keeps it', (tester) async {
    final api = FakeApi(email: 'me@example.com', emailVerified: true);
    await tester.pumpWidget(testApp(api, locale: zhHans));
    await settle(tester);
    await openSettings(tester);
    await scrollTo(tester, const Key('email-reports'));
    expect(find.text('开启后，每次 AI 测算完成都会把报告发到 me@example.com'), findsOneWidget);
    await tester.tap(find.byKey(const Key('email-reports')));
    await settle(tester);
    expect(lastBody(api, '/v1/account/settings'), {'email_reports': true});
    expect(api.emailReports, isTrue);
    expect(reportsSwitch(tester).value, isTrue);
    expect(find.text('每次 AI 测算完成，报告都会发到 me@example.com'), findsOneWidget);
  });

  testWidgets('removing the email turns 测算完成后发到邮箱 back to 否', (tester) async {
    final api = FakeApi(email: 'me@example.com', emailVerified: true)..emailReports = true;
    await tester.pumpWidget(testApp(api, locale: zhHans));
    await settle(tester);
    await openSettings(tester);
    await tester.tap(find.byKey(const Key('remove-email')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('confirm-remove')));
    await settle(tester);
    await scrollTo(tester, const Key('email-reports'));
    expect(reportsSwitch(tester).value, isFalse);
    expect(reportsSwitch(tester).onChanged, isNull);
  });
}
