import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/providers.dart';
import '../l10n/gen/app_localizations.dart';
import 'bazi_form_page.dart';
import 'content_text.dart';
import 'daily_card.dart';
import 'daily_east.dart';
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
const eastMethods = {'bazi', 'qiuqian', 'liuyao', 'fengshui'};
const westMethods = {'tarot'};

/// The page a method opens on: its card's, and the service picked before signing in (S29); null for none.
Widget? methodPage(String system) => switch (system) {
      'bazi' => const BaziFormPage(),
      'tarot' => const TarotPage(),
      'fengshui' => const FengshuiPage(),
      'qiuqian' => const QiuqianPage(),
      'liuyao' => const LiuyaoPage(),
      _ => null,
    };

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
    // of the day: 今日一卦 or 今日一签 under 东方 (S26), 今日一牌 under 西方.
    final groups = <Widget>[
      for (final (key, title, members, daily) in [
        ('east', l10n.homeEast, eastMethods, const EastDailyCard()),
        ('west', l10n.homeWest, westMethods, const DailyCard()),
      ])
        if (methods.any(members.contains)) ...[
          fadeIn(GroupTitle(key: Key('group-$key'), title: title)),
          CardGrid(children: [for (final system in methods.where(members.contains)) fadeIn(MethodEntry(system))]),
          fadeIn(daily),
        ],
    ];
    return Scaffold(
      // A clean bar (owner, v8.1.0; v9.1.0): the mark and the name, then a framed ☰ on the right. ☰ opens the menu
      // from that side, with 历史记录, 个人资料, 语言, 设置 and the rest. This replaces the 2026-10-27 bar, which had
      // each of them as its own button, and the v8.1.0 one, with ☰ on the left and 历史记录 beside the title.
      endDrawer: const AppMenu(),
      // ☰ turns into ✕ as the menu slides in, and back as it goes (S30).
      onEndDrawerChanged: MenuMorph.openedOf(context),
      appBar: AppBar(
        title: const AppTitle(),
        actions: [
          Builder(builder: (context) => MenuButton(onPressed: () => Scaffold.of(context).openEndDrawer())),
          const SizedBox(width: Space.m),
        ],
      ),
      // In the app's container (S26): fluid on a phone and a tablet, at most 1620 on a wider window.
      body: ListView(
        padding: pagePadding(context),
        children: [
          FadeSlideIn(
            child: HeroBanner(
              title: me == null ? l10n.appTitle : l10n.greeting(me.name),
              subtitle: l10n.disclaimerShort,
              // The time of day (S27): the sun, or the moon.
              icon: sunOrMoon(ref.watch(nightProvider)),
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
}

/// A group's name above its methods on the home page: 东方, 西方 (owner, v6.1.0). Read out as a heading.
class GroupTitle extends StatelessWidget {
  const GroupTitle({super.key, required this.title});
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

/// A method's card on 首页 (keyed `entry-<method>`): its icon, name and line, opening its page; [onTap] does something
/// else instead (the introduction page's: signing in first, S29).
class MethodEntry extends StatelessWidget {
  MethodEntry(this.system, {Key? key, this.onTap}) : super(key: key ?? Key('entry-$system'));
  final String system;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final page = methodPage(system);
    // Each line may hold staff's HTML (S33): its key written out.
    final (icon, title, subtitle) = switch (system) {
      'bazi' => (Icons.grid_view_rounded, l10n.homeBazi, ContentText(l10n.homeBaziDesc, contentKey: 'homeBaziDesc')),
      'tarot' => (Icons.style_rounded, l10n.homeTarot, ContentText(l10n.homeTarotDesc, contentKey: 'homeTarotDesc')),
      'fengshui' => (
          Icons.explore_outlined,
          l10n.homeFengshui,
          ContentText(l10n.homeFengshuiDesc, contentKey: 'homeFengshuiDesc'),
        ),
      'qiuqian' => (
          Icons.temple_buddhist_outlined,
          l10n.homeQiuqian,
          ContentText(l10n.homeQiuqianDesc, contentKey: 'homeQiuqianDesc'),
        ),
      _ => (Icons.toll_outlined, l10n.homeLiuyao, ContentText(l10n.homeLiuyaoDesc, contentKey: 'homeLiuyaoDesc')),
    };
    if (page == null) return const SizedBox.shrink();
    return _Entry(icon: icon, title: title, subtitle: subtitle, onTap: onTap ?? () => push(context, page));
  }
}

class _Entry extends StatelessWidget {
  const _Entry({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;

  /// Its line, in the card's line style.
  final Widget subtitle;
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
                DefaultTextStyle.merge(
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                  child: subtitle,
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
        ],
      ),
    );
  }
}
