import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../data/api_client.dart';
import '../../l10n/gen/app_localizations.dart';
import '../design.dart';
import '../history_page.dart';
import '../keyboard.dart';
import '../profiles_page.dart';
import '../review_page.dart';
import '../settings_page.dart';
import 'language_menu.dart';

/// The ☰ menu (owner, v8.1.0, tech plan WP15.1): the pages and settings that sat on the home bar, in one side menu,
/// so the bar keeps ☰, the title and 历史记录. The menu is the page's drawer: Esc closes it, as the drawer is a local
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
    final current = ref.watch(settingsProvider).apiLocaleCode;
    final language = appLanguages.firstWhere((l) => l.$1 == current, orElse: () => appLanguages.first).$2;
    return Drawer(
      key: const Key('app-menu'),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _Header(account: user == null ? null : accountLabel(user)),
          ListTile(
            key: const Key('menu-history'),
            leading: const Icon(Icons.history),
            title: Text(l10n.history),
            onTap: () => _open(context, const HistoryPage()),
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

/// Who is signed in, as the menu header and 设置 show it.
String accountLabel(AppUser user) => user.email ?? '—';

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
