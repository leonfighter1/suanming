import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/providers.dart';
import '../data/api_client.dart';
import '../l10n/gen/app_localizations.dart';
import 'design.dart';
import 'layout.dart';
import 'sign_in_page.dart';
import 'widgets/contact_dialog.dart';
import 'widgets/remedy.dart' show compactButtons;

/// A group's heading in 设置 (账号与登录, 报告), read out as a heading.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup(this.title, {super.key});
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.l, Space.m, Space.l, Space.xs),
      child: Semantics(
        header: true,
        child: Text(title, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
      ),
    );
  }
}

/// 设置, in the ☰ menu (v8.1.0): the account and how it signs in, then sign-out and deletion, in groups.
/// 个人资料, 语言, 内容审核 and 键盘快捷键 are in the menu itself.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  static String _methodLabel(AppLocalizations l10n, String method) => switch (method) {
        'password' => l10n.password,
        'apple' => l10n.appleSignIn,
        'google' => l10n.googleSignIn,
        _ => method,
      };

  /// After a dialog that changed the account: keep the new account, and say what changed.
  static Future<void> _changed(BuildContext context, WidgetRef ref, Future<AppUser?> dialog, String done) async {
    final messenger = ScaffoldMessenger.of(context);
    final auth = ref.read(authProvider.notifier);
    final user = await dialog;
    if (user == null) return;
    auth.changed(user);
    messenger.showSnackBar(SnackBar(content: Text(done)));
  }

  /// 删除邮箱 or 解绑 the phone, after asking.
  static Future<void> _remove(BuildContext context, WidgetRef ref, String kind, String action, String done) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$action？'),
        actions: [
          compactButtons(
            ctx,
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
                const SizedBox(width: Space.s),
                FilledButton(key: const Key('confirm-remove'), onPressed: () => Navigator.pop(ctx, true), child: Text(action)),
              ],
            ),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final auth = ref.read(authProvider.notifier);
    try {
      auth.changed(await ref.read(apiClientProvider).removeContact(kind));
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(accountProblem(l10n, e))));
    }
  }

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
    final theme = Theme.of(context);
    final user = ref.watch(authProvider).value;
    final locale = ref.watch(settingsProvider).apiLocaleCode;
    if (user == null) return const SizedBox.shrink();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      // In the app's container (S27); its tiles carry their own inset.
      body: ListView(
        padding: pagePadding(context, top: 0, margin: false),
        children: [
          SettingsGroup(l10n.settingsAccountGroup, key: const Key('settings-account')),
          // The three logins (v8.2.0, WP15.3): each changed in its own dialog; an email or a phone counts once a code
          // sent to it comes back.
          ListTile(
            key: const Key('settings-username'),
            title: Text(l10n.username),
            subtitle: Text(user.username ?? l10n.notSet),
            trailing: const Icon(Icons.edit_outlined),
            onTap: () => _changed(context, ref, showUsernameDialog(context, current: user.username), l10n.usernameSaved),
          ),
          ListTile(
            key: const Key('settings-email'),
            title: Text(l10n.email),
            subtitle: Text(
              user.email == null
                  ? l10n.notSet
                  : '${user.email} · ${user.emailVerified ? l10n.emailVerifiedLabel : l10n.emailUnverifiedLabel}',
            ),
            trailing: user.email == null
                ? const Icon(Icons.add)
                : IconButton(
                    key: const Key('remove-email'),
                    tooltip: l10n.removeEmail,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _remove(context, ref, 'email', l10n.removeEmail, l10n.emailRemovedDone),
                  ),
            onTap: () => _changed(
              context,
              ref,
              showContactDialog(context, kind: 'email', current: user.email),
              l10n.emailVerifiedDone,
            ),
          ),
          ListTile(
            key: const Key('settings-phone'),
            title: Text(l10n.phone),
            subtitle: Text(user.phone ?? l10n.phoneUnbound),
            trailing: user.phone == null
                ? const Icon(Icons.chevron_right)
                : IconButton(
                    key: const Key('unbind-phone'),
                    tooltip: l10n.unbindPhone,
                    icon: const Icon(Icons.link_off),
                    onPressed: () => _remove(context, ref, 'phone', l10n.unbindPhone, l10n.phoneUnboundDone),
                  ),
            onTap: () => _changed(context, ref, showContactDialog(context, kind: 'phone'), l10n.phoneBoundDone),
          ),
          ListTile(
            title: Text(l10n.regionAccount),
            subtitle: Text(signupRegions[user.country]?[locale] ?? user.country),
          ),
          ListTile(
            title: Text(l10n.signInMethods),
            subtitle: Text('${user.signInMethods.map((m) => _methodLabel(l10n, m)).join('、')}\n${l10n.loginsNote}'),
            isThreeLine: true,
          ),
          // 报告 (v9.0.0, WP15.4): 测算完成后发到邮箱, 否 by default (the owner).
          SettingsGroup(l10n.settingsReportsGroup, key: const Key('settings-reports')),
          const _EmailReportsTile(),
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
            leading: Icon(Icons.delete_forever, color: theme.colorScheme.error),
            title: Text(l10n.deleteAccount, style: TextStyle(color: theme.colorScheme.error)),
            onTap: () => _confirmDelete(context, ref),
          ),
        ],
      ),
    );
  }
}

/// 测算完成后发到邮箱 (v9.0.0, tech plan WP15.4; the owner: 默认为否，改为是后自动发送): on only with a verified email.
/// Under it, when the server has no mail provider yet, what happens to the mail.
class _EmailReportsTile extends ConsumerStatefulWidget {
  const _EmailReportsTile();

  @override
  ConsumerState<_EmailReportsTile> createState() => _EmailReportsTileState();
}

class _EmailReportsTileState extends ConsumerState<_EmailReportsTile> {
  bool _busy = false;

  Future<void> _set(bool on) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final auth = ref.read(authProvider.notifier);
    setState(() => _busy = true);
    try {
      await ref.read(apiClientProvider).setEmailReports(on);
      await auth.reload();
    } catch (e) {
      final text = e is ApiException && e.code == 'email_unverified' ? l10n.emailReportsNeedsEmail : accountProblem(l10n, e);
      messenger.showSnackBar(SnackBar(content: Text(text)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final user = ref.watch(authProvider).value;
    if (user == null) return const SizedBox.shrink();
    final delivery = ref.watch(accountSettingsProvider).value?.mailDelivery;
    final email = user.email;
    final ready = email != null && user.emailVerified;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          key: const Key('email-reports'),
          value: user.emailReports,
          onChanged: ready && !_busy ? _set : null,
          title: Text(l10n.emailReports),
          subtitle: Text(
            !ready
                ? l10n.emailReportsNeedsEmail
                : user.emailReports
                    ? l10n.emailReportsOn(email)
                    : l10n.emailReportsOff(email),
          ),
        ),
        if (delivery == 'outbox' || delivery == 'off')
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.l, 0, Space.l, Space.s),
            child: Text(
              delivery == 'outbox' ? l10n.mailOutboxNotice : l10n.mailOffNotice,
              key: const Key('mail-delivery-notice'),
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}
