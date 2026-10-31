import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../application/providers.dart';
import '../data/api_client.dart';
import '../l10n/gen/app_localizations.dart';
import 'buttons.dart';
import 'design.dart';
import 'layout.dart';
import 'tokens.dart';
import 'widgets/app_title.dart';
import 'widgets/remedy.dart' show compactButtons;

/// When users may sign in again (维护, S35), in words: the time an admin set, or the window of three to four hours; a
/// time past is "soon". A time on another day carries its date.
String maintenanceLine(AppLocalizations l10n, Maintenance m, DateTime now) {
  if (!m.endsBy.isAfter(now)) return l10n.maintenanceSoon;
  final today = now.toLocal();
  String at(DateTime t) {
    final local = t.toLocal();
    final sameDay = local.year == today.year && local.month == today.month && local.day == today.day;
    return DateFormat(sameDay ? 'HH:mm' : 'M月d日 HH:mm').format(local);
  }

  return m.endsFrom == m.endsBy
      ? l10n.maintenanceUntil(at(m.endsBy))
      : l10n.maintenanceWindow(at(m.endsFrom), at(m.endsBy));
}

/// 维护's notice (S35): what is going on and when users may sign in again, the warning's icon with the words; for
/// [staff], that they work as usual. On the introduction and sign-in pages, and on 首页 for staff; nothing while there
/// is no maintenance.
class MaintenanceNotice extends ConsumerWidget {
  const MaintenanceNotice({super.key, this.staff = false});
  final bool staff;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = ref.watch(maintenanceProvider);
    if (m == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final t = ThemeTokens.of(context);
    final text = Theme.of(context).textTheme;
    return AppCard(
      key: const Key('maintenance-notice'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: firstLineInset(text.titleMedium, Space.xl)),
            child: Icon(Icons.construction_outlined, color: t.warning, size: Space.xl),
          ),
          const SizedBox(width: Space.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.maintenanceTitle, style: text.titleMedium),
                const SizedBox(height: Space.xs),
                Text(maintenanceLine(l10n, m, ref.watch(clockProvider)()), key: const Key('maintenance-line')),
                if (staff) ...[
                  const SizedBox(height: Space.xs),
                  Text(l10n.maintenanceStaff, style: text.bodySmall?.copyWith(color: t.textSecondary)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A signed-in user who isn't staff, while 维护 is on (S35): when they may sign in again on the banner, 再看看 (it also
/// asks each minute by itself) and 退出登录. When it ends, 首页 comes back.
class MaintenancePage extends ConsumerWidget {
  const MaintenancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final m = ref.watch(maintenanceProvider);
    final check = AppFilledButton.icon(
      key: const Key('maintenance-check'),
      onPressed: () => ref.read(maintenanceProvider.notifier).check(),
      icon: const Icon(Icons.refresh),
      label: Text(l10n.maintenanceCheck),
    );
    final signOut = AppTextButton(
      key: const Key('maintenance-sign-out'),
      onPressed: () => ref.read(authProvider.notifier).signOut(),
      child: Text(l10n.signOut),
    );
    return Scaffold(
      appBar: AppBar(title: const AppTitle()),
      body: ListView(
        padding: pagePadding(context),
        children: [
          HeroBanner(
            key: const Key('maintenance-banner'),
            title: l10n.maintenanceTitle,
            subtitle: m == null ? null : maintenanceLine(l10n, m, ref.watch(clockProvider)()),
            icon: Icons.construction_outlined,
          ),
          // On a phone the main button spans the column; wider, both size to their labels in a row, the main one
          // last (the ui-design skill).
          if (WindowClass.ofContext(context) == WindowClass.compact) ...[
            check,
            const SizedBox(height: Space.s),
            signOut,
          ] else
            Align(
              alignment: Alignment.centerLeft,
              child: compactButtons(
                context,
                Row(mainAxisSize: MainAxisSize.min, children: [signOut, const SizedBox(width: Space.s), check]),
              ),
            ),
        ],
      ),
    );
  }
}
