import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../models/txn.dart';
import '../state/ledger_store.dart';

class AddTxnPage extends StatefulWidget {
  const AddTxnPage({super.key, required this.store});

  final LedgerStore store;

  @override
  State<AddTxnPage> createState() => _AddTxnPageState();
}

class _AddTxnPageState extends State<AddTxnPage> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  TxnType _type = TxnType.expense;
  String _categoryKey = kExpenseCategories.first.key;
  DateTime _day = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _switchType(TxnType type) {
    setState(() {
      _type = type;
      _categoryKey = categoriesOf(type).first.key;
    });
  }

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2015),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _day = picked);
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.amountInvalid)));
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.store.add(
        Txn(
          type: _type,
          categoryKey: _categoryKey,
          amount: double.parse(amount.toStringAsFixed(2)),
          day: dayKey(_day),
          createdAt: DateTime.now().millisecondsSinceEpoch,
          note: _noteCtrl.text.trim(),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.saveFailed(l10n.errorText(e)))),
      );
      return;
    }
    if (!mounted) return;
    Navigator.pop(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          l10n.savedToast(
            _type == TxnType.expense ? l10n.expense : l10n.income,
            formatMoney(amount),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cats = categoriesOf(_type);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.addEntry)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<TxnType>(
            segments: [
              ButtonSegment(
                value: TxnType.expense,
                label: Text(l10n.expense),
                icon: const Icon(Icons.arrow_upward),
              ),
              ButtonSegment(
                value: TxnType.income,
                label: Text(l10n.income),
                icon: const Icon(Icons.arrow_downward),
              ),
            ],
            selected: {_type},
            onSelectionChanged: (s) => _switchType(s.first),
            showSelectedIcon: false,
          ),
          const SizedBox(height: 20),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TextField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                autofocus: true,
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  prefixText: '¥ ',
                  hintText: '0.00',
                  hintStyle: TextStyle(color: Color(0xFFBCC5DE)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(l10n.categoryField, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final c in cats)
                _CategoryChip(
                  category: c,
                  label: l10n.categoryLabel(c.key),
                  selected: c.key == _categoryKey,
                  // 英文分类名比中文长，粗体选中态可能顶到 68px 芯片边；中文一律两字，
                  // 保持 maxLines/overflow 为 null（默认值）以维持既有像素不变。
                  singleLine: l10n.locale.languageCode == 'en',
                  onTap: () => setState(() => _categoryKey = c.key),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.event),
                  title: Text(l10n.dateField),
                  trailing: Text(l10n.formatDay(_day)),
                  onTap: _pickDay,
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: TextField(
                    controller: _noteCtrl,
                    decoration: InputDecoration(
                      icon: const Icon(Icons.edit_note),
                      border: InputBorder.none,
                      hintText: l10n.noteHint,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text(_saving ? l10n.saving : l10n.save),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.category,
    required this.label,
    required this.selected,
    required this.onTap,
    this.singleLine = false,
  });

  final TxnCategory category;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// 为 true 时把文字限制成一行并省略号截断，避免英文长词溢出撑高芯片。
  /// 为 false（中文）时 maxLines/overflow 都留 null，与默认渲染完全一致。
  final bool singleLine;

  @override
  Widget build(BuildContext context) {
    final color = selected ? category.color : Theme.of(context).colorScheme.outlineVariant;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 68,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? category.color.withValues(alpha: 0.12) : null,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: selected ? 1.6 : 1),
        ),
        child: Column(
          children: [
            Icon(category.icon, color: selected ? category.color : null),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: singleLine ? 1 : null,
              overflow: singleLine ? TextOverflow.ellipsis : null,
              style: TextStyle(
                fontSize: 12,
                color: selected ? category.color : null,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
