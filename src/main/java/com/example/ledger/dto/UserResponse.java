package com.example.ledger.dto;

import com.example.ledger.domain.User;

public record UserResponse(Long id, String username, String nickname, String email, String phone,
    boolean hasAvatar) {

  public static UserResponse of(User user) {
    return new UserResponse(user.getId(), user.getUsername(), user.getNickname(), user.getEmail(),
        user.getPhone(), !user.getAvatar().isBlank());
  }
}
