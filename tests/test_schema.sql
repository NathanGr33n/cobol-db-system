-- ============================================================
-- COBOL-DB Banking System - Schema Validation Tests
-- Run against a fresh database after schema.sql + seed_data.sql
-- Each test should produce PASS or FAIL output
-- ============================================================

\echo '============================================'
\echo '  SCHEMA VALIDATION TESTS'
\echo '============================================'

-- ----------------------------------------------------------
-- Test 1: All tables exist
-- ----------------------------------------------------------
\echo ''
\echo 'Test 1: Verify all tables exist'
DO $$
DECLARE
    tbl TEXT;
    tables TEXT[] := ARRAY['customers', 'accounts', 'transactions', 'audit_log'];
BEGIN
    FOREACH tbl IN ARRAY tables LOOP
        IF EXISTS (SELECT 1 FROM information_schema.tables
                   WHERE table_name = tbl AND table_schema = 'public') THEN
            RAISE NOTICE '  PASS: Table % exists', tbl;
        ELSE
            RAISE NOTICE '  FAIL: Table % does not exist', tbl;
        END IF;
    END LOOP;
END $$;

-- ----------------------------------------------------------
-- Test 2: CHECK constraint - negative balance rejected
-- ----------------------------------------------------------
\echo ''
\echo 'Test 2: CHECK constraint - negative balance rejected'
DO $$
BEGIN
    UPDATE ACCOUNTS SET BALANCE = -100 WHERE ACCOUNT_ID = 2001;
    RAISE NOTICE '  FAIL: Negative balance was accepted';
EXCEPTION WHEN check_violation THEN
    RAISE NOTICE '  PASS: Negative balance correctly rejected';
END $$;

-- ----------------------------------------------------------
-- Test 3: CHECK constraint - invalid account type rejected
-- ----------------------------------------------------------
\echo ''
\echo 'Test 3: CHECK constraint - invalid account type rejected'
DO $$
BEGIN
    INSERT INTO ACCOUNTS (CUSTOMER_ID, BALANCE, ACCOUNT_TYPE, STATUS)
    VALUES (1001, 100, 'INVALID', 'ACTIVE');
    RAISE NOTICE '  FAIL: Invalid account type was accepted';
EXCEPTION WHEN check_violation THEN
    RAISE NOTICE '  PASS: Invalid account type correctly rejected';
END $$;

-- ----------------------------------------------------------
-- Test 4: CHECK constraint - invalid transaction type rejected
-- ----------------------------------------------------------
\echo ''
\echo 'Test 4: CHECK constraint - invalid TXN_TYPE rejected'
DO $$
BEGIN
    INSERT INTO TRANSACTIONS (ACCOUNT_ID, AMOUNT, TXN_TYPE)
    VALUES (2001, 100, 'INVALID');
    RAISE NOTICE '  FAIL: Invalid TXN_TYPE was accepted';
EXCEPTION WHEN check_violation THEN
    RAISE NOTICE '  PASS: Invalid TXN_TYPE correctly rejected';
END $$;

-- ----------------------------------------------------------
-- Test 5: CHECK constraint - zero/negative amount rejected
-- ----------------------------------------------------------
\echo ''
\echo 'Test 5: CHECK constraint - zero amount rejected'
DO $$
BEGIN
    INSERT INTO TRANSACTIONS (ACCOUNT_ID, AMOUNT, TXN_TYPE)
    VALUES (2001, 0, 'DEPOSIT');
    RAISE NOTICE '  FAIL: Zero amount was accepted';
EXCEPTION WHEN check_violation THEN
    RAISE NOTICE '  PASS: Zero amount correctly rejected';
END $$;

-- ----------------------------------------------------------
-- Test 6: FK constraint - account for non-existent customer
-- ----------------------------------------------------------
\echo ''
\echo 'Test 6: FK constraint - account for non-existent customer'
DO $$
BEGIN
    INSERT INTO ACCOUNTS (CUSTOMER_ID, BALANCE, ACCOUNT_TYPE, STATUS)
    VALUES (99999, 100, 'CHECKING', 'ACTIVE');
    RAISE NOTICE '  FAIL: Non-existent customer FK was accepted';
EXCEPTION WHEN foreign_key_violation THEN
    RAISE NOTICE '  PASS: Non-existent customer FK correctly rejected';
END $$;

-- ----------------------------------------------------------
-- Test 7: FK constraint - transaction for non-existent account
-- ----------------------------------------------------------
\echo ''
\echo 'Test 7: FK constraint - transaction for non-existent account'
DO $$
BEGIN
    INSERT INTO TRANSACTIONS (ACCOUNT_ID, AMOUNT, TXN_TYPE)
    VALUES (99999, 100, 'DEPOSIT');
    RAISE NOTICE '  FAIL: Non-existent account FK was accepted';
EXCEPTION WHEN foreign_key_violation THEN
    RAISE NOTICE '  PASS: Non-existent account FK correctly rejected';
END $$;

-- ----------------------------------------------------------
-- Test 8: UNIQUE constraint - duplicate email rejected
-- ----------------------------------------------------------
\echo ''
\echo 'Test 8: UNIQUE constraint - duplicate email rejected'
DO $$
BEGIN
    INSERT INTO CUSTOMERS (FIRST_NAME, LAST_NAME, EMAIL)
    VALUES ('Test', 'User', 'john.smith@email.com');
    RAISE NOTICE '  FAIL: Duplicate email was accepted';
EXCEPTION WHEN unique_violation THEN
    RAISE NOTICE '  PASS: Duplicate email correctly rejected';
END $$;

-- ----------------------------------------------------------
-- Test 9: UNIQUE constraint - case-insensitive duplicate email
-- ----------------------------------------------------------
\echo ''
\echo 'Test 9: UNIQUE constraint - case-insensitive duplicate email'
DO $$
BEGIN
    INSERT INTO CUSTOMERS (FIRST_NAME, LAST_NAME, EMAIL)
    VALUES ('Case', 'Duplicate', 'JOHN.SMITH@EMAIL.COM');
    RAISE NOTICE '  FAIL: Case-insensitive duplicate email was accepted';
EXCEPTION WHEN unique_violation THEN
    RAISE NOTICE '  PASS: Case-insensitive duplicate email rejected';
END $$;

-- ----------------------------------------------------------
-- Test 10: CHECK constraint - invalid email format rejected
-- ----------------------------------------------------------
\echo ''
\echo 'Test 10: CHECK constraint - invalid email format rejected'
DO $$
BEGIN
    INSERT INTO CUSTOMERS (FIRST_NAME, LAST_NAME, EMAIL)
    VALUES ('Invalid', 'Email', 'not-an-email');
    RAISE NOTICE '  FAIL: Invalid email format was accepted';
EXCEPTION WHEN check_violation THEN
    RAISE NOTICE '  PASS: Invalid email format correctly rejected';
END $$;

-- ----------------------------------------------------------
-- Test 11: Audit trigger fires on balance update
-- ----------------------------------------------------------
\echo ''
\echo 'Test 11: Audit trigger fires on balance update'
DO $$
DECLARE
    v_count_before INT;
    v_count_after INT;
BEGIN
    SELECT COUNT(*) INTO v_count_before FROM AUDIT_LOG
    WHERE ACTION = 'BALANCE_UPDATE';

    UPDATE ACCOUNTS SET BALANCE = BALANCE + 0.01
    WHERE ACCOUNT_ID = 2001;

    SELECT COUNT(*) INTO v_count_after FROM AUDIT_LOG
    WHERE ACTION = 'BALANCE_UPDATE';

    -- Revert the change
    UPDATE ACCOUNTS SET BALANCE = BALANCE - 0.01
    WHERE ACCOUNT_ID = 2001;

    IF v_count_after > v_count_before THEN
        RAISE NOTICE '  PASS: Audit trigger fired on balance update';
    ELSE
        RAISE NOTICE '  FAIL: Audit trigger did not fire';
    END IF;
END $$;

-- ----------------------------------------------------------
-- Test 12: Seed data integrity
-- ----------------------------------------------------------
\echo ''
\echo 'Test 12: Seed data integrity'
DO $$
DECLARE
    v_cust INT;
    v_acct INT;
    v_txn INT;
BEGIN
    SELECT COUNT(*) INTO v_cust FROM CUSTOMERS;
    SELECT COUNT(*) INTO v_acct FROM ACCOUNTS;
    SELECT COUNT(*) INTO v_txn FROM TRANSACTIONS;

    IF v_cust >= 5 THEN
        RAISE NOTICE '  PASS: % customers loaded', v_cust;
    ELSE
        RAISE NOTICE '  FAIL: Expected >= 5 customers, got %', v_cust;
    END IF;

    IF v_acct >= 8 THEN
        RAISE NOTICE '  PASS: % accounts loaded', v_acct;
    ELSE
        RAISE NOTICE '  FAIL: Expected >= 8 accounts, got %', v_acct;
    END IF;

    IF v_txn >= 10 THEN
        RAISE NOTICE '  PASS: % transactions loaded', v_txn;
    ELSE
        RAISE NOTICE '  FAIL: Expected >= 10 transactions, got %', v_txn;
    END IF;
END $$;

-- ----------------------------------------------------------
-- Test 11: Migration - PHONE column exists on CUSTOMERS
-- ----------------------------------------------------------
\echo ''
\echo 'Test 11: Migration - PHONE column exists on CUSTOMERS'
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_name = 'customers'
                 AND column_name = 'phone'
                 AND table_schema = 'public') THEN
        RAISE NOTICE '  PASS: PHONE column exists on CUSTOMERS';
    ELSE
        RAISE NOTICE '  FAIL: PHONE column not found on CUSTOMERS';
    END IF;
END $$;

-- ----------------------------------------------------------
-- Test 12: Migration - TRANSFER TXN_TYPE is accepted
-- ----------------------------------------------------------
\echo ''
\echo 'Test 12: Migration - TRANSFER TXN_TYPE is accepted'
DO $$
DECLARE
    v_txn_id INT;
BEGIN
    INSERT INTO TRANSACTIONS (ACCOUNT_ID, AMOUNT, TXN_TYPE)
    VALUES (2001, 1.00, 'TRANSFER')
    RETURNING TXN_ID INTO v_txn_id;

    DELETE FROM TRANSACTIONS WHERE TXN_ID = v_txn_id;

    RAISE NOTICE '  PASS: TRANSFER TXN_TYPE accepted';
EXCEPTION WHEN check_violation THEN
    RAISE NOTICE '  FAIL: TRANSFER TXN_TYPE rejected';
END $$;

-- ----------------------------------------------------------
-- Test 13: Migration - RELATED_TXN_ID column exists
-- ----------------------------------------------------------
\echo ''
\echo 'Test 13: Migration - RELATED_TXN_ID column exists on TRANSACTIONS'
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_name = 'transactions'
                 AND column_name = 'related_txn_id'
                 AND table_schema = 'public') THEN
        RAISE NOTICE '  PASS: RELATED_TXN_ID column exists';
    ELSE
        RAISE NOTICE '  FAIL: RELATED_TXN_ID column not found';
    END IF;
END $$;

-- ----------------------------------------------------------
-- Test 14: Migration - CREATED_AT column exists on ACCOUNTS
-- ----------------------------------------------------------
\echo ''
\echo 'Test 14: Migration - CREATED_AT column exists on ACCOUNTS'
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_name = 'accounts'
                 AND column_name = 'created_at'
                 AND table_schema = 'public') THEN
        RAISE NOTICE '  PASS: CREATED_AT column exists on ACCOUNTS';
    ELSE
        RAISE NOTICE '  FAIL: CREATED_AT column not found on ACCOUNTS';
    END IF;
END $$;

-- ----------------------------------------------------------
-- Test 15: Migration - Stored procedures exist
-- ----------------------------------------------------------
\echo ''
\echo 'Test 15: Migration - Stored procedures exist'
DO $$
DECLARE
    fn TEXT;
    fns TEXT[] := ARRAY['fn_deposit', 'fn_withdraw', 'fn_transfer'];
BEGIN
    FOREACH fn IN ARRAY fns LOOP
        IF EXISTS (SELECT 1 FROM information_schema.routines
                   WHERE routine_name = fn
                     AND routine_schema = 'public') THEN
            RAISE NOTICE '  PASS: Function % exists', fn;
        ELSE
            RAISE NOTICE '  FAIL: Function % not found', fn;
        END IF;
    END LOOP;
END $$;

\echo ''
\echo '============================================'
\echo '  TESTS COMPLETE'
\echo '============================================'
