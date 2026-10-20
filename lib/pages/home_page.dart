import 'package:flutter/material.dart';

import '../auth/auth_session.dart';
import '../app_theme.dart';
import '../l10n/app_localizations.dart';
import '../state/ledger_store.dart';
import '../state/locale_controller.dart';
import '../state/theme_mode_controller.dart';
import '../utils/run_guarded.dart';
import 'add_txn_page.dart';
import 'analytics_page.dart';
import 'feedback_page.dart';
import 'profile_page.dart';
import 'records_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.store,
    required this.session,
    required this.theme,
    required this.locale,
  });

  final LedgerStore store;
  final AuthSession session;
  final ThemeModeController theme;
  final LocaleController locale;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;

  Future<void> _openAdd() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddTxnPage(store: widget.store)),
    );
  }

  void _onMenu(String value) {
    switch (value) {
      case 'profile':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ProfilePage(session: widget.session)),
        );
      case 'seed':
        runGuarded(context, widget.store.seedDemoData);
      case 'clear':
        _clearAll();
      case 'theme':
        _pickThemeMode();
      case 'locale':
        _pickLocale();
      case 'feedback':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => FeedbackPage(session: widget.session)),
        );
      case 'signout':
        widget.session.signOut();
    }
  }

  Future<void> _pickThemeMode() async {
    final l10n = AppLocalizations.of(context);
    final choices = <(ThemeMode, String, IconData)>[
      (ThemeMode.system, l10n.themeSystem, Icons.brightness_auto),
      (ThemeMode.light, l10n.themeLight, Icons.light_mode),
      (ThemeMode.dark, l10n.themeDark, Icons.dark_mode),
    ];
    final picked = await showDialog<ThemeMode>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.themeDialogTitle),
        children: [
          for (final (mode, label, icon) in choices)
            ListTile(
              dense: true,
              leading: Icon(icon),
              title: Text(label),
              trailing: widget.theme.mode == mode
                  ? const Icon(Icons.check, color: kPrimary)
                  : null,
              onTap: () => Navigator.pop(context, mode),
            ),
        ],
      ),
    );
    if (picked != null) await widget.theme.setMode(picked);
  }

  Future<void> _pickLocale() async {
    final l10n = AppLocalizations.of(context);
    final picked = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.languageDialogTitle),
        children: [
          for (final code in LocaleController.supportedCodes)
            ListTile(
              dense: true,
              leading: Icon(
                code == widget.locale.code
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: code == widget.locale.code ? kPrimary : null,
              ),
              // 语言名固定用本语言书写，切英文时菜单里仍显示「简体中文」
              title: Text(l10n.languageName(code)),
              onTap: () => Navigator.pop(context, code),
            ),
        ],
      ),
    );
    if (picked != null) await widget.locale.setCode(picked);
  }

  Future<void> _clearAll() async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.clearDialogTitle),
        content: Text(l10n.clearDialogBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.clear),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await runGuarded(context, widget.store.clearAll);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_index == 0 ? l10n.homeTitle : l10n.analyticsTitle),
        actions: [
          PopupMenuButton<String>(
            onSelected: _onMenu,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'profile',
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.person_outline),
                  title: Text(l10n.menuProfile),
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'seed',
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.auto_awesome),
                  title: Text(l10n.menuSeed),
                ),
              ),
              PopupMenuItem(
                value: 'clear',
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.delete_sweep),
                  title: Text(l10n.menuClear),
                ),
              ),
              PopupMenuItem(
                value: 'theme',
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.palette_outlined),
                  title: Text(l10n.menuTheme(l10n.themeModeName(widget.theme.mode))),
                ),
              ),
              PopupMenuItem(
                value: 'locale',
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.translate),
                  title: Text(l10n.menuLanguage(l10n.languageName(widget.locale.code))),
                ),
              ),
              PopupMenuItem(
                value: 'feedback',
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.feedback_outlined),
                  title: Text(l10n.menuFeedback),
                ),
              ),
              PopupMenuItem(
                value: 'signout',
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.logout),
                  title: Text(l10n.menuSignOut(widget.session.displayName)),
                ),
              ),
            ],
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: [
          RecordsPage(store: widget.store),
          AnalyticsPage(store: widget.store, onAdd: _openAdd),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAdd,
        icon: const Icon(Icons.add),
        label: Text(l10n.addEntry),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.receipt_long),
            label: l10n.navRecords,
          ),
          NavigationDestination(
            icon: const Icon(Icons.pie_chart),
            label: l10n.navAnalytics,
          ),
        ],
      ),
    );
  }
}
