import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../l10n/gen/app_localizations.dart';
import '../design.dart';

/// The app languages: API code, menu label, short label on the bar. 简体中文 first.
const appLanguages = [('zh-Hans', '简体中文', '简'), ('zh-Hant', '繁體中文', '繁'), ('en', 'English', 'EN')];

/// 语言, straight on a top bar (home and sign-in): the current language's short
/// label, and a one-tap menu to switch.
class LanguageMenu extends ConsumerWidget {
  const LanguageMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final current = ref.watch(settingsProvider).apiLocaleCode;
    final short = appLanguages.firstWhere((l) => l.$1 == current, orElse: () => appLanguages.first).$3;
    return PopupMenuButton<String>(
      key: const Key('language-menu'),
      tooltip: l10n.language,
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.field)),
      // A Material 3 icon button takes any width: the icon plus the short label.
      icon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.translate),
          const SizedBox(width: Space.xs),
          Text(
            short,
            key: const Key('language-current'),
            style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600),
          ),
        ],
      ),
      onSelected: (code) => ref.read(settingsProvider.notifier).setLocale(switch (code) {
        'zh-Hant' => zhHant,
        'en' => const Locale('en'),
        _ => zhHans,
      }),
      itemBuilder: (_) => [
        for (final (code, label, _) in appLanguages)
          CheckedPopupMenuItem(key: Key('language-$code'), value: code, checked: current == code, child: Text(label)),
      ],
    );
  }
}
