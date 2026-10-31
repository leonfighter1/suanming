import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/providers.dart';
import '../l10n/gen/app_localizations.dart';
import 'buttons.dart';
import 'content.dart';
import 'content_text.dart';
import 'design.dart';
import 'home_page.dart';
import 'layout.dart';
import 'maintenance.dart';
import 'sign_in_page.dart';
import 'widgets/app_title.dart';
import 'widgets/language_menu.dart';
import 'widgets/remedy.dart' show compactButtons;

/// 欢迎 (S29; the owner: 「create another introduction page: 欢迎来到命理大师 logo / 加入我们…… / <BUTTON - 登入、注册> -
/// 点击然后进入登录页面 / 下面就是各种服务的类型 … 2x2 grid / 点击业务，如果没有登录，那就直接进入登入页面，然后要记录刚刚点击的服务
/// 类型，登入后直接进入服务页面，注册的话就不考虑，直接进入主页」): what a visitor sees before signing in. The welcome on the
/// banners' art with the app's mark (or the logo staff put in), 登录 / 注册, then the services as 首页 groups them (东方
/// 2 × 2 on a desktop window). A service opens the sign-in page, which opens the service once signed in.
class IntroPage extends ConsumerWidget {
  const IntroPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    void signIn([String? service]) => push(context, SignInPage(service: service));
    final button = AppFilledButton.icon(
      key: const Key('intro-sign-in'),
      onPressed: signIn,
      icon: const Icon(Icons.login),
      label: Text(l10n.introSignIn),
    );
    // Each part comes in after the one before it, as on 首页.
    var order = 0;
    FadeSlideIn fadeIn(Widget child) => FadeSlideIn(index: order++, child: child);
    return Scaffold(
      // The language can be switched before signing in, as on the sign-in page.
      appBar: AppBar(title: const AppTitle(), actions: const [LanguageMenu(), SizedBox(width: Space.xs)]),
      body: ListView(
        padding: pagePadding(context),
        children: [
          fadeIn(
            HeroBanner(
              key: const Key('intro-banner'),
              title: l10n.introWelcome,
              subtitle: l10n.introJoin,
              contentKey: 'introJoin',
              trailing: const IntroLogo(),
            ),
          ),
          // 维护 (S35): when users may sign in again, while it is on.
          const MaintenanceNotice(),
          // The page's one action: across the column on a phone, its label's width beyond.
          fadeIn(
            WindowClass.ofContext(context) == WindowClass.compact
                ? button
                : Align(alignment: Alignment.centerLeft, child: compactButtons(context, button)),
          ),
          fadeIn(
            Padding(
              padding: const EdgeInsets.only(top: Space.xl, bottom: Space.xs),
              child: Semantics(header: true, child: Text(l10n.introServices, style: theme.textTheme.titleLarge)),
            ),
          ),
          fadeIn(
            Padding(
              padding: const EdgeInsets.only(bottom: Space.l),
              child: ContentText(
                l10n.introServicesHint,
                contentKey: 'introServicesHint',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ),
          for (final (key, title, members) in [
            ('east', l10n.homeEast, eastMethods),
            ('west', l10n.homeWest, westMethods),
          ]) ...[
            fadeIn(GroupTitle(key: Key('intro-group-$key'), title: title)),
            CardGrid(
              children: [
                // Before signing in the region isn't known: the default order.
                for (final s in defaultMethods.where(members.contains))
                  fadeIn(MethodEntry(s, key: Key('intro-$s'), onTap: () => signIn(s))),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The introduction page's mark: the logo staff put in (内容管理), else the app's own, drawn ([BaguaMark]); the app's
/// own too when staff's can't load. Beside the welcome's words, which say what it is.
class IntroLogo extends StatelessWidget {
  const IntroLogo({super.key});

  /// Its size beside the welcome.
  static const size = 72.0;

  @override
  Widget build(BuildContext context) {
    const own = BaguaMark(key: Key('intro-mark'), size: size);
    final staff = ContentScope.imageOf(context, 'logo');
    return ExcludeSemantics(
      child: staff == null
          ? own
          : Image(
              key: const Key('intro-logo'),
              image: staff,
              width: size,
              height: size,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => own,
            ),
    );
  }
}
