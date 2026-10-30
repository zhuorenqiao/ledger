package com.example.ledger.service;

import com.example.ledger.domain.Txn;
import com.example.ledger.domain.User;
import com.example.ledger.dto.BatchTxnRequest;
import com.example.ledger.dto.PageResponse;
import com.example.ledger.dto.TxnRequest;
import com.example.ledger.dto.TxnResponse;
import com.example.ledger.repository.TxnRepository;
import com.example.ledger.repository.UserRepository;
import com.example.ledger.security.AuthUser;
import com.example.ledger.web.ApiException;
import com.example.ledger.web.ErrorCode;
import java.math.RoundingMode;
import java.util.List;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class TxnService {

  private static final int MAX_PAGE_SIZE = 1000;

  private final TxnRepository txns;
  private final UserRepository users;

  public TxnService(TxnRepository txns, UserRepository users) {
    this.txns = txns;
    this.users = users;
  }

  @Transactional(readOnly = true)
  public PageResponse<TxnResponse> page(AuthUser me, int page, int size, String day) {
    int safeSize = Math.min(Math.max(size, 1), MAX_PAGE_SIZE);
    int safePage = Math.max(page, 0);
    long userId = me.id();
    boolean filteredByDay = day != null && !day.isBlank();
    PageRequest pageable = PageRequest.of(safePage, safeSize);

    long total = filteredByDay
        ? txns.countByUserIdAndDay(userId, day)
        : txns.countByUserId(userId);
    List<TxnResponse> items = (filteredByDay
            ? txns.findByUserIdAndDayOrderByDayDescCreatedAtDesc(userId, day, pageable)
            : txns.findByUserIdOrderByDayDescCreatedAtDesc(userId, pageable))
        .stream().map(TxnResponse::from).toList();
    boolean last = (long) (safePage + 1) * safeSize >= total;
    return new PageResponse<>(items, safePage, safeSize, total, last);
  }

  @Transactional
  public TxnResponse create(AuthUser me, TxnRequest request) {
    return TxnResponse.from(txns.save(toEntity(userOf(me), request)));
  }

  @Transactional
  public int createBatch(AuthUser me, BatchTxnRequest request) {
    User user = userOf(me);
    List<Txn> entities = request.txns().stream().map(r -> toEntity(user, r)).toList();
    txns.saveAll(entities);
    return entities.size();
  }

  @Transactional
  public void delete(AuthUser me, long id) {
    Txn txn = txns.findByIdAndUserId(id, me.id())
        .orElseThrow(() -> new ApiException(ErrorCode.TXN_NOT_FOUND, "账单 " + id + " 不存在"));
    txns.delete(txn);
  }

  @Transactional
  public int clear(AuthUser me) {
    return txns.deleteByUserId(me.id());
  }

  private User userOf(AuthUser me) {
    return users.getReferenceById(me.id());
  }

  private static Txn toEntity(User user, TxnRequest r) {
    CategoryCatalog.requireValidCategory(r.type(), r.category());
    return new Txn(user, r.type(), r.category(), r.amount().setScale(2, RoundingMode.HALF_UP),
        r.day(), r.noteOrEmpty(), r.createdAt());
  }
}
