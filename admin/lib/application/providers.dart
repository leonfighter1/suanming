import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../data/admin_api.dart';
import '../domain/models.dart';
import '../platform/download.dart';
import '../platform/login_hint.dart';
import '../platform/pick_file.dart';
import '../presentation/format.dart' show moneyUnit;
import '../platform/prefs.dart';
import '../platform/session_lock.dart';

/// When Riverpod asks again by itself after a failed request: a few times, quickly (0.2, 0.4, 0.8, 1.6 s), when the
/// server erred or couldn't be reached; never when it said no (4xx, the session over), which asking again won't
/// change. Riverpod's own default goes on for some 45 s, showing only a spinner; after these the page shows the problem
/// and 重试.
Duration? retryAdmin(int retryCount, Object error) {
  if (retryCount >= 4 || error is Error) return null;
  if (error is AdminApiException && error.status < 500) return null;
  return Duration(milliseconds: 200 << retryCount);
}

/// The HTTP client the API talks through; null for the default one. Tests put a fake server here.
final httpClientProvider = Provider<http.Client?>((ref) => null);

/// What the app's ☰ → 管理后台 hands over in the address, taken off it once read.
final _handedOver = Provider<Map<String, String>>((ref) => takeAddressParameters(const {'login', 'handoff'}));

/// The login the app's ☰ → 管理后台 hands over (`?login=`, tech plan S25), for the sign-in to fill in. Tests set it.
final loginHintProvider = Provider<String?>((ref) => ref.watch(_handedOver)['login']);

/// The one-time code the app's ☰ → 管理后台 hands over (`&handoff=`, S33): signed in with it, no second sign-in. Tests
/// set it.
final handoffProvider = Provider<String?>((ref) => ref.watch(_handedOver)['handoff']);

/// Where the dashboard keeps its own settings: the browser's storage. Tests put a map here.
class Prefs {
  const Prefs({required this.read, required this.write});
  final String? Function(String key) read;
  final void Function(String key, String value) write;
}

final prefsProvider = Provider<Prefs>((ref) => const Prefs(read: readPref, write: writePref));

/// The session's key in this browser's storage, and the name of the lock its tabs take turns under (S34; the owner:
/// 「不需要重复登录dashboard 页面了」): its refresh token, shared by the dashboard's tabs and kept across a restart.
const sessionKey = 'mingli-admin-session';

/// 外观 (v12.1.0): the system's light or dark, or one of them always, kept in this browser. A change fades the
/// colours; nothing moves.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const key = 'mingli-admin-theme';

  @override
  ThemeMode build() => switch (ref.read(prefsProvider).read(key)) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  void set(ThemeMode mode) {
    state = mode;
    ref.read(prefsProvider).write(key, mode.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

final adminApiProvider = Provider<AdminApi>((ref) {
  final api = AdminApi(baseUrl: adminApiBase(), client: ref.watch(httpClientProvider));
  // Two statements: in a cascade, the first closure's body would take the second assignment in.
  api.onSignedOut = () => ref.read(sessionProvider.notifier).ended();
  api.onNotAllowed = () => ref.read(sessionProvider.notifier).recheck();
  api.onSession = (refresh) => ref.read(prefsProvider).write(sessionKey, refresh ?? '');
  api.keptSession = () => ref.read(prefsProvider).read(sessionKey);
  api.oneAtATime = (rotate) => oneAtATime(sessionKey, rotate);
  return api;
});

/// The signed-in staff member (admin, manager or integrator: tech plan S25); null until signed in, and again once the
/// session is over.
class SessionNotifier extends Notifier<AdminMe?> {
  @override
  AdminMe? build() {
    // 设置 (S31): money in the signed-in session's currency, 元 without one.
    listenSelf((_, me) => moneyUnit = me?.currency ?? MoneyUnit.yuan);
    return null;
  }

  Future<void> signIn(String login, String password) async {
    state = await ref.read(adminApiProvider).signIn(login, password);
  }

  /// Signed in at the start without asking again (S33; the owner: 「如果当前登录进去的用户有dashboard access，那么不需要
  /// 重复登录了」): with the app's one-time code, else with this browser's session (from before a reload, another tab's,
  /// from before a restart: S34). Neither working leaves the sign-in, its login filled in where the app gave it.
  Future<void> start() async {
    final api = ref.read(adminApiProvider);
    final code = ref.read(handoffProvider);
    if (code != null) {
      try {
        state = await api.signInWithCode(code);
        return;
      } on Object {
        // Used or late: this browser's session, if it has one.
      }
    }
    final kept = ref.read(prefsProvider).read(sessionKey);
    if (kept == null || kept.isEmpty) return;
    try {
      state = await api.resume(kept);
    } on Object {
      ref.read(prefsProvider).write(sessionKey, '');
    }
  }

  void signOut() {
    ref.read(adminApiProvider).signOut();
    state = null;
  }

  /// The server ended the session (a failed refresh, the account no longer staff).
  void ended() => state = null;

  Future<void>? _checking;

  /// The server refused something to the role: asks again what the role is and may do, once however many requests
  /// were refused, so the pages shown follow a role changed since signing in.
  Future<void> recheck() => _checking ??= _recheckOnce().whenComplete(() => _checking = null);

  Future<void> _recheckOnce() async {
    if (state == null) return;
    try {
      final me = await ref.read(adminApiProvider).me();
      if (state != null) state = me;
    } on Object {
      // No longer staff ends the session by itself (admin_only); anything else leaves the role as it was.
    }
  }
}

final sessionProvider = NotifierProvider<SessionNotifier, AdminMe?>(SessionNotifier.new);

/// The period every page shows: the last 7, 30 or 90 days.
class DaysNotifier extends Notifier<int> {
  @override
  int build() => 30;
  void set(int days) => state = days;
}

final daysProvider = NotifierProvider<DaysNotifier, int>(DaysNotifier.new);

final overviewProvider = FutureProvider.autoDispose<Overview>(
  (ref) => ref.watch(adminApiProvider).overview(ref.watch(daysProvider)),
);
final seriesProvider = FutureProvider.autoDispose<List<DayRow>>(
  (ref) => ref.watch(adminApiProvider).series(ref.watch(daysProvider)),
);
final breakdownProvider = FutureProvider.autoDispose<Breakdown>(
  (ref) => ref.watch(adminApiProvider).breakdown(ref.watch(daysProvider)),
);

/// The 用户 table's search, filters, sorting and page.
class UserQueryNotifier extends Notifier<UserQuery> {
  @override
  UserQuery build() => const UserQuery();
  void set(UserQuery q) => state = q;
}

final userQueryProvider = NotifierProvider<UserQueryNotifier, UserQuery>(UserQueryNotifier.new);

final usersProvider = FutureProvider.autoDispose<UserPage>(
  (ref) => ref.watch(adminApiProvider).users(ref.watch(userQueryProvider)),
);
final userProvider = FutureProvider.autoDispose.family<UserDetail, String>(
  (ref, id) => ref.watch(adminApiProvider).user(id),
);
final activeProvider = FutureProvider.autoDispose<Active>((ref) => ref.watch(adminApiProvider).active());

/// 消息 (tech plan S25): every message with its wordings, and the latest dispatches.
final messagesProvider = FutureProvider.autoDispose<MessageListing>((ref) => ref.watch(adminApiProvider).messages());
final dispatchLogProvider = FutureProvider.autoDispose<List<DispatchEntry>>(
  (ref) => ref.watch(adminApiProvider).dispatchLog(),
);

/// 内容 (内容管理, tech plan S29): every text the app shows and the images it takes from here, with staff's changes.
final contentProvider = FutureProvider.autoDispose<ContentListing>((ref) => ref.watch(adminApiProvider).content());

/// 设置 (tech plan S31): every setting with its value, its default and words, what answers AI calls, the rates' day.
final settingsProvider = FutureProvider.autoDispose<SettingsListing>((ref) => ref.watch(adminApiProvider).settings());

/// Chooses a file of the given types to send (内容管理's images): the browser's chooser; tests choose their own.
final pickFileProvider = Provider<Future<AdminFile?> Function(List<String> types)>((ref) => pickFile);

/// What "now" is, for 「5 分钟前」; tests fix it.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Saves an export: the browser downloads it; tests see what was saved.
final saveFileProvider = Provider<Future<void> Function(AdminFile file)>(
  (ref) => (f) async {
    if (!await downloadFile(f.bytes, f.name, f.mime)) throw UnsupportedError('只能在浏览器里下载');
  },
);
