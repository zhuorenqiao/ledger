-- 账本后端表结构。MySQL 容器首次初始化时自动执行（docker-entrypoint-initdb.d），
-- Spring Boot 侧使用 spring.jpa.hibernate.ddl-auto=validate，只校验不建表。

CREATE TABLE IF NOT EXISTS users (
  id            BIGINT       NOT NULL AUTO_INCREMENT,
  username      VARCHAR(64)  NOT NULL,
  password_hash VARCHAR(100) NOT NULL,
  nickname      VARCHAR(64)  NOT NULL DEFAULT '',
  created_at    BIGINT       NOT NULL COMMENT 'epoch millis',
  PRIMARY KEY (id),
  UNIQUE KEY uk_users_username (username)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS txn (
  id         BIGINT        NOT NULL AUTO_INCREMENT,
  user_id    BIGINT        NOT NULL,
  type       VARCHAR(16)   NOT NULL COMMENT 'expense | income',
  category   VARCHAR(32)   NOT NULL COMMENT '分类 key，与客户端 TxnCategory.key 对应',
  amount     DECIMAL(12,2) NOT NULL,
  day        VARCHAR(10)   NOT NULL COMMENT '记账日期 yyyy-MM-dd',
  note       VARCHAR(255)  NOT NULL DEFAULT '',
  created_at BIGINT        NOT NULL COMMENT 'epoch millis',
  PRIMARY KEY (id),
  KEY idx_txn_user_day (user_id, day, created_at),
  CONSTRAINT fk_txn_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;
