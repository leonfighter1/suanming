import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config.dart';
import '../data/api_client.dart';
import '../data/profile_store.dart';
import '../data/token_store.dart';
import '../domain/models.dart';
import '../domain/places.dart';
import '../domain/profile.dart';
import '../domain/terms.dart';

const zhHant = Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant');
const zhHans = Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans');
/// 简体中文 first: the main language (Mainland usage).
const supportedAppLocales = [zhHans, zhHant, Locale('en')];

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
  SettingsNotifier([this._initial = zhHans]);
  final Locale _initial;

  /// 简体中文 by default.
  @override
  Settings build() => Settings(locale: _initial);
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
    final id = state.value?.id;
    await _api.deleteAccount();
    // The account is gone: its on-device profiles go too.
    if (id != null) await ref.read(profileStoreProvider).delete(id);
    state = const AsyncData(null);
  }
}

final authProvider = AsyncNotifierProvider<AuthNotifier, AppUser?>(AuthNotifier.new);

final termsProvider = FutureProvider<Terms>((ref) => Terms.load(rootBundle));

// ---- personal profiles (device only) ----

final profileStoreProvider = Provider<ProfileStore>((ref) => SecureProfileStore());

/// The editable sample the test account starts with.
BirthProfile sampleProfile(String name) => BirthProfile(
      id: 'default',
      name: name,
      gender: 'male',
      birthLocal: DateTime(1990, 3, 15, 14, 30),
      cityKey: 'hk',
    );

/// Test accounts get ready-made profiles so testing starts at once.
bool isTestAccount(AppUser u) {
  final e = (u.email ?? '').toLowerCase();
  return e.startsWith('test') || e == 'admin' || e == 'xumei';
}

/// Seeded profiles per test account (all editable).
List<BirthProfile> testProfiles(AppUser u) => switch ((u.email ?? '').toLowerCase()) {
      'xumei' => [
          BirthProfile(
            id: 'default',
            name: 'xumei',
            gender: 'female',
            birthLocal: DateTime(1992, 6, 18, 10, 20),
            cityKey: 'shanghai',
          ),
        ],
      'admin' => [
        BirthProfile(
          id: 'default',
          name: '管理员',
          gender: 'female',
          birthLocal: DateTime(1988, 8, 8, 8),
          cityKey: 'taipei',
          timeMode: 'shichen',
          shichen: '辰',
        ),
        BirthProfile(
          id: 'family',
          name: '测试家人',
          gender: 'male',
          // 農曆 1960 正月初一 = 1960-01-28
          birthLocal: DateTime(1960, 1, 28, 12),
          cityKey: 'hk',
          dateMode: 'lunar',
          timeMode: 'shichen',
          shichen: '午',
        ),
      ],
      _ => [sampleProfile('测试用户')],
    };

class ProfilesNotifier extends AsyncNotifier<ProfileBook> {
  String? _userId;
  ProfileStore get _store => ref.read(profileStoreProvider);

  @override
  Future<ProfileBook> build() async {
    final user = await ref.watch(authProvider.future);
    _userId = user?.id;
    if (user == null) return const ProfileBook();
    var book = ProfileBook.decode(await _store.read(user.id));
    if (book.profiles.isEmpty && isTestAccount(user)) {
      book = ProfileBook(profiles: testProfiles(user), defaultId: 'default');
      await _store.write(user.id, book.encode());
    }
    return book;
  }

  Future<void> _save(ProfileBook book) async {
    state = AsyncData(book);
    if (_userId != null) await _store.write(_userId!, book.encode());
  }

  ProfileBook get _book => state.value ?? const ProfileBook();

  Future<void> upsert(BirthProfile p, {bool makeDefault = false}) async {
    final list = [..._book.profiles];
    final i = list.indexWhere((x) => x.id == p.id);
    i >= 0 ? list[i] = p : list.add(p);
    final first = _book.profiles.isEmpty;
    await _save(_book.copyWith(profiles: list, defaultId: makeDefault || first ? p.id : null));
  }

  Future<void> remove(String id) async {
    final list = _book.profiles.where((p) => p.id != id).toList();
    final def = _book.defaultId == id ? (list.isEmpty ? null : list.first.id) : _book.defaultId;
    await _save(ProfileBook(profiles: list, defaultId: def, chartLabels: _book.chartLabels));
  }

  Future<void> setDefault(String id) => _save(_book.copyWith(defaultId: id));

  Future<void> labelChart(String chartId, String name) =>
      _save(_book.copyWith(chartLabels: {..._book.chartLabels, chartId: name}));
}

final profilesProvider = AsyncNotifierProvider<ProfilesNotifier, ProfileBook>(ProfilesNotifier.new);

// ---- history & calendar ----

final historyProvider = FutureProvider.autoDispose<List<HistoryItem>>(
  (ref) => ref.watch(apiClientProvider).listReports(),
);

/// 農曆 equivalent and 時辰 list of a date (y-m-d only), for the pickers.
final calendarDayProvider = FutureProvider.autoDispose.family<CalendarDay, DateTime>(
  (ref, d) => ref.watch(apiClientProvider).calendarDay(DateTime(d.year, d.month, d.day)),
);

/// Months of a 農曆 year (incl. 閏月), for the 農曆 date picker.
final lunarMonthsProvider = FutureProvider.autoDispose.family<List<LunarMonthInfo>, int>(
  (ref, year) => ref.watch(apiClientProvider).lunarMonths(year),
);

/// Birthplace countries (static server data; cached for the session).
final placeCountriesProvider = FutureProvider<List<PlaceCountryInfo>>(
  (ref) => ref.watch(apiClientProvider).placeCountries(),
);

/// Regions with their cities for one country.
final placeRegionsProvider = FutureProvider.family<List<PlaceRegion>, String>(
  (ref, country) => ref.watch(apiClientProvider).placeRegions(country),
);

final pollIntervalProvider = Provider<Duration>((ref) => AppConfig.pollInterval);

/// Price and bought 破除運勢 plans of a report.
final remediesProvider = FutureProvider.autoDispose.family<RemedyList, String>(
  (ref, reportId) => ref.watch(apiClientProvider).listRemedies(reportId),
);

/// Polls a 破除運勢 plan until it leaves `pending`.
final remedyProvider = StreamProvider.autoDispose.family<RemedyView, String>((ref, id) async* {
  final api = ref.watch(apiClientProvider);
  final interval = ref.watch(pollIntervalProvider);
  while (true) {
    final r = await api.getRemedy(id);
    yield r;
    if (r.isTerminal) return;
    await Future<void>.delayed(interval);
  }
});

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
