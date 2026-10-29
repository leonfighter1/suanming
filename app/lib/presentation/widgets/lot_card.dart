import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../l10n/gen/app_localizations.dart';
import '../design.dart';
import '../theme.dart';

/// 求籤 (v4.3.0): the lot drawn, as a temple prints it on its slip: the set, the lot's title and label,
/// and its four lines in the reader's script (English readers see the original).
class LotCard extends ConsumerWidget {
  const LotCard({super.key, required this.lotNumber});
  final int lotNumber;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(settingsProvider).apiLocaleCode;
    final lots = ref.watch(termsProvider).value?.lots;
    final lot = lots?.lot(lotNumber);
    if (lots == null || lot == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    // 籤紙: the yellow paper temples print lots on, darker at night.
    final paper = dark ? const Color(0xFF3F3321) : const Color(0xFFF3DCA6);
    final ink = dark ? const Color(0xFFF1E4C8) : const Color(0xFF3B2A22);
    final accent = dark ? const Color(0xFFE59A86) : AppColors.accent;
    return AppCard(
      title: l10n.qiuqianYourLot,
      icon: Icons.temple_buddhist_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: Space.l, vertical: Space.xl),
            decoration: BoxDecoration(
              color: paper,
              borderRadius: BorderRadius.circular(Radii.field),
              border: Border.all(color: accent, width: 2),
            ),
            child: Column(
              children: [
                Text(lots.name(locale), style: theme.textTheme.bodySmall?.copyWith(color: ink)),
                const SizedBox(height: Space.xs),
                Text(
                  '${lot.title(locale)} · ${lot.ganzhi}',
                  key: const Key('lot-title'),
                  style: theme.textTheme.titleMedium?.copyWith(color: accent),
                ),
                const SizedBox(height: Space.l),
                for (final line in lot.poem(locale))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: Space.xs),
                    child: Text(
                      line,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(color: ink, letterSpacing: 4, height: 1.3),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: Space.s),
          Text(l10n.qiuqianTextNote, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// Two moon blocks (筊杯) as they landed: each with its flat face or its round face up.
class JiaobeiBlocks extends StatelessWidget {
  const JiaobeiBlocks({super.key, required this.blocks, this.size = 44});

  /// 'flat' or 'round' for each block.
  final List<String> blocks;
  final double size;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      label: blocks.map((b) => b == 'flat' ? l10n.blockFlat : l10n.blockRound).join(', '),
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, b) in blocks.indexed) ...[
              if (i > 0) const SizedBox(width: Space.s),
              CustomPaint(size: Size(size, size / 2), painter: JiaobeiPainter(flat: b == 'flat', dark: dark)),
            ],
          ],
        ),
      ),
    );
  }
}

/// One moon block in a box twice as wide as it is high: [flat] face up, or its round back. The 求籤 stage
/// (qiuqian_stage.dart) paints the thrown blocks with it too.
class JiaobeiPainter extends CustomPainter {
  const JiaobeiPainter({required this.flat, required this.dark});
  final bool flat;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final red = dark ? const Color(0xFFD0604F) : const Color(0xFFA8382B);
    final light = dark ? const Color(0xFFE8A190) : const Color(0xFFE0907C);
    // A half-moon: the round back above, the flat face below.
    final half = Path()
      ..moveTo(0, size.height)
      ..arcToPoint(Offset(size.width, size.height), radius: Radius.elliptical(size.width / 2, size.height))
      ..close();
    if (flat) {
      // The flat face up: its pale wood, the rim around it.
      canvas.drawPath(half, Paint()..color = light);
      canvas.drawPath(half, Paint()
        ..color = red
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2);
    } else {
      // The round back up: lacquered red with a highlight.
      canvas.drawPath(half, Paint()..color = red);
      canvas.drawArc(
        Rect.fromLTWH(size.width * 0.2, size.height * 0.25, size.width * 0.6, size.height * 1.2),
        3.6,
        1.2,
        false,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(JiaobeiPainter old) => old.flat != flat || old.dark != dark;
}
