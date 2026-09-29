package com.example.ledger.config;

import java.time.Duration;
import java.util.List;
import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "app")
public record AppProperties(Jwt jwt, Cors cors) {

  public record Jwt(String secret, Duration ttl, String issuer) {}

  public record Cors(List<String> allowedOriginPatterns) {}
}
