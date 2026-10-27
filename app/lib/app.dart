import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'application/providers.dart';
import 'l10n/gen/app_localizations.dart';
import 'presentation/home_page.dart';
import 'presentation/keyboard.dart';
import 'presentation/sign_in_page.dart';
import 'presentation/theme.dart';

class MingliApp extends ConsumerWidget {
  const MingliApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(settingsProvider).locale;
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      locale: locale,
      supportedLocales: supportedAppLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // App-wide keys around the Navigator: Esc = back one level, Ctrl+/ = list.
      builder: (_, navigator) => KeyboardShell(child: navigator!),
      home: const AuthGate(),
    );
  }
}

/// Signed out → sign-in; signed in → home. Everything else sits behind this.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => switch (ref.watch(authProvider)) {
        AsyncData(:final value) => value == null ? const SignInPage() : const HomePage(),
        AsyncError() => const SignInPage(),
        _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
      };
}
