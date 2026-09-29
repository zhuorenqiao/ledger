package com.example.ledger.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record RegisterRequest(
    @NotBlank @Size(min = 3, max = 32)
    @Pattern(regexp = "[A-Za-z0-9_.-]+", message = "用户名只能包含字母、数字、下划线、点和横线")
    String username,

    @NotBlank @Size(min = 6, max = 64)
    String password,

    @Size(max = 32)
    String nickname) {

  public String nicknameOrDefault() {
    return nickname == null || nickname.isBlank() ? username : nickname.trim();
  }
}
