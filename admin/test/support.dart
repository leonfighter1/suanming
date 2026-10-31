import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mingli_admin/app.dart';
import 'package:mingli_admin/application/providers.dart';
import 'package:mingli_admin/data/admin_api.dart';
import 'package:mingli_app/generated/content_rich.dart' show richTags;

/// The dashboard's tests: a fake admin API (the server's shapes, api/openapi.yaml tag admin) behind a MockClient, a
/// fixed "now", and the saved exports kept instead of downloaded.

typedef Json = Map<String, dynamic>;

final testNow = DateTime.utc(2026, 10, 29, 12);
const wide = Size(1280, 900);
const phone = Size(360, 740);

String _iso(DateTime t) => t.toUtc().toIso8601String();

Json _user(
  String id,
  String login, {
  String role = 'user',
  bool byConfig = false,
  String status = 'active',
  bool ai = true,
  bool topUp = true,
  bool demo = true,
  int balance = 1000,
  double topup = 0,
  int used = 0,
  int jobs = 0,
  Duration? seen,
  int createdDaysAgo = 30,
}) =>
    {
      'id': id,
      'login': login,
      'country': 'CN',
      'role': role,
      'admin_by_config': byConfig,
      'status': status,
      'permissions': {'ai': ai, 'top_up': topUp},
      'demo': demo,
      'created_at': _iso(testNow.subtract(Duration(days: createdDaysAgo))),
      if (seen != null) 'last_seen_at': _iso(testNow.subtract(seen)),
      'balance': balance,
      'held': 0,
      'topup_cny': topup,
      'points_used': used,
      'jobs': jobs,
      'tokens': jobs * 9000,
      'cost_cny': jobs * 2.5,
    };

class FakeAdmin {
  FakeAdmin() {
    users.addAll([
      _user('admin-1', 'boss', role: 'admin', demo: false, seen: const Duration(minutes: 1), createdDaysAgo: 90),
      _user('root-1', 'root', role: 'admin', byConfig: true, demo: false, createdDaysAgo: 89),
      for (var i = 1; i <= 28; i++)
        _user(
          'u-${'$i'.padLeft(2, '0')}',
          'user${'$i'.padLeft(2, '0')}',
          status: i == 3 ? 'suspended' : 'active',
          ai: i != 5,
          demo: i > 2,
          balance: i * 100,
          topup: (i % 4) * 10.0,
          used: i * 50,
          jobs: i,
          seen: i <= 2 ? Duration(minutes: 3 * i) : (i <= 6 ? Duration(hours: i) : null),
          createdDaysAgo: i,
        ),
    ]);
  }

  final requests = <http.Request>[];
  final users = <Json>[];
  final saved = <AdminFile>[];

  /// Who signs in, and how the server answers.
  String password = 'secret1';
  bool admin = true;
  bool suspended = false;

  /// The next admin call answers 401 once (an expired access token); [refreshFails] makes the refresh fail too.
  bool expireOnce = false;
  bool refreshFails = false;

  /// The next admin call answers 403 admin_only (the role taken away mid-session).
  bool revokeNext = false;

  /// The signed-in staff member's role (tech plan S25): admin (boss, admin-1), manager (mgr, mgr-1) or integrator
  /// (integ, int-1); the last two aren't in the account list. Changing it mid-session is a role changed by another
  /// admin: the server answers by it from then on, as the real one does.
  String role = 'admin';

  /// No way to send messages on this server (a test send answers 503 delivery_unavailable).
  bool deliveryOff = false;

  /// An admin's wordings, by kind/locale: {subject?, body, updated_at}.
  final custom = <String, Json>{};

  /// 内容管理 (S29): staff's texts, by key/locale ({text, updated_at}), and images, by key ({type, bytes, updated_at}).
  final contentTexts = <String, Json>{};
  final contentImages = <String, Json>{};

  /// The file 上传 is given (null: the chooser closed without one), and the types it was asked for.
  AdminFile? pick;
  List<String>? pickTypes;

  /// 设置 (S31): what the panel changed, by key; what answers AI calls; the rates' day (null: none yet).
  final settingValues = <String, Object?>{};
  String aiServing = 'mock';
  String? ratesDate = '2026-10-29';

  /// The dispatch log, the oldest first.
  final log = <Json>[];

  /// The report formats that answer 503 (no Chinese font for a PDF).
  final failFormats = <String>{};

  /// The paths that answer 500 for now.
  final failPaths = <String>{};

  String _access = 'a1';

  late final http.Client client = MockClient(_handle);

  // ---- what tests ask ----

  List<http.Request> to(String path, {String method = 'GET'}) =>
      [for (final r in requests) if (r.method == method && r.url.path == path) r];

  http.Request last(String path, {String method = 'GET'}) => to(path, method: method).last;

  Json bodyOf(http.Request r) => jsonDecode(r.body) as Json;

  Json userById(String id) => users.firstWhere((u) => u['id'] == id);

  // ---- the server ----

  http.Response _json(Object body, [int status = 200]) => http.Response.bytes(
        utf8.encode(jsonEncode(body)),
        status,
        headers: {'content-type': 'application/json'},
      );

  http.Response _problem(int status, String title, [String? code]) =>
      _json({'title': title, 'status': status, 'code': ?code}, status);

  Future<http.Response> _handle(http.Request r) async {
    requests.add(r);
    final path = r.url.path;
    final q = r.url.queryParameters;
    switch (path) {
      case '/v1/auth/login':
        final b = bodyOf(r);
        if (b['password'] != password) return _problem(401, 'invalid credentials');
        if (suspended) return _problem(403, 'this account is suspended', 'account_suspended');
        _access = 'a1';
        return _json({'access_token': 'a1', 'refresh_token': 'r1'});
      case '/v1/auth/refresh':
        if (refreshFails) return _problem(401, 'invalid refresh token');
        _access = 'a2';
        return _json({'access_token': 'a2', 'refresh_token': 'r2'});
      // ☰ → 管理后台's one-time code (S33), as src/auth/service.ts redeemHandoff takes it: 'h-ok' is a fresh one.
      case '/v1/auth/handoff':
        if (bodyOf(r)['code'] != 'h-ok') return _problem(401, 'the link has expired or was used; sign in', 'handoff_invalid');
        _access = 'a1';
        return _json({'access_token': 'a1', 'refresh_token': 'r1'});
      case '/v1/auth/logout':
        return http.Response('', 204);
    }
    if (!path.startsWith('/v1/admin/')) return _problem(404, 'not found');
    if (r.headers['authorization'] != 'Bearer $_access') return _problem(401, 'unauthorized');
    if (expireOnce) {
      expireOnce = false;
      _access = 'expired';
      return _problem(401, 'token expired');
    }
    if (!admin || revokeNext) {
      revokeNext = false;
      return _problem(403, 'admins only', 'admin_only');
    }
    if (failPaths.contains(path)) return _problem(500, '服务器出错了');
    final days = int.tryParse(q['days'] ?? '') ?? 30;
    if (path == '/v1/admin/me') {
      final (id, login) = switch (role) {
        'manager' => ('mgr-1', 'mgr'),
        'integrator' => ('int-1', 'integ'),
        _ => ('admin-1', 'boss'),
      };
      return _json({
        'id': id,
        'login': login,
        'role': role,
        'admin_by_config': false,
        'can': capabilities[role],
        'assignable_roles': assignable[role],
        // The dashboard's currency (设置, S31) at a test rate.
        if (settingValues['currencies.dashboard'] == 'HKD')
          'currency': {'code': 'HKD', 'symbol': 'HK\$', 'decimals': 2, 'rate': 1.1, 'rates_date': '2026-10-29'},
        // 增加积分's most (设置, S32).
        'grant_max': settingValues['limits.grant_max'] ?? 1000000,
      });
    }
    // Every route asks for its capability, as the server's capabilityOf does.
    final needs = path.startsWith('/v1/admin/settings')
        ? 'settings'
        : path.startsWith('/v1/admin/content')
        ? 'content'
        : path.startsWith('/v1/admin/messages/')
        ? 'messages'
        : path == '/v1/admin/reports' || RegExp(r'^/v1/admin/users/[^/]+/(points|sign-out)$').hasMatch(path)
            ? 'user_data'
            : RegExp(r'^/v1/admin/users/[^/]+$').hasMatch(path) && r.method == 'PATCH'
                ? 'assign'
                : 'view';
    if (!capabilities[role]!.contains(needs)) return _problem(403, 'the $role role may not do this', 'not_allowed');
    if (path.startsWith('/v1/admin/messages/')) return _messages(r);
    if (path.startsWith('/v1/admin/content')) return _content(r);
    if (path.startsWith('/v1/admin/settings')) return _settings(r);
    if (path == '/v1/admin/overview') return _json(overview(days));
    if (path == '/v1/admin/series') return _json({'items': series(days)});
    if (path == '/v1/admin/breakdown') return _json(breakdown(days));
    if (path == '/v1/admin/users') return _json(_page(q));
    if (path == '/v1/admin/active') return _json(_active());
    if (path == '/v1/admin/reports') return _report(q);
    final m = RegExp(r'^/v1/admin/users/([^/]+)(/points|/sign-out)?$').firstMatch(path);
    if (m != null) {
      final id = m.group(1)!;
      final u = users.where((u) => u['id'] == id).firstOrNull;
      if (u == null) return _problem(404, 'account not found');
      switch ((r.method, m.group(2))) {
        case ('GET', null):
          return _json(_detail(u));
        case ('PATCH', null):
          final b = bodyOf(r);
          if (role != 'admin' && u['role'] == 'admin') {
            return _problem(403, "only an admin changes an admin's account", 'not_allowed');
          }
          if (b['role'] != null && !assignable[role]!.contains(b['role'])) {
            return _problem(403, "the $role role can't give the ${b['role']} role", 'not_allowed');
          }
          if (id == 'admin-1' && b['status'] == 'suspended') return _problem(409, 'no', 'admin_self');
          if (b['status'] != null) u['status'] = b['status'];
          if (b['role'] != null) u['role'] = b['role'];
          if (b['permissions'] != null) {
            u['permissions'] = {...u['permissions'] as Json, ...b['permissions'] as Json};
          }
          return _json(u);
        case ('POST', '/points'):
          final points = bodyOf(r)['points'] as int;
          u['balance'] = (u['balance'] as int) + points;
          return _json({'balance': u['balance'], 'held': 0, 'available': u['balance']}, 201);
        case ('POST', '/sign-out'):
          return _json({'signed_out': true});
      }
    }
    return _problem(404, 'not found');
  }

  Json overview(int days) => {
        'days': days,
        'from': series(days).first['day'],
        'to': '2026-10-29',
        'accounts': {'total': users.length, 'new': days ~/ 7, 'suspended': 1, 'admins': 2, 'demo': 26},
        'active': {'now': 3, 'day': 8, 'week': 15, 'month': 24},
        'ai': {
          'jobs': days * 5,
          'delivered_jobs': days * 5 - 2,
          'input_tokens': days * 40000,
          'output_tokens': days * 11000,
          'tokens': days * 51000,
          'cost_usd': days * 2.05,
        },
        'money': {
          'topup_cny': days * 90.0,
          'net_cny': days * 84.06,
          'cost_cny': days * 14.97,
          'profit_cny': days * 69.09,
          'margin': 0.822,
        },
        'points': {'sold': days * 9000, 'granted': 5000, 'used': days * 7000, 'outstanding': 120000},
        // The period before (v12.3.0), set so each change is easy to work out: 充值 90 against 80 a day (+12.5 %),
        // AI cost 14.97 against 15.97 (-6.3 %, good), profit 69.09 against 58 (+19.1 %), margin 82.2 % against 78 %
        // (+4.2 points), new accounts the same (flat), AI requests 5 against 4 (+25 %), tokens 51,000 against 60,000
        // (-15 %, bad), 积分 sold the same, used 7,000 against 5,000 (+40 %).
        'previous': {
          'from': '2026-08-01',
          'to': series(days).first['day'],
          'accounts': {'new': days ~/ 7},
          'ai': {'jobs': days * 4, 'tokens': days * 60000, 'cost_usd': days * 2.19},
          'money': {
            'topup_cny': days * 80.0,
            'net_cny': days * 74.72,
            'cost_cny': days * 15.97,
            'profit_cny': days * 58.0,
            'margin': 0.78,
          },
          'points': {'sold': days * 9000, 'granted': 4000, 'used': days * 5000},
        },
      };

  List<Json> series(int days) => [
        for (var i = days - 1; i >= 0; i--)
          {
            'day': testNow.subtract(Duration(days: i)).toIso8601String().substring(0, 10),
            'new_accounts': i % 7 == 0 ? 1 : 0,
            'active_accounts': 5 + i % 3,
            'jobs': 5,
            'input_tokens': 40000,
            'output_tokens': 11000,
            'tokens': 51000,
            'topup_cny': i % 2 == 0 ? 180.0 : 0.0,
            'net_cny': i % 2 == 0 ? 168.12 : 0.0,
            'cost_cny': 14.97,
            'profit_cny': i % 2 == 0 ? 153.15 : -14.97,
            'margin': i % 2 == 0 ? 0.911 : null,
            'points_sold': i % 2 == 0 ? 18000 : 0,
            'points_granted': 0,
            'points_used': 7000,
          },
      ];

  Json breakdown(int days) => {
        'byMethod': [
          {'kind': 'report', 'system': 'bazi', 'jobs': days * 2, 'tokens': days * 30000, 'cost_cny': days * 8.5, 'points_used': days * 3000},
          {'kind': 'life_report', 'jobs': days, 'tokens': days * 15000, 'cost_cny': days * 4.0, 'points_used': days * 2500},
          {'kind': 'followup', 'system': 'tarot', 'jobs': days * 2, 'tokens': days * 6000, 'cost_cny': days * 2.47, 'points_used': days * 1500},
        ],
        'byModel': [
          {
            'model': 'claude-opus-5-5',
            'jobs': days * 5,
            'input_tokens': days * 40000,
            'output_tokens': days * 11000,
            'tokens': days * 51000,
            'cost_cny': days * 14.97,
          },
        ],
      };

  Json _page(Map<String, String> q) {
    final needle = q['q']?.toLowerCase();
    final kept = users
        .where(
          (u) =>
              (needle == null || (u['login'] as String).contains(needle) || (u['id'] as String).startsWith(needle)) &&
              (q['status'] == null || u['status'] == q['status']) &&
              (q['role'] == null || u['role'] == q['role']) &&
              (q['demo'] != 'exclude' || u['demo'] != true) &&
              (q['demo'] != 'only' || u['demo'] == true),
        )
        .toList();
    final field = switch (q['sort']) {
      'balance' => 'balance',
      'topup' => 'topup_cny',
      'used' => 'points_used',
      'jobs' => 'jobs',
      'cost' => 'cost_cny',
      'last_seen' => 'last_seen_at',
      _ => 'created_at',
    };
    Comparable<Object> v(Json u) => (u[field] ?? '') as Comparable<Object>;
    kept.sort((a, b) => q['order'] == 'asc' ? v(a).compareTo(v(b)) : v(b).compareTo(v(a)));
    final per = int.parse(q['per_page'] ?? '25');
    final pages = (kept.length / per).ceil().clamp(1, 1 << 30);
    final page = (int.tryParse(q['page'] ?? '1') ?? 1).clamp(1, pages);
    return {
      'total': kept.length,
      'page': page,
      'pages': pages,
      'per_page': per,
      'items': kept.skip((page - 1) * per).take(per).toList(),
    };
  }

  Json _detail(Json u) => {
        'user': u,
        'entries': [
          {
            'id': 'e3',
            'kind': 'charge',
            'points': -688,
            'balance': u['balance'],
            'created_at': _iso(testNow.subtract(const Duration(hours: 2))),
            'for': {'kind': 'report', 'id': 'c1', 'system': 'bazi'},
            'basis': 'measured',
            'usd': 0.18,
          },
          {
            'id': 'e2',
            'kind': 'grant',
            'points': 500,
            'balance': (u['balance'] as int) + 688,
            'created_at': _iso(testNow.subtract(const Duration(days: 1))),
            'reason': 'admin:x',
            'note': '活动奖励',
          },
          {
            'id': 'e1',
            'kind': 'topup',
            'points': 1000,
            'balance': (u['balance'] as int) + 188,
            'created_at': _iso(testNow.subtract(const Duration(days: 2))),
            'pack': {'yuan': 10, 'points': 1000},
          },
        ],
        'jobs': [
          {
            'job_id': 'j1',
            'created_at': _iso(testNow.subtract(const Duration(hours: 2))),
            'kind': 'report',
            'system': 'bazi',
            'models': ['claude-opus-5-5'],
            'tokens': 12000,
            'cost_cny': 1.31,
            'delivered': true,
          },
        ],
        'by_method': [
          {'kind': 'report', 'system': 'bazi', 'jobs': 1, 'tokens': 12000, 'cost_cny': 1.31, 'points_used': 688},
        ],
      };

  Json _active() {
    List<Json> within(Duration d) {
      final seen = users.where((u) {
        final at = u['last_seen_at'] as String?;
        return at != null && testNow.difference(DateTime.parse(at)) < d;
      }).toList()
        ..sort((a, b) => (b['last_seen_at'] as String).compareTo(a['last_seen_at'] as String));
      return seen;
    }

    return {
      'counts': {
        'now': within(const Duration(minutes: 15)).length,
        'day': within(const Duration(days: 1)).length,
        'week': within(const Duration(days: 7)).length,
        'month': within(const Duration(days: 30)).length,
      },
      'now': within(const Duration(minutes: 15)),
      'day': within(const Duration(days: 1)),
    };
  }

  http.Response _report(Map<String, String> q) {
    final format = q['format'] ?? 'csv';
    if (failFormats.contains(format)) return _problem(503, 'no CJK font on this server');
    final span = '${series(int.parse(q['days'] ?? '30')).first['day']}_2026-10-29';
    final (name, type) = switch ((format, q['kind'])) {
      ('csv', 'users') => ('命理大师-用户-$span.csv', 'text/csv; charset=utf-8'),
      ('csv', _) => ('命理大师-收益曲线-$span.csv', 'text/csv; charset=utf-8'),
      ('pdf', _) => ('命理大师-经营报表-$span.pdf', 'application/pdf'),
      _ => ('命理大师-经营报表-$span.docx', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'),
    };
    return http.Response.bytes(
      Uint8List.fromList(utf8.encode('file $format')),
      200,
      headers: {
        'content-type': type,
        'content-disposition': 'attachment; filename="export.$format"; filename*=UTF-8\'\'${Uri.encodeComponent(name)}',
      },
    );
  }

  // ---- 消息 (tech plan S25): the server's shapes (src/admin/messages.ts), the wordings checked as markup.ts does ----

  /// The wording in use for [kind] in [locale]: an admin's, else the default; with the default.
  Json wording(Json spec, String locale) {
    final d = (spec['defaults'] as Json)[locale] as Json;
    final c = custom['${spec['kind']}/$locale'];
    return {
      'locale': locale,
      ...(c == null ? d : {'subject': ?c['subject'], 'body': c['body']}),
      'custom': c != null,
      if (c != null) 'updated_at': c['updated_at'],
      'default': d,
    };
  }

  Json? _spec(Object? kind) => messageSpecs.where((s) => s['kind'] == kind).firstOrNull;

  /// What is wrong with a wording, in the server's words.
  List<String> problemsOf(Json spec, String? subject, String body) {
    final names = {for (final v in spec['variables'] as List) (v as Json)['name']};
    final used = {for (final m in RegExp(r'\{\{(\w+)\}\}').allMatches('${subject ?? ''}\n$body')) m.group(1)};
    return [
      if (body.trim().isEmpty) '正文不能为空',
      if (spec['channel'] == 'mail' && (subject ?? '').trim().isEmpty) '邮件需要标题',
      for (final n in used) if (!names.contains(n)) '没有 {{$n}} 这个变量',
      for (final n in spec['required'] as List) if (!used.contains(n)) '需要用到 {{$n}}',
    ];
  }

  String _filled(String s) => s.replaceAllMapped(RegExp(r'\{\{(\w+)\}\}'), (m) => sampleValues[m.group(1)] ?? m.group(0)!);

  Json _settingView(Json spec) {
    final key = spec['key'] as String;
    final changed = settingValues.containsKey(key);
    return {
      ...spec,
      'value': changed ? settingValues[key] : spec['default'],
      if (changed) 'changed': {'updated_at': _iso(testNow)},
    };
  }

  /// 设置 (S31), as src/admin/settings.ts answers; a value checked as the registry's problemOf checks it.
  http.Response _settings(http.Request r) {
    final path = r.url.path;
    if (path == '/v1/admin/settings' && r.method == 'GET') {
      return _json({
        'settings': [for (final spec in settingSpecs) _settingView(spec)],
        'ai': {'serving': aiServing, 'models': 'claude-opus-5-5'},
        if (ratesDate != null) 'rates': {'date': ratesDate, 'stale': false},
      });
    }
    final key = path.substring('/v1/admin/settings/'.length);
    final spec = settingSpecs.where((x) => x['key'] == key).firstOrNull;
    if (spec == null) return _problem(404, 'no such setting', 'unknown_setting');
    if (r.method == 'DELETE') {
      settingValues.remove(key);
      return _json(_settingView(spec));
    }
    final value = bodyOf(r)['value'];
    final problem = switch (spec['type']) {
      'number' when value is! num => '要一个数字',
      'number' when (value as num) < (spec['min'] as num) || value > (spec['max'] as num) =>
        '要在 ${spec['min']} 到 ${spec['max']} 之间',
      'choices' when value is! List || value.isEmpty => '至少选一个',
      // The server's registry.ts problemOf for packs, its rule in short: 100 积分 a 元 at the least (packFits).
      'packs' when value is! List || value.isEmpty => '至少要一个套餐',
      'packs' when (value as List).any((p) => (p['points'] as num) < (p['yuan'] as num) * 100) =>
        '${value.firstWhere((p) => (p['points'] as num) < (p['yuan'] as num) * 100)['yuan']} 元的套餐：积分要是整数，每元至少 100 积分',
      _ => null,
    };
    if (problem != null) return _problem(400, problem, 'invalid_setting');
    settingValues[key] = value;
    return _json(_settingView(spec));
  }

  /// 内容管理 (S29), as src/admin/content.ts answers.
  http.Response _content(http.Request r) {
    final path = r.url.path;
    if (path == '/v1/admin/content' && r.method == 'GET') {
      return _json({
        'locales': ['zh-Hans', 'zh-Hant'],
        'image_types': imageTypes,
        'image_max_bytes': imageMaxBytes,
        'pages': contentPages,
        'texts': [
          for (final t in contentCatalog)
            {
              ...t,
              'changed': {for (final l in ['zh-Hans', 'zh-Hant']) l: ?contentTexts['${t['key']}/$l']},
            },
        ],
        'images': [
          for (final (key, label) in contentImageLabels)
            {
              'key': key,
              'label': label,
              'places': contentImagePlaces[key],
              if (contentImages[key] case final i?) ...{
                'url': '/v1/content/images/$key?v=${i['updated_at']}',
                'updated_at': i['updated_at'],
              },
            },
        ],
      });
    }
    final text = RegExp(r'^/v1/admin/content/texts/(\w+)/(zh-Hans|zh-Hant)$').firstMatch(path);
    if (text != null) {
      final spec = contentCatalog.where((t) => t['key'] == text[1]).firstOrNull;
      if (spec == null) return _problem(404, 'no such text', 'unknown_text');
      final id = '${text[1]}/${text[2]}';
      if (r.method == 'DELETE') {
        contentTexts.remove(id);
        return _json({'key': text[1], 'locale': text[2], 'text': (spec['defaults'] as Json)[text[2]]});
      }
      final value = (bodyOf(r)['text'] as String? ?? '').trim();
      if (value.isEmpty) return _problem(400, 'text is required');
      String names(Iterable<String> ps) => (ps.toSet().toList()..sort()).join(',');
      final own = (spec['placeholders'] as List).cast<String>();
      if (names(RegExp(r'\{(\w+)\}').allMatches(value).map((m) => m[1]!)) != names(own)) {
        return _problem(400, 'the text must keep its placeholders and add none', 'placeholders_mismatch');
      }
      // HTML (S33), as src/admin/content.ts and src/content/rich.ts richProblem refuse it, in short: tags only where
      // the text is rich, and no tag outside the subset.
      if (RegExp(r'</?[A-Za-z]').hasMatch(value)) {
        if (spec['rich'] != true) return _problem(400, '这段文字在应用里只显示纯文字，不能用 HTML', 'rich_unsupported');
        final tag = RegExp(r'</?([A-Za-z]+)').allMatches(value).map((m) => m[1]!).where((t) => !richTags.contains(t)).firstOrNull;
        if (tag != null) return _problem(400, '不支持的标签：<$tag>', 'rich_invalid');
      }
      contentTexts[id] = {'text': value, 'updated_at': _iso(testNow)};
      return _json({'key': text[1], 'locale': text[2], 'text': value, 'updated_at': _iso(testNow)});
    }
    final image = RegExp(r'^/v1/admin/content/images/(\w+)$').firstMatch(path);
    if (image != null) {
      final key = image[1]!;
      if (!contentImageLabels.any((i) => i.$1 == key)) return _problem(404, 'no such image', 'unknown_image');
      if (r.method == 'DELETE') {
        contentImages.remove(key);
        return _json({'key': key});
      }
      final type = r.headers['content-type'] ?? '';
      if (!imageTypes.contains(type)) return _problem(415, 'an image is png, jpeg or webp', 'image_type');
      if (r.bodyBytes.length > imageMaxBytes) return _problem(413, 'request body too large');
      contentImages[key] = {'type': type, 'bytes': r.bodyBytes.length, 'updated_at': _iso(testNow)};
      return _json({'key': key, 'url': '/v1/content/images/$key?v=${_iso(testNow)}', 'updated_at': _iso(testNow)});
    }
    return _problem(404, 'not found');
  }

  http.Response _messages(http.Request r) {
    final path = r.url.path;
    if (path == '/v1/admin/messages/templates' && r.method == 'GET') {
      return _json({
        'templates': [
          for (final s in messageSpecs)
            {
              for (final k in ['kind', 'channel', 'name', 'about', 'variables', 'required']) k: s[k],
              'locales': [for (final l in (s['defaults'] as Json).keys) wording(s, l)],
            },
        ],
        'delivery': {'mail': deliveryOff ? 'off' : 'outbox', 'sms': deliveryOff ? 'off' : 'outbox'},
      });
    }
    final tm = RegExp(r'^/v1/admin/messages/templates/([^/]+)/([^/]+)$').firstMatch(path);
    if (tm != null) {
      final spec = _spec(tm.group(1));
      final locale = tm.group(2)!;
      if (spec == null || !(spec['defaults'] as Json).containsKey(locale)) return _problem(404, 'no such message');
      if (r.method == 'PUT') {
        final b = bodyOf(r);
        final problems = problemsOf(spec, b['subject'] as String?, b['body'] as String? ?? '');
        if (problems.isNotEmpty) {
          return _json({'title': problems.join('；'), 'status': 400, 'code': 'invalid_template', 'problems': problems}, 400);
        }
        custom['${spec['kind']}/$locale'] = {'subject': ?b['subject'], 'body': b['body'], 'updated_at': _iso(testNow)};
        return _json(wording(spec, locale));
      }
      if (r.method == 'DELETE') {
        custom.remove('${spec['kind']}/$locale');
        return _json(wording(spec, locale));
      }
    }
    if (path == '/v1/admin/messages/preview' && r.method == 'POST') {
      final b = bodyOf(r);
      final spec = _spec(b['kind'])!;
      final w = b['body'] is String ? b : wording(spec, b['locale'] as String);
      final text = _filled(w['body'] as String).trim();
      final problems = problemsOf(spec, w['subject'] as String?, w['body'] as String);
      if (spec['channel'] == 'sms') {
        return _json({'text': text, 'sms': smsSegments(text), 'problems': problems});
      }
      final subject = _filled(w['subject'] as String? ?? '');
      return _json({
        'subject': subject,
        'text': text,
        'html': '<!doctype html><html data-scheme="${b['scheme'] ?? ''}"><body>$text</body></html>',
        'problems': problems,
      });
    }
    if (path == '/v1/admin/messages/test' && r.method == 'POST') {
      final b = bodyOf(r);
      final spec = _spec(b['kind'])!;
      final to = (b['to'] as String? ?? '').trim();
      final mail = spec['channel'] == 'mail';
      if (mail ? !to.contains('@') : !RegExp(r'^\+?[\d ]{6,}$').hasMatch(to)) {
        return _problem(400, mail ? 'to must be an email address' : 'to must be a phone number');
      }
      if (b['body'] is String) {
        final problems = problemsOf(spec, b['subject'] as String?, b['body'] as String);
        if (problems.isNotEmpty) {
          return _json({'title': problems.join('；'), 'status': 400, 'code': 'invalid_template', 'problems': problems}, 400);
        }
      }
      if (deliveryOff) return _problem(503, 'no mail transport on this server', 'delivery_unavailable');
      final entry = {
        'id': 'd${log.length + 1}',
        'at': _iso(testNow),
        'kind': spec['kind'],
        'channel': spec['channel'],
        'locale': b['locale'],
        'to': mail ? '${to[0]}***${to.substring(to.indexOf('@'))}' : '+86 *******${to.substring(to.length - 4)}',
        if (mail) 'subject': '(subject)',
        'status': 'sent',
        'transport': 'outbox',
        'custom': custom.containsKey('${spec['kind']}/${b['locale']}') || b['body'] is String,
        'test': true,
      };
      log.add(entry);
      return _json({'entry': entry}, 202);
    }
    if (path == '/v1/admin/messages/log' && r.method == 'GET') return _json({'items': log.reversed.toList()});
    return _problem(404, 'not found');
  }
}

/// What each staff role may do, and the roles it may give (the server's src/admin/roles.ts).
const capabilities = {
  'admin': ['view', 'assign', 'user_data', 'messages', 'content', 'settings'],
  'manager': ['view', 'assign'],
  'integrator': ['messages', 'content'],
};
const assignable = {
  'admin': ['user', 'integrator', 'manager', 'admin'],
  'manager': ['user', 'integrator', 'manager'],
  'integrator': <String>[],
};

/// 设置's settings (the server's src/settings/registry.ts), a few of each kind.
const settingSpecs = <Json>[
  {
    'key': 'sessions.idle_days',
    'group': 'sessions',
    'type': 'number',
    'min': 0.01,
    'max': 365,
    'unit': '天',
    'label': '登录有效期',
    'about': '账户多久没用之后要重新登录。',
    'default': 2,
  },
  {
    'key': 'limits.grant_max',
    'group': 'limits',
    'type': 'number',
    'integer': true,
    'min': 1,
    'max': 100000000,
    'unit': '积分',
    'label': '一次最多增加的积分',
    'about': '管理后台给一个账户增加积分时，一次最多加这么多。',
    'default': 1000000,
  },
  {
    'key': 'ai.mock',
    'group': 'ai',
    'type': 'boolean',
    'optional': true,
    'label': 'AI 模拟',
    'about': '开：示范回答，不花 token；关：真实模型。不选就跟随 .env 的 IS_AI_MOCK。',
    'default': null,
  },
  {
    'key': 'ai.model',
    'group': 'ai',
    'type': 'choice',
    'optional': true,
    'options': ['claude-opus-5-5', 'claude-sonnet-5-5'],
    'label': 'AI 模型',
    'about': '每一步 AI 都用这个模型。',
    'default': null,
  },
  {
    'key': 'currencies.accepted',
    'group': 'currencies',
    'type': 'choices',
    'options': ['CNY', 'HKD', 'TWD', 'USD'],
    'label': '收的货币',
    'about': '用户充值时可以选的货币。',
    'default': ['CNY', 'HKD'],
  },
  {
    'key': 'currencies.dashboard',
    'group': 'currencies',
    'type': 'choice',
    'options': ['CNY', 'HKD', 'TWD', 'USD'],
    'label': '管理后台的货币',
    'about': '管理后台的金额用这个货币显示。',
    'default': 'CNY',
  },
  {
    'key': 'points.packs',
    'group': 'points',
    'type': 'packs',
    'max': 8,
    'label': '充值套餐',
    'about': '用户充值时可以选的套餐。',
    'default': [
      {'yuan': 10, 'points': 1000},
      {'yuan': 20, 'points': 2200},
    ],
  },
];

/// 内容管理's images and what an image may be (the server's catalog.ts).
const contentImageLabels = [('banner', '横幅背景（命理罗盘）'), ('logo', '介绍页标志')];
const imageTypes = ['image/png', 'image/jpeg', 'image/webp'];
const imageMaxBytes = 2 * 1024 * 1024;

/// The app's pages as 内容 lists them (the server's pages.ts), a few.
const contentPages = [
  {'id': 'MingliApp', 'name': '整个应用'},
  {'id': 'IntroPage', 'name': '欢迎页（登录前）'},
  {'id': 'HomePage', 'name': '首页'},
  {'id': 'LiuyaoPage', 'name': '算卦'},
  {'id': 'PointsPage', 'name': '我的积分'},
];

/// Where an image shows (the server's usage.ts), by key.
const contentImagePlaces = {
  'banner': [
    {'page': 'HomePage', 'parts': ['横幅']},
    {'page': 'LiuyaoPage', 'parts': ['横幅']},
  ],
  'logo': [
    {'page': 'IntroPage', 'parts': ['标志']},
  ],
};

/// The texts 内容 lists (the server's, from the app's message files) with where each shows (usage.ts): a few of the
/// app's, one shared by several pages, then enough for 再显示, ten of them on 算卦's AI button and the rest on no page.
final contentCatalog = <Json>[
  {
    'key': 'homeTarot',
    'area': 'home',
    'placeholders': <String>[],
    'defaults': {'zh-Hans': '塔罗占卜', 'zh-Hant': '塔羅占卜'},
    'places': [
      {'page': 'IntroPage', 'parts': ['方法入口']},
      {'page': 'HomePage', 'parts': ['方法入口']},
    ],
  },
  {
    'key': 'pointsBalanceLine',
    'area': 'points',
    'placeholders': ['balance'],
    'defaults': {'zh-Hans': '余额 {balance} 积分', 'zh-Hant': '餘額 {balance} 積分'},
    'places': [
      {'page': 'HomePage', 'parts': ['菜单']},
      {'page': 'PointsPage', 'parts': <String>[]},
    ],
  },
  {
    'key': 'serverUnreachable',
    'area': 'server',
    'placeholders': <String>[],
    'defaults': {'zh-Hans': '连不上服务器。\n请稍后再试。', 'zh-Hant': '連不上伺服器。\n請稍後再試。'},
    'places': [
      {'page': 'MingliApp', 'parts': <String>[]},
    ],
  },
  for (var i = 1; i <= 40; i++)
    {
      'key': 'sample$i',
      'area': 'sample',
      'placeholders': <String>[],
      'defaults': {'zh-Hans': '示例文字 $i', 'zh-Hant': '示例文字 $i'},
      'places': [
        if (i <= 10) {'page': 'LiuyaoPage', 'parts': ['AI 解读按钮']},
      ],
      // The first may hold HTML (the app shows it through ContentText, S33).
      if (i == 1) 'rich': true,
    },
];

/// The values a preview fills in (the server's samples).
const sampleValues = {'code': '482913', 'minutes': '10', 'title': '八字 AI 解读', 'subtitle': '张三 · 1990-05-01', 'count': '2'};

/// An SMS's length and the messages it takes (the server's smsSegments): 70 a message with Chinese in it, 67 a part.
Json smsSegments(String text) {
  final length = text.runes.length;
  final ascii = RegExp(r'^[\x20-\x7E\n\r]*$').hasMatch(text);
  final (one, part) = ascii ? (160, 153) : (70, 67);
  return {'length': length, 'segments': length == 0 ? 0 : (length <= one ? 1 : (length / part).ceil())};
}

/// The four messages, as the server's specs list them (their wordings shortened).
final messageSpecs = <Json>[
  {
    'kind': 'code_mail',
    'channel': 'mail',
    'name': '邮箱验证码',
    'about': '注册、绑定邮箱或找回密码时发出',
    'variables': [
      {'name': 'code', 'about': '验证码', 'sample': '482913'},
      {'name': 'minutes', 'about': '有效分钟数', 'sample': '10'},
    ],
    'required': ['code'],
    'defaults': {
      'zh-Hans': {'subject': '命理大师验证码：{{code}}', 'body': '# 验证你的邮箱\n\n你的验证码是：\n\n!! {{code}}\n\n{{minutes}} 分钟内有效。'},
      'zh-Hant': {'subject': '命理大師驗證碼：{{code}}', 'body': '# 驗證你的郵箱\n\n你的驗證碼是：\n\n!! {{code}}'},
      'en': {'subject': 'Your 命理大师 code: {{code}}', 'body': '# Verify your email\n\n!! {{code}}'},
    },
  },
  {
    'kind': 'report_mail',
    'channel': 'mail',
    'name': '报告邮件',
    'about': '用户把一份解读发到自己的邮箱时发出',
    'variables': [
      {'name': 'title', 'about': '报告的标题', 'sample': '八字 AI 解读'},
      {'name': 'subtitle', 'about': '为谁、何时', 'sample': '张三 · 1990-05-01'},
      {'name': 'report', 'about': '报告的内容', 'sample': '', 'part': true},
    ],
    'required': ['report'],
    'defaults': {
      'zh-Hans': {'subject': '命理大师：{{title}}', 'body': '# {{title}}\n\n{{subtitle}}\n\n{{report}}'},
      'zh-Hant': {'subject': '命理大師：{{title}}', 'body': '# {{title}}\n\n{{subtitle}}\n\n{{report}}'},
    },
  },
  {
    'kind': 'records_mail',
    'channel': 'mail',
    'name': '记录邮件',
    'about': '用户把几条以往记录发到自己的邮箱时发出',
    'variables': [
      {'name': 'title', 'about': '邮件的标题', 'sample': '2 条测算记录'},
      {'name': 'count', 'about': '记录的条数', 'sample': '2'},
      {'name': 'records', 'about': '记录的列表', 'sample': '', 'part': true},
    ],
    'required': <String>[],
    'defaults': {
      'zh-Hans': {'subject': '命理大师：{{title}}', 'body': '# {{title}}\n\n{{records}}'},
      'zh-Hant': {'subject': '命理大師：{{title}}', 'body': '# {{title}}\n\n{{records}}'},
    },
  },
  {
    'kind': 'code_sms',
    'channel': 'sms',
    'name': '短信验证码',
    'about': '注册、绑定手机号或找回密码时发出',
    'variables': [
      {'name': 'code', 'about': '验证码', 'sample': '482913'},
      {'name': 'minutes', 'about': '有效分钟数', 'sample': '10'},
    ],
    'required': ['code'],
    'defaults': {
      'zh-Hans': {'body': '【命理大师】你的验证码是 {{code}}，{{minutes}} 分钟内有效。如非本人操作，请忽略本短信。'},
      'zh-Hant': {'body': '【命理大師】你的驗證碼是 {{code}}，{{minutes}} 分鐘內有效。'},
      'en': {'body': '[命理大师] Your code is {{code}}, valid for {{minutes}} minutes.'},
    },
  },
];

/// The dashboard on a [size] screen, signed in as the admin unless [signIn] is false.
/// [prefs] is the browser's storage (the theme picked, v12.1.0): empty unless a test gives one. [loginHint] is the
/// login the app's ☰ → 管理后台 hands over (`?login=`, S25).
Future<FakeAdmin> pumpAdmin(
  WidgetTester tester, {
  FakeAdmin? fake,
  Size size = wide,
  bool signIn = true,
  Map<String, String>? prefs,
  String? loginHint,
  String? handoff,
  Map<String, String>? tab,
}) async {
  final f = fake ?? FakeAdmin();
  final stored = prefs ?? <String, String>{};
  // This tab's storage (S33): an empty value takes the key away, as the browser's does.
  final inTab = tab ?? <String, String>{};
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      retry: retryAdmin,
      overrides: [
        httpClientProvider.overrideWithValue(f.client),
        clockProvider.overrideWithValue(() => testNow),
        saveFileProvider.overrideWithValue((file) async => f.saved.add(file)),
        pickFileProvider.overrideWithValue((types) async {
          f.pickTypes = types;
          return f.pick;
        }),
        prefsProvider.overrideWithValue(Prefs(read: (k) => stored[k], write: (k, v) => stored[k] = v)),
        tabPrefsProvider.overrideWithValue(
          Prefs(read: (k) => inTab[k], write: (k, v) => v.isEmpty ? inTab.remove(k) : inTab[k] = v),
        ),
        loginHintProvider.overrideWithValue(loginHint),
        handoffProvider.overrideWithValue(handoff),
      ],
      child: const AdminApp(),
    ),
  );
  await tester.pumpAndSettle();
  if (signIn) await signInAs(tester);
  return f;
}

Future<void> signInAs(WidgetTester tester, {String login = 'boss', String password = 'secret1'}) async {
  await tester.enterText(find.byKey(const Key('admin-login')), login);
  await tester.enterText(find.byKey(const Key('admin-password')), password);
  await tester.tap(find.byKey(const Key('admin-submit')));
  await tester.pumpAndSettle();
}

/// Taps the control keyed [key], brought into view first, and lets what it does settle.
Future<void> tapOn(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

/// A page's entry in the rail (wide) or the bar (phone).
Finder nav(String label) => find.descendant(
      of: find.byWidgetPredicate((w) => w is NavigationRail || w is NavigationBar),
      matching: find.text(label),
    );

/// Opens the page [label]: from the rail or the bar, else from the menu at the top right (S33: 内容, 消息, 导出). On a
/// phone, a page of the menu goes back first when the page asked for is the bar's.
Future<void> go(WidgetTester tester, String label) async {
  if (nav(label).evaluate().isEmpty && find.byKey(const Key('menu-back')).evaluate().isNotEmpty) {
    await tester.tap(find.byKey(const Key('menu-back')));
    await tester.pumpAndSettle();
  }
  if (nav(label).evaluate().isNotEmpty) {
    await tester.tap(nav(label));
  } else {
    await openMenu(tester);
    await tester.tap(find.byKey(ValueKey<String>('menu-$label')));
  }
  await tester.pumpAndSettle();
}

/// Opens the menu at the top right (S33): its pages, 外观 and 退出登录.
Future<void> openMenu(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('admin-menu')));
  await tester.pumpAndSettle();
}

/// The text of the widget with [key].
String textOf(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(ValueKey<String>(key))).data!;

/// The main column's list on a dashboard page (DashboardLayout, v12.3.0).
Finder get mainList =>
    find.descendant(of: find.byKey(const Key('page-main')), matching: find.byType(Scrollable)).first;

/// Scrolls the main column until [finder] is built and on screen, then a frame (rules 27, 64): a card below the hero
/// and the figures is past the list's built area. A negative [delta] goes back up (rule 25).
Future<void> scrollToIt(WidgetTester tester, Finder finder, {double delta = 300}) async {
  await tester.scrollUntilVisible(finder, delta, scrollable: mainList);
  await tester.pump();
}
