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

  /// 每次 tab 切换自增：作为动画 builder 的 key，让 TweenAnimationBuilder 重新
  /// 挂载并重播；初值为 0 表示「用户还没切过」，body 保持原样不做变换，
  /// 首页 golden 走 identity 分支。
  int _transitionSeq = 0;

  /// 新页进场方向：+1 从右侧进（向左甩或点右边 tab），-1 从左侧进。
  int _slideDirection = 0;

  /// 只有完成一次可辨的横向甩动才切：velocity 阈值 250 px/s。位移阈值省略
  /// 是因为 GestureDetector.onHorizontalDragEnd 只给到 velocity，加位移需要
  /// 额外累积 DragUpdate 的 dx，收益不明显。
  static const _swipeVelocityThreshold = 250.0;

  void _setIndex(int i, {int? direction}) {
    if (i == _index) return;
    setState(() {
      final dir = direction ?? (i > _index ? 1 : -1);
      _index = i;
      _slideDirection = dir;
      _transitionSeq += 1;
    });
  }

  void _onHorizontalDragEnd(DragEndDetails d) {
    final vx = d.velocity.pixelsPerSecond.dx;
    if (vx.abs() < _swipeVelocityThreshold) return;
    final dir = vx < 0 ? 1 : -1;
    final next = (_index + dir).clamp(0, 1);
    if (next == _index) return;
    _setIndex(next, direction: dir);
  }

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

  Widget _buildBody() {
    final stack = IndexedStack(
      index: _index,
      children: [
        RecordsPage(store: widget.store),
        AnalyticsPage(store: widget.store, onAdd: _openAdd),
      ],
    );
    // 首屏或从未切换过：直接返回，不动 IndexedStack，保住既有 golden 字节一致。
    if (_transitionSeq == 0) {
      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragEnd: _onHorizontalDragEnd,
        child: stack,
      );
    }
    // 切换过一次：包一层 TweenAnimationBuilder。key 变化触发重播，从
    // ±6% 视口宽度的位移缓动到 0，形成一次短促滑入；IndexedStack 与两个子页
    // 的状态保持不变。
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      child: LayoutBuilder(
        builder: (context, constraints) => TweenAnimationBuilder<Offset>(
          key: ValueKey(_transitionSeq),
          tween: Tween(
            begin: Offset(_slideDirection.toDouble(), 0),
            end: Offset.zero,
          ),
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          builder: (context, factor, child) => Transform.translate(
            offset: factor * constraints.maxWidth * 0.06,
            child: child,
          ),
          child: stack,
        ),
      ),
    );
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
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAdd,
        icon: const Icon(Icons.add),
        label: Text(l10n.addEntry),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _setIndex,
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
