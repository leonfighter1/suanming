import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mingli_app/presentation/buttons.dart';
import 'package:mingli_app/presentation/design.dart';
import 'package:mingli_app/presentation/keyboard.dart';
import 'package:mingli_app/presentation/layout.dart';

import '../application/providers.dart';
import 'messages.dart';

/// 管理后台登录 (tech plan S22; the roles, S25): an account without a staff role (admin, manager, integrator) is turned
/// away.
class AdminSignInPage extends ConsumerStatefulWidget {
  const AdminSignInPage({super.key});

  @override
  ConsumerState<AdminSignInPage> createState() => _AdminSignInPageState();
}

class _AdminSignInPageState extends ConsumerState<AdminSignInPage> {
  /// The login the app's ☰ → 管理后台 handed over (S25), if any: filled in, so the password comes first.
  late final _login = TextEditingController(text: ref.read(loginHintProvider) ?? '');
  late final _hinted = _login.text.isNotEmpty;
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _login.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(sessionProvider.notifier).signIn(_login.text.trim(), _password.text);
    } catch (e) {
      if (mounted) setState(() => _error = problemText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SubmitShortcut(
      onSubmit: _busy ? null : _submit,
      child: Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: pagePadding(context),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: AppCard(
                title: '命理大师 管理后台',
                icon: Icons.admin_panel_settings_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('管理员、经理和集成人员可以登录。', style: theme.textTheme.bodyMedium),
                    const SizedBox(height: Space.l),
                    TextField(
                      key: const Key('admin-login'),
                      controller: _login,
                      autofocus: !_hinted,
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => _passwordFocus.requestFocus(),
                      decoration: const InputDecoration(labelText: '用户名 / 邮箱'),
                    ),
                    const SizedBox(height: Space.m),
                    TextField(
                      key: const Key('admin-password'),
                      controller: _password,
                      focusNode: _passwordFocus,
                      autofocus: _hinted,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                      decoration: const InputDecoration(labelText: '密码'),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: Space.m),
                      Text(_error!, key: const Key('admin-error'), style: TextStyle(color: theme.colorScheme.error)),
                    ],
                    const SizedBox(height: Space.l),
                    AppFilledButton(
                      key: const Key('admin-submit'),
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('登录'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
