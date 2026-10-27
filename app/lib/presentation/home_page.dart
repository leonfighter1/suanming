import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/providers.dart';
import '../l10n/gen/app_localizations.dart';
import 'account_page.dart';
import 'bazi_form_page.dart';
import 'design.dart';
import 'history_page.dart';
import 'profiles_page.dart';
import 'review_page.dart';
import 'tarot_page.dart';

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
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            key: const Key('open-history'),
            tooltip: l10n.history,
            icon: const Icon(Icons.history),
            onPressed: () => push(context, const HistoryPage()),
          ),
          const _MoreMenu(),
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
              key: const Key('entry-life'),
              icon: Icons.auto_stories,
              title: l10n.lifeEntry,
              subtitle: l10n.lifeEntryDesc,
              onTap: () => push(context, const BaziFormPage(lifeReport: true)),
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

/// The 「更多」 drop-down menu: profiles, history, account, language.
class _MoreMenu extends ConsumerWidget {
  const _MoreMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsProvider);
    return PopupMenuButton<String>(
      key: const Key('more-menu'),
      tooltip: l10n.more,
      icon: const Icon(Icons.more_vert),
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.field)),
      onSelected: (v) => switch (v) {
        'profiles' => push(context, const ProfilesPage()),
        'history' => push(context, const HistoryPage()),
        'account' => push(context, const AccountPage()),
        'review' => push(context, const ReviewPage()),
        'zh-Hant' => ref.read(settingsProvider.notifier).setLocale(zhHant),
        'zh-Hans' => ref.read(settingsProvider.notifier).setLocale(zhHans),
        'en' => ref.read(settingsProvider.notifier).setLocale(const Locale('en')),
        _ => null,
      },
      itemBuilder: (_) => [
        _item('profiles', Icons.people_alt_outlined, l10n.profiles, key: const Key('menu-profiles')),
        _item('history', Icons.history, l10n.history),
        _item('account', Icons.person_outline, l10n.account, key: const Key('open-account')),
        // 内容审核: reviewers only (the server decides who is one).
        if (ref.read(authProvider).value?.isReviewer ?? false)
          _item('review', Icons.fact_check_outlined, l10n.reviewTitle, key: const Key('open-review')),
        const PopupMenuDivider(),
        for (final (code, label) in [('zh-Hans', '简体中文'), ('zh-Hant', '繁體中文'), ('en', 'English')])
          CheckedPopupMenuItem(value: code, checked: settings.apiLocaleCode == code, child: Text(label)),
      ],
    );
  }

  PopupMenuItem<String> _item(String v, IconData icon, String label, {Key? key}) => PopupMenuItem(
        key: key,
        value: v,
        child: Row(children: [Icon(icon, size: 20), const SizedBox(width: Space.m), Text(label)]),
      );
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
