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

/// On the home page, open a method: scroll to its entry, then tap it. Since v6.1.0 the 西方 group (塔羅) sits
/// below the 東方 one, off a phone's first screen.
Future<void> openEntry(WidgetTester tester, String system) async {
  await scrollTo(tester, Key('entry-$system'));
  await tester.tap(find.byKey(Key('entry-$system')));
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
  }) : finalReport = finalReport ?? fixture('report_passed');

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
        return _json(_tokens(), 201);
      case ('POST', '/v1/auth/login'):
        final b = jsonDecode(req.body) as Map;
        if (b['password'] != 'long enough pw') {
          return _json({'title': 'Authentication failed', 'detail': 'email or password is incorrect', 'status': 401}, 401);
        }
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
    if (req.method == 'GET' && path == '/v1/me') {
      return _json({
        'id': 'u1',
        'email': email,
        'country': 'HK',
        'locale': 'zh-Hant',
        'sign_in_methods': ['password'],
        'created_at': '2026-10-26T00:00:00Z',
        // The dev reviewer (MINGLI_ADMINS default).
        'role': email == 'admin' ? 'admin' : 'user',
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
    if (req.method == 'GET' && path == '/v1/reports' && history != null) return _json({'items': history}, 200);
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
    if (req.method == 'POST' && path == '/v1/reports') return _json(_pending, 202);
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
      return _json({'limit': followUpLimit, 'items': items}, 200);
    }
    if (asked != null && req.method == 'POST') {
      if (followUpError != null) return _json(followUpError!, followUpError!['status'] as int);
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
      return _json({...fixture('life_passed'), 'status': 'pending', 'facts': null, 'layers': null}, 202);
    }
    if (req.method == 'GET' && path == '/v1/life-reports') {
      return _json({'items': [{...fixture('life_passed'), 'facts': null, 'layers': null, 'person': ?person}]}, 200);
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
      return _json({'price': {'amount': 18, 'currency': 'HKD'}, 'items': [...remedies, ...locked]}, 200);
    }
    if (req.method == 'POST' && remedyOf.hasMatch(path)) {
      final topic = (jsonDecode(req.body) as Map)['topic'];
      final plan = {...fixture('remedy_passed'), 'topic': topic};
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

  static http.Response _json(Object body, int status) => http.Response.bytes(
        utf8.encode(jsonEncode(body)),
        status,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
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
}) {
  final store = tokens ?? InMemoryTokenStore(signedIn ? Tokens(api.access, 'refresh-0') : null);
  return ProviderScope(
    overrides: [
      if (locale != null) settingsProvider.overrideWith(() => SettingsNotifier(locale)),
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
