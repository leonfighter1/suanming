import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mingli_admin/application/providers.dart';
import 'package:mingli_admin/config.dart';
import 'package:mingli_admin/data/admin_api.dart';
import 'package:mingli_admin/domain/models.dart';
import 'package:mingli_admin/presentation/format.dart';
import 'package:mingli_admin/presentation/widgets/line_chart.dart';

// The dashboard's small parts (管理后台, tech plan S22).

void main() {
  test('the API: ?api= first, else the page\'s own server under /admin/, else the dev server', () {
    expect(adminApiBase(Uri.parse('http://localhost:5000/?api=http://10.0.0.2:8787/')), 'http://10.0.0.2:8787');
    expect(adminApiBase(Uri.parse('https://mingli.example/admin/')), 'https://mingli.example');
    expect(adminApiBase(Uri.parse('http://127.0.0.1:8787/admin/#/users')), 'http://127.0.0.1:8787');
    expect(adminApiBase(Uri.parse('http://localhost:5000/')), 'http://127.0.0.1:8787');
  });

  test('a download\'s name: the UTF-8 one before the ASCII fallback', () {
    expect(
      fileName("attachment; filename=\"report.csv\"; filename*=UTF-8''${Uri.encodeComponent('命理大师-收益曲线.csv')}"),
      '命理大师-收益曲线.csv',
    );
    expect(fileName('attachment; filename="report.pdf"'), 'report.pdf');
    expect(fileName(null), isNull);
  });

  test('the 用户 query: only what is set, the search trimmed', () {
    const q = UserQuery();
    expect(q.query, 'demo=include&sort=created&order=desc&page=1&per_page=25');
    final r = q.copyWith(q: ' boss ', status: () => 'suspended', sort: 'balance', asc: true, page: 2);
    expect(Uri.splitQueryString(r.query), {
      'q': 'boss',
      'status': 'suspended',
      'demo': 'include',
      'sort': 'balance',
      'order': 'asc',
      'page': '2',
      'per_page': '25',
    });
    expect(r.copyWith(status: () => null).status, isNull);
    expect(r.copyWith(page: 3).status, 'suspended');
    expect(q.copyWith(), q);
  });

  test('money, counts and times read the way the dashboard writes them', () {
    expect(yuan(2720), '¥2,720.00');
    expect(yuan(-14.97), '-¥14.97');
    expect(compact(9999), '9,999');
    expect(compact(15300), '1.5万');
    expect(compact(320000000), '3.2亿');
    expect(percent(0.6392), '63.9%');
    expect(percent(null), '—');
    final now = DateTime.utc(2026, 10, 29, 12);
    expect(ago(now.subtract(const Duration(seconds: 20)), now), '刚刚');
    expect(ago(now.subtract(const Duration(minutes: 5)), now), '5 分钟前');
    expect(ago(now.subtract(const Duration(hours: 3)), now), '3 小时前');
    expect(ago(now.subtract(const Duration(days: 2)), now), '2 天前');
  });

  test('what a job or a 积分 change was', () {
    expect(whatOf('report', 'bazi'), '八字 AI 解读');
    expect(whatOf('followup', 'tarot'), '塔罗 追问');
    expect(whatOf('life_report', 'bazi'), '一生运势报告');
    expect(whatOf('inquiry', 'bazi'), '八字 深度分析');
    expect(entryOf(kind: 'topup', packYuan: 30), '充值 30 元');
    expect(entryOf(kind: 'grant', reason: 'dev'), '开发测试赠送');
    expect(entryOf(kind: 'grant', reason: 'admin:1f2e'), '管理员赠送');
    expect(entryOf(kind: 'charge', forKind: 'remedy', system: 'bazi'), '八字 破除运势方案');
  });

  test('the chart\'s axis steps are round', () {
    expect(niceStep(195), 50);
    expect(niceStep(1530000), 500000);
    expect(niceStep(37), 10);
    expect(niceStep(0), 1);
  });

  test('a failed request is asked again a few times when the server erred, never when it said no', () {
    const down = AdminApiException(500, '服务器出错了');
    expect([for (var i = 0; i < 5; i++) retryAdmin(i, down)?.inMilliseconds], [200, 400, 800, 1600, null]);
    expect(retryAdmin(0, const AdminUnreachable('http://x')), const Duration(milliseconds: 200));
    expect(retryAdmin(0, const AdminApiException(403, 'admins only', 'admin_only')), isNull);
    expect(retryAdmin(0, const AdminApiException(401, '请先登录')), isNull);
    expect(retryAdmin(0, StateError('bug')), isNull);
  });

  test('an account from the server: its role, status and permissions', () {
    final u = AdminUser.fromJson({
      'id': 'u1',
      'login': 'a***@x.com',
      'country': 'CN',
      'role': 'admin',
      'admin_by_config': true,
      'status': 'suspended',
      'permissions': {'ai': false, 'top_up': true},
      'demo': false,
      'created_at': '2026-10-01T00:00:00.000Z',
      'balance': 120,
      'held': 30,
      'topup_cny': 10,
      'points_used': 880,
      'jobs': 2,
      'tokens': 18000,
      'cost_cny': 2.6,
    });
    expect([u.admin, u.adminByConfig, u.suspended, u.ai, u.topUpAllowed, u.demo], [true, true, true, false, true, false]);
    expect(u.lastSeenAt, isNull);
    expect(u.topup, 10.0);
  });

  // S34: the dashboard's tabs share one session, and the server (src/auth/tokens.ts rotate) takes each refresh token
  // once: a second use ends the session for every tab.
  test('two tabs share the session: each refresh takes the newest refresh token kept, never one already used', () async {
    var last = 0;
    final used = <String>{};
    final live = <String>{};
    var ended = false;
    http.Response answer(Object body, [int status = 200]) =>
        http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});
    Json tokens() {
      last++;
      live.add('a$last');
      return {'access_token': 'a$last', 'refresh_token': 'r$last'};
    }

    final server = MockClient((r) async {
      switch (r.url.path) {
        case '/v1/auth/login':
          return answer(tokens());
        case '/v1/auth/refresh':
          final t = (jsonDecode(r.body) as Map)['refresh_token'] as String;
          if (used.contains(t)) ended = true;
          if (ended || t != 'r$last') return answer({'title': 'invalid refresh token', 'status': 401}, 401);
          used.add(t);
          return answer(tokens());
        default:
          final access = r.headers['authorization']?.replaceFirst('Bearer ', '');
          if (ended || !live.contains(access)) return answer({'title': 'unauthorized', 'status': 401}, 401);
          return answer({'id': 'admin-1', 'login': 'boss'});
      }
    });
    final browser = <String, String>{};
    AdminApi tab() => AdminApi(baseUrl: 'http://server', client: server)
      ..onSession = ((r) => r == null ? browser.remove(sessionKey) : browser[sessionKey] = r)
      ..keptSession = (() => browser[sessionKey]);

    final a = tab();
    await a.signIn('boss', 'secret1');
    final b = tab();
    await b.resume(browser[sessionKey]!);
    // Both access tokens run out: a's refresh takes r2, b's, not its own r1 (used), and b's then a's.
    live.clear();
    expect((await a.me()).login, 'boss');
    expect([ended, browser[sessionKey]], [false, 'r3']);
    live.clear();
    expect((await b.me()).login, 'boss');
    expect([ended, browser[sessionKey]], [false, 'r4']);
  });
}
