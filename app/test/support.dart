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
  FakeApi({Map<String, dynamic>? finalReport, this.pendingPolls = 1, this.expireAccessOnce = false})
      : finalReport = finalReport ?? fixture('report_passed');

  final Map<String, dynamic> finalReport;
  int pendingPolls;

  /// Answer the first authenticated call with 401 to exercise token refresh.
  bool expireAccessOnce;
  final requests = <http.Request>[];
  int _tokenSerial = 0;
  String access = 'access-0';

  Map<String, dynamic> get _pending => {...finalReport, 'status': 'pending', 'layers': null, 'ai_disclosure': null};

  Map<String, dynamic> _tokens() {
    _tokenSerial++;
    access = 'access-$_tokenSerial';
    return {'access_token': access, 'refresh_token': 'refresh-$_tokenSerial', 'token_type': 'Bearer', 'expires_in': 900};
  }

  late final client = MockClient((req) async {
    requests.add(req);
    final path = req.url.path;
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
      return _json({'id': 'u1', 'email': 'me@example.com', 'country': 'HK', 'locale': 'zh-Hant', 'sign_in_methods': ['password'], 'created_at': '2026-10-26T00:00:00Z'}, 200);
    }
    if (req.method == 'DELETE' && path == '/v1/account') {
      return _json({'deleted': {'account': true, 'charts': 1, 'reports': 1}, 'completed_at': '2026-10-26T00:00:00Z'}, 200);
    }
    if (req.method == 'POST' && path == '/v1/charts') {
      final system = (jsonDecode(req.body) as Map)['system'];
      return _json(fixture(system == 'tarot' ? 'chart_tarot' : 'chart_bazi'), 201);
    }
    if (req.method == 'POST' && path == '/v1/reports') return _json(_pending, 202);
    if (req.method == 'GET' && path.startsWith('/v1/reports/')) {
      if (pendingPolls > 0) {
        pendingPolls--;
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

Widget testApp(FakeApi api, {bool signedIn = true, TokenStore? tokens}) {
  final store = tokens ?? InMemoryTokenStore(signedIn ? Tokens(api.access, 'refresh-0') : null);
  return ProviderScope(
    overrides: [
      tokenStoreProvider.overrideWithValue(store),
      apiClientProvider.overrideWith(
        (ref) => ApiClient(
          baseUrl: 'http://api.test',
          tokens: store,
          client: api.client,
          onSignedOut: () => ref.invalidate(authProvider),
        ),
      ),
      pollIntervalProvider.overrideWithValue(Duration.zero),
      // rootBundle caches asset futures across tests, and a future created in a
      // previous test's fake-async zone never completes in the next one.
      termsProvider.overrideWithValue(AsyncValue.data(testTerms)),
    ],
    child: const MingliApp(),
  );
}
