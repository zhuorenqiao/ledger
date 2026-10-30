package com.example.ledger.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/**
 * 个人中心提交的资料改动。nickname 留空时服务端回退成 username；email 与 phone 允许清空。
 */
public record UpdateProfileRequest(
    @Size(max = 32) String nickname,

    @Email(message = "邮箱格式不正确") @Size(max = 255) String email,

    @Pattern(regexp = "|1[3-9]\\d{9}", message = "手机号格式不正确") String phone) {

  public String emailOrEmpty() {
    return email == null ? "" : email.trim();
  }

  public String phoneOrEmpty() {
    return phone == null ? "" : phone.trim();
  }
}
