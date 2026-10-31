import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../config.dart';
import '../data/api_client.dart';
import '../data/profile_store.dart';
import '../data/settings_store.dart';
import '../data/token_store.dart';
import '../domain/content.dart';
import '../domain/dates.dart';
import '../domain/inquiry.dart';
import '../domain/life_report.dart';
import '../domain/models.dart';
import '../domain/places.dart';
import '../domain/profile.dart';
import '../domain/terms.dart';
import '../platform/speech.dart';
import '../platform/time_zone.dart';

const zhHant = Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant');
const zhHans = Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans');
/// 简体中文 first: the main language (Mainland usage). Chinese only: the owner removed English (2026-10-28).
const supportedAppLocales = [zhHans, zhHant];

/// The API's locale code for an app locale.
String apiLocale(Locale l) => l.scriptCode == 'Hans' ? 'zh-Hans' : 'zh-Hant';

class Settings {
  const Settings({required this.locale, this.themeMode = ThemeMode.system, this.byTime = false});
  final Locale locale;

  /// 外观 (v12.1.0): the system's light or dark, or one of them always.
  final ThemeMode themeMode;

  /// 跟随时间 (S27; owner, 2026-10-30: 「皮肤会跟随时间变化而变化。当地时间7点到第二天凌晨6点为深色，其余为浅色」): the theme
  /// follows the local time of day ([nightProvider]) instead of [themeMode]. Where the reader picked nothing, the default.
  final bool byTime;
  String get apiLocaleCode => apiLocale(locale);
}

class SettingsNotifier extends Notifier<Settings> {
  SettingsNotifier([this._initial = zhHans, this._theme = ThemeMode.system, this._byTime = false]);
  final Locale _initial;
  final ThemeMode _theme;
  final bool _byTime;

  /// 简体中文 by default (owner, 2026-10-26) and the system's theme; main() passes the ones the reader last picked.
  @override
  Settings build() => Settings(locale: _initial, themeMode: _theme, byTime: _byTime);

  /// Switches the language and keeps it for the next start (v5.1.0). A failed save only loses that.
  void setLocale(Locale l) {
    state = Settings(locale: l, themeMode: state.themeMode, byTime: state.byTime);
    unawaited(ref.read(settingsStoreProvider).setLanguage(apiLocale(l)).catchError((Object _) {}));
  }

  /// Switches the theme and keeps it for the next start (v12.1.0): [mode], or with [byTime] the time of day's (S27).
  /// The page keeps its layout: only colours change.
  void setThemeMode(ThemeMode mode, {bool byTime = false}) {
    state = Settings(locale: state.locale, themeMode: mode, byTime: byTime);
    unawaited(ref.read(settingsStoreProvider).setTheme(byTime ? 'time' : mode.name).catchError((Object _) {}));
  }
}

/// The theme to start in: the one the reader last picked, else the time of day's (跟随时间, S27). Storage that can't be
/// read starts with the time of day's too.
Future<({ThemeMode mode, bool byTime})> startTheme(SettingsStore store) async {
  const byTime = (mode: ThemeMode.system, byTime: true);
  try {
    return switch (await store.theme()) {
      'light' => (mode: ThemeMode.light, byTime: false),
      'dark' => (mode: ThemeMode.dark, byTime: false),
      'system' => (mode: ThemeMode.system, byTime: false),
      _ => byTime,
    };
  } catch (_) {
    return byTime;
  }
}

/// The clock 跟随时间 and the banner read (S27): the device's local time; tests give their own.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Night by the local clock (owner, 2026-10-30: 「当地时间7点到第二天凌晨6点为深色，其余为浅色」): 19:00 to 06:00.
bool isNight(DateTime t) => t.hour >= 19 || t.hour < 6;

/// The next turn after [t]: that day's 06:00 or 19:00, else the next day's 06:00.
DateTime nextTurn(DateTime t) {
  for (final turn in [DateTime(t.year, t.month, t.day, 6), DateTime(t.year, t.month, t.day, 19)]) {
    if (t.isBefore(turn)) return turn;
  }
  return DateTime(t.year, t.month, t.day + 1, 6);
}

/// Whether it is night now ([isNight]), turning by itself at 06:00 and 19:00 while the app is open: 跟随时间's theme and
/// the banner's moon or sun.
final nightProvider = NotifierProvider<NightNotifier, bool>(NightNotifier.new);

class NightNotifier extends Notifier<bool> {
  Timer? _turn;

  @override
  bool build() {
    ref.onDispose(() => _turn?.cancel());
    return _now();
  }

  /// Night or day now, and a timer for the next turn, which asks again.
  bool _now() {
    final now = ref.read(clockProvider)();
    _turn?.cancel();
    _turn = Timer(nextTurn(now).difference(now), () => state = _now());
    return isNight(now);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, Settings>(SettingsNotifier.new);

final settingsStoreProvider = Provider<SettingsStore>((ref) => SecureSettingsStore());

/// The language to start in: the one the reader last picked, else 简体中文 (owner, 2026-10-26).
/// Storage that can't be read (a private window, no secure context) starts in 简体 too, and so does
/// English saved before the owner removed it (v5.4.0).
Future<Locale> startLocale(SettingsStore store) async {
  try {
    return switch (await store.language()) {
      'zh-Hant' => zhHant,
      _ => zhHans,
    };
  } catch (_) {
    return zhHans;
  }
}

final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());

/// The system share sheet (a download on the web); tests replace it to see what would be shared.
final shareProvider = Provider<Future<void> Function(ShareParams params)>(
  (ref) => (params) async {
    await SharePlus.instance.share(params);
  },
);

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

  /// [login]: a username, an email or a bound phone (v8.2.0).
  Future<void> login(String login, String password) async {
    await _api.login(login, password);
    state = AsyncData(await _api.me());
  }

  /// The account as an account call returned it (a new username, a bound phone, a verified email).
  void changed(AppUser user) => state = AsyncData(user);

  /// The account read again, after a change made elsewhere than an account call (a setting).
  Future<void> reload() async => state = AsyncData(await _api.me());

  Future<void> register({
    String? username,
    String? email,
    required String password,
    required String country,
    required bool ageConfirmed,
  }) async {
    await _api.register(
      username: username,
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

/// 设置 → 报告 (v9.0.0): the account's settings and what delivers mail on the server, read when 设置 opens.
final accountSettingsProvider = FutureProvider.autoDispose<AccountSettings>(
  (ref) => ref.read(apiClientProvider).settings(),
);

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

/// 北京 as the places table has it (CN, 北京市, GeoNames 1816670): the admin's birthplace (owner, v5.4.0).
const beijing = BirthPlace(
  country: 'CN',
  countryNames: PlaceNames('中國', '中国', 'China'),
  region: '22',
  regionNames: PlaceNames('北京市', '北京市', 'Beijing'),
  cityId: 1816670,
  city: PlaceNames('北京', '北京', 'Beijing'),
  timezone: 'Asia/Shanghai',
  longitude: 116.3972,
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
          cityKey: 'beijing',
          place: beijing,
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

/// The admin's profile as seeded before v5.4.0 (born in 台北), still untouched on a device, moves to 北京 (the
/// owner). A profile someone has edited keeps what they chose. Null when there is nothing to move.
ProfileBook? movedAdminSeed(AppUser u, ProfileBook book) {
  if ((u.email ?? '').toLowerCase() != 'admin') return null;
  final i = book.profiles.indexWhere(
    (p) => p.id == 'default' && p.name == '管理员' && p.place == null && p.cityKey == 'taipei',
  );
  if (i < 0) return null;
  final list = [...book.profiles];
  list[i] = list[i].copyWith(cityKey: 'beijing', place: beijing);
  return book.copyWith(profiles: list);
}

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
    final moved = movedAdminSeed(user, book);
    if (moved != null) {
      book = moved;
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
    await _save(ProfileBook(profiles: list, defaultId: def, chartLabels: _book.chartLabels, chartPlaces: _book.chartPlaces));
  }

  Future<void> setDefault(String id) => _save(_book.copyWith(defaultId: id));

  /// 归类到… (v8.0.0): the chart's label on this device follows its person on the server; an empty name drops it.
  Future<void> relabelChart(String chartId, String name) => _save(
        _book.copyWith(
          chartLabels: {
            for (final e in _book.chartLabels.entries)
              if (e.key != chartId) e.key: e.value,
            if (name.isNotEmpty) chartId: name,
          },
        ),
      );

  /// Remembers whose chart it is and where they were born (device only).
  Future<void> labelChart(String chartId, String name, {String? place}) => _save(_book.copyWith(
        chartLabels: {..._book.chartLabels, if (name.isNotEmpty) chartId: name},
        chartPlaces: {..._book.chartPlaces, if (place != null && place.isNotEmpty) chartId: place},
      ));
}

final profilesProvider = AsyncNotifierProvider<ProfilesNotifier, ProfileBook>(ProfilesNotifier.new);

/// Whose reading a 塔罗, 求签, 算卦 or 风水 chart is (v8.0.0): the reader's default profile, so 以往记录 can file it by
/// person. 归类到… in history moves it to someone else. Nothing when there is no profile yet.
Map<String, Object?> readerPerson(ProfileBook? book) {
  final name = book?.defaultProfile?.name.trim() ?? '';
  return name.isEmpty
      ? const {}
      : {
          'person': {'name': name},
        };
}

// ---- history & calendar ----

/// The readings of 以往记录: as many as the API lists (100, v8.0.0), for its months and people.
final historyProvider = FutureProvider.autoDispose<List<HistoryItem>>(
  (ref) => ref.watch(apiClientProvider).listReports(limit: 100),
);

/// 農曆 equivalent and 時辰 list of a date (y-m-d only), for the pickers.
final calendarDayProvider = FutureProvider.autoDispose.family<CalendarDay, DateTime>(
  (ref, d) => ref.watch(apiClientProvider).calendarDay(DateTime(d.year, d.month, d.day)),
);

/// Months of a 農曆 year (incl. 閏月), for the 農曆 date picker.
final lunarMonthsProvider = FutureProvider.autoDispose.family<List<LunarMonthInfo>, int>(
  (ref, year) => ref.watch(apiClientProvider).lunarMonths(year),
);

/// Polls a 一生运势报告 until it leaves `pending`.
final lifeReportProvider = StreamProvider.autoDispose.family<LifeReportView, String>((ref, id) async* {
  final api = ref.watch(apiClientProvider);
  final interval = ref.watch(pollIntervalProvider);
  while (true) {
    final r = await api.getLifeReport(id);
    yield r;
    if (r.isTerminal) return;
    await Future<void>.delayed(interval);
  }
});

/// The user's life reports (newest first).
final lifeReportsProvider = FutureProvider.autoDispose<List<LifeReportView>>(
  (ref) => ref.watch(apiClientProvider).listLifeReports(),
);

/// 每日一牌 for the device's calendar date (GET /v1/tarot/daily).
final dailyCardProvider = FutureProvider.autoDispose<ChartResult>(
  (ref) => ref.watch(apiClientProvider).dailyCard(ymd(DateTime.now())),
);

/// 今日一卦 / 今日一签 for the device's calendar date and time zone (GET /v1/east/daily, S26).
final eastDailyProvider = FutureProvider.autoDispose<ChartResult>(
  (ref) => ref.watch(apiClientProvider).eastDaily(ymd(DateTime.now()), deviceTimeZone()),
);

/// The methods the home page offers, in the region's entry order (GET /v1/methods, v4.3.0); the
/// app shows the ones it has a page for. Unreachable or refused: the default order.
const defaultMethods = ['bazi', 'tarot', 'qiuqian', 'liuyao', 'fengshui'];

/// The methods the app has a page for: the home page's four, and 起名, reached from a 八字 chart (v4.5.0;
/// off in the matrix until the owner's review, so absent unless the region offers it).
const appMethods = [...defaultMethods, 'naming'];
final methodsProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  try {
    final order = await ref.watch(apiClientProvider).methods();
    final shown = order.where(appMethods.contains).toList();
    return shown.isEmpty ? defaultMethods : shown;
  } catch (_) {
    return defaultMethods;
  }
});

/// A chart by id (life reports opened from history need its 八字).
final chartProvider = FutureProvider.autoDispose.family<ChartResult, String>(
  (ref, id) => ref.watch(apiClientProvider).getChart(id),
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

/// 内容管理 (S29): what staff changed of the app's texts and images, in the app's language. Nothing (the app's own)
/// until it comes, and whenever it can't: a server from before the CMS, no network.
final contentProvider = FutureProvider<ContentView>((ref) async {
  final locale = ref.watch(settingsProvider.select((s) => s.apiLocaleCode));
  try {
    return await ref.watch(apiClientProvider).content(locale);
  } catch (_) {
    return ContentView.none;
  }
});

/// ☰ → 管理后台 without a second sign-in (S33; the owner: 「如果当前登录进去的用户有dashboard access，那么不需要重复登录了」):
/// a one-time code, asked for while the menu is open, so a tap opens the dashboard at once (a browser lets a tap open a
/// tab, not a reply that comes after it). Null where there is none (a server from before, a failed request).
final adminHandoffProvider = FutureProvider.autoDispose<String?>((ref) async {
  try {
    return await ref.watch(apiClientProvider).adminHandoff();
  } on Object {
    return null;
  }
});

/// 积分 (v11.0.0, S20): the account's balance, packs and latest changes. Off (nothing shown, nothing costs) when the
/// server has them off, or is one from before them (404).
final pointsProvider = FutureProvider.autoDispose<PointsView>((ref) async {
  try {
    return await ref.watch(apiClientProvider).points();
  } on ApiException catch (e) {
    if (e.status == 404) return PointsView.off;
    rethrow;
  }
});

/// 货币 (S31): the currency the reader picked for 充值, kept on this device; null until they pick one (充值 then offers
/// the first the server accepts).
class CurrencyPick extends AsyncNotifier<String?> {
  @override
  Future<String?> build() => ref.read(settingsStoreProvider).currency().catchError((Object _) => null);

  void pick(String code) {
    state = AsyncData(code);
    unawaited(ref.read(settingsStoreProvider).setCurrency(code).catchError((Object _) {}));
  }
}

final currencyPickProvider = AsyncNotifierProvider<CurrencyPick, String?>(CurrencyPick.new);

/// 收据 (S31): the account's receipts, newest first.
final receiptsProvider = FutureProvider.autoDispose<List<ReceiptView>>((ref) => ref.watch(apiClientProvider).receipts());

/// The [chartQuoteProvider] key for a chart and the topics a reading would be asked for (default all).
String quoteKey(String chartId, [Iterable<String>? topics]) => topics == null ? chartId : '$chartId|${topics.join(',')}';

/// What each AI request on a chart costs now, keyed by [quoteKey]. Null while 积分 are off.
final chartQuoteProvider = FutureProvider.autoDispose.family<ChartQuote?, String>((ref, key) async {
  if (!(await ref.watch(pointsProvider.future)).enabled) return null;
  final [chartId, ...rest] = key.split('|');
  final topics = rest.isEmpty ? null : rest.first.split(',').where((t) => t.isNotEmpty).toList();
  return ref.watch(apiClientProvider).chartQuote(chartId, topics: topics);
});

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

/// A reading's 追问 (v7.0.0), polled while one is being answered. [parent] is `reports/<id>` or `life-reports/<id>`.
final followUpsProvider = StreamProvider.autoDispose.family<FollowUpList, String>((ref, parent) async* {
  final api = ref.watch(apiClientProvider);
  final interval = ref.watch(pollIntervalProvider);
  while (true) {
    final list = await api.listFollowUps(parent);
    yield list;
    if (!list.answering) return;
    await Future<void>.delayed(interval);
  }
});

/// 深度分析 (v10.0.0), polled while the master writes its next turn.
final inquiryProvider = StreamProvider.autoDispose.family<InquiryView, String>((ref, id) async* {
  final api = ref.watch(apiClientProvider);
  final interval = ref.watch(pollIntervalProvider);
  while (true) {
    final inquiry = await api.getInquiry(id);
    yield inquiry;
    if (!inquiry.thinking) return;
    await Future<void>.delayed(interval);
  }
});

/// The mic button's speech recognition (v10.0.0): the browser's on the web, none elsewhere. Tests put in their own.
final speechInputProvider = Provider<SpeechInput>((ref) => createSpeechInput());

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
