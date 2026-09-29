package com.example.ledger.web;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.ErrorResponse;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.MissingServletRequestParameterException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;

/** 把各类异常统一翻译成 {@link ApiResponse}，HTTP 状态码与业务 code 同时给出。 */
@RestControllerAdvice
public class ApiExceptionHandler {

  private static final Logger log = LoggerFactory.getLogger(ApiExceptionHandler.class);

  @ExceptionHandler(ApiException.class)
  public ResponseEntity<ApiResponse<Void>> handleApi(ApiException e) {
    return forError(e.errorCode(), e.getMessage());
  }

  @ExceptionHandler(MethodArgumentNotValidException.class)
  public ResponseEntity<ApiResponse<Void>> handleValidation(MethodArgumentNotValidException e) {
    String message = e.getBindingResult().getFieldErrors().stream()
        .findFirst()
        .map(err -> err.getField() + ": " + err.getDefaultMessage())
        .orElse(ErrorCode.PARAM_INVALID.message());
    return forError(ErrorCode.PARAM_INVALID, message);
  }

  @ExceptionHandler(MethodArgumentTypeMismatchException.class)
  public ResponseEntity<ApiResponse<Void>> handleTypeMismatch(MethodArgumentTypeMismatchException e) {
    return forError(ErrorCode.PARAM_INVALID, "参数 " + e.getName() + " 类型不正确");
  }

  @ExceptionHandler(MissingServletRequestParameterException.class)
  public ResponseEntity<ApiResponse<Void>> handleMissingParam(
      MissingServletRequestParameterException e) {
    return forError(ErrorCode.PARAM_INVALID, "缺少参数 " + e.getParameterName());
  }

  @ExceptionHandler(HttpMessageNotReadableException.class)
  public ResponseEntity<ApiResponse<Void>> handleUnreadable(HttpMessageNotReadableException e) {
    return forError(ErrorCode.PARAM_INVALID, "请求体不是合法的 JSON");
  }

  /**
   * 兜底：404 / 405 / 415 等框架异常自带 HTTP 状态，按状态翻译成对应 code；
   * 其余未预期异常归为 50000 并记日志。
   */
  @ExceptionHandler(Exception.class)
  public ResponseEntity<ApiResponse<Void>> handleUnexpected(Exception e) {
    if (e instanceof ErrorResponse error) {
      int status = error.getStatusCode().value();
      return forStatus(status, status == HttpStatus.NOT_FOUND.value() ? "接口不存在" : null);
    }
    log.error("未处理的异常: {}", e.getMessage(), e);
    return forError(ErrorCode.INTERNAL_ERROR, null);
  }

  private static ResponseEntity<ApiResponse<Void>> forStatus(int status, String message) {
    HttpStatus resolved = HttpStatus.resolve(status) == null
        ? HttpStatus.INTERNAL_SERVER_ERROR
        : HttpStatus.valueOf(status);
    ErrorCode code = switch (resolved) {
      case UNAUTHORIZED -> ErrorCode.UNAUTHORIZED;
      case FORBIDDEN -> ErrorCode.FORBIDDEN;
      case NOT_FOUND -> ErrorCode.NOT_FOUND;
      case METHOD_NOT_ALLOWED -> ErrorCode.METHOD_NOT_ALLOWED;
      case CONFLICT -> ErrorCode.CONFLICT;
      case UNSUPPORTED_MEDIA_TYPE -> ErrorCode.UNSUPPORTED_MEDIA_TYPE;
      case INTERNAL_SERVER_ERROR -> ErrorCode.INTERNAL_ERROR;
      default -> resolved.is4xxClientError() ? ErrorCode.PARAM_INVALID : ErrorCode.INTERNAL_ERROR;
    };
    // 保留框架给出的原始 HTTP 状态，只额外补上业务 code
    return ResponseEntity.status(resolved).body(ApiResponse.fail(code, message));
  }

  private static ResponseEntity<ApiResponse<Void>> forError(ErrorCode code, String message) {
    return ResponseEntity.status(code.httpStatus()).body(ApiResponse.fail(code, message));
  }
}
