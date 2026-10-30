import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../data/admin_api.dart';
import '../domain/models.dart';
import '../platform/download.dart';
import '../platform/login_hint.dart';
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

/// The login the app's ☰ → 管理后台 hands over (`?login=`, tech plan S25), for the sign-in to fill in; taken off the
/// address once read. Tests set it.
final loginHintProvider = Provider<String?>((ref) => takeLoginHint());

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
  // Two statements: in a cascade, the first closure's body would take the second assignment in.
  api.onSignedOut = () => ref.read(sessionProvider.notifier).ended();
  api.onNotAllowed = () => ref.read(sessionProvider.notifier).recheck();
  return api;
});

/// The signed-in staff member (admin, manager or integrator: tech plan S25); null until signed in, and again once the
/// session is over.
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

/// What "now" is, for 「5 分钟前」; tests fix it.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Saves an export: the browser downloads it; tests see what was saved.
final saveFileProvider = Provider<Future<void> Function(AdminFile file)>(
  (ref) => (f) async {
    if (!await downloadFile(f.bytes, f.name, f.mime)) throw UnsupportedError('只能在浏览器里下载');
  },
);
