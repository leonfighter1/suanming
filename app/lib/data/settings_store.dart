import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The reader's own settings on this device (v5.1.0): the language they picked and, since v12.1.0, the theme, so they
/// survive a restart or a reload. Secure storage, like the profile book.
abstract class SettingsStore {
  /// The API code of the language last picked ('zh-Hans', 'zh-Hant'; 'en' from before v5.4.0), or null.
  Future<String?> language();
  Future<void> setLanguage(String apiLocale);

  /// The theme last picked ('system', 'light', 'dark'), or null.
  Future<String?> theme();
  Future<void> setTheme(String mode);

  /// The currency last picked for 充值 (S31: 'HKD' …), or null.
  Future<String?> currency();
  Future<void> setCurrency(String code);
}

class SecureSettingsStore implements SettingsStore {
  SecureSettingsStore([FlutterSecureStorage? s]) : _s = s ?? const FlutterSecureStorage();
  final FlutterSecureStorage _s;
  static const _key = 'settings:language';
  static const _themeKey = 'settings:theme';
  static const _currencyKey = 'settings:currency';

  @override
  Future<String?> language() => _s.read(key: _key);
  @override
  Future<void> setLanguage(String apiLocale) => _s.write(key: _key, value: apiLocale);
  @override
  Future<String?> theme() => _s.read(key: _themeKey);
  @override
  Future<void> setTheme(String mode) => _s.write(key: _themeKey, value: mode);
  @override
  Future<String?> currency() => _s.read(key: _currencyKey);
  @override
  Future<void> setCurrency(String code) => _s.write(key: _currencyKey, value: code);
}

class InMemorySettingsStore implements SettingsStore {
  String? saved;
  String? savedTheme;
  String? savedCurrency;
  @override
  Future<String?> language() async => saved;
  @override
  Future<void> setLanguage(String apiLocale) async => saved = apiLocale;
  @override
  Future<String?> theme() async => savedTheme;
  @override
  Future<void> setTheme(String mode) async => savedTheme = mode;
  @override
  Future<String?> currency() async => savedCurrency;
  @override
  Future<void> setCurrency(String code) async => savedCurrency = code;
}
