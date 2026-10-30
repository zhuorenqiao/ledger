import 'dart:io';

import 'package:ledger_front/data/api_client.dart';
import 'package:ledger_front/data/demo_data.dart';
import 'package:ledger_front/data/remote_ledger_repository.dart';
import 'package:ledger_front/models/txn.dart';
import 'package:flutter_test/flutter_test.dart';

/// 真实联调用例：需要 MySQL + Spring Boot 已启动。
/// 运行：`RUN_BACKEND_TESTS=1 flutter test test/backend_integration_test.dart`
void main() {
  final baseUrl = Platform.environment['BACKEND_URL'] ?? 'http://localhost:9090';
  final enabled = Platform.environment['RUN_BACKEND_TESTS'] == '1';

  test('注册→写入→分页读取→后端统计→删除→清空', () async {
    final username = 'itest_${DateTime.now().millisecondsSinceEpoch}';
    String? token;
    final api = ApiClient(baseUrl: baseUrl, token: () => token);
    final repo = RemoteLedgerRepository(api);

    final registered = await api.post('/api/auth/register', {
      'username': username,
      'password': 'secret123',
      'nickname': '集成测试',
    }) as Map;
    token = registered['token'] as String;
    expect(token, isNotEmpty);

    final me = await api.get('/api/auth/me') as Map;
    expect(me['username'], username);

    final day = dayKey(DateTime.now());
    final month = DateTime.now();
    await repo.insertMany([
      Txn(
        type: TxnType.expense,
        categoryKey: 'food',
        amount: 30,
        day: day,
        createdAt: 1,
        note: '午饭',
      ),
      Txn(type: TxnType.expense, categoryKey: 'transport', amount: 30, day: day, createdAt: 2),
      Txn(type: TxnType.income, categoryKey: 'salary', amount: 1000, day: day, createdAt: 3),
    ]);

    final saved = await repo.loadAll();
    expect(saved, hasLength(3));
    expect(saved.every((t) => t.id != null), isTrue);
    expect(saved.first.categoryKey, isNotEmpty);

    final summary = await repo.summary(fromDay: day, toDay: day);
    expect(summary.expense, 60);
    expect(summary.income, 1000);
    expect(summary.count, 3);
    expect(summary.expenseByCategory.map((s) => s.category.key), containsAll(['food', 'transport']));

    final trend = await repo.dailyTrend(month.year, month.month);
    expect(trend, hasLength(DateTime(month.year, month.month + 1, 0).day));
    expect(trend.firstWhere((p) => p.label == day.substring(8)).expense, 60);

    final years = await repo.years();
    expect(years, contains(month.year));

    final one = saved.firstWhere((t) => t.categoryKey == 'transport');
    await repo.delete(one.id!);
    expect(await repo.loadAll(), hasLength(2));

    await repo.deleteAll();
    expect(await repo.loadAll(), isEmpty);

    // 「载入示例数据」走的就是批量接口，金额精度不合规会被整批拒绝
    final demo = demoTxns();
    await repo.insertMany(demo);
    final allTime = await repo.summary();
    expect(allTime.count, demo.length);
    expect(allTime.income, greaterThan(0));

    // 流水页懒加载：一页 20 条，翻页不重不漏；当日流水按天查
    final firstPage = await repo.loadPage(0, 20);
    final secondPage = await repo.loadPage(1, 20);
    expect(firstPage.txns, hasLength(20));
    expect(firstPage.hasMore, isTrue);
    expect(
      secondPage.txns.map((t) => t.id).toSet().intersection(
        firstPage.txns.map((t) => t.id).toSet(),
      ),
      isEmpty,
    );
    final someDay = demo.first.day;
    final dayTxns = await repo.loadDay(someDay);
    expect(dayTxns, isNotEmpty);
    expect(dayTxns.every((t) => t.day == someDay), isTrue);

    await repo.deleteAll();

    // 未带 token 必须被后端拒绝
    token = null;
    final error = await repo.years().then<Object?>((_) => null, onError: (e, _) => e);
    expect(error, isA<ApiException>());
    expect((error as ApiException).statusCode, 401);
  }, skip: enabled ? false : '需要先启动后端：$baseUrl（RUN_BACKEND_TESTS=1 开启）');
}
