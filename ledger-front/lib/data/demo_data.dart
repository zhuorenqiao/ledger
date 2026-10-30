import '../models/txn.dart';

/// 演示数据：近 14 个月的日常支出 + 每月工资，便于日/月/年三种视图都有内容。
List<Txn> demoTxns() {
  final now = DateTime.now();
  var seed = 7;
  double next(double lo, double hi) {
    seed = (seed * 1103515245 + 12345) & 0x7fffffff;
    return lo + (seed % 10000) / 10000 * (hi - lo);
  }

  // 后端金额列为 DECIMAL(12,2)，随机值必须先到分为单位再入库。
  double money(double v) => double.parse(v.toStringAsFixed(2));

  final result = <Txn>[];
  for (var back = 13; back >= 0; back--) {
    final month = DateTime(now.year, now.month - back);
    final lastDay = DateTime(now.year, now.month).isAtSameMomentAs(month)
        ? now.day
        : DateTime(month.year, month.month + 1, 0).day;
    result.add(
      Txn(
        type: TxnType.income,
        categoryKey: 'salary',
        amount: 12000 + (month.month % 3) * 600,
        day: dayKey(DateTime(month.year, month.month, 10)),
        createdAt: DateTime(month.year, month.month, 10).millisecondsSinceEpoch,
      ),
    );
    if (month.month % 4 == 0) {
      result.add(
        Txn(
          type: TxnType.income,
          categoryKey: 'investment',
          amount: money(next(300, 2600)),
          day: dayKey(DateTime(month.year, month.month, 18)),
          createdAt: DateTime(month.year, month.month, 18).millisecondsSinceEpoch,
        ),
      );
    }
    const spendCats = [
      ('food', 18.0, 160.0),
      ('transport', 6.0, 45.0),
      ('shopping', 60.0, 680.0),
      ('entertainment', 20.0, 220.0),
      ('medical', 30.0, 400.0),
      ('study', 40.0, 300.0),
      ('beauty', 80.0, 900.0),
    ];
    final createdBase = DateTime(month.year, month.month, 1).millisecondsSinceEpoch;
    for (var d = 1; d <= lastDay; d++) {
      final day = DateTime(month.year, month.month, d);
      final items = <(String, double)>[];
      for (final (key, lo, hi) in spendCats) {
        final chance = key == 'food' ? 0.85 : 0.18;
        if (next(0, 1) < chance) {
          items.add((key, next(lo, hi)));
        }
      }
      if (day.day % 5 == 0) items.add(('housing', next(900, 2600)));
      for (var i = 0; i < items.length; i++) {
        result.add(
          Txn(
            type: TxnType.expense,
            categoryKey: items[i].$1,
            amount: money(items[i].$2),
            day: dayKey(day),
            createdAt: createdBase + d * 100000 + i * 1000,
          ),
        );
      }
    }
  }
  return result;
}
