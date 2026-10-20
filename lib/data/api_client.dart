import 'dart:typed_data';

import 'package:dio/dio.dart';

/// multipart 里的一个文件。web 端拿不到本地路径，只能带着字节和文件名走。
typedef FormFile = ({String filename, Uint8List bytes});

/// 后端返回的业务错误：`code` 是统一响应体里的业务码，`statusCode` 是 HTTP 状态。
class ApiException implements Exception {
  const ApiException(this.message, {this.code, this.statusCode, this.kind});

  final String message;
  final int? code;
  final int? statusCode;

  /// 客户端自己造的错误类别（network / http / generic）。为 null 表示文案来自后端，
  /// 界面按原文展示，前端不翻译后端话术。
  final String? kind;

  bool get unauthorized => statusCode == 401;

  @override
  String toString() => message;
}

/// 轻量 REST 客户端：注入 Bearer token，把错误统一成 [ApiException]。
class ApiClient {
  ApiClient({
    required String baseUrl,
    required this.token,
    this.onUnauthorized,
    HttpClientAdapter? adapter,
  }) : _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 20),
          headers: {'Accept': 'application/json'},
        ),
      ) {
    if (adapter != null) _dio.httpClientAdapter = adapter;
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final t = token();
          if (t != null && t.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $t';
          }
          handler.next(options);
        },
      ),
    );
  }

  final Dio _dio;
  final String? Function() token;
  final void Function()? onUnauthorized;

  /// baseUrl 变化后重建连接（改服务器地址时用）。
  void updateBaseUrl(String baseUrl) => _dio.options.baseUrl = baseUrl;

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _dio.get(path, queryParameters: _clean(query)));

  Future<dynamic> post(String path, Object? body) => _send(() => _dio.post(path, data: body));

  Future<dynamic> put(String path, Object? body) => _send(() => _dio.put(path, data: body));

  /// 上传单个二进制（头像）。web 端拿不到文件路径，只能传字节。
  Future<dynamic> postBytes(
    String path, {
    required String field,
    required Uint8List bytes,
    required String filename,
  }) =>
      postForm(path, fileField: field, files: [(filename: filename, bytes: bytes)]);

  /// 提交表单，可带多个同名文件（反馈图片）。没有文件时不留空字段，
  /// 免得后端收到一个空的 multipart part。
  Future<dynamic> postForm(
    String path, {
    Map<String, String> fields = const {},
    String fileField = 'files',
    List<FormFile> files = const [],
  }) {
    final data = <String, dynamic>{...fields};
    if (files.isNotEmpty) {
      data[fileField] = [
        for (final file in files)
          MultipartFile.fromBytes(file.bytes, filename: file.filename),
      ];
    }
    return _send(() => _dio.post(path, data: FormData.fromMap(data)));
  }

  Future<dynamic> delete(String path) => _send(() => _dio.delete(path));

  Future<dynamic> _send(Future<Response<dynamic>> Function() request) async {
    try {
      final response = await request();
      return _unwrap(response.data);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401) onUnauthorized?.call();
      final data = e.response?.data;
      final serverMessage = data is Map ? data['message'] : null;
      if (serverMessage is String && serverMessage.isNotEmpty) {
        throw ApiException(serverMessage, code: _codeOf(e), statusCode: status);
      }
      final (message, kind) = _clientError(e, status);
      throw ApiException(
        message,
        code: _codeOf(e),
        statusCode: status,
        kind: kind,
      );
    }
  }

  /// 后端统一响应体 `{code, message, success, data}`，上层只取 data。
  static dynamic _unwrap(dynamic body) {
    if (body is Map && body.containsKey('data')) return body['data'];
    return body;
  }

  static int? _codeOf(DioException e) {
    final data = e.response?.data;
    final code = data is Map ? data['code'] : null;
    return code is num ? code.toInt() : null;
  }

  /// 没有后端话术时，前端自己兜一句中文，并标出类别让界面按语言改写。
  static (String, String) _clientError(DioException e, int? status) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      return ('连不上服务器，请检查后端是否已启动', 'network');
    }
    if (status != null) return ('请求失败（HTTP $status）', 'http');
    return (e.message ?? '请求失败', 'generic');
  }

  static Map<String, dynamic>? _clean(Map<String, dynamic>? query) {
    if (query == null) return null;
    query.removeWhere((_, v) => v == null);
    return query;
  }
}
