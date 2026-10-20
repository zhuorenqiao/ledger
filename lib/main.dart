import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_theme.dart';
import 'auth/auth_session.dart';
import 'data/remote_ledger_repository.dart';
import 'l10n/app_localizations.dart';
import 'pages/home_page.dart';
import 'pages/login_page.dart';
import 'state/ledger_store.dart';
import 'state/locale_controller.dart';
import 'state/theme_mode_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    LedgerApp(
      session: await AuthSession.restore(),
      theme: await ThemeModeController.restore(),
      locale: await LocaleController.restore(),
    ),
  );
}

class LedgerApp extends StatefulWidget {
  const LedgerApp({
    super.key,
    required this.session,
    this.theme,
    this.locale,
    this.storeFactory,
  });

  final AuthSession session;

  /// 主题模式控制器；不传则跟随系统且不持久化（测试用）。
  final ThemeModeController? theme;

  /// 语言控制器；不传则固定简体中文且不持久化（测试用）。
  final LocaleController? locale;

  /// 测试可注入本地仓库；默认按登录态创建后端仓库。
  final LedgerStore Function(AuthSession session)? storeFactory;

  @override
  State<LedgerApp> createState() => _LedgerAppState();
}

class _LedgerAppState extends State<LedgerApp> {
  late final ThemeModeController _theme = widget.theme ?? ThemeModeController.defaults();
  late final LocaleController _locale = widget.locale ?? LocaleController.defaults();

  LedgerStore? _store;

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_onSessionChanged);
    _theme.addListener(_onSettingsChanged);
    _locale.addListener(_onSettingsChanged);
    if (widget.session.isSignedIn) _openStore();
  }

  @override
  void dispose() {
    widget.session.removeListener(_onSessionChanged);
    _theme.removeListener(_onSettingsChanged);
    _locale.removeListener(_onSettingsChanged);
    _store?.dispose();
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  void _onSessionChanged() {
    if (widget.session.isSignedIn) {
      if (_store == null) _openStore();
    } else {
      _store?.dispose();
      _store = null;
    }
    if (mounted) setState(() {});
  }

  void _openStore() {
    _store = (widget.storeFactory ?? _remoteStore)(widget.session)..load();
  }

  static LedgerStore _remoteStore(AuthSession session) =>
      LedgerStore(RemoteLedgerRepository(session.api));

  @override
  Widget build(BuildContext context) {
    final store = _store;
    final l10n = AppLocalizations(_locale.locale);
    return MaterialApp(
      title: l10n.appTitle,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      darkTheme: buildDarkAppTheme(),
      themeMode: _theme.mode,
      locale: _locale.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: store == null
          ? LoginPage(session: widget.session)
          : HomePage(
              store: store,
              session: widget.session,
              theme: _theme,
              locale: _locale,
            ),
    );
  }
}
