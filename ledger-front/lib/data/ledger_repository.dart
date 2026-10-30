import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../models/stats.dart';
import '../models/txn.dart';

/// 一页账单及其后是否还有数据。
class TxnPage {
  const TxnPage(this.txns, this.hasMore);

  final List<Txn> txns;
  final bool hasMore;
}

/// 账本存储接口：后端仓库走 REST + MySQL，本地实现（移动端 SQLite、Web 端
/// SharedPreferences）作为离线备用。
abstract class LedgerRepository {
  Future<List<Txn>> loadAll();

  /// 分页读取，流水页懒加载用。
  Future<TxnPage> loadPage(int page, int size);

  /// 某一天的全部账单（报表的当日流水）。
  Future<List<Txn>> loadDay(String day);

  Future<Txn> insert(Txn txn);

  Future<void> insertMany(List<Txn> txns);

  Future<void> delete(int id);

  Future<void> deleteAll();

  /// 区间统计，fromDay/toDay 为 yyyy-MM-dd，省略即不限。
  Future<Summary> summary({String? fromDay, String? toDay});

  Future<List<TrendPoint>> dailyTrend(int year, int month);

  Future<List<TrendPoint>> monthlyTrend(int year);

  /// 有账单的年份，倒序；至少包含今年。
  Future<List<int>> years();
}

/// 本地仓库共用：把账单读进内存后按后端口径聚合、分页。
mixin InMemoryStats on LedgerRepository {
  @override
  Future<TxnPage> loadPage(int page, int size) async {
    final all = await loadAll();
    final start = page * size;
    if (start >= all.length) return const TxnPage([], false);
    final end = (start + size).clamp(0, all.length);
    return TxnPage(all.sublist(start, end), end < all.length);
  }

  @override
  Future<List<Txn>> loadDay(String day) async =>
      (await loadAll()).where((t) => t.day == day).toList();

  @override
  Future<Summary> summary({String? fromDay, String? toDay}) async {
    return summarize(_inRange(await loadAll(), fromDay, toDay));
  }

  @override
  Future<List<TrendPoint>> dailyTrend(int year, int month) async {
    final all = await loadAll();
    return dailyTrendOf(
      all.where((t) => t.dayDate.year == year && t.dayDate.month == month),
      year,
      month,
    );
  }

  @override
  Future<List<TrendPoint>> monthlyTrend(int year) async {
    final all = await loadAll();
    return monthlyTrendOf(
      all.where((t) => t.dayDate.year == year),
      year,
    );
  }

  @override
  Future<List<int>> years() async {
    final set = (await loadAll()).map((t) => t.dayDate.year).toSet();
    set.add(DateTime.now().year);
    return set.toList()..sort((a, b) => b.compareTo(a));
  }

  static Iterable<Txn> _inRange(List<Txn> txns, String? fromDay, String? toDay) => txns.where((t) =>
      (fromDay == null || t.day.compareTo(fromDay) >= 0) &&
      (toDay == null || t.day.compareTo(toDay) <= 0));
}

const _rowType = 'type';
const _rowCategory = 'category';
const _rowAmount = 'amount';
const _rowDay = 'day';
const _rowNote = 'note';
const _rowCreated = 'created';

Map<String, Object?> _toRow(Txn t) => {
  _rowType: t.type.name,
  _rowCategory: t.categoryKey,
  _rowAmount: t.amount,
  _rowDay: t.day,
  _rowNote: t.note,
  _rowCreated: t.createdAt,
};

Txn _fromRow(int id, Map<String, Object?> row) => Txn(
  id: id,
  type: TxnType.values.byName(row[_rowType] as String),
  categoryKey: row[_rowCategory] as String,
  amount: (row[_rowAmount] as num).toDouble(),
  day: row[_rowDay] as String,
  note: row[_rowNote] as String? ?? '',
  createdAt: (row[_rowCreated] as num).toInt(),
);

class SqfliteRepository extends LedgerRepository with InMemoryStats {
  SqfliteRepository();

  static const _dbName = 'ledger.db';
  Database? _db;

  Future<Database> _open() async {
    if (_db != null) return _db!;
    final dir = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dir, _dbName),
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE txn (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT NOT NULL,
            category TEXT NOT NULL,
            amount REAL NOT NULL,
            day TEXT NOT NULL,
            note TEXT NOT NULL DEFAULT '',
            created INTEGER NOT NULL
          )
        ''');
        await db.execute('CREATE INDEX idx_txn_day ON txn (day)');
      },
    );
    return _db!;
  }

  @override
  Future<List<Txn>> loadAll() async {
    final db = await _open();
    final rows = await db.query('txn', orderBy: 'day DESC, created DESC');
    return rows.map((r) => _fromRow(r['id'] as int, r)).toList();
  }

  @override
  Future<Txn> insert(Txn txn) async {
    final db = await _open();
    final id = await db.insert('txn', _toRow(txn));
    return _fromRow(id, _toRow(txn));
  }

  @override
  Future<void> insertMany(List<Txn> txns) async {
    final db = await _open();
    final batch = db.batch();
    for (final t in txns) {
      batch.insert('txn', _toRow(t));
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<void> delete(int id) async {
    final db = await _open();
    await db.delete('txn', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> deleteAll() async {
    final db = await _open();
    await db.delete('txn');
  }
}

class SharedPreferencesRepository extends LedgerRepository with InMemoryStats {
  SharedPreferencesRepository();

  static const _key = 'ledger.txns';

  Future<(SharedPreferences, List<Txn>)> _read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return (prefs, const <Txn>[]);
    final rows = (jsonDecode(raw) as List).cast<Map<String, Object?>>();
    return (prefs, rows.map((r) => _fromRow(r['id'] as int, r)).toList());
  }

  Future<void> _write(SharedPreferences prefs, List<Txn> txns) {
    final rows = [
      for (final t in txns)
        {'id': t.id, ..._toRow(t)},
    ];
    return prefs.setString(_key, jsonEncode(rows));
  }

  @override
  Future<List<Txn>> loadAll() async {
    final (_, txns) = await _read();
    final sorted = [...txns]..sort((a, b) => b.day.compareTo(a.day));
    return sorted;
  }

  @override
  Future<Txn> insert(Txn txn) async {
    final (prefs, txns) = await _read();
    final id = txns.map((t) => t.id ?? 0).fold<int>(0, (a, b) => a > b ? a : b) + 1;
    final saved = _fromRow(id, _toRow(txn));
    await _write(prefs, [saved, ...txns]);
    return saved;
  }

  @override
  Future<void> insertMany(List<Txn> txns) async {
    final (prefs, existing) = await _read();
    var id = existing.map((t) => t.id ?? 0).fold<int>(0, (a, b) => a > b ? a : b);
    final added = [
      for (final t in txns)
        _fromRow(++id, _toRow(t)),
    ];
    await _write(prefs, [...added, ...existing]);
  }

  @override
  Future<void> delete(int id) async {
    final (prefs, txns) = await _read();
    await _write(prefs, txns.where((t) => t.id != id).toList());
  }

  @override
  Future<void> deleteAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
