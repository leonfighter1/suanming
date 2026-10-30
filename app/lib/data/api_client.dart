import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../domain/document.dart';
import '../domain/inquiry.dart';
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
  const ApiException(this.status, this.title, [this.detail, this.code, this.problem = const {}]);
  final int status;
  final String title;
  final String? detail;

  /// Machine-readable reason, e.g. `captcha_required`, `region`, `age`.
  final String? code;

  /// The whole problem body, for a code's own fields (a 402's `need` and `available`, v11.0.0).
  final Json problem;

  bool get isRegionBlocked => status == 451;
  bool get isUnauthorized => status == 401;

  /// 积分不足 (v11.0.0): the request costs more than the account has available.
  bool get isPointsShort => status == 402 && code == 'points_short';

  @override
  String toString() => detail ?? title;
}

class AppUser {
  const AppUser({
    required this.id,
    this.username,
    this.email,
    this.emailVerified = false,
    this.phone,
    required this.country,
    required this.signInMethods,
    this.role = 'user',
    this.emailReports = false,
    this.staff,
  });
  factory AppUser.fromJson(Json j) => AppUser(
        id: j['id'] as String,
        username: j['username'] as String?,
        email: j['email'] as String?,
        emailVerified: j['email_verified'] as bool? ?? false,
        phone: j['phone'] as String?,
        country: j['country'] as String,
        signInMethods: (j['sign_in_methods'] as List).cast<String>(),
        role: j['role'] as String? ?? 'user',
        emailReports: (j['settings'] as Map?)?['email_reports'] as bool? ?? false,
        staff: j['staff'] as String?,
      );
  final String id;

  /// The three logins (v8.2.0): a username, an email (proved by a code once [emailVerified]), a phone (only once
  /// bound, in E.164).
  final String? username;
  final String? email;
  final bool emailVerified;
  final String? phone;
  final String country;
  final List<String> signInMethods;

  /// 'admin' for 内容审核 reviewers.
  final String role;
  bool get isReviewer => role == 'admin';

  /// 测算完成后发到邮箱 (v8.2.0, WP15.4): 否 by default.
  final bool emailReports;

  /// 后台角色 (tech plan S25): admin, manager or integrator; null for everyone else. The ☰ shows 管理后台 for it.
  final String? staff;

  /// Who is signed in, as the menu header shows it: the username, else the email, else the phone.
  String get login => username ?? email ?? phone ?? '—';
}

/// The account's settings (GET /v1/account/settings, v9.0.0), and what delivers mail on this server: "outbox" while it
/// has no provider (nothing really leaves), "off", or the provider's name.
class AccountSettings {
  const AccountSettings({required this.emailReports, required this.mailDelivery});
  factory AccountSettings.fromJson(Json j) => AccountSettings(
        emailReports: (j['settings'] as Map)['email_reports'] as bool,
        mailDelivery: (j['delivery'] as Map)['mail'] as String,
      );
  final bool emailReports;
  final String mailDelivery;
}

/// Where a code or a mail went (POST /v1/account/{email|phone}, v8.2.0; /v1/documents/email, v9.0.0), masked, and
/// what delivered it: "outbox" while the server has no provider, so nothing really left it.
class CodeSent {
  const CodeSent({required this.sentTo, required this.delivery});
  factory CodeSent.fromJson(Json j) => CodeSent(sentTo: j['sent_to'] as String, delivery: j['delivery'] as String);
  final String sentTo;
  final String delivery;
  bool get outbox => delivery == 'outbox';
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

  /// A new account (v8.2.0): a username, an email, or both.
  Future<void> register({
    String? username,
    String? email,
    required String password,
    required String country,
    required String locale,
    required bool ageConfirmed,
  }) =>
      _storeTokens(_send('POST', '/v1/auth/register', {
        'username': ?username,
        'email': ?email,
        'password': password,
        'country': country,
        'locale': locale,
        'age_confirmed': ageConfirmed,
      }));

  /// [login] is a username, an email or a bound phone (v8.2.0); the server tells them apart.
  Future<void> login(String login, String password, {String? captchaToken}) =>
      _storeTokens(_send('POST', '/v1/auth/login', {
        'login': login,
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

  // ---- the account's logins (v8.2.0, tech plan WP15.3) ----

  Future<AppUser> setUsername(String username) async =>
      AppUser.fromJson(await _authed('PUT', '/v1/account/username', {'username': username}));

  /// Sends a code to an email or a phone ([kind]: 'email' or 'phone'); it counts once [confirmContact] brings it back.
  Future<CodeSent> startContact(String kind, String value) async =>
      CodeSent.fromJson(await _authed('POST', '/v1/account/$kind', {kind: value}));

  Future<AppUser> confirmContact(String kind, String value, String code) async =>
      AppUser.fromJson(await _authed('POST', '/v1/account/$kind/verify', {kind: value, 'code': code}));

  /// Removes the email or unbinds the phone.
  Future<AppUser> removeContact(String kind) async => AppUser.fromJson(await _authed('DELETE', '/v1/account/$kind'));

  /// Deletes the account and all its data on the server, then forgets the tokens.
  Future<Json> deleteAccount() async {
    final receipt = await _authed('DELETE', '/v1/account');
    await tokens.clear();
    return receipt;
  }

  // ---- charts & reports ----

  /// The methods the account's region offers, in its entry order (GET /v1/methods, v4.3.0):
  /// 求籤 first in Taiwan and Hong Kong.
  Future<List<String>> methods() async {
    final j = await _authed('GET', '/v1/methods');
    return [for (final m in j['methods'] as List) (m as Json)['system'] as String];
  }

  Future<ChartResult> createChart(Map<String, Object?> request) async =>
      ChartResult.fromJson(await _authed('POST', '/v1/charts', request));

  /// 算卦 (v6.0.0): 24 coins laid out face down on the server, before the reader picks; their id, to cast
  /// from with mode pick.
  Future<String> liuyaoLayout() async => (await _authed('POST', '/v1/liuyao/layouts', const {}))['draw_id'] as String;

  Future<ReportView> createReport({
    required String chartId,
    required String locale,
    List<String>? topics,
    String? question,
    String? focus,
    Map<String, Object?>? context,
    String? inquiryId,
  }) async =>
      ReportView.fromJson(await _authed('POST', '/v1/reports', {
        'chart_id': chartId,
        'locale': locale,
        if (topics != null && topics.isNotEmpty) 'topics': topics,
        if (question != null && question.isNotEmpty) 'question': question,
        'focus': ?focus,
        'context': ?context,
        'inquiry_id': ?inquiryId,
      }));

  // ---- 深度分析 (v10.0.0) ----

  /// Starts a 深度分析 on a chart: the master's first question comes in the background (202), so poll [getInquiry].
  /// 400 `goal_required` without a clear goal.
  Future<InquiryView> startInquiry({
    required String chartId,
    required String locale,
    required String goal,
    String? question,
    String? focus,
    Map<String, Object?>? context,
  }) async =>
      InquiryView.fromJson(await _authed('POST', '/v1/inquiries', {
        'chart_id': chartId,
        'locale': locale,
        'goal': goal,
        if (question != null && question.isNotEmpty) 'question': question,
        'focus': ?focus,
        'context': ?context,
      }));

  Future<InquiryView> getInquiry(String id) async => InquiryView.fromJson(await _authed('GET', '/v1/inquiries/$id'));

  /// The answer to the master's question; its next turn comes in the background (202).
  Future<InquiryView> answerInquiry(String id, String answer) async =>
      InquiryView.fromJson(await _authed('POST', '/v1/inquiries/$id/answers', {'answer': answer}));

  Future<ReportView> getReport(String id) async => ReportView.fromJson(await _authed('GET', '/v1/reports/$id'));

  /// A passed tarot (v4.2.0) or 求籤 (v4.3.0) reading as a share image, made by the server (JPEG).
  Future<Uint8List> shareImage(String reportId) =>
      _withAccess((access) => _bytes('/v1/reports/$reportId/share.jpg', access));

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

  // ---- 以往记录 (v8.0.0) ----

  /// A record's document as Word or PDF, rendered by the server from [doc] (POST /v1/documents).
  Future<Uint8List> document(Doc doc, DocFormat format, {required String fileName, required String locale}) =>
      _withAccess(
        (access) => _postBytes('/v1/documents', {
          'format': format.ext,
          'filename': fileName,
          'locale': locale,
          'document': doc.toJson(),
        }, access),
      );

  /// 发到邮箱 (v9.0.0): [docs] (each with its file name) in [format], in one mail to the account's verified email.
  Future<CodeSent> emailDocuments(List<(Doc, String)> docs, DocFormat format, {required String locale}) async =>
      CodeSent.fromJson(await _authed('POST', '/v1/documents/email', {
        'format': format.ext,
        'locale': locale,
        'documents': [
          for (final (doc, name) in docs) {'filename': name, 'document': doc.toJson()},
        ],
      }));

  /// 测算完成后发到邮箱 and what delivers mail here (v9.0.0).
  Future<AccountSettings> settings() async => AccountSettings.fromJson(await _authed('GET', '/v1/account/settings'));

  Future<AccountSettings> setEmailReports(bool on) async =>
      AccountSettings.fromJson(await _authed('PATCH', '/v1/account/settings', {'email_reports': on}));

  /// Deletes one reading with its plans and 追问 (and its chart when nothing else reads it).
  Future<Json> deleteReport(String id) => _authed('DELETE', '/v1/reports/$id');

  /// Deletes one 一生运势报告 with its 追问.
  Future<Json> deleteLifeReport(String id) => _authed('DELETE', '/v1/life-reports/$id');

  /// 归类到…: files a chart's records under [name]; an empty name clears it. A birth chart keeps its birthplace.
  Future<ChartPerson?> setChartPerson(String chartId, String name) async =>
      ChartPerson.fromJson((await _authed('POST', '/v1/charts/$chartId/person', {'name': name}))['person']);

  // ---- 追问 (v7.0.0) ----

  /// A reading's 追问, oldest first: [parent] is `reports/<id>` or `life-reports/<id>`.
  Future<FollowUpList> listFollowUps(String parent) async =>
      FollowUpList.fromJson(await _authed('GET', '/v1/$parent/followups'));

  /// Asks one more: answered in the background (202), so poll [listFollowUps].
  Future<FollowUpView> askFollowUp(String parent, String question) async =>
      FollowUpView.fromJson(await _authed('POST', '/v1/$parent/followups', {'question': question}));

  // ---- 积分 (v11.0.0) ----

  /// The balance, what running requests hold, the 充值 packs and the latest changes; `enabled: false` when the
  /// server has 积分 off.
  Future<PointsView> points() async => PointsView.fromJson(await _authed('GET', '/v1/points'));

  /// 充值 one pack by its price in 元 (simulated in development: no payment).
  Future<void> topUp(int yuan) => _authed('POST', '/v1/points/top-ups', {'yuan': yuan});

  /// What each AI request on a chart costs now; [topics] the reading would be asked for (default all).
  Future<ChartQuote> chartQuote(String chartId, {List<String>? topics}) async => ChartQuote.fromJson(
        await _authed('GET', '/v1/charts/$chartId/quote${topics == null ? '' : '?topics=${topics.join(',')}'}'),
      );

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

  Future<Json> _authed(String method, String path, [Object? body]) =>
      _withAccess((access) => _send(method, path, body, access));

  /// Runs [call] with the access token, refreshing it once if the server says it has expired.
  Future<T> _withAccess<T>(Future<T> Function(String access) call) async {
    final t = await tokens.read();
    if (t == null) throw const ApiException(401, 'Signed out');
    try {
      return await call(t.access);
    } on ApiException catch (e) {
      // 管理后台 (v11.2.0): a suspended account is signed out here, and the sign-in page says why.
      if (e.code == 'account_suspended') {
        await tokens.clear();
        onSignedOut?.call();
        rethrow;
      }
      if (!e.isUnauthorized) rethrow;
      if (!await (_refreshing ??= _refresh().whenComplete(() => _refreshing = null))) {
        await tokens.clear();
        onSignedOut?.call();
        rethrow;
      }
      return call((await tokens.read())!.access);
    }
  }

  /// A file the server makes (an image): its bytes, or the server's problem as an [ApiException].
  Future<Uint8List> _bytes(String path, String access) async {
    final http.Response res;
    try {
      res = await _http.get(Uri.parse('$baseUrl$path'), headers: {'authorization': 'Bearer $access'});
    } on http.ClientException catch (e) {
      throw ApiUnreachable(baseUrl, e.message);
    }
    if (res.statusCode >= 400) throw _problem(res);
    return res.bodyBytes;
  }

  /// A file the server makes from a request body (a document): its bytes, or the server's problem.
  Future<Uint8List> _postBytes(String path, Object body, String access) async {
    final http.Response res;
    try {
      res = await _http.post(
        Uri.parse('$baseUrl$path'),
        headers: {'content-type': 'application/json', 'authorization': 'Bearer $access'},
        body: jsonEncode(body),
      );
    } on http.ClientException catch (e) {
      throw ApiUnreachable(baseUrl, e.message);
    }
    if (res.statusCode >= 400) throw _problem(res);
    return res.bodyBytes;
  }

  /// The RFC 7807 problem in an error response.
  ApiException _problem(http.Response res) {
    try {
      final p = jsonDecode(utf8.decode(res.bodyBytes)) as Json;
      return ApiException(res.statusCode, p['title'] as String? ?? 'Error', p['detail'] as String?, p['code'] as String?, p);
    } on FormatException {
      return ApiException(res.statusCode, 'HTTP ${res.statusCode}');
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
        'PUT' => await _http.put(uri, headers: headers, body: jsonEncode(body)),
        'PATCH' => await _http.patch(uri, headers: headers, body: jsonEncode(body)),
        _ => await _http.post(uri, headers: headers, body: jsonEncode(body)),
      };
    } on http.ClientException catch (e) {
      // No HTTP response at all: wrong host (127.0.0.1 on a phone), server down,
      // firewall, CORS refusal or an https page calling an http API.
      throw ApiUnreachable(baseUrl, e.message);
    }
    if (res.statusCode >= 400) throw _problem(res);
    final text = utf8.decode(res.bodyBytes);
    return text.isEmpty ? <String, dynamic>{} : jsonDecode(text) as Json;
  }
}
