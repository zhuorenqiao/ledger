/// 锁住「后端原文 vs 客户端本地化」这条契约：
/// - 后端带 message 的错误 → kind 为 null，界面原样展示，两语言都不翻译；
/// - 客户端自造的网络/HTTP/未知错误 → 打 kind 标记，按语言改写；
/// - generic 类保留底层诊断细节。
///
/// 分两层验证：`ApiClient._send` 的分派（走 stub adapter），以及
/// `AppLocalizations.errorText` 的映射（纯函数，直接构造 ApiException）。
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_front/data/api_client.dart';
import 'package:ledger_front/l10n/app_localizations.dart';

/// 按请求返回固定 JSON 响应体。status >= 400 时 Dio 会抛 badResponse。
class _BodyAdapter implements HttpClientAdapter {
  _BodyAdapter(this.responder);

  final (Object? body, int status) Function(RequestOptions options) responder;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final (body, status) = responder(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );
  }
}

/// 直接抛出构造好的 DioException，用来模拟连接失败 / 未知异常这类没有响应体的场景。
class _ThrowAdapter implements HttpClientAdapter {
  _ThrowAdapter(this.builder);

  final DioException Function(RequestOptions options) builder;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw builder(options);
  }
}

ApiClient _client(HttpClientAdapter adapter) => ApiClient(
  baseUrl: 'http://server.test',
  token: () => 't',
  adapter: adapter,
);

Future<ApiException> _capture(Future<dynamic> Function() call) async {
  try {
    await call();
  } on ApiException catch (e) {
    return e;
  }
  throw StateError('期望抛出 ApiException');
}

void main() {
  final zh = AppLocalizations(const Locale('zh'));
  final en = AppLocalizations(const Locale('en'));

  group('ApiClient._send 的 kind 分派', () {
    test('后端带 message 时原样透传，kind 为 null', () async {
      final client = _client(
        _BodyAdapter(
          (_) => (
            {'code': 40001, 'message': '分类 food 不属于 income', 'success': false, 'data': null},
            400,
          ),
        ),
      );

      final e = await _capture(() => client.get('/api/txns'));

      expect(e.kind, isNull);
      expect(e.message, '分类 food 不属于 income');
      expect(e.statusCode, 400);
      expect(e.code, 40001);
    });

    test('有 HTTP 状态但后端没给 message 时归为 http', () async {
      final client = _client(_BodyAdapter((_) => ({'code': 50000}, 500)));

      final e = await _capture(() => client.get('/api/txns'));

      expect(e.kind, 'http');
      expect(e.statusCode, 500);
    });

    test('连接失败归为 network', () async {
      final client = _client(
        _ThrowAdapter(
          (o) => DioException(
            requestOptions: o,
            type: DioExceptionType.connectionError,
            message: 'no route to host',
          ),
        ),
      );

      final e = await _capture(() => client.get('/api/txns'));

      expect(e.kind, 'network');
    });

    test('未知异常带细节归为 generic，并保留底层 message', () async {
      final client = _client(
        _ThrowAdapter(
          (o) => DioException(
            requestOptions: o,
            type: DioExceptionType.unknown,
            message: '证书校验失败',
          ),
        ),
      );

      final e = await _capture(() => client.get('/api/txns'));

      expect(e.kind, 'generic');
      expect(e.message, '证书校验失败');
    });
  });

  group('AppLocalizations.errorText 的映射', () {
    test('kind 为 null 时按后端原文展示，两语言都不翻译', () {
      const e = ApiException('分类 food 不属于 income', code: 40001, statusCode: 400);

      expect(e.kind, isNull);
      expect(zh.errorText(e), '分类 food 不属于 income');
      expect(en.errorText(e), '分类 food 不属于 income');
    });

    test('network 类错误本地化', () {
      const e = ApiException('连不上服务器，请检查后端是否已启动', kind: 'network');

      expect(zh.errorText(e), zh.networkUnavailable);
      expect(en.errorText(e), en.networkUnavailable);
      expect(zh.errorText(e), isNot(en.errorText(e)));
    });

    test('http 类错误带状态码本地化', () {
      const e = ApiException('请求失败（HTTP 503）', statusCode: 503, kind: 'http');

      expect(zh.errorText(e), zh.requestFailedHttp(503));
      expect(en.errorText(e), 'Request failed (HTTP 503)');
    });

    test('generic 类错误附带底层诊断细节', () {
      const e = ApiException('证书校验失败', kind: 'generic');

      expect(zh.errorText(e), '请求失败：证书校验失败');
      expect(en.errorText(e), 'Request failed: 证书校验失败');
    });

    test('generic 拿不到细节时不重复拼接', () {
      const bare = ApiException('请求失败', kind: 'generic');

      expect(zh.errorText(bare), '请求失败');
      expect(en.errorText(bare), 'Request failed');
    });

    test('非 ApiException 退回 toString', () {
      expect(zh.errorText(StateError('boom')), contains('boom'));
      expect(en.errorText(StateError('boom')), contains('boom'));
    });
  });
}
