import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../application/providers.dart';
import '../domain/points.dart';
import '../l10n/gen/app_localizations.dart';
import 'buttons.dart';
import 'design.dart';
import 'labels.dart';
import 'layout.dart';
import 'widgets/remedy.dart' show compactButtons;

/// What a 积分 change was, as the page lists it: the request a charge paid for, a top-up's pack, a grant.
String pointsWhat(AppLocalizations l10n, PointsEntryView e) {
  String method(String? s) => s == 'bazi' ? l10n.pointsBazi : l10n.methodLabel(s ?? '');
  return switch ((e.kind, e.forKind)) {
    ('topup', _) => l10n.pointsTopUpEntry(e.packYuan ?? 0),
    ('grant', _) => e.reason == 'dev'
        ? l10n.pointsGrantDev
        : (e.reason ?? '').startsWith('admin')
        ? l10n.pointsGrantAdmin
        : l10n.pointsTitle,
    (_, 'report') => l10n.pointsForReading(method(e.system)),
    (_, 'inquiry') => l10n.pointsForInquiry(method(e.system)),
    (_, 'followup') => l10n.kindFollowUp,
    (_, 'life_report') => l10n.kindLife,
    (_, 'remedy') => l10n.kindRemedy,
    _ => l10n.pointsTitle,
  };
}

/// 我的积分 (v11.0.0, S20): what is available and what running requests hold, 充值 (simulated until real payments
/// come), how charging works, and every change. The packs are the owner's: 10元 = 1000 积分, more per 元 in the
/// larger ones.
class PointsPage extends ConsumerStatefulWidget {
  const PointsPage({super.key});

  @override
  ConsumerState<PointsPage> createState() => _PointsPageState();
}

class _PointsPageState extends ConsumerState<PointsPage> {
  /// The pack being added, while its request runs.
  int? _adding;

  Future<void> _topUp(PointsPack pack) async {
    if (_adding != null) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _adding = pack.yuan);
    try {
      await ref.read(apiClientProvider).topUp(pack.yuan);
      ref.invalidate(pointsProvider);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text(l10n.pointsToppedUp(pack.points))));
    } catch (e) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text('${l10n.errorTitle}: $e')));
    } finally {
      if (mounted) setState(() => _adding = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(pointsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.pointsTitle)),
      body: switch (async) {
        AsyncValue(value: final p?) => _body(context, p),
        AsyncValue(error: final e?) => Center(
            child: Padding(padding: pagePadding(context), child: Text('${l10n.errorTitle}\n$e', textAlign: TextAlign.center)),
          ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Widget _body(BuildContext context, PointsView p) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ListView(
      padding: pagePadding(context),
      children: [
        AppCard(
          key: const Key('points-balance'),
          color: scheme.primaryContainer.withValues(alpha: 0.55),
          child: Row(
            children: [
              Icon(Icons.toll_outlined, size: 40, color: scheme.primary),
              const SizedBox(width: Space.l),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.pointsAvailable, style: theme.textTheme.labelLarge),
                    Text(
                      '${p.available}',
                      key: const Key('points-available'),
                      style: theme.textTheme.headlineMedium?.copyWith(color: scheme.primary, fontWeight: FontWeight.w700),
                    ),
                    Text(l10n.pointsBalanceLine(p.balance), style: theme.textTheme.bodyMedium),
                    if (p.held > 0)
                      Text(
                        l10n.pointsHeldLine(p.held),
                        key: const Key('points-held'),
                        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        AppCard(
          key: const Key('points-top-up'),
          title: l10n.pointsTopUp,
          icon: Icons.add_card_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(p.simulated ? l10n.pointsTopUpSimulated : l10n.pointsTopUpUnavailable, style: theme.textTheme.bodyMedium),
              const SizedBox(height: Space.m),
              compactButtons(
                context,
                Wrap(
                  spacing: Space.s,
                  runSpacing: Space.s,
                  children: [for (final pack in p.packs) _PackButton(pack: pack, busy: _adding == pack.yuan, onPressed: p.simulated && _adding == null ? () => _topUp(pack) : null)],
                ),
              ),
            ],
          ),
        ),
        AppCard(
          key: const Key('points-how'),
          title: l10n.pointsHowTitle,
          icon: Icons.info_outline,
          child: Text(l10n.pointsHow, style: ReadingText.small(context)),
        ),
        AppCard(
          key: const Key('points-entries'),
          title: l10n.pointsEntries,
          icon: Icons.receipt_long_outlined,
          child: p.entries.isEmpty
              ? Text(l10n.pointsNoEntries, key: const Key('points-no-entries'))
              : Column(children: [for (final e in p.entries) _EntryRow(entry: e)]),
        ),
      ],
    );
  }
}

/// Every pack's box is as wide as the others (owner, 2026-10-30: 「十元的框跟其他的充值框大小不一」): room for the widest
/// line, 6250 积分, and three to a row on a 360 phone.
const _packWidth = 88.0;

/// One pack: what it costs, the 积分 it brings and its bonus.
class _PackButton extends StatelessWidget {
  const _PackButton({required this.pack, required this.busy, required this.onPressed});
  final PointsPack pack;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return SizedBox(
      width: _packWidth,
      child: AppOutlinedButton(
        key: ValueKey<String>('points-pack-${pack.yuan}'),
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: Space.m, vertical: Space.s)),
        // Each line on one line, and the bonus line's room even without a bonus (10 元): every box as tall as the others.
        child: DefaultTextStyle.merge(
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              busy
                  ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(l10n.pointsPackYuan(pack.yuan), style: theme.textTheme.titleMedium),
              Text(l10n.pointsPackPoints(pack.points), style: theme.textTheme.bodySmall),
              Text(
                pack.bonusPercent > 0 ? l10n.pointsPackBonus(pack.bonusPercent) : '',
                style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.tertiary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One change: what it was, when and how it was priced, how much it was and what it left.
class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry});
  final PointsEntryView entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final e = entry;
    final basis = switch (e.basis) {
      'measured' => l10n.pointsBasisMeasured,
      'estimate' => l10n.pointsBasisEstimate,
      'flat' => l10n.pointsBasisFlat,
      _ => null,
    };
    final details = [
      DateFormat('yyyy-MM-dd HH:mm').format(e.createdAt.toLocal()),
      ?basis,
      ?e.note,
      if (e.usd != null) l10n.pointsCost(e.usd!.toStringAsFixed(3)),
    ].join(' · ');
    final gain = e.points > 0;
    return Padding(
      key: ValueKey<String>('points-entry-${e.id}'),
      padding: const EdgeInsets.symmetric(vertical: Space.s),
      child: Row(
        children: [
          Icon(gain ? Icons.add_circle_outline : Icons.remove_circle_outline, color: gain ? scheme.tertiary : scheme.primary),
          const SizedBox(width: Space.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pointsWhat(l10n, e), style: theme.textTheme.titleSmall),
                Text(details, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(width: Space.s),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                gain ? '+${e.points}' : '${e.points}',
                key: ValueKey<String>('points-amount-${e.id}'),
                style: theme.textTheme.titleSmall?.copyWith(color: gain ? scheme.tertiary : scheme.primary, fontWeight: FontWeight.w700),
              ),
              Text(l10n.pointsBalanceLine(e.balance), style: theme.textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}
