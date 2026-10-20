import 'package:flutter/material.dart';
import 'package:ledger_front/state/theme_mode_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('默认跟随系统', () {
    expect(ThemeModeController.defaults().mode, ThemeMode.system);
  });

  test('restore 读回上次选择', () async {
    SharedPreferences.setMockInitialValues({'ui.themeMode': 'dark'});
    expect((await ThemeModeController.restore()).mode, ThemeMode.dark);

    SharedPreferences.setMockInitialValues({'ui.themeMode': '不认识的值为啥'});
    expect((await ThemeModeController.restore()).mode, ThemeMode.system);
  });

  test('setMode 持久化并通知，重复设置不重复通知', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = await ThemeModeController.restore();
    var notifications = 0;
    controller.addListener(() => notifications++);

    await controller.setMode(ThemeMode.light);

    expect(controller.mode, ThemeMode.light);
    expect(notifications, 1);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('ui.themeMode'), 'light');

    await controller.setMode(ThemeMode.light);
    expect(notifications, 1);
  });
}
