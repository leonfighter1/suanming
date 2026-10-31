import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mingli_admin/data/admin_api.dart';
import 'package:mingli_app/presentation/buttons.dart';

import '../../app/test/keys.dart';
import 'support.dart';

// 内容 (内容管理, tech plan S29): staff find a text the app shows by its words or its key, change it in each language or
// put it back to the app's own, and put the app's images in or take them out. FakeAdmin answers as src/admin/content.ts
// does.

const tall = Size(1440, 1800);

/// The 内容 page, wide enough for its panel.
Future<FakeAdmin> openContent(WidgetTester tester, {FakeAdmin? fake}) async {
  final f = await pumpAdmin(tester, fake: fake, size: tall);
  await go(tester, '内容');
  return f;
}

Future<void> search(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(const Key('content-search')), text);
  await tester.pumpAndSettle();
}

/// [key]'s editor, the text found by its key.
Future<void> openText(WidgetTester tester, String key) async {
  await search(tester, key);
  await tapOn(tester, 'text-$key');
}

/// [text] typed into [locale]'s field, and the field's notes settled (an error fades out).
Future<void> typeIn(WidgetTester tester, String locale, String text) async {
  await tester.enterText(find.byKey(ValueKey<String>('text-$locale')), text);
  await tester.pumpAndSettle();
}

bool saveOn(WidgetTester tester) => tester.widget<AppFilledButton>(find.byKey(const Key('text-save'))).onPressed != null;

/// A PNG's signature and a little after it.
final png = AdminFile(Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 0, 0]), 'banner.png', 'image/png');

const changedAt = '2026-10-29T12:00:00.000Z';

void main() {
  testWidgets('every text the app shows, in both languages with its key, 30 at a time', (tester) async {
    await openContent(tester);
    expect(textOf(tester, 'content-count'), '共 43 条');
    expect(find.byKey(const ValueKey<String>('text-homeTarot')), findsOneWidget);
    expect(find.text('塔羅占卜'), findsOneWidget);
    expect(find.text('pointsBalanceLine'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('text-sample27')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('text-sample28')), findsNothing);
    expect(find.text('再显示 13 条'), findsOneWidget);
    await tapOn(tester, 'content-more');
    expect(find.byKey(const ValueKey<String>('text-sample40')), findsOneWidget);
    expect(find.byKey(const Key('content-more')), findsNothing);
  });

  testWidgets('the search finds a text by its words (the app\'s or staff\'s, either language) or its key; 已修改 '
      'shows only the changed', (tester) async {
    final f = FakeAdmin()..contentTexts['sample5/zh-Hant'] = {'text': '改過的', 'updated_at': changedAt};
    await openContent(tester, fake: f);
    await search(tester, '塔羅');
    expect(textOf(tester, 'content-count'), '找到 1 条，共 43 条');
    expect(find.byKey(const ValueKey<String>('text-homeTarot')), findsOneWidget);
    await search(tester, 'pointsbalance');
    expect(find.byKey(const ValueKey<String>('text-pointsBalanceLine')), findsOneWidget);
    await search(tester, '改過');
    expect(find.byKey(const ValueKey<String>('text-sample5')), findsOneWidget);
    await search(tester, '没有这段');
    expect(find.text('没有符合的文字'), findsOneWidget);

    await search(tester, '');
    await tester.tap(find.descendant(of: find.byKey(const Key('content-filter')), matching: find.text('已修改')));
    await tester.pumpAndSettle();
    expect(textOf(tester, 'content-count'), '找到 1 条，共 43 条');
    expect(find.byKey(const ValueKey<String>('text-sample5-changed')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('text-homeTarot')), findsNothing);
  });

  testWidgets('a text changed in both languages: the server keeps each, the list marks it 已修改', (tester) async {
    final f = await openContent(tester);
    await openText(tester, 'homeTarot');
    expect(find.text('修改文字'), findsOneWidget);
    expect(find.text('应用自带的'), findsNWidgets(2));
    expect(saveOn(tester), isFalse, reason: 'nothing changed yet');
    await typeIn(tester, 'zh-Hans', '  塔罗占卜·新 ');
    await typeIn(tester, 'zh-Hant', '塔羅占卜·新');
    expect(find.text('应用自带：塔罗占卜'), findsOneWidget);
    await tapOn(tester, 'text-save');
    expect(f.bodyOf(f.last('/v1/admin/content/texts/homeTarot/zh-Hans', method: 'PUT')), {'text': '塔罗占卜·新'});
    expect(f.bodyOf(f.last('/v1/admin/content/texts/homeTarot/zh-Hant', method: 'PUT')), {'text': '塔羅占卜·新'});
    expect(find.text('修改文字'), findsNothing);
    expect(find.text('已保存，应用下次打开时显示'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('text-homeTarot-changed')), findsOneWidget);
    expect(find.text('塔罗占卜·新'), findsOneWidget);
  });

  testWidgets('a text keeps its placeholders: the editor names them, and a wording without is refused and why',
      (tester) async {
    final f = await openContent(tester);
    await openText(tester, 'pointsBalanceLine');
    expect(textOf(tester, 'text-placeholders'), '要保留：{balance}（应用会换成真实的值）');
    await typeIn(tester, 'zh-Hans', '余额积分');
    await tapOn(tester, 'text-save');
    expect(find.text('要保留 {balance}，不能加别的'), findsOneWidget);
    expect(f.contentTexts, isEmpty);
    expect(find.text('修改文字'), findsOneWidget, reason: 'still open, to put it right');
    expect(saveOn(tester), isFalse, reason: 'until the words change');

    await typeIn(tester, 'zh-Hans', '还剩 {balance} 积分');
    expect(find.text('要保留 {balance}，不能加别的'), findsNothing);
    await tapOn(tester, 'text-save');
    expect(f.contentTexts['pointsBalanceLine/zh-Hans']?['text'], '还剩 {balance} 积分');
    expect(find.text('修改文字'), findsNothing);
  });

  testWidgets('an empty wording can\'t be saved', (tester) async {
    await openContent(tester);
    await openText(tester, 'homeTarot');
    await typeIn(tester, 'zh-Hans', '  ');
    expect(find.text('不能为空'), findsOneWidget);
    expect(saveOn(tester), isFalse);
  });

  testWidgets('back to the app\'s own: the button puts its words back, 保存 takes staff\'s away', (tester) async {
    final f = FakeAdmin()..contentTexts['homeTarot/zh-Hans'] = {'text': '塔罗', 'updated_at': changedAt};
    await openContent(tester, fake: f);
    await openText(tester, 'homeTarot');
    expect(find.text('应用自带：塔罗占卜'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('text-zh-Hant-own')), findsNothing, reason: '繁體 is the app\'s own');
    await tapOn(tester, 'text-zh-Hans-own');
    expect(tester.widget<TextField>(find.byKey(const ValueKey<String>('text-zh-Hans'))).controller!.text, '塔罗占卜');
    await tapOn(tester, 'text-save');
    expect(f.to('/v1/admin/content/texts/homeTarot/zh-Hans', method: 'DELETE'), hasLength(1));
    expect(f.to('/v1/admin/content/texts/homeTarot/zh-Hans', method: 'PUT'), isEmpty);
    expect(f.contentTexts, isEmpty);
    expect(find.byKey(const ValueKey<String>('text-homeTarot-changed')), findsNothing);
  });

  testWidgets('from the keyboard: Tab and Enter open a text, the field is ready, Ctrl+Enter saves; Esc with an edit '
      'asks first', (tester) async {
    final f = await openContent(tester);
    await search(tester, 'homeTarot');
    await tabTo(tester, 'text-homeTarot');
    await press(tester, LogicalKeyboardKey.enter);
    expect(find.text('修改文字'), findsOneWidget);
    expect(focusedKey(), 'text-zh-Hans');

    await typeIn(tester, 'zh-Hans', '塔罗');
    await press(tester, LogicalKeyboardKey.escape);
    expect(find.byKey(const Key('leave-confirm')), findsOneWidget);
    await tapOn(tester, 'leave-stay');
    expect(find.text('修改文字'), findsOneWidget);

    await press(tester, LogicalKeyboardKey.enter, control: true);
    await tester.pumpAndSettle();
    expect(f.bodyOf(f.last('/v1/admin/content/texts/homeTarot/zh-Hans', method: 'PUT')), {'text': '塔罗'});
    expect(find.text('修改文字'), findsNothing);

    // Nothing changed: Esc closes at once.
    await openText(tester, 'pointsBalanceLine');
    await press(tester, LogicalKeyboardKey.escape);
    expect(find.text('修改文字'), findsNothing);
    expect(find.byKey(const Key('leave-confirm')), findsNothing);
  });

  testWidgets('a text whose own wording has lines: Enter starts a new line there', (tester) async {
    await openContent(tester);
    await openText(tester, 'serverUnreachable');
    final field = tester.widget<TextField>(find.byKey(const ValueKey<String>('text-zh-Hans')));
    expect(field.textInputAction, TextInputAction.newline);
    final other = tester.widget<TextField>(find.byKey(const ValueKey<String>('text-zh-Hant')));
    expect(other.keyboardType, TextInputType.multiline);
  });

  testWidgets('an image put in: offered the types the server takes, sent as it is, then shown; and taken out',
      (tester) async {
    final f = FakeAdmin()..pick = png;
    await openContent(tester, fake: f);
    expect(find.byKey(const ValueKey<String>('image-banner-own')), findsOneWidget);
    expect(textOf(tester, 'image-limits'), 'PNG、JPEG、WebP 格式，最多 2 MB。应用下次打开时显示。');
    await tapOn(tester, 'image-banner-put');
    expect(f.pickTypes, ['image/png', 'image/jpeg', 'image/webp']);
    final put = f.last('/v1/admin/content/images/banner', method: 'PUT');
    expect(put.headers['content-type'], 'image/png');
    expect(put.bodyBytes, png.bytes);
    expect(find.text('已换上「横幅背景（命理罗盘）」，应用下次打开时显示'), findsOneWidget);
    // From the server, at its version's address. The test's network answers 400: the broken-image mark, no error.
    final shown = tester.widget<Image>(find.byKey(const ValueKey<String>('image-banner-shown')));
    expect((shown.image as NetworkImage).url, endsWith('/v1/content/images/banner?v=$changedAt'));
    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);

    await tapOn(tester, 'image-banner-remove');
    expect(find.text('移除「横幅背景（命理罗盘）」？'), findsOneWidget);
    await tapOn(tester, 'confirm-yes');
    expect(f.to('/v1/admin/content/images/banner', method: 'DELETE'), hasLength(1));
    expect(find.byKey(const ValueKey<String>('image-banner-own')), findsOneWidget);
  });

  testWidgets('an image the server would refuse is not sent (another type, too large); nothing chosen, nothing sent',
      (tester) async {
    final f = FakeAdmin()..pick = AdminFile(Uint8List(10), 'a.gif', 'image/gif');
    await openContent(tester, fake: f);
    await tapOn(tester, 'image-banner-put');
    expect(find.text('要 PNG、JPEG、WebP 格式的图片'), findsOneWidget);
    f.pick = AdminFile(Uint8List(imageMaxBytes + 1), 'big.png', 'image/png');
    await tapOn(tester, 'image-banner-put');
    expect(find.text('图片太大了：最多 2 MB'), findsOneWidget);
    f.pick = null;
    await tapOn(tester, 'image-banner-put');
    expect(f.to('/v1/admin/content/images/banner', method: 'PUT'), isEmpty);
  });
}
