import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../data/api_client.dart';
import '../../l10n/gen/app_localizations.dart';
import '../buttons.dart';
import '../design.dart';
import '../keyboard.dart';
import 'remedy.dart' show compactButtons;

/// What an account call's problem means, in the reader's language (v8.2.0); the server's words otherwise.
String accountProblem(AppLocalizations l10n, Object e) {
  if (e is ApiUnreachable) return l10n.serverUnreachable(e.baseUrl);
  if (e is! ApiException) return '$e';
  return switch (e.code) {
    'wrong_code' => l10n.codeWrong,
    'expired' => l10n.codeExpired,
    'no_code' => l10n.codeVoid,
    'wait' || 'too_many' => l10n.codeWait,
    'phone_taken' => l10n.phoneTaken,
    'email_taken' => l10n.emailTaken,
    'username_taken' => l10n.usernameTaken,
    'already_bound' => l10n.alreadyBound,
    'last_login' => l10n.lastLogin,
    'delivery_unavailable' => l10n.deliveryOff,
    'invalid' when e.title.contains('username') => l10n.usernameHint,
    'invalid' when e.title.contains('mobile') => l10n.phoneInvalid,
    'invalid' when e.title.contains('email') => l10n.emailInvalid,
    _ => e.toString(),
  };
}

/// 绑定手机号 or 验证邮箱 (v8.2.0, tech plan WP15.3): the number or the address, 发送验证码, then the code that came
/// back. The code is what proves the number or the address the user's own (the owner: 手机号需要绑定用户本人).
/// Returns the account after the code, or null when cancelled.
Future<AppUser?> showContactDialog(BuildContext context, {required String kind, String? current}) =>
    showDialog<AppUser>(context: context, builder: (_) => ContactDialog(kind: kind, current: current));

class ContactDialog extends ConsumerStatefulWidget {
  const ContactDialog({super.key, required this.kind, this.current});

  /// 'email' or 'phone'.
  final String kind;

  /// The account's email to verify, prefilled; a new one may be typed over it.
  final String? current;

  @override
  ConsumerState<ContactDialog> createState() => _ContactDialogState();
}

class _ContactDialogState extends ConsumerState<ContactDialog> {
  late final _value = TextEditingController(text: widget.current ?? '');
  final _code = TextEditingController();
  final _codeFocus = FocusNode();
  CodeSent? _sent;
  String? _sentValue;
  bool _busy = false;
  String? _error;

  bool get _phone => widget.kind == 'phone';

  @override
  void dispose() {
    _value.dispose();
    _code.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function(ApiClient api) work) async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await work(ref.read(apiClientProvider));
    } catch (e) {
      if (mounted) setState(() => _error = accountProblem(l10n, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() => _run((api) async {
        final value = _value.text.trim();
        final sent = await api.startContact(widget.kind, value);
        if (!mounted) return;
        setState(() {
          _sent = sent;
          _sentValue = value;
          _code.clear();
        });
        _codeFocus.requestFocus();
      });

  Future<void> _confirm() => _run((api) async {
        final user = await api.confirmContact(widget.kind, _sentValue!, _code.text.trim());
        if (mounted) Navigator.pop(context, user);
      });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final sent = _sent;
    final canConfirm = !_busy && sent != null && _code.text.trim().length == 6;
    return SubmitShortcut(
      onSubmit: sent == null ? (_busy ? null : _send) : (canConfirm ? _confirm : null),
      child: AlertDialog(
        title: Text(_phone ? l10n.bindPhoneTitle : l10n.verifyEmailTitle),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const Key('contact-value'),
                controller: _value,
                autofocus: true,
                enabled: !_busy,
                keyboardType: _phone ? TextInputType.phone : TextInputType.emailAddress,
                autofillHints: [_phone ? AutofillHints.telephoneNumber : AutofillHints.email],
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _busy ? null : _send(),
                decoration: InputDecoration(
                  labelText: _phone ? l10n.phone : l10n.email,
                  helperText: _phone ? l10n.phoneHint : null,
                  helperMaxLines: 3,
                ),
              ),
              if (sent != null) ...[
                const SizedBox(height: Space.m),
                Text(l10n.codeSentTo(sent.sentTo), key: const Key('code-sent')),
                // Nothing really left the server yet: the owner picks the providers next (tech plan S15).
                if (sent.outbox) ...[
                  const SizedBox(height: Space.xs),
                  Text(
                    l10n.outboxNotice,
                    key: const Key('outbox-notice'),
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
                const SizedBox(height: Space.s),
                TextField(
                  key: const Key('contact-code'),
                  controller: _code,
                  focusNode: _codeFocus,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => canConfirm ? _confirm() : null,
                  decoration: InputDecoration(labelText: l10n.codeField),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: Space.s),
                Text(_error!, key: const Key('contact-error'), style: TextStyle(color: theme.colorScheme.error)),
              ],
            ],
          ),
        ),
        actions: [
          compactButtons(
            context,
            Wrap(
              alignment: WrapAlignment.end,
              spacing: Space.s,
              runSpacing: Space.s,
              children: [
                AppTextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
                if (sent == null)
                  AppFilledButton(key: const Key('contact-send'), onPressed: _busy ? null : _send, child: Text(l10n.sendCode))
                else ...[
                  AppTextButton(key: const Key('contact-resend'), onPressed: _busy ? null : _send, child: Text(l10n.resendCode)),
                  AppFilledButton(
                    key: const Key('contact-confirm'),
                    onPressed: canConfirm ? _confirm : null,
                    child: Text(_phone ? l10n.confirmBind : l10n.confirmVerify),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 用户名 (v8.2.0): set or change it. Returns the account after saving, or null when cancelled.
Future<AppUser?> showUsernameDialog(BuildContext context, {String? current}) =>
    showDialog<AppUser>(context: context, builder: (_) => _UsernameDialog(current: current));

class _UsernameDialog extends ConsumerStatefulWidget {
  const _UsernameDialog({this.current});
  final String? current;

  @override
  ConsumerState<_UsernameDialog> createState() => _UsernameDialogState();
}

class _UsernameDialogState extends ConsumerState<_UsernameDialog> {
  late final _name = TextEditingController(text: widget.current ?? '');
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = await ref.read(apiClientProvider).setUsername(_name.text.trim());
      if (mounted) Navigator.pop(context, user);
    } catch (e) {
      if (mounted) setState(() => _error = accountProblem(l10n, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final canSave = !_busy && _name.text.trim().isNotEmpty;
    return SubmitShortcut(
      onSubmit: canSave ? _save : null,
      child: AlertDialog(
        title: Text(l10n.usernameTitle),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const Key('username-field'),
                controller: _name,
                autofocus: true,
                enabled: !_busy,
                textInputAction: TextInputAction.done,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => canSave ? _save() : null,
                decoration: InputDecoration(labelText: l10n.username, helperText: l10n.usernameHint, helperMaxLines: 2),
              ),
              if (_error != null) ...[
                const SizedBox(height: Space.s),
                Text(_error!, key: const Key('username-error'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ],
          ),
        ),
        actions: [
          compactButtons(
            context,
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
                const SizedBox(width: Space.s),
                AppFilledButton(key: const Key('username-save'), onPressed: canSave ? _save : null, child: Text(l10n.save)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
