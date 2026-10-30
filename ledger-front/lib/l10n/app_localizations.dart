import 'package:flutter/material.dart';

import '../data/api_client.dart';

/// 中英双语词条。每个词条一个成员，两种语言写在同一行里：新增词条不会漏掉某一种
/// 语言，也不存在查表 key 打错这种运行时问题。默认语言是中文。
class AppLocalizations {
  AppLocalizations(this.locale) : _zh = locale.languageCode != 'en';

  final Locale locale;
  final bool _zh;

  static const supportedLocales = [Locale('zh'), Locale('en')];

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// 未挂 delegate 时退回中文，方便单页 widget 测试直接 MaterialApp 包一层。
  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations) ??
      AppLocalizations(const Locale('zh'));

  // ---------- 通用 ----------
  String get appTitle => _zh ? '记账本' : 'Ledger';
  String get save => _zh ? '保存' : 'Save';
  String get saving => _zh ? '保存中…' : 'Saving…';
  String get cancel => _zh ? '取消' : 'Cancel';
  String get delete => _zh ? '删除' : 'Delete';
  String get submit => _zh ? '提交' : 'Submit';
  String get optional => _zh ? '可留空' : 'Optional';
  String get expense => _zh ? '支出' : 'Expense';
  String get income => _zh ? '收入' : 'Income';
  String get balance => _zh ? '结余' : 'Balance';

  String joinList(List<String> items) => items.join(_zh ? '、' : ', ');

  // ---------- 首页骨架与菜单 ----------
  String get navRecords => _zh ? '流水' : 'Records';
  String get navAnalytics => _zh ? '报表' : 'Reports';
  String get homeTitle => _zh ? '我的账本' : 'My Ledger';
  String get analyticsTitle => _zh ? '收支报表' : 'Reports';
  String get addEntry => _zh ? '记一笔' : 'Add entry';
  String get menuProfile => _zh ? '个人中心' : 'Profile';
  String get menuSeed => _zh ? '载入示例数据' : 'Load sample data';
  String get menuClear => _zh ? '清空账单' : 'Clear all entries';
  String get menuFeedback => _zh ? '意见反馈' : 'Feedback';
  String menuTheme(String mode) => _zh ? '切换主题（$mode）' : 'Theme ($mode)';
  String menuLanguage(String name) => _zh ? '切换语言（$name）' : 'Language ($name)';
  String menuSignOut(String name) => _zh ? '退出登录（$name）' : 'Sign out ($name)';

  String get themeDialogTitle => _zh ? '切换主题' : 'Choose theme';
  String get themeSystem => _zh ? '跟随系统' : 'System';
  String get themeLight => _zh ? '浅色' : 'Light';
  String get themeDark => _zh ? '深色' : 'Dark';
  String themeModeName(ThemeMode mode) => switch (mode) {
    ThemeMode.system => themeSystem,
    ThemeMode.light => themeLight,
    ThemeMode.dark => themeDark,
  };

  /// 语言名一律用本语言书写，这是语言选择器的通行做法，不随界面语言翻译。
  String languageName(String code) => code == 'en' ? 'English' : '简体中文';
  String get languageDialogTitle => _zh ? '切换语言' : 'Choose language';

  String get clearDialogTitle => _zh ? '清空所有账单？' : 'Clear every entry?';
  String get clearDialogBody => _zh
      ? '服务器上的全部账单记录会被删除，此操作不可撤销。'
      : 'Every entry stored on the server will be deleted. This cannot be undone.';
  String get clear => _zh ? '清空' : 'Clear';

  // ---------- 流水页 ----------
  String get deleteTxnTitle => _zh ? '删除这笔记录？' : 'Delete this entry?';
  String get deleteFailed => _zh ? '删除失败' : 'Delete failed';
  String loadTxnsFailed(String error) =>
      _zh ? '读取服务器账单失败：$error' : 'Could not load entries: $error';
  String dayTotals(String expense, String income) =>
      _zh ? '支出 $expense   收入 $income' : 'Spent $expense   In $income';
  String loadMoreFailed(String error) => _zh
      ? '加载失败，点击重试：$error'
      : 'Failed to load, tap to retry: $error';
  String get endOfList => _zh ? '已经到底了' : 'That’s everything';
  String get emptyTitle => _zh ? '还没有任何账单' : 'No entries yet';
  String get emptySeedCta => _zh ? '载入示例数据，体验图表' : 'Load sample data to explore charts';

  // ---------- 记一笔 ----------
  String get amountInvalid => _zh ? '请输入大于 0 的金额' : 'Enter an amount greater than 0';
  String saveFailed(String error) => _zh ? '保存失败：$error' : 'Save failed: $error';
  String savedToast(String kind, String amount) =>
      _zh ? '已记录 $kind $amount' : 'Saved $kind $amount';
  String get categoryField => _zh ? '分类' : 'Category';
  String get dateField => _zh ? '日期' : 'Date';
  String get noteHint => _zh ? '备注（可选）' : 'Note (optional)';

  // ---------- 登录 / 注册 ----------
  String get loginSubtitle => _zh ? '使用已有账号查看服务器上的账本' : 'Sign in to open the ledger on your server';
  String get registerSubtitle => _zh ? '注册后账单保存在服务器 MySQL' : 'Register and entries are stored in server MySQL';
  String get serverUrlField => _zh ? '服务器地址' : 'Server URL';
  String get usernameField => _zh ? '用户名' : 'Username';
  String get passwordField => _zh ? '密码' : 'Password';
  String get nicknameOptional => _zh ? '昵称（可选）' : 'Nickname (optional)';
  String get phoneOptional => _zh ? '手机号（可选）' : 'Mobile (optional)';
  String get emailOptional => _zh ? '邮箱（可选）' : 'Email (optional)';
  String get cnMobileHint => _zh ? '中国大陆 11 位' : '11-digit mainland China number';
  String get credentialsRequired => _zh ? '请填写用户名和密码' : 'Username and password are required';
  String get loginCta => _zh ? '登录' : 'Sign in';
  String get registerCta => _zh ? '注册并登录' : 'Register & sign in';
  String get toRegister => _zh ? '还没有账号？去注册' : 'No account yet? Register';
  String get toLogin => _zh ? '已有账号，去登录' : 'Have an account? Sign in';

  // ---------- 个人中心 ----------
  String get profileTitle => _zh ? '个人中心' : 'Profile';
  String get nicknameRequired => _zh ? '显示名称不能为空' : 'Display name is required';
  String get nicknameTooLong => _zh ? '显示名称最多 32 个字符' : 'Display name may not exceed 32 characters';
  String get emailTooLong => _zh ? '邮箱最多 255 个字符' : 'Email may not exceed 255 characters';
  String get emailInvalid => _zh ? '邮箱格式不正确' : 'Invalid email format';
  String get emailInvalidOrBlank =>
      _zh ? '邮箱格式不正确，或者留空' : 'Invalid email format, or leave it blank';
  String get mobileInvalid =>
      _zh ? '手机号要填 11 位中国大陆号码，或者留空' : 'Mobile must be an 11-digit mainland China number, or blank';
  String get profileSaved => _zh ? '资料已更新' : 'Profile updated';
  String get avatarTooBig => _zh ? '图片超过 2MB，换一张小一点的' : 'Image is over 2MB — pick a smaller one';
  String get avatarUpdated => _zh ? '头像已更新' : 'Avatar updated';
  String get avatarTooltip => _zh ? '点击更换头像' : 'Tap to change avatar';
  String accountReadonly(String username) =>
      _zh ? '登录账号 $username，不可修改' : 'Signed in as $username (read-only)';
  String get profileSection => _zh ? '资料设置' : 'Profile settings';
  String get displayNameField => _zh ? '显示名称' : 'Display name';
  String get displayNameHint => _zh ? '账单与菜单里展示的名字' : 'Shown on entries and menus';
  String get phoneField => _zh ? '手机号' : 'Mobile';
  String get phoneHint => _zh ? '中国大陆 11 位，可留空' : '11-digit mainland China number, optional';
  String get emailField => _zh ? '邮箱' : 'Email';

  // ---------- 意见反馈 ----------
  String get feedbackTitle => _zh ? '意见反馈' : 'Feedback';
  String get feedbackHeading => _zh ? '说点什么' : 'Tell us something';
  String get feedbackIntro => _zh
      ? '用着别扭的地方、想要的功能，都可以写在这里。'
      : 'Anything that feels awkward, or a feature you want — write it here.';
  String get feedbackHint => _zh
      ? '例如：希望报表页能把每月数据导出成 CSV'
      : 'e.g. Let the reports page export monthly data to CSV';
  String get imagesField => _zh ? '图片（选填）' : 'Images (optional)';
  String imagesLimit(int max) =>
      _zh ? '最多 $max 张，单张 2MB 以内' : 'Up to $max images, 2MB each';
  String get removeImage => _zh ? '移除这张图片' : 'Remove this image';
  String get pickImage => _zh ? '选择图片' : 'Pick an image';
  String get addImage => _zh ? '添加图片' : 'Add image';
  String imagesRejected(String list) =>
      _zh ? '这几张图没能添加：$list' : 'These images were skipped: $list';
  String imageTooMany(String name, int max) =>
      _zh ? '$name（最多 $max 张）' : '$name (over $max images)';
  String imageTooBig(String name) => _zh ? '$name（超过 2MB）' : '$name (over 2MB)';
  String get feedbackEmpty => _zh ? '写点什么再提交吧' : 'Write something first';
  String get feedbackSubmitted => _zh ? '反馈已提交，谢谢你的建议' : 'Feedback sent — thanks for the tip';

  // ---------- 报表页 ----------
  String get segDaily => _zh ? '每日' : 'Daily';
  String get segMonthly => _zh ? '每月' : 'Monthly';
  String get segYearly => _zh ? '每年' : 'Yearly';
  String get dailyExpensePie => _zh ? '当日支出构成' : 'Spending by category';
  String get dailyIncomePie => _zh ? '当日收入构成' : 'Income by category';
  String get monthExpensePie => _zh ? '本月支出构成' : 'This month by category';
  String get monthIncomePie => _zh ? '本月收入构成' : 'This month income';
  String get yearExpensePie => _zh ? '全年支出构成' : 'This year by category';
  String get yearIncomePie => _zh ? '全年收入构成' : 'This year income';
  String get dailyFlow => _zh ? '当日流水' : 'Entries for the day';
  String get dailyEmptyCta => _zh ? '今天还没有记账，点我去记一笔' : 'Nothing recorded yet — tap to add an entry';
  String avgPerDay(String amount) => _zh ? '日均支出 $amount' : 'Avg per day $amount';
  String avgPerMonth(String amount) => _zh ? '月均支出 $amount' : 'Avg per month $amount';
  String get dailyTrendTitle => _zh ? '每日支出趋势' : 'Daily spending';
  String get monthlyTrendTitle => _zh ? '每月收支趋势' : 'Monthly in & out';
  String get busiestDayTitle => _zh ? '花得最多的一天' : 'Biggest spending day';
  String get yearPickerTitle => _zh ? '选择年份' : 'Pick a year';
  String get monthComparison => _zh ? '月度对比' : 'Month by month';
  String get yearNoExpense => _zh ? '这一年还没有支出记录' : 'No spending recorded this year';

  // ---------- 图表 ----------
  String get chartEmpty => _zh ? '这段时间还没有数据' : 'Nothing recorded for this range';
  String summarySubtitle(String subtitle, int count) => _zh
      ? '$subtitle · $count 笔'
      : '$subtitle · $count entries';
  String chartTick(int index, {required bool byDay}) =>
      _zh ? '$index${byDay ? '日' : '月'}' : '${byDay ? 'Day' : 'Month'} $index';
  String tooltipLine(String label, String kind, String value) =>
      _zh ? '$label  $kind：$value' : '$label · $kind: $value';

  /// 坐标轴刻度：中文大额用「万」，两档语言都在千位以上用 k。
  String compactAmount(double v) {
    if (_zh && v >= 10000) return '${(v / 10000).toStringAsFixed(1)}万';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }

  // ---------- 日期与分类 ----------
  String formatDay(DateTime d) => _zh
      ? '${d.year}年${d.month}月${d.day}日'
      : '${_enMonths[d.month - 1]} ${d.day}, ${d.year}';

  String formatDayWithWeekday(DateTime d) => '${formatDay(d)} ${weekdayLabel(d)}';

  String formatMonth(DateTime d) => _zh
      ? '${d.year}年${d.month}月'
      : '${_enMonths[d.month - 1]} ${d.year}';

  String weekdayLabel(DateTime d) => _zh
      ? const ['周一', '周二', '周三', '周四', '周五', '周六', '周日'][d.weekday - 1]
      : const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d.weekday - 1];

  String monthLabel(int month) =>
      _zh ? '$month月' : _enMonths[month.clamp(1, 12) - 1];

  String monthWithDay(int month, String day) =>
      _zh ? '$month月$day日' : '${_enMonths[month.clamp(1, 12) - 1]} $day';

  String yearLabel(int year) => _zh ? '$year 年' : '$year';

  static const _enMonths = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// 英文名刻意取短：分类芯片固定 68 逻辑像素宽，长词会挤成两行。
  String categoryLabel(String key) => switch (key) {
    'food' => _zh ? '餐饮' : 'Food',
    'transport' => _zh ? '交通' : 'Transport',
    'shopping' => _zh ? '购物' : 'Shopping',
    'housing' => _zh ? '居住' : 'Housing',
    'entertainment' => _zh ? '娱乐' : 'Leisure',
    'medical' => _zh ? '医疗' : 'Medical',
    'study' => _zh ? '学习' : 'Study',
    'beauty' => _zh ? '服饰美容' : 'Apparel',
    'salary' => _zh ? '工资' : 'Salary',
    'bonus' => _zh ? '奖金' : 'Bonus',
    'part_time' => _zh ? '兼职' : 'Part-time',
    'investment' => _zh ? '理财' : 'Investing',
    'other_expense' || 'other_income' => _zh ? '其他' : 'Other',
    _ => _zh ? '其他' : 'Other',
  };

  // ---------- 错误文案 ----------
  String get operationFailed => _zh ? '操作失败' : 'Operation failed';
  String guardedFailure(String failure, String error) =>
      _zh ? '$failure：$error' : '$failure: $error';
  String get networkUnavailable =>
      _zh ? '连不上服务器，请检查后端是否已启动' : 'Can’t reach the server — check that the backend is running';
  String requestFailedHttp(int? status) =>
      _zh ? '请求失败（HTTP $status）' : 'Request failed (HTTP $status)';
  String get requestFailed => _zh ? '请求失败' : 'Request failed';

  /// 后端直接返回的中文业务提示原样展示（前端不猜后端文案）；只有客户端自己造的
  /// 那几条错误才按 [ApiException.kind] 走双语词条。
  String errorText(Object error) {
    if (error is ApiException) {
      return switch (error.kind) {
        'network' => networkUnavailable,
        'http' => requestFailedHttp(error.statusCode),
        'generic' => _genericErrorText(error.message),
        _ => error.message,
      };
    }
    return error.toString();
  }

  /// generic 类错误（证书、URL 解析等）把底层细节拼在本地化前缀后，方便排障；
  /// 当 Dio 没给出细节时 message 已被兜底成中文「请求失败」，此时不再重复拼接。
  String _genericErrorText(String detail) {
    if (detail.isEmpty || detail == '请求失败') return requestFailed;
    return _zh ? '$requestFailed：$detail' : '$requestFailed: $detail';
  }
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales
      .any((l) => l.languageCode == locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async => AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
