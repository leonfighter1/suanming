import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mingli_app/presentation/design.dart';

import '../application/providers.dart';
import '../domain/models.dart';
import 'format.dart';
import 'users_page.dart';
import 'widgets/common.dart';
import 'widgets/dashboard.dart';

/// 活跃 (管理后台, tech plan S22): who is using the app now and today, by each account's latest request, fetched again
/// every minute; each account opens its own page, to manage it.
class ActivePage extends ConsumerStatefulWidget {
  const ActivePage({super.key});

  @override
  ConsumerState<ActivePage> createState() => _ActivePageState();
}

class _ActivePageState extends ConsumerState<ActivePage> {
  late final Timer _every;

  @override
  void initState() {
    super.initState();
    _every = Timer.periodic(const Duration(minutes: 1), (_) => ref.invalidate(activeProvider));
  }

  @override
  void dispose() {
    _every.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(clockProvider)();
    return PageBody(
      children: [
        const PageHeader('活跃', subtitle: '按每个账户最近一次请求的时间，每分钟刷新'),
        AsyncView(
          ref.watch(activeProvider),
          onRetry: () => ref.invalidate(activeProvider),
          data: (a) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Who is on now leads (S24 WP24.3); the longer windows support it.
              HeroFigure(label: '15 分钟内', value: count(a.inNow), caption: '此刻在用的账户'),
              StatGrid(
                maxColumns: 3,
                children: [
                  StatTile(label: '24 小时内', value: count(a.inDay), icon: Icons.today_outlined),
                  StatTile(label: '7 天内', value: count(a.inWeek), icon: Icons.date_range_outlined),
                  StatTile(label: '30 天内', value: count(a.inMonth), icon: Icons.calendar_month_outlined),
                ],
              ),
              AppCard(
                title: '此刻在用（15 分钟内）',
                icon: Icons.bolt_outlined,
                child: _Accounts(a.now, now, list: 'now', empty: '这 15 分钟里没有人在用'),
              ),
              AppCard(
                title: '24 小时内',
                icon: Icons.today_outlined,
                child: _Accounts(a.day, now, list: 'day', empty: '这 24 小时里没有人用过'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Accounts extends StatelessWidget {
  const _Accounts(this.users, this.now, {required this.list, required this.empty});
  final List<AdminUser> users;
  final DateTime now;

  /// Which list (now, day): an account active now is in both.
  final String list;
  final String empty;

  @override
  Widget build(BuildContext context) => DataGrid(
        label: '活跃账户',
        empty: empty,
        columns: const [
          DataColumn(label: Text('账户')),
          DataColumn(label: Text('最近活跃')),
          DataColumn(label: Text('状态')),
          DataColumn(label: Text('积分余额'), numeric: true),
          DataColumn(label: Text('AI 次数'), numeric: true),
        ],
        rows: [
          for (final u in users)
            DataRow(
              cells: [
                DataCell(
                  TextButton(
                    key: Key('active-$list-${u.id}'),
                    onPressed: () => openAccount(context, u),
                    child: Text(u.login),
                  ),
                ),
                DataCell(Text(u.lastSeenAt == null ? '—' : ago(u.lastSeenAt!, now))),
                DataCell(AccountPills(u)),
                DataCell(numText(count(u.balance))),
                DataCell(numText(count(u.jobs))),
              ],
            ),
        ],
      );
}
