import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mingli_app/presentation/design.dart';

import '../application/providers.dart';
import 'active_page.dart';
import 'overview_page.dart';
import 'reports_page.dart';
import 'revenue_page.dart';
import 'usage_page.dart';
import 'users_page.dart';

typedef _Dest = ({String label, IconData icon, IconData selected});

const _dests = <_Dest>[
  (label: '概览', icon: Icons.dashboard_outlined, selected: Icons.dashboard),
  (label: '用户', icon: Icons.people_outline, selected: Icons.people),
  (label: '活跃', icon: Icons.bolt_outlined, selected: Icons.bolt),
  (label: '收益', icon: Icons.show_chart, selected: Icons.show_chart),
  (label: '用量', icon: Icons.memory_outlined, selected: Icons.memory),
  (label: '导出', icon: Icons.download_outlined, selected: Icons.download),
];

/// The width from which the pages sit beside a rail rather than above a bar.
const wideFrom = 840.0;

/// The dashboard's six pages (管理后台, tech plan S22): a rail beside them on a wide screen, a bar under them on a phone.
class AdminShell extends ConsumerStatefulWidget {
  const AdminShell({super.key});

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  int _tab = 0;

  /// Everything fetched again.
  void _refresh() => ref
    ..invalidate(overviewProvider)
    ..invalidate(seriesProvider)
    ..invalidate(breakdownProvider)
    ..invalidate(usersProvider)
    ..invalidate(userProvider)
    ..invalidate(activeProvider);

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= wideFrom;
    final me = ref.watch(sessionProvider);
    final page = switch (_tab) {
      0 => const OverviewPage(),
      1 => const UsersPage(),
      2 => const ActivePage(),
      3 => const RevenuePage(),
      4 => const UsagePage(),
      _ => const ReportsPage(),
    };
    void go(int i) => setState(() => _tab = i);
    return Scaffold(
      appBar: AppBar(
        title: Text(wide ? '命理大师 管理后台' : '管理后台'),
        actions: [
          if (wide && me != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.s),
              child: Center(child: Text(me.login, key: const Key('admin-me'))),
            ),
          IconButton(key: const Key('refresh'), tooltip: '刷新', onPressed: _refresh, icon: const Icon(Icons.refresh)),
          IconButton(
            key: const Key('sign-out'),
            tooltip: '退出登录',
            onPressed: () => ref.read(sessionProvider.notifier).signOut(),
            icon: const Icon(Icons.logout),
          ),
          const SizedBox(width: Space.s),
        ],
      ),
      body: wide
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: _tab,
                  labelType: NavigationRailLabelType.all,
                  onDestinationSelected: go,
                  destinations: [
                    for (final d in _dests)
                      NavigationRailDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selected), label: Text(d.label)),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: page),
              ],
            )
          : page,
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: go,
              destinations: [
                for (final d in _dests)
                  NavigationDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selected), label: d.label),
              ],
            ),
    );
  }
}
