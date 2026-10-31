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
import 'reports_page.dart';
import 'revenue_page.dart';
import 'usage_page.dart';
import 'users_page.dart';

/// A page of the dashboard, and what the role must be able to do to see it ([Can], tech plan S25).
typedef _Dest = ({String label, IconData icon, IconData selected, String needs, Widget Function() page});

final _dests = <_Dest>[
  (label: '概览', icon: Icons.dashboard_outlined, selected: Icons.dashboard, needs: Can.view, page: OverviewPage.new),
  (label: '用户', icon: Icons.people_outline, selected: Icons.people, needs: Can.view, page: UsersPage.new),
  (label: '活跃', icon: Icons.bolt_outlined, selected: Icons.bolt, needs: Can.view, page: ActivePage.new),
  (label: '收益', icon: Icons.show_chart, selected: Icons.show_chart, needs: Can.view, page: RevenuePage.new),
  (label: '用量', icon: Icons.memory_outlined, selected: Icons.memory, needs: Can.view, page: UsagePage.new),
  (label: '导出', icon: Icons.download_outlined, selected: Icons.download, needs: Can.userData, page: ReportsPage.new),
  (label: '消息', icon: Icons.mail_outline, selected: Icons.mail, needs: Can.messages, page: MessagesPage.new),
  (label: '内容', icon: Icons.article_outlined, selected: Icons.article, needs: Can.content, page: ContentPage.new),
];

/// The width from which the pages sit beside a rail rather than above a bar.
const wideFrom = 840.0;

/// 外观 in the bar (v12.1.0): 跟随系统, 浅色 or 深色, the current one ticked. Enter opens it, the arrows move, Esc closes.
class ThemeMenu extends ConsumerWidget {
  const ThemeMenu({super.key});

  static const _choices = [(ThemeMode.system, '跟随系统'), (ThemeMode.light, '浅色'), (ThemeMode.dark, '深色')];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return PopupMenuButton<ThemeMode>(
      key: const Key('theme'),
      tooltip: '外观：${_choices.firstWhere((c) => c.$1 == mode).$2}',
      icon: Icon(switch (mode) {
        ThemeMode.light => Icons.light_mode_outlined,
        ThemeMode.dark => Icons.dark_mode_outlined,
        ThemeMode.system => Icons.brightness_auto_outlined,
      }),
      initialValue: mode,
      onSelected: (m) => ref.read(themeModeProvider.notifier).set(m),
      itemBuilder: (_) => [
        for (final (m, label) in _choices)
          CheckedPopupMenuItem(key: Key('theme-${m.name}'), value: m, checked: m == mode, child: Text(label)),
      ],
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
    ..invalidate(contentProvider);

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= wideFrom;
    final me = ref.watch(sessionProvider);
    final can = me?.can ?? const <String>{};
    final dests = [for (final d in _dests) if (can.contains(d.needs)) d];
    if (dests.isEmpty) return const Scaffold(body: Center(child: Text('你的角色在这里没有可看的页面')));
    final at = dests.indexWhere((d) => d.label == _page).clamp(0, dests.length - 1);
    final page = KeyedSubtree(key: ValueKey<String>('page-${dests[at].label}'), child: dests[at].page());
    void go(int i) => setState(() => _page = dests[i].label);
    // A rail or a bar takes two pages or more.
    final nav = dests.length > 1;
    return Scaffold(
      appBar: AppBar(
        title: Text(wide ? '命理大师 管理后台' : '管理后台'),
        actions: [
          if (wide && me != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.s),
              child: Center(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: me.login),
                      TextSpan(
                        text: ' · ${roleName(me.role)}',
                        style: TextStyle(color: ThemeTokens.of(context).textSecondary),
                      ),
                    ],
                  ),
                  key: const Key('admin-me'),
                ),
              ),
            ),
          const ThemeMenu(),
          AppIconButton(key: const Key('refresh'), tooltip: '刷新', onPressed: _refresh, icon: const Icon(Icons.refresh)),
          AppIconButton(
            key: const Key('sign-out'),
            tooltip: '退出登录',
            onPressed: () => ref.read(sessionProvider.notifier).signOut(),
            icon: const Icon(Icons.logout),
          ),
          const SizedBox(width: Space.s),
        ],
      ),
      body: wide && nav
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: at,
                  labelType: NavigationRailLabelType.all,
                  onDestinationSelected: go,
                  destinations: [
                    for (final d in dests)
                      NavigationRailDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selected), label: Text(d.label)),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: page),
              ],
            )
          : page,
      bottomNavigationBar: wide || !nav
          ? null
          : NavigationBar(
              selectedIndex: at,
              onDestinationSelected: go,
              destinations: [
                for (final d in dests)
                  NavigationDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selected), label: d.label),
              ],
            ),
    );
  }
}
