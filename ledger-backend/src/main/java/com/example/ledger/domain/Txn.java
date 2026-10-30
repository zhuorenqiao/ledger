package com.example.ledger.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import java.math.BigDecimal;

@Entity
@Table(name = "txn")
public class Txn {

  @Id
  @GeneratedValue(strategy = GenerationType.IDENTITY)
  private Long id;

  @ManyToOne(fetch = FetchType.LAZY, optional = false)
  @JoinColumn(name = "user_id", nullable = false)
  private User user;

  @Column(nullable = false, length = 16)
  private String type;

  @Column(nullable = false, length = 32)
  private String category;

  @Column(nullable = false, precision = 12, scale = 2)
  private BigDecimal amount;

  @Column(nullable = false, length = 10)
  private String day;

  @Column(nullable = false, length = 255)
  private String note;

  @Column(name = "created_at", nullable = false)
  private Long createdAt;

  protected Txn() {
  }

  public Txn(User user, String type, String category, BigDecimal amount, String day, String note,
      long createdAt) {
    this.user = user;
    this.type = type;
    this.category = category;
    this.amount = amount;
    this.day = day;
    this.note = note;
    this.createdAt = createdAt;
  }

  public Long getId() {
    return id;
  }

  public User getUser() {
    return user;
  }

  public String getType() {
    return type;
  }

  public String getCategory() {
    return category;
  }

  public BigDecimal getAmount() {
    return amount;
  }

  public String getDay() {
    return day;
  }

  public String getNote() {
    return note;
  }

  public Long getCreatedAt() {
    return createdAt;
  }
}
