import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../l10n/gen/app_localizations.dart';
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(authProvider).value;
    // 积分 (v11.0.0): asked for again each time the menu opens, so the balance is the latest.
    final points = ref.watch(pointsProvider).value;
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
              trailing: Text(
                '${points!.available}',
                key: const Key('menu-points'),
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
            trailing: Text(themeLabel(l10n, ref.watch(settingsProvider).themeMode), key: const Key('theme-current')),
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

/// ☰ on the right of the home bar (owner, v9.1.0: 「需要添加外框，更加明显」): framed in 赭红 on a light tint, so it
/// reads as the way into the menu. While it has the keyboard focus the theme's focus outline takes the frame's place.
class MenuButton extends StatelessWidget {
  const MenuButton({super.key, required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final frame = BorderSide(color: scheme.primary, width: 1.5);
    return IconButton(
      key: const Key('open-menu'),
      tooltip: l10n.menu,
      icon: const Icon(Icons.menu),
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

/// 跟随系统, 浅色 or 深色.
String themeLabel(AppLocalizations l10n, ThemeMode mode) => switch (mode) {
      ThemeMode.light => l10n.themeLight,
      ThemeMode.dark => l10n.themeDark,
      ThemeMode.system => l10n.themeSystem,
    };

/// 外观 from the menu (v12.1.0): 跟随系统, 浅色 or 深色, the current one ticked and focused. The page under the dialog
/// fades into the theme picked, its layout unchanged.
Future<void> pickTheme(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final settings = ref.read(settingsProvider.notifier);
  final current = ref.read(settingsProvider).themeMode;
  final mode = await showDialog<ThemeMode>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text(l10n.appearance),
      children: [
        for (final m in [ThemeMode.system, ThemeMode.light, ThemeMode.dark])
          ListTile(
            key: Key('theme-${m.name}'),
            autofocus: m == current,
            selected: m == current,
            leading: Icon(m == current ? Icons.check : null),
            title: Text(themeLabel(l10n, m)),
            onTap: () => Navigator.pop(ctx, m),
          ),
      ],
    ),
  );
  if (mode != null) settings.setThemeMode(mode);
}

class _Header extends StatelessWidget {
  const _Header({required this.account});
  final String? account;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: EdgeInsets.fromLTRB(Space.l, MediaQuery.paddingOf(context).top + Space.xl, Space.l, Space.l),
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
    );
  }
}
