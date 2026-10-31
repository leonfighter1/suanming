import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'application/providers.dart';
import 'data/api_client.dart';
import 'domain/content.dart';
import 'l10n/gen/app_localizations.dart';
import 'presentation/content.dart';
import 'presentation/design.dart';
import 'presentation/home_page.dart';
import 'presentation/intro_page.dart';
import 'presentation/keyboard.dart';
import 'presentation/maintenance.dart';
import 'presentation/theme.dart';
import 'presentation/widgets/app_menu.dart';

class MingliApp extends ConsumerWidget {
  const MingliApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    // 内容管理 (S29): staff's changes in front of the app's texts and images, once they come.
    final content = ref.watch(contentProvider).value ?? ContentView.none;
    final server = Uri.parse(ref.watch(apiClientProvider).baseUrl);
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      // 外观 (v12.1.0): a change fades every colour, border and state into the other theme; nothing moves. 跟随时间
      // (S27): dark from 19:00 to 06:00 by the local clock, light otherwise, turning by itself.
      themeMode: settings.byTime ? (ref.watch(nightProvider) ? ThemeMode.dark : ThemeMode.light) : settings.themeMode,
      themeAnimationStyle: const AnimationStyle(duration: Motion.theme, curve: Motion.themeCurve),
      locale: settings.locale,
      supportedLocales: supportedAppLocales,
      localizationsDelegates: [
        ContentDelegate(content.texts),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // App-wide keys around the Navigator: Esc = back one level, Ctrl+/ = list.
      builder: (_, navigator) => ContentScope(
        images: {for (final MapEntry(:key, :value) in content.images.entries) key: server.resolve(value).toString()},
        child: MenuMorph(child: KeyboardShell(child: navigator!)),
      ),
      home: const AuthGate(),
    );
  }
}

/// Signed out → the introduction page (S29), which opens sign-in; signed in → home. Everything else sits behind this.
/// 登出 (S29; the owner: 「增加登出动画，如果用户登出」): when the account goes out, 首页 sinks back and fades as the
/// introduction page comes forward ([Motion.signOut]). Every other change is at once, and so is that one under reduce
/// motion.
class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

/// How far 首页 sinks back as it leaves, and the introduction page comes forward from.
const _sinkTo = 0.94;

class _AuthGateState extends ConsumerState<AuthGate> {
  /// The last change was the account going out.
  bool _out = false;

  @override
  Widget build(BuildContext context) {
    final menu = MenuMorph.openedOf(context);
    ref.listen(authProvider, (before, now) {
      // Only a change in or out counts: going out reloads the account and answers "out" twice.
      final wasIn = before?.value != null;
      if (wasIn == (now.value != null)) return;
      _out = wasIn;
      // The menu it went out from leaves with 首页: ☰ again for the next sign-in.
      if (_out) menu?.call(false);
    });
    // 维护 (S35): an account that isn't staff waits on a page of its own; staff work as usual.
    final down = ref.watch(maintenanceProvider);
    final page = switch (ref.watch(authProvider)) {
      AsyncError(:final error) when error is ApiException && error.isMaintenance =>
        const MaintenancePage(key: ValueKey('maintenance')),
      AsyncError() => const IntroPage(key: ValueKey('signed-out')),
      // Data, or the page it had while it asks again (going out reloads it): no spinner between.
      AsyncValue(hasValue: true, :final value) => value == null
          ? const IntroPage(key: ValueKey('signed-out'))
          : down != null && value.staff == null
              ? const MaintenancePage(key: ValueKey('maintenance'))
              : const HomePage(key: ValueKey('signed-in')),
      _ => const Scaffold(key: ValueKey('loading'), body: Center(child: CircularProgressIndicator())),
    };
    final still = MediaQuery.disableAnimationsOf(context);
    // A page keeps the times it came with: 首页 comes in at once and leaves over [Motion.signOut]; the introduction page
    // comes in over it after a sign-out, and leaves at once (under the sign-in page). Reduce motion turned on or off
    // starts the switch afresh, so the page on show leaves as it now should.
    return AnimatedSwitcher(
      key: ValueKey(still),
      duration: _out && !still ? Motion.signOut : Duration.zero,
      reverseDuration: page is HomePage && !still ? Motion.signOut : Duration.zero,
      switchInCurve: Motion.curve,
      switchOutCurve: Motion.curve,
      layoutBuilder: _layout,
      transitionBuilder: _sinking,
      child: page,
    );
  }

  /// The page leaving stays under the one coming (as the switch's own layout has it), from that frame on taking no
  /// taps and flying no heroes: its SnackBar's would meet the coming page's. Both in the same wrappers, under their own
  /// keys, so the page leaving keeps its state.
  static Widget _layout(Widget? current, List<Widget> previous) => Stack(
        alignment: Alignment.center,
        children: [
          for (final p in previous) _part(p, shown: false),
          if (current != null) _part(current, shown: true),
        ],
      );

  static Widget _part(Widget child, {required bool shown}) => KeyedSubtree(
        key: child.key,
        child: HeroMode(enabled: shown, child: IgnorePointer(ignoring: !shown, child: child)),
      );

  /// Coming, from a little smaller and clear; leaving, the same way back.
  static Widget _sinking(Widget child, Animation<double> animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(scale: Tween(begin: _sinkTo, end: 1.0).animate(animation), child: child),
      );
}
