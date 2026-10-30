package com.example.ledger.web;

import com.example.ledger.dto.FeedbackResponse;
import com.example.ledger.security.AuthUser;
import com.example.ledger.service.FeedbackService;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequestMapping("/api/feedback")
public class FeedbackController {

  private final FeedbackService feedbacks;

  public FeedbackController(FeedbackService feedbacks) {
    this.feedbacks = feedbacks;
  }

  /** multipart 提交：`content` 是正文文本域，`images` 是最多 3 张图（可选，同名多份）。 */
  @PostMapping
  public ResponseEntity<FeedbackResponse> submit(@AuthenticationPrincipal AuthUser me,
      @RequestParam("content") String content,
      @RequestPart(value = "images", required = false) List<MultipartFile> images) {
    return ResponseEntity.status(HttpStatus.CREATED).body(feedbacks.submit(me, content, images));
  }
}
