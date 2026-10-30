import '../models/stats.dart';
import '../models/txn.dart';
import 'api_client.dart';
import 'ledger_repository.dart';

/// 走 Java 后端 REST 接口的账本仓库，数据落在 MySQL。
class RemoteLedgerRepository implements LedgerRepository {
  RemoteLedgerRepository(this._api);

  /// loadAll 逐页取完时的页大小；流水页懒加载由 LedgerStore 指定 20。
  static const _pageSize = 200;

  /// 单日账单一次取完的上限，后端单页最大 1000。
  static const _dayPageSize = 500;

  final ApiClient _api;

  @override
  Future<List<Txn>> loadAll() async {
    final result = <Txn>[];
    var page = 0;
    while (true) {
      final chunk = await loadPage(page, _pageSize);
      result.addAll(chunk.txns);
      if (!chunk.hasMore) return result;
      page++;
    }
  }

  @override
  Future<TxnPage> loadPage(int page, int size) async {
    final payload = await _api.get(
      '/api/txns',
      query: {'page': page, 'size': size},
    ) as Map;
    return _pageFrom(payload);
  }

  @override
  Future<List<Txn>> loadDay(String day) async {
    final payload = await _api.get(
      '/api/txns',
      query: {'day': day, 'page': 0, 'size': _dayPageSize},
    ) as Map;
    return _pageFrom(payload).txns;
  }

  static TxnPage _pageFrom(Map payload) {
    final txns = (payload['items'] as List)
        .cast<Map<String, dynamic>>()
        .map(_txnFromJson)
        .toList();
    return TxnPage(txns, payload['last'] != true);
  }

  @override
  Future<Txn> insert(Txn txn) async {
    final payload = await _api.post('/api/txns', _txnToJson(txn)) as Map;
    return _txnFromJson(payload.cast<String, dynamic>());
  }

  @override
  Future<void> insertMany(List<Txn> txns) async {
    await _api.post('/api/txns/batch', {
      'txns': txns.map(_txnToJson).toList(),
    });
  }

  @override
  Future<void> delete(int id) => _api.delete('/api/txns/$id');

  @override
  Future<void> deleteAll() async {
    await _api.delete('/api/txns');
  }

  @override
  Future<Summary> summary({String? fromDay, String? toDay}) async {
    final payload = await _api.get(
      '/api/stats/summary',
      query: {'from': fromDay, 'to': toDay},
    ) as Map;
    return Summary(
      expense: (payload['expense'] as num).toDouble(),
      income: (payload['income'] as num).toDouble(),
      expenseByCategory: _slices(payload['expenseByCategory']),
      incomeByCategory: _slices(payload['incomeByCategory']),
      count: (payload['count'] as num).toInt(),
    );
  }

  @override
  Future<List<TrendPoint>> dailyTrend(int year, int month) =>
      _trend('/api/stats/daily', {'year': year, 'month': month});

  @override
  Future<List<TrendPoint>> monthlyTrend(int year) =>
      _trend('/api/stats/monthly', {'year': year});

  @override
  Future<List<int>> years() async {
    final payload = await _api.get('/api/stats/years') as List;
    return payload.cast<num>().map((e) => e.toInt()).toList();
  }

  Future<List<TrendPoint>> _trend(String path, Map<String, dynamic> query) async {
    final payload = await _api.get(path, query: query) as List;
    return payload.cast<Map<String, dynamic>>().map((e) {
      return TrendPoint(
        e['label'] as String,
        (e['expense'] as num).toDouble(),
        (e['income'] as num).toDouble(),
      );
    }).toList();
  }

  static List<CategorySlice> _slices(Object? raw) =>
      (raw as List).cast<Map<String, dynamic>>().map((e) {
        return CategorySlice(categoryOf(e['category'] as String), (e['amount'] as num).toDouble());
      }).toList();
}

Txn _txnFromJson(Map<String, dynamic> json) => Txn(
  id: (json['id'] as num).toInt(),
  type: TxnType.values.byName(json['type'] as String),
  categoryKey: json['category'] as String,
  amount: (json['amount'] as num).toDouble(),
  day: json['day'] as String,
  note: json['note'] as String? ?? '',
  createdAt: (json['createdAt'] as num).toInt(),
);

Map<String, Object?> _txnToJson(Txn t) => {
  'type': t.type.name,
  'category': t.categoryKey,
  'amount': t.amount,
  'day': t.day,
  'note': t.note,
  'createdAt': t.createdAt,
};
