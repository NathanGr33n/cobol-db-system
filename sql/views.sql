-- ============================================================
-- COBOL-DB-SYSTEM : Database Views
-- Reporting views that simplify COBOL SQL queries.
-- ============================================================

BEGIN;

-- -----------------------------------------------------------
-- v_account_summary
-- Joined view of accounts with customer names.
-- Used by rptgen.cbl Account Summary report.
-- -----------------------------------------------------------
CREATE OR REPLACE VIEW v_account_summary AS
SELECT A.ACCOUNT_ID,
       C.CUSTOMER_ID,
       C.FIRST_NAME,
       C.LAST_NAME,
       A.BALANCE,
       A.ACCOUNT_TYPE,
       A.STATUS
FROM   ACCOUNTS A
JOIN   CUSTOMERS C ON A.CUSTOMER_ID = C.CUSTOMER_ID
ORDER BY A.ACCOUNT_ID;

-- -----------------------------------------------------------
-- v_daily_activity
-- Aggregated transaction counts and totals by date.
-- -----------------------------------------------------------
CREATE OR REPLACE VIEW v_daily_activity AS
SELECT CAST(CREATED_AT AS DATE) AS TXN_DATE,
       TXN_TYPE,
       COUNT(*)                 AS TXN_COUNT,
       SUM(AMOUNT)             AS TOTAL_AMOUNT
FROM   TRANSACTIONS
GROUP BY CAST(CREATED_AT AS DATE), TXN_TYPE
ORDER BY TXN_DATE DESC, TXN_TYPE;

-- -----------------------------------------------------------
-- v_customer_portfolio
-- Total balance across all active accounts per customer.
-- -----------------------------------------------------------
CREATE OR REPLACE VIEW v_customer_portfolio AS
SELECT C.CUSTOMER_ID,
       C.FIRST_NAME,
       C.LAST_NAME,
       C.EMAIL,
       COUNT(A.ACCOUNT_ID)      AS ACCOUNT_COUNT,
       COALESCE(SUM(CASE WHEN A.STATUS = 'ACTIVE'
                         THEN A.BALANCE ELSE 0 END), 0)
                                 AS TOTAL_ACTIVE_BALANCE,
       SUM(CASE WHEN A.STATUS = 'ACTIVE' THEN 1 ELSE 0 END)
                                 AS ACTIVE_ACCOUNTS,
       SUM(CASE WHEN A.STATUS = 'CLOSED' THEN 1 ELSE 0 END)
                                 AS CLOSED_ACCOUNTS
FROM   CUSTOMERS C
LEFT JOIN ACCOUNTS A ON C.CUSTOMER_ID = A.CUSTOMER_ID
GROUP BY C.CUSTOMER_ID, C.FIRST_NAME, C.LAST_NAME, C.EMAIL
ORDER BY C.CUSTOMER_ID;

COMMIT;
