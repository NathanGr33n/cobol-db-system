-- ============================================================
-- Migration 001: Database Improvements
-- - Add TRANSFER to TXN_TYPE check constraint
-- - Add RELATED_TXN_ID to TRANSACTIONS for transfer linking
-- - Add PHONE to CUSTOMERS
-- - Add CREATED_AT to ACCOUNTS
-- - Add stored procedures for core operations
-- ============================================================

BEGIN;

-- ----------------------------------------------------------
-- 6a: Allow TRANSFER in TXN_TYPE and add related txn link
-- ----------------------------------------------------------
ALTER TABLE TRANSACTIONS
    DROP CONSTRAINT IF EXISTS transactions_txn_type_check;

ALTER TABLE TRANSACTIONS
    ADD CONSTRAINT transactions_txn_type_check
    CHECK (TXN_TYPE IN ('DEPOSIT', 'WITHDRAW', 'TRANSFER'));

ALTER TABLE TRANSACTIONS
    ADD COLUMN IF NOT EXISTS RELATED_TXN_ID INT
    REFERENCES TRANSACTIONS (TXN_ID) ON DELETE SET NULL;

-- ----------------------------------------------------------
-- 6c: Add PHONE column to CUSTOMERS
-- ----------------------------------------------------------
ALTER TABLE CUSTOMERS
    ADD COLUMN IF NOT EXISTS PHONE VARCHAR(20);

-- ----------------------------------------------------------
-- 6d: Add CREATED_AT timestamp to ACCOUNTS
-- ----------------------------------------------------------
ALTER TABLE ACCOUNTS
    ADD COLUMN IF NOT EXISTS CREATED_AT TIMESTAMP
    DEFAULT CURRENT_TIMESTAMP;

-- ----------------------------------------------------------
-- 6b: Stored procedures for core banking operations
-- ----------------------------------------------------------

-- Deposit procedure
CREATE OR REPLACE FUNCTION fn_deposit(
    p_account_id INT,
    p_amount DECIMAL(12,2)
) RETURNS TABLE(new_balance DECIMAL(12,2), txn_id INT) AS $$
DECLARE
    v_balance DECIMAL(12,2);
    v_status VARCHAR(20);
    v_txn_id INT;
BEGIN
    -- Validate account
    SELECT BALANCE, STATUS INTO v_balance, v_status
    FROM ACCOUNTS WHERE ACCOUNT_ID = p_account_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Account % not found', p_account_id;
    END IF;

    IF v_status <> 'ACTIVE' THEN
        RAISE EXCEPTION 'Account % is not active', p_account_id;
    END IF;

    IF p_amount <= 0 THEN
        RAISE EXCEPTION 'Amount must be greater than zero';
    END IF;

    -- Update balance
    UPDATE ACCOUNTS SET BALANCE = BALANCE + p_amount
    WHERE ACCOUNT_ID = p_account_id;

    -- Record transaction
    INSERT INTO TRANSACTIONS (ACCOUNT_ID, AMOUNT, TXN_TYPE)
    VALUES (p_account_id, p_amount, 'DEPOSIT')
    RETURNING TXN_ID INTO v_txn_id;

    -- Audit
    INSERT INTO AUDIT_LOG (ACTION, STATUS, DETAILS)
    VALUES ('DEPOSIT', 'SUCCESS',
            'Deposited ' || p_amount || ' to account ' || p_account_id);

    RETURN QUERY SELECT BALANCE, v_txn_id
    FROM ACCOUNTS WHERE ACCOUNT_ID = p_account_id;
END;
$$ LANGUAGE plpgsql;

-- Withdraw procedure
CREATE OR REPLACE FUNCTION fn_withdraw(
    p_account_id INT,
    p_amount DECIMAL(12,2)
) RETURNS TABLE(new_balance DECIMAL(12,2), txn_id INT) AS $$
DECLARE
    v_balance DECIMAL(12,2);
    v_status VARCHAR(20);
    v_txn_id INT;
BEGIN
    SELECT BALANCE, STATUS INTO v_balance, v_status
    FROM ACCOUNTS WHERE ACCOUNT_ID = p_account_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Account % not found', p_account_id;
    END IF;

    IF v_status <> 'ACTIVE' THEN
        RAISE EXCEPTION 'Account % is not active', p_account_id;
    END IF;

    IF p_amount <= 0 THEN
        RAISE EXCEPTION 'Amount must be greater than zero';
    END IF;

    IF p_amount > v_balance THEN
        RAISE EXCEPTION 'Insufficient funds: requested %, available %',
            p_amount, v_balance;
    END IF;

    UPDATE ACCOUNTS SET BALANCE = BALANCE - p_amount
    WHERE ACCOUNT_ID = p_account_id;

    INSERT INTO TRANSACTIONS (ACCOUNT_ID, AMOUNT, TXN_TYPE)
    VALUES (p_account_id, p_amount, 'WITHDRAW')
    RETURNING TXN_ID INTO v_txn_id;

    INSERT INTO AUDIT_LOG (ACTION, STATUS, DETAILS)
    VALUES ('WITHDRAW', 'SUCCESS',
            'Withdrew ' || p_amount || ' from account ' || p_account_id);

    RETURN QUERY SELECT BALANCE, v_txn_id
    FROM ACCOUNTS WHERE ACCOUNT_ID = p_account_id;
END;
$$ LANGUAGE plpgsql;

-- Transfer procedure (atomic)
CREATE OR REPLACE FUNCTION fn_transfer(
    p_from_account INT,
    p_to_account INT,
    p_amount DECIMAL(12,2)
) RETURNS VOID AS $$
DECLARE
    v_from_balance DECIMAL(12,2);
    v_from_status VARCHAR(20);
    v_to_status VARCHAR(20);
    v_debit_txn INT;
    v_credit_txn INT;
BEGIN
    IF p_from_account = p_to_account THEN
        RAISE EXCEPTION 'Cannot transfer to the same account';
    END IF;

    IF p_amount <= 0 THEN
        RAISE EXCEPTION 'Amount must be greater than zero';
    END IF;

    -- Validate FROM
    SELECT BALANCE, STATUS INTO v_from_balance, v_from_status
    FROM ACCOUNTS WHERE ACCOUNT_ID = p_from_account;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'From account % not found', p_from_account;
    END IF;
    IF v_from_status <> 'ACTIVE' THEN
        RAISE EXCEPTION 'From account % is not active', p_from_account;
    END IF;
    IF p_amount > v_from_balance THEN
        RAISE EXCEPTION 'Insufficient funds in account %', p_from_account;
    END IF;

    -- Validate TO
    SELECT STATUS INTO v_to_status
    FROM ACCOUNTS WHERE ACCOUNT_ID = p_to_account;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'To account % not found', p_to_account;
    END IF;
    IF v_to_status <> 'ACTIVE' THEN
        RAISE EXCEPTION 'To account % is not active', p_to_account;
    END IF;

    -- Debit
    UPDATE ACCOUNTS SET BALANCE = BALANCE - p_amount
    WHERE ACCOUNT_ID = p_from_account;

    INSERT INTO TRANSACTIONS (ACCOUNT_ID, AMOUNT, TXN_TYPE)
    VALUES (p_from_account, p_amount, 'TRANSFER')
    RETURNING TXN_ID INTO v_debit_txn;

    -- Credit
    UPDATE ACCOUNTS SET BALANCE = BALANCE + p_amount
    WHERE ACCOUNT_ID = p_to_account;

    INSERT INTO TRANSACTIONS (ACCOUNT_ID, AMOUNT, TXN_TYPE, RELATED_TXN_ID)
    VALUES (p_to_account, p_amount, 'TRANSFER', v_debit_txn)
    RETURNING TXN_ID INTO v_credit_txn;

    -- Link debit to credit
    UPDATE TRANSACTIONS SET RELATED_TXN_ID = v_credit_txn
    WHERE TXN_ID = v_debit_txn;

    -- Audit
    INSERT INTO AUDIT_LOG (ACTION, STATUS, DETAILS)
    VALUES ('TRANSFER', 'SUCCESS',
            'Transferred ' || p_amount ||
            ' from account ' || p_from_account ||
            ' to account ' || p_to_account);
END;
$$ LANGUAGE plpgsql;

COMMIT;
