import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mingli_app/presentation/buttons.dart';
import 'package:mingli_app/presentation/design.dart';
import 'package:mingli_app/presentation/tokens.dart';

import '../application/providers.dart';
import '../domain/models.dart';
import 'active_page.dart';
import 'content_page.dart';
import 'format.dart';
import 'messages_page.dart';
import 'overview_page.dart';
import 'settings_page.dart';
import 'reports_page.dart';
import 'revenue_page.dart';
import 'usage_page.dart';
import 'users_page.dart';

/// A page of the dashboard, what the role must be able to do to see it ([Can], tech plan S25), and whether it sits in
/// the menu at the top right rather than the rail (S33).
typedef _Dest = ({String label, IconData icon, IconData selected, String needs, Widget Function() page, bool inMenu});

final _dests = <_Dest>[
  (label: '概览', icon: Icons.dashboard_outlined, selected: Icons.dashboard, needs: Can.view, page: OverviewPage.new, inMenu: false),
  (label: '用户', icon: Icons.people_outline, selected: Icons.people, needs: Can.view, page: UsersPage.new, inMenu: false),
  (label: '活跃', icon: Icons.bolt_outlined, selected: Icons.bolt, needs: Can.view, page: ActivePage.new, inMenu: false),
  (label: '收益', icon: Icons.show_chart, selected: Icons.show_chart, needs: Can.view, page: RevenuePage.new, inMenu: false),
  (label: '用量', icon: Icons.memory_outlined, selected: Icons.memory, needs: Can.view, page: UsagePage.new, inMenu: false),
  (label: '设置', icon: Icons.tune_outlined, selected: Icons.tune, needs: Can.settings, page: SettingsPage.new, inMenu: false),
  // The owner (S33): 「内容页面需要移动到管理员页面右上角，同时管理员右上角应该改成下拉菜单，而且把导出和消息也放进去」.
  (label: '内容', icon: Icons.article_outlined, selected: Icons.article, needs: Can.content, page: ContentPage.new, inMenu: true),
  (label: '消息', icon: Icons.mail_outline, selected: Icons.mail, needs: Can.messages, page: MessagesPage.new, inMenu: true),
  (label: '导出', icon: Icons.download_outlined, selected: Icons.download, needs: Can.userData, page: ReportsPage.new, inMenu: true),
];

/// The width from which the pages sit beside a rail rather than above a bar.
const wideFrom = 840.0;

/// 外观 (v12.1.0): the system's light or dark, or one of them always, kept in this browser.
const _themes = [
  (ThemeMode.system, '跟随系统', Icons.brightness_auto_outlined),
  (ThemeMode.light, '浅色', Icons.light_mode_outlined),
  (ThemeMode.dark, '深色', Icons.dark_mode_outlined),
];

/// The menu at the top right (S33): the pages that live there (内容, 消息, 导出, as far as the role may), 外观 and
/// 退出登录. Its button is the staff member and the role on a wide screen, an icon on a phone. Enter opens it, the
/// arrows move, Esc closes.
class _AdminMenu extends ConsumerStatefulWidget {
  const _AdminMenu({required this.me, required this.pages, required this.current, required this.onPage, required this.wide});
  final AdminMe me;
  final List<_Dest> pages;
  final String current;
  final ValueChanged<String> onPage;
  final bool wide;

  @override
  ConsumerState<_AdminMenu> createState() => _AdminMenuState();
}

class _AdminMenuState extends ConsumerState<_AdminMenu> {
  /// The button's focus: from it, ↓ moves into the open menu.
  final _button = FocusNode(debugLabel: 'admin-menu');

  AdminMe get me => widget.me;
  List<_Dest> get pages => widget.pages;
  String get current => widget.current;
  ValueChanged<String> get onPage => widget.onPage;
  bool get wide => widget.wide;

  @override
  void dispose() {
    _button.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(themeModeProvider);
    final tk = ThemeTokens.of(context);
    return MenuAnchor(
      childFocusNode: _button,
      menuChildren: [
        for (final d in pages)
          MenuItemButton(
            key: ValueKey<String>('menu-${d.label}'),
            leadingIcon: Icon(d.label == current ? d.selected : d.icon),
            onPressed: () => onPage(d.label),
            child: Text(d.label),
          ),
        if (pages.isNotEmpty) const Divider(height: Space.s),
        SubmenuButton(
          key: const Key('theme'),
          leadingIcon: Icon(_themes.firstWhere((t) => t.$1 == mode).$3),
          menuChildren: [
            for (final (m, label, _) in _themes)
              MenuItemButton(
                key: Key('theme-${m.name}'),
                trailingIcon: m == mode ? const Icon(Icons.check) : null,
                onPressed: () => ref.read(themeModeProvider.notifier).set(m),
                child: Text(label),
              ),
          ],
          child: const Text('外观'),
        ),
        MenuItemButton(
          key: const Key('sign-out'),
          leadingIcon: const Icon(Icons.logout),
          onPressed: () => ref.read(sessionProvider.notifier).signOut(),
          child: const Text('退出登录'),
        ),
      ],
      builder: (context, controller, _) {
        void toggle() => controller.isOpen ? controller.close() : controller.open();
        if (!wide) {
          return AppIconButton(
            key: const Key('admin-menu'),
            focusNode: _button,
            tooltip: '${me.login} · ${roleName(me.role)}',
            onPressed: toggle,
            icon: const Icon(Icons.account_circle_outlined),
          );
        }
        return AppTextButton(
          key: const Key('admin-menu'),
          focusNode: _button,
          onPressed: toggle,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: me.login, style: TextStyle(color: tk.text)),
                    TextSpan(text: ' · ${roleName(me.role)}', style: TextStyle(color: tk.textSecondary)),
                  ],
                ),
                key: const Key('admin-me'),
              ),
              const SizedBox(width: Space.xs),
              Icon(Icons.arrow_drop_down, color: tk.textSecondary),
            ],
          ),
        );
      },
    );
  }
}

/// The dashboard's pages (管理后台, tech plan S22), those the role may see (S25): a rail beside them on a wide screen, a
/// bar under them on a phone; a role with one page gets the page alone.
class AdminShell extends ConsumerStatefulWidget {
  const AdminShell({super.key});

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  /// The page shown, by its label: it stays when the role changes and the list with it.
  String? _page;

  /// The last page of the rail shown: where a phone goes back to from a page of the menu.
  String? _railPage;

  /// Everything fetched again.
  void _refresh() => ref
    ..invalidate(overviewProvider)
    ..invalidate(seriesProvider)
    ..invalidate(breakdownProvider)
    ..invalidate(usersProvider)
    ..invalidate(userProvider)
    ..invalidate(activeProvider)
    ..invalidate(messagesProvider)
    ..invalidate(dispatchLogProvider)
    ..invalidate(contentProvider)
    ..invalidate(settingsProvider);

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= wideFrom;
    final me = ref.watch(sessionProvider);
    final can = me?.can ?? const <String>{};
    final dests = [for (final d in _dests) if (can.contains(d.needs)) d];
    if (dests.isEmpty) return const Scaffold(body: Center(child: Text('你的角色在这里没有可看的页面')));
    final rail = [for (final d in dests) if (!d.inMenu) d];
    final menu = [for (final d in dests) if (d.inMenu) d];
    final shown = dests.firstWhere((d) => d.label == _page, orElse: () => rail.isEmpty ? menu.first : rail.first);
    final at = rail.indexOf(shown);
    final page = KeyedSubtree(key: ValueKey<String>('page-${shown.label}'), child: shown.page());
    void go(String label) => setState(() {
          _page = label;
          if (rail.any((d) => d.label == label)) _railPage = label;
        });
    // A rail or a bar takes two pages or more. On a phone a page of the menu takes the bar's place, with a way back.
    final nav = rail.length > 1;
    final back = !wide && nav && at < 0;
    return Scaffold(
      appBar: AppBar(
        leading: back
            ? AppIconButton(
                key: const Key('menu-back'),
                tooltip: '返回',
                onPressed: () => go(_railPage ?? rail.first.label),
                icon: const Icon(Icons.arrow_back),
              )
            : null,
        title: Text(wide ? '命理大师 管理后台' : (at < 0 ? shown.label : '管理后台')),
        actions: [
          AppIconButton(key: const Key('refresh'), tooltip: '刷新', onPressed: _refresh, icon: const Icon(Icons.refresh)),
          if (me != null) _AdminMenu(me: me, pages: menu, current: shown.label, onPage: go, wide: wide),
          const SizedBox(width: Space.s),
        ],
      ),
      body: wide && nav
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: at < 0 ? null : at,
                  labelType: NavigationRailLabelType.all,
                  onDestinationSelected: (i) => go(rail[i].label),
                  destinations: [
                    for (final d in rail)
                      NavigationRailDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selected), label: Text(d.label)),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: page),
              ],
            )
          : page,
      bottomNavigationBar: wide || !nav || back
          ? null
          : NavigationBar(
              selectedIndex: at,
              onDestinationSelected: (i) => go(rail[i].label),
              destinations: [
                for (final d in rail)
                  NavigationDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selected), label: d.label),
              ],
            ),
    );
  }
}
