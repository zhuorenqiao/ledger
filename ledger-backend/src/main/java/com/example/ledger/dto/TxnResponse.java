package com.example.ledger.dto;

import com.example.ledger.domain.Txn;
import java.math.BigDecimal;

public record TxnResponse(
    Long id, String type, String category, BigDecimal amount, String day, String note,
    Long createdAt) {

  public static TxnResponse from(Txn txn) {
    return new TxnResponse(txn.getId(), txn.getType(), txn.getCategory(), txn.getAmount(),
        txn.getDay(), txn.getNote(), txn.getCreatedAt());
  }
}
