package com.example.ledger.web;

import java.util.regex.Pattern;

final class RequestValidation {

  private static final Pattern DAY = Pattern.compile("\\d{4}-\\d{2}-\\d{2}");

  private RequestValidation() {
  }

  static void requireDayFormat(String day) {
    if (day != null && !day.isBlank() && !DAY.matcher(day).matches()) {
      throw new ApiException(ErrorCode.PARAM_INVALID, "日期参数必须是 yyyy-MM-dd");
    }
  }
}
