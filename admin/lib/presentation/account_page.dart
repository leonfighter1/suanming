import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mingli_app/presentation/design.dart';
import 'package:mingli_app/presentation/keyboard.dart';

import '../application/providers.dart';
import '../domain/models.dart';
import 'format.dart';
import 'messages.dart';
import 'users_page.dart';
import 'widgets/common.dart';
import 'widgets/dashboard.dart';
import 'widgets/tables.dart';

/// The most an admin grants at once (the server's GRANT_MAX).
const grantMax = 1000000;

/// One account (管理后台, tech plan S22; laid out in S24 WP24.3): its numbers, its 积分 ledger, its latest AI jobs and
/// what each kind of job cost; in the panel, suspending it, the admin role and its permissions, 增加积分 and signing it
/// out everywhere.
class AccountPage extends ConsumerStatefulWidget {
  const AccountPage({super.key, required this.id, required this.login});
  final String id;
  final String login;

  @override
  ConsumerState<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends ConsumerState<AccountPage> {
  final _points = TextEditingController();
  final _note = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _points.dispose();
    _note.dispose();
    super.dispose();
  }

  /// The numbers that change with this account, fetched again.
  void _changed() => ref
    ..invalidate(userProvider(widget.id))
    ..invalidate(usersProvider)
    ..invalidate(overviewProvider)
    ..invalidate(seriesProvider)
    ..invalidate(activeProvider);

  Future<void> _run(Future<String> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final done = await action();
      _changed();
      if (mounted) say(context, done);
    } catch (e) {
      if (mounted) say(context, problemText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title, String body) async =>
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(key: const Key('confirm-no'), onPressed: () => Navigator.pop(c, false), child: const Text('取消')),
            FilledButton(
              key: const Key('confirm-yes'),
              autofocus: true,
              onPressed: () => Navigator.pop(c, true),
              child: const Text('确定'),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _update(Map<String, Object?> change, String done) => _run(() async {
        await ref.read(adminApiProvider).updateUser(widget.id, change);
        return done;
      });

  Future<void> _suspend(AdminUser u, bool on) async {
    if (on && !await _confirm('停用 ${u.login}？', '停用后这个账号会在所有设备上退出，也不能再登录，直到恢复。')) return;
    await _update({'status': on ? 'suspended' : 'active'}, on ? '已停用 ${u.login}' : '已恢复 ${u.login}');
  }

  Future<void> _admin(AdminUser u, bool on) async {
    if (on && !await _confirm('设 ${u.login} 为管理员？', '管理员可以查看所有账户和收益，停用账户、修改权限和增加积分。')) return;
    await _update({'role': on ? 'admin' : 'user'}, on ? '${u.login} 已是管理员' : '已取消 ${u.login} 的管理员');
  }

  Future<void> _grant(AdminUser u) async {
    if (_busy) return;
    final n = int.tryParse(_points.text.trim());
    if (n == null || n < 1 || n > grantMax) {
      say(context, '积分请填 1 到 ${count(grantMax)} 之间的整数');
      return;
    }
    final note = _note.text.trim();
    if (!await _confirm('给 ${u.login} 增加 ${count(n)} 积分？', note.isEmpty ? '会记在这个账户的积分记录里。' : '备注：$note')) return;
    await _run(() async {
      final balance = await ref.read(adminApiProvider).grant(widget.id, n, note: note);
      _points.clear();
      _note.clear();
      return '已增加 ${count(n)} 积分，余额 ${count(balance)}';
    });
  }

  Future<void> _signOutEverywhere(AdminUser u) => _run(() async {
        await ref.read(adminApiProvider).signOutEverywhere(widget.id);
        return '${u.login} 已在所有设备上退出';
      });
  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(userProvider(widget.id));
    final user = detail.value?.user;
    void retry() => ref.invalidate(userProvider(widget.id));
    return SubmitShortcut(
      onSubmit: _busy || user == null ? null : () => _grant(user),
      child: Scaffold(
        appBar: AppBar(title: Text(user?.login ?? widget.login)),
        // The account's numbers and records in the main column; what an admin does to it in the panel (S24 WP24.3),
        // after its figures on a narrow screen.
        body: DashboardLayout(
          narrowAt: 1,
          main: [
            AsyncView(detail, onRetry: retry, data: _figures),
            AsyncView(detail, onRetry: retry, data: _records),
          ],
          aside: [AsyncView(detail, onRetry: retry, data: _actions)],
        ),
      ),
    );
  }

  /// 积分余额 as the hero, with how the ledger brought it there; the account's money and AI use; its facts.
  Widget _figures(UserDetail d) {
    final u = d.user;
    final now = ref.watch(clockProvider)();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HeroFigure(
          label: '积分余额',
          value: count(u.balance),
          valueKey: const Key('account-balance'),
          caption: u.held > 0 ? '其中 ${count(u.held)} 冻结在进行中的 AI 请求里' : '没有冻结的积分',
          // The ledger lists the newest first; the line runs oldest to newest.
          trend: [for (final e in d.entries.reversed) e.balance.toDouble()],
          trendLabel: '积分余额，按积分记录从早到晚',
        ),
        StatGrid(
          children: [
            StatTile(label: '充值合计', value: yuan(u.topup)),
            StatTile(label: '已用积分', value: count(u.pointsUsed)),
            StatTile(label: 'AI 请求', value: count(u.jobs), detail: '${compact(u.tokens)} tokens'),
            StatTile(label: 'AI 成本', value: yuan(u.cost)),
          ],
        ),
        AppCard(
          title: '账户',
          icon: Icons.person_outline,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(alignment: Alignment.centerLeft, child: AccountPills(u, wrap: true)),
              const SizedBox(height: Space.s),
              Fact('账户 ID', u.id),
              Fact('地区', u.country.isEmpty ? '—' : u.country),
              Fact('注册', localTime(u.createdAt)),
              Fact('最近活跃', u.lastSeenAt == null ? '—' : '${localTime(u.lastSeenAt!)}（${ago(u.lastSeenAt!, now)}）'),
            ],
          ),
        ),
      ],
    );
  }

  /// The account's 积分 ledger, its latest AI jobs, and what each kind of job cost.
  Widget _records(UserDetail d) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            title: '积分记录',
            icon: Icons.receipt_long_outlined,
            child: DataGrid(
              label: '积分记录',
              empty: '还没有积分记录',
              columns: const [
                DataColumn(label: Text('时间')),
                DataColumn(label: Text('项目')),
                DataColumn(label: Text('积分'), numeric: true),
                DataColumn(label: Text('余额'), numeric: true),
                DataColumn(label: Text('备注')),
              ],
              rows: [
                for (final e in d.entries)
                  DataRow(
                    cells: [
                      DataCell(Text(localTime(e.createdAt))),
                      DataCell(
                        Text(entryOf(kind: e.kind, forKind: e.forKind, system: e.system, packYuan: e.packYuan, reason: e.reason)),
                      ),
                      DataCell(numText(e.points > 0 ? '+${count(e.points)}' : '-${count(-e.points)}')),
                      DataCell(numText(count(e.balance))),
                      DataCell(Text(e.note ?? '')),
                    ],
                  ),
              ],
            ),
          ),
          AppCard(
            title: 'AI 记录',
            icon: Icons.memory_outlined,
            child: DataGrid(
              label: 'AI 记录',
              empty: '还没有 AI 请求',
              columns: const [
                DataColumn(label: Text('时间')),
                DataColumn(label: Text('项目')),
                DataColumn(label: Text('模型')),
                DataColumn(label: Text('Tokens'), numeric: true),
                DataColumn(label: Text('成本'), numeric: true),
                DataColumn(label: Text('结果')),
              ],
              rows: [
                for (final j in d.jobs)
                  DataRow(
                    cells: [
                      DataCell(Text(localTime(j.createdAt))),
                      DataCell(Text(whatOf(j.kind, j.system))),
                      DataCell(Text(j.models.join('、'))),
                      DataCell(numText(compact(j.tokens))),
                      DataCell(numText(yuan(j.cost))),
                      DataCell(Text(j.delivered ? '已完成' : '未完成')),
                    ],
                  ),
              ],
            ),
          ),
          AppCard(title: '各项目用量', icon: Icons.category_outlined, child: MethodTable(d.byMethod)),
        ],
      );

  /// What an admin does to the account, in the panel: its permissions, a grant of 积分, signing it out everywhere.
  Widget _actions(UserDetail d) {
    final u = d.user;
    final self = ref.watch(sessionProvider)?.id == u.id;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PanelSection(
          first: true,
          title: '权限',
          child: Column(
            children: [
              SwitchListTile(
                key: const Key('switch-suspended'),
                contentPadding: EdgeInsets.zero,
                title: const Text('停用账户'),
                subtitle: Text(self ? '不能停用自己' : '停用后不能登录，已登录的设备立即退出'),
                value: u.suspended,
                onChanged: _busy || self ? null : (v) => _suspend(u, v),
              ),
              SwitchListTile(
                key: const Key('switch-admin'),
                contentPadding: EdgeInsets.zero,
                title: const Text('管理员'),
                subtitle: Text(
                  u.adminByConfig
                      ? '由服务器设置（MINGLI_ADMINS）指定，不能在这里取消'
                      : self
                          ? '不能取消自己的管理员'
                          : '可以登录管理后台，管理所有账户',
                ),
                value: u.admin,
                onChanged: _busy || self || u.adminByConfig ? null : (v) => _admin(u, v),
              ),
              SwitchListTile(
                key: const Key('switch-ai'),
                contentPadding: EdgeInsets.zero,
                title: const Text('可以用 AI'),
                subtitle: const Text('关闭后不能再发起 AI 解读、追问、深度分析和一生运势报告'),
                value: u.ai,
                onChanged: _busy
                    ? null
                    : (v) => _update({
                          'permissions': {'ai': v},
                        }, v ? '已允许 ${u.login} 用 AI' : '已关闭 ${u.login} 的 AI'),
              ),
              SwitchListTile(
                key: const Key('switch-topup'),
                contentPadding: EdgeInsets.zero,
                title: const Text('可以充值'),
                value: u.topUpAllowed,
                onChanged: _busy
                    ? null
                    : (v) => _update({
                          'permissions': {'top_up': v},
                        }, v ? '已允许 ${u.login} 充值' : '已关闭 ${u.login} 的充值'),
              ),
            ],
          ),
        ),
        PanelSection(
          title: '增加积分',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const Key('grant-points'),
                controller: _points,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: '积分', helperText: '1 到 ${count(grantMax)}'),
              ),
              const SizedBox(height: Space.s),
              Wrap(
                spacing: Space.s,
                children: [
                  for (final n in const [100, 1000, 5000])
                    ActionChip(
                      key: Key('grant-$n'),
                      label: Text(count(n)),
                      onPressed: () => _points.text = '$n',
                    ),
                ],
              ),
              const SizedBox(height: Space.m),
              TextField(
                key: const Key('grant-note'),
                controller: _note,
                maxLength: 200,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _grant(u),
                decoration: const InputDecoration(labelText: '备注（可不填）', hintText: '例如：活动奖励、补偿'),
              ),
              const SizedBox(height: Space.s),
              // The panel's main action spans its column.
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('grant-submit'),
                  onPressed: _busy ? null : () => _grant(u),
                  icon: const Icon(Icons.add),
                  label: const Text('增加积分'),
                ),
              ),
            ],
          ),
        ),
        PanelSection(
          title: '登录',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('让这个账户在所有设备上退出登录，下次要重新登录。', style: theme.textTheme.bodyMedium),
              const SizedBox(height: Space.m),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: const Key('sign-out-everywhere'),
                  onPressed: _busy ? null : () => _signOutEverywhere(u),
                  icon: const Icon(Icons.logout),
                  label: const Text('在所有设备上退出'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
