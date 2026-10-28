import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'application/providers.dart';
import 'data/settings_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The language the reader last picked, read before the first frame so the app opens in it (v5.1.0).
  final settings = SecureSettingsStore();
  final locale = await startLocale(settings);
  runApp(
    ProviderScope(
      overrides: [
        settingsStoreProvider.overrideWithValue(settings),
        settingsProvider.overrideWith(() => SettingsNotifier(locale)),
      ],
      child: const MingliApp(),
    ),
  );
}
