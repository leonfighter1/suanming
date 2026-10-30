import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../data/admin_api.dart';
import '../domain/models.dart';
import '../platform/download.dart';
import '../platform/prefs.dart';

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

/// Where the dashboard keeps its own settings: the browser's storage. Tests put a map here.
class Prefs {
  const Prefs({required this.read, required this.write});
  final String? Function(String key) read;
  final void Function(String key, String value) write;
}

final prefsProvider = Provider<Prefs>((ref) => const Prefs(read: readPref, write: writePref));

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
  api.onSignedOut = () => ref.read(sessionProvider.notifier).ended();
  return api;
});

/// The signed-in admin; null until signed in, and again once the session is over.
class SessionNotifier extends Notifier<AdminMe?> {
  @override
  AdminMe? build() => null;

  Future<void> signIn(String login, String password) async {
    state = await ref.read(adminApiProvider).signIn(login, password);
  }

  void signOut() {
    ref.read(adminApiProvider).signOut();
    state = null;
  }

  /// The server ended the session (a failed refresh, the account no longer an admin).
  void ended() => state = null;
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

/// What "now" is, for 「5 分钟前」; tests fix it.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Saves an export: the browser downloads it; tests see what was saved.
final saveFileProvider = Provider<Future<void> Function(AdminFile file)>(
  (ref) => (f) async {
    if (!await downloadFile(f.bytes, f.name, f.mime)) throw UnsupportedError('只能在浏览器里下载');
  },
);
