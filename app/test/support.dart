import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mingli_app/app.dart';
import 'package:mingli_app/application/providers.dart';
import 'package:mingli_app/data/api_client.dart';
import 'package:mingli_app/data/profile_store.dart';
import 'package:mingli_app/data/token_store.dart';
import 'package:mingli_app/domain/terms.dart';

/// Fixtures are generated from the real engine + pipeline by `npm run sync:app`.
Map<String, dynamic> fixture(String name) =>
    jsonDecode(File('test/fixtures/$name.json').readAsStringSync()) as Map<String, dynamic>;

final testTerms = Terms.parse(
  File('assets/i18n/terms.json').readAsStringSync(),
  File('assets/i18n/tarot_deck.json').readAsStringSync(),
);

/// The page's main vertical list (pages also contain horizontal timelines).
final mainScrollable = find.byType(Scrollable).first;

/// A fake v1 API. Authenticated routes require `Bearer <access>`; charts come from
/// fixtures; reports go pending → [finalReport].
class FakeApi {
  FakeApi({
    Map<String, dynamic>? finalReport,
    this.pendingPolls = 1,
    this.expireAccessOnce = false,
    this.email = 'me@example.com',
    this.pendingStage,
  }) : finalReport = finalReport ?? fixture('report_passed');

  /// The signed-in user's email (`test…` accounts get a seeded default profile).
  final String email;

  /// Stage reported while pending (null = none yet).
  final String? pendingStage;

  final Map<String, dynamic> finalReport;
  int pendingPolls;

  /// Answer the first authenticated call with 401 to exercise token refresh.
  bool expireAccessOnce;
  final requests = <http.Request>[];

  /// 破除運勢 plans bought so far.
  final remedies = <Map<String, dynamic>>[];
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
      return _json({'id': 'u1', 'email': email, 'country': 'HK', 'locale': 'zh-Hant', 'sign_in_methods': ['password'], 'created_at': '2026-10-26T00:00:00Z'}, 200);
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
          },
        ],
      }, 200);
    }
    if (req.method == 'DELETE' && path == '/v1/account') {
      return _json({'deleted': {'account': true, 'charts': 1, 'reports': 1}, 'completed_at': '2026-10-26T00:00:00Z'}, 200);
    }
    if (req.method == 'POST' && path == '/v1/charts') {
      final system = (jsonDecode(req.body) as Map)['system'];
      return _json(fixture(system == 'tarot' ? 'chart_tarot' : 'chart_bazi'), 201);
    }
    if (req.method == 'POST' && path == '/v1/reports') return _json(_pending, 202);
    // 破除運勢: price + bought plans; buying returns pending, polling returns the plan.
    final remedyOf = RegExp(r'^/v1/reports/[^/]+/remedies$');
    if (req.method == 'GET' && remedyOf.hasMatch(path)) {
      return _json({'price': {'amount': 18, 'currency': 'HKD'}, 'items': remedies}, 200);
    }
    if (req.method == 'POST' && remedyOf.hasMatch(path)) {
      final topic = (jsonDecode(req.body) as Map)['topic'];
      final r = {...fixture('remedy_passed'), 'topic': topic, 'status': 'pending', 'content': null};
      remedies.add({...fixture('remedy_passed'), 'topic': topic});
      return _json(r, 202);
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
}) {
  final store = tokens ?? InMemoryTokenStore(signedIn ? Tokens(api.access, 'refresh-0') : null);
  return ProviderScope(
    overrides: [
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
    ],
    child: const MingliApp(),
  );
}
