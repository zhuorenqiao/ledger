import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../data/api_client.dart';
import '../auth/auth_session.dart';
import '../l10n/app_localizations.dart';
import '../utils/validators.dart';

/// 登录 / 注册页：拿到后端签发的 JWT 后才能进入账本。
class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.session});

  final AuthSession session;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _nickname = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  late final TextEditingController _server = TextEditingController(
    text: widget.session.baseUrl,
  );

  bool _registerMode = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _nickname.dispose();
    _phone.dispose();
    _email.dispose();
    _server.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final username = _username.text.trim();
    final password = _password.text;
    if (username.isEmpty || password.isEmpty) {
      setState(() => _error = l10n.credentialsRequired);
      return;
    }
    if (_registerMode) {
      final phone = _phone.text.trim();
      if (phone.isNotEmpty && !cnMobilePattern.hasMatch(phone)) {
        setState(() => _error = l10n.mobileInvalid);
        return;
      }
      final email = _email.text.trim();
      if (email.isNotEmpty && !emailPattern.hasMatch(email)) {
        setState(() => _error = l10n.emailInvalidOrBlank);
        return;
      }
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.session.setBaseUrl(_server.text);
      if (_registerMode) {
        await widget.session.register(
          username: username,
          password: password,
          nickname: _nickname.text,
          email: _email.text,
          phone: _phone.text,
        );
      } else {
        await widget.session.login(username, password);
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = l10n.errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [theme.colorScheme.primaryContainer, theme.scaffoldBackgroundColor],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.account_balance_wallet,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(l10n.appTitle, style: theme.textTheme.titleLarge),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _registerMode ? l10n.registerSubtitle : l10n.loginSubtitle,
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _server,
                          decoration: InputDecoration(labelText: l10n.serverUrlField),
                          keyboardType: TextInputType.url,
                          enabled: !_busy,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _username,
                          decoration: InputDecoration(labelText: l10n.usernameField),
                          enabled: !_busy,
                          onSubmitted: (_) => _submit(),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _password,
                          decoration: InputDecoration(labelText: l10n.passwordField),
                          obscureText: true,
                          enabled: !_busy,
                          onSubmitted: (_) => _submit(),
                        ),
                        if (_registerMode) ...[
                          const SizedBox(height: 12),
                          TextField(
                            controller: _nickname,
                            decoration: InputDecoration(labelText: l10n.nicknameOptional),
                            enabled: !_busy,
                            onSubmitted: (_) => _submit(),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _phone,
                            decoration: InputDecoration(
                              labelText: l10n.phoneOptional,
                              hintText: l10n.cnMobileHint,
                            ),
                            keyboardType: TextInputType.phone,
                            maxLength: 11,
                            enabled: !_busy,
                            onSubmitted: (_) => _submit(),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _email,
                            decoration: InputDecoration(labelText: l10n.emailOptional),
                            keyboardType: TextInputType.emailAddress,
                            enabled: !_busy,
                            onSubmitted: (_) => _submit(),
                          ),
                        ],
                        const SizedBox(height: 16),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: kExpense,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        FilledButton(
                          onPressed: _busy ? null : _submit,
                          child: _busy
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(_registerMode ? l10n.registerCta : l10n.loginCta),
                        ),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => setState(() {
                                  _registerMode = !_registerMode;
                                  _error = null;
                                }),
                          child: Text(_registerMode ? l10n.toLogin : l10n.toRegister),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
