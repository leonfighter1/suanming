import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../domain/models.dart';

/// The server said no: its status, its title and the code it named (admin_only, admin_self, …).
class AdminApiException implements Exception {
  const AdminApiException(this.status, this.title, [this.code]);
  final int status;
  final String title;
  final String? code;

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

/// A file the API made: its bytes, the name it gave it and its type.
class AdminFile {
  const AdminFile(this.bytes, this.name, this.mime);
  final Uint8List bytes;
  final String name;
  final String mime;
}

/// The admin API (/v1/admin/*, api/openapi.yaml tag admin). The session lives in memory only: closing the tab signs
/// the admin out. An expired access token is refreshed once; a refresh that fails signs out.
class AdminApi {
  AdminApi({required this.baseUrl, http.Client? client}) : _http = client ?? http.Client();

  final String baseUrl;
  final http.Client _http;
  String? _access;
  String? _refresh;

  /// Told when the session is gone (a failed refresh, the account suspended or no longer an admin).
  void Function()? onSignedOut;

  /// Signs in, then checks the account is an admin (403 admin_only otherwise, and the session is dropped).
  Future<AdminMe> signIn(String login, String password) async {
    final t = await _send('POST', '/v1/auth/login', body: {'login': login, 'password': password});
    _access = t['access_token'] as String;
    _refresh = t['refresh_token'] as String;
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

  // ---- transport ----

  Future<Json> _authed(String method, String path, [Object? body]) =>
      _withAccess(() => _send(method, path, body: body, auth: true));

  Future<T> _withAccess<T>(Future<T> Function() call) async {
    final used = _access;
    if (used == null) throw const AdminApiException(401, '请先登录');
    try {
      return await call();
    } on AdminApiException catch (e) {
      // Suspended, or no longer an admin: the session is over.
      if (e.code == 'account_suspended' || e.code == 'admin_only') {
        _ended();
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
      return AdminApiException(res.statusCode, p['title'] as String? ?? 'HTTP ${res.statusCode}', p['code'] as String?);
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
