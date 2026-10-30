package com.example.ledger.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.math.BigDecimal;

public record TxnRequest(
    @NotBlank String type,

    @NotBlank @Size(max = 32) String category,

    @NotNull @DecimalMin(value = "0.00", inclusive = false) @Digits(integer = 10, fraction = 2)
    BigDecimal amount,

    @NotBlank @Pattern(regexp = "\\d{4}-\\d{2}-\\d{2}", message = "day 必须是 yyyy-MM-dd") String day,

    @Size(max = 200) String note,

    @NotNull Long createdAt) {

  public String noteOrEmpty() {
    return note == null ? "" : note.trim();
  }
}
