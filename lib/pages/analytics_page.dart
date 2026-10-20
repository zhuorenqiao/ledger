import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/stats.dart';
import '../models/txn.dart';
import '../state/ledger_store.dart';
import '../widgets/charts.dart';

const _segmentLabelStyle = TextStyle(fontSize: 13, fontWeight: FontWeight.w600);

/// 月度对比条的标签：后端 label 通常是「1」~「12」的月份数字，能解析就本地化成
/// 「N月 / Mon」；万一格式变了解析不出来，直接展示原始 label，而不是错误地兜底成 1 月。
String _monthBarLabel(AppLocalizations l10n, String raw) {
  final month = int.tryParse(raw);
  return month == null ? raw : l10n.monthLabel(month);
}

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key, required this.store, required this.onAdd});

  final LedgerStore store;
  final VoidCallback onAdd;

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  int _tab = 0;
  DateTime _day = DateTime.now();
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  late int _year = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        Container(
          color: theme.scaffoldBackgroundColor,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: SegmentedButton<int>(
              expandedInsets: EdgeInsets.zero,
              segments: [
                ButtonSegment(
                  value: 0,
                  label: Text(
                    l10n.segDaily,
                    maxLines: 1,
                    softWrap: false,
                    style: _segmentLabelStyle,
                  ),
                  icon: const Icon(Icons.ac_unit, size: 18),
                ),
                ButtonSegment(
                  value: 1,
                  label: Text(
                    l10n.segMonthly,
                    maxLines: 1,
                    softWrap: false,
                    style: _segmentLabelStyle,
                  ),
                  icon: const Icon(Icons.calendar_month, size: 18),
                ),
                ButtonSegment(
                  value: 2,
                  label: Text(
                    l10n.segYearly,
                    maxLines: 1,
                    softWrap: false,
                    style: _segmentLabelStyle,
                  ),
                  icon: const Icon(Icons.calendar_today, size: 18),
                ),
              ],
              selected: {_tab},
              onSelectionChanged: (s) => setState(() => _tab = s.first),
              showSelectedIcon: false,
            ),
          ),
        ),
        Expanded(
          child: ListenableBuilder(
            listenable: widget.store,
            builder: (context, _) {
              final revision = widget.store.revision;
              switch (_tab) {
                case 1:
                  return _MonthlyView(
                    store: widget.store,
                    revision: revision,
                    month: _month,
                    onMonthChanged: (m) => setState(() => _month = m),
                  );
                case 2:
                  return _YearlyView(
                    store: widget.store,
                    revision: revision,
                    year: _year,
                    onYearChanged: (y) => setState(() => _year = y),
                  );
                default:
                  return _DailyView(
                    store: widget.store,
                    revision: revision,
                    day: _day,
                    onDayChanged: (d) => setState(() => _day = d),
                    onAdd: widget.onAdd,
                  );
              }
            },
          ),
        ),
      ],
    );
  }
}

class _RangePickerBar extends StatelessWidget {
  const _RangePickerBar({
    required this.label,
    required this.onPrev,
    required this.onNext,
    required this.onPick,
    required this.isMaxReached,
  });

  final String label;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onPick;
  final bool isMaxReached;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(onPressed: onPrev, icon: const Icon(Icons.chevron_left)),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: TextButton.icon(
              onPressed: onPick,
              icon: const Icon(Icons.tune, size: 16),
              label: Text(label, style: const TextStyle(fontSize: 17)),
            ),
          ),
        ),
        IconButton(
          onPressed: isMaxReached ? null : onNext,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _DailyView extends StatefulWidget {
  const _DailyView({
    required this.store,
    required this.revision,
    required this.day,
    required this.onDayChanged,
    required this.onAdd,
  });

  final LedgerStore store;
  final int revision;
  final DateTime day;
  final ValueChanged<DateTime> onDayChanged;
  final VoidCallback onAdd;

  @override
  State<_DailyView> createState() => _DailyViewState();
}

class _DailyViewState extends State<_DailyView> {
  Summary _summary = Summary.empty;
  List<Txn> _txns = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_DailyView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.day != oldWidget.day || widget.revision != oldWidget.revision) _load();
  }

  Future<void> _load() async {
    final day = widget.day;
    final summaryFuture = widget.store.summaryOfDay(day);
    final txnsFuture = widget.store.txnsOfDay(day);
    final result = (await summaryFuture, await txnsFuture);
    if (!mounted || day != widget.day) return;
    setState(() {
      _summary = result.$1;
      _txns = result.$2;
    });
  }

  Future<void> _pick(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.day,
      firstDate: DateTime(2015),
      lastDate: DateTime.now(),
    );
    if (picked != null) widget.onDayChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final today = dayKey(DateTime.now());
    final day = widget.day;
    final txns = _txns;
    final summary = _summary;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
      children: [
        _RangePickerBar(
          label: l10n.formatDayWithWeekday(day),
          onPrev: () => widget.onDayChanged(day.subtract(const Duration(days: 1))),
          onNext: () {
            final next = day.add(const Duration(days: 1));
            if (dayKey(next).compareTo(today) <= 0) widget.onDayChanged(next);
          },
          onPick: () => _pick(context),
          isMaxReached: dayKey(day).compareTo(today) >= 0,
        ),
        const SizedBox(height: 8),
        SummaryCards(summary: summary, subtitle: l10n.formatDay(day)),
        const SizedBox(height: 12),
        CategoryPieCard(title: l10n.dailyExpensePie, slices: summary.expenseByCategory),
        const SizedBox(height: 12),
        if (summary.incomeByCategory.isNotEmpty) ...[
          CategoryPieCard(title: l10n.dailyIncomePie, slices: summary.incomeByCategory),
          const SizedBox(height: 12),
        ],
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.dailyFlow, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (txns.isEmpty)
                  TextButton(
                    onPressed: widget.onAdd,
                    child: Text(l10n.dailyEmptyCta),
                  )
                else
                  for (final t in txns) _TxnRow(txn: t),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MonthlyView extends StatefulWidget {
  const _MonthlyView({
    required this.store,
    required this.revision,
    required this.month,
    required this.onMonthChanged,
  });

  final LedgerStore store;
  final int revision;
  final DateTime month;
  final ValueChanged<DateTime> onMonthChanged;

  @override
  State<_MonthlyView> createState() => _MonthlyViewState();
}

class _MonthlyViewState extends State<_MonthlyView> {
  Summary _summary = Summary.empty;
  List<TrendPoint> _trend = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_MonthlyView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.month != oldWidget.month || widget.revision != oldWidget.revision) _load();
  }

  Future<void> _load() async {
    final month = widget.month;
    final summaryFuture = widget.store.summaryOfMonth(month.year, month.month);
    final trendFuture = widget.store.dailyTrend(month.year, month.month);
    final result = (await summaryFuture, await trendFuture);
    if (!mounted || month != widget.month) return;
    setState(() {
      _summary = result.$1;
      _trend = result.$2;
    });
  }

  Future<void> _pick(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.month,
      firstDate: DateTime(2015),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      widget.onMonthChanged(DateTime(picked.year, picked.month));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final nowMonth = DateTime(DateTime.now().year, DateTime.now().month);
    final month = widget.month;
    final summary = _summary;
    final busiest = _trend.fold<TrendPoint?>(
      null,
      (best, p) => best == null || p.expense > best.expense ? p : best,
    );
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
      children: [
        _RangePickerBar(
          label: l10n.formatMonth(month),
          onPrev: () => widget.onMonthChanged(DateTime(month.year, month.month - 1)),
          onNext: () => widget.onMonthChanged(DateTime(month.year, month.month + 1)),
          onPick: () => _pick(context),
          isMaxReached: !month.isBefore(nowMonth),
        ),
        const SizedBox(height: 8),
        SummaryCards(
          summary: summary,
          subtitle: l10n.avgPerDay(formatMoney(summary.expense / daysInMonth)),
        ),
        const SizedBox(height: 12),
        TrendBarCard(
          title: l10n.dailyTrendTitle,
          points: _trend,
          byDay: true,
          showIncome: false,
        ),
        const SizedBox(height: 8),
        const LegendRow(showIncome: false),
        const SizedBox(height: 12),
        CategoryPieCard(title: l10n.monthExpensePie, slices: summary.expenseByCategory),
        const SizedBox(height: 12),
        if (summary.incomeByCategory.isNotEmpty) ...[
          CategoryPieCard(title: l10n.monthIncomePie, slices: summary.incomeByCategory),
          const SizedBox(height: 12),
        ],
        if (busiest != null && busiest.expense > 0)
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.local_fire_department),
              title: Text(l10n.busiestDayTitle),
              subtitle: Text(l10n.monthWithDay(month.month, busiest.label)),
              trailing: Text(
                formatMoney(busiest.expense),
                style: const TextStyle(
                  color: kExpense,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _YearlyView extends StatefulWidget {
  const _YearlyView({
    required this.store,
    required this.revision,
    required this.year,
    required this.onYearChanged,
  });

  final LedgerStore store;
  final int revision;
  final int year;
  final ValueChanged<int> onYearChanged;

  @override
  State<_YearlyView> createState() => _YearlyViewState();
}

class _YearlyViewState extends State<_YearlyView> {
  Summary _summary = Summary.empty;
  List<TrendPoint> _trend = const [];
  List<int> _years = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_YearlyView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.year != oldWidget.year || widget.revision != oldWidget.revision) _load();
  }

  Future<void> _load() async {
    final year = widget.year;
    final summaryFuture = widget.store.summaryOfYear(year);
    final trendFuture = widget.store.monthlyTrend(year);
    final yearsFuture = widget.store.years();
    final result = (await summaryFuture, await trendFuture, await yearsFuture);
    if (!mounted || year != widget.year) return;
    setState(() {
      _summary = result.$1;
      _trend = result.$2;
      _years = result.$3;
    });
  }

  Future<void> _pick(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final picked = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.yearPickerTitle),
        children: [
          for (final y in _years)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, y),
              child: Text(l10n.yearLabel(y)),
            ),
        ],
      ),
    );
    if (picked != null) widget.onYearChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final year = widget.year;
    final summary = _summary;
    final peak = _trend.fold<TrendPoint?>(
      null,
      (best, p) => best == null || p.expense > best.expense ? p : best,
    );
    final thisYear = DateTime.now().year;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
      children: [
        _RangePickerBar(
          label: l10n.yearLabel(year),
          onPrev: () => widget.onYearChanged(year - 1),
          onNext: () => widget.onYearChanged(year + 1),
          isMaxReached: year >= thisYear,
          onPick: () => _pick(context),
        ),
        const SizedBox(height: 8),
        SummaryCards(
          summary: summary,
          subtitle: l10n.avgPerMonth(formatMoney(summary.expense / 12)),
        ),
        const SizedBox(height: 12),
        TrendBarCard(
          title: l10n.monthlyTrendTitle,
          points: _trend,
          byDay: false,
        ),
        const SizedBox(height: 8),
        const LegendRow(),
        const SizedBox(height: 12),
        CategoryPieCard(title: l10n.yearExpensePie, slices: summary.expenseByCategory),
        const SizedBox(height: 12),
        if (summary.incomeByCategory.isNotEmpty) ...[
          CategoryPieCard(title: l10n.yearIncomePie, slices: summary.incomeByCategory),
          const SizedBox(height: 12),
        ],
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                child: Text(
                  l10n.monthComparison,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              for (final p in _trend)
                if (p.expense > 0)
                  _MonthBar(
                    label: _monthBarLabel(l10n, p.label),
                    amount: p.expense,
                    maxAmount: peak?.expense ?? 1,
                  ),
              if (_trend.every((p) => p.expense == 0))
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(l10n.yearNoExpense),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MonthBar extends StatelessWidget {
  const _MonthBar({
    required this.label,
    required this.amount,
    required this.maxAmount,
  });

  final String label;
  final double amount;
  final double maxAmount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 40, child: Text(label)),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: maxAmount <= 0 ? 0 : amount / maxAmount,
                minHeight: 10,
                color: kExpense,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(
              formatMoney(amount),
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _TxnRow extends StatelessWidget {
  const _TxnRow({required this.txn});

  final Txn txn;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cat = txn.category;
    final isExpense = txn.type == TxnType.expense;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: cat.color.withValues(alpha: 0.18),
        child: Icon(cat.icon, size: 18, color: cat.color),
      ),
      title: Text(
        l10n.categoryLabel(txn.categoryKey) +
            (txn.note.isEmpty ? '' : ' · ${txn.note}'),
      ),
      subtitle: Text(
        DateTime.fromMillisecondsSinceEpoch(txn.createdAt).toString().substring(11, 16),
      ),
      trailing: Text(
        '${isExpense ? '-' : '+'}${formatMoney(txn.amount)}',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: isExpense ? kExpense : kIncome,
        ),
      ),
    );
  }
}
