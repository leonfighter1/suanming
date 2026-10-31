import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../generated/content_l10n.dart';
import '../l10n/gen/app_localizations.dart';

/// 内容管理 (S29): the app's messages with what staff changed in front ([ContentLocalizations]). A new one each time the
/// changes come, so the words on screen follow them; the app's own load as they always did, at once.
class ContentDelegate extends LocalizationsDelegate<AppLocalizations> {
  const ContentDelegate(this.texts);
  final Map<String, String> texts;

  @override
  bool isSupported(Locale locale) => AppLocalizations.delegate.isSupported(locale);

  @override
  Future<AppLocalizations> load(Locale locale) =>
      AppLocalizations.delegate.load(locale).then((own) => ContentLocalizations(own, texts));

  @override
  bool shouldReload(ContentDelegate old) => !mapEquals(old.texts, texts);
}

/// The images staff put in (S29), by key, at their full addresses; above every page (app.dart). [imageOf] is the
/// image to show for a key, or null for the app's own.
class ContentScope extends InheritedWidget {
  const ContentScope({super.key, required this.images, required super.child});
  final Map<String, String> images;

  static ImageProvider? imageOf(BuildContext context, String key) {
    final url = context.dependOnInheritedWidgetOfExactType<ContentScope>()?.images[key];
    return url == null ? null : NetworkImage(url);
  }

  @override
  bool updateShouldNotify(ContentScope old) => !mapEquals(old.images, images);
}
