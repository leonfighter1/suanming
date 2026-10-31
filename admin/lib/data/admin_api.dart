import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../domain/models.dart';

/// The server said no: its status, its title and the code it named (admin_only, admin_self, …), and for a wording
/// it can't keep (invalid_template) what is wrong with it.
class AdminApiException implements Exception {
  const AdminApiException(this.status, this.title, [this.code, this.problems = const []]);
  final int status;
  final String title;
  final String? code;
  final List<String> problems;

  @override
  String toString() => title;
}

/// The server could not be reached at all.
class AdminUnreachable implements Exception {
  const AdminUnreachable(this.baseUrl);
  final String baseUrl;

  @override
  String toString() => '连不上服务器：$baseUrl';
}

/// A file the API made (its bytes, the name it gave it and its type), or one chosen to send it (内容管理's images).
class AdminFile {
  const AdminFile(this.bytes, this.name, this.mime);
  final Uint8List bytes;
  final String name;
  final String mime;
}

/// The admin API (/v1/admin/*, api/openapi.yaml tag admin). The session lives in this tab (S33: its refresh token in
/// the tab's storage, through [onSession]): a reload keeps it, closing the tab signs the admin out. An expired access
/// token is refreshed once; a refresh that fails signs out.
class AdminApi {
  AdminApi({required this.baseUrl, http.Client? client}) : _http = client ?? http.Client();

  final String baseUrl;
  final http.Client _http;
  String? _access;
  String? _refresh;

  /// Told when the session is gone (a failed refresh, the account suspended or no longer staff).
  void Function()? onSignedOut;

  /// Told when the server refused something to the caller's role (403 not_allowed): the role may have changed since
  /// signing in, so the dashboard asks again what it may show.
  void Function()? onNotAllowed;

  /// Told when the session's refresh token changes (signed in, refreshed), null when the session ends (S33).
  void Function(String? refresh)? onSession;

  /// Signs in, then checks the account has a staff role (403 admin_only otherwise, and the session is dropped).
  Future<AdminMe> signIn(String login, String password) =>
      _signedIn(_send('POST', '/v1/auth/login', body: {'login': login, 'password': password}));

  /// Signs in with the one-time code the app's ☰ → 管理后台 handed over (S33): a session of the dashboard's own.
  Future<AdminMe> signInWithCode(String code) => _signedIn(_send('POST', '/v1/auth/handoff', body: {'code': code}));

  /// This tab's session again after a reload (S33): its refresh token rotated, then checked as a sign-in is.
  Future<AdminMe> resume(String refresh) =>
      _signedIn(_send('POST', '/v1/auth/refresh', body: {'refresh_token': refresh}));

  Future<AdminMe> _signedIn(Future<Json> tokens) async {
    final t = await tokens;
    _access = t['access_token'] as String;
    _refresh = t['refresh_token'] as String;
    onSession?.call(_refresh);
    try {
      return await me();
    } catch (_) {
      signOut();
      rethrow;
    }
  }

  void signOut() {
    final refresh = _refresh;
    _access = null;
    _refresh = null;
    onSession?.call(null);
    if (refresh != null) {
      // The server's session ends too; signed out here either way.
      _send('POST', '/v1/auth/logout', body: {'refresh_token': refresh}).ignore();
    }
  }

  Future<AdminMe> me() async => AdminMe.fromJson(await _authed('GET', '/v1/admin/me'));

  Future<Overview> overview(int days) async => Overview.fromJson(await _authed('GET', '/v1/admin/overview?days=$days'));

  Future<List<DayRow>> series(int days) async => [
        for (final d in (await _authed('GET', '/v1/admin/series?days=$days'))['items'] as List) DayRow.fromJson(d as Json),
      ];

  Future<Breakdown> breakdown(int days) async => Breakdown.fromJson(await _authed('GET', '/v1/admin/breakdown?days=$days'));

  Future<UserPage> users(UserQuery q) async => UserPage.fromJson(await _authed('GET', '/v1/admin/users?${q.query}'));

  Future<UserDetail> user(String id) async => UserDetail.fromJson(await _authed('GET', '/v1/admin/users/$id'));

  /// Status, role or permissions: `{'status': 'suspended'}`, `{'role': 'admin'}`, `{'permissions': {'ai': false}}`.
  Future<AdminUser> updateUser(String id, Map<String, Object?> change) async =>
      AdminUser.fromJson(await _authed('PATCH', '/v1/admin/users/$id', change));

  /// 增加积分: the account's balance after it.
  Future<int> grant(String id, int points, {String? note}) async {
    final j = await _authed('POST', '/v1/admin/users/$id/points', {
      'points': points,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
    return (j['balance'] as num).toInt();
  }

  Future<void> signOutEverywhere(String id) => _authed('POST', '/v1/admin/users/$id/sign-out', const <String, Object?>{});

  Future<Active> active() async => Active.fromJson(await _authed('GET', '/v1/admin/active'));

  /// An export: the revenue curve or the accounts as CSV ([kind] series | users), the report as pdf or docx.
  Future<AdminFile> report({required int days, required String format, String kind = 'series'}) =>
      _withAccess(() => _file('/v1/admin/reports?days=$days&format=$format&kind=$kind'));

  // ---- 消息 (tech plan S25) ----

  Future<MessageListing> messages() async => MessageListing.fromJson(await _authed('GET', '/v1/admin/messages/templates'));

  /// Keeps [body] (and a mail's [subject]) as the message's wording in [locale]; the wording now in use.
  Future<TemplateWording> saveTemplate(String kind, String locale, {String? subject, required String body}) async =>
      TemplateWording.fromJson(
        await _authed('PUT', '/v1/admin/messages/templates/$kind/$locale', {'subject': ?subject, 'body': body}),
      );

  /// The message back to its default wording in [locale].
  Future<TemplateWording> resetTemplate(String kind, String locale) async =>
      TemplateWording.fromJson(await _authed('DELETE', '/v1/admin/messages/templates/$kind/$locale'));

  /// A draft with the sample values, the page [scheme] light or dark (the dashboard's).
  Future<MessagePreview> preview(String kind, String locale, {String? subject, required String body, String? scheme}) async =>
      MessagePreview.fromJson(await _authed('POST', '/v1/admin/messages/preview', {
        'kind': kind,
        'locale': locale,
        'subject': ?subject,
        'body': body,
        'scheme': ?scheme,
      }));

  /// A test send with the sample values to [to]: the draft ([body], [subject]) or, without them, the saved wording.
  Future<DispatchEntry> testSend(String kind, String locale, String to, {String? subject, String? body}) async {
    final j = await _authed('POST', '/v1/admin/messages/test', {
      'kind': kind,
      'locale': locale,
      'to': to,
      'subject': ?subject,
      'body': ?body,
    });
    return DispatchEntry.fromJson(j['entry'] as Json);
  }

  /// The latest dispatches, the newest first.
  Future<List<DispatchEntry>> dispatchLog({int limit = 50}) async => [
        for (final e in (await _authed('GET', '/v1/admin/messages/log?limit=$limit'))['items'] as List)
          DispatchEntry.fromJson(e as Json),
      ];

  // ---- 内容 (内容管理, tech plan S29) ----

  Future<ContentListing> content() async => ContentListing.fromJson(await _authed('GET', '/v1/admin/content'));

  /// Keeps [text] as the app's text [key] in [locale]; refused (placeholders_mismatch) when it drops or adds one of
  /// the text's placeholders.
  Future<void> saveText(String key, String locale, String text) =>
      _authed('PUT', '/v1/admin/content/texts/$key/$locale', {'text': text});

  /// The text back to the app's own in [locale].
  Future<void> resetText(String key, String locale) => _authed('DELETE', '/v1/admin/content/texts/$key/$locale');

  /// [file] put in as the image [key]: the app shows it from then on.
  Future<void> putImage(String key, AdminFile file) => _authed('PUT', '/v1/admin/content/images/$key', file);

  /// The image [key] taken out: the app shows its own again.
  Future<void> removeImage(String key) => _authed('DELETE', '/v1/admin/content/images/$key');

  // ---- 设置 (tech plan S31) ----

  Future<SettingsListing> settings() async => SettingsListing.fromJson(await _authed('GET', '/v1/admin/settings'));

  /// Keeps [value] as [key]'s; refused (invalid_setting) with what is wrong when it doesn't fit.
  Future<SettingView> saveSetting(String key, Object? value) async =>
      SettingView.fromJson(await _authed('PUT', '/v1/admin/settings/$key', {'value': value}));

  /// [key] back to its default.
  Future<SettingView> resetSetting(String key) async =>
      SettingView.fromJson(await _authed('DELETE', '/v1/admin/settings/$key'));

  // ---- transport ----

  Future<Json> _authed(String method, String path, [Object? body]) =>
      _withAccess(() => _send(method, path, body: body, auth: true));

  Future<T> _withAccess<T>(Future<T> Function() call) async {
    final used = _access;
    if (used == null) throw const AdminApiException(401, '请先登录');
    try {
      return await call();
    } on AdminApiException catch (e) {
      // Suspended, or no longer staff: the session is over.
      if (e.code == 'account_suspended' || e.code == 'admin_only') {
        _ended();
        rethrow;
      }
      if (e.code == 'not_allowed') {
        onNotAllowed?.call();
        rethrow;
      }
      if (e.status != 401) rethrow;
      // A page asks for several things at once: one of them may have refreshed the session already.
      if (_access == used && !await _refreshed()) {
        _ended();
        rethrow;
      }
      if (_access == null) rethrow;
      return call();
    }
  }

  /// The session is over, here and on the server: told once, however many requests find out.
  void _ended() {
    if (_access == null && _refresh == null) return;
    signOut();
    onSignedOut?.call();
  }

  Future<bool>? _refreshing;

  /// One refresh for every request that met the expired token (the server rotates the refresh token, so a second
  /// refresh with the same one would fail).
  Future<bool> _refreshed() => _refreshing ??= _refreshOnce().whenComplete(() => _refreshing = null);

  Future<bool> _refreshOnce() async {
    final refresh = _refresh;
    if (refresh == null) return false;
    try {
      final t = await _send('POST', '/v1/auth/refresh', body: {'refresh_token': refresh});
      _access = t['access_token'] as String;
      _refresh = t['refresh_token'] as String;
      onSession?.call(_refresh);
      return true;
    } on Object {
      return false;
    }
  }

  Map<String, String> _headers(bool auth) => {
        'content-type': 'application/json',
        if (auth && _access != null) 'authorization': 'Bearer $_access',
      };

  Future<Json> _send(String method, String path, {Object? body, bool auth = false}) async {
    final uri = Uri.parse('$baseUrl$path');
    final http.Response res;
    try {
      res = switch (method) {
        'GET' => await _http.get(uri, headers: _headers(auth)),
        'PATCH' => await _http.patch(uri, headers: _headers(auth), body: jsonEncode(body)),
        // A picture (内容管理) goes as it is, under its own type.
        'PUT' when body is AdminFile =>
          await _http.put(uri, headers: {..._headers(auth), 'content-type': body.mime}, body: body.bytes),
        'PUT' => await _http.put(uri, headers: _headers(auth), body: jsonEncode(body)),
        'DELETE' => await _http.delete(uri, headers: _headers(auth)),
        _ => await _http.post(uri, headers: _headers(auth), body: jsonEncode(body)),
      };
    } on http.ClientException {
      throw AdminUnreachable(baseUrl);
    }
    if (res.statusCode >= 400) throw _problem(res);
    final text = utf8.decode(res.bodyBytes);
    return text.isEmpty ? <String, dynamic>{} : jsonDecode(text) as Json;
  }

  Future<AdminFile> _file(String path) async {
    final http.Response res;
    try {
      res = await _http.get(Uri.parse('$baseUrl$path'), headers: _headers(true));
    } on http.ClientException {
      throw AdminUnreachable(baseUrl);
    }
    if (res.statusCode >= 400) throw _problem(res);
    return AdminFile(res.bodyBytes, fileName(res.headers['content-disposition']) ?? 'export', res.headers['content-type'] ?? 'application/octet-stream');
  }

  static AdminApiException _problem(http.Response res) {
    try {
      final p = jsonDecode(utf8.decode(res.bodyBytes)) as Json;
      return AdminApiException(
        res.statusCode,
        p['title'] as String? ?? 'HTTP ${res.statusCode}',
        p['code'] as String?,
        [for (final x in (p['problems'] as List? ?? const [])) '$x'],
      );
    } on FormatException {
      return AdminApiException(res.statusCode, 'HTTP ${res.statusCode}');
    }
  }
}

/// The file name a Content-Disposition gives: its UTF-8 name (RFC 5987) before its ASCII fallback.
String? fileName(String? disposition) {
  if (disposition == null) return null;
  final utf = RegExp(r"filename\*=UTF-8''([^;]+)", caseSensitive: false).firstMatch(disposition);
  if (utf != null) return Uri.decodeComponent(utf.group(1)!.trim());
  return RegExp(r'filename="([^"]+)"').firstMatch(disposition)?.group(1);
}
