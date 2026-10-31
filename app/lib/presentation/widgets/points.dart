import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../data/api_client.dart';
import '../../domain/points.dart';
import '../../l10n/gen/app_localizations.dart';
import '../buttons.dart';
import '../design.dart';
import '../points_page.dart';
import 'remedy.dart' show compactButtons;

/// What an AI button's request costs (积分, v11.0.0): 「约 N 积分 · 完成后按实际用量扣除 · 可用 M」, or with [fee] the
/// 深度分析's 统一收费. Nothing while 积分 are off or the price isn't known yet. Its text is keyed `price-<id>`.
class PriceLine extends ConsumerWidget {
  const PriceLine({super.key, required this.id, required this.quote, this.fee = false});
  final String id;
  final Quote? quote;
  final bool fee;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = quote;
    final points = ref.watch(pointsProvider).value;
    if (q == null || points == null || !points.enabled) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: Space.xs),
      child: Text(
        fee ? l10n.pointsInquiryFee(q.points) : l10n.pointsAboutLine(q.points, points.available),
        key: ValueKey<String>('price-$id'),
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary),
      ),
    );
  }
}

/// 积分不足 (v11.0.0): when [error] is the server's 402 points_short, says what the request needs and what is
/// available, and 去充值 opens 我的积分. True when it was that error (the caller shows nothing else then).
Future<bool> showPointsShort(BuildContext context, Object error) async {
  if (error is! ApiException || !error.isPointsShort) return false;
  final l10n = AppLocalizations.of(context);
  final need = (error.problem['need'] as num?)?.toInt() ?? 0;
  final available = (error.problem['available'] as num?)?.toInt() ?? 0;
  final navigator = Navigator.of(context);
  final go = await showDialog<bool>(
    context: context,
    builder: (ctx) => compactButtons(
      ctx,
      AlertDialog(
        key: const Key('points-short'),
        icon: const Icon(Icons.toll_outlined),
        title: Text(l10n.pointsShortTitle),
        content: Text(l10n.pointsShortBody(need, available), key: const Key('points-short-body')),
        actions: [
          AppTextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          AppFilledButton(
            key: const Key('points-go-top-up'),
            autofocus: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.pointsGoTopUp),
          ),
        ],
      ),
    ),
  );
  if (go == true) await navigator.push(MaterialPageRoute<void>(builder: (_) => const PointsPage()));
  return true;
}
