package com.example.ledger.repository;

import java.math.BigDecimal;

/** 分类聚合结果。 */
public interface CategoryTotal {
  String getCategory();

  BigDecimal getTotal();
}
