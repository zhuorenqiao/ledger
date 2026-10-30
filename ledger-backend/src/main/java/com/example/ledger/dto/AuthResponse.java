package com.example.ledger.dto;

import java.time.Instant;

public record AuthResponse(String token, String tokenType, Instant expiresAt, UserResponse user) {

  public static AuthResponse of(String token, Instant expiresAt, UserResponse user) {
    return new AuthResponse(token, "Bearer", expiresAt, user);
  }
}
