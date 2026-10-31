import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mingli_app/app.dart';
import 'package:mingli_app/application/providers.dart';
import 'package:mingli_app/data/api_client.dart';
import 'package:mingli_app/data/profile_store.dart';
import 'package:mingli_app/data/settings_store.dart';
import 'package:mingli_app/data/token_store.dart';
import 'package:mingli_app/domain/terms.dart';

import 'keys.dart';

/// Fixtures are generated from the real engine + pipeline by `npm run sync:app`.
Map<String, dynamic> fixture(String name) =>
    jsonDecode(File('test/fixtures/$name.json').readAsStringSync()) as Map<String, dynamic>;

final testTerms = Terms.parse(
  File('assets/i18n/terms.json').readAsStringSync(),
  File('assets/i18n/tarot_deck.json').readAsStringSync(),
  File('assets/i18n/term_tips.json').readAsStringSync(),
  File('assets/i18n/qiuqian_lots.json').readAsStringSync(),
  File('assets/i18n/fengshui.json').readAsStringSync(),
  File('assets/i18n/naming_chars.json').readAsStringSync(),
  File('assets/i18n/liuyao.json').readAsStringSync(),
);

/// The page's main vertical list (pages also contain horizontal timelines).
final mainScrollable = find.byType(Scrollable).first;

/// Scroll [scrollable] (the main list) until [finder] is built and on screen; a negative [delta]
/// scrolls up (rule 25). scrollUntilVisible ends on ensureVisible without a frame, so a second one
/// checks the old layout and its first drag can carry a short card past unseen: pump around it
/// (rule 27). Every widget test scrolls through here or [scrollTo], never scrollUntilVisible itself.
Future<void> scrollToFinder(WidgetTester tester, Finder finder, {double delta = 300, Finder? scrollable}) async {
  await tester.pump();
  await tester.scrollUntilVisible(finder, delta, scrollable: scrollable ?? mainScrollable);
  await tester.pump();
}

/// Scroll the main list down to [key] (see [scrollToFinder]).
Future<void> scrollTo(WidgetTester tester, Key key) => scrollToFinder(tester, find.byKey(key));

/// Scroll the main list to [finder], let the page take [n] frames and tap it; with [after], [n] frames again after the
/// tap (S28: one home for four copies).
Future<void> scrollAndTap(WidgetTester tester, Finder finder, {bool after = false, int n = 12}) async {
  await scrollToFinder(tester, finder);
  await tester.ensureVisible(finder);
  await frames(tester, n);
  await tester.tap(finder);
  if (after) await frames(tester, n);
}

/// On the home page, open a method: scroll to its entry, then tap it. Since v6.1.0 the 西方 group (塔羅) sits
/// below the 東方 one, off a phone's first screen.
Future<void> openEntry(WidgetTester tester, String system) async {
  await scrollTo(tester, Key('entry-$system'));
  await tester.tap(find.byKey(Key('entry-$system')));
}

/// Whether the button keyed [key] can be pressed. The key is the app's button's (S30, buttons.dart); the Material
/// button that says so is inside it.
bool buttonEnabled(WidgetTester tester, Key key) => tester
    .widget<ButtonStyleButton>(
      find.descendant(of: find.byKey(key), matching: find.byWidgetPredicate((w) => w is ButtonStyleButton)),
    )
    .enabled;

/// From 首页 to 八字's chart: 八字排盘, then 排盘 with the form as it opens (S28: six tests had a copy).
Future<void> openBaziChart(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('entry-bazi')));
  await frames(tester, 10);
  await scrollTo(tester, const Key('compute-chart'));
  await tester.tap(find.byKey(const Key('compute-chart')));
  await frames(tester, 10);
}

/// 塔罗, 求签 and 算卦 are drawn only for a question (v11.1.0, the owner: 必须要有所求才能去求): types [question] into
/// the page's question field ([field]: `tarot-question`, `qiuqian-question` or `liuyao-question`), then pumps, so
/// the draw button is enabled before the next tap (rule 19).
Future<void> ask(WidgetTester tester, String field, [String question = '最近的工作會順利嗎？']) async {
  await tester.enterText(find.byKey(Key(field)), question);
  await tester.pump();
}

/// On the home page, open the ☰ menu (v8.1.0) and tap [key] in it: 个人资料, 语言, 设置, 内容审核 and the rest
/// live there. The caller pumps for whatever the tap opens.
Future<void> openFromMenu(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(const Key('open-menu')));
  // The drawer slides in (about 250 ms).
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.tap(find.byKey(Key(key)));
}

/// A fake v1 API. Authenticated routes require `Bearer <access>`; charts come from
/// fixtures; reports go pending → [finalReport].
class FakeApi {
  FakeApi({
    Map<String, dynamic>? finalReport,
    this.pendingPolls = 1,
    this.expireAccessOnce = false,
    this.email = 'me@example.com',
    this.pendingStage,
    this.history,
    this.username,
    this.emailVerified = false,
  })  : finalReport = finalReport ?? fixture('report_passed'),
        accountEmail = email;

  /// The account's logins as the server keeps them (v8.2.0): what /v1/me shows, changed by the account routes. A
  /// code sent by POST /v1/account/{email|phone} is always [code].
  String? username;
  String? accountEmail;
  bool emailVerified;
  String? phone;
  static const code = '123456';
  final _codeFor = <String, String>{};

  /// What delivers codes and mail here: "outbox" while the server has no provider.
  String delivery = 'outbox';

  /// 测算完成后发到邮箱 (v8.2.0, WP15.4).
  bool emailReports = false;

  /// /v1/me's staff role (S25): admin, manager or integrator; none by default.
  String? staff;

  /// GET /v1/east/daily (S26): the day's 东方 draw, 'qiuqian' (a 签) or 'liuyao' (a 卦); null, neither is served.
  String? eastDaily = 'qiuqian';

  /// 发到邮箱 (v9.0.0): the requests, as sent.
  final emailed = <Map<String, dynamic>>[];

  /// GET /v1/reports items, when a test needs other readings than the one 八字 report.
  final List<Map<String, dynamic>>? history;

  /// GET /v1/methods: the region's methods in entry order (v4.3.0). Tests of the order set it.
  List<String> methods = const ['bazi', 'tarot', 'qiuqian', 'liuyao', 'fengshui', 'astrology'];

  /// POST /v1/liuyao/layouts calls so far (v6.0.0).
  int layouts = 0;

  /// POST /v1/charts for 起名 (v4.5.0): a test's own chart in place of chart_naming.
  Map<String, dynamic>? namingChart;

  /// The signed-in user's email (`test…` accounts get a seeded default profile).
  final String email;

  /// Stage reported while pending (null = none yet).
  final String? pendingStage;

  final Map<String, dynamic> finalReport;
  int pendingPolls;

  /// Answer the first authenticated call with 401 to exercise token refresh.
  bool expireAccessOnce;
  final requests = <http.Request>[];

  /// The server preloaded every topic's 破除運勢 plan (locked until bought).
  bool preloadRemedies = false;

  /// A reviewer decided the held item (it leaves the queue).
  bool reviewed = false;

  /// Every request fails without a response (server unreachable).
  bool offline = false;

  /// 破除運勢 plans bought so far.
  final remedies = <Map<String, dynamic>>[];

  /// Whose chart the history's 八字 reading and 一生运势报告 are of, as the server keeps it (v6.2.0); null = none
  /// (a chart made before v6.2.0).
  Map<String, dynamic>? person;

  /// 追问 asked so far (v7.0.0), per reading path (`reports/<id>` or `life-reports/<id>`), oldest first. Each is
  /// answered with followup_passed after [followUpPolls] polls of the list.
  final followUps = <String, List<Map<String, dynamic>>>{};
  int followUpPolls = 1;
  final _pollsLeft = <String, int>{};

  /// The most 追问 a reading may have (the server's FOLLOWUP_LIMIT is 20).
  int followUpLimit = 20;

  /// false: every answer says the reading can't answer its question.
  bool followUpInScope = true;

  /// Asking answers with this problem instead, e.g. {'status': 409, 'code': 'followup_pending'}.
  Map<String, dynamic>? followUpError;

  /// 深度分析 (v10.0.0): the conversations so far by id, the questions the fake master plans, and whether its turns
  /// fail (the first one: failed; a later one: ready with what was said).
  final inquiries = <String, Map<String, dynamic>>{};
  int inquiryPlanned = 2;
  bool inquiryFails = false;

  /// 管理后台 (v11.2.0): an admin suspended the account: sign-in and every signed-in call answer 403
  /// account_suspended.
  bool suspended = false;

  /// 积分 (v11.0.0): off (`enabled: false`) unless a test turns them on. On, each AI request costs its price here at
  /// once (the server holds it, then charges what it cost); with less than that available it answers 402
  /// points_short. 充值 is simulated unless [pointsTopUp] says otherwise.
  bool pointsOn = false;
  int pointsBalance = 0;
  String pointsTopUp = 'simulated';
  final pointsEntries = <Map<String, dynamic>>[];
  final prices = <String, int>{'report': 688, 'inquiry': 747, 'life_report': 1208, 'followup': 270, 'remedy': 303};

  /// GET /v1/charts/{id}/quote requests so far, with their topics.
  final quoteTopics = <String?>[];

  /// 以往记录 (v8.0.0): the documents asked for, the records deleted and the charts filed under a person.
  final documents = <Map<String, dynamic>>[];
  final deleted = <String>[];
  final filed = <String, String>{};
  int _tokenSerial = 0;
  String access = 'access-0';

  Map<String, dynamic> get _pending => {
        ...finalReport,
        'status': 'pending',
        'layers': null,
        'ai_disclosure': null,
        if (pendingStage != null) 'progress': {'stage': pendingStage, 'attempt': 1, 'updated_at': '2026-10-26T00:00:00Z'},
      };

  Map<String, dynamic> _tokens() {
    _tokenSerial++;
    access = 'access-$_tokenSerial';
    return {'access_token': access, 'refresh_token': 'refresh-$_tokenSerial', 'token_type': 'Bearer', 'expires_in': 900};
  }

  late final client = MockClient((req) async {
    requests.add(req);
    if (offline) throw http.ClientException('Load failed', req.url);
    final path = req.url.path;
    // Calendar data generated from the real server functions (calendar.json).
    final cal = fixture('calendar');
    final q = req.url.queryParameters;
    if (req.method == 'GET' && path == '/v1/calendar/lunar') {
      return _json({'date': q['date'], ...(cal['day'] as Map<String, dynamic>)}, 200);
    }
    if (req.method == 'GET' && path == '/v1/calendar/lunar-months') {
      final months = (cal['months'] as Map)[q['year']] ?? (cal['months'] as Map)['1990'];
      return _json({'year': int.parse(q['year']!), 'months': months}, 200);
    }
    if (req.method == 'GET' && path == '/v1/calendar/solar') {
      final date = (cal['solar'] as Map)['${q['year']}-${q['month']}-${q['day']}-${q['leap']}'];
      return date == null
          ? _json({'title': 'Invalid request', 'status': 400}, 400)
          : _json({'date': date, 'lunar': (cal['day'] as Map)['lunar']}, 200);
    }
    // Birthplaces: real server data (places.json; CN trimmed to 廣東).
    if (req.method == 'GET' && path == '/v1/places') return _json(fixture('places')['index'] as Object, 200);
    if (req.method == 'GET' && path.startsWith('/v1/places/')) {
      final c = (fixture('places')['countries'] as Map)[path.split('/').last.toUpperCase()];
      return c == null ? _json({'title': 'not found', 'status': 404}, 404) : _json(c as Object, 200);
    }
    switch ((req.method, path)) {
      case ('POST', '/v1/auth/register'):
        if ((jsonDecode(req.body) as Map)['username'] == 'taken') {
          return _json(
            {'title': 'Authentication failed', 'detail': 'this username is taken', 'status': 409, 'code': 'username_taken'},
            409,
          );
        }
        return _json(_tokens(), 201);
      case ('POST', '/v1/auth/login'):
        final b = jsonDecode(req.body) as Map;
        if (b['password'] != 'long enough pw') {
          return _json({'title': 'Authentication failed', 'detail': 'email or password is incorrect', 'status': 401}, 401);
        }
        if (suspended) return _problem(403, 'this account has been suspended', 'account_suspended');
        return _json(_tokens(), 200);
      case ('POST', '/v1/auth/refresh'):
        return _json(_tokens(), 200);
      case ('POST', '/v1/auth/logout'):
        return http.Response('', 204);
    }
    if (req.headers['authorization'] != 'Bearer $access' || expireAccessOnce) {
      expireAccessOnce = false;
      return _json({'title': 'Authentication failed', 'status': 401}, 401);
    }
    if (suspended) return _problem(403, 'this account has been suspended', 'account_suspended');
    if (req.method == 'GET' && path == '/v1/me') return _json(_me, 200);
    // 积分 (v11.0.0): the balance and changes, 充值, a chart's prices.
    if (req.method == 'GET' && path == '/v1/points') {
      if (!pointsOn) return _json({'enabled': false}, 200);
      return _json({
        'enabled': true,
        'balance': pointsBalance,
        'held': 0,
        'available': pointsBalance,
        'top_up': pointsTopUp,
        'packs': [
          for (final (yuan, points, bonus) in const [(10, 1000, 0), (20, 2200, 10), (30, 3450, 15), (40, 4800, 20), (50, 6250, 25)])
            {'yuan': yuan, 'points': points, 'bonus_percent': bonus},
        ],
        'entries': pointsEntries,
        'holds': const [],
      }, 200);
    }
    if (req.method == 'POST' && path == '/v1/points/top-ups') {
      if (!pointsOn) return _problem(404, 'points are off', 'points_off');
      final yuan = (jsonDecode(req.body) as Map)['yuan'] as int;
      final points = const {10: 1000, 20: 2200, 30: 3450, 40: 4800, 50: 6250}[yuan]!;
      pointsBalance += points;
      final entry = <String, dynamic>{
        'id': '7a7a7a7a-0000-4000-8000-${pointsEntries.length.toString().padLeft(12, '0')}',
        'kind': 'topup',
        'points': points,
        'balance': pointsBalance,
        'created_at': '2026-10-29T08:00:00.000Z',
        'pack': {'yuan': yuan, 'points': points},
      };
      pointsEntries.insert(0, entry);
      return _json({'entry': entry, 'balance': pointsBalance, 'held': 0, 'available': pointsBalance}, 201);
    }
    final quote = RegExp(r'^/v1/charts/([^/]+)/quote$').firstMatch(path);
    if (req.method == 'GET' && quote != null) {
      if (!pointsOn) return _problem(404, 'points are off', 'points_off');
      quoteTopics.add(q['topics']);
      Map<String, int> price(String kind) => {'points': prices[kind]!, 'hold': (prices[kind]! * 1.5).ceil()};
      return _json({
        'report': price('report'),
        'inquiry': {...price('inquiry'), 'hold': prices['inquiry'], 'max_questions': 6},
        'life_report': price('life_report'),
      }, 200);
    }
    // The account's logins and settings (v8.2.0).
    if (path == '/v1/account/username' && req.method == 'PUT') {
      final name = (jsonDecode(req.body) as Map)['username'] as String;
      if (name.toLowerCase() == 'taken') return _problem(409, 'this username is taken', 'username_taken');
      username = name;
      return _json(_me, 200);
    }
    final contact = RegExp(r'^/v1/account/(email|phone)(/verify)?$').firstMatch(path);
    if (contact != null) {
      final kind = contact[1]!;
      if (req.method == 'DELETE') {
        if (kind == 'email') {
          accountEmail = null;
          emailVerified = false;
          emailReports = false;
        } else {
          phone = null;
        }
        return _json(_me, 200);
      }
      final body = jsonDecode(req.body) as Map;
      // As the server reads a local number: in the account's region (HK).
      final raw = (body[kind] as String).trim();
      final digits = raw.replaceAll(RegExp(r'\D'), '');
      final value = kind == 'email' ? raw : (raw.startsWith('+') ? '+$digits' : '+852$digits');
      if (contact[2] == null) {
        if (value == '+85200000000') return _problem(409, 'this number is bound to another account', 'phone_taken');
        _codeFor[kind] = value;
        final masked = kind == 'phone' ? '+852 ****${value.substring(value.length - 4)}' : '${value[0]}***@${value.split('@').last}';
        return _json({'sent_to': masked, 'expires_at': '2026-10-29T01:10:00Z', 'delivery': delivery}, 202);
      }
      if (_codeFor[kind] != value) return _problem(400, 'no code was sent for this; ask for one first', 'no_code');
      if (body['code'] != code) return _problem(400, 'the code is not right', 'wrong_code');
      _codeFor.remove(kind);
      if (kind == 'phone') {
        phone = value;
      } else {
        accountEmail = value;
        emailVerified = true;
      }
      return _json(_me, 200);
    }
    if (path == '/v1/account/settings') {
      if (req.method == 'PATCH') {
        final on = (jsonDecode(req.body) as Map)['email_reports'] as bool;
        if (on && !emailVerified) return _problem(409, 'verify an email first', 'email_unverified');
        emailReports = on;
      }
      return _json({
        'settings': {'email_reports': emailReports},
        'delivery': {'mail': delivery, 'sms': delivery},
      }, 200);
    }
    // 内容审核: one held report (review_report.json, generated from the server).
    if (path == '/v1/admin/reviews' && req.method == 'GET') {
      final item = {...fixture('review_report')}..remove('content');
      return _json({'items': reviewed ? const [] : [item]}, 200);
    }
    if (path.startsWith('/v1/admin/reviews/')) {
      if (req.method == 'POST') {
        reviewed = true;
        final b = jsonDecode(req.body) as Map;
        return _json({...fixture('review_report'), 'decision': {'decision': b['decision'], 'by': 'admin', 'at': '2026-10-26T00:00:00Z'}}, 200);
      }
      return _json(fixture('review_report'), 200);
    }
    if (req.method == 'GET' && path == '/v1/reports' && history != null) {
      return _json({'items': [for (final h in history!) if (!deleted.contains(h['report_id'])) _filedTo(h)]}, 200);
    }
    if (req.method == 'GET' && path == '/v1/reports') {
      return _json({
        'items': [
          {
            'report_id': finalReport['report_id'],
            'chart_id': '22222222-2222-4222-8222-222222222222',
            'status': 'passed',
            'created_at': '2026-10-25T00:00:00.000Z',
            'updated_at': '2026-10-25T00:00:00.000Z',
            'locale': 'zh-Hant',
            'topics': ['wuxing'],
            'chart': {'system': 'bazi', 'four_pillars': '庚午 己卯 己卯 辛未', 'civil_local': '1990-03-15T14:30:00'},
            'person': ?person,
          },
        ],
      }, 200);
    }
    if (req.method == 'DELETE' && path == '/v1/account') {
      return _json({'deleted': {'account': true, 'charts': 1, 'reports': 1}, 'completed_at': '2026-10-26T00:00:00Z'}, 200);
    }
    if (req.method == 'POST' && path == '/v1/charts') {
      final body = jsonDecode(req.body) as Map;
      // 塔罗, 求签 and 算卦 are drawn only for a question (v11.1.0), as the server has it.
      if (const ['tarot', 'qiuqian', 'liuyao'].contains(body['system']) &&
          ((body['question'] as String?) ?? '').trim().isEmpty) {
        return _problem(400, 'ask your question first', 'question_required');
      }
      final tarot = switch (body['spread']) {
        'celtic_cross' => 'chart_tarot_celtic',
        'single' => 'chart_tarot_single',
        'two_paths' => 'chart_tarot_two_paths',
        'relationship' => 'chart_tarot_relationship',
        _ => 'chart_tarot',
      };
      if (body['system'] == 'naming' && namingChart != null) return _json(namingChart!, 201);
      return _json(
        fixture(switch (body['system']) {
          'tarot' => tarot,
          'qiuqian' => 'chart_qiuqian',
          'fengshui' => 'chart_fengshui',
          'naming' => 'chart_naming',
          'liuyao' => 'chart_liuyao',
          _ => 'chart_bazi',
        }),
        201,
      );
    }
    // The region's methods in entry order (v4.3.0): the default order unless a test sets [methods].
    // 算卦's coins laid out for a pick cast (v6.0.0): their id and commitment, the coins staying here.
    if (req.method == 'POST' && path == '/v1/liuyao/layouts') {
      layouts++;
      return _json({
        'draw_id': '9a9a9a9a-9a9a-49a9-89a9-9a9a9a9a9a9a',
        'size': 24,
        'picks': 18,
        'commitment': 'sha256:${'0' * 64}',
      }, 201);
    }
    // The cast that report_liuyao_passed reads (v6.0.0).
    if (req.method == 'GET' && path == '/v1/charts/56565656-5656-4565-8565-565656565656') {
      return _json(fixture('chart_liuyao'), 200);
    }
    if (req.method == 'GET' && path == '/v1/methods') {
      return _json({
        'region': 'HK',
        'matrix_version': '0.2.0',
        'methods': [for (final m in methods) {'system': m, 'entry_weight': 1}],
      }, 200);
    }
    // The 求籤 draw that report_qiuqian_passed reads (v4.3.0).
    if (req.method == 'GET' && path == '/v1/charts/dddddddd-dddd-4ddd-8ddd-dddddddddddd') {
      return _json(fixture('chart_qiuqian'), 200);
    }
    // The 起名 candidates that report_naming_passed reads (v4.5.0).
    if (req.method == 'GET' && path == '/v1/charts/34343434-3434-4434-8434-343434343434') {
      return _json(fixture('chart_naming'), 200);
    }
    // The 风水 room that report_fengshui_passed reads (v4.4.0).
    if (req.method == 'GET' && path == '/v1/charts/ffffffff-ffff-4fff-8fff-ffffffffffff') {
      return _json(fixture('chart_fengshui'), 200);
    }
    // 深度分析 (v10.0.0): the fake master asks [inquiryPlanned] questions, one per poll after each answer, then is done.
    if (req.method == 'POST' && path == '/v1/inquiries') {
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      final goal = (body['goal'] as String? ?? '').trim();
      if (goal.characters.length < 4) return _problem(400, 'a 深度分析 needs a clear goal', 'goal_required');
      final paid = _pay('inquiry');
      if (paid != null) return paid;
      final id = '99999999-9999-4999-8999-${(inquiries.length + 1).toString().padLeft(12, '0')}';
      inquiries[id] = {
        'inquiry_id': id,
        'chart_id': body['chart_id'],
        'status': 'thinking',
        'goal': goal,
        'max_questions': 6,
        'turns': <Map<String, dynamic>>[],
        'created_at': '2026-10-29T00:00:00Z',
        'updated_at': '2026-10-29T00:00:00Z',
      };
      return _json(inquiries[id]!, 202);
    }
    final iq = RegExp(r'^/v1/inquiries/([^/]+)(/answers)?$').firstMatch(path);
    if (iq != null) {
      final inquiry = inquiries[iq.group(1)];
      if (inquiry == null) return _json({'title': 'not found', 'status': 404}, 404);
      final turns = inquiry['turns'] as List<Map<String, dynamic>>;
      if (req.method == 'POST') {
        if (inquiry['status'] != 'asking') return _problem(409, 'the master has no question waiting', 'inquiry_not_asking');
        turns.last['answer'] = (jsonDecode(req.body) as Map)['answer'];
        inquiry['status'] = 'thinking';
        return _json(inquiry, 202);
      }
      if (inquiry['status'] == 'thinking') {
        if (inquiryFails) {
          inquiry['status'] = turns.isEmpty ? 'failed' : 'ready';
        } else if (turns.length < inquiryPlanned) {
          final n = turns.length + 1;
          turns.add({'say': '（示範）大師的第$n句話。', 'question': '（示範）大師的第$n個問題？'});
          inquiry
            ..['status'] = 'asking'
            ..['planned'] = inquiryPlanned;
        } else {
          inquiry
            ..['status'] = 'ready'
            ..['closing'] = '（示範）好，我了解了，現在給你做最終解答。'
            ..['understanding'] = '（示範）你最想知道的事';
        }
      }
      return _json(inquiry, 200);
    }
    if (req.method == 'POST' && path == '/v1/reports') {
      final paid = _pay('report');
      if (paid != null) return paid;
      final id = (jsonDecode(req.body) as Map)['inquiry_id'] as String?;
      if (id != null && inquiries[id] != null) {
        inquiries[id]!
          ..['status'] = 'closed'
          ..['report_id'] = finalReport['report_id'];
      }
      return _json(_pending, 202);
    }
    // 以往记录 (v8.0.0): a document's bytes (a PDF's or a zip's first bytes are enough); deleting; filing.
    if (req.method == 'POST' && path == '/v1/documents') {
      documents.add(jsonDecode(req.body) as Map<String, dynamic>);
      final pdf = documents.last['format'] == 'pdf';
      return http.Response.bytes(pdf ? utf8.encode('%PDF-1.7') : [0x50, 0x4b, 0x03, 0x04], 200);
    }
    // 发到邮箱 (v9.0.0): only to a verified email.
    if (req.method == 'POST' && path == '/v1/documents/email') {
      if (!emailVerified) return _problem(409, 'verify an email first', 'email_unverified');
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      emailed.add(body);
      final to = '${accountEmail![0]}***@${accountEmail!.split('@').last}';
      return _json({'sent_to': to, 'count': (body['documents'] as List).length, 'delivery': delivery}, 202);
    }
    final gone = RegExp(r'^/v1/(?:life-)?reports/([^/]+)$').firstMatch(path);
    if (req.method == 'DELETE' && gone != null) {
      deleted.add(gone.group(1)!);
      return _json({'deleted': {'reports': 1, 'remedies': 0, 'followups': 0, 'charts': 1}}, 200);
    }
    final filing = RegExp(r'^/v1/charts/([^/]+)/person$').firstMatch(path);
    if (req.method == 'POST' && filing != null) {
      final name = (jsonDecode(req.body) as Map)['name'] as String;
      filed[filing.group(1)!] = name;
      return _json({'chart_id': filing.group(1), if (name.isNotEmpty) 'person': {'name': name}}, 200);
    }
    // 追问 (v7.0.0): the list answers a pending one once its polls run out; asking adds a pending one.
    final asked = RegExp(r'^/v1/((?:life-)?reports/[^/]+)/followups$').firstMatch(path);
    if (asked != null && req.method == 'GET') {
      final items = followUps[asked.group(1)!] ?? [];
      for (final f in items.where((f) => f['status'] == 'pending')) {
        final id = f['followup_id'] as String;
        final left = _pollsLeft[id] ?? 0;
        if (left > 0) {
          _pollsLeft[id] = left - 1;
          continue;
        }
        final done = fixture('followup_passed');
        f
          ..['status'] = 'passed'
          ..['answer'] = {...(done['answer'] as Map<String, dynamic>), 'in_scope': followUpInScope}
          ..['ai_disclosure'] = done['ai_disclosure'];
      }
      return _json({
        'limit': followUpLimit,
        'items': items,
        if (pointsOn) 'price': {'points': prices['followup'], 'hold': (prices['followup']! * 1.5).ceil()},
      }, 200);
    }
    if (asked != null && req.method == 'POST') {
      if (followUpError != null) return _json(followUpError!, followUpError!['status'] as int);
      final paid = _pay('followup');
      if (paid != null) return paid;
      final list = followUps.putIfAbsent(asked.group(1)!, () => []);
      final id = '45454545-0000-4000-8000-${list.length.toString().padLeft(12, '0')}';
      final item = <String, dynamic>{
        'followup_id': id,
        'question': (jsonDecode(req.body) as Map)['question'],
        'status': 'pending',
        'created_at': '2026-10-28T00:00:00.000Z',
        'updated_at': '2026-10-28T00:00:00.000Z',
      };
      list.add(item);
      _pollsLeft[id] = followUpPolls;
      return _json(item, 202);
    }
    // 一生运势报告: real engine facts for the owner's sample (life_passed.json).
    if (req.method == 'POST' && path == '/v1/life-reports') {
      final paid = _pay('life_report');
      if (paid != null) return paid;
      return _json({...fixture('life_passed'), 'status': 'pending', 'facts': null, 'layers': null}, 202);
    }
    if (req.method == 'GET' && path == '/v1/life-reports') {
      final life = {...fixture('life_passed'), 'facts': null, 'layers': null, 'person': ?person};
      return _json({'items': [if (!deleted.contains(life['life_report_id'])) _filedTo(life)]}, 200);
    }
    if (req.method == 'GET' && path.startsWith('/v1/life-reports/')) {
      return _json({...fixture('life_passed'), 'person': ?person}, 200);
    }
    if (req.method == 'GET' && path == '/v1/charts/66666666-6666-4666-8666-666666666666') {
      return _json(fixture('chart_life'), 200);
    }
    // The 八字 chart that report_passed reads: its four pillars head the reading (v3.4.0).
    if (req.method == 'GET' && path == '/v1/charts/22222222-2222-4222-8222-222222222222') {
      return _json(fixture('chart_bazi'), 200);
    }
    // 每日一牌: the single-card draw, for any date.
    if (req.method == 'GET' && path == '/v1/tarot/daily') {
      return _json({...fixture('chart_tarot_single'), 'date': '2026-10-25'}, 200);
    }
    // 今日一卦 / 今日一签 (S26): the day's [eastDaily] draw, for any date; 451 when it is null.
    if (req.method == 'GET' && path == '/v1/east/daily') {
      return switch (eastDaily) {
        'qiuqian' => _json({...fixture('chart_qiuqian'), 'date': '2026-10-25'}, 200),
        'liuyao' => _json({...fixture('chart_liuyao'), 'date': '2026-10-25'}, 200),
        _ => _problem(451, 'neither 求签 nor 算卦 is available here', 'unavailable'),
      };
    }
    // The three-card draw that report_tarot_passed reads.
    if (req.method == 'GET' && path == '/v1/charts/33333333-3333-4333-8333-333333333333') {
      return _json(fixture('chart_tarot'), 200);
    }
    // 分享图 (v4.2.0): the server's JPEG; here a JPEG's first bytes are enough.
    if (req.method == 'GET' && RegExp(r'^/v1/reports/[^/]+/share\.jpg$').hasMatch(path)) {
      return http.Response.bytes([0xff, 0xd8, 0xff, 0xe0, 0, 0x10], 200, headers: {'content-type': 'image/jpeg'});
    }
    // 破除運勢: price + plans. preloadRemedies: every topic ready but locked, and
    // buying unlocks at once (200); otherwise buying returns pending (202) and polling the plan.
    final remedyOf = RegExp(r'^/v1/reports/[^/]+/remedies$');
    if (req.method == 'GET' && remedyOf.hasMatch(path)) {
      final bought = {for (final r in remedies) r['topic']};
      final locked = preloadRemedies
          ? [
              for (final t in (finalReport['topics'] as List).cast<String>())
                if (!bought.contains(t))
                  {...fixture('remedy_passed'), 'topic': t, 'locked': true, 'content': null, 'payment': null},
            ]
          : const [];
      return _json({
        'price': {'amount': 18, 'currency': 'HKD'},
        'items': [...remedies, ...locked],
        if (pointsOn) 'points': {'points': prices['remedy'], 'hold': (prices['remedy']! * 1.5).ceil()},
      }, 200);
    }
    if (req.method == 'POST' && remedyOf.hasMatch(path)) {
      final paid = _pay('remedy');
      if (paid != null) return paid;
      final topic = (jsonDecode(req.body) as Map)['topic'];
      final plan = {
        ...fixture('remedy_passed'),
        'topic': topic,
        // Paid in 积分 (v11.0.0) when they are on.
        if (pointsOn) 'payment': {'status': 'points'},
      };
      remedies.add(plan);
      if (preloadRemedies) return _json(plan, 200);
      return _json({...plan, 'status': 'pending', 'content': null}, 202);
    }
    if (req.method == 'GET' && path.startsWith('/v1/remedies/')) {
      return _json(remedies.isEmpty ? fixture('remedy_passed') : remedies.last, 200);
    }
    if (req.method == 'GET' && path.startsWith('/v1/reports/')) {
      // pendingPolls < 0: stay pending forever.
      if (pendingPolls != 0) {
        if (pendingPolls > 0) pendingPolls--;
        return _json(_pending, 200);
      }
      return _json(finalReport, 200);
    }
    return _json({'title': 'not found', 'status': 404}, 404);
  });

  /// 积分 (v11.0.0): what an AI request of [kind] costs, taken at once; a 402 points_short problem when short.
  http.Response? _pay(String kind) {
    if (!pointsOn) return null;
    final price = prices[kind]!;
    if (pointsBalance < price) {
      return _json({
        'title': 'not enough 积分',
        'status': 402,
        'code': 'points_short',
        'need': price,
        'available': pointsBalance,
      }, 402);
    }
    pointsBalance -= price;
    pointsEntries.insert(0, {
      'id': '7b7b7b7b-0000-4000-8000-${pointsEntries.length.toString().padLeft(12, '0')}',
      'kind': 'charge',
      'points': -price,
      'balance': pointsBalance,
      'created_at': '2026-10-29T09:00:00.000Z',
      'for': {'kind': kind, 'id': '00000000-0000-4000-8000-000000000000', 'system': 'bazi'},
      'basis': 'measured',
      'usd': price / 1953.96,
    });
    return null;
  }

  /// A listed record with the person its chart was filed under since (归类到…, v8.0.0).
  Map<String, dynamic> _filedTo(Map<String, dynamic> item) {
    final name = filed[item['chart_id']];
    if (name == null) return item;
    return {...item}..['person'] = name.isEmpty ? null : {'name': name};
  }

  static http.Response _json(Object body, int status) => http.Response.bytes(
        utf8.encode(jsonEncode(body)),
        status,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  /// A problem as the server's account routes write it: the message as the title, and its code.
  static http.Response _problem(int status, String title, String code) =>
      _json({'title': title, 'status': status, 'code': code}, status);

  /// GET /v1/me, from the account as it stands.
  Map<String, Object?> get _me => {
        'id': 'u1',
        'username': ?username,
        'email': accountEmail,
        'email_verified': emailVerified,
        'phone': ?phone,
        'country': 'HK',
        'locale': 'zh-Hant',
        'sign_in_methods': ['password'],
        'settings': {'email_reports': emailReports},
        'created_at': '2026-10-26T00:00:00Z',
        // The dev reviewer (MINGLI_ADMINS default).
        'role': email == 'admin' || username == 'admin' ? 'admin' : 'user',
        'staff': ?staff,
      };
}

/// [pollInterval] must be non-zero when a report never leaves pending, or the
/// poller spins forever without letting fake time advance.
Widget testApp(
  FakeApi api, {
  bool signedIn = true,
  TokenStore? tokens,
  ProfileStore? profiles,
  Duration pollInterval = Duration.zero,
  // Most widget tests assert 繁體 copy; null = the app's real default (简体).
  Locale? locale = zhHant,
  // Replaced providers, e.g. the share sheet.
  List<Override> overrides = const [],
  // The device's saved settings (the language picked, v5.1.0).
  SettingsStore? settings,
  // 外观 (v12.1.0); null = the system's.
  ThemeMode? theme,
  // 跟随时间 (S27): the theme by the time of day (the app's default where nothing was picked).
  bool byTime = false,
}) {
  final store = tokens ?? InMemoryTokenStore(signedIn ? Tokens(api.access, 'refresh-0') : null);
  return ProviderScope(
    overrides: [
      if (locale != null || theme != null || byTime)
        settingsProvider.overrideWith(() => SettingsNotifier(locale ?? zhHans, theme ?? ThemeMode.system, byTime)),
      settingsStoreProvider.overrideWithValue(settings ?? InMemorySettingsStore()),
      tokenStoreProvider.overrideWithValue(store),
      profileStoreProvider.overrideWithValue(profiles ?? InMemoryProfileStore()),
      apiClientProvider.overrideWith(
        (ref) => ApiClient(
          baseUrl: 'http://api.test',
          tokens: store,
          client: api.client,
          onSignedOut: () => ref.invalidate(authProvider),
        ),
      ),
      pollIntervalProvider.overrideWithValue(pollInterval),
      // rootBundle caches asset futures across tests, and a future created in a
      // previous test's fake-async zone never completes in the next one.
      termsProvider.overrideWithValue(AsyncValue.data(testTerms)),
      ...overrides,
    ],
    child: const MingliApp(),
  );
}
