package com.example.ledger.web;

/** 业务异常：携带 {@link ErrorCode}，由 {@link ApiExceptionHandler} 转成统一响应体。 */
public class ApiException extends RuntimeException {

  private final ErrorCode errorCode;

  public ApiException(ErrorCode errorCode) {
    super(errorCode.message());
    this.errorCode = errorCode;
  }

  public ApiException(ErrorCode errorCode, String message) {
    super(message);
    this.errorCode = errorCode;
  }

  public ErrorCode errorCode() {
    return errorCode;
  }
}
