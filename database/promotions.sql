CREATE TABLE IF NOT EXISTS promotions (
 id BIGINT PRIMARY KEY AUTO_INCREMENT,
 name VARCHAR(120) NOT NULL,
 discount_type ENUM('percentage','fixed') NOT NULL,
 discount_value DECIMAL(12,2) NOT NULL,
 max_discount_amount DECIMAL(12,0) NULL,
 min_bill_amount DECIMAL(12,0) NOT NULL DEFAULT 0,
 is_active BOOLEAN NOT NULL DEFAULT TRUE,
 is_always_active BOOLEAN NOT NULL DEFAULT TRUE,
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
CREATE TABLE IF NOT EXISTS invoice_promotions (
 first_order_id BIGINT PRIMARY KEY,
 promotion_id BIGINT NOT NULL,
 FOREIGN KEY (first_order_id) REFERENCES orders(id),
 FOREIGN KEY (promotion_id) REFERENCES promotions(id)
);
