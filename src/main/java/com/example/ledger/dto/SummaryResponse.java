package com.example.ledger.dto;

import java.math.BigDecimal;
import java.util.List;

/** 区间内的收支合计与分类构成，由 SQL 聚合得到。 */
public record SummaryResponse(
    BigDecimal expense,
    BigDecimal income,
    long count,
    List<CategorySlice> expenseByCategory,
    List<CategorySlice> incomeByCategory) {

  public record CategorySlice(String category, BigDecimal amount) {
  }

  public static SummaryResponse empty() {
    return new SummaryResponse(BigDecimal.ZERO, BigDecimal.ZERO, 0, List.of(), List.of());
  }
}
