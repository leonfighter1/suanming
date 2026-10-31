import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mingli_app/presentation/buttons.dart';
import 'package:mingli_app/presentation/design.dart';
import 'package:mingli_app/presentation/tokens.dart';
import 'package:mingli_app/presentation/keyboard.dart';

import '../application/providers.dart';
import '../domain/models.dart';
import 'account_page.dart';
import 'format.dart';
import 'widgets/common.dart';
import 'widgets/dashboard.dart';

/// Opens an account's own page.
void openAccount(BuildContext context, AdminUser u) => Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => AccountPage(id: u.id, login: u.login)),
    );

/// What sets an account apart, as small labels: its staff role (管理员, 经理, 集成人员), 已停用, AI or 充值 turned off,
/// 演示. In a table they stay on one line (the column takes their width); [wrap] lets them flow onto more lines on an
/// account's page.
class AccountPills extends StatelessWidget {
  const AccountPills(this.u, {super.key, this.wrap = false});
  final AdminUser u;
  final bool wrap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = ThemeTokens.of(context);
    final pills = [
      // A staff role (S25): the admin in the accent, the others quieter.
      if (u.role != 'user')
        Pill(
          u.adminByConfig ? '管理员（服务器指定）' : roleName(u.role),
          color: u.admin ? t.accent : t.textSecondary,
        ),
      if (u.suspended) Pill('已停用', color: scheme.error, icon: Icons.block),
      if (!u.ai) Pill('AI 已关', color: scheme.error),
      if (!u.topUpAllowed) Pill('充值已关', color: scheme.error),
      if (u.demo) Pill('演示', color: scheme.tertiary),
    ];
    if (pills.isEmpty) return const Text('正常');
    if (wrap) return Wrap(spacing: Space.xs, runSpacing: Space.xs, children: pills);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, p) in pills.indexed) ...[if (i > 0) const SizedBox(width: Space.xs), p],
      ],
    );
  }
}

/// 用户 (管理后台, tech plan S22): every account, searched, filtered and sorted, 25 to a page; each opens its own page.
class UsersPage extends ConsumerStatefulWidget {
  const UsersPage({super.key});

  @override
  ConsumerState<UsersPage> createState() => _UsersPageState();
}

/// The sortable columns, by their index in the table.
const _sortColumns = {2: 'balance', 3: 'topup', 4: 'used', 5: 'jobs', 6: 'cost', 7: 'last_seen', 8: 'created'};

class _UsersPageState extends ConsumerState<UsersPage> {
  late final _search = TextEditingController(text: ref.read(userQueryProvider).q);
  Timer? _typing;

  @override
  void dispose() {
    _typing?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _set(UserQuery Function(UserQuery q) change) {
    final n = ref.read(userQueryProvider.notifier);
    n.set(change(ref.read(userQueryProvider)));
  }

  /// Searching as one types, once the typing pauses; Enter searches at once.
  void _searchFor(String text, {bool now = false}) {
    _typing?.cancel();
    void go() => _set((q) => q.copyWith(q: text, page: 1));
    if (now) {
      go();
    } else {
      _typing = Timer(const Duration(milliseconds: 300), go);
    }
  }

  DataColumn _sorted(String label, String key, {bool numeric = true}) => DataColumn(
        label: Text(label),
        numeric: numeric,
        // A new column starts with the largest (the newest) first; the same column again turns the order round.
        onSort: (_, asc) => _set((q) => q.sort == key ? q.copyWith(asc: asc, page: 1) : q.copyWith(sort: key, asc: false, page: 1)),
      );

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(userQueryProvider);
    final users = ref.watch(usersProvider);
    final now = ref.watch(clockProvider)();
    return DashboardLayout(
      // The table in the main column; the search and filters in the panel (S24 WP24.3), before the table on a narrow
      // screen.
      narrowAt: 1,
      main: [
        PageHeader('用户', subtitle: users.whenOrNull(data: (p) => '共 ${count(p.total)} 个账户（全部时间的数字）')),
        AppCard(
          child: AsyncView(
            users,
            onRetry: () => ref.invalidate(usersProvider),
            data: (p) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DataGrid(
                  label: '用户',
                  empty: '没有符合条件的账户',
                  sortColumnIndex: _sortColumns.entries.where((e) => e.value == query.sort).firstOrNull?.key,
                  sortAscending: query.asc,
                  columns: [
                    const DataColumn(label: Text('账户')),
                    const DataColumn(label: Text('状态')),
                    _sorted('积分余额', 'balance'),
                    _sorted('充值', 'topup'),
                    _sorted('已用积分', 'used'),
                    _sorted('AI 次数', 'jobs'),
                    _sorted('AI 成本', 'cost'),
                    _sorted('最近活跃', 'last_seen', numeric: false),
                    _sorted('注册', 'created', numeric: false),
                  ],
                  rows: [
                    for (final u in p.items)
                      DataRow(
                        cells: [
                          DataCell(
                            AppTextButton(
                              key: Key('user-${u.id}'),
                              onPressed: () => openAccount(context, u),
                              child: Text(u.login),
                            ),
                          ),
                          DataCell(AccountPills(u)),
                          DataCell(numText(count(u.balance))),
                          DataCell(numText(yuan(u.topup))),
                          DataCell(numText(count(u.pointsUsed))),
                          DataCell(numText(count(u.jobs))),
                          DataCell(numText(yuan(u.cost))),
                          DataCell(Text(u.lastSeenAt == null ? '—' : ago(u.lastSeenAt!, now))),
                          DataCell(Text(localDay(u.createdAt))),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: Space.s),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '第 ${p.page} / ${p.pages} 页 · 共 ${count(p.total)} 个',
                        key: const Key('users-page'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    AppIconButton(
                      key: const Key('page-prev'),
                      tooltip: '上一页',
                      onPressed: p.page > 1 ? () => _set((q) => q.copyWith(page: p.page - 1)) : null,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    AppIconButton(
                      key: const Key('page-next'),
                      tooltip: '下一页',
                      onPressed: p.page < p.pages ? () => _set((q) => q.copyWith(page: p.page + 1)) : null,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
      aside: [
        PanelSection(
          first: true,
          title: '搜索',
          child: TextField(
            key: const Key('users-search'),
            controller: _search,
            textInputAction: TextInputAction.search,
            onChanged: _searchFor,
            onSubmitted: (t) => _searchFor(t, now: true),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: '搜索',
              // The server matches the shown login (an email or phone shows only in part) or the id's start.
              hintText: '用户名，或账户 ID 的开头',
            ),
          ),
        ),
        PanelSection(
          title: '筛选',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentKeys<String>(
                child: SegmentedButton<String>(
                  key: const Key('filter-status'),
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: '', label: Text('全部状态')),
                    ButtonSegment(value: 'active', label: Text('正常')),
                    ButtonSegment(value: 'suspended', label: Text('已停用')),
                  ],
                  selected: {query.status ?? ''},
                  onSelectionChanged: (s) =>
                      _set((q) => q.copyWith(status: () => s.first.isEmpty ? null : s.first, page: 1)),
                ),
              ),
              const SizedBox(height: Space.s),
              // Five choices (S25) are more than a segmented row holds in the panel: chips, which wrap.
              Wrap(
                key: const Key('filter-role'),
                spacing: Space.s,
                runSpacing: Space.s,
                children: [
                  for (final (value, label) in [('', '全部角色'), for (final e in roleNames.entries) (e.key, e.value)])
                    ChoiceChip(
                      key: ValueKey<String>('filter-role-${value.isEmpty ? 'all' : value}'),
                      label: Text(label),
                      showCheckmark: false,
                      selected: (query.role ?? '') == value,
                      onSelected: (_) => _set((q) => q.copyWith(role: () => value.isEmpty ? null : value, page: 1)),
                    ),
                ],
              ),
              const SizedBox(height: Space.s),
              SegmentKeys<String>(
                child: SegmentedButton<String>(
                  key: const Key('filter-demo'),
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 'include', label: Text('含演示')),
                    ButtonSegment(value: 'exclude', label: Text('不含演示')),
                    ButtonSegment(value: 'only', label: Text('只看演示')),
                  ],
                  selected: {query.demo},
                  onSelectionChanged: (s) => _set((q) => q.copyWith(demo: s.first, page: 1)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
