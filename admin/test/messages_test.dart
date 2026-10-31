import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mingli_admin/presentation/message_editor_page.dart';
import 'package:mingli_app/presentation/buttons.dart';

import '../../app/test/keys.dart';
import 'support.dart';

// 消息 (tech plan S25 WP25.3; the owner: 设计好邮件发送逻辑，让后台用户可以编辑各类发送邮件的前端页面。同时还有SMS等等。…同时邮件的
// preview界面以及发送出去的邮件也要符合当前app的跟随系统模式): the messages by channel, the editor, its preview, a test send and
// the log.

const tall = Size(1440, 1400);

/// The 消息 page, then [kind]'s editor.
Future<void> openEditor(WidgetTester tester, String kind) async {
  if (find.byKey(Key('message-$kind')).evaluate().isEmpty) await go(tester, '消息');
  await tapOn(tester, 'message-$kind');
}

TextEditingController controllerOf(WidgetTester tester, String key) =>
    tester.widget<TextField>(find.byKey(Key(key))).controller!;

/// The last preview the editor asked for.
Json lastPreview(FakeAdmin f) => f.bodyOf(f.last('/v1/admin/messages/preview', method: 'POST'));

/// Types [text] into [key] and waits out the preview's pause.
Future<void> typeIn(WidgetTester tester, String key, String text) async {
  await tester.enterText(find.byKey(Key(key)), text);
  await tester.pump(previewDelay);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('消息 lists the messages by channel, each language marked once edited; the panel says how they leave', (tester) async {
    final f = FakeAdmin()
      ..custom['report_mail/zh-Hant'] = {'subject': '命理大師：{{title}}', 'body': '# {{title}}\n\n{{report}}', 'updated_at': '2026-10-29T08:00:00.000Z'}
      ..log.add({
        'id': 'd0',
        'at': '2026-10-29T11:55:00.000Z',
        'kind': 'code_sms',
        'channel': 'sms',
        'locale': 'zh-Hans',
        'to': '+86 *******5678',
        'status': 'sent',
        'transport': 'outbox',
        'custom': false,
      });
    await pumpAdmin(tester, fake: f, size: tall);
    await go(tester, '消息');
    for (final kind in ['code_mail', 'report_mail', 'records_mail', 'code_sms']) {
      expect(find.byKey(Key('message-$kind')), findsOneWidget, reason: kind);
    }
    expect(find.text('邮件'), findsWidgets);
    expect(find.text('短信'), findsWidgets);
    // The mail cards come before the SMS card.
    expect(
      tester.getRect(find.byKey(const Key('message-code_sms'))).top,
      greaterThan(tester.getRect(find.byKey(const Key('message-records_mail'))).top),
    );
    expect(find.descendant(of: find.byKey(const Key('message-report_mail-zh-Hant')), matching: find.text('繁體中文 · 已修改')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('message-report_mail-zh-Hans')), matching: find.text('简体中文')), findsOneWidget);
    expect(textOf(tester, 'delivery-mail'), '写进服务器的发件箱（.outbox），不经第三方服务');
    // The log: which message, to whom (masked), how it went.
    expect(find.descendant(of: find.byKey(const Key('log-d0')), matching: find.text('短信验证码')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('log-d0')), matching: find.text('+86 *******5678 · 简体中文')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('log-d0')), matching: find.text('已发出')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('log-d0')), matching: find.text('5 分钟前')), findsOneWidget);
  });

  testWidgets('the editor: the saved wording, previewed at once and again a moment after an edit; Ctrl+Enter saves', (tester) async {
    final f = await pumpAdmin(tester, size: tall);
    await openEditor(tester, 'code_mail');
    expect(controllerOf(tester, 'template-subject').text, '命理大师验证码：{{code}}');
    expect(controllerOf(tester, 'template-body').text, startsWith('# 验证你的邮箱'));
    expect(textOf(tester, 'wording-state'), '简体中文：默认内容');
    // The first preview: the saved wording, in the dashboard's light, with the sample values.
    expect(lastPreview(f), containsPair('kind', 'code_mail'));
    expect(lastPreview(f), containsPair('locale', 'zh-Hans'));
    expect(lastPreview(f), containsPair('scheme', 'light'));
    expect(textOf(tester, 'preview-subject'), '命理大师验证码：482913');
    // Off the web the mail's text stands in for its page.
    expect(find.descendant(of: find.byKey(const Key('mail-text')), matching: find.textContaining('!! 482913')), findsOneWidget);
    expect(tester.widget<AppFilledButton>(find.byKey(const Key('template-save'))).onPressed, isNull);

    final asked = f.to('/v1/admin/messages/preview', method: 'POST').length;
    await tester.enterText(find.byKey(const Key('template-body')), '你的码：{{code}}');
    await tester.pump(const Duration(milliseconds: 100));
    expect(f.to('/v1/admin/messages/preview', method: 'POST'), hasLength(asked));
    await tester.pump(previewDelay);
    await tester.pumpAndSettle();
    expect(f.to('/v1/admin/messages/preview', method: 'POST'), hasLength(asked + 1));
    expect(lastPreview(f), containsPair('body', '你的码：{{code}}'));
    expect(find.descendant(of: find.byKey(const Key('mail-text')), matching: find.text('你的码：482913')), findsOneWidget);

    await press(tester, LogicalKeyboardKey.enter, control: true);
    await tester.pumpAndSettle();
    final put = f.last('/v1/admin/messages/templates/code_mail/zh-Hans', method: 'PUT');
    expect(f.bodyOf(put), {'subject': '命理大师验证码：{{code}}', 'body': '你的码：{{code}}'});
    expect(find.text('已保存简体中文的内容'), findsOneWidget);
    expect(textOf(tester, 'wording-state'), startsWith('简体中文：已修改'));
    expect(tester.widget<AppFilledButton>(find.byKey(const Key('template-save'))).onPressed, isNull);

    // Nothing unsaved: Esc goes straight back, and the list marks the language.
    await press(tester, LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('简体中文 · 已修改'), findsOneWidget);
  });

  testWidgets('恢复默认 asks first, then the default wording is back; 撤销修改 drops the edits', (tester) async {
    final f = FakeAdmin()..custom['code_mail/zh-Hans'] = {'subject': '码 {{code}}', 'body': '码 {{code}}', 'updated_at': '2026-10-29T08:00:00.000Z'};
    await pumpAdmin(tester, fake: f, size: tall);
    await openEditor(tester, 'code_mail');
    expect(controllerOf(tester, 'template-body').text, '码 {{code}}');
    expect(textOf(tester, 'wording-state'), startsWith('简体中文：已修改'));

    await typeIn(tester, 'template-body', '码 {{code}} 改');
    await tapOn(tester, 'template-revert');
    expect(controllerOf(tester, 'template-body').text, '码 {{code}}');
    expect(f.to('/v1/admin/messages/templates/code_mail/zh-Hans', method: 'PUT'), isEmpty);

    await tapOn(tester, 'template-reset');
    expect(find.text('恢复简体中文的默认内容？'), findsOneWidget);
    await tapOn(tester, 'confirm-no');
    expect(f.to('/v1/admin/messages/templates/code_mail/zh-Hans', method: 'DELETE'), isEmpty);
    await tapOn(tester, 'template-reset');
    await tapOn(tester, 'confirm-yes');
    expect(f.to('/v1/admin/messages/templates/code_mail/zh-Hans', method: 'DELETE'), hasLength(1));
    expect(controllerOf(tester, 'template-body').text, startsWith('# 验证你的邮箱'));
    expect(controllerOf(tester, 'template-subject').text, '命理大师验证码：{{code}}');
    expect(textOf(tester, 'wording-state'), '简体中文：默认内容');
    expect(find.text('已恢复简体中文的默认内容'), findsOneWidget);
    expect(tester.widget<AppOutlinedButton>(find.byKey(const Key('template-reset'))).onPressed, isNull);
  });

  testWidgets('a value goes in where the cursor is; a part on a line of its own, in the body only', (tester) async {
    await pumpAdmin(tester, size: tall);
    await openEditor(tester, 'report_mail');
    final body = controllerOf(tester, 'template-body');
    body.value = const TextEditingValue(text: 'AB', selection: TextSelection.collapsed(offset: 1));
    await tester.pump();
    await tapOn(tester, 'var-title');
    expect(body.text, 'A{{title}}B');
    // The cursor after it: a part goes on its own line there.
    await tapOn(tester, 'var-report');
    expect(body.text, 'A{{title}}\n{{report}}\nB');

    // Into the subject once it had the focus; a part never.
    await tester.tap(find.byKey(const Key('template-subject')));
    await tester.pump();
    final subject = controllerOf(tester, 'template-subject');
    subject.selection = TextSelection.collapsed(offset: subject.text.length);
    await tapOn(tester, 'var-subtitle');
    expect(subject.text, '命理大师：{{title}}{{subtitle}}');
    await tester.tap(find.byKey(const Key('template-subject')));
    await tester.pump();
    await tapOn(tester, 'var-report');
    expect(subject.text, '命理大师：{{title}}{{subtitle}}');
    expect('{{report}}'.allMatches(body.text), hasLength(2));
  });

  testWidgets('what is wrong shows under the body, and 保存 waits until it is right', (tester) async {
    final f = await pumpAdmin(tester, size: tall);
    await openEditor(tester, 'code_mail');
    // {{code}} out of the subject too: the check reads both.
    await typeIn(tester, 'template-subject', '验证码');
    await typeIn(tester, 'template-body', '你好 {{who}}');
    expect(find.descendant(of: find.byKey(const Key('template-problems')), matching: find.text('没有 {{who}} 这个变量')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('template-problems')), matching: find.text('需要用到 {{code}}')), findsOneWidget);
    expect(tester.widget<AppFilledButton>(find.byKey(const Key('template-save'))).onPressed, isNull);
    await press(tester, LogicalKeyboardKey.enter, control: true);
    await tester.pumpAndSettle();
    expect(f.to('/v1/admin/messages/templates/code_mail/zh-Hans', method: 'PUT'), isEmpty);

    await typeIn(tester, 'template-body', '你好 {{code}}');
    expect(find.byKey(const Key('template-problems')), findsNothing);
    expect(tester.widget<AppFilledButton>(find.byKey(const Key('template-save'))).onPressed, isNotNull);
  });

  testWidgets('another language asks about unsaved edits first; its own wording, previewed', (tester) async {
    final f = await pumpAdmin(tester, size: tall);
    await openEditor(tester, 'code_mail');
    await typeIn(tester, 'template-body', '改了 {{code}}');
    await tester.tap(find.descendant(of: find.byKey(const Key('locale')), matching: find.text('繁體中文')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('leave-confirm')), findsOneWidget);
    await tapOn(tester, 'leave-stay');
    expect(controllerOf(tester, 'template-body').text, '改了 {{code}}');
    expect(textOf(tester, 'wording-state'), '简体中文：默认内容');

    await tester.tap(find.descendant(of: find.byKey(const Key('locale')), matching: find.text('繁體中文')));
    await tester.pumpAndSettle();
    await tapOn(tester, 'leave-go');
    expect(controllerOf(tester, 'template-body').text, startsWith('# 驗證你的郵箱'));
    expect(textOf(tester, 'wording-state'), '繁體中文：默认内容');
    expect(lastPreview(f), containsPair('locale', 'zh-Hant'));
    expect(lastPreview(f), containsPair('body', '# 驗證你的郵箱\n\n你的驗證碼是：\n\n!! {{code}}'));
  });

  testWidgets('发送测试: where to, then the draft with the sample values; the log shows it', (tester) async {
    final f = await pumpAdmin(tester, size: tall);
    await openEditor(tester, 'code_mail');
    // The saved wording: no draft goes along.
    await tapOn(tester, 'template-test');
    expect(find.text('发送测试邮件'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('test-to')), 'me@example.com');
    await press(tester, LogicalKeyboardKey.enter, control: true);
    await tester.pumpAndSettle();
    expect(f.bodyOf(f.last('/v1/admin/messages/test', method: 'POST')), {'kind': 'code_mail', 'locale': 'zh-Hans', 'to': 'me@example.com'});
    expect(find.text('测试邮件已发到 m***@example.com（写进了服务器的发件箱）'), findsOneWidget);
    expect(find.byKey(const Key('log-d1')), findsOneWidget);

    // A draft goes along as it is; Enter in the field sends.
    await typeIn(tester, 'template-body', '测试 {{code}}');
    await tapOn(tester, 'template-test');
    await tester.enterText(find.byKey(const Key('test-to')), 'me@example.com');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(f.bodyOf(f.last('/v1/admin/messages/test', method: 'POST')), {
      'kind': 'code_mail',
      'locale': 'zh-Hans',
      'to': 'me@example.com',
      'subject': '命理大师验证码：{{code}}',
      'body': '测试 {{code}}',
    });
    expect(find.byKey(const Key('log-d2')), findsOneWidget);

    // A bad address, and a server that can't send, each say so; Esc closes the question, nothing sent.
    await tapOn(tester, 'template-test');
    await tester.enterText(find.byKey(const Key('test-to')), 'nobody');
    await tapOn(tester, 'test-send');
    expect(find.text('to must be an email address'), findsOneWidget);
    f.deliveryOff = true;
    await tapOn(tester, 'template-test');
    await tester.enterText(find.byKey(const Key('test-to')), 'me@example.com');
    await tapOn(tester, 'test-send');
    expect(find.text('这台服务器没有发送方式，发不出去'), findsOneWidget);
    final sent = f.to('/v1/admin/messages/test', method: 'POST').length;
    await tapOn(tester, 'template-test');
    await press(tester, LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(f.to('/v1/admin/messages/test', method: 'POST'), hasLength(sent));
  });

  testWidgets('leaving with unsaved edits asks first', (tester) async {
    await pumpAdmin(tester, size: tall);
    await openEditor(tester, 'code_mail');
    await typeIn(tester, 'template-body', '没保存 {{code}}');
    await press(tester, LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('leave-confirm')), findsOneWidget);
    await tapOn(tester, 'leave-stay');
    expect(find.byKey(const Key('template-body')), findsOneWidget);
    await press(tester, LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await tapOn(tester, 'leave-go');
    expect(find.byKey(const Key('template-body')), findsNothing);
    expect(find.byKey(const Key('message-code_mail')), findsOneWidget);
  });

  testWidgets('an SMS: no subject; its text, its length and the messages it takes', (tester) async {
    await pumpAdmin(tester, size: tall);
    await openEditor(tester, 'code_sms');
    expect(find.byKey(const Key('template-subject')), findsNothing);
    const text = '【命理大师】你的验证码是 482913，10 分钟内有效。如非本人操作，请忽略本短信。';
    expect(tester.widget<SelectableText>(find.byKey(const Key('preview-sms'))).data, text);
    expect(textOf(tester, 'preview-segments'), '${text.runes.length} 个字 · 1 条短信');
    // Longer than 70 with Chinese in it: 67 a message.
    await typeIn(tester, 'template-body', '验证码 {{code}}${'很' * 70}');
    final long = '验证码 482913${'很' * 70}';
    expect(textOf(tester, 'preview-segments'), '${long.runes.length} 个字 · ${(long.runes.length / 67).ceil()} 条短信');
  });

  testWidgets('the preview follows 外观: a dark dashboard asks for the dark page', (tester) async {
    final f = await pumpAdmin(tester, size: tall, prefs: {'mingli-admin-theme': 'dark'});
    await openEditor(tester, 'report_mail');
    expect(lastPreview(f), containsPair('scheme', 'dark'));
  });

  testWidgets('from the keyboard: Tab to a message, Enter opens it; the editor in reading order', (tester) async {
    await pumpAdmin(tester, size: tall);
    await go(tester, '消息');
    await tabTo(tester, 'message-code_mail');
    await press(tester, LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('template-body')), findsOneWidget);
    final stops = await tabStops(tester);
    expect(
      stops,
      containsAllInOrder(['locale', 'template-subject', 'var-code', 'var-minutes', 'template-body', 'template-test']),
    );
  });
}
