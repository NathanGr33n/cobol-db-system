-- ============================================================
-- COBOL-DB Banking System - Seed Data
-- Run after schema.sql
-- ============================================================

BEGIN;

-- ----------------------------------------------------------
-- CUSTOMERS
-- ----------------------------------------------------------
INSERT INTO CUSTOMERS (CUSTOMER_ID, FIRST_NAME, LAST_NAME, EMAIL, CREATED_AT) VALUES
    (1001, 'John',    'Smith',    'john.smith@email.com',    '2024-01-15'),
    (1002, 'Sarah',   'Johnson',  'sarah.johnson@email.com', '2024-02-20'),
    (1003, 'Michael', 'Williams', 'michael.w@email.com',     '2024-03-10'),
    (1004, 'Emily',   'Brown',    'emily.brown@email.com',   '2024-04-05'),
    (1005, 'David',   'Garcia',   'david.garcia@email.com',  '2024-05-12');

-- Reset sequence to next available value
SELECT setval('customers_customer_id_seq', (SELECT MAX(CUSTOMER_ID) FROM CUSTOMERS));

-- ----------------------------------------------------------
-- ACCOUNTS
-- ----------------------------------------------------------
INSERT INTO ACCOUNTS (ACCOUNT_ID, CUSTOMER_ID, BALANCE, ACCOUNT_TYPE, STATUS) VALUES
    (2001, 1001, 5000.00,  'CHECKING', 'ACTIVE'),
    (2002, 1001, 12000.00, 'SAVINGS',  'ACTIVE'),
    (2003, 1002, 3500.00,  'CHECKING', 'ACTIVE'),
    (2004, 1003, 8200.00,  'SAVINGS',  'ACTIVE'),
    (2005, 1003, 1500.00,  'CHECKING', 'ACTIVE'),
    (2006, 1004, 950.00,   'CHECKING', 'ACTIVE'),
    (2007, 1005, 22000.00, 'SAVINGS',  'ACTIVE'),
    (2008, 1005, 0.00,     'CHECKING', 'CLOSED');

SELECT setval('accounts_account_id_seq', (SELECT MAX(ACCOUNT_ID) FROM ACCOUNTS));

-- ----------------------------------------------------------
-- TRANSACTIONS
-- ----------------------------------------------------------
INSERT INTO TRANSACTIONS (ACCOUNT_ID, AMOUNT, TXN_TYPE, CREATED_AT) VALUES
    (2001, 1000.00, 'DEPOSIT',  '2024-06-01 09:00:00'),
    (2001,  200.00, 'WITHDRAW', '2024-06-02 14:30:00'),
    (2002, 5000.00, 'DEPOSIT',  '2024-06-01 10:15:00'),
    (2003, 1500.00, 'DEPOSIT',  '2024-06-03 08:45:00'),
    (2003,  300.00, 'WITHDRAW', '2024-06-04 16:00:00'),
    (2004, 2000.00, 'DEPOSIT',  '2024-06-05 11:20:00'),
    (2005,  500.00, 'DEPOSIT',  '2024-06-06 09:30:00'),
    (2006,  100.00, 'WITHDRAW', '2024-06-07 13:00:00'),
    (2007, 10000.00,'DEPOSIT',  '2024-06-08 10:00:00'),
    (2007,  3000.00,'WITHDRAW', '2024-06-09 15:45:00');

-- ----------------------------------------------------------
-- AUDIT_LOG
-- ----------------------------------------------------------
INSERT INTO AUDIT_LOG (ACTION, STATUS, DETAILS, CREATED_AT) VALUES
    ('CUSTOMER_CREATE', 'SUCCESS', 'Created customer John Smith (ID: 1001)',       '2024-01-15 08:00:00'),
    ('ACCOUNT_CREATE',  'SUCCESS', 'Created checking account 2001 for customer 1001', '2024-01-15 08:05:00'),
    ('DEPOSIT',         'SUCCESS', 'Deposited 1000.00 to account 2001',            '2024-06-01 09:00:00'),
    ('WITHDRAW',        'SUCCESS', 'Withdrew 200.00 from account 2001',            '2024-06-02 14:30:00'),
    ('DEPOSIT',         'SUCCESS', 'Deposited 5000.00 to account 2002',            '2024-06-01 10:15:00');

COMMIT;
