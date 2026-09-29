package com.example.ledger.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Size;
import java.util.List;

/** 批量写入，供「载入示例数据」一次提交上千条账单。 */
public record BatchTxnRequest(
    @NotEmpty @Size(max = 5000) List<@Valid TxnRequest> txns) {
}
