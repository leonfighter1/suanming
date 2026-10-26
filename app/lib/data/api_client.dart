import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/models.dart';
import 'token_store.dart';

class ApiException implements Exception {
  const ApiException(this.status, this.title, [this.detail, this.code]);
  final int status;
  final String title;
  final String? detail;

  /// Machine-readable reason, e.g. `captcha_required`, `region`, `age`.
  final String? code;

  bool get isRegionBlocked => status == 451;
  bool get isUnauthorized => status == 401;

  @override
  String toString() => detail ?? title;
}

class AppUser {
  const AppUser({required this.id, this.email, required this.country, required this.signInMethods});
  factory AppUser.fromJson(Json j) => AppUser(
        id: j['id'] as String,
        email: j['email'] as String?,
        country: j['country'] as String,
        signInMethods: (j['sign_in_methods'] as List).cast<String>(),
      );
  final String id;
  final String? email;
  final String country;
  final List<String> signInMethods;
}

/// v1 API client (api/openapi.yaml). Authenticated calls send the access token;
/// on 401 the client refreshes once (single-flight) and retries, and signs out
/// if the refresh fails.
class ApiClient {
  ApiClient({required this.baseUrl, required this.tokens, http.Client? client, this.onSignedOut})
      : _http = client ?? http.Client();

  final String baseUrl;
  final TokenStore tokens;
  final void Function()? onSignedOut;
  final http.Client _http;
  Future<bool>? _refreshing;

  // ---- auth ----

  Future<void> register({
    required String email,
    required String password,
    required String country,
    required String locale,
    required bool ageConfirmed,
  }) =>
      _storeTokens(_send('POST', '/v1/auth/register', {
        'email': email,
        'password': password,
        'country': country,
        'locale': locale,
        'age_confirmed': ageConfirmed,
      }));

  Future<void> login(String email, String password, {String? captchaToken}) =>
      _storeTokens(_send('POST', '/v1/auth/login', {
        'email': email,
        'password': password,
        'captcha_token': ?captchaToken,
      }));

  Future<void> logout() async {
    final t = await tokens.read();
    await tokens.clear();
    if (t != null) {
      try {
        await _send('POST', '/v1/auth/logout', {'refresh_token': t.refresh});
      } on Object {
        // Local sign-out already happened; the server session expires on its own.
      }
    }
  }

  Future<AppUser> me() async => AppUser.fromJson(await _authed('GET', '/v1/me'));

  /// Deletes the account and all its data on the server, then forgets the tokens.
  Future<Json> deleteAccount() async {
    final receipt = await _authed('DELETE', '/v1/account');
    await tokens.clear();
    return receipt;
  }

  // ---- charts & reports ----

  Future<ChartResult> createChart(Map<String, Object?> request) async =>
      ChartResult.fromJson(await _authed('POST', '/v1/charts', request));

  Future<ReportView> createReport({
    required String chartId,
    required String locale,
    List<String>? topics,
    String? question,
  }) async =>
      ReportView.fromJson(await _authed('POST', '/v1/reports', {
        'chart_id': chartId,
        'locale': locale,
        if (topics != null && topics.isNotEmpty) 'topics': topics,
        if (question != null && question.isNotEmpty) 'question': question,
      }));

  Future<ReportView> getReport(String id) async => ReportView.fromJson(await _authed('GET', '/v1/reports/$id'));

  Future<ChartResult> getChart(String id) async => ChartResult.fromJson(await _authed('GET', '/v1/charts/$id'));

  /// The user's readings, newest first.
  Future<List<HistoryItem>> listReports({int limit = 30}) async {
    final j = await _authed('GET', '/v1/reports?limit=$limit');
    return (j['items'] as List).cast<Json>().map(HistoryItem.fromJson).toList();
  }

  static String ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// 農曆 equivalent and the 時辰 (with 干支) of a 公曆 date. Public, no sign-in.
  Future<CalendarDay> calendarDay(DateTime d) async =>
      CalendarDay.fromJson(await _send('GET', '/v1/calendar/lunar?date=${ymd(d)}'));

  /// Months of a 農曆 year, including its leap month.
  Future<List<LunarMonthInfo>> lunarMonths(int year) async {
    final j = await _send('GET', '/v1/calendar/lunar-months?year=$year');
    return (j['months'] as List).cast<Json>().map(LunarMonthInfo.fromJson).toList();
  }

  /// 公曆 date of a 農曆 date.
  Future<DateTime> lunarToSolar(int year, int month, int day, {required bool leap}) async {
    final j = await _send('GET', '/v1/calendar/solar?year=$year&month=$month&day=$day&leap=$leap');
    return DateTime.parse(j['date'] as String);
  }

  // ---- transport ----

  Future<void> _storeTokens(Future<Json> response) async {
    final j = await response;
    await tokens.write(Tokens(j['access_token'] as String, j['refresh_token'] as String));
  }

  Future<Json> _authed(String method, String path, [Object? body]) async {
    final t = await tokens.read();
    if (t == null) throw const ApiException(401, 'Signed out');
    try {
      return await _send(method, path, body, t.access);
    } on ApiException catch (e) {
      if (!e.isUnauthorized) rethrow;
      if (!await (_refreshing ??= _refresh().whenComplete(() => _refreshing = null))) {
        await tokens.clear();
        onSignedOut?.call();
        rethrow;
      }
      return _send(method, path, body, (await tokens.read())!.access);
    }
  }

  Future<bool> _refresh() async {
    final t = await tokens.read();
    if (t == null) return false;
    try {
      await _storeTokens(_send('POST', '/v1/auth/refresh', {'refresh_token': t.refresh}));
      return true;
    } on ApiException {
      return false;
    }
  }

  Future<Json> _send(String method, String path, [Object? body, String? access]) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = {
      'content-type': 'application/json',
      if (access != null) 'authorization': 'Bearer $access',
    };
    final res = switch (method) {
      'GET' => await _http.get(uri, headers: headers),
      'DELETE' => await _http.delete(uri, headers: headers),
      _ => await _http.post(uri, headers: headers, body: jsonEncode(body)),
    };
    final text = utf8.decode(res.bodyBytes);
    if (res.statusCode >= 400) {
      try {
        final p = jsonDecode(text) as Json;
        throw ApiException(res.statusCode, p['title'] as String? ?? 'Error', p['detail'] as String?, p['code'] as String?);
      } on FormatException {
        throw ApiException(res.statusCode, 'HTTP ${res.statusCode}');
      }
    }
    return text.isEmpty ? <String, dynamic>{} : jsonDecode(text) as Json;
  }
}
