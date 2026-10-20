import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:ledger_front/app_theme.dart';
import 'package:ledger_front/auth/auth_session.dart';
import 'package:ledger_front/data/ledger_repository.dart';
import 'package:ledger_front/main.dart';
import 'package:ledger_front/models/txn.dart';
import 'package:ledger_front/pages/feedback_page.dart';
import 'package:ledger_front/pages/login_page.dart';
import 'package:ledger_front/pages/records_page.dart';
import 'package:ledger_front/state/ledger_store.dart';
import 'package:ledger_front/state/locale_controller.dart';
import 'package:ledger_front/state/theme_mode_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('未登录时只看到登录页', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final session = await AuthSession.restore();

    await tester.pumpWidget(LedgerApp(session: session));
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOne);
    expect(find.text('服务器地址'), findsOne);
    expect(find.text('记一笔'), findsNothing);
  });

  testWidgets('本地已有 token 时直接进入账本首页', (tester) async {
    SharedPreferences.setMockInitialValues({
      'auth.token': 'jwt',
      'auth.user': jsonEncode({'id': 1, 'username': 'ren', 'nickname': '仁'}),
    });
    final session = await AuthSession.restore();

    await tester.pumpWidget(
      LedgerApp(
        session: session,
        storeFactory: (_) => LedgerStore(SharedPreferencesRepository()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsNothing);
    expect(find.widgetWithText(AppBar, '我的账本'), findsOne);
    expect(find.text('记一笔'), findsOne);
  });

  testWidgets('登录页校验与注册态切换', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final session = await AuthSession.restore();

    await tester.pumpWidget(LedgerApp(session: session));
    await tester.pumpAndSettle();

    await tester.tap(find.text('登录'));
    await tester.pumpAndSettle();
    expect(find.text('请填写用户名和密码'), findsOne);

    await tester.tap(find.text('还没有账号？去注册'));
    await tester.pumpAndSettle();
    expect(find.text('昵称（可选）'), findsOne);
    expect(find.text('注册并登录'), findsOne);
  });

  testWidgets('从右上角菜单切换深色主题', (tester) async {
    SharedPreferences.setMockInitialValues({
      'auth.token': 'jwt',
      'auth.user': jsonEncode({'id': 1, 'username': 'ren', 'nickname': '仁'}),
    });
    final session = await AuthSession.restore();
    final theme = await ThemeModeController.restore();

    await tester.pumpWidget(
      LedgerApp(
        session: session,
        theme: theme,
        storeFactory: (_) => LedgerStore(SharedPreferencesRepository()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('切换主题（跟随系统）'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('深色'));
    await tester.pumpAndSettle();

    expect(theme.mode, ThemeMode.dark);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp).first).themeMode,
      ThemeMode.dark,
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('ui.themeMode'), 'dark');
  });

  testWidgets('从右上角菜单切换英文界面', (tester) async {
    SharedPreferences.setMockInitialValues({
      'auth.token': 'jwt',
      'auth.user': jsonEncode({'id': 1, 'username': 'ren', 'nickname': '仁'}),
    });
    final session = await AuthSession.restore();
    final locale = await LocaleController.restore();

    await tester.pumpWidget(
      LedgerApp(
        session: session,
        locale: locale,
        storeFactory: (_) => LedgerStore(SharedPreferencesRepository()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('切换语言（简体中文）'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(locale.code, 'en');
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp).first).locale,
      const Locale('en'),
    );
    expect(find.text('My Ledger'), findsOne);
    expect(find.text('Add entry'), findsOne);
    expect(find.text('记一笔'), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('ui.locale'), 'en');
  });

  testWidgets('从右上角菜单进入意见反馈', (tester) async {
    SharedPreferences.setMockInitialValues({
      'auth.token': 'jwt',
      'auth.user': jsonEncode({'id': 1, 'username': 'ren', 'nickname': '仁'}),
    });
    final session = await AuthSession.restore();

    await tester.pumpWidget(
      LedgerApp(
        session: session,
        storeFactory: (_) => LedgerStore(SharedPreferencesRepository()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('意见反馈'));
    await tester.pumpAndSettle();

    expect(find.byType(FeedbackPage), findsOne);
    expect(find.text('提交'), findsOne);
  });

  testWidgets('流水页滑到底部自动加载下一页', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repo = SharedPreferencesRepository();
    await repo.insertMany([
      for (var i = 0; i < 45; i++)
        Txn(
          type: TxnType.expense,
          categoryKey: 'food',
          amount: 10,
          day: '2026-09-01',
          createdAt: i,
        ),
    ]);
    final store = LedgerStore(repo);
    await store.load();
    expect(store.txns, hasLength(20));

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(body: RecordsPage(store: store)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('已经到底了'), findsNothing);

    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable).last);
    for (var i = 0; i < 10 && store.hasMore; i++) {
      scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
      await tester.pumpAndSettle();
    }

    expect(store.txns, hasLength(45));
    expect(store.hasMore, isFalse);

    // 最后一页加载完列表变长，再滚一次到底才能看到页脚
    scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(find.text('已经到底了'), findsOne);
  });
}
