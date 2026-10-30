package com.example.ledger.service;

import com.example.ledger.dto.SummaryResponse;
import com.example.ledger.dto.TrendPoint;
import com.example.ledger.repository.CategoryTotal;
import com.example.ledger.repository.DayTotal;
import com.example.ledger.repository.TxnRepository;
import com.example.ledger.repository.TypeTotal;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.YearMonth;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.TreeSet;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** 统计口径全部由 MySQL 的 GROUP BY 完成，客户端只负责渲染。 */
@Service
public class StatsService {

  private static final String ALL_FROM = "0000-01-01";
  private static final String ALL_TO = "9999-12-31";

  private final TxnRepository txns;

  public StatsService(TxnRepository txns) {
    this.txns = txns;
  }

  @Transactional(readOnly = true)
  public SummaryResponse summary(long userId, String from, String to) {
    String start = from == null || from.isBlank() ? ALL_FROM : from;
    String end = to == null || to.isBlank() ? ALL_TO : to;

    BigDecimal expense = BigDecimal.ZERO;
    BigDecimal income = BigDecimal.ZERO;
    long count = 0;
    for (TypeTotal row : txns.sumByType(userId, start, end)) {
      count += row.getCnt();
      if (CategoryCatalog.EXPENSE.equals(row.getType())) {
        expense = row.getTotal();
      } else {
        income = row.getTotal();
      }
    }
    return new SummaryResponse(expense, income, count,
        slices(userId, CategoryCatalog.EXPENSE, start, end),
        slices(userId, CategoryCatalog.INCOME, start, end));
  }

  @Transactional(readOnly = true)
  public List<TrendPoint> daily(long userId, int year, int month) {
    YearMonth ym = YearMonth.of(year, month);
    List<DayTotal> rows = txns.sumByDay(userId, ym.atDay(1).toString(), ym.atEndOfMonth().toString());
    List<TrendPoint> points = new ArrayList<>(ym.lengthOfMonth());
    for (int day = 1; day <= ym.lengthOfMonth(); day++) {
      String key = ym.atDay(day).toString();
      points.add(new TrendPoint(String.valueOf(day), totalOf(rows, key, CategoryCatalog.EXPENSE),
          totalOf(rows, key, CategoryCatalog.INCOME)));
    }
    return points;
  }

  @Transactional(readOnly = true)
  public List<TrendPoint> monthly(long userId, int year) {
    LocalDate start = LocalDate.of(year, 1, 1);
    LocalDate end = LocalDate.of(year, 12, 31);
    List<DayTotal> rows = txns.sumByDay(userId, start.toString(), end.toString());
    List<TrendPoint> points = new ArrayList<>(12);
    for (int month = 1; month <= 12; month++) {
      String prefix = YearMonth.of(year, month).atDay(1).toString().substring(0, 7);
      points.add(new TrendPoint(String.valueOf(month),
          totalOfMonth(rows, prefix, CategoryCatalog.EXPENSE),
          totalOfMonth(rows, prefix, CategoryCatalog.INCOME)));
    }
    return points;
  }

  @Transactional(readOnly = true)
  public List<Integer> years(long userId) {
    TreeSet<Integer> years = new TreeSet<>(Comparator.reverseOrder());
    txns.distinctYears(userId).stream().map(Integer::parseInt).forEach(years::add);
    years.add(LocalDate.now().getYear());
    return List.copyOf(years);
  }

  private List<SummaryResponse.CategorySlice> slices(long userId, String type, String from,
      String to) {
    return txns.sumByCategory(userId, type, from, to).stream()
        .sorted(Comparator.comparing(CategoryTotal::getTotal).reversed())
        .map(r -> new SummaryResponse.CategorySlice(r.getCategory(), r.getTotal()))
        .toList();
  }

  private static BigDecimal totalOf(List<DayTotal> rows, String day, String type) {
    BigDecimal total = BigDecimal.ZERO;
    for (DayTotal row : rows) {
      if (row.getDay().equals(day) && row.getType().equals(type)) {
        total = row.getTotal();
      }
    }
    return total;
  }

  private static BigDecimal totalOfMonth(List<DayTotal> rows, String monthPrefix, String type) {
    BigDecimal total = BigDecimal.ZERO;
    for (DayTotal row : rows) {
      if (row.getDay().startsWith(monthPrefix) && row.getType().equals(type)) {
        total = total.add(row.getTotal());
      }
    }
    return total;
  }
}
