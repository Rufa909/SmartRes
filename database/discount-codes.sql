CREATE TABLE IF NOT EXISTS discount_codes (
 id BIGINT PRIMARY KEY AUTO_INCREMENT,
 discount_name VARCHAR(120) NOT NULL,
 discount_code VARCHAR(64) NOT NULL UNIQUE,
 code_mode ENUM('manual','auto') NOT NULL,
 total_quantity INT UNSIGNED NOT NULL,
 used_quantity INT UNSIGNED NOT NULL DEFAULT 0,
 discount_type ENUM('percentage','fixed') NOT NULL,
 discount_percent DECIMAL(5,2) NULL,
 fixed_amount DECIMAL(12,0) NULL,
 max_discount_amount DECIMAL(12,0) NULL,
 min_order_value DECIMAL(12,0) NOT NULL DEFAULT 0,
 is_active BOOLEAN NOT NULL DEFAULT TRUE,
 is_always_active BOOLEAN NOT NULL DEFAULT FALSE,
 all_day BOOLEAN NOT NULL DEFAULT TRUE,
 start_time VARCHAR(5) NULL,
 end_time VARCHAR(5) NULL,
 weekdays JSON NOT NULL,
 start_date DATE NULL,
 end_date DATE NULL,
 version BIGINT NOT NULL DEFAULT 1,
 created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
 updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS invoice_discount_codes (
 first_order_id BIGINT PRIMARY KEY,
 discount_id BIGINT NOT NULL,
 FOREIGN KEY (first_order_id) REFERENCES orders(id),
 FOREIGN KEY (discount_id) REFERENCES discount_codes(id)
);
CREATE TABLE IF NOT EXISTS discount_redemptions (
 id BIGINT PRIMARY KEY AUTO_INCREMENT,
 discount_id BIGINT NOT NULL,
 first_order_id BIGINT NOT NULL UNIQUE,
 invoice_code VARCHAR(60) NOT NULL,
 redeemed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
 FOREIGN KEY (discount_id) REFERENCES discount_codes(id),
 FOREIGN KEY (first_order_id) REFERENCES orders(id)
);
