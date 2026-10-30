import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// 执行一次后端写操作，失败时用 SnackBar 反馈（网络错误、分类校验等）。
Future<void> runGuarded(
  BuildContext context,
  Future<void> Function() action, {
  String? failure,
}) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  try {
    await action();
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          l10n.guardedFailure(
            failure ?? l10n.operationFailed,
            l10n.errorText(e),
          ),
        ),
      ),
    );
  }
}
