CREATE TABLE IF NOT EXISTS dining_sessions (
 id CHAR(36) PRIMARY KEY,
 table_id BIGINT NOT NULL,
 join_code CHAR(6) NOT NULL,
 expires_at DATETIME NOT NULL,
 revoked_at DATETIME NULL,
 failed_attempts INT NOT NULL DEFAULT 0,
 locked_until DATETIME NULL,
 created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
 INDEX (table_id, revoked_at),
 FOREIGN KEY (table_id) REFERENCES restaurant_tables(id)
);
CREATE TABLE IF NOT EXISTS customer_session_tokens (
 token_hash CHAR(64) PRIMARY KEY,
 session_id CHAR(36) NOT NULL,
 created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
 FOREIGN KEY (session_id) REFERENCES dining_sessions(id)
);
