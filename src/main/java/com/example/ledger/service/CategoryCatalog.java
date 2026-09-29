package com.example.ledger.service;

import com.example.ledger.web.ApiException;
import com.example.ledger.web.ErrorCode;
import java.util.Map;
import java.util.Set;

/** 分类目录：客户端用 key 渲染图标与文案，后端只用它校验数据合法性。 */
public final class CategoryCatalog {

  public static final String EXPENSE = "expense";
  public static final String INCOME = "income";

  private static final Map<String, Set<String>> BY_TYPE = Map.of(
      EXPENSE, Set.of("food", "transport", "shopping", "housing", "entertainment", "medical",
          "study", "beauty", "other_expense"),
      INCOME, Set.of("salary", "bonus", "part_time", "investment", "other_income"));

  private CategoryCatalog() {
  }

  public static void requireValidType(String type) {
    if (!BY_TYPE.containsKey(type)) {
      throw new ApiException(ErrorCode.CATEGORY_INVALID, "type 只能是 expense 或 income");
    }
  }

  public static void requireValidCategory(String type, String category) {
    requireValidType(type);
    if (!BY_TYPE.get(type).contains(category)) {
      throw new ApiException(ErrorCode.CATEGORY_INVALID, "分类 " + category + " 不属于 " + type);
    }
  }
}
