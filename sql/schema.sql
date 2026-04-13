-- ============================================================
-- COBOL-DB-SYSTEM : Database Schema
-- Target: PostgreSQL (DB2-compatible where possible)
-- ============================================================

BEGIN;

-- -----------------------------------------------------------
-- CUSTOMERS
-- -----------------------------------------------------------
CREATE TABLE IF NOT EXISTS CUSTOMERS (
    CUSTOMER_ID   SERIAL       PRIMARY KEY,
    FIRST_NAME    VARCHAR(50)  NOT NULL,
    LAST_NAME     VARCHAR(50)  NOT NULL,
    EMAIL         VARCHAR(100) NOT NULL UNIQUE,
    CREATED_AT    DATE         NOT NULL DEFAULT CURRENT_DATE
);

CREATE INDEX idx_customers_email ON CUSTOMERS (EMAIL);

-- -----------------------------------------------------------
-- ACCOUNTS
-- -----------------------------------------------------------
CREATE TABLE IF NOT EXISTS ACCOUNTS (
    ACCOUNT_ID    SERIAL         PRIMARY KEY,
    CUSTOMER_ID   INT            NOT NULL
                  REFERENCES CUSTOMERS (CUSTOMER_ID)
                  ON DELETE RESTRICT,
    BALANCE       DECIMAL(12,2)  NOT NULL DEFAULT 0.00
                  CHECK (BALANCE >= 0),
    ACCOUNT_TYPE  VARCHAR(20)    NOT NULL DEFAULT 'CHECKING'
                  CHECK (ACCOUNT_TYPE IN ('CHECKING', 'SAVINGS')),
    STATUS        VARCHAR(20)    NOT NULL DEFAULT 'ACTIVE'
                  CHECK (STATUS IN ('ACTIVE', 'CLOSED'))
);

CREATE INDEX idx_accounts_customer ON ACCOUNTS (CUSTOMER_ID);

-- -----------------------------------------------------------
-- TRANSACTIONS
-- -----------------------------------------------------------
CREATE TABLE IF NOT EXISTS TRANSACTIONS (
    TXN_ID        SERIAL         PRIMARY KEY,
    ACCOUNT_ID    INT            NOT NULL
                  REFERENCES ACCOUNTS (ACCOUNT_ID)
                  ON DELETE RESTRICT,
    AMOUNT        DECIMAL(12,2)  NOT NULL
                  CHECK (AMOUNT > 0),
    TXN_TYPE      VARCHAR(10)    NOT NULL
                  CHECK (TXN_TYPE IN ('DEPOSIT', 'WITHDRAW')),
    CREATED_AT    TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_txn_account   ON TRANSACTIONS (ACCOUNT_ID);
CREATE INDEX idx_txn_created   ON TRANSACTIONS (CREATED_AT);

-- -----------------------------------------------------------
-- AUDIT_LOG
-- -----------------------------------------------------------
CREATE TABLE IF NOT EXISTS AUDIT_LOG (
    LOG_ID        SERIAL         PRIMARY KEY,
    ACTION        VARCHAR(50)    NOT NULL,
    STATUS        VARCHAR(20)    NOT NULL
                  CHECK (STATUS IN ('SUCCESS', 'FAILURE')),
    CREATED_AT    TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_audit_created ON AUDIT_LOG (CREATED_AT);

COMMIT;
