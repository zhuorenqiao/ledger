import 'txn.dart';

class CategorySlice {
  const CategorySlice(this.category, this.amount);

  final TxnCategory category;
  final double amount;
}

class Summary {
  const Summary({
    required this.expense,
    required this.income,
    required this.expenseByCategory,
    required this.incomeByCategory,
    required this.count,
  });

  final double expense;
  final double income;
  final List<CategorySlice> expenseByCategory;
  final List<CategorySlice> incomeByCategory;
  final int count;

  double get balance => income - expense;

  static const empty = Summary(
    expense: 0,
    income: 0,
    expenseByCategory: [],
    incomeByCategory: [],
    count: 0,
  );
}

class TrendPoint {
  const TrendPoint(this.label, this.expense, this.income);

  final String label;
  final double expense;
  final double income;
}

/// 在内存里汇总账单，本地仓库和单元测试用它复刻后端的统计口径。
Summary summarize(Iterable<Txn> txns) {
  var expense = 0.0, income = 0.0;
  final exp = <String, double>{};
  final inc = <String, double>{};
  for (final t in txns) {
    if (t.type == TxnType.expense) {
      expense += t.amount;
      exp[t.categoryKey] = (exp[t.categoryKey] ?? 0) + t.amount;
    } else {
      income += t.amount;
      inc[t.categoryKey] = (inc[t.categoryKey] ?? 0) + t.amount;
    }
  }
  List<CategorySlice> slices(Map<String, double> m) {
    final list = m.entries.map((e) => CategorySlice(categoryOf(e.key), e.value)).toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
    return list;
  }

  return Summary(
    expense: expense,
    income: income,
    expenseByCategory: slices(exp),
    incomeByCategory: slices(inc),
    count: txns.length,
  );
}

/// 按天聚合出连续的日趋势，缺失日期补 0。
List<TrendPoint> dailyTrendOf(Iterable<Txn> txns, int year, int month) {
  final daysInMonth = DateTime(year, month + 1, 0).day;
  final buckets = <String, List<Txn>>{};
  for (final t in txns) {
    final d = t.dayDate;
    if (d.year == year && d.month == month) {
      buckets.putIfAbsent(t.day, () => []).add(t);
    }
  }
  return List.generate(daysInMonth, (i) {
    final s = summarize(buckets[dayKey(DateTime(year, month, i + 1))] ?? const []);
    return TrendPoint('${i + 1}', s.expense, s.income);
  });
}

/// 按月聚合出 12 个月的趋势。
List<TrendPoint> monthlyTrendOf(Iterable<Txn> txns, int year) {
  final buckets = <int, List<Txn>>{};
  for (final t in txns) {
    final d = t.dayDate;
    if (d.year == year) buckets.putIfAbsent(d.month, () => []).add(t);
  }
  return List.generate(12, (i) {
    final s = summarize(buckets[i + 1] ?? const []);
    return TrendPoint('${i + 1}', s.expense, s.income);
  });
}
