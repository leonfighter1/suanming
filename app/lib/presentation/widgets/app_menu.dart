import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../data/api_client.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../platform/open_link.dart';
import '../buttons.dart';
import '../design.dart';
import '../history_page.dart';
import '../keyboard.dart';
import '../points_page.dart';
import '../profiles_page.dart';
import '../review_page.dart';
import '../settings_page.dart';
import 'language_menu.dart';

/// The ☰ menu (owner, v8.1.0, tech plan WP15.1): the pages and settings that sat on the home bar, in one side menu.
/// Since v9.1.0 (owner) 历史记录 lives here too, and the bar keeps only the title and a framed ☰ on its right
/// ([MenuButton]), from where the menu slides in: it is the page's end drawer. Esc closes it, as the drawer is a local
/// history entry of the page, and Tab stays inside it while it is open.
class AppMenu extends ConsumerWidget {
  const AppMenu({super.key});

  /// Closes the menu, then opens [page] over 首页.
  static void _open(BuildContext context, Widget page) {
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(MaterialPageRoute<void>(builder: (_) => page));
  }

  /// Closes the menu and opens the 管理后台 in this tab (S35; the owner: 「不需要单独打开新的页面，留在app本体」), handing
  /// over the app's own address for the dashboard's 返回应用. Where there is no tab (the app off the web), its address
  /// goes on the clipboard and a line says so.
  static Future<void> _openAdmin(BuildContext context, WidgetRef ref, AppUser user) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final base = ref.read(apiClientProvider).baseUrl;
    final url = adminUrl(base, user.login);
    // Signed in at once with the menu's one-time code (S33); without one, the sign-in with the login filled in.
    final handoff = ref.read(adminHandoffProvider).value;
    final app = kIsWeb ? '${Uri.base.origin}${Uri.base.path}' : null;
    Navigator.of(context).pop();
    if (await openHere(adminUrl(base, user.login, handoff: handoff, app: app))) return;
    // Off the web the address is copied: without the code, which is for this moment only.
    await Clipboard.setData(ClipboardData(text: url));
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.adminLinkCopied(url))));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(authProvider).value;
    // 积分 (v11.0.0): asked for again each time the menu opens, so the balance is the latest.
    final points = ref.watch(pointsProvider).value;
    // 管理后台 (S33): staff's one-time code, asked for while the menu is open, ready for the tap.
    if (user?.staff != null) ref.watch(adminHandoffProvider);
    final current = ref.watch(settingsProvider).apiLocaleCode;
    final language = appLanguages.firstWhere((l) => l.$1 == current, orElse: () => appLanguages.first).$2;
    return Drawer(
      key: const Key('app-menu'),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _Header(account: user?.login),
          ListTile(
            key: const Key('menu-history'),
            leading: const Icon(Icons.history),
            title: Text(l10n.history),
            onTap: () => _open(context, const HistoryPage()),
          ),
          if (points?.enabled ?? false)
            ListTile(
              key: const Key('open-points'),
              leading: const Icon(Icons.toll_outlined),
              title: Text(l10n.pointsTitle),
              trailing: RollingNumber<int>(
                points!.available,
                format: (v) => '$v',
                textKey: const Key('menu-points'),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary),
              ),
              onTap: () => _open(context, const PointsPage()),
            ),
          ListTile(
            key: const Key('open-profiles'),
            leading: const Icon(Icons.people_alt_outlined),
            title: Text(l10n.profiles),
            onTap: () => _open(context, const ProfilesPage()),
          ),
          ListTile(
            key: const Key('language-menu'),
            leading: const Icon(Icons.translate),
            title: Text(l10n.language),
            trailing: Text(language, key: const Key('language-current')),
            onTap: () => pickLanguage(context, ref),
          ),
          ListTile(
            key: const Key('theme-menu'),
            leading: const Icon(Icons.contrast),
            title: Text(l10n.appearance),
            trailing: Text(themeLabel(l10n, ref.watch(settingsProvider)), key: const Key('theme-current')),
            onTap: () => pickTheme(context, ref),
          ),
          ListTile(
            key: const Key('open-settings'),
            leading: const Icon(Icons.settings_outlined),
            title: Text(l10n.settings),
            onTap: () => _open(context, const SettingsPage()),
          ),
          // 内容审核: reviewers only (the server decides who is one).
          if (user?.isReviewer ?? false)
            ListTile(
              key: const Key('open-review'),
              leading: const Icon(Icons.fact_check_outlined),
              title: Text(l10n.reviewTitle),
              onTap: () => _open(context, const ReviewPage()),
            ),
          // 管理后台 (S25; the owner: 如果登陆者具备各项权限…可以在下拉菜单设置中选择进入后台系统): staff only, as the server says
          // (GET /v1/me's staff). The dashboard opens in a new tab, signed in by a one-time code asked for now (S33).
          if (user?.staff case final staff?)
            ListTile(
              key: const Key('open-admin'),
              leading: const Icon(Icons.admin_panel_settings_outlined),
              title: Text(l10n.adminDashboard),
              subtitle: Text(
                kIsWeb ? l10n.adminDashboardOpen(staffName(l10n, staff)) : l10n.adminDashboardCopy(staffName(l10n, staff)),
              ),
              trailing: Icon(kIsWeb ? Icons.open_in_new : Icons.copy_outlined),
              onTap: () => _openAdmin(context, ref, user!),
            ),
          // The keyboard list is also behind Ctrl+/ (or ?) on every page.
          ListTile(
            key: const Key('open-shortcuts'),
            leading: const Icon(Icons.keyboard_outlined),
            title: Text(l10n.keysTitle),
            subtitle: const Text('Ctrl + /'),
            onTap: () {
              final navigator = Navigator.of(context);
              navigator.pop();
              showShortcutList(navigator.context);
            },
          ),
          const Divider(),
          ListTile(
            key: const Key('menu-sign-out'),
            leading: const Icon(Icons.logout),
            title: Text(l10n.signOut),
            onTap: () {
              final auth = ref.read(authProvider.notifier);
              Navigator.of(context).pop();
              auth.signOut();
            },
          ),
        ],
      ),
    );
  }
}

/// ☰ → ✕ (S30; owner, 2026-10-30: 「菜单按钮的三条横线在打开时变形为叉号：上下两条旋转交叉，中间一条淡出；关闭时反向变回」):
/// the menu's state as a progress from ☰ (0) to ✕ (1), run over [Motion.medium] as the menu slides in or out. A
/// Scaffold with the menu gives [openedOf] as its onEndDrawerChanged; [MenuButton] and the menu's own close button
/// draw the progress with Material's menu_close icon (the outer lines turn into a cross, the middle one fades), at the
/// same place, so the ☰ the menu slides over is the ✕ it shows. Reduce motion: it jumps. One for the app, above its
/// pages (app.dart).
class MenuMorph extends StatefulWidget {
  const MenuMorph({super.key, required this.child});
  final Widget child;

  /// The menu's progress from ☰ to ✕; ☰ outside a MenuMorph.
  static Animation<double> of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_MenuState>()?.progress ?? kAlwaysDismissedAnimation;

  /// What a Scaffold with the menu calls as the menu opens (true) and closes (false).
  static ValueChanged<bool>? openedOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_MenuState>()?.opened;

  @override
  State<MenuMorph> createState() => _MenuMorphState();
}

class _MenuMorphState extends State<MenuMorph> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: Motion.medium);
  late final _progress = CurvedAnimation(parent: _controller, curve: Motion.themeCurve);

  @override
  void dispose() {
    _progress.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _opened(bool open) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _controller.value = open ? 1 : 0;
    } else if (open) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) => _MenuState(progress: _progress, opened: _opened, child: widget.child);
}

class _MenuState extends InheritedWidget {
  const _MenuState({required this.progress, required this.opened, required super.child});
  final Animation<double> progress;
  final ValueChanged<bool> opened;

  @override
  bool updateShouldNotify(_MenuState old) => old.progress != progress || old.opened != opened;
}

/// ☰ on the right of the home bar (owner, v9.1.0: 「需要添加外框，更加明显」): framed in 赭红 on a light tint, so it
/// reads as the way into the menu. While it has the keyboard focus the theme's focus outline takes the frame's place.
/// It turns into ✕ as the menu opens ([MenuMorph]).
class MenuButton extends StatelessWidget {
  const MenuButton({super.key, required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final frame = BorderSide(color: scheme.primary, width: 1.5);
    return AppIconButton(
      key: const Key('open-menu'),
      tooltip: l10n.menu,
      icon: AnimatedIcon(icon: AnimatedIcons.menu_close, progress: MenuMorph.of(context)),
      onPressed: onPressed,
      style: IconButton.styleFrom(
        foregroundColor: scheme.primary,
        backgroundColor: scheme.primaryContainer.withValues(alpha: 0.35),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.chip)),
      ).copyWith(
        side: WidgetStateBorderSide.resolveWith(
          (states) => states.contains(WidgetState.focused) ? focusOutline(scheme) : frame,
        ),
      ),
    );
  }
}

/// 语言 from the menu: 简体中文 or 繁體中文, the current one ticked and focused.
Future<void> pickLanguage(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final settings = ref.read(settingsProvider.notifier);
  final current = ref.read(settingsProvider).apiLocaleCode;
  final code = await showDialog<String>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text(l10n.language),
      children: [
        for (final (code, label, _) in appLanguages)
          ListTile(
            key: Key('language-$code'),
            autofocus: code == current,
            selected: code == current,
            leading: Icon(code == current ? Icons.check : null),
            title: Text(label),
            onTap: () => Navigator.pop(ctx, code),
          ),
      ],
    ),
  );
  if (code != null) settings.setLocale(code == 'zh-Hant' ? zhHant : zhHans);
}

/// 跟随时间, 跟随系统, 浅色 or 深色: what the theme follows in [s].
String themeLabel(AppLocalizations l10n, Settings s) => s.byTime
    ? l10n.themeTime
    : switch (s.themeMode) {
        ThemeMode.light => l10n.themeLight,
        ThemeMode.dark => l10n.themeDark,
        ThemeMode.system => l10n.themeSystem,
      };

/// 外观 from the menu (v12.1.0): 跟随时间 (S27, with its hours), 跟随系统, 浅色 or 深色, the current one ticked and
/// focused. The page under the dialog fades into the theme picked, its layout unchanged.
Future<void> pickTheme(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final settings = ref.read(settingsProvider.notifier);
  final now = ref.read(settingsProvider);
  final choices = [
    for (final m in [null, ThemeMode.system, ThemeMode.light, ThemeMode.dark])
      Settings(locale: now.locale, themeMode: m ?? ThemeMode.system, byTime: m == null),
  ];
  String keyOf(Settings s) => s.byTime ? 'time' : s.themeMode.name;
  final picked = await showDialog<Settings>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text(l10n.appearance),
      children: [
        for (final c in choices)
          ListTile(
            key: Key('theme-${keyOf(c)}'),
            autofocus: keyOf(c) == keyOf(now),
            selected: keyOf(c) == keyOf(now),
            leading: Icon(keyOf(c) == keyOf(now) ? Icons.check : null),
            title: Text(themeLabel(l10n, c)),
            subtitle: c.byTime ? Text(l10n.themeTimeHint) : null,
            onTap: () => Navigator.pop(ctx, c),
          ),
      ],
    ),
  );
  if (picked != null) settings.setThemeMode(picked.themeMode, byTime: picked.byTime);
}

class _Header extends StatelessWidget {
  const _Header({required this.account});
  final String? account;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    // The menu's close button where ☰ was in the bar (S30): centred in the bar's height, as far from the right.
    // The words leave it room.
    return Stack(
      children: [
        Container(
          padding: EdgeInsets.fromLTRB(Space.l, MediaQuery.paddingOf(context).top + Space.xl, Space.xxxl + Space.m, Space.l),
          margin: const EdgeInsets.only(bottom: Space.s),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [scheme.primary, Color.lerp(scheme.primary, scheme.tertiary, 0.6)!],
            ),
          ),
          child: Row(
            children: [
              // The app icon (npm run build:icons), the same as on the phone's home screen.
              ExcludeSemantics(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(Radii.field),
                  child: Image.asset('assets/icon/app_icon.png', key: const Key('menu-icon'), width: 56, height: 56),
                ),
              ),
              const SizedBox(width: Space.l),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.appTitle, style: text.titleLarge?.copyWith(color: scheme.onPrimary, fontWeight: FontWeight.w600)),
                    if (account != null) ...[
                      const SizedBox(height: Space.xs),
                      Text(
                        account!,
                        key: const Key('menu-account'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodyMedium?.copyWith(color: scheme.onPrimary.withValues(alpha: 0.85)),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: MediaQuery.paddingOf(context).top + (kToolbarHeight - kMinInteractiveDimension) / 2,
          right: Space.m,
          child: AppIconButton(
            key: const Key('menu-close'),
            tooltip: l10n.close,
            onPressed: () => Navigator.of(context).pop(),
            style: IconButton.styleFrom(foregroundColor: scheme.onPrimary),
            icon: AnimatedIcon(icon: AnimatedIcons.menu_close, progress: MenuMorph.of(context)),
          ),
        ),
      ],
    );
  }
}

/// A staff role in the reader's words (tech plan S25).
String staffName(AppLocalizations l10n, String role) => switch (role) {
      'admin' => l10n.staffAdmin,
      'manager' => l10n.staffManager,
      'editor' => l10n.staffEditor,
      _ => role,
    };

/// The 管理后台 on the API's own address, its sign-in's login filled in (`?login=`, like a login hint) and, with a
/// one-time code (S33), signed in at once (`&handoff=`); with the app's own address (S35), a way back to it
/// (`&app=`). The dashboard takes them off its address once read.
String adminUrl(String apiBase, String login, {String? handoff, String? app}) =>
    '$apiBase/admin/?login=${Uri.encodeQueryComponent(login)}'
    '${handoff == null ? '' : '&handoff=${Uri.encodeQueryComponent(handoff)}'}'
    '${app == null ? '' : '&app=${Uri.encodeQueryComponent(app)}'}';
