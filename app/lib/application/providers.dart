import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config.dart';
import '../data/api_client.dart';
import '../data/token_store.dart';
import '../domain/models.dart';
import '../domain/terms.dart';

const zhHant = Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant');
const zhHans = Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans');
const supportedAppLocales = [zhHant, zhHans, Locale('en')];

/// The API's locale code for an app locale.
String apiLocale(Locale l) => l.languageCode == 'en'
    ? 'en'
    : l.scriptCode == 'Hans'
        ? 'zh-Hans'
        : 'zh-Hant';

class Settings {
  const Settings({required this.locale});
  final Locale locale;
  String get apiLocaleCode => apiLocale(locale);
}

class SettingsNotifier extends Notifier<Settings> {
  @override
  Settings build() => const Settings(locale: zhHant);
  void setLocale(Locale l) => state = Settings(locale: l);
}

final settingsProvider = NotifierProvider<SettingsNotifier, Settings>(SettingsNotifier.new);

final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(
    baseUrl: AppConfig.apiBaseUrl,
    tokens: ref.watch(tokenStoreProvider),
    // A failed token refresh means the session is gone: show the sign-in screen.
    onSignedOut: () => ref.invalidate(authProvider),
  ),
);

/// The signed-in user, or null when signed out.
class AuthNotifier extends AsyncNotifier<AppUser?> {
  ApiClient get _api => ref.read(apiClientProvider);

  @override
  Future<AppUser?> build() async {
    if (await ref.read(tokenStoreProvider).read() == null) return null;
    try {
      return await _api.me();
    } on ApiException catch (e) {
      if (e.isUnauthorized) return null;
      rethrow;
    }
  }

  Future<void> login(String email, String password) async {
    await _api.login(email, password);
    state = AsyncData(await _api.me());
  }

  Future<void> register({
    required String email,
    required String password,
    required String country,
    required bool ageConfirmed,
  }) async {
    await _api.register(
      email: email,
      password: password,
      country: country,
      locale: ref.read(settingsProvider).apiLocaleCode,
      ageConfirmed: ageConfirmed,
    );
    state = AsyncData(await _api.me());
  }

  Future<void> signOut() async {
    await _api.logout();
    state = const AsyncData(null);
  }

  Future<void> deleteAccount() async {
    await _api.deleteAccount();
    state = const AsyncData(null);
  }
}

final authProvider = AsyncNotifierProvider<AuthNotifier, AppUser?>(AuthNotifier.new);

final termsProvider = FutureProvider<Terms>((ref) => Terms.load(rootBundle));

final pollIntervalProvider = Provider<Duration>((ref) => AppConfig.pollInterval);

/// Polls a report until it leaves `pending`.
final reportProvider = StreamProvider.autoDispose.family<ReportView, String>((ref, id) async* {
  final api = ref.watch(apiClientProvider);
  final interval = ref.watch(pollIntervalProvider);
  while (true) {
    final report = await api.getReport(id);
    yield report;
    if (report.isTerminal) return;
    await Future<void>.delayed(interval);
  }
});
