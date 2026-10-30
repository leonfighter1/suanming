import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mingli_app/l10n/gen/app_localizations.dart';
import 'package:mingli_app/presentation/design.dart';
import 'package:mingli_app/presentation/keyboard.dart';
import 'package:mingli_app/presentation/theme.dart';
import 'package:mingli_app/presentation/widgets/remedy.dart' show compactButtons;

import 'application/providers.dart';
import 'presentation/shell.dart';
import 'presentation/sign_in_page.dart';

/// 命理大师 管理后台 (tech plan S22): the app's theme and keyboard layer (Esc goes back, Ctrl+/ lists the keys), in 简体.
/// Its buttons sit in rows on wide pages, so all of them size to their label (the app's compactButtons, everywhere).
/// 外观 (v12.1.0) is the bar's choice, kept in this browser; a change fades every colour into the other theme.
class AdminApp extends ConsumerWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp(
        title: '命理大师 管理后台',
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: ref.watch(themeModeProvider),
        themeAnimationStyle: const AnimationStyle(duration: Motion.theme, curve: Motion.themeCurve),
        locale: const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
        supportedLocales: AppLocalizations.supportedLocales,
        // The app's own strings: its keyboard layer speaks them.
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, navigator) => KeyboardShell(child: compactButtons(context, navigator!)),
        home: const AdminGate(),
      );
}

/// Signed out: sign in; an admin signed in: the dashboard.
class AdminGate extends ConsumerWidget {
  const AdminGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(sessionProvider) == null ? const AdminSignInPage() : const AdminShell();
}
