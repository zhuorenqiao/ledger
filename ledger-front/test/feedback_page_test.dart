import 'package:flutter/material.dart';
import 'package:ledger_front/app_theme.dart';
import 'package:ledger_front/auth/auth_session.dart';
import 'package:ledger_front/data/api_client.dart';
import 'package:ledger_front/data/feedback_repository.dart';
import 'package:ledger_front/pages/feedback_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 假仓库：只记账不联网。ApiClient 传进去只为满足父类构造，永远不会被调用。
class _FakeRepository extends FeedbackRepository {
  _FakeRepository()
      : super(ApiClient(baseUrl: 'http://localhost:9090', token: () => null));

  int calls = 0;
  String? lastContent;
  List<FormFile> lastImages = const [];
  ApiException? failure;

  @override
  Future<void> submit({required String content, List<FormFile> images = const []}) async {
    calls++;
    lastContent = content;
    lastImages = images;
    final error = failure;
    if (error != null) throw error;
  }
}

/// 从一个宿主页 push 反馈页，这样才测得到「提交成功后返回上一页」。
Future<void> _pumpWithHost(WidgetTester tester, FeedbackPage page) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => page),
              ),
              child: const Text('打开反馈'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('打开反馈'));
  await tester.pumpAndSettle();
}

Future<AuthSession> _session() async {
  SharedPreferences.setMockInitialValues({});
  return AuthSession.restore();
}

void main() {
  testWidgets('反馈页正文最多 1000 字', (tester) async {
    final session = await _session();
    await _pumpWithHost(
      tester,
      FeedbackPage(session: session, repository: _FakeRepository()),
    );

    await tester.enterText(find.byType(TextField), 'a' * 1200);
    await tester.pump();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text.length, FeedbackRepository.maxContentLength);
    expect(find.text('1000/1000'), findsOne);
  });

  testWidgets('空内容时提交按钮不可点', (tester) async {
    final session = await _session();
    final repository = _FakeRepository();
    await _pumpWithHost(tester, FeedbackPage(session: session, repository: repository));

    final submit = find.widgetWithText(FilledButton, '提交');
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);

    // 只有空白字符也不算填了内容
    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
    expect(repository.calls, 0);
  });

  testWidgets('提交成功后回到上一页并提示', (tester) async {
    final session = await _session();
    final repository = _FakeRepository();
    await _pumpWithHost(tester, FeedbackPage(session: session, repository: repository));
    expect(find.text('意见反馈'), findsOne);

    await tester.enterText(find.byType(TextField), '  希望报表页支持导出 CSV  ');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '提交'));
    await tester.pumpAndSettle();

    expect(repository.calls, 1);
    expect(repository.lastContent, '希望报表页支持导出 CSV');
    expect(repository.lastImages, isEmpty);
    expect(find.byType(FeedbackPage), findsNothing);
    expect(find.text('反馈已提交，谢谢你的建议'), findsOne);
  });

  testWidgets('320 逻辑宽度下正文框与提交按钮不溢出', (tester) async {
    tester.view.physicalSize = const Size(320 * 2, 800 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final session = await _session();
    await _pumpWithHost(
      tester,
      FeedbackPage(session: session, repository: _FakeRepository()),
    );

    expect(find.text('提交'), findsOne);
    expect(find.text('添加图片'), findsOne);
    expect(find.text('0/1000'), findsOne);
    // 溢出会被当成异常抛出来，这里顺便确认整页没崩
    expect(tester.takeException(), isNull);
  });

  testWidgets('提交失败时留在反馈页并显示原因', (tester) async {
    final session = await _session();
    final repository = _FakeRepository()
      ..failure = const ApiException('连不上服务器，请检查后端是否已启动');
    await _pumpWithHost(tester, FeedbackPage(session: session, repository: repository));

    await tester.enterText(find.byType(TextField), '提交不上');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '提交'));
    await tester.pumpAndSettle();

    expect(repository.calls, 1);
    expect(find.byType(FeedbackPage), findsOne);
    expect(find.text('连不上服务器，请检查后端是否已启动'), findsOne);
    expect(tester.takeException(), isNull);
  });
}
