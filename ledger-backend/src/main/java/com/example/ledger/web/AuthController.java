package com.example.ledger.web;

import com.example.ledger.dto.AuthResponse;
import com.example.ledger.dto.LoginRequest;
import com.example.ledger.dto.RegisterRequest;
import com.example.ledger.dto.UpdateProfileRequest;
import com.example.ledger.dto.UserResponse;
import com.example.ledger.security.AuthUser;
import com.example.ledger.service.AuthService;
import com.example.ledger.service.AvatarService;
import jakarta.validation.Valid;
import org.springframework.core.io.FileSystemResource;
import org.springframework.core.io.Resource;
import org.springframework.http.CacheControl;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequestMapping("/api/auth")
public class AuthController {

  private final AuthService authService;
  private final AvatarService avatarService;

  public AuthController(AuthService authService, AvatarService avatarService) {
    this.authService = authService;
    this.avatarService = avatarService;
  }

  @PostMapping("/register")
  public ResponseEntity<AuthResponse> register(@Valid @RequestBody RegisterRequest request) {
    return ResponseEntity.status(HttpStatus.CREATED).body(authService.register(request));
  }

  @PostMapping("/login")
  public AuthResponse login(@Valid @RequestBody LoginRequest request) {
    return authService.login(request);
  }

  @GetMapping("/me")
  public UserResponse me(@AuthenticationPrincipal AuthUser me) {
    return authService.me(me);
  }

  @PutMapping("/me")
  public UserResponse updateMe(@AuthenticationPrincipal AuthUser me,
      @Valid @RequestBody UpdateProfileRequest request) {
    return authService.updateProfile(me, request);
  }

  @PostMapping("/me/avatar")
  public UserResponse uploadAvatar(@AuthenticationPrincipal AuthUser me,
      @RequestPart("file") MultipartFile file) {
    return avatarService.store(me, file);
  }

  /** 换图后 URL 不变，所以禁缓存，客户端不用自己加版本号。 */
  @GetMapping("/me/avatar")
  public ResponseEntity<Resource> avatar(@AuthenticationPrincipal AuthUser me) {
    AvatarService.Stored stored = avatarService.load(me);
    return ResponseEntity.ok()
        .contentType(MediaType.parseMediaType(stored.contentType()))
        .cacheControl(CacheControl.noStore())
        .body(new FileSystemResource(stored.file()));
  }
}
