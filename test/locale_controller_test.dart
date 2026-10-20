import 'package:flutter/widgets.dart';
import 'package:ledger_front/state/locale_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('默认简体中文', () {
    expect(LocaleController.defaults().code, 'zh');
    expect(LocaleController.defaults().locale, const Locale('zh'));
  });

  test('restore 读回上次选择，陌生值退回中文', () async {
    SharedPreferences.setMockInitialValues({'ui.locale': 'en'});
    expect((await LocaleController.restore()).code, 'en');

    SharedPreferences.setMockInitialValues({'ui.locale': 'fr'});
    expect((await LocaleController.restore()).code, 'zh');
  });

  test('setCode 持久化并通知，重复或非法值不通知', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = await LocaleController.restore();
    var notifications = 0;
    controller.addListener(() => notifications++);

    await controller.setCode('en');
    expect(controller.code, 'en');
    expect(notifications, 1);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('ui.locale'), 'en');

    await controller.setCode('en');
    await controller.setCode('de');
    expect(notifications, 1);
  });
}
