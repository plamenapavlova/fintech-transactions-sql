-- =====================================================================
-- Fintech Transactions Database - Schema
-- PostgreSQL 16
--
-- Models a digital-banking card payments system: customers on different
-- account tiers make card payments at merchants in several cities.
-- Normalized to 3NF: each fact (city, category, merchant, customer,
-- transaction) is stored exactly once and linked by foreign keys.
-- =====================================================================

DROP TABLE IF EXISTS transactions        CASCADE;
DROP TABLE IF EXISTS merchants           CASCADE;
DROP TABLE IF EXISTS merchant_categories CASCADE;
DROP TABLE IF EXISTS customers           CASCADE;
DROP TABLE IF EXISTS cities              CASCADE;

-- Cities where customers live and merchants operate
CREATE TABLE cities (
    city_id      INTEGER      PRIMARY KEY,
    city_name    VARCHAR(60)  NOT NULL,
    country_code CHAR(2)      NOT NULL,
    CONSTRAINT uq_city UNIQUE (city_name, country_code)
);

-- Customers and their account tier
CREATE TABLE customers (
    customer_id  INTEGER      PRIMARY KEY,
    full_name    VARCHAR(100) NOT NULL,
    tier         VARCHAR(10)  NOT NULL
                 CHECK (tier IN ('Standard', 'Premium', 'Metal')),
    home_city_id INTEGER      NOT NULL REFERENCES cities (city_id),
    signup_date  DATE         NOT NULL
);

-- Merchant categories (e.g. Groceries, Travel).
-- Kept in its own table so a category is a property of the merchant,
-- not repeated on every transaction.
CREATE TABLE merchant_categories (
    category_id   INTEGER     PRIMARY KEY,
    category_name VARCHAR(40) NOT NULL UNIQUE
);

-- Merchants that accept card payments
CREATE TABLE merchants (
    merchant_id   INTEGER      PRIMARY KEY,
    merchant_name VARCHAR(100) NOT NULL,
    category_id   INTEGER      NOT NULL REFERENCES merchant_categories (category_id),
    city_id       INTEGER      NOT NULL REFERENCES cities (city_id)
);

-- Card transactions (the fact table)
CREATE TABLE transactions (
    transaction_id INTEGER       PRIMARY KEY,
    customer_id    INTEGER       NOT NULL REFERENCES customers (customer_id),
    merchant_id    INTEGER       NOT NULL REFERENCES merchants (merchant_id),
    amount         NUMERIC(12,2) NOT NULL CHECK (amount > 0),
    currency       CHAR(3)       NOT NULL DEFAULT 'EUR',
    status         VARCHAR(10)   NOT NULL
                   CHECK (status IN ('COMPLETED', 'DECLINED', 'REFUNDED')),
    created_at     TIMESTAMP     NOT NULL
);

-- Indexes on foreign keys and on the timestamp, which the
-- reporting queries filter, join and group by most often.
CREATE INDEX idx_tx_customer   ON transactions (customer_id);
CREATE INDEX idx_tx_merchant   ON transactions (merchant_id);
CREATE INDEX idx_tx_created_at ON transactions (created_at);
CREATE INDEX idx_merchant_cat  ON merchants (category_id);
CREATE INDEX idx_customer_city ON customers (home_city_id);
