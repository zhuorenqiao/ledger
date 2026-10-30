package com.example.ledger.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.util.Arrays;
import java.util.List;

@Entity
@Table(name = "feedback")
public class Feedback {

  /** 正文上限，与客户端 TextField 的 maxLength 一致。 */
  public static final int MAX_CONTENT = 1000;

  /** 单条反馈最多带几张图。 */
  public static final int MAX_IMAGES = 3;

  @Id
  @GeneratedValue(strategy = GenerationType.IDENTITY)
  private Long id;

  @Column(name = "user_id", nullable = false)
  private Long userId;

  @Column(nullable = false, length = 1000)
  private String content;

  /** 逗号分隔的图片文件名，图片本体在 app.storage.feedback-dir 下。 */
  @Column(nullable = false, length = 512)
  private String images = "";

  @Column(name = "created_at", nullable = false)
  private Long createdAt;

  protected Feedback() {
  }

  public Feedback(Long userId, String content, List<String> images, long createdAt) {
    this.userId = userId;
    this.content = content;
    this.images = String.join(",", images);
    this.createdAt = createdAt;
  }

  public Long getId() {
    return id;
  }

  public Long getUserId() {
    return userId;
  }

  public String getContent() {
    return content;
  }

  public String getImages() {
    return images;
  }

  public List<String> imageNames() {
    return images.isBlank() ? List.of() : Arrays.asList(images.split(","));
  }

  public long getCreatedAt() {
    return createdAt;
  }
}
