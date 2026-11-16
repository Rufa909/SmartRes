CREATE TABLE IF NOT EXISTS customer_service_requests (
 id BIGINT PRIMARY KEY AUTO_INCREMENT,
 table_id BIGINT NOT NULL,
 dining_session_id CHAR(36) NOT NULL,
 status ENUM('pending','acknowledged') NOT NULL DEFAULT 'pending',
 requested_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
 acknowledged_at TIMESTAMP NULL,
 INDEX idx_service_request_pending (status,requested_at),
 INDEX idx_service_request_session (dining_session_id,status),
 CONSTRAINT fk_service_request_table FOREIGN KEY (table_id) REFERENCES restaurant_tables(id),
 CONSTRAINT fk_service_request_session FOREIGN KEY (dining_session_id) REFERENCES dining_sessions(id)
);
