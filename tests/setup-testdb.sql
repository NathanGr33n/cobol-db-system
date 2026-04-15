-- ============================================================
-- TEST DATABASE SETUP
-- Drops and recreates all tables with known seed data so
-- every test run starts from a deterministic state.
-- ============================================================

BEGIN;

-- Clean slate
DROP TABLE IF EXISTS AUDIT_LOG    CASCADE;
DROP TABLE IF EXISTS TRANSACTIONS CASCADE;
DROP TABLE IF EXISTS ACCOUNTS     CASCADE;
DROP TABLE IF EXISTS CUSTOMERS    CASCADE;

-- Recreate schema (mirrors sql/schema.sql)
CREATE TABLE CUSTOMERS (
    CUSTOMER_ID   SERIAL       PRIMARY KEY,
    FIRST_NAME    VARCHAR(50)  NOT NULL,
    LAST_NAME     VARCHAR(50)  NOT NULL,
    EMAIL         VARCHAR(100) NOT NULL UNIQUE,
    CREATED_AT    DATE         NOT NULL DEFAULT CURRENT_DATE
);

CREATE TABLE ACCOUNTS (
    ACCOUNT_ID    SERIAL         PRIMARY KEY,
    CUSTOMER_ID   INT            NOT NULL
                  REFERENCES CUSTOMERS (CUSTOMER_ID)
                  ON DELETE RESTRICT,
    BALANCE       DECIMAL(12,2)  NOT NULL DEFAULT 0.00
                  CHECK (BALANCE >= 0),
    ACCOUNT_TYPE  VARCHAR(20)    NOT NULL DEFAULT 'CHECKING'
                  CHECK (ACCOUNT_TYPE IN ('CHECKING', 'SAVINGS')),
    STATUS        VARCHAR(20)    NOT NULL DEFAULT 'ACTIVE'
                  CHECK (STATUS IN ('ACTIVE', 'CLOSED')),
    INTEREST_RATE DECIMAL(5,4)   NOT NULL DEFAULT 0.0000
                  CHECK (INTEREST_RATE >= 0
                     AND INTEREST_RATE <= 1.0000)
);

CREATE TABLE TRANSACTIONS (
    TXN_ID        SERIAL         PRIMARY KEY,
    ACCOUNT_ID    INT            NOT NULL
                  REFERENCES ACCOUNTS (ACCOUNT_ID)
                  ON DELETE RESTRICT,
    AMOUNT        DECIMAL(12,2)  NOT NULL
                  CHECK (AMOUNT > 0),
    TXN_TYPE      VARCHAR(10)    NOT NULL
                  CHECK (TXN_TYPE IN ('DEPOSIT', 'WITHDRAW',
                         'TRANSFER', 'INTEREST')),
    CREATED_AT    TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE AUDIT_LOG (
    LOG_ID        SERIAL         PRIMARY KEY,
    ACTION        VARCHAR(50)    NOT NULL,
    STATUS        VARCHAR(20)    NOT NULL
                  CHECK (STATUS IN ('SUCCESS', 'FAILURE')),
    CREATED_AT    TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- -----------------------------------------------------------
-- Seed: 3 customers, 4 accounts (1 closed), 0 transactions
-- Known starting balances for assertion checks.
-- -----------------------------------------------------------

-- Customers: IDs will be 1, 2, 3
INSERT INTO CUSTOMERS (FIRST_NAME, LAST_NAME, EMAIL) VALUES
    ('Test',  'Alpha', 'alpha@test.com'),
    ('Test',  'Beta',  'beta@test.com'),
    ('Test',  'Gamma', 'gamma@test.com');

-- Accounts:
--   ID 1 → Customer 1, CHECKING, $1000.00, ACTIVE, 0% rate
--   ID 2 → Customer 1, SAVINGS,  $5000.00, ACTIVE, 2.5% rate
--   ID 3 → Customer 2, CHECKING, $250.00,  ACTIVE, 0% rate
--   ID 4 → Customer 3, CHECKING, $0.00,    CLOSED, 0% rate
INSERT INTO ACCOUNTS (CUSTOMER_ID, BALANCE, ACCOUNT_TYPE, STATUS, INTEREST_RATE) VALUES
    (1, 1000.00, 'CHECKING', 'ACTIVE',  0.0000),
    (1, 5000.00, 'SAVINGS',  'ACTIVE',  0.0250),
    (2,  250.00, 'CHECKING', 'ACTIVE',  0.0000),
    (3,    0.00, 'CHECKING', 'CLOSED',  0.0000);

COMMIT;
