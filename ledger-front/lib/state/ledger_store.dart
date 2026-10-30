import 'package:flutter/foundation.dart' show ChangeNotifier;

import '../data/demo_data.dart';
import '../data/ledger_repository.dart';
import '../models/stats.dart';
import '../models/txn.dart';

/// 内存中持有一份账本流水，统计口径全部委托给仓库（线上即后端 + MySQL）。
class LedgerStore extends ChangeNotifier {
  LedgerStore(this._repo);

  final LedgerRepository _repo;

  /// 流水页一次加载的条数。
  static const pageSize = 20;

  List<Txn> _txns = const [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  bool _disposed = false;
  Object? _error;
  Object? _moreError;
  int _page = 0;

  List<Txn> get txns => _txns;
  bool get loading => _loading;
  bool get loadingMore => _loadingMore;
  bool get hasMore => _hasMore;
  Object? get error => _error;
  Object? get moreError => _moreError;
  bool get isEmpty => _txns.isEmpty;

  /// 每次写入递增，报表页据此判断是否需要重新拉取统计。
  int get revision => _revision;
  int _revision = 0;

  /// 重新从第一页开始加载。
  Future<void> load() async {
    _setLoading(true);
    _error = null;
    try {
      final first = await _repo.loadPage(0, pageSize);
      _txns = first.txns;
      _page = 0;
      _hasMore = first.hasMore;
    } catch (e) {
      _error = e;
    }
    _setLoading(false);
  }

  /// 滚动到底部时加载下一页。
  Future<void> loadMore() async {
    if (_loading || _loadingMore || !_hasMore) return;
    _loadingMore = true;
    _moreError = null;
    _notify();
    try {
      final next = await _repo.loadPage(_page + 1, pageSize);
      _page++;
      // 新增一笔会让服务端整体后移一位，边界上的记录可能重复出现
      final seen = _txns.map((t) => t.id).toSet();
      _txns = [..._txns, ...next.txns.where((t) => !seen.contains(t.id))];
      _hasMore = next.hasMore;
    } catch (e) {
      _moreError = e;
    }
    _loadingMore = false;
    _notify();
  }

  Future<void> add(Txn txn) async {
    final saved = await _repo.insert(txn);
    _txns = [saved, ..._txns]..sort(_byDayDesc);
    _touch();
  }

  Future<void> remove(Txn txn) async {
    final id = txn.id;
    if (id == null) return;
    await _repo.delete(id);
    _txns = _txns.where((t) => t.id != id).toList();
    _touch();
  }

  Future<void> clearAll() async {
    await _repo.deleteAll();
    _txns = const [];
    _touch();
  }

  Future<void> seedDemoData() async {
    await _repo.insertMany(demoTxns());
    await load();
  }

  // ---------- 统计（由仓库计算，线上走后端接口） ----------

  Future<Summary> summaryOfDay(DateTime day) {
    final key = dayKey(day);
    return _repo.summary(fromDay: key, toDay: key);
  }

  Future<Summary> summaryOfMonth(int year, int month) async {
    final (from, to) = _monthRange(year, month);
    return _repo.summary(fromDay: from, toDay: to);
  }

  Future<Summary> summaryOfYear(int year) => _repo.summary(
    fromDay: '$year-01-01',
    toDay: '$year-12-31',
  );

  Future<List<TrendPoint>> dailyTrend(int year, int month) => _repo.dailyTrend(year, month);

  Future<List<TrendPoint>> monthlyTrend(int year) => _repo.monthlyTrend(year);

  Future<List<int>> years() => _repo.years();

  /// 某一天的流水：内存里只有已加载的分页，需要单独向仓库取。
  Future<List<Txn>> txnsOfDay(DateTime day) => _repo.loadDay(dayKey(day));

  List<DayGroup> get dayGroups {
    final buckets = <String, List<Txn>>{};
    for (final t in _txns) {
      buckets.putIfAbsent(t.day, () => []).add(t);
    }
    final keys = buckets.keys.toList()..sort((a, b) => b.compareTo(a));
    return keys.map((k) {
      final list = buckets[k]!;
      final s = summarize(list);
      return DayGroup(DateTime.parse(k), list, s.expense, s.income);
    }).toList();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _setLoading(bool value) {
    _loading = value;
    _notify();
  }

  void _touch() {
    _revision++;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  static (String, String) _monthRange(int year, int month) => (
    dayKey(DateTime(year, month, 1)),
    dayKey(DateTime(year, month + 1, 0)),
  );

  static int _byDayDesc(Txn a, Txn b) {
    final byDay = b.day.compareTo(a.day);
    return byDay != 0 ? byDay : b.createdAt.compareTo(a.createdAt);
  }
}

class DayGroup {
  const DayGroup(this.day, this.txns, this.expense, this.income);

  final DateTime day;
  final List<Txn> txns;
  final double expense;
  final double income;
}
