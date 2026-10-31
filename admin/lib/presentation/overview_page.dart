import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mingli_app/presentation/design.dart';
import 'package:mingli_app/presentation/tokens.dart';

import '../application/providers.dart';
import '../domain/models.dart';
import 'format.dart';
import 'users_page.dart' show openAccount;
import 'widgets/common.dart';
import 'widgets/dashboard.dart';
import 'widgets/tables.dart';

/// 概览 (管理后台, tech plan S22; laid out in S24 WP24.3, owner 2026-10-30): the period's 充值 as the page's hero figure
/// with its change and its days, the supporting figures in a compact grid, the revenue curve and each kind of AI job;
/// at the right, a panel of its own: who is online now, how many were active, the accounts and the 积分.
class OverviewPage extends ConsumerWidget {
  const OverviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(overviewProvider);
    final o = overview.value;
    return DashboardLayout(
      main: [
        PageHeader(
          '概览',
          subtitle: o == null ? null : '${o.from} 至 ${o.to}（北京时间）',
          trailing: const PeriodPicker(),
        ),
        AsyncView(
          overview,
          onRetry: () => ref.invalidate(overviewProvider),
          data: (o) => _Figures(o, ref.watch(seriesProvider).value ?? const []),
        ),
        const SizedBox(height: Space.m),
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
      aside: [
        const _Online(),
        if (o != null) ...[_Active(o), _Accounts(o), _Points(o)],
      ],
    );
  }
}

/// The hero (充值收入) and the grid of supporting figures, each with its change against the period before.
class _Figures extends StatelessWidget {
  const _Figures(this.o, this.days);
  final Overview o;
  final List<DayRow> days;

  @override
  Widget build(BuildContext context) {
    final m = o.money;
    final p = o.previous;
    final against = '前 ${o.days} 天';
    Change? change(num now, num? before, {bool upIsGood = true}) =>
        before == null ? null : Change(now.toDouble(), before.toDouble(), against: against, upIsGood: upIsGood);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HeroFigure(
          label: '充值收入',
          number: m.topup, format: yuan,
          change: change(m.topup, p?.money.topup),
          caption: '净收入 ${yuan(m.net)}（扣除支付手续费和增值税）',
          trend: [for (final d in days) d.money.topup],
          trendLabel: '每日充值收入，${o.from} 至 ${o.to}',
        ),
        StatGrid(
          children: [
            StatTile(
              label: 'AI 成本',
              number: m.cost, format: yuan,
              change: change(m.cost, p?.money.cost, upIsGood: false),
              detail: '${usd(o.costUsd)} · ${count(o.jobs)} 次 AI 请求',
            ),
            StatTile(label: '毛利', number: m.profit, format: yuan, change: change(m.profit, p?.money.profit), detail: '净收入减 AI 成本'),
            StatTile(
              label: '毛利率',
              value: percent(m.margin),
              change: m.margin == null || p?.money.margin == null
                  ? null
                  : Change(m.margin!, p!.money.margin!, against: against, points: true),
              detail: '毛利 ÷ 净收入',
            ),
            StatTile(
              label: '新增账户',
              number: o.newAccounts, format: count,
              change: change(o.newAccounts, p?.newAccounts),
              detail: '共 ${count(o.accounts)} 个账户',
            ),
            StatTile(
              label: 'AI 请求',
              number: o.jobs, format: count,
              change: change(o.jobs, p?.jobs),
              detail: '完成 ${count(o.deliveredJobs)} 次',
            ),
            StatTile(
              label: 'Tokens',
              number: o.tokens, format: compact,
              change: change(o.tokens, p?.tokens),
              detail: '输入 ${compact(o.inputTokens)} · 输出 ${compact(o.outputTokens)}',
            ),
            StatTile(
              label: '售出积分',
              number: o.pointsSold, format: count,
              change: change(o.pointsSold, p?.pointsSold),
              detail: '赠送 ${count(o.pointsGranted)}',
            ),
            StatTile(
              label: '消耗积分',
              number: o.pointsUsed, format: count,
              change: change(o.pointsUsed, p?.pointsUsed),
              detail: '用户持有 ${count(o.pointsOutstanding)}',
            ),
          ],
        ),
      ],
    );
  }
}

/// 此刻在线: who made a request in the last 15 minutes, the latest first; each opens its account.
class _Online extends ConsumerWidget {
  const _Online();

  static const _shown = 6;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeProvider);
    final now = ref.watch(clockProvider)();
    final theme = Theme.of(context);
    final t = ThemeTokens.of(context);
    return PanelSection(
      first: true,
      title: '此刻在线',
      trailing: Text(
        active.whenOrNull(data: (a) => count(a.inNow)) ?? '',
        key: const Key('online-count'),
        style: theme.textTheme.titleLarge?.copyWith(color: t.accent),
      ),
      child: AsyncView(
        active,
        onRetry: () => ref.invalidate(activeProvider),
        data: (a) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (a.now.isEmpty)
              Text('15 分钟内没有人在用', style: theme.textTheme.bodyMedium?.copyWith(color: t.textMuted)),
            for (final u in a.now.take(_shown)) _Person(u, now),
            if (a.now.length > _shown)
              Padding(
                padding: const EdgeInsets.only(top: Space.xs),
                child: Text('还有 ${a.now.length - _shown} 人，见“活跃”', style: theme.textTheme.bodySmall?.copyWith(color: t.textMuted)),
              ),
          ],
        ),
      ),
    );
  }
}

/// An account in the panel: its initial, its name and when it was last seen; Enter or a tap opens its page.
class _Person extends StatelessWidget {
  const _Person(this.u, this.now);
  final AdminUser u;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = ThemeTokens.of(context);
    return InkWell(
      key: ValueKey<String>('online-${u.id}'),
      borderRadius: BorderRadius.circular(Radii.field),
      onTap: () => openAccount(context, u),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.s),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: t.accentSoft,
              child: Text(
                u.login.characters.first.toUpperCase(),
                style: theme.textTheme.labelLarge?.copyWith(color: t.onAccentSoft),
              ),
            ),
            const SizedBox(width: Space.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(u.login, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
                  Text(
                    u.lastSeenAt == null ? '—' : ago(u.lastSeenAt!, now),
                    style: theme.textTheme.bodySmall?.copyWith(color: t.textMuted),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: t.textMuted),
          ],
        ),
      ),
    );
  }
}

class _Active extends StatelessWidget {
  const _Active(this.o);
  final Overview o;

  @override
  Widget build(BuildContext context) => PanelSection(
        title: '活跃',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Meter(label: '24 小时内', value: o.activeDay, of: o.accounts),
            Meter(label: '7 天内', value: o.activeWeek, of: o.accounts),
            Meter(label: '30 天内', value: o.activeMonth, of: o.accounts),
          ],
        ),
      );
}

class _Accounts extends StatelessWidget {
  const _Accounts(this.o);
  final Overview o;

  @override
  Widget build(BuildContext context) => PanelSection(
        title: '账户',
        child: Column(
          children: [
            NumberRow('全部', count(o.accounts), valueKey: const Key('panel-accounts')),
            NumberRow('本期新增', count(o.newAccounts)),
            NumberRow('已停用', count(o.suspended)),
            NumberRow('管理员', count(o.admins)),
            if (o.demo > 0) NumberRow('演示', count(o.demo)),
          ],
        ),
      );
}

class _Points extends StatelessWidget {
  const _Points(this.o);
  final Overview o;

  @override
  Widget build(BuildContext context) => PanelSection(
        title: '积分',
        child: Column(
          children: [
            NumberRow('用户持有', count(o.pointsOutstanding), valueKey: const Key('panel-outstanding')),
            NumberRow('本期售出', count(o.pointsSold)),
            NumberRow('本期赠送', count(o.pointsGranted)),
            NumberRow('本期消耗', count(o.pointsUsed)),
          ],
        ),
      );
}
