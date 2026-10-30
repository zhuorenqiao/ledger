package com.example.ledger.dto;

import com.example.ledger.domain.Feedback;

/** 反馈提交成功后回给客户端的内容，只用来确认「收到了哪一条」。 */
public record FeedbackResponse(long id, int contentLength, int imageCount, long createdAt) {

  public static FeedbackResponse of(Feedback feedback) {
    return new FeedbackResponse(
        feedback.getId(),
        feedback.getContent().length(),
        feedback.imageNames().size(),
        feedback.getCreatedAt());
  }
}
