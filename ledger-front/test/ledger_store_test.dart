import 'package:ledger_front/data/demo_data.dart';
import 'package:ledger_front/data/ledger_repository.dart';
import 'package:ledger_front/models/stats.dart';
import 'package:ledger_front/models/txn.dart';
import 'package:ledger_front/state/ledger_store.dart';
import 'package:flutter_test/flutter_test.dart';

Txn expense(String categoryKey, double amount, String day) => Txn(
  type: TxnType.expense,
  categoryKey: categoryKey,
  amount: amount,
  day: day,
  createdAt: 0,
);

/// 只记录调用参数的假仓库，用来断言 Store 传给后端的统计区间。
class _RecordingRepository extends LedgerRepository {
  final calls = <String>[];

  @override
  Future<Summary> summary({String? fromDay, String? toDay}) {
    calls.add('summary|$fromDay|$toDay');
    return Future.value(Summary.empty);
  }

  @override
  Future<List<TrendPoint>> dailyTrend(int year, int month) {
    calls.add('daily|$year-$month');
    return Future.value(const []);
  }

  @override
  Future<List<TrendPoint>> monthlyTrend(int year) {
    calls.add('monthly|$year');
    return Future.value(const []);
  }

  @override
  Future<List<int>> years() {
    calls.add('years');
    return Future.value(const [2026]);
  }

  @override
  Future<TxnPage> loadPage(int page, int size) async {
    calls.add('loadPage|$page|$size');
    return const TxnPage([], false);
  }

  @override
  Future<List<Txn>> loadDay(String day) async {
    calls.add('loadDay|$day');
    return const [];
  }

  @override
  Future<Txn> insert(Txn txn) {
    calls.add('insert');
    return Future.value(
      Txn(
        id: 1,
        type: txn.type,
        categoryKey: txn.categoryKey,
        amount: txn.amount,
        day: txn.day,
        createdAt: txn.createdAt,
        note: txn.note,
      ),
    );
  }

  @override
  Future<void> delete(int id) async => calls.add('delete|$id');

  @override
  Future<void> deleteAll() async => calls.add('deleteAll');

  @override
  Future<void> insertMany(List<Txn> txns) async => calls.add('insertMany|${txns.length}');

  @override
  Future<List<Txn>> loadAll() async {
    calls.add('loadAll');
    return const [];
  }
}

void main() {
  group('summarize', () {
    test('按类型汇总并给出分类明细', () {
      final s = summarize([
        expense('food', 30, '2026-09-01'),
        expense('food', 20, '2026-09-02'),
        expense('transport', 15, '2026-09-02'),
        Txn(
          type: TxnType.income,
          categoryKey: 'salary',
          amount: 1000,
          day: '2026-09-10',
          createdAt: 0,
        ),
      ]);

      expect(s.expense, 65);
      expect(s.income, 1000);
      expect(s.balance, 935);
      expect(s.expenseByCategory.first.category.key, 'food');
      expect(s.expenseByCategory.first.amount, 50);
      expect(s.count, 4);
    });

    test('空账本得到全零结果', () {
      final s = summarize(const []);
      expect(s.expense, 0);
      expect(s.income, 0);
      expect(s.expenseByCategory, isEmpty);
    });
  });

  group('LedgerStore 统计委托', () {
    test('日/月/年统计传给仓库的区间正确', () async {
      final repo = _RecordingRepository();
      final store = LedgerStore(repo);

      await store.summaryOfDay(DateTime(2026, 9, 5));
      await store.summaryOfMonth(2026, 9);
      await store.summaryOfYear(2026);

      expect(repo.calls, [
        'summary|2026-09-05|2026-09-05',
        'summary|2026-09-01|2026-09-30',
        'summary|2026-01-01|2026-12-31',
      ]);
    });

    test('趋势与年份直接走仓库', () async {
      final repo = _RecordingRepository();
      final store = LedgerStore(repo);

      expect(await store.dailyTrend(2026, 9), isEmpty);
      expect(await store.monthlyTrend(2026), isEmpty);
      expect(await store.years(), [2026]);
      expect(repo.calls, ['daily|2026-9', 'monthly|2026', 'years']);
    });

    test('写入后 revision 递增，供报表页重新拉统计', () async {
      final repo = _RecordingRepository();
      final store = LedgerStore(repo);
      expect(store.revision, 0);

      await store.add(expense('food', 12, '2026-09-01'));
      expect(store.revision, 1);
      expect(store.txns.single.id, 1);

      await store.clearAll();
      expect(store.revision, 2);
      expect(store.txns, isEmpty);
    });
  });

  group('流水懒加载', () {
    test('load 取首页，loadMore 追加到最后一页后停止', () async {
      final repo = _PagingRepository();
      final store = LedgerStore(repo);

      await store.load();
      expect(store.txns, hasLength(20));
      expect(store.hasMore, isTrue);
      expect(repo.pages, [0]);

      await store.loadMore();
      expect(store.txns, hasLength(40));
      expect(store.hasMore, isTrue);

      await store.loadMore();
      expect(store.txns, hasLength(45));
      expect(store.hasMore, isFalse);

      await store.loadMore();
      expect(repo.pages, [0, 1, 2]);
    });

    test('下一页失败保留已加载列表，只在页脚提示', () async {
      final repo = _PagingRepository()..failNextPage = true;
      final store = LedgerStore(repo);
      await store.load();

      await store.loadMore();

      expect(store.txns, hasLength(20));
      expect(store.error, isNull);
      expect(store.moreError, isNotNull);
      expect(store.hasMore, isTrue);

      repo.failNextPage = false;
      await store.loadMore();
      expect(store.txns, hasLength(40));
      expect(store.moreError, isNull);
    });

    test('正好一页时不再请求下一页', () async {
      final repo = _PagingRepository(total: 20);
      final store = LedgerStore(repo);

      await store.load();

      expect(store.txns, hasLength(20));
      expect(store.hasMore, isFalse);
      await store.loadMore();
      expect(repo.pages, [0]);
    });

    test('当日流水走仓库按天查询', () async {
      final repo = _RecordingRepository();
      final store = LedgerStore(repo);
      await store.txnsOfDay(DateTime(2026, 9, 5));
      expect(repo.calls, ['loadDay|2026-09-05']);
    });
  });

  test('dayKey 固定为 yyyy-MM-dd', () {
    expect(dayKey(DateTime(2026, 1, 5)), '2026-01-05');
  });

  test('示例数据金额最多两位小数', () {
    // 后端金额列是 DECIMAL(12,2) 且 @Digits 校验，超精度会让整批写入被拒
    final tooPrecise = demoTxns().where((t) {
      final text = t.amount.toString();
      final dot = text.indexOf('.');
      return dot >= 0 && text.length - dot - 1 > 2;
    }).toList();
    expect(tooPrecise, isEmpty);
  });
}

/// 分页返回 [total] 条账单的假仓库，可让第 0 页之后的请求失败。
class _PagingRepository extends LedgerRepository {
  _PagingRepository({this.total = 45});

  final int total;
  bool failNextPage = false;
  final pages = <int>[];

  List<Txn> get _all => List.generate(
    total,
    (i) => Txn(
      id: i + 1,
      type: TxnType.expense,
      categoryKey: 'food',
      amount: 1,
      day: '2026-09-01',
      createdAt: i,
    ),
  );

  @override
  Future<TxnPage> loadPage(int page, int size) async {
    pages.add(page);
    if (page > 0 && failNextPage) throw Exception('下一页失败');
    final start = page * size;
    if (start >= total) return const TxnPage([], false);
    final end = (start + size).clamp(0, total);
    return TxnPage(_all.sublist(start, end), end < total);
  }

  @override
  Future<List<Txn>> loadAll() async => _all;

  @override
  Future<List<Txn>> loadDay(String day) async => _all;

  @override
  Future<Txn> insert(Txn txn) => throw UnimplementedError();

  @override
  Future<void> insertMany(List<Txn> txns) => throw UnimplementedError();

  @override
  Future<void> delete(int id) => throw UnimplementedError();

  @override
  Future<void> deleteAll() => throw UnimplementedError();

  @override
  Future<Summary> summary({String? fromDay, String? toDay}) async => Summary.empty;

  @override
  Future<List<TrendPoint>> dailyTrend(int year, int month) async => const [];

  @override
  Future<List<TrendPoint>> monthlyTrend(int year) async => const [];

  @override
  Future<List<int>> years() async => const [2026];
}
