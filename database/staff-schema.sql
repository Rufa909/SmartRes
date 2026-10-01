CREATE TABLE IF NOT EXISTS restaurant_tables (
 id BIGINT PRIMARY KEY AUTO_INCREMENT, code VARCHAR(32) NOT NULL UNIQUE,
 name VARCHAR(100) NOT NULL, area VARCHAR(60) NOT NULL, seats INT NOT NULL DEFAULT 4,
 guests INT NOT NULL DEFAULT 0,
 status ENUM('available','dining','waiting_payment','disabled') NOT NULL DEFAULT 'available',
 updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS categories (
 id BIGINT PRIMARY KEY AUTO_INCREMENT, name VARCHAR(120) NOT NULL UNIQUE,
 sort_order INT NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS menu_items (
 id BIGINT PRIMARY KEY AUTO_INCREMENT, category_id BIGINT NOT NULL,
 name VARCHAR(160) NOT NULL UNIQUE, description TEXT, emoji VARCHAR(20) DEFAULT '🍽️',
 price DECIMAL(12,2) NOT NULL, is_available BOOLEAN NOT NULL DEFAULT TRUE,
 FOREIGN KEY (category_id) REFERENCES categories(id)
);
CREATE TABLE IF NOT EXISTS orders (
 id BIGINT PRIMARY KEY AUTO_INCREMENT, order_code VARCHAR(40) NOT NULL UNIQUE,
 request_id VARCHAR(100) NOT NULL UNIQUE, request_hash CHAR(64) NOT NULL,
 table_id BIGINT NOT NULL, status ENUM('new','completed','cancelled') DEFAULT 'new',
 payment_status ENUM('unpaid','paid') DEFAULT 'unpaid', total_amount DECIMAL(12,2) NOT NULL,
 created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
 FOREIGN KEY (table_id) REFERENCES restaurant_tables(id)
);
CREATE TABLE IF NOT EXISTS order_items (
 id BIGINT PRIMARY KEY AUTO_INCREMENT, order_id BIGINT NOT NULL, menu_item_id BIGINT NOT NULL,
 item_name VARCHAR(160) NOT NULL, quantity INT NOT NULL, unit_price DECIMAL(12,2) NOT NULL,
 status ENUM('preparing','cooking','completed','served') NOT NULL DEFAULT 'preparing',
 served_at TIMESTAMP NULL,
 FOREIGN KEY (order_id) REFERENCES orders(id), FOREIGN KEY (menu_item_id) REFERENCES menu_items(id)
);
