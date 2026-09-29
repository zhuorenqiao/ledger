package com.example.ledger.web;

import org.springframework.http.HttpStatus;

/**
 * 业务错误码。code 走统一响应体的 {@code code} 字段，httpStatus 决定 HTTP 状态码，
 * 两者各自保留：网关/浏览器看 HTTP，客户端按 code 做分支。
 */
public enum ErrorCode {

  SUCCESS(0, "成功", HttpStatus.OK),
  PARAM_INVALID(40000, "请求参数不合法", HttpStatus.BAD_REQUEST),
  CATEGORY_INVALID(40001, "分类不合法", HttpStatus.BAD_REQUEST),
  UNAUTHORIZED(40100, "未登录或登录已过期", HttpStatus.UNAUTHORIZED),
  LOGIN_FAILED(40101, "用户名或密码错误", HttpStatus.UNAUTHORIZED),
  FORBIDDEN(40300, "没有权限访问该资源", HttpStatus.FORBIDDEN),
  NOT_FOUND(40400, "资源不存在", HttpStatus.NOT_FOUND),
  TXN_NOT_FOUND(40401, "账单不存在", HttpStatus.NOT_FOUND),
  METHOD_NOT_ALLOWED(40500, "请求方法不被允许", HttpStatus.METHOD_NOT_ALLOWED),
  CONFLICT(40900, "请求与当前资源状态冲突", HttpStatus.CONFLICT),
  USERNAME_TAKEN(40901, "用户名已被占用", HttpStatus.CONFLICT),
  UNSUPPORTED_MEDIA_TYPE(41500, "不支持的 Content-Type", HttpStatus.UNSUPPORTED_MEDIA_TYPE),
  INTERNAL_ERROR(50000, "服务器内部错误", HttpStatus.INTERNAL_SERVER_ERROR);

  private final int code;
  private final String message;
  private final HttpStatus httpStatus;

  ErrorCode(int code, String message, HttpStatus httpStatus) {
    this.code = code;
    this.message = message;
    this.httpStatus = httpStatus;
  }

  public int code() {
    return code;
  }

  public String message() {
    return message;
  }

  public HttpStatus httpStatus() {
    return httpStatus;
  }
}
