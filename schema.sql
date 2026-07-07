-- =====================================================================
-- E-Commerce Cart & Checkout Module - Database Schema
-- Target: MySQL 8.x (adjust AUTO_INCREMENT / types if using Postgres/H2)
-- =====================================================================

DROP DATABASE IF EXISTS ecommerce_cart_checkout;
CREATE DATABASE ecommerce_cart_checkout;
USE ecommerce_cart_checkout;

-- ---------------------------------------------------------------------
-- 1. USER TABLE
-- ---------------------------------------------------------------------
CREATE TABLE app_user (
    id          BIGINT AUTO_INCREMENT PRIMARY KEY,
    name        VARCHAR(150)        NOT NULL,
    email       VARCHAR(150)        NOT NULL UNIQUE,
    created_at  TIMESTAMP           DEFAULT CURRENT_TIMESTAMP,
    updated_at  TIMESTAMP           DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- ---------------------------------------------------------------------
-- 2. PRODUCT TABLE
-- ---------------------------------------------------------------------
CREATE TABLE product (
    id              BIGINT AUTO_INCREMENT PRIMARY KEY,
    name            VARCHAR(200)        NOT NULL,
    description     VARCHAR(1000),
    price           DECIMAL(12,2)       NOT NULL CHECK (price >= 0),
    stock_quantity  INT                 NOT NULL DEFAULT 0 CHECK (stock_quantity >= 0),
    version         BIGINT              NOT NULL DEFAULT 0,   -- optimistic locking for stock updates
    created_at      TIMESTAMP           DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP           DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- ---------------------------------------------------------------------
-- 3. CART TABLE  (one active cart per user)
-- ---------------------------------------------------------------------
CREATE TABLE cart (
    id          BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id     BIGINT              NOT NULL,
    status      VARCHAR(20)         NOT NULL DEFAULT 'ACTIVE',  -- ACTIVE, CHECKED_OUT, ABANDONED
    created_at  TIMESTAMP           DEFAULT CURRENT_TIMESTAMP,
    updated_at  TIMESTAMP           DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_cart_user FOREIGN KEY (user_id) REFERENCES app_user(id) ON DELETE CASCADE,
    UNIQUE KEY uq_user_active_cart (user_id, status)   -- ensures one ACTIVE cart per user
);

-- ---------------------------------------------------------------------
-- 4. CART_ITEM TABLE
-- ---------------------------------------------------------------------
CREATE TABLE cart_item (
    id          BIGINT AUTO_INCREMENT PRIMARY KEY,
    cart_id     BIGINT              NOT NULL,
    product_id  BIGINT              NOT NULL,
    quantity    INT                 NOT NULL CHECK (quantity > 0),
    price       DECIMAL(12,2)       NOT NULL,   -- snapshot of unit price when added
    created_at  TIMESTAMP           DEFAULT CURRENT_TIMESTAMP,
    updated_at  TIMESTAMP           DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_cart_item_cart    FOREIGN KEY (cart_id)    REFERENCES cart(id)    ON DELETE CASCADE,
    CONSTRAINT fk_cart_item_product FOREIGN KEY (product_id) REFERENCES product(id) ON DELETE RESTRICT,
    UNIQUE KEY uq_cart_product (cart_id, product_id)   -- one row per product per cart
);

-- ---------------------------------------------------------------------
-- 5. COUPON TABLE
-- ---------------------------------------------------------------------
CREATE TABLE coupon (
    id              BIGINT AUTO_INCREMENT PRIMARY KEY,
    code            VARCHAR(50)         NOT NULL UNIQUE,
    discount_type   VARCHAR(20)         NOT NULL,   -- PERCENTAGE, FLAT
    discount_value  DECIMAL(12,2)       NOT NULL CHECK (discount_value >= 0),
    max_discount    DECIMAL(12,2)       NULL,       -- optional cap for percentage coupons
    min_cart_value  DECIMAL(12,2)       NULL DEFAULT 0,
    expiry_date     TIMESTAMP           NOT NULL,
    active          BOOLEAN             NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMP           DEFAULT CURRENT_TIMESTAMP
);

-- ---------------------------------------------------------------------
-- 6. ORDER TABLE  (named "orders" - "order" is a reserved SQL keyword)
-- ---------------------------------------------------------------------
CREATE TABLE orders (
    id                  BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id             BIGINT              NOT NULL,
    cart_id             BIGINT              NULL,
    coupon_id           BIGINT              NULL,
    subtotal_amount     DECIMAL(12,2)       NOT NULL,
    discount_amount     DECIMAL(12,2)       NOT NULL DEFAULT 0,
    total_amount        DECIMAL(12,2)       NOT NULL,
    status              VARCHAR(20)         NOT NULL DEFAULT 'PENDING',
                        -- PENDING, PAYMENT_SUCCESS, PAYMENT_FAILED, CONFIRMED, CANCELLED
    payment_reference   VARCHAR(100)        NULL,
    created_at          TIMESTAMP           DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP           DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_order_user   FOREIGN KEY (user_id)   REFERENCES app_user(id) ON DELETE RESTRICT,
    CONSTRAINT fk_order_cart   FOREIGN KEY (cart_id)   REFERENCES cart(id)     ON DELETE SET NULL,
    CONSTRAINT fk_order_coupon FOREIGN KEY (coupon_id) REFERENCES coupon(id)  ON DELETE SET NULL
);

-- ---------------------------------------------------------------------
-- 7. ORDER_ITEM TABLE
-- ---------------------------------------------------------------------
CREATE TABLE order_item (
    id          BIGINT AUTO_INCREMENT PRIMARY KEY,
    order_id    BIGINT              NOT NULL,
    product_id  BIGINT              NOT NULL,
    quantity    INT                 NOT NULL CHECK (quantity > 0),
    price       DECIMAL(12,2)       NOT NULL,   -- unit price at time of order
    line_total  DECIMAL(12,2)       NOT NULL,   -- price * quantity
    CONSTRAINT fk_order_item_order   FOREIGN KEY (order_id)   REFERENCES orders(id)  ON DELETE CASCADE,
    CONSTRAINT fk_order_item_product FOREIGN KEY (product_id) REFERENCES product(id) ON DELETE RESTRICT
);

-- ---------------------------------------------------------------------
-- Indexes for common query patterns
-- ---------------------------------------------------------------------
CREATE INDEX idx_cart_user_id          ON cart(user_id);
CREATE INDEX idx_cart_item_cart_id     ON cart_item(cart_id);
CREATE INDEX idx_cart_item_product_id ON cart_item(product_id);
CREATE INDEX idx_orders_user_id        ON orders(user_id);
CREATE INDEX idx_orders_status         ON orders(status);
CREATE INDEX idx_orders_created_at     ON orders(created_at);
CREATE INDEX idx_order_item_order_id   ON order_item(order_id);
CREATE INDEX idx_coupon_code           ON coupon(code);

-- ---------------------------------------------------------------------
-- Sample seed data (optional - useful for Postman testing)
-- ---------------------------------------------------------------------
INSERT INTO app_user (name, email) VALUES
  ('Alice Sharma', 'alice@example.com'),
  ('Bob Verma', 'bob@example.com');

INSERT INTO product (name, description, price, stock_quantity) VALUES
  ('Wireless Mouse', 'Ergonomic wireless mouse', 799.00, 50),
  ('Mechanical Keyboard', 'RGB mechanical keyboard', 3499.00, 30),
  ('USB-C Hub', '7-in-1 USB-C hub', 1999.00, 100);

INSERT INTO coupon (code, discount_type, discount_value, max_discount, min_cart_value, expiry_date) VALUES
  ('FLAT100', 'FLAT', 100.00, NULL, 500.00, '2026-12-31 23:59:59'),
  ('SAVE10', 'PERCENTAGE', 10.00, 500.00, 0.00, '2026-12-31 23:59:59');
