import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/txn.dart';
import '../state/ledger_store.dart';
import '../utils/run_guarded.dart';

class RecordsPage extends StatefulWidget {
  const RecordsPage({super.key, required this.store});

  final LedgerStore store;

  @override
  State<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  /// 距底部多少像素就预取下一页。
  static const _preloadExtent = 200.0;

  final ScrollController _scroll = ScrollController();

  LedgerStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    if (position.pixels >= position.maxScrollExtent - _preloadExtent) {
      store.loadMore();
    }
  }

  Future<void> _confirmDelete(BuildContext context, Txn txn) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteTxnTitle),
        content: Text(
          '${l10n.categoryLabel(txn.categoryKey)}  ${formatMoney(txn.amount)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await runGuarded(context, () => store.remove(txn), failure: l10n.deleteFailed);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        if (store.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (store.error != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(l10n.loadTxnsFailed(l10n.errorText(store.error!))),
            ),
          );
        }
        final groups = store.dayGroups;
        if (groups.isEmpty) return _buildEmpty(context);

        return ListView.builder(
          controller: _scroll,
          // 数据不足一屏时也允许下拉，否则永远触发不了滚动加载
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 80),
          itemCount: groups.length + 1,
          itemBuilder: (context, i) {
            if (i == groups.length) return _footer(context);
            return _daySection(context, groups[i]);
          },
        );
      },
    );
  }

  Widget _daySection(BuildContext context, DayGroup group) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.formatDayWithWeekday(group.day),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text(
                l10n.dayTotals(formatMoney(group.expense), formatMoney(group.income)),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: [
              for (final t in group.txns)
                Dismissible(
                  key: ValueKey('${t.id}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    color: kExpense,
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  confirmDismiss: (_) async {
                    await _confirmDelete(context, t);
                    return false; // 由对话框决定是否删除
                  },
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: t.category.color.withValues(alpha: 0.18),
                      child: Icon(t.category.icon,
                          size: 18, color: t.category.color),
                    ),
                    title: Text(
                      l10n.categoryLabel(t.categoryKey) +
                          (t.note.isEmpty ? '' : ' · ${t.note}'),
                    ),
                    subtitle: Text(
                      DateTime.fromMillisecondsSinceEpoch(t.createdAt)
                          .toString()
                          .substring(5, 16)
                          .replaceFirst('-', '/'),
                    ),
                    trailing: Text(
                      '${t.type == TxnType.expense ? '-' : '+'}${formatMoney(t.amount)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: t.type == TxnType.expense ? kExpense : kIncome,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _footer(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (store.loadingMore) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (store.moreError != null) {
      return Center(
        child: TextButton(
          onPressed: () => store.loadMore(),
          child: Text(l10n.loadMoreFailed(l10n.errorText(store.moreError!))),
        ),
      );
    }
    if (!store.hasMore) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text(l10n.endOfList, style: const TextStyle(fontSize: 12)),
        ),
      );
    }
    return const SizedBox(height: 24);
  }

  Widget _buildEmpty(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long,
              size: 56,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(l10n.emptyTitle),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: () => runGuarded(context, store.seedDemoData),
              icon: const Icon(Icons.auto_awesome),
              label: Text(l10n.emptySeedCta),
            ),
          ],
        ),
      ),
    );
  }
}
