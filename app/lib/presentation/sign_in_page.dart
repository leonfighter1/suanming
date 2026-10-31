import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/providers.dart';
import '../data/api_client.dart';
import '../l10n/gen/app_localizations.dart';
import 'buttons.dart';
import 'design.dart';
import 'home_page.dart';
import 'keyboard.dart';
import 'layout.dart';
import 'maintenance.dart';
import 'widgets/language_menu.dart';

/// Regions offered at sign-up (geo_rule_matrix: served regions). The server
/// re-checks Geo-Rule and refuses unserved ones with 451.
const signupRegions = {
  'HK': {'zh-Hant': '香港', 'zh-Hans': '香港', 'en': 'Hong Kong'},
  'TW': {'zh-Hant': '台灣', 'zh-Hans': '台湾', 'en': 'Taiwan'},
  'SG': {'zh-Hant': '新加坡', 'zh-Hans': '新加坡', 'en': 'Singapore'},
  'MY': {'zh-Hant': '馬來西亞', 'zh-Hans': '马来西亚', 'en': 'Malaysia'},
  'US': {'zh-Hant': '美國', 'zh-Hans': '美国', 'en': 'United States'},
  'CA': {'zh-Hant': '加拿大', 'zh-Hans': '加拿大', 'en': 'Canada'},
  'AU': {'zh-Hant': '澳洲', 'zh-Hans': '澳大利亚', 'en': 'Australia'},
  'GB': {'zh-Hant': '英國', 'zh-Hans': '英国', 'en': 'United Kingdom'},
};

/// Signing in or up, opened from the introduction page (S29).
class SignInPage extends ConsumerStatefulWidget {
  const SignInPage({super.key, this.service});

  /// The service picked on the introduction page: opened once signed in; signing up goes to 首页 alone.
  final String? service;

  @override
  ConsumerState<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends ConsumerState<SignInPage> {
  // Signing in: one field for a username, an email or a bound phone (v8.2.0). Signing up: a username, the email
  // optional.
  final _login = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  String _country = 'HK';
  bool _ageConfirmed = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _login.dispose();
    _username.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  /// What went wrong, in the reader's language where the server names it.
  String _message(AppLocalizations l10n, ApiException e) => switch (e.code) {
        'captcha_required' || 'locked' => l10n.captchaRequired,
        'username_invalid' => l10n.usernameHint,
        'username_taken' => l10n.usernameTaken,
        'email_invalid' => l10n.emailInvalid,
        'email_taken' => l10n.emailTaken,
        'password_weak' => l10n.passwordWeak,
        // 管理后台 (v11.2.0): an admin suspended the account.
        'account_suspended' => l10n.accountSuspended,
        // 维护 (S35): when they may sign in again.
        'maintenance' => maintenanceLine(l10n, Maintenance.fromJson(e.problem), ref.read(clockProvider)()),
        _ when e.status == 429 => l10n.captchaRequired,
        _ when e.status == 401 && !_register => l10n.loginFailed,
        _ => e.toString(),
      };

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = ref.read(authProvider.notifier);
    try {
      if (_register) {
        final email = _email.text.trim();
        await auth.register(
          username: _username.text.trim(),
          email: email.isEmpty ? null : email,
          password: _password.text,
          country: _country,
          ageConfirmed: _ageConfirmed,
        );
      } else {
        await auth.login(_login.text.trim(), _password.text);
      }
      // In (S29): back to the gate, 首页 now, and on to the service picked before signing in.
      if (!mounted) return;
      final navigator = Navigator.of(context);
      final page = _register ? null : methodPage(widget.service ?? '');
      if (page == null) {
        navigator.popUntil((r) => r.isFirst);
      } else {
        navigator.pushAndRemoveUntil(MaterialPageRoute<void>(builder: (_) => page), (r) => r.isFirst);
      }
    } on ApiException catch (e) {
      setState(() => _error = _message(l10n, e));
    } on ApiUnreachable catch (e) {
      setState(() => _error = l10n.serverUnreachable(e.baseUrl));
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(settingsProvider).apiLocaleCode;
    final canSubmit = !_busy && (!_register || (_ageConfirmed && _username.text.trim().isNotEmpty));
    // In the app's container (S26): one column on a phone and a tablet. On a desktop window the banner at the left,
    // as tall as the form, and the form at the right, five of the twelve columns.
    final window = WindowClass.ofContext(context);
    final wide = window == WindowClass.large;
    final padding = pagePadding(context);
    final banner = HeroBanner(
      key: const Key('auth-banner'),
      title: _register ? l10n.createAccount : l10n.signIn,
      subtitle: l10n.disclaimerShort,
      icon: sunOrMoon(ref.watch(nightProvider)),
      margin: wide ? EdgeInsets.zero : null,
    );
    final form = _form(l10n, locale, canSubmit);
    // Enter in a field moves on, Enter in 密码 submits; Ctrl+Enter submits from anywhere.
    return SubmitShortcut(
      onSubmit: canSubmit ? _submit : null,
      child: Scaffold(
        // The language can be switched before signing in, too.
        appBar: AppBar(title: Text(l10n.appTitle), actions: const [LanguageMenu(), SizedBox(width: Space.xs)]),
        body: ListView(
          padding: padding,
          children: wide
              ? [
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: banner),
                        SizedBox(width: window.gutter),
                        SizedBox(
                          key: const Key('auth-form'),
                          width: Grid.span(
                            MediaQuery.sizeOf(context).width - padding.horizontal,
                            5,
                            columns: window.columns,
                            gutter: window.gutter,
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: form),
                        ),
                      ],
                    ),
                  ),
                ]
              : [banner, ...form],
        ),
      ),
    );
  }

  /// The fields and buttons: signing in, or signing up.
  List<Widget> _form(AppLocalizations l10n, String locale, bool canSubmit) => [
        // 维护 (S35): when users may sign in again, while it is on (staff sign in as usual).
        const MaintenanceNotice(),
        if (_register) ...[
          TextField(
            key: const Key('username'),
            controller: _username,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newUsername],
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: l10n.username,
              prefixIcon: const Icon(Icons.person_outline),
              helperText: l10n.usernameHint,
              helperMaxLines: 2,
            ),
          ),
          const SizedBox(height: Space.m),
          TextField(
            key: const Key('email'),
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            decoration: InputDecoration(labelText: l10n.emailOptional, prefixIcon: const Icon(Icons.mail_outline)),
          ),
        ] else
          TextField(
            key: const Key('login'),
            controller: _login,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.username, AutofillHints.email, AutofillHints.telephoneNumber],
            decoration: InputDecoration(
              labelText: l10n.loginField,
              prefixIcon: const Icon(Icons.person_outline),
              helperText: l10n.loginFieldHint,
            ),
          ),
        const SizedBox(height: Space.m),
        TextField(
          key: const Key('password'),
          controller: _password,
          obscureText: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => canSubmit ? _submit() : null,
          autofillHints: [_register ? AutofillHints.newPassword : AutofillHints.password],
          decoration: InputDecoration(
            labelText: l10n.password,
            prefixIcon: const Icon(Icons.lock_outline),
            helperText: _register ? l10n.passwordHint : null,
          ),
        ),
        if (_register) ...[
          const SizedBox(height: Space.m),
          DropdownButtonFormField<String>(
            key: const Key('country'),
            initialValue: _country,
            decoration: InputDecoration(labelText: l10n.regionAccount, helperText: l10n.regionAccountHint),
            items: [
              for (final e in signupRegions.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value[locale] ?? e.key)),
            ],
            onChanged: (v) => setState(() => _country = v ?? _country),
          ),
          CheckboxListTile(
            key: const Key('age-confirm'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _ageConfirmed,
            title: Text(l10n.ageConfirm),
            onChanged: (v) => setState(() => _ageConfirmed = v ?? false),
          ),
        ],
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: Space.s),
            child: Text(_error!, key: const Key('auth-error'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        const SizedBox(height: Space.l),
        AppFilledButton(
          key: const Key('auth-submit'),
          onPressed: canSubmit ? _submit : null,
          child: Text(_register ? l10n.createAccount : l10n.signIn),
        ),
        AppTextButton(
          key: const Key('auth-toggle'),
          onPressed: () => setState(() {
            _register = !_register;
            _error = null;
          }),
          child: Text(_register ? l10n.haveAccount : l10n.noAccount),
        ),
        const Divider(height: Space.xxl),
        // Needs the sign_in_with_apple / google_sign_in SDKs and console setup (client ids).
        AppOutlinedButton.icon(onPressed: null, icon: const Icon(Icons.apple), label: Text('${l10n.appleSignIn} · ${l10n.comingSoon}')),
        const SizedBox(height: Space.s),
        AppOutlinedButton.icon(onPressed: null, icon: const Icon(Icons.g_mobiledata), label: Text('${l10n.googleSignIn} · ${l10n.comingSoon}')),
      ];
}
