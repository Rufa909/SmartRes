CREATE TABLE IF NOT EXISTS cashier_invoices (
 id BIGINT PRIMARY KEY AUTO_INCREMENT,
 invoice_code VARCHAR(60) NOT NULL UNIQUE,
 table_id BIGINT NOT NULL,
 table_code VARCHAR(32) NOT NULL,
 total_amount DECIMAL(12,2) NOT NULL,
 payment_method VARCHAR(32) NOT NULL,
 paid_at TIMESTAMP NOT NULL,
 cashier_name VARCHAR(120) NOT NULL,
 snapshot JSON NOT NULL,
 INDEX idx_cashier_paid_at (paid_at,id),
 FOREIGN KEY (table_id) REFERENCES restaurant_tables(id)
);
CREATE TABLE IF NOT EXISTS invoice_adjustments (
 id BIGINT PRIMARY KEY AUTO_INCREMENT,
 invoice_code VARCHAR(60) NOT NULL,
 table_id BIGINT NOT NULL,
 actor_name VARCHAR(120) NOT NULL,
 reason VARCHAR(500) NOT NULL,
 before_snapshot JSON NOT NULL,
 after_snapshot JSON NOT NULL,
 created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
 INDEX idx_adjustment_invoice (invoice_code,id),
 FOREIGN KEY (table_id) REFERENCES restaurant_tables(id)
);
CREATE TABLE IF NOT EXISTS cashier_vouchers (
 code VARCHAR(40) PRIMARY KEY,
 percentage DECIMAL(5,2) NOT NULL,
 min_amount DECIMAL(12,2) NOT NULL DEFAULT 0,
 is_active BOOLEAN NOT NULL DEFAULT TRUE,
 starts_at TIMESTAMP NULL,
 ends_at TIMESTAMP NULL
);
CREATE TABLE IF NOT EXISTS invoice_discounts (
 first_order_id BIGINT PRIMARY KEY,
 mode ENUM('manual','voucher') NOT NULL,
 percentage DECIMAL(5,2) NOT NULL DEFAULT 0,
 voucher_code VARCHAR(40) NULL,
 FOREIGN KEY (first_order_id) REFERENCES orders(id)
);
