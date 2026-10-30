import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_front/app_theme.dart';

/// 主题里所有「由 Material 组件用 DefaultTextStyle 替换外层样式」的文本样式。
///
/// 这类样式不会和外层默认样式合并，漏写 fontFamily 就会丢掉 ThemeData.fontFamily，
/// 中文退到引擎默认字体（无中文字形）渲染成豆腐块。
Iterable<TextStyle?> _componentTextStyles(ThemeData theme) sync* {
  yield theme.appBarTheme.titleTextStyle;
  yield theme.appBarTheme.toolbarTextStyle;
  yield theme.snackBarTheme.contentTextStyle;
  yield theme.navigationBarTheme.labelTextStyle?.resolve(const {});
  yield theme.dialogTheme.titleTextStyle;
  yield theme.dialogTheme.contentTextStyle;
  yield theme.chipTheme.labelStyle;
  yield theme.inputDecorationTheme.labelStyle;
  yield theme.floatingActionButtonTheme.extendedTextStyle;
}

void main() {
  final themes = <String, ThemeData>{
    '浅色': buildAppTheme(),
    '深色': buildDarkAppTheme(),
  };

  group('中文字体族', () {
    test('textTheme 带全局字族', () {
      themes.forEach((name, theme) {
        expect(theme.textTheme.bodyMedium?.fontFamily, kFontFamily, reason: name);
        expect(theme.textTheme.titleLarge?.fontFamily, kFontFamily, reason: name);
        expect(theme.textTheme.labelLarge?.fontFamily, kFontFamily, reason: name);
      });
    });

    test('组件主题里手写的文本样式都带字族', () {
      themes.forEach((name, theme) {
        for (final style in _componentTextStyles(theme)) {
          if (style == null) continue;
          expect(
            style.fontFamily,
            kFontFamily,
            reason: '$name 的组件样式漏了 fontFamily，中文会变豆腐块',
          );
        }
      });
    });

    testWidgets('AppBar 标题渲染时拿得到字族', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(appBar: AppBar(title: const Text('我的账本'))),
        ),
      );
      final context = tester.element(find.text('我的账本'));
      expect(DefaultTextStyle.of(context).style.fontFamily, kFontFamily);
    });

    testWidgets('SnackBar 内容渲染时拿得到字族', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已记录 支出 12.00')),
                ),
                child: const Text('触发'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('触发'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final context = tester.element(find.text('已记录 支出 12.00'));
      expect(DefaultTextStyle.of(context).style.fontFamily, kFontFamily);

      // 让 SnackBar 自动消失，别把定时器留给测试框架。
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('普通 Text 仍能从外层拿到字族', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(body: Text('流水')),
        ),
      );
      final context = tester.element(find.text('流水'));
      expect(DefaultTextStyle.of(context).style.fontFamily, kFontFamily);
    });
  });
}
