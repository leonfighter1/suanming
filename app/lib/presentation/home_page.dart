import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/providers.dart';
import '../l10n/gen/app_localizations.dart';
import 'account_page.dart';
import 'bazi_form_page.dart';
import 'tarot_page.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            tooltip: l10n.settings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => showModalBottomSheet<void>(context: context, builder: (_) => const _SettingsSheet()),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Entry(
            key: const Key('entry-bazi'),
            icon: Icons.grid_view,
            title: l10n.homeBazi,
            subtitle: l10n.homeBaziDesc,
            page: const BaziFormPage(),
          ),
          _Entry(
            key: const Key('entry-tarot'),
            icon: Icons.style,
            title: l10n.homeTarot,
            subtitle: l10n.homeTarotDesc,
            page: const TarotPage(),
          ),
          const SizedBox(height: 16),
          Text(l10n.disclaimerShort, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _Entry extends StatelessWidget {
  const _Entry({super.key, required this.icon, required this.title, required this.subtitle, required this.page});
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget page;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: Icon(icon, size: 36),
          title: Text(title, style: Theme.of(context).textTheme.titleLarge),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page)),
        ),
      );
}

class _SettingsSheet extends ConsumerWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.language, style: Theme.of(context).textTheme.labelLarge),
          SegmentedButton<Locale>(
            segments: const [
              ButtonSegment(value: zhHant, label: Text('繁體')),
              ButtonSegment(value: zhHans, label: Text('简体')),
              ButtonSegment(value: Locale('en'), label: Text('EN')),
            ],
            selected: {settings.locale},
            onSelectionChanged: (s) => notifier.setLocale(s.first),
          ),
          const SizedBox(height: 8),
          // The region is fixed on the account at sign-up (Geo-Rule), not a setting.
          ListTile(
            key: const Key('open-account'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.person_outline),
            title: Text(l10n.account),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context)
                ..pop()
                ..push(MaterialPageRoute<void>(builder: (_) => const AccountPage()));
            },
          ),
        ],
      ),
    );
  }
}
