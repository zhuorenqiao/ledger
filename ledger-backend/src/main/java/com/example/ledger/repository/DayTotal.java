package com.example.ledger.repository;

import java.math.BigDecimal;

/** 某一天某种收支的合计，日趋势与月趋势都由它派生。 */
public interface DayTotal {
  String getDay();

  String getType();

  BigDecimal getTotal();
}
