import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:ledger_front/data/api_client.dart';
import 'package:ledger_front/data/remote_ledger_repository.dart';
import 'package:ledger_front/models/txn.dart';
import 'package:flutter_test/flutter_test.dart';

/// 按请求返回固定 JSON，用来校验客户端与后端 DTO 的字段约定。
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.responder);

  final (Object? body, int status) Function(RequestOptions options) responder;
  final requests = <RequestOptions>[];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final (body, status) = responder(options);
    // 成功响应由后端全局包装成统一响应体，失败响应由异常处理器给出 code
    final envelope = status < 400
        ? {'code': 0, 'message': '成功', 'success': true, 'data': body}
        : body;
    return ResponseBody.fromString(
      jsonEncode(envelope),
      status,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );
  }
}

RemoteLedgerRepository _repo(
  (Object?, int) Function(RequestOptions) responder, {
  void Function()? onUnauthorized,
}) {
  return RemoteLedgerRepository(
    ApiClient(
      baseUrl: 'http://server.test',
      token: () => 't',
      onUnauthorized: onUnauthorized,
      adapter: _StubAdapter(responder),
    ),
  );
}

Object? _body(RequestOptions options) => switch (options.data) {
  final String s => jsonDecode(s),
  final Uint8List b => jsonDecode(utf8.decode(b)),
  final Object o => o,
  null => null,
};

Future<ApiException> _failure(Future<void> Function() action) async {
  try {
    await action();
  } on ApiException catch (e) {
    return e;
  }
  throw StateError('期望抛出 ApiException');
}

Map<String, dynamic> _txnJson(int id, String type, String category, String day) => {
  'id': id,
  'type': type,
  'category': category,
  'amount': 12.5,
  'day': day,
  'note': '午餐',
  'createdAt': 1750000000000,
};

void main() {
  test('loadAll 按分页取完所有账单', () async {
    late _StubAdapter adapter;
    adapter = _StubAdapter((options) {
      if (options.queryParameters['page'] == 0) {
        return ({'items': [_txnJson(2, 'expense', 'food', '2026-09-02')], 'last': false}, 200);
      }
      return ({'items': [_txnJson(1, 'income', 'salary', '2026-09-01')], 'last': true}, 200);
    });
    final repo = RemoteLedgerRepository(
      ApiClient(baseUrl: 'http://server.test', token: () => 't', adapter: adapter),
    );

    final txns = await repo.loadAll();

    expect(txns, hasLength(2));
    expect(txns.first.id, 2);
    expect(txns.first.type, TxnType.expense);
    expect(txns.first.categoryKey, 'food');
    expect(txns.first.note, '午餐');
    expect(txns.last.type, TxnType.income);
    expect(adapter.requests, hasLength(2));
  });

  test('insert 提交的字段与后端 TxnRequest 对齐，并回填服务器 id', () async {
    final repo = _repo((_) => (_txnJson(42, 'expense', 'transport', '2026-09-03'), 201));

    final saved = await repo.insert(
      Txn(
        type: TxnType.expense,
        categoryKey: 'transport',
        amount: 18,
        day: '2026-09-03',
        createdAt: 1750000000000,
        note: '地铁',
      ),
    );

    expect(saved.id, 42);
    expect(saved.amount, 12.5);
  });

  test('summary 解析后端聚合结果', () async {
    late _StubAdapter adapter;
    adapter = _StubAdapter((options) {
      expect(options.path, '/api/stats/summary');
      expect(options.queryParameters['from'], '2026-09-01');
      expect(options.queryParameters['to'], '2026-09-30');
      return (
        {
          'expense': 120.5,
          'income': 12000,
          'count': 7,
          'expenseByCategory': [
            {'category': 'food', 'amount': 80.5},
            {'category': 'transport', 'amount': 40},
          ],
          'incomeByCategory': [
            {'category': 'salary', 'amount': 12000},
          ],
        },
        200,
      );
    });
    final repo = RemoteLedgerRepository(
      ApiClient(baseUrl: 'http://server.test', token: () => 't', adapter: adapter),
    );

    final summary = await repo.summary(fromDay: '2026-09-01', toDay: '2026-09-30');

    expect(summary.expense, 120.5);
    expect(summary.count, 7);
    expect(summary.expenseByCategory.first.category.key, 'food');
    expect(summary.incomeByCategory.single.category.key, 'salary');
  });

  test('趋势接口还原成连续刻度', () async {
    final repo = _repo((_) => ([
      {'label': '1', 'expense': 10, 'income': 0},
      {'label': '2', 'expense': 0, 'income': 300},
    ], 200));

    final trend = await repo.dailyTrend(2026, 9);

    expect(trend.map((p) => p.label), ['1', '2']);
    expect(trend.last.income, 300);
  });

  test('years 返回后端给出的年份', () async {
    final repo = _repo((_) => ([2026, 2025], 200));
    expect(await repo.years(), [2026, 2025]);
  });

  test('insertMany 走批量接口并带上全部账单', () async {
    late _StubAdapter adapter;
    adapter = _StubAdapter((_) => ({'inserted': 2}, 200));
    final repo = RemoteLedgerRepository(
      ApiClient(baseUrl: 'http://server.test', token: () => 't', adapter: adapter),
    );

    await repo.insertMany([
      Txn(type: TxnType.expense, categoryKey: 'food', amount: 1, day: '2026-09-01', createdAt: 0),
      Txn(type: TxnType.expense, categoryKey: 'food', amount: 2, day: '2026-09-02', createdAt: 0),
    ]);

    final options = adapter.requests.single;
    expect(options.path, '/api/txns/batch');
    expect((_body(options) as Map)['txns'], hasLength(2));
  });

  test('401 触发会话过期回调并带出业务码', () async {
    var expired = false;
    final repo = _repo(
      (_) => ({'code': 40100, 'message': '未登录或登录已过期', 'success': false, 'data': null}, 401),
      onUnauthorized: () => expired = true,
    );

    final error = await _failure(repo.years);

    expect(error.unauthorized, isTrue);
    expect(error.code, 40100);
    expect(expired, isTrue);
  });

  test('后端校验失败时抛出带 code 与 message 的 ApiException', () async {
    final repo = _repo(
      (_) => ({'code': 40001, 'message': '分类 food 不属于 income', 'success': false, 'data': null}, 400),
    );

    final error = await _failure(repo.deleteAll);

    expect(error.statusCode, 400);
    expect(error.code, 40001);
    expect(error.message, '分类 food 不属于 income');
  });

  test('delete 走 /api/txns/{id}', () async {
    late _StubAdapter adapter;
    adapter = _StubAdapter((_) => (null, 200));
    final repo = RemoteLedgerRepository(
      ApiClient(baseUrl: 'http://server.test', token: () => 't', adapter: adapter),
    );

    await repo.delete(9);

    expect(adapter.requests.single.method, 'DELETE');
    expect(adapter.requests.single.path, '/api/txns/9');
  });

  test('loadPage 依据 last 判断是否还有下一页', () async {
    late _StubAdapter adapter;
    adapter = _StubAdapter((options) {
      expect(options.queryParameters['size'], 20);
      return ({'items': [_txnJson(1, 'expense', 'food', '2026-09-01')], 'last': false}, 200);
    });
    final repo = RemoteLedgerRepository(
      ApiClient(baseUrl: 'http://server.test', token: () => 't', adapter: adapter),
    );

    final page = await repo.loadPage(0, 20);

    expect(page.txns, hasLength(1));
    expect(page.hasMore, isTrue);
  });

  test('loadDay 带 day 查询参数', () async {
    late _StubAdapter adapter;
    adapter = _StubAdapter((options) {
      expect(options.queryParameters['day'], '2026-09-01');
      return ({'items': [_txnJson(3, 'expense', 'food', '2026-09-01')], 'last': true}, 200);
    });
    final repo = RemoteLedgerRepository(
      ApiClient(baseUrl: 'http://server.test', token: () => 't', adapter: adapter),
    );

    final txns = await repo.loadDay('2026-09-01');

    expect(txns.single.id, 3);
  });
}
