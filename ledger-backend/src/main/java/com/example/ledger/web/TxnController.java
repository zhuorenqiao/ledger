package com.example.ledger.web;

import com.example.ledger.dto.BatchTxnRequest;
import com.example.ledger.dto.PageResponse;
import com.example.ledger.dto.TxnRequest;
import com.example.ledger.dto.TxnResponse;
import com.example.ledger.security.AuthUser;
import com.example.ledger.service.TxnService;
import jakarta.validation.Valid;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/txns")
public class TxnController {

  private final TxnService txns;

  public TxnController(TxnService txns) {
    this.txns = txns;
  }

  /** 分页拉取账单，`day` 可选用于只看某一天。 */
  @GetMapping
  public PageResponse<TxnResponse> page(@AuthenticationPrincipal AuthUser me,
      @RequestParam(defaultValue = "0") int page,
      @RequestParam(defaultValue = "20") int size,
      @RequestParam(required = false) String day) {
    RequestValidation.requireDayFormat(day);
    return txns.page(me, page, size, day);
  }

  @PostMapping
  public ResponseEntity<TxnResponse> create(@AuthenticationPrincipal AuthUser me,
      @Valid @RequestBody TxnRequest request) {
    return ResponseEntity.status(HttpStatus.CREATED).body(txns.create(me, request));
  }

  @PostMapping("/batch")
  public Map<String, Integer> createBatch(@AuthenticationPrincipal AuthUser me,
      @Valid @RequestBody BatchTxnRequest request) {
    return Map.of("inserted", txns.createBatch(me, request));
  }

  @DeleteMapping("/{id}")
  public void delete(@AuthenticationPrincipal AuthUser me, @PathVariable long id) {
    txns.delete(me, id);
  }

  @DeleteMapping
  public Map<String, Integer> clear(@AuthenticationPrincipal AuthUser me) {
    return Map.of("deleted", txns.clear(me));
  }
}
