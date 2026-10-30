package com.example.ledger.security;

import com.example.ledger.config.AppProperties;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.Date;
import java.util.Optional;
import javax.crypto.SecretKey;
import org.springframework.stereotype.Service;

@Service
public class JwtService {

  /** 签发结果：token 及其过期时间。 */
  public record Issued(String token, Instant expiresAt) {}

  private final SecretKey key;
  private final String issuer;
  private final long ttlSeconds;

  JwtService(AppProperties props) {
    this.key = Keys.hmacShaKeyFor(props.jwt().secret().getBytes(StandardCharsets.UTF_8));
    this.issuer = props.jwt().issuer();
    this.ttlSeconds = props.jwt().ttl().toSeconds();
  }

  public Issued issue(AuthUser user) {
    Instant now = Instant.now();
    Instant expiry = now.plusSeconds(ttlSeconds);
    String token = Jwts.builder()
        .issuer(issuer)
        .subject(String.valueOf(user.id()))
        .claim("username", user.username())
        .issuedAt(Date.from(now))
        .expiration(Date.from(expiry))
        .signWith(key)
        .compact();
    return new Issued(token, expiry);
  }

  public Optional<AuthUser> parse(String token) {
    try {
      Claims claims = Jwts.parser()
          .verifyWith(key)
          .requireIssuer(issuer)
          .build()
          .parseSignedClaims(token)
          .getPayload();
      return Optional.of(new AuthUser(Long.valueOf(claims.getSubject()), claims.get("username", String.class)));
    } catch (JwtException | IllegalArgumentException e) {
      return Optional.empty();
    }
  }
}
