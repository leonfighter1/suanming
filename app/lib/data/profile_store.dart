import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Per-account key/value storage for the profile book (encrypted on device).
abstract class ProfileStore {
  Future<String?> read(String userId);
  Future<void> write(String userId, String value);
  Future<void> delete(String userId);
}

class SecureProfileStore implements ProfileStore {
  SecureProfileStore([FlutterSecureStorage? s]) : _s = s ?? const FlutterSecureStorage();
  final FlutterSecureStorage _s;
  String _key(String userId) => 'profiles:$userId';

  @override
  Future<String?> read(String userId) => _s.read(key: _key(userId));
  @override
  Future<void> write(String userId, String value) => _s.write(key: _key(userId), value: value);
  @override
  Future<void> delete(String userId) => _s.delete(key: _key(userId));
}

class InMemoryProfileStore implements ProfileStore {
  final Map<String, String> data = {};
  @override
  Future<String?> read(String userId) async => data[userId];
  @override
  Future<void> write(String userId, String value) async => data[userId] = value;
  @override
  Future<void> delete(String userId) async => data.remove(userId);
}
