import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mingli_app/config.dart';
import 'package:mingli_app/data/api_client.dart';
import 'package:mingli_app/data/token_store.dart';

void main() {
  group('resolveApiBase', () {
    test('a phone opening the dev server by LAN address calls the same host', () {
      expect(resolveApiBase(web: true, page: Uri.parse('http://192.168.1.5:5000/#/')), 'http://192.168.1.5:8787');
    });

    test('?api= on the page wins (Pages test with an https tunnel)', () {
      expect(
        resolveApiBase(
          web: true,
          page: Uri.parse('https://leonfighter1.github.io/suanming/?api=https://x.trycloudflare.com/'),
          define: 'http://a',
        ),
        'https://x.trycloudflare.com',
      );
      // Only http(s) URLs are accepted.
      expect(resolveApiBase(web: true, page: Uri.parse('http://localhost:5000/?api=javascript:alert(1)')), 'http://127.0.0.1:8787');
    });

    test('build setting next; an https page never guesses its own host', () {
      expect(
        resolveApiBase(web: true, page: Uri.parse('https://leonfighter1.github.io/suanming/'), define: 'https://api.example'),
        'https://api.example',
      );
      expect(resolveApiBase(web: true, page: Uri.parse('https://leonfighter1.github.io/suanming/')), 'http://127.0.0.1:8787');
    });

    test('"origin": the API serves the page (public tunnel)', () {
      expect(resolveApiBase(web: true, page: Uri.parse('https://abc.trycloudflare.com/#/'), define: 'origin'), 'https://abc.trycloudflare.com');
    });

    test('local browser, Android emulator and desktop defaults', () {
      expect(resolveApiBase(web: true, page: Uri.parse('http://127.0.0.1:5000/')), 'http://127.0.0.1:8787');
      expect(resolveApiBase(web: true, page: Uri.parse('http://localhost:5000/')), 'http://127.0.0.1:8787');
      expect(resolveApiBase(web: false, android: true), 'http://10.0.2.2:8787');
      expect(resolveApiBase(web: false), 'http://127.0.0.1:8787');
    });
  });

  test('a network failure becomes ApiUnreachable with the address it tried', () async {
    final api = ApiClient(
      baseUrl: 'http://127.0.0.1:8787',
      tokens: InMemoryTokenStore(null),
      client: MockClient((_) async => throw http.ClientException('Load failed')),
    );
    await expectLater(
      api.login('xumei', 'xumei'),
      throwsA(isA<ApiUnreachable>().having((e) => e.baseUrl, 'baseUrl', 'http://127.0.0.1:8787')),
    );
  });
}
