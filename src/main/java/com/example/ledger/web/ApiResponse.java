package com.example.ledger.web;

/**
 * 统一响应体。成功时 code=0、success=true、data 为业务数据；
 * 失败时 code 为 {@link ErrorCode}，message 可直接展示给用户。
 */
public record ApiResponse<T>(int code, String message, boolean success, T data) {

  public static <T> ApiResponse<T> ok(T data) {
    return new ApiResponse<>(ErrorCode.SUCCESS.code(), ErrorCode.SUCCESS.message(), true, data);
  }

  public static <T> ApiResponse<T> fail(ErrorCode errorCode, String message) {
    return new ApiResponse<>(errorCode.code(),
        message == null || message.isBlank() ? errorCode.message() : message, false, null);
  }
}
