package com.example.ledger.security;

/** 通过 JWT 解析出来的当前登录用户，作为 Controller 的 @AuthenticationPrincipal。 */
public record AuthUser(Long id, String username) {
}
