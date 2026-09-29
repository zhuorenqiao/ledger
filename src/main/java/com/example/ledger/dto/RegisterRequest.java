package com.example.ledger.dto;

import jakarta.validation.constraints.Email;
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
    String nickname,

    @Email(message = "邮箱格式不正确") @Size(max = 255)
    String email,

    // 选填；@Pattern 整体匹配，空串走左边分支即通过，null 本身也不触发校验
    @Pattern(regexp = "|1[3-9]\\d{9}", message = "手机号格式不正确")
    String phone) {

  public String nicknameOrDefault() {
    return nickname == null || nickname.isBlank() ? username : nickname.trim();
  }

  public String emailOrEmpty() {
    return email == null ? "" : email.trim();
  }

  public String phoneOrEmpty() {
    return phone == null ? "" : phone.trim();
  }
}
