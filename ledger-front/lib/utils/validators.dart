/// 表单校验规则。后端 `RegisterRequest` / `UpdateProfileRequest` 用同一套约束，
/// 改这里记得同步改那边，否则前端放行、后端 400。
library;

final RegExp emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// 中国大陆手机号，选填时先判 isEmpty 再校验。
final RegExp cnMobilePattern = RegExp(r'^1[3-9]\d{9}$');
