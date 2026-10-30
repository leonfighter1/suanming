import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mingli_app/presentation/design.dart';

import '../application/providers.dart';
import '../domain/models.dart';
import 'format.dart';
import 'widgets/common.dart';
import 'widgets/kpi_tile.dart';
import 'widgets/tables.dart';

/// 概览 (管理后台, tech plan S22): the period's money, accounts, active users, tokens and 积分, the revenue curve, and
/// what each kind of AI job cost.
class OverviewPage extends ConsumerWidget {
  const OverviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(overviewProvider);
    return PageBody(
      children: [
        PageHeader(
          '概览',
          subtitle: overview.whenOrNull(data: (o) => '${o.from} 至 ${o.to}（北京时间）'),
          trailing: const PeriodPicker(),
        ),
        AsyncView(overview, onRetry: () => ref.invalidate(overviewProvider), data: (o) => _Figures(o)),
        const SizedBox(height: Space.l),
        AppCard(
          title: '收益曲线',
          icon: Icons.show_chart,
          child: AsyncView(
            ref.watch(seriesProvider),
            onRetry: () => ref.invalidate(seriesProvider),
            data: (days) => RevenueChart(days),
          ),
        ),
        AppCard(
          title: '各项目',
          icon: Icons.category_outlined,
          child: AsyncView(
            ref.watch(breakdownProvider),
            onRetry: () => ref.invalidate(breakdownProvider),
            data: (b) => MethodTable(b.byMethod),
          ),
        ),
      ],
    );
  }
}

class _Figures extends StatelessWidget {
  const _Figures(this.o);
  final Overview o;

  @override
  Widget build(BuildContext context) {
    final m = o.money;
    return KpiGrid(
      children: [
        KpiTile(
          label: '充值收入',
          value: yuan(m.topup),
          icon: Icons.payments_outlined,
          detail: '净收入 ${yuan(m.net)}（扣除支付手续费和增值税）',
        ),
        KpiTile(
          label: 'AI 成本',
          value: yuan(m.cost),
          icon: Icons.memory_outlined,
          detail: '${usd(o.costUsd)} · ${count(o.jobs)} 次 AI 请求',
        ),
        KpiTile(
          label: '毛利',
          value: yuan(m.profit),
          icon: Icons.trending_up,
          tone: m.profit < 0 ? Theme.of(context).colorScheme.error : null,
          detail: '毛利率 ${percent(m.margin)}（毛利 ÷ 净收入）',
        ),
        KpiTile(
          label: '账户',
          value: count(o.accounts),
          icon: Icons.people_outline,
          detail: [
            '新增 ${count(o.newAccounts)}',
            '停用 ${count(o.suspended)}',
            '管理员 ${count(o.admins)}',
            if (o.demo > 0) '演示 ${count(o.demo)}',
          ].join(' · '),
        ),
        KpiTile(
          label: '活跃（15 分钟内）',
          value: count(o.activeNow),
          icon: Icons.bolt_outlined,
          detail: '24 小时 ${count(o.activeDay)} · 7 天 ${count(o.activeWeek)} · 30 天 ${count(o.activeMonth)}',
        ),
        KpiTile(
          label: 'Tokens',
          value: compact(o.tokens),
          icon: Icons.data_usage,
          detail: '输入 ${compact(o.inputTokens)} · 输出 ${compact(o.outputTokens)}',
        ),
        KpiTile(
          label: '售出积分',
          value: count(o.pointsSold),
          icon: Icons.toll_outlined,
          detail: '赠送 ${count(o.pointsGranted)} · 消耗 ${count(o.pointsUsed)} · 未用 ${count(o.pointsOutstanding)}',
        ),
      ],
    );
  }
}
