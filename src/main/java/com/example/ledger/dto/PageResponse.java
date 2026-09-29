package com.example.ledger.dto;

import java.util.List;

/** 分页载荷：客户端按 page 递增拉取直到 last=true。 */
public record PageResponse<T>(List<T> items, int page, int size, long total, boolean last) {
}
