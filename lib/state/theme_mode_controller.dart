import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 主题模式（跟随系统 / 浅色 / 深色），选择记在本地，下次启动仍生效。
class ThemeModeController extends ChangeNotifier {
  ThemeModeController._(this._prefs, this._mode);

  /// 不接本地存储时使用，默认跟随系统（预览、测试用）。
  ThemeModeController.defaults() : _prefs = null, _mode = ThemeMode.system;

  static const _key = 'ui.themeMode';

  static Future<ThemeModeController> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    return ThemeModeController._(
      prefs,
      ThemeMode.values.firstWhere((m) => m.name == stored, orElse: () => ThemeMode.system),
    );
  }

  final SharedPreferences? _prefs;
  ThemeMode _mode;

  ThemeMode get mode => _mode;

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    await _prefs?.setString(_key, mode.name);
  }
}
