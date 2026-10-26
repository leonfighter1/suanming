import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/providers.dart';
import '../l10n/gen/app_localizations.dart';
import 'sign_in_page.dart';

class AccountPage extends ConsumerWidget {
  const AccountPage({super.key});

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteAccountTitle),
        content: Text(l10n.deleteAccountBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(
            key: const Key('confirm-delete'),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.confirmDelete),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref.read(authProvider.notifier).deleteAccount();
      navigator.popUntil((r) => r.isFirst);
      messenger.showSnackBar(SnackBar(content: Text(l10n.accountDeleted)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(authProvider).value;
    final locale = ref.watch(settingsProvider).apiLocaleCode;
    if (user == null) return const SizedBox.shrink();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.account)),
      body: ListView(
        children: [
          ListTile(title: Text(l10n.email), subtitle: Text(user.email ?? '—')),
          ListTile(
            title: Text(l10n.regionAccount),
            subtitle: Text(signupRegions[user.country]?[locale] ?? user.country),
          ),
          ListTile(title: Text(l10n.signInMethods), subtitle: Text(user.signInMethods.join(', '))),
          const Divider(),
          ListTile(
            key: const Key('sign-out'),
            leading: const Icon(Icons.logout),
            title: Text(l10n.signOut),
            onTap: () async {
              final navigator = Navigator.of(context);
              await ref.read(authProvider.notifier).signOut();
              navigator.popUntil((r) => r.isFirst);
            },
          ),
          ListTile(
            key: const Key('delete-account'),
            leading: Icon(Icons.delete_forever, color: Theme.of(context).colorScheme.error),
            title: Text(l10n.deleteAccount, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            onTap: () => _confirmDelete(context, ref),
          ),
        ],
      ),
    );
  }
}
