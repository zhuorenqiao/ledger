package com.example.ledger.service;

import com.example.ledger.config.AppProperties;
import com.example.ledger.domain.Feedback;
import com.example.ledger.dto.FeedbackResponse;
import com.example.ledger.repository.FeedbackRepository;
import com.example.ledger.security.AuthUser;
import com.example.ledger.web.ApiException;
import com.example.ledger.web.ErrorCode;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

/**
 * 意见反馈：一段正文 + 最多 3 张图。正文进数据库，图片落盘在
 * app.storage.feedback-dir，库里只记文件名（与头像同一套做法）。
 */
@Service
public class FeedbackService {

  /** 扩展名由 Content-Type 反推，客户端给的文件名一律不用。 */
  private static final Map<String, String> TYPE_TO_EXT = Map.of(
      "image/png", "png",
      "image/jpeg", "jpg",
      "image/webp", "webp",
      "image/gif", "gif");

  private static final Logger log = LoggerFactory.getLogger(FeedbackService.class);

  private final FeedbackRepository feedbacks;
  private final Path feedbackDir;

  public FeedbackService(FeedbackRepository feedbacks, AppProperties props) {
    this.feedbacks = feedbacks;
    this.feedbackDir = Path.of(props.storage().feedbackDir());
  }

  @Transactional
  public FeedbackResponse submit(AuthUser me, String content, List<MultipartFile> files) {
    String text = content == null ? "" : content.trim();
    if (text.isEmpty()) {
      throw new ApiException(ErrorCode.PARAM_INVALID, "反馈内容不能为空");
    }
    // 按码点算：MySQL 的 VARCHAR(1000) 也是按字符（码点）计数的，这样校验过了就一定存得下
    if (text.codePointCount(0, text.length()) > Feedback.MAX_CONTENT) {
      throw new ApiException(ErrorCode.PARAM_INVALID,
          "反馈内容最多 " + Feedback.MAX_CONTENT + " 个字");
    }

    List<MultipartFile> images = files == null ? List.of()
        : files.stream().filter(file -> file != null && !file.isEmpty()).toList();
    if (images.size() > Feedback.MAX_IMAGES) {
      throw new ApiException(ErrorCode.PARAM_INVALID, "最多上传 " + Feedback.MAX_IMAGES + " 张图片");
    }
    // 先把所有扩展名校验完再落盘，免得中途失败留下一堆没用的文件
    List<String> extensions = new ArrayList<>(images.size());
    for (MultipartFile image : images) {
      String ext = TYPE_TO_EXT.get(image.getContentType());
      if (ext == null) {
        throw new ApiException(ErrorCode.PARAM_INVALID,
            "只支持 " + String.join("、", TYPE_TO_EXT.keySet()) + " 图片");
      }
      extensions.add(ext);
    }

    List<String> stored = writeFiles(me.id(), images, extensions);
    // 事务回滚不会顺手删掉刚写的文件，最坏留下一份孤儿图片；反过来先写库再落盘
    // 会留下指向空文件的记录，更难收拾，所以选前者。
    Feedback feedback = feedbacks.save(
        new Feedback(me.id(), text, stored, System.currentTimeMillis()));
    return FeedbackResponse.of(feedback);
  }

  private List<String> writeFiles(long userId, List<MultipartFile> images, List<String> extensions) {
    if (images.isEmpty()) {
      return List.of();
    }
    List<String> names = new ArrayList<>(images.size());
    try {
      Files.createDirectories(feedbackDir);
      for (int i = 0; i < images.size(); i++) {
        String name = userId + "-" + UUID.randomUUID() + "." + extensions.get(i);
        try (InputStream in = images.get(i).getInputStream()) {
          Files.copy(in, feedbackDir.resolve(name), StandardCopyOption.REPLACE_EXISTING);
        }
        names.add(name);
      }
    } catch (IOException e) {
      deleteQuietly(names);
      throw new ApiException(ErrorCode.INTERNAL_ERROR, "反馈图片保存失败：" + e.getMessage());
    }
    return names;
  }

  /** 写到一半失败时把已经落盘的那几张清掉。 */
  private void deleteQuietly(List<String> names) {
    for (String name : names) {
      try {
        Files.deleteIfExists(feedbackDir.resolve(name));
      } catch (IOException e) {
        log.debug("反馈图片 {} 没删掉: {}", name, e.getMessage());
      }
    }
  }
}
