import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The reader's own settings on this device (v5.1.0): the language they picked, so it survives a restart
/// or a reload. Secure storage, like the profile book.
abstract class SettingsStore {
  /// The API code of the language last picked ('zh-Hans', 'zh-Hant'; 'en' from before v5.4.0), or null.
  Future<String?> language();
  Future<void> setLanguage(String apiLocale);
}

class SecureSettingsStore implements SettingsStore {
  SecureSettingsStore([FlutterSecureStorage? s]) : _s = s ?? const FlutterSecureStorage();
  final FlutterSecureStorage _s;
  static const _key = 'settings:language';

  @override
  Future<String?> language() => _s.read(key: _key);
  @override
  Future<void> setLanguage(String apiLocale) => _s.write(key: _key, value: apiLocale);
}

class InMemorySettingsStore implements SettingsStore {
  String? saved;
  @override
  Future<String?> language() async => saved;
  @override
  Future<void> setLanguage(String apiLocale) async => saved = apiLocale;
}
