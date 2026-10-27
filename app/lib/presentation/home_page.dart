import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/providers.dart';
import '../l10n/gen/app_localizations.dart';
import 'bazi_form_page.dart';
import 'design.dart';
import 'history_page.dart';
import 'profiles_page.dart';
import 'settings_page.dart';
import 'tarot_page.dart';
import 'widgets/language_menu.dart';

void push(BuildContext context, Widget page) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final book = ref.watch(profilesProvider).value;
    final me = book?.defaultProfile;
    return Scaffold(
      // Everything one tap away: 历史记录, 个人资料, 语言, and the 设置 gear.
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            key: const Key('open-history'),
            tooltip: l10n.history,
            icon: const Icon(Icons.history),
            onPressed: () => push(context, const HistoryPage()),
          ),
          IconButton(
            key: const Key('open-profiles'),
            tooltip: l10n.profiles,
            icon: const Icon(Icons.people_alt_outlined),
            onPressed: () => push(context, const ProfilesPage()),
          ),
          const LanguageMenu(),
          IconButton(
            key: const Key('open-settings'),
            tooltip: l10n.settings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => push(context, const SettingsPage()),
          ),
          const SizedBox(width: Space.xs),
        ],
      ),
      body: ListView(
        padding: Space.page,
        children: [
          FadeSlideIn(
            child: HeroBanner(
              title: me == null ? l10n.appTitle : l10n.greeting(me.name),
              subtitle: l10n.disclaimerShort,
              icon: Icons.auto_awesome,
            ),
          ),
          if (book != null && me == null)
            FadeSlideIn(
              index: 1,
              child: AppCard(
                key: const Key('create-profile-prompt'),
                title: l10n.noProfileTitle,
                icon: Icons.person_add_alt_1,
                color: Theme.of(context).colorScheme.secondaryContainer,
                onTap: () => push(context, const ProfileEditPage()),
                child: Text(l10n.noProfileBody),
              ),
            ),
          FadeSlideIn(
            index: 2,
            child: _Entry(
              key: const Key('entry-bazi'),
              icon: Icons.grid_view_rounded,
              title: l10n.homeBazi,
              subtitle: l10n.homeBaziDesc,
              onTap: () => push(context, const BaziFormPage()),
            ),
          ),
          FadeSlideIn(
            index: 3,
            child: _Entry(
              key: const Key('entry-tarot'),
              icon: Icons.style_rounded,
              title: l10n.homeTarot,
              subtitle: l10n.homeTarotDesc,
              onTap: () => push(context, const TarotPage()),
            ),
          ),
          const FadeSlideIn(index: 4, child: RecentHistory()),
        ],
      ),
    );
  }
}

class _Entry extends StatelessWidget {
  const _Entry({super.key, required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(Radii.field + 2)),
            child: Icon(icon, size: 30, color: scheme.onPrimaryContainer),
          ),
          const SizedBox(width: Space.l),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: Space.xs),
                Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
        ],
      ),
    );
  }
}
