import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 界面语言（简体中文 / English），选择记在本地，下次启动仍生效。默认中文。
class LocaleController extends ChangeNotifier {
  LocaleController._(this._prefs, this._code);

  /// 不接本地存储时使用，固定中文（预览、测试用）。
  LocaleController.defaults() : _prefs = null, _code = defaultCode;

  static const _key = 'ui.locale';
  static const defaultCode = 'zh';
  static const supportedCodes = ['zh', 'en'];

  static Future<LocaleController> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    return LocaleController._(
      prefs,
      supportedCodes.contains(stored) ? stored! : defaultCode,
    );
  }

  final SharedPreferences? _prefs;
  String _code;

  String get code => _code;

  Locale get locale => Locale(_code);

  Future<void> setCode(String code) async {
    if (_code == code || !supportedCodes.contains(code)) return;
    _code = code;
    notifyListeners();
    await _prefs?.setString(_key, code);
  }
}
