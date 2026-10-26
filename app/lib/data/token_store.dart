import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class Tokens {
  const Tokens(this.access, this.refresh);
  final String access;
  final String refresh;
}

abstract class TokenStore {
  Future<Tokens?> read();
  Future<void> write(Tokens t);
  Future<void> clear();
}

/// Keychain (iOS) / Keystore-backed storage (Android).
class SecureTokenStore implements TokenStore {
  SecureTokenStore([FlutterSecureStorage? storage]) : _s = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _s;
  static const _a = 'access_token';
  static const _r = 'refresh_token';

  @override
  Future<Tokens?> read() async {
    final a = await _s.read(key: _a);
    final r = await _s.read(key: _r);
    return a == null || r == null ? null : Tokens(a, r);
  }

  @override
  Future<void> write(Tokens t) async {
    await _s.write(key: _a, value: t.access);
    await _s.write(key: _r, value: t.refresh);
  }

  @override
  Future<void> clear() async {
    await _s.delete(key: _a);
    await _s.delete(key: _r);
  }
}

class InMemoryTokenStore implements TokenStore {
  InMemoryTokenStore([this._t]);
  Tokens? _t;
  @override
  Future<Tokens?> read() async => _t;
  @override
  Future<void> write(Tokens t) async => _t = t;
  @override
  Future<void> clear() async => _t = null;
}
