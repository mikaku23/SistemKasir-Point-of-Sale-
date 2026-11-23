-- MINI POS database schema
-- MySQL 8.0+ / InnoDB / utf8mb4
-- Currency fields are stored as whole Indonesian Rupiah (no decimal fraction).

CREATE DATABASE IF NOT EXISTS mini_pos
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE mini_pos;

-- 1. Single Admin account. The application setup creates the first account.
-- Do not insert a default plaintext password here.
CREATE TABLE IF NOT EXISTS users (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    username VARCHAR(50) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    is_active TINYINT(1) NOT NULL DEFAULT 1,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_users_username (username)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 2. Product master data. Stock starts at zero and is changed through Inventory
-- or successful Sales operations, not through the Products edit form.
CREATE TABLE IF NOT EXISTS products (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    product_code VARCHAR(40) NOT NULL,
    name VARCHAR(120) NOT NULL,
    price BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Whole IDR amount',
    stock INT UNSIGNED NOT NULL DEFAULT 0,
    min_stock INT UNSIGNED NOT NULL DEFAULT 0,
    is_active TINYINT(1) NOT NULL DEFAULT 1,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_products_product_code (product_code),
    KEY idx_products_name (name),
    KEY idx_products_active_stock (is_active, stock, min_stock)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 3. A completed cash sale. A row is inserted only as part of a successful,
-- atomic sale operation. Transactions are historical records and are not deleted.
CREATE TABLE IF NOT EXISTS transactions (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    invoice_number VARCHAR(40) NOT NULL,
    user_id BIGINT UNSIGNED NOT NULL,
    total BIGINT UNSIGNED NOT NULL,
    paid BIGINT UNSIGNED NOT NULL,
    change_amount BIGINT UNSIGNED NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_transactions_invoice_number (invoice_number),
    KEY idx_transactions_created_at (created_at),
    KEY idx_transactions_user_created (user_id, created_at),
    CONSTRAINT fk_transactions_user
        FOREIGN KEY (user_id) REFERENCES users (id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_transactions_paid CHECK (paid >= total),
    CONSTRAINT chk_transactions_change CHECK (change_amount = paid - total)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 4. Immutable snapshots of the products sold at the time of each transaction.
CREATE TABLE IF NOT EXISTS transaction_details (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    transaction_id BIGINT UNSIGNED NOT NULL,
    product_id BIGINT UNSIGNED NOT NULL,
    product_code_snapshot VARCHAR(40) NOT NULL,
    product_name_snapshot VARCHAR(120) NOT NULL,
    unit_price BIGINT UNSIGNED NOT NULL,
    quantity INT UNSIGNED NOT NULL,
    subtotal BIGINT UNSIGNED NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_transaction_product (transaction_id, product_id),
    KEY idx_transaction_details_product (product_id),
    CONSTRAINT fk_transaction_details_transaction
        FOREIGN KEY (transaction_id) REFERENCES transactions (id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_transaction_details_product
        FOREIGN KEY (product_id) REFERENCES products (id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_transaction_details_quantity CHECK (quantity > 0),
    CONSTRAINT chk_transaction_details_subtotal CHECK (subtotal = unit_price * quantity)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 5. Audit trail for every stock change: receipt, manual issue, adjustment, or sale.
-- quantity is always a positive absolute amount; stock_before/stock_after show direction.
CREATE TABLE IF NOT EXISTS stock_movements (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    product_id BIGINT UNSIGNED NOT NULL,
    user_id BIGINT UNSIGNED NOT NULL,
    transaction_id BIGINT UNSIGNED NULL,
    movement_type ENUM('IN', 'OUT', 'ADJUSTMENT', 'SALE') NOT NULL,
    quantity INT UNSIGNED NOT NULL,
    stock_before INT UNSIGNED NOT NULL,
    stock_after INT UNSIGNED NOT NULL,
    notes VARCHAR(255) NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_stock_movements_product_created (product_id, created_at),
    KEY idx_stock_movements_transaction (transaction_id),
    KEY idx_stock_movements_user_created (user_id, created_at),
    CONSTRAINT fk_stock_movements_product
        FOREIGN KEY (product_id) REFERENCES products (id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_stock_movements_user
        FOREIGN KEY (user_id) REFERENCES users (id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_stock_movements_transaction
        FOREIGN KEY (transaction_id) REFERENCES transactions (id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_stock_movements_quantity CHECK (quantity > 0),
    CONSTRAINT chk_stock_movements_sale_transaction CHECK (
        (movement_type = 'SALE' AND transaction_id IS NOT NULL)
        OR (movement_type <> 'SALE' AND transaction_id IS NULL)
    )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
