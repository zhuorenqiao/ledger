package com.example.ledger.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "users")
public class User {

  @Id
  @GeneratedValue(strategy = GenerationType.IDENTITY)
  private Long id;

  @Column(nullable = false, unique = true, length = 64)
  private String username;

  @Column(name = "password_hash", nullable = false, length = 100)
  private String passwordHash;

  @Column(nullable = false, length = 64)
  private String nickname;

  @Column(nullable = false, length = 255)
  private String email;

  @Column(nullable = false, length = 20)
  private String phone;

  /** 头像文件名（含扩展名），图片本体在 app.storage.avatar-dir 下。 */
  @Column(nullable = false, length = 64)
  private String avatar = "";

  @Column(name = "created_at", nullable = false)
  private Long createdAt;

  protected User() {
  }

  public User(String username, String passwordHash, String nickname, String email, String phone,
      long createdAt) {
    this.username = username;
    this.passwordHash = passwordHash;
    this.nickname = nickname;
    this.email = email;
    this.phone = phone;
    this.createdAt = createdAt;
  }

  public Long getId() {
    return id;
  }

  public String getUsername() {
    return username;
  }

  public String getPasswordHash() {
    return passwordHash;
  }

  public String getNickname() {
    return nickname;
  }

  public String getEmail() {
    return email;
  }

  public String getPhone() {
    return phone;
  }

  public String getAvatar() {
    return avatar;
  }

  public long getCreatedAt() {
    return createdAt;
  }

  /** 个人中心可改的字段；username 是登录凭据，不在范围内。 */
  public void updateProfile(String nickname, String email, String phone) {
    this.nickname = nickname;
    this.email = email;
    this.phone = phone;
  }

  public void updateAvatar(String avatar) {
    this.avatar = avatar == null ? "" : avatar;
  }
}
