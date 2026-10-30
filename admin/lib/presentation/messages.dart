import 'package:flutter/material.dart';

import '../data/admin_api.dart';

/// What went wrong, in plain words (管理后台, tech plan S22).
String problemText(Object e) => switch (e) {
      AdminApiException(code: 'admin_only') => '这个账号不是管理员',
      AdminApiException(code: 'account_suspended') => '这个账号已被停用',
      AdminApiException(code: 'admin_self') => '不能停用自己，也不能取消自己的管理员',
      AdminApiException(code: 'admin_by_config') => '这位管理员由服务器设置（MINGLI_ADMINS）指定，不能在这里取消',
      AdminApiException(status: 401) => '账号或密码不正确',
      AdminApiException(status: 503) => '服务器上没有中文字体，做不了 PDF：先导出 Word',
      AdminApiException(:final title) => title,
      _ => '$e',
    };

/// A short message at the bottom; the one showing goes first (MISTAKES rule 57).
void say(BuildContext context, String text) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(content: Text(text)));
}
