import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'application/providers.dart';
import 'data/settings_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The language (v5.1.0) and the theme (v12.1.0) the reader last picked, read before the first frame so the app
  // opens in them.
  final settings = SecureSettingsStore();
  final locale = await startLocale(settings);
  final theme = await startTheme(settings);
  runApp(
    ProviderScope(
      overrides: [
        settingsStoreProvider.overrideWithValue(settings),
        settingsProvider.overrideWith(() => SettingsNotifier(locale, theme)),
      ],
      child: const MingliApp(),
    ),
  );
}
