import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/providers.dart';
import '../l10n/gen/app_localizations.dart';
import 'bazi_form_page.dart';
import 'daily_card.dart';
import 'design.dart';
import 'fengshui_page.dart';
import 'history_page.dart';
import 'layout.dart';
import 'liuyao_page.dart';
import 'profiles_page.dart';
import 'qiuqian_page.dart';
import 'tarot_page.dart';
import 'widgets/app_menu.dart';
import 'widgets/app_title.dart';

void push(BuildContext context, Widget page) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

/// The home page's two groups (owner, v6.1.0): 东方, 八字 · 算卦 · 风水 · 求签, and 西方, 塔罗 for now. A new
/// method joins one of them here. Inside a group the methods keep the region's order.
const _east = {'bazi', 'qiuqian', 'liuyao', 'fengshui'};
const _west = {'tarot'};

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final book = ref.watch(profilesProvider).value;
    final me = book?.defaultProfile;
    // The methods in the region's entry order (GET /v1/methods, v4.3.0): 求籤 first in Taiwan and Hong Kong, the
    // default order elsewhere and while the order loads. Each group under its name, 东方 first.
    final methods = (ref.watch(methodsProvider).value ?? defaultMethods).where(defaultMethods.contains).toList();
    // Each part comes in after the one before it (FadeSlideIn's index), the banner and the profile prompt first.
    var order = 2;
    FadeSlideIn fadeIn(Widget child) => FadeSlideIn(index: order++, child: child);
    // A group's methods in a CardGrid (S26: on a desktop window 东方's four 2 × 2, 西方's one 1 × 1), then its card
    // of the day.
    final groups = <Widget>[
      for (final (key, title, members, daily) in [
        ('east', l10n.homeEast, _east, null),
        ('west', l10n.homeWest, _west, const DailyCard()),
      ])
        if (methods.any(members.contains)) ...[
          fadeIn(_GroupTitle(key: Key('group-$key'), title: title)),
          CardGrid(children: [for (final system in methods.where(members.contains)) fadeIn(_entry(context, l10n, system))]),
          if (daily != null) fadeIn(daily),
        ],
    ];
    return Scaffold(
      // A clean bar (owner, v8.1.0; v9.1.0): the mark and the name, then a framed ☰ on the right. ☰ opens the menu
      // from that side, with 历史记录, 个人资料, 语言, 设置 and the rest. This replaces the 2026-10-27 bar, which had
      // each of them as its own button, and the v8.1.0 one, with ☰ on the left and 历史记录 beside the title.
      endDrawer: const AppMenu(),
      appBar: AppBar(
        title: const AppTitle(),
        actions: [
          Builder(builder: (context) => MenuButton(onPressed: () => Scaffold.of(context).openEndDrawer())),
          const SizedBox(width: Space.m),
        ],
      ),
      // In the app's container (S26): fluid on a phone and a tablet, at most 1620 on a wider window.
      body: ListView(
        padding: containerPadding(context),
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
          ...groups,
          fadeIn(const RecentHistory()),
        ],
      ),
    );
  }

  Widget _entry(BuildContext context, AppLocalizations l10n, String system) => switch (system) {
        'bazi' => _Entry(
            key: const Key('entry-bazi'),
            icon: Icons.grid_view_rounded,
            title: l10n.homeBazi,
            subtitle: l10n.homeBaziDesc,
            onTap: () => push(context, const BaziFormPage()),
          ),
        'tarot' => _Entry(
            key: const Key('entry-tarot'),
            icon: Icons.style_rounded,
            title: l10n.homeTarot,
            subtitle: l10n.homeTarotDesc,
            onTap: () => push(context, const TarotPage()),
          ),
        'fengshui' => _Entry(
            key: const Key('entry-fengshui'),
            icon: Icons.explore_outlined,
            title: l10n.homeFengshui,
            subtitle: l10n.homeFengshuiDesc,
            onTap: () => push(context, const FengshuiPage()),
          ),
        'qiuqian' => _Entry(
            key: const Key('entry-qiuqian'),
            icon: Icons.temple_buddhist_outlined,
            title: l10n.homeQiuqian,
            subtitle: l10n.homeQiuqianDesc,
            onTap: () => push(context, const QiuqianPage()),
          ),
        'liuyao' => _Entry(
            key: const Key('entry-liuyao'),
            icon: Icons.toll_outlined,
            title: l10n.homeLiuyao,
            subtitle: l10n.homeLiuyaoDesc,
            onTap: () => push(context, const LiuyaoPage()),
          ),
        _ => const SizedBox.shrink(),
      };
}

/// A group's name above its methods on the home page: 东方, 西方 (owner, v6.1.0). Read out as a heading.
class _GroupTitle extends StatelessWidget {
  const _GroupTitle({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // On the cards' left edge (the ui-design skill's alignment rule).
    return Padding(
      padding: const EdgeInsets.only(top: Space.s, bottom: Space.m),
      child: Semantics(
        header: true,
        child: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
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
            decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(Radii.tile)),
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
