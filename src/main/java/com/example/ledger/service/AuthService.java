package com.example.ledger.service;

import com.example.ledger.domain.User;
import com.example.ledger.dto.AuthResponse;
import com.example.ledger.dto.LoginRequest;
import com.example.ledger.dto.RegisterRequest;
import com.example.ledger.dto.UserResponse;
import com.example.ledger.repository.UserRepository;
import com.example.ledger.security.AuthUser;
import com.example.ledger.security.JwtService;
import com.example.ledger.web.ApiException;
import com.example.ledger.web.ErrorCode;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AuthService {

  private final UserRepository users;
  private final PasswordEncoder passwordEncoder;
  private final JwtService jwtService;

  public AuthService(UserRepository users, PasswordEncoder passwordEncoder, JwtService jwtService) {
    this.users = users;
    this.passwordEncoder = passwordEncoder;
    this.jwtService = jwtService;
  }

  @Transactional
  public AuthResponse register(RegisterRequest request) {
    String username = request.username().trim();
    if (users.existsByUsername(username)) {
      throw new ApiException(ErrorCode.USERNAME_TAKEN, "用户名 " + username + " 已被占用");
    }
    User saved = users.save(new User(username, passwordEncoder.encode(request.password()),
        request.nicknameOrDefault(), System.currentTimeMillis()));
    return tokenFor(saved);
  }

  @Transactional(readOnly = true)
  public AuthResponse login(LoginRequest request) {
    User user = users.findByUsername(request.username().trim())
        .filter(u -> passwordEncoder.matches(request.password(), u.getPasswordHash()))
        .orElseThrow(() -> new ApiException(ErrorCode.LOGIN_FAILED));
    return tokenFor(user);
  }

  @Transactional(readOnly = true)
  public UserResponse me(AuthUser authUser) {
    User user = users.findById(authUser.id())
        .orElseThrow(() -> new ApiException(ErrorCode.UNAUTHORIZED, "账号不存在或已被删除"));
    return toResponse(user);
  }

  private AuthResponse tokenFor(User user) {
    JwtService.Issued issued = jwtService.issue(new AuthUser(user.getId(), user.getUsername()));
    return AuthResponse.of(issued.token(), issued.expiresAt(), toResponse(user));
  }

  private static UserResponse toResponse(User user) {
    return new UserResponse(user.getId(), user.getUsername(), user.getNickname());
  }
}
