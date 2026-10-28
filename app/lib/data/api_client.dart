import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/life_report.dart';
import '../domain/models.dart';
import '../domain/places.dart';
import 'token_store.dart';

/// The API could not be reached at all (no HTTP response).
class ApiUnreachable implements Exception {
  const ApiUnreachable(this.baseUrl, this.message);
  final String baseUrl;
  final String message;

  @override
  String toString() => 'API unreachable at $baseUrl: $message';
}

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
  const AppUser({required this.id, this.email, required this.country, required this.signInMethods, this.role = 'user'});
  factory AppUser.fromJson(Json j) => AppUser(
        id: j['id'] as String,
        email: j['email'] as String?,
        country: j['country'] as String,
        signInMethods: (j['sign_in_methods'] as List).cast<String>(),
        role: j['role'] as String? ?? 'user',
      );
  final String id;
  final String? email;
  final String country;
  final List<String> signInMethods;

  /// 'admin' for 内容审核 reviewers.
  final String role;
  bool get isReviewer => role == 'admin';
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
    String? focus,
    Map<String, Object?>? context,
  }) async =>
      ReportView.fromJson(await _authed('POST', '/v1/reports', {
        'chart_id': chartId,
        'locale': locale,
        if (topics != null && topics.isNotEmpty) 'topics': topics,
        if (question != null && question.isNotEmpty) 'question': question,
        'focus': ?focus,
        'context': ?context,
      }));

  Future<ReportView> getReport(String id) async => ReportView.fromJson(await _authed('GET', '/v1/reports/$id'));

  Future<ChartResult> getChart(String id) async => ChartResult.fromJson(await _authed('GET', '/v1/charts/$id'));

  // ---- 内容审核 (reviewers only) ----

  Future<List<Json>> listReviews() async => ((await _authed('GET', '/v1/admin/reviews'))['items'] as List).cast<Json>();

  Future<Json> getReview(String kind, String id) => _authed('GET', '/v1/admin/reviews/$kind/$id');

  /// 每日一牌 for [date] (YYYY-MM-DD, the device's date): the same card all day.
  Future<ChartResult> dailyCard(String date) async =>
      ChartResult.fromJson(await _authed('GET', '/v1/tarot/daily?date=$date'));

  Future<Json> decideReview(String kind, String id, {required bool approve, String? note}) =>
      _authed('POST', '/v1/admin/reviews/$kind/$id', {'decision': approve ? 'approve' : 'reject', if (note != null && note.trim().isNotEmpty) 'note': note.trim()});

  // ---- 一生运势报告 ----

  Future<LifeReportView> createLifeReport({required String chartId, required String locale, Map<String, Object?>? context}) async =>
      LifeReportView.fromJson(await _authed('POST', '/v1/life-reports', {'chart_id': chartId, 'locale': locale, 'context': ?context}));

  Future<LifeReportView> getLifeReport(String id) async => LifeReportView.fromJson(await _authed('GET', '/v1/life-reports/$id'));

  Future<List<LifeReportView>> listLifeReports() async {
    final j = await _authed('GET', '/v1/life-reports');
    return (j['items'] as List).cast<Json>().map(LifeReportView.fromJson).toList();
  }

  // ---- birthplaces (public) ----

  Future<List<PlaceCountryInfo>> placeCountries() async {
    final j = await _send('GET', '/v1/places');
    return (j['countries'] as List).cast<Json>().map(PlaceCountryInfo.fromJson).toList();
  }

  Future<List<PlaceRegion>> placeRegions(String country) async {
    final j = await _send('GET', '/v1/places/$country');
    return (j['regions'] as List).cast<Json>().map(PlaceRegion.fromJson).toList();
  }

  // ---- 破除運勢 plans (paid per topic) ----

  Future<RemedyList> listRemedies(String reportId) async =>
      RemedyList.fromJson(await _authed('GET', '/v1/reports/$reportId/remedies'));

  /// Buys the plan for one topic. TODO(Phase 4 payments): pass the store receipt;
  /// until then the server records a placeholder charge.
  Future<RemedyView> buyRemedy(String reportId, String topic) async =>
      RemedyView.fromJson(await _authed('POST', '/v1/reports/$reportId/remedies', {'topic': topic}));

  Future<RemedyView> getRemedy(String id) async => RemedyView.fromJson(await _authed('GET', '/v1/remedies/$id'));

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
    final http.Response res;
    try {
      res = switch (method) {
        'GET' => await _http.get(uri, headers: headers),
        'DELETE' => await _http.delete(uri, headers: headers),
        _ => await _http.post(uri, headers: headers, body: jsonEncode(body)),
      };
    } on http.ClientException catch (e) {
      // No HTTP response at all: wrong host (127.0.0.1 on a phone), server down,
      // firewall, CORS refusal or an https page calling an http API.
      throw ApiUnreachable(baseUrl, e.message);
    }
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
