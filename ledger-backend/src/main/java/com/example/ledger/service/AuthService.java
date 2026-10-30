package com.example.ledger.service;

import com.example.ledger.domain.User;
import com.example.ledger.dto.AuthResponse;
import com.example.ledger.dto.LoginRequest;
import com.example.ledger.dto.RegisterRequest;
import com.example.ledger.dto.UpdateProfileRequest;
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
        request.nicknameOrDefault(), request.emailOrEmpty(), request.phoneOrEmpty(),
        System.currentTimeMillis()));
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
    return UserResponse.of(requireUser(authUser));
  }

  @Transactional
  public UserResponse updateProfile(AuthUser authUser, UpdateProfileRequest request) {
    User user = requireUser(authUser);
    String nickname = request.nickname() == null || request.nickname().isBlank()
        ? user.getUsername()
        : request.nickname().trim();
    user.updateProfile(nickname, request.emailOrEmpty(), request.phoneOrEmpty());
    return UserResponse.of(user);
  }

  private User requireUser(AuthUser authUser) {
    return users.findById(authUser.id())
        .orElseThrow(() -> new ApiException(ErrorCode.UNAUTHORIZED, "账号不存在或已被删除"));
  }

  private AuthResponse tokenFor(User user) {
    JwtService.Issued issued = jwtService.issue(new AuthUser(user.getId(), user.getUsername()));
    return AuthResponse.of(issued.token(), issued.expiresAt(), UserResponse.of(user));
  }
}
