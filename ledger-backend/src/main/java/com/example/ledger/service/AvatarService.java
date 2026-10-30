package com.example.ledger.service;

import com.example.ledger.config.AppProperties;
import com.example.ledger.domain.User;
import com.example.ledger.dto.UserResponse;
import com.example.ledger.repository.UserRepository;
import com.example.ledger.security.AuthUser;
import com.example.ledger.web.ApiException;
import com.example.ledger.web.ErrorCode;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.Map;
import java.util.stream.Collectors;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

/** 头像落盘在 app.storage.avatar-dir，数据库只记文件名。 */
@Service
public class AvatarService {

  /** 扩展名由 Content-Type 反推，客户端给的文件名一律不用。 */
  private static final Map<String, String> TYPE_TO_EXT = Map.of(
      "image/png", "png",
      "image/jpeg", "jpg",
      "image/webp", "webp",
      "image/gif", "gif");

  private static final Map<String, String> EXT_TO_TYPE = TYPE_TO_EXT.entrySet().stream()
      .collect(Collectors.toMap(Map.Entry::getValue, Map.Entry::getKey));

  private static final Logger log = LoggerFactory.getLogger(AvatarService.class);

  private final UserRepository users;
  private final Path avatarDir;
  public AvatarService(UserRepository users, AppProperties props) {
    this.users = users;
    this.avatarDir = Path.of(props.storage().avatarDir());
  }

  public record Stored(Path file, String contentType) {}

  @Transactional
  public UserResponse store(AuthUser me, MultipartFile file) {
    if (file == null || file.isEmpty()) {
      throw new ApiException(ErrorCode.PARAM_INVALID, "请选择一张图片");
    }
    String ext = TYPE_TO_EXT.get(file.getContentType());
    if (ext == null) {
      throw new ApiException(ErrorCode.PARAM_INVALID,
          "只支持 " + String.join("、", TYPE_TO_EXT.keySet()) + " 图片");
    }
    User user = requireUser(me);
    String filename = user.getId() + "." + ext;
    try {
      Files.createDirectories(avatarDir);
      try (InputStream in = file.getInputStream()) {
        Files.copy(in, avatarDir.resolve(filename), StandardCopyOption.REPLACE_EXISTING);
      }
    } catch (IOException e) {
      throw new ApiException(ErrorCode.INTERNAL_ERROR, "头像保存失败：" + e.getMessage());
    }
    deleteQuietly(user.getAvatar(), filename);
    user.updateAvatar(filename);
    return UserResponse.of(user);
  }

  @Transactional(readOnly = true)
  public Stored load(AuthUser me) {
    User user = requireUser(me);
    if (user.getAvatar().isBlank()) {
      throw new ApiException(ErrorCode.NOT_FOUND, "还没有上传头像");
    }
    Path file = avatarDir.resolve(user.getAvatar());
    if (!Files.isRegularFile(file)) {
      throw new ApiException(ErrorCode.NOT_FOUND, "头像文件已丢失，请重新上传");
    }
    int dot = user.getAvatar().lastIndexOf('.');
    String ext = dot < 0 ? "" : user.getAvatar().substring(dot + 1);
    return new Stored(file, EXT_TO_TYPE.getOrDefault(ext, "application/octet-stream"));
  }

  private User requireUser(AuthUser me) {
    return users.findById(me.id())
        .orElseThrow(() -> new ApiException(ErrorCode.UNAUTHORIZED, "账号不存在或已被删除"));
  }

  private void deleteQuietly(String previous, String keep) {
    if (previous.isBlank() || previous.equals(keep)) {
      return;
    }
    try {
      Files.deleteIfExists(avatarDir.resolve(previous));
    } catch (IOException e) {
      log.debug("旧头像 {} 没删掉: {}", previous, e.getMessage());
    }
  }
}
