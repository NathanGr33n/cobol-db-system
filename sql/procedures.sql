-- ============================================================
-- COBOL-DB-SYSTEM : Stored Procedures
-- PostgreSQL functions encapsulating core banking operations.
-- Callable from COBOL via EXEC SQL CALL or from the API layer.
-- ============================================================

BEGIN;

-- -----------------------------------------------------------
-- fn_process_deposit
-- Validates account, updates balance, records transaction,
-- writes audit log. Returns new balance.
-- -----------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_process_deposit(
    p_account_id INT,
    p_amount     DECIMAL(12,2)
) RETURNS DECIMAL(12,2)
LANGUAGE plpgsql
AS $$
DECLARE
    v_balance DECIMAL(12,2);
    v_status  VARCHAR(20);
BEGIN
    IF p_amount <= 0 THEN
        RAISE EXCEPTION 'Amount must be greater than zero';
    END IF;

    SELECT BALANCE, STATUS
    INTO   v_balance, v_status
    FROM   ACCOUNTS
    WHERE  ACCOUNT_ID = p_account_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Account % not found', p_account_id;
    END IF;

    IF v_status <> 'ACTIVE' THEN
        RAISE EXCEPTION 'Account % is not active', p_account_id;
    END IF;

    v_balance := v_balance + p_amount;

    UPDATE ACCOUNTS
    SET    BALANCE = v_balance
    WHERE  ACCOUNT_ID = p_account_id;

    INSERT INTO TRANSACTIONS (ACCOUNT_ID, AMOUNT, TXN_TYPE)
    VALUES (p_account_id, p_amount, 'DEPOSIT');

    INSERT INTO AUDIT_LOG (ACTION, STATUS)
    VALUES ('DEPOSIT  - ACCT ' || p_account_id, 'SUCCESS');

    RETURN v_balance;
END;
$$;

-- -----------------------------------------------------------
-- fn_process_withdrawal
-- Validates account, checks sufficient funds, updates balance,
-- records transaction, writes audit log. Returns new balance.
-- -----------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_process_withdrawal(
    p_account_id INT,
    p_amount     DECIMAL(12,2)
) RETURNS DECIMAL(12,2)
LANGUAGE plpgsql
AS $$
DECLARE
    v_balance DECIMAL(12,2);
    v_status  VARCHAR(20);
BEGIN
    IF p_amount <= 0 THEN
        RAISE EXCEPTION 'Amount must be greater than zero';
    END IF;

    SELECT BALANCE, STATUS
    INTO   v_balance, v_status
    FROM   ACCOUNTS
    WHERE  ACCOUNT_ID = p_account_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Account % not found', p_account_id;
    END IF;

    IF v_status <> 'ACTIVE' THEN
        RAISE EXCEPTION 'Account % is not active', p_account_id;
    END IF;

    IF v_balance < p_amount THEN
        INSERT INTO AUDIT_LOG (ACTION, STATUS)
        VALUES ('WITHDRAW - ACCT ' || p_account_id, 'FAILURE');
        RAISE EXCEPTION 'Insufficient funds in account %', p_account_id;
    END IF;

    v_balance := v_balance - p_amount;

    UPDATE ACCOUNTS
    SET    BALANCE = v_balance
    WHERE  ACCOUNT_ID = p_account_id;

    INSERT INTO TRANSACTIONS (ACCOUNT_ID, AMOUNT, TXN_TYPE)
    VALUES (p_account_id, p_amount, 'WITHDRAW');

    INSERT INTO AUDIT_LOG (ACTION, STATUS)
    VALUES ('WITHDRAW - ACCT ' || p_account_id, 'SUCCESS');

    RETURN v_balance;
END;
$$;

-- -----------------------------------------------------------
-- fn_transfer
-- Atomic inter-account transfer. Locks both rows, validates,
-- debits source, credits target, records two transactions,
-- writes audit log. Returns new source balance.
-- -----------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_transfer(
    p_source_id INT,
    p_target_id INT,
    p_amount    DECIMAL(12,2)
) RETURNS DECIMAL(12,2)
LANGUAGE plpgsql
AS $$
DECLARE
    v_src_balance DECIMAL(12,2);
    v_tgt_balance DECIMAL(12,2);
    v_src_status  VARCHAR(20);
    v_tgt_status  VARCHAR(20);
    v_audit_action VARCHAR(50);
BEGIN
    IF p_source_id = p_target_id THEN
        RAISE EXCEPTION 'Source and target accounts must differ';
    END IF;

    IF p_amount <= 0 THEN
        RAISE EXCEPTION 'Amount must be greater than zero';
    END IF;

    v_audit_action := 'TRANSFER - SRC ' || p_source_id
                   || ' TGT ' || p_target_id;

    -- Lock source
    SELECT BALANCE, STATUS
    INTO   v_src_balance, v_src_status
    FROM   ACCOUNTS
    WHERE  ACCOUNT_ID = p_source_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Source account % not found', p_source_id;
    END IF;
    IF v_src_status <> 'ACTIVE' THEN
        RAISE EXCEPTION 'Source account % is not active', p_source_id;
    END IF;

    IF v_src_balance < p_amount THEN
        INSERT INTO AUDIT_LOG (ACTION, STATUS)
        VALUES (v_audit_action, 'FAILURE');
        RAISE EXCEPTION 'Insufficient funds in source account %',
                         p_source_id;
    END IF;

    -- Lock target
    SELECT BALANCE, STATUS
    INTO   v_tgt_balance, v_tgt_status
    FROM   ACCOUNTS
    WHERE  ACCOUNT_ID = p_target_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Target account % not found', p_target_id;
    END IF;
    IF v_tgt_status <> 'ACTIVE' THEN
        RAISE EXCEPTION 'Target account % is not active', p_target_id;
    END IF;

    -- Execute transfer
    UPDATE ACCOUNTS SET BALANCE = v_src_balance - p_amount
    WHERE  ACCOUNT_ID = p_source_id;

    UPDATE ACCOUNTS SET BALANCE = v_tgt_balance + p_amount
    WHERE  ACCOUNT_ID = p_target_id;

    INSERT INTO TRANSACTIONS (ACCOUNT_ID, AMOUNT, TXN_TYPE)
    VALUES (p_source_id, p_amount, 'TRANSFER');

    INSERT INTO TRANSACTIONS (ACCOUNT_ID, AMOUNT, TXN_TYPE)
    VALUES (p_target_id, p_amount, 'TRANSFER');

    INSERT INTO AUDIT_LOG (ACTION, STATUS)
    VALUES (v_audit_action, 'SUCCESS');

    RETURN v_src_balance - p_amount;
END;
$$;

-- -----------------------------------------------------------
-- fn_close_account
-- Validates balance is zero and no recent transactions,
-- then sets status to CLOSED. Returns TRUE on success.
-- -----------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_close_account(
    p_account_id INT
) RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
    v_balance   DECIMAL(12,2);
    v_status    VARCHAR(20);
    v_txn_count INT;
BEGIN
    SELECT BALANCE, STATUS
    INTO   v_balance, v_status
    FROM   ACCOUNTS
    WHERE  ACCOUNT_ID = p_account_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Account % not found', p_account_id;
    END IF;

    IF v_status = 'CLOSED' THEN
        RAISE EXCEPTION 'Account % is already closed', p_account_id;
    END IF;

    IF v_balance > 0 THEN
        INSERT INTO AUDIT_LOG (ACTION, STATUS)
        VALUES ('CLOSE ACCT ' || p_account_id, 'FAILURE');
        RAISE EXCEPTION 'Cannot close account % with balance > 0',
                         p_account_id;
    END IF;

    SELECT COUNT(*) INTO v_txn_count
    FROM   TRANSACTIONS
    WHERE  ACCOUNT_ID = p_account_id
    AND    CREATED_AT >= CURRENT_TIMESTAMP - INTERVAL '30 days';

    IF v_txn_count > 0 THEN
        INSERT INTO AUDIT_LOG (ACTION, STATUS)
        VALUES ('CLOSE ACCT ' || p_account_id, 'FAILURE');
        RAISE EXCEPTION
            'Cannot close account % with recent transactions',
            p_account_id;
    END IF;

    UPDATE ACCOUNTS
    SET    STATUS = 'CLOSED'
    WHERE  ACCOUNT_ID = p_account_id;

    INSERT INTO AUDIT_LOG (ACTION, STATUS)
    VALUES ('CLOSE ACCT ' || p_account_id, 'SUCCESS');

    RETURN TRUE;
END;
$$;

COMMIT;
