-- ============================================================
-- COBOL-DB-SYSTEM : Seed Data
-- ============================================================

BEGIN;

-- -----------------------------------------------------------
-- Customers
-- -----------------------------------------------------------
INSERT INTO CUSTOMERS (FIRST_NAME, LAST_NAME, EMAIL, CREATED_AT) VALUES
    ('Alice',   'Johnson',  'alice.johnson@example.com',  '2025-01-15'),
    ('Bob',     'Smith',    'bob.smith@example.com',      '2025-02-20'),
    ('Carol',   'Williams', 'carol.williams@example.com', '2025-03-10'),
    ('David',   'Brown',    'david.brown@example.com',    '2025-04-05'),
    ('Eve',     'Davis',    'eve.davis@example.com',      '2025-05-01');

-- -----------------------------------------------------------
-- Accounts
-- -----------------------------------------------------------
INSERT INTO ACCOUNTS (CUSTOMER_ID, BALANCE, ACCOUNT_TYPE, STATUS, INTEREST_RATE) VALUES
    (1, 5000.00,  'CHECKING', 'ACTIVE',  0.0000),
    (1, 12000.00, 'SAVINGS',  'ACTIVE',  0.0250),
    (2, 3200.50,  'CHECKING', 'ACTIVE',  0.0000),
    (3, 750.00,   'SAVINGS',  'ACTIVE',  0.0250),
    (4, 0.00,     'CHECKING', 'CLOSED',  0.0000),
    (5, 9800.75,  'CHECKING', 'ACTIVE',  0.0000);

-- -----------------------------------------------------------
-- Transactions
-- -----------------------------------------------------------
INSERT INTO TRANSACTIONS (ACCOUNT_ID, AMOUNT, TXN_TYPE, CREATED_AT) VALUES
    (1, 1000.00, 'DEPOSIT',  '2025-06-01 09:00:00'),
    (1,  200.00, 'WITHDRAW', '2025-06-02 14:30:00'),
    (2, 5000.00, 'DEPOSIT',  '2025-06-01 10:00:00'),
    (3,  500.00, 'DEPOSIT',  '2025-06-03 11:15:00'),
    (3,  100.50, 'WITHDRAW', '2025-06-04 16:45:00'),
    (6, 2000.00, 'DEPOSIT',  '2025-06-05 08:20:00');

-- -----------------------------------------------------------
-- Audit Log
-- -----------------------------------------------------------
INSERT INTO AUDIT_LOG (ACTION, STATUS, CREATED_AT) VALUES
    ('DEPOSIT  - ACCT 1',  'SUCCESS', '2025-06-01 09:00:01'),
    ('WITHDRAW - ACCT 1',  'SUCCESS', '2025-06-02 14:30:01'),
    ('DEPOSIT  - ACCT 2',  'SUCCESS', '2025-06-01 10:00:01'),
    ('DEPOSIT  - ACCT 3',  'SUCCESS', '2025-06-03 11:15:01'),
    ('WITHDRAW - ACCT 3',  'SUCCESS', '2025-06-04 16:45:01'),
    ('DEPOSIT  - ACCT 6',  'SUCCESS', '2025-06-05 08:20:01');

COMMIT;
