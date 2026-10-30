package com.example.ledger.repository;

import java.math.BigDecimal;

/** 按收支类型聚合的金额与笔数。 */
public interface TypeTotal {
  String getType();

  Long getCnt();

  BigDecimal getTotal();
}
