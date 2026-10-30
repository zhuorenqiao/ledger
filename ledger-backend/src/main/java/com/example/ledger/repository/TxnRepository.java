package com.example.ledger.repository;

import com.example.ledger.domain.Txn;
import com.example.ledger.domain.User;
import java.util.List;
import java.util.Optional;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface TxnRepository extends JpaRepository<Txn, Long> {

  List<Txn> findByUserIdOrderByDayDescCreatedAtDesc(long userId, Pageable pageable);

  List<Txn> findByUserIdAndDayOrderByDayDescCreatedAtDesc(long userId, String day,
      Pageable pageable);

  long countByUserId(long userId);

  long countByUserIdAndDay(long userId, String day);

  Optional<Txn> findByIdAndUserId(long id, long userId);

  @Modifying
  @Query("delete from Txn t where t.user.id = :userId")
  int deleteByUserId(@Param("userId") long userId);

  @Query("select t.category as category, sum(t.amount) as total from Txn t "
      + "where t.user.id = :userId and t.type = :type and t.day between :from and :to "
      + "group by t.category")
  List<CategoryTotal> sumByCategory(@Param("userId") long userId, @Param("type") String type,
      @Param("from") String from, @Param("to") String to);

  @Query("select t.type as type, count(t.id) as cnt, sum(t.amount) as total from Txn t "
      + "where t.user.id = :userId and t.day between :from and :to group by t.type")
  List<TypeTotal> sumByType(@Param("userId") long userId, @Param("from") String from,
      @Param("to") String to);

  @Query("select t.day as day, t.type as type, sum(t.amount) as total from Txn t "
      + "where t.user.id = :userId and t.day between :from and :to group by t.day, t.type")
  List<DayTotal> sumByDay(@Param("userId") long userId, @Param("from") String from,
      @Param("to") String to);

  @Query("select distinct substring(t.day, 1, 4) from Txn t where t.user.id = :userId")
  List<String> distinctYears(@Param("userId") long userId);
}
