import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/stats.dart';
import '../models/txn.dart';

/// 渐变亮端：向白提亮
Color _lift(Color color) => Color.lerp(color, Colors.white, 0.32)!;

/// 渐变暗端：略微压深，让色块有层次而不发灰
Color _sink(Color color) => Color.lerp(color, Colors.black, 0.10)!;

/// 柱子上浅下深的竖向渐变
LinearGradient _rodGradient(Color base) => LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [_lift(base), base],
);

/// 收支概览卡片
class SummaryCards extends StatelessWidget {
  const SummaryCards({super.key, required this.summary, this.subtitle});

  final Summary summary;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                _cell(context, l10n.expense, summary.expense, kExpense),
                _divider(context),
                _cell(context, l10n.income, summary.income, kIncome),
                _divider(context),
                _cell(
                  context,
                  l10n.balance,
                  summary.balance,
                  summary.balance >= 0
                      ? kBalancePositive
                      : kBalanceNegative,
                ),
              ],
            ),
          ),
        ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              l10n.summarySubtitle(subtitle!, summary.count),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }

  Widget _divider(BuildContext context) => Container(
    width: 1,
    height: 34,
    color: Theme.of(context).dividerColor,
  );

  Widget _cell(BuildContext context, String label, double value, Color color) =>
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            Text(
              formatMoney(value),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
}

/// 分类占比饼图 + 图例
class CategoryPieCard extends StatelessWidget {
  const CategoryPieCard({super.key, required this.title, required this.slices});

  final String title;
  final List<CategorySlice> slices;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final total = slices.fold<double>(0, (a, s) => a + s.amount);
    return _Card(
      title: title,
      child: slices.isEmpty || total <= 0
          ? const _Empty()
          : Column(
              children: [
                SizedBox(
                  height: 190,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 42,
                      sections: [
                        for (final s in slices)
                          PieChartSectionData(
                            value: s.amount,
                            color: s.category.color,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                _lift(s.category.color),
                                _sink(s.category.color),
                              ],
                            ),
                            radius: 58,
                            title: (s.amount / total * 100).toStringAsFixed(0),
                            titleStyle: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                for (final s in slices)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: s.category.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(l10n.categoryLabel(s.category.key)),
                        const Spacer(),
                        Text(
                          formatMoney(s.amount),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        SizedBox(
                          width: 52,
                          child: Text(
                            '${(s.amount / total * 100).toStringAsFixed(1)}%',
                            textAlign: TextAlign.right,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

/// 趋势柱状图：支出/收入并排
class TrendBarCard extends StatelessWidget {
  const TrendBarCard({
    super.key,
    required this.title,
    required this.points,
    required this.byDay,
    this.showIncome = true,
  });

  final String title;
  final List<TrendPoint> points;

  /// 横轴按日还是按月，只影响气泡提示里的单位。
  final bool byDay;
  final bool showIncome;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final labelStep = points.length > 16 ? 5 : 1;
    double maxValue(TrendPoint p) =>
        showIncome ? (p.expense > p.income ? p.expense : p.income) : p.expense;
    final maxV = points.fold<double>(0, (a, p) {
      final v = maxValue(p);
      return v > a ? v : a;
    });
    final hasData = maxV > 0;
    return _Card(
      title: title,
      child: SizedBox(
        height: 220,
        child: !hasData
            ? const _Empty()
            : BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxV * 1.15,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) =>
                          Theme.of(context).colorScheme.inverseSurface,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                          BarTooltipItem(
                            l10n.tooltipLine(
                              l10n.chartTick((group.x + 1).round(), byDay: byDay),
                              rodIndex == 0 ? l10n.expense : l10n.income,
                              rod.toY.toStringAsFixed(2),
                            ),
                            const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                    ),
                  ),
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    horizontalInterval: maxV / 4,
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 44,
                        getTitlesWidget: (v, _) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Text(
                            l10n.compactAmount(v),
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        // 数据点很多时隔级显示，避免标签重叠
                        interval: labelStep.toDouble(),
                        getTitlesWidget: (v, _) {
                          final i = v.round();
                          if (i != v || i % labelStep != 0) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              points[i.clamp(0, points.length - 1)].label,
                              style: const TextStyle(fontSize: 11),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < points.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: points[i].expense,
                            gradient: _rodGradient(kExpense),
                            width: points.length > 16 ? 4 : 9,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                          if (showIncome)
                            BarChartRodData(
                              toY: points[i].income,
                              gradient: _rodGradient(kIncome),
                              width: points.length > 16 ? 4 : 9,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

/// 支出/收入图例说明
class LegendRow extends StatelessWidget {
  const LegendRow({super.key, this.showIncome = true});

  final bool showIncome;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _dot(context, kExpense, l10n.expense),
        if (showIncome) ...[
          const SizedBox(width: 16),
          _dot(context, kIncome, l10n.income),
        ],
      ],
    );
  }

  Widget _dot(BuildContext context, Color color, String label) => Row(
    children: [
      Container(
        width: 10,
        height: 10,
        color: color,
      ),
      const SizedBox(width: 6),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: Center(
        child: Text(
          AppLocalizations.of(context).chartEmpty,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}
