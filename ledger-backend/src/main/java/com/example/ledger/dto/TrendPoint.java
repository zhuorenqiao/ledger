package com.example.ledger.dto;

import java.math.BigDecimal;

/** 趋势图上的一个刻度：label 为日或月，缺失的日期/月份补 0 以保证横轴连续。 */
public record TrendPoint(String label, BigDecimal expense, BigDecimal income) {
}
