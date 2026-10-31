import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../application/providers.dart';
import '../domain/points.dart';
import '../l10n/gen/app_localizations.dart';
import '../platform/printer.dart';
import 'buttons.dart';
import 'content_text.dart';
import 'design.dart';
import 'home_page.dart' show push;
import 'layout.dart';
import 'widgets/life_blocks.dart' show LifeKeyValues;

/// A receipt's lines, label and value, as the page shows them and the printout prints them.
List<(String, String)> receiptLines(AppLocalizations l10n, ReceiptView r) => [
      (l10n.receiptNumber, r.number),
      (l10n.receiptDate, DateFormat('yyyy-MM-dd HH:mm').format(r.createdAt.toLocal())),
      if (r.email.isNotEmpty) (l10n.receiptEmail, r.email),
      (l10n.receiptPack, l10n.receiptPackLine(r.packYuan, r.points)),
      (l10n.receiptPaid, '${r.paid}（${r.currency}）'),
      if (r.currency != 'CNY')
        (l10n.receiptRate, '${l10n.receiptRateLine('${r.rate}', r.currency)}${r.ratesDate == null ? '' : '（${r.ratesDate}）'}'),
      if (r.serviceChargePercent > 0) (l10n.receiptCharge, l10n.receiptChargeLine(_percent(r.serviceChargePercent))),
    ];

/// A percentage as written: 5, 7.5.
String _percent(double v) => v == v.roundToDouble() ? '${v.toInt()}' : '$v';

/// 收据 (S31; the owner: 「Generate a purchase receipt for user. user is able to view and print the money spent and points
/// they purchased」): every 充值's receipt, newest first; each opens its page. An admin's 增加积分 has none.
class ReceiptsPage extends ConsumerWidget {
  const ReceiptsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(receiptsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.receiptsTitle)),
      body: switch (async) {
        AsyncValue(value: final items?) => _list(context, items),
        AsyncValue(error: final e?) => Center(
            child: Padding(padding: pagePadding(context), child: Text('${l10n.errorTitle}\n$e', textAlign: TextAlign.center)),
          ),
        // 骨架屏 (S30): the page as it will be, a typical receipt under bars of its size.
        _ => Skeleton.cover(label: l10n.loading, child: _list(context, [_typical])),
      },
    );
  }

  Widget _list(BuildContext context, List<ReceiptView> items) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return ListView(
      padding: pagePadding(context),
      children: [
        ContentText(l10n.receiptsAbout, contentKey: 'receiptsAbout', style: ReadingText.small(context)),
        const SizedBox(height: Space.m),
        if (items.isEmpty)
          EmptyState(icon: Icons.receipt_long_outlined, text: l10n.receiptsEmpty, contentKey: 'receiptsEmpty')
        else
          for (final r in items)
            AppCard(
              key: ValueKey<String>('receipt-${r.id}'),
              title: r.number,
              icon: Icons.receipt_outlined,
              trailing: Text(r.paid, style: theme.textTheme.titleMedium),
              onTap: () => push(context, ReceiptPage(receipt: r)),
              child: Text(
                '${DateFormat('yyyy-MM-dd HH:mm').format(r.createdAt.toLocal())} · '
                '${l10n.receiptPackLine(r.packYuan, r.points)}',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
      ],
    );
  }
}

/// What 收据 shows while the receipts come (骨架屏).
final _typical = ReceiptView(
  id: 'typical',
  number: 'MLDS-2026-000001',
  createdAt: DateTime(2026, 10, 31, 16),
  email: '',
  packYuan: 10,
  points: 1000,
  currency: 'CNY',
  amount: 10,
  rate: 1,
  serviceChargePercent: 0,
  simulated: true,
  symbol: '¥',
  decimals: 2,
);

/// One receipt, to view and print: its lines and, while 充值 is simulated, that no payment was taken.
class ReceiptPage extends ConsumerWidget {
  const ReceiptPage({super.key, required this.receipt});
  final ReceiptView receipt;

  Future<void> _print(AppLocalizations l10n, WidgetRef ref) async {
    final lines = receiptLines(l10n, receipt);
    final html = printableHtml(
      title: '${l10n.appTitle} · ${l10n.receiptTitle(receipt.number)}',
      sections: [('', [for (final (k, v) in lines) '$k：$v'])],
      footer: receipt.simulated ? l10n.receiptSimulated : l10n.appTitle,
    );
    // The browser prints it; elsewhere the share sheet offers to.
    if (!await printHtml(html)) {
      await ref.read(shareProvider)(
        ShareParams(text: [for (final (k, v) in lines) '$k：$v'].join('\n'), subject: l10n.receiptTitle(receipt.number)),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.receiptTitle(receipt.number))),
      body: ListView(
        padding: pagePadding(context),
        children: [
          AppCard(
            key: const Key('receipt'),
            title: l10n.appTitle,
            icon: Icons.receipt_long_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LifeKeyValues(rows: receiptLines(l10n, receipt)),
                if (receipt.simulated) ...[
                  const SizedBox(height: Space.m),
                  ContentText(
                    l10n.receiptSimulated,
                    contentKey: 'receiptSimulated',
                    key: const Key('receipt-simulated'),
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: AppOutlinedButton.icon(
              key: const Key('receipt-print'),
              onPressed: () => _print(l10n, ref),
              icon: const Icon(Icons.print_outlined),
              label: Text(l10n.receiptPrint),
            ),
          ),
        ],
      ),
    );
  }
}
