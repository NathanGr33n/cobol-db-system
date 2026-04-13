-- ============================================================
-- TEST DATABASE TEARDOWN
-- Removes all test data. Run after test suite completes.
-- ============================================================

BEGIN;

DELETE FROM AUDIT_LOG;
DELETE FROM TRANSACTIONS;
DELETE FROM ACCOUNTS;
DELETE FROM CUSTOMERS;

-- Reset sequences so next test run gets predictable IDs
ALTER SEQUENCE customers_customer_id_seq    RESTART WITH 1;
ALTER SEQUENCE accounts_account_id_seq      RESTART WITH 1;
ALTER SEQUENCE transactions_txn_id_seq      RESTART WITH 1;
ALTER SEQUENCE audit_log_log_id_seq         RESTART WITH 1;

COMMIT;
