import 'package:flutter/material.dart';

enum TxnType { expense, income }

/// 分类的静态属性。显示名称属于界面文案，由 AppLocalizations.categoryLabel 提供。
class TxnCategory {
  const TxnCategory(this.key, this.icon, this.color);

  final String key;
  final IconData icon;
  final Color color;
}

const List<TxnCategory> kExpenseCategories = [
  TxnCategory('food', Icons.restaurant, Color(0xFFFF7A45)),
  TxnCategory('transport', Icons.local_taxi, Color(0xFF2FA8FF)),
  TxnCategory('shopping', Icons.shopping_bag, Color(0xFFA855F7)),
  TxnCategory('housing', Icons.home, Color(0xFF14C3A2)),
  TxnCategory('entertainment', Icons.sports_esports, Color(0xFFFFC53D)),
  TxnCategory('medical', Icons.local_hospital, Color(0xFFFF4D6D)),
  TxnCategory('study', Icons.menu_book, Color(0xFF4C6EF5)),
  TxnCategory('beauty', Icons.checkroom, Color(0xFFF06595)),
  TxnCategory('other_expense', Icons.more_horiz, Color(0xFF8C9BAB)),
];

const List<TxnCategory> kIncomeCategories = [
  TxnCategory('salary', Icons.badge, Color(0xFF22C55E)),
  TxnCategory('bonus', Icons.card_giftcard, Color(0xFFFB923C)),
  TxnCategory('part_time', Icons.work, Color(0xFF06B6D4)),
  TxnCategory('investment', Icons.trending_up, Color(0xFF8B5CF6)),
  TxnCategory('other_income', Icons.savings, Color(0xFF8C9BAB)),
];

TxnCategory categoryOf(String key) {
  return [...kExpenseCategories, ...kIncomeCategories].firstWhere(
    (c) => c.key == key,
    orElse: () => kExpenseCategories.last,
  );
}

List<TxnCategory> categoriesOf(TxnType type) =>
    type == TxnType.expense ? kExpenseCategories : kIncomeCategories;

class Txn {
  const Txn({
    this.id,
    required this.type,
    required this.categoryKey,
    required this.amount,
    required this.day,
    required this.createdAt,
    this.note = '',
  });

  final int? id;
  final TxnType type;
  final String categoryKey;
  final double amount;

  /// 记账日期，格式 yyyy-MM-dd
  final String day;
  final int createdAt;
  final String note;

  TxnCategory get category => categoryOf(categoryKey);

  DateTime get dayDate => DateTime.parse(day);

  Txn copyWith({double? amount, String? day, String? note}) => Txn(
    id: id,
    type: type,
    categoryKey: categoryKey,
    amount: amount ?? this.amount,
    day: day ?? this.day,
    createdAt: createdAt,
    note: note ?? this.note,
  );
}

/// yyyy-MM-dd
String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String formatMoney(double v) => v.toStringAsFixed(2);
