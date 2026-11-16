ALTER TABLE menu_items ADD COLUMN image_url VARCHAR(2048) NULL;
ALTER TABLE menu_items ADD COLUMN version BIGINT NOT NULL DEFAULT 1;
ALTER TABLE categories ADD COLUMN version BIGINT NOT NULL DEFAULT 1;
CREATE TABLE IF NOT EXISTS menu_audit (
 id BIGINT PRIMARY KEY AUTO_INCREMENT,
 actor_id BIGINT NOT NULL,
 actor_name VARCHAR(120) NOT NULL,
 action VARCHAR(40) NOT NULL,
 entity_id BIGINT NOT NULL,
 before_data JSON NULL,
 after_data JSON NOT NULL,
 created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS menu_item_options (
 id BIGINT PRIMARY KEY AUTO_INCREMENT,
 menu_item_id BIGINT NOT NULL,
 group_name VARCHAR(100) NOT NULL,
 option_name VARCHAR(100) NOT NULL,
 extra_price DECIMAL(12,2) NOT NULL DEFAULT 0,
 CONSTRAINT fk_options_menu_item FOREIGN KEY (menu_item_id) REFERENCES menu_items(id) ON DELETE CASCADE,
 INDEX idx_menu_item_options_group (menu_item_id,group_name,id)
);
