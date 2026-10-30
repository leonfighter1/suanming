import 'package:flutter/material.dart';

import '../data/admin_api.dart';

/// What went wrong, in plain words (管理后台, tech plan S22; the roles and 消息, S25).
String problemText(Object e) => switch (e) {
      AdminApiException(code: 'admin_only') => '这个账号没有后台权限',
      AdminApiException(code: 'not_allowed') => '你的角色不能做这件事',
      AdminApiException(code: 'account_suspended') => '这个账号已被停用',
      AdminApiException(code: 'admin_self') => '不能停用自己，也不能改自己的角色',
      AdminApiException(code: 'admin_by_config') => '这位管理员由服务器设置（MINGLI_ADMINS）指定，不能在这里取消',
      AdminApiException(code: 'invalid_template', :final problems) when problems.isNotEmpty => problems.join('；'),
      AdminApiException(code: 'delivery_unavailable') => '这台服务器没有发送方式，发不出去',
      AdminApiException(code: 'delivery_failed') => '发送失败：服务器没能交出这条消息',
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
