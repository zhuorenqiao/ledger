import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show ChangeNotifier, kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

import '../data/api_client.dart';

/// 显式传入的后端地址，只在 `--dart-define=API_BASE_URL=...` 时有值
/// （Android 模拟器访问宿主机要用 `http://10.0.2.2:9090`）。
const apiBaseUrlOverride = String.fromEnvironment('API_BASE_URL');

/// 默认后端地址，按平台分三种情况：
/// - 命令行给过 `API_BASE_URL` 就照它来；
/// - Web 上没给时取页面自身的 origin。部署形态是 nginx 同源托管静态产物并反代 `/api`
///   （部署配置见同级后端仓库的 `deploy/docker-compose.preview.yml`），这样换 IP、换域名、
///   换端口都不用重新 build，浏览器也不会触发 CORS 预检；
/// - 其余平台回落到本机 9090，和本地开发时一致。
String get defaultApiBaseUrl {
  if (apiBaseUrlOverride.isNotEmpty) return apiBaseUrlOverride;
  if (kIsWeb) {
    final base = Uri.base;
    if (base.isScheme('http') || base.isScheme('https')) return base.origin;
  }
  return 'http://localhost:9090';
}

class SessionUser {
  const SessionUser(this.id, this.username, this.nickname,
      {this.email = '', this.phone = '', this.hasAvatar = false});

  final int id;
  final String username;
  final String nickname;
  final String email;
  final String phone;
  final bool hasAvatar;

  factory SessionUser.fromJson(Map<String, dynamic> json) =>
      SessionUser(
        (json['id'] as num).toInt(),
        json['username'] as String,
        json['nickname'] as String? ?? '',
        email: json['email'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        hasAvatar: json['hasAvatar'] as bool? ?? false,
      );

  Map<String, Object?> toJson() => {
    'id': id,
    'username': username,
    'nickname': nickname,
    'email': email,
    'phone': phone,
    'hasAvatar': hasAvatar,
  };
}

/// 保存 JWT 与服务器地址，负责注册 / 登录 / 退出。
class AuthSession extends ChangeNotifier {
  AuthSession._(this._prefs, this._baseUrl, this._token, this._user);

  static const _kBaseUrl = 'api.baseUrl';
  static const _kToken = 'auth.token';
  static const _kUser = 'auth.user';

  static Future<AuthSession> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final rawUser = prefs.getString(_kUser);
    return AuthSession._(
      prefs,
      prefs.getString(_kBaseUrl) ?? defaultApiBaseUrl,
      prefs.getString(_kToken),
      rawUser == null
          ? null
          : SessionUser.fromJson(jsonDecode(rawUser) as Map<String, dynamic>),
    );
  }

  final SharedPreferences _prefs;

  String _baseUrl;
  String? _token;
  SessionUser? _user;
  ApiClient? _api;

  /// 只在本次运行内有意义：重启后图片缓存本来就是空的，不需要持久化。
  int _avatarVersion = 0;

  String get baseUrl => _baseUrl;
  SessionUser? get user => _user;
  bool get isSignedIn => _token != null;
  String get displayName => _user?.nickname.isNotEmpty == true ? _user!.nickname : (_user?.username ?? '');

  ApiClient get api => _api ??= ApiClient(
    baseUrl: _baseUrl,
    token: () => _token,
    onUnauthorized: _expireToken,
  );

  Future<void> setBaseUrl(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    _baseUrl = trimmed.endsWith('/') ? trimmed.substring(0, trimmed.length - 1) : trimmed;
    _api?.updateBaseUrl(_baseUrl);
    await _prefs.setString(_kBaseUrl, _baseUrl);
    notifyListeners();
  }

  Future<void> login(String username, String password) =>
      _authenticate('/api/auth/login', {'username': username.trim(), 'password': password});

  Future<void> register({
    required String username,
    required String password,
    required String nickname,
    String email = '',
    String phone = '',
  }) =>
      _authenticate('/api/auth/register', {
        'username': username.trim(),
        'password': password,
        'nickname': nickname.trim(),
        'email': email.trim(),
        'phone': phone.trim(),
      });

  /// 头像和接口共用同一个 Bearer token，图片加载器需要现成的请求头。
  Map<String, String> get authHeaders =>
      _token == null ? const {} : {'Authorization': 'Bearer $_token'};

  /// 地址带版本号：Flutter 的 ImageCache 按 URL 命中，后端 no-store 管不到它，
  /// URL 不变的话换图后拿到的还是内存里的旧图。服务端忽略这个查询参数。
  String? get avatarUrl =>
      _token != null && _user?.hasAvatar == true
      ? '$_baseUrl/api/auth/me/avatar?v=$_avatarVersion'
      : null;

  /// 个人中心保存资料：后端回传最新用户信息，直接覆盖本地会话。
  Future<void> updateProfile({
    required String nickname,
    required String email,
    required String phone,
  }) async {
    final payload = await api.put(
      '/api/auth/me',
      {'nickname': nickname.trim(), 'email': email.trim(), 'phone': phone.trim()},
    ) as Map;
    await _applyUser(payload.cast<String, dynamic>());
  }

  Future<void> uploadAvatar({required Uint8List bytes, required String filename}) async {
    final payload = await api.postBytes(
      '/api/auth/me/avatar',
      field: 'file',
      bytes: bytes,
      filename: filename,
    ) as Map;
    _avatarVersion = DateTime.now().millisecondsSinceEpoch;
    await _applyUser(payload.cast<String, dynamic>());
  }

  Future<void> _applyUser(Map<String, dynamic> payload) async {
    _user = SessionUser.fromJson(payload);
    await _prefs.setString(_kUser, jsonEncode(_user!.toJson()));
    notifyListeners();
  }

  Future<void> signOut() async {
    await _prefs.remove(_kToken);
    await _prefs.remove(_kUser);
    _token = null;
    _user = null;
    notifyListeners();
  }

  Future<void> _authenticate(String path, Map<String, Object?> body) async {
    final payload = await api.post(path, body) as Map;
    await _applyToken(payload.cast<String, dynamic>());
  }

  Future<void> _applyToken(Map<String, dynamic> payload) async {
    _token = payload['token'] as String;
    _user = SessionUser.fromJson(payload['user'] as Map<String, dynamic>);
    await _prefs.setString(_kToken, _token!);
    await _prefs.setString(_kUser, jsonEncode(_user!.toJson()));
    notifyListeners();
  }

  /// 后端返回 401（token 过期或被撤销）时清掉本地会话，UI 回到登录页。
  void _expireToken() {
    if (_token == null) return;
    _token = null;
    _user = null;
    unawaited(_prefs.remove(_kToken));
    unawaited(_prefs.remove(_kUser));
    notifyListeners();
  }
}
