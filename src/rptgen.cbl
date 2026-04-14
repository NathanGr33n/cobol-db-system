      ******************************************************************
      * RPTGEN.CBL - Report Generator
      * Banking System - Account and Transaction Reports
      * Uses Embedded SQL (EXEC SQL) for PostgreSQL via ocesql
      * Demonstrates cursor-based multi-row processing
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. RPTGEN.
       AUTHOR. COBOL-DB-SYSTEM.
       DATE-WRITTEN. 2024-06-01.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       REPOSITORY.
           FUNCTION ALL INTRINSIC.

       DATA DIVISION.
       WORKING-STORAGE SECTION.

      ******************************************************************
      * SQL Communication Area
      ******************************************************************
           EXEC SQL
               INCLUDE SQLCA
           END-EXEC.

      ******************************************************************
      * Host Variables - Account Summary
      ******************************************************************
       01  WS-CUSTOMER-ID          PIC 9(8)       VALUE ZEROS.
       01  WS-FIRST-NAME           PIC X(50)      VALUE SPACES.
       01  WS-LAST-NAME            PIC X(50)      VALUE SPACES.
       01  WS-ACCOUNT-ID           PIC 9(8)       VALUE ZEROS.
       01  WS-BALANCE              PIC S9(10)V99  VALUE ZEROS.
       01  WS-ACCOUNT-TYPE         PIC X(20)      VALUE SPACES.
       01  WS-ACCOUNT-STATUS       PIC X(20)      VALUE SPACES.

      ******************************************************************
      * Host Variables - Transaction Report
      ******************************************************************
       01  WS-TXN-ID               PIC 9(8)       VALUE ZEROS.
       01  WS-TXN-AMOUNT           PIC S9(10)V99  VALUE ZEROS.
       01  WS-TXN-TYPE             PIC X(10)      VALUE SPACES.
       01  WS-TXN-DATE             PIC X(26)      VALUE SPACES.

      ******************************************************************
      * Host Variables - Audit Report
      ******************************************************************
       01  WS-LOG-ID               PIC 9(8)       VALUE ZEROS.
       01  WS-LOG-ACTION           PIC X(50)      VALUE SPACES.
       01  WS-LOG-STATUS           PIC X(20)      VALUE SPACES.
       01  WS-LOG-DETAILS          PIC X(200)     VALUE SPACES.
       01  WS-LOG-DATE             PIC X(26)      VALUE SPACES.

      ******************************************************************
      * Accumulator Variables
      ******************************************************************
       01  WS-TOTAL-BALANCE        PIC S9(12)V99  VALUE ZEROS.
       01  WS-TOTAL-DEPOSITS       PIC S9(12)V99  VALUE ZEROS.
       01  WS-TOTAL-WITHDRAWALS    PIC S9(12)V99  VALUE ZEROS.
       01  WS-RECORD-COUNT         PIC 9(6)       VALUE ZEROS.
       01  WS-DEPOSIT-COUNT        PIC 9(6)       VALUE ZEROS.
       01  WS-WITHDRAW-COUNT       PIC 9(6)       VALUE ZEROS.

      ******************************************************************
      * Program Control Variables
      ******************************************************************
       01  WS-MENU-CHOICE          PIC 9          VALUE ZERO.
       01  WS-CONTINUE-FLAG        PIC X          VALUE 'Y'.
           88 WS-CONTINUE                         VALUE 'Y' 'y'.
           88 WS-EXIT                             VALUE 'N' 'n'.
       01  WS-EOF-FLAG             PIC X          VALUE 'N'.
           88 WS-EOF                              VALUE 'Y'.
           88 WS-NOT-EOF                          VALUE 'N'.
       01  WS-INPUT-ID             PIC 9(8)       VALUE ZEROS.
       01  WS-DATE-START            PIC X(10)      VALUE SPACES.
       01  WS-DATE-END              PIC X(10)      VALUE SPACES.
       01  WS-USE-DATES             PIC X          VALUE 'N'.
           88 WS-FILTER-BY-DATE                    VALUE 'Y'.
           88 WS-NO-DATE-FILTER                    VALUE 'N'.

      ******************************************************************
      * Database Configuration
      ******************************************************************
           COPY 'cpy/dbconfig.cpy'.

      ******************************************************************
      * Display Formatting
      ******************************************************************
       01  WS-SEPARATOR            PIC X(70)      VALUE ALL '-'.
       01  WS-DBL-SEPARATOR        PIC X(70)      VALUE ALL '='.
       01  WS-DISPLAY-ID           PIC Z(7)9.
       01  WS-DISPLAY-BALANCE      PIC $$$,$$$,$$9.99.
       01  WS-DISPLAY-AMOUNT       PIC $$$,$$$,$$9.99.
       01  WS-DISPLAY-TOTAL        PIC $$$,$$$,$$9.99.

       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-PROCESS-MENU
               UNTIL WS-EXIT
           PERFORM 9000-TERMINATE
           STOP RUN
           .

      ******************************************************************
      * Initialize database connection
      ******************************************************************
       1000-INITIALIZE.
           EXEC SQL
               CONNECT TO :WS-DB-NAME
           END-EXEC

           IF SQLCODE NOT = ZERO
               DISPLAY 'ERROR: Database connection failed.'
               DISPLAY 'SQLCODE: ' SQLCODE
               STOP RUN
           END-IF

           DISPLAY SPACES
           DISPLAY '=========================================='
           DISPLAY '  COBOL BANKING SYSTEM - REPORT GENERATOR'
           DISPLAY '=========================================='
           .

      ******************************************************************
      * Main menu loop
      ******************************************************************
       2000-PROCESS-MENU.
           DISPLAY SPACES
           DISPLAY WS-SEPARATOR
           DISPLAY '  REPORT GENERATOR MENU'
           DISPLAY WS-SEPARATOR
           DISPLAY '  1. Account Summary by Customer'
           DISPLAY '  2. Transaction History by Account'
           DISPLAY '  3. Full Account Report (All Customers)'
           DISPLAY '  4. Transaction Summary Report'
           DISPLAY '  5. Audit Log Report'
           DISPLAY '  9. Exit'
           DISPLAY WS-SEPARATOR
           DISPLAY 'Enter choice: ' WITH NO ADVANCING
           ACCEPT WS-MENU-CHOICE

           EVALUATE WS-MENU-CHOICE
               WHEN 1
                   PERFORM 3000-ACCOUNT-SUMMARY
               WHEN 2
                   PERFORM 4000-TRANSACTION-HISTORY
               WHEN 3
                   PERFORM 5000-FULL-ACCOUNT-REPORT
               WHEN 4
                   PERFORM 6000-TRANSACTION-SUMMARY
               WHEN 5
                   PERFORM 7000-AUDIT-LOG-REPORT
               WHEN 9
                   SET WS-EXIT TO TRUE
               WHEN OTHER
                   DISPLAY 'ERROR: Invalid choice. Try again.'
           END-EVALUATE
           .

      ******************************************************************
      * Account Summary for a specific customer
      ******************************************************************
       3000-ACCOUNT-SUMMARY.
           DISPLAY SPACES
           DISPLAY 'Enter Customer ID: ' WITH NO ADVANCING
           ACCEPT WS-INPUT-ID

           IF WS-INPUT-ID = ZEROS
               DISPLAY 'ERROR: Invalid Customer ID.'
               GO TO 3000-EXIT
           END-IF

      *    Get customer info
           EXEC SQL
               SELECT FIRST_NAME, LAST_NAME
               INTO :WS-FIRST-NAME, :WS-LAST-NAME
               FROM CUSTOMERS
               WHERE CUSTOMER_ID = :WS-INPUT-ID
           END-EXEC

           IF SQLCODE = 100
               DISPLAY 'INFO: Customer not found.'
               GO TO 3000-EXIT
           END-IF

           DISPLAY SPACES
           DISPLAY WS-DBL-SEPARATOR
           DISPLAY '  ACCOUNT SUMMARY'
           DISPLAY WS-DBL-SEPARATOR
           MOVE WS-INPUT-ID TO WS-DISPLAY-ID
           DISPLAY '  Customer ID  : ' WS-DISPLAY-ID
           DISPLAY '  Customer Name: '
               FUNCTION TRIM(WS-FIRST-NAME) ' '
               FUNCTION TRIM(WS-LAST-NAME)
           DISPLAY WS-SEPARATOR

           MOVE ZERO TO WS-RECORD-COUNT
           MOVE ZERO TO WS-TOTAL-BALANCE
           SET WS-NOT-EOF TO TRUE

           EXEC SQL
               DECLARE CSR-CUST-ACCTS CURSOR FOR
               SELECT ACCOUNT_ID, BALANCE, ACCOUNT_TYPE, STATUS
               FROM ACCOUNTS
               WHERE CUSTOMER_ID = :WS-INPUT-ID
               ORDER BY ACCOUNT_ID
           END-EXEC

           EXEC SQL OPEN CSR-CUST-ACCTS END-EXEC

           IF SQLCODE NOT = ZERO
               DISPLAY 'ERROR: Could not open cursor.'
               GO TO 3000-EXIT
           END-IF

           PERFORM 3100-FETCH-ACCOUNT UNTIL WS-EOF

           EXEC SQL CLOSE CSR-CUST-ACCTS END-EXEC

           MOVE WS-TOTAL-BALANCE TO WS-DISPLAY-TOTAL
           DISPLAY WS-SEPARATOR
           DISPLAY '  Total Accounts : ' WS-RECORD-COUNT
           DISPLAY '  Total Balance  : ' WS-DISPLAY-TOTAL
           DISPLAY WS-DBL-SEPARATOR
           .
       3000-EXIT.
           EXIT
           .

       3100-FETCH-ACCOUNT.
           EXEC SQL
               FETCH CSR-CUST-ACCTS
               INTO :WS-ACCOUNT-ID, :WS-BALANCE,
                    :WS-ACCOUNT-TYPE, :WS-ACCOUNT-STATUS
           END-EXEC

           IF SQLCODE = ZERO
               ADD 1 TO WS-RECORD-COUNT
               ADD WS-BALANCE TO WS-TOTAL-BALANCE
               MOVE WS-ACCOUNT-ID TO WS-DISPLAY-ID
               MOVE WS-BALANCE TO WS-DISPLAY-BALANCE
               DISPLAY '  Acct: ' WS-DISPLAY-ID
                   '  Type: '
                   FUNCTION TRIM(WS-ACCOUNT-TYPE)
                   '  Status: '
                   FUNCTION TRIM(WS-ACCOUNT-STATUS)
                   '  Bal: ' WS-DISPLAY-BALANCE
           ELSE
               SET WS-EOF TO TRUE
               IF SQLCODE NOT = 100
                   DISPLAY 'ERROR: Fetch error. SQLCODE: '
                       SQLCODE
               END-IF
           END-IF
           .

      ******************************************************************
      * Transaction history for a specific account
      ******************************************************************
       4000-TRANSACTION-HISTORY.
           DISPLAY SPACES
           DISPLAY 'Enter Account ID: ' WITH NO ADVANCING
           ACCEPT WS-INPUT-ID

           IF WS-INPUT-ID = ZEROS
               DISPLAY 'ERROR: Invalid Account ID.'
               GO TO 4000-EXIT
           END-IF

      *    Verify account exists
           EXEC SQL
               SELECT BALANCE, ACCOUNT_TYPE
               INTO :WS-BALANCE, :WS-ACCOUNT-TYPE
               FROM ACCOUNTS
               WHERE ACCOUNT_ID = :WS-INPUT-ID
           END-EXEC

           IF SQLCODE = 100
               DISPLAY 'INFO: Account not found.'
               GO TO 4000-EXIT
           END-IF

      *    Optional date range filter
           DISPLAY 'Filter by date range? (Y/N): '
               WITH NO ADVANCING
           ACCEPT WS-USE-DATES

           IF WS-FILTER-BY-DATE
               DISPLAY 'Start date (YYYY-MM-DD): '
                   WITH NO ADVANCING
               ACCEPT WS-DATE-START
               DISPLAY 'End date   (YYYY-MM-DD): '
                   WITH NO ADVANCING
               ACCEPT WS-DATE-END
           ELSE
               MOVE '1900-01-01' TO WS-DATE-START
               MOVE '2099-12-31' TO WS-DATE-END
           END-IF

           DISPLAY SPACES
           DISPLAY WS-DBL-SEPARATOR
           DISPLAY '  TRANSACTION HISTORY'
           DISPLAY WS-DBL-SEPARATOR
           MOVE WS-INPUT-ID TO WS-DISPLAY-ID
           MOVE WS-BALANCE TO WS-DISPLAY-BALANCE
           DISPLAY '  Account ID     : ' WS-DISPLAY-ID
           DISPLAY '  Account Type   : '
               FUNCTION TRIM(WS-ACCOUNT-TYPE)
           DISPLAY '  Current Balance: ' WS-DISPLAY-BALANCE
           IF WS-FILTER-BY-DATE
               DISPLAY '  Date Range     : '
                   FUNCTION TRIM(WS-DATE-START) ' to '
                   FUNCTION TRIM(WS-DATE-END)
           END-IF
           DISPLAY WS-SEPARATOR

           MOVE ZERO TO WS-RECORD-COUNT
           MOVE ZERO TO WS-TOTAL-DEPOSITS
           MOVE ZERO TO WS-TOTAL-WITHDRAWALS
           SET WS-NOT-EOF TO TRUE

           EXEC SQL
               DECLARE CSR-TXN-HIST CURSOR FOR
               SELECT TXN_ID, AMOUNT, TXN_TYPE, CREATED_AT
               FROM TRANSACTIONS
               WHERE ACCOUNT_ID = :WS-INPUT-ID
                 AND CREATED_AT >= CAST(:WS-DATE-START AS TIMESTAMP)
                 AND CREATED_AT <
                     CAST(:WS-DATE-END AS TIMESTAMP)
                     + INTERVAL '1 day'
               ORDER BY CREATED_AT DESC
           END-EXEC

           EXEC SQL OPEN CSR-TXN-HIST END-EXEC

           IF SQLCODE NOT = ZERO
               DISPLAY 'ERROR: Could not open cursor.'
               GO TO 4000-EXIT
           END-IF

           PERFORM 4100-FETCH-TRANSACTION UNTIL WS-EOF

           EXEC SQL CLOSE CSR-TXN-HIST END-EXEC

           MOVE WS-TOTAL-DEPOSITS TO WS-DISPLAY-TOTAL
           DISPLAY WS-SEPARATOR
           DISPLAY '  Transactions   : ' WS-RECORD-COUNT
           DISPLAY '  Total Deposits : ' WS-DISPLAY-TOTAL
           MOVE WS-TOTAL-WITHDRAWALS TO WS-DISPLAY-TOTAL
           DISPLAY '  Total Withdrawn: ' WS-DISPLAY-TOTAL
           DISPLAY WS-DBL-SEPARATOR
           .
       4000-EXIT.
           EXIT
           .

       4100-FETCH-TRANSACTION.
           EXEC SQL
               FETCH CSR-TXN-HIST
               INTO :WS-TXN-ID, :WS-TXN-AMOUNT,
                    :WS-TXN-TYPE, :WS-TXN-DATE
           END-EXEC

           IF SQLCODE = ZERO
               ADD 1 TO WS-RECORD-COUNT
               IF WS-TXN-TYPE = 'DEPOSIT'
                   ADD WS-TXN-AMOUNT TO WS-TOTAL-DEPOSITS
               ELSE
                   ADD WS-TXN-AMOUNT TO WS-TOTAL-WITHDRAWALS
               END-IF
               MOVE WS-TXN-ID TO WS-DISPLAY-ID
               MOVE WS-TXN-AMOUNT TO WS-DISPLAY-AMOUNT
               DISPLAY '  TXN: ' WS-DISPLAY-ID
                   '  Type: '
                   FUNCTION TRIM(WS-TXN-TYPE)
                   '  Amount: ' WS-DISPLAY-AMOUNT
                   '  Date: '
                   FUNCTION TRIM(WS-TXN-DATE)
           ELSE
               SET WS-EOF TO TRUE
               IF SQLCODE NOT = 100
                   DISPLAY 'ERROR: Fetch error. SQLCODE: '
                       SQLCODE
               END-IF
           END-IF
           .

      ******************************************************************
      * Full account report - all customers and their accounts
      ******************************************************************
       5000-FULL-ACCOUNT-REPORT.
           DISPLAY SPACES
           DISPLAY WS-DBL-SEPARATOR
           DISPLAY '  FULL ACCOUNT REPORT - ALL CUSTOMERS'
           DISPLAY WS-DBL-SEPARATOR

           MOVE ZERO TO WS-RECORD-COUNT
           MOVE ZERO TO WS-TOTAL-BALANCE
           SET WS-NOT-EOF TO TRUE

           EXEC SQL
               DECLARE CSR-FULL-RPT CURSOR FOR
               SELECT C.CUSTOMER_ID, C.FIRST_NAME, C.LAST_NAME,
                      A.ACCOUNT_ID, A.BALANCE,
                      A.ACCOUNT_TYPE, A.STATUS
               FROM CUSTOMERS C
               JOIN ACCOUNTS A
                   ON C.CUSTOMER_ID = A.CUSTOMER_ID
               ORDER BY C.CUSTOMER_ID, A.ACCOUNT_ID
           END-EXEC

           EXEC SQL OPEN CSR-FULL-RPT END-EXEC

           IF SQLCODE NOT = ZERO
               DISPLAY 'ERROR: Could not open cursor.'
               GO TO 5000-EXIT
           END-IF

           PERFORM 5100-FETCH-FULL-RECORD UNTIL WS-EOF

           EXEC SQL CLOSE CSR-FULL-RPT END-EXEC

           MOVE WS-TOTAL-BALANCE TO WS-DISPLAY-TOTAL
           DISPLAY WS-SEPARATOR
           DISPLAY '  Total Records      : ' WS-RECORD-COUNT
           DISPLAY '  Total All Balances : ' WS-DISPLAY-TOTAL
           DISPLAY WS-DBL-SEPARATOR
           .
       5000-EXIT.
           EXIT
           .

       5100-FETCH-FULL-RECORD.
           EXEC SQL
               FETCH CSR-FULL-RPT
               INTO :WS-CUSTOMER-ID, :WS-FIRST-NAME,
                    :WS-LAST-NAME, :WS-ACCOUNT-ID,
                    :WS-BALANCE, :WS-ACCOUNT-TYPE,
                    :WS-ACCOUNT-STATUS
           END-EXEC

           IF SQLCODE = ZERO
               ADD 1 TO WS-RECORD-COUNT
               ADD WS-BALANCE TO WS-TOTAL-BALANCE
               MOVE WS-CUSTOMER-ID TO WS-DISPLAY-ID
               DISPLAY '  Cust: ' WS-DISPLAY-ID
                   '  '
                   FUNCTION TRIM(WS-FIRST-NAME) ' '
                   FUNCTION TRIM(WS-LAST-NAME)
               MOVE WS-ACCOUNT-ID TO WS-DISPLAY-ID
               MOVE WS-BALANCE TO WS-DISPLAY-BALANCE
               DISPLAY '    Acct: ' WS-DISPLAY-ID
                   '  ' FUNCTION TRIM(WS-ACCOUNT-TYPE)
                   '  ' FUNCTION TRIM(WS-ACCOUNT-STATUS)
                   '  ' WS-DISPLAY-BALANCE
           ELSE
               SET WS-EOF TO TRUE
               IF SQLCODE NOT = 100
                   DISPLAY 'ERROR: Fetch error. SQLCODE: '
                       SQLCODE
               END-IF
           END-IF
           .

      ******************************************************************
      * Transaction summary report - aggregate stats
      ******************************************************************
       6000-TRANSACTION-SUMMARY.
           DISPLAY SPACES
           DISPLAY WS-DBL-SEPARATOR
           DISPLAY '  TRANSACTION SUMMARY REPORT'
           DISPLAY WS-DBL-SEPARATOR

      *    Get deposit totals
           EXEC SQL
               SELECT COUNT(*), COALESCE(SUM(AMOUNT), 0)
               INTO :WS-DEPOSIT-COUNT, :WS-TOTAL-DEPOSITS
               FROM TRANSACTIONS
               WHERE TXN_TYPE = 'DEPOSIT'
           END-EXEC

           IF SQLCODE NOT = ZERO
               DISPLAY 'ERROR: Could not retrieve deposit stats.'
               GO TO 6000-EXIT
           END-IF

      *    Get withdrawal totals
           EXEC SQL
               SELECT COUNT(*), COALESCE(SUM(AMOUNT), 0)
               INTO :WS-WITHDRAW-COUNT, :WS-TOTAL-WITHDRAWALS
               FROM TRANSACTIONS
               WHERE TXN_TYPE = 'WITHDRAW'
           END-EXEC

           IF SQLCODE NOT = ZERO
               DISPLAY 'ERROR: Could not retrieve withdrawal stats.'
               GO TO 6000-EXIT
           END-IF

      *    Get total account balance
           EXEC SQL
               SELECT COALESCE(SUM(BALANCE), 0)
               INTO :WS-TOTAL-BALANCE
               FROM ACCOUNTS
               WHERE STATUS = 'ACTIVE'
           END-EXEC

           MOVE WS-TOTAL-DEPOSITS TO WS-DISPLAY-TOTAL
           DISPLAY '  Deposits'
           DISPLAY '    Count : ' WS-DEPOSIT-COUNT
           DISPLAY '    Total : ' WS-DISPLAY-TOTAL
           DISPLAY SPACES

           MOVE WS-TOTAL-WITHDRAWALS TO WS-DISPLAY-TOTAL
           DISPLAY '  Withdrawals'
           DISPLAY '    Count : ' WS-WITHDRAW-COUNT
           DISPLAY '    Total : ' WS-DISPLAY-TOTAL
           DISPLAY SPACES

           COMPUTE WS-RECORD-COUNT =
               WS-DEPOSIT-COUNT + WS-WITHDRAW-COUNT
           DISPLAY '  Total Transactions : ' WS-RECORD-COUNT

           MOVE WS-TOTAL-BALANCE TO WS-DISPLAY-TOTAL
           DISPLAY '  Active Account Sum : ' WS-DISPLAY-TOTAL
           DISPLAY WS-DBL-SEPARATOR
           .
       6000-EXIT.
           EXIT
           .

      ******************************************************************
      * Audit log report - recent audit entries
      ******************************************************************
       7000-AUDIT-LOG-REPORT.
           DISPLAY SPACES

      *    Optional date range filter
           DISPLAY 'Filter by date range? (Y/N): '
               WITH NO ADVANCING
           ACCEPT WS-USE-DATES

           IF WS-FILTER-BY-DATE
               DISPLAY 'Start date (YYYY-MM-DD): '
                   WITH NO ADVANCING
               ACCEPT WS-DATE-START
               DISPLAY 'End date   (YYYY-MM-DD): '
                   WITH NO ADVANCING
               ACCEPT WS-DATE-END
           ELSE
               MOVE '1900-01-01' TO WS-DATE-START
               MOVE '2099-12-31' TO WS-DATE-END
           END-IF

           DISPLAY WS-DBL-SEPARATOR
           DISPLAY '  AUDIT LOG REPORT'
           IF WS-FILTER-BY-DATE
               DISPLAY '  Date Range: '
                   FUNCTION TRIM(WS-DATE-START) ' to '
                   FUNCTION TRIM(WS-DATE-END)
           ELSE
               DISPLAY '  (Last 50 entries)'
           END-IF
           DISPLAY WS-DBL-SEPARATOR

           MOVE ZERO TO WS-RECORD-COUNT
           SET WS-NOT-EOF TO TRUE

           EXEC SQL
               DECLARE CSR-AUDIT CURSOR FOR
               SELECT LOG_ID, ACTION, STATUS,
                      DETAILS, CREATED_AT
               FROM AUDIT_LOG
               WHERE CREATED_AT >= CAST(:WS-DATE-START AS TIMESTAMP)
                 AND CREATED_AT <
                     CAST(:WS-DATE-END AS TIMESTAMP)
                     + INTERVAL '1 day'
               ORDER BY CREATED_AT DESC
               FETCH FIRST 50 ROWS ONLY
           END-EXEC

           EXEC SQL OPEN CSR-AUDIT END-EXEC

           IF SQLCODE NOT = ZERO
               DISPLAY 'ERROR: Could not open audit cursor.'
               GO TO 7000-EXIT
           END-IF

           PERFORM 7100-FETCH-AUDIT UNTIL WS-EOF

           EXEC SQL CLOSE CSR-AUDIT END-EXEC

           DISPLAY WS-SEPARATOR
           DISPLAY '  Total Entries Shown: ' WS-RECORD-COUNT
           DISPLAY WS-DBL-SEPARATOR
           .
       7000-EXIT.
           EXIT
           .

       7100-FETCH-AUDIT.
           EXEC SQL
               FETCH CSR-AUDIT
               INTO :WS-LOG-ID, :WS-LOG-ACTION,
                    :WS-LOG-STATUS, :WS-LOG-DETAILS,
                    :WS-LOG-DATE
           END-EXEC

           IF SQLCODE = ZERO
               ADD 1 TO WS-RECORD-COUNT
               MOVE WS-LOG-ID TO WS-DISPLAY-ID
               DISPLAY '  #' WS-DISPLAY-ID
                   '  ' FUNCTION TRIM(WS-LOG-DATE)
                   '  ' FUNCTION TRIM(WS-LOG-ACTION)
                   '  [' FUNCTION TRIM(WS-LOG-STATUS) ']'
               IF FUNCTION LENGTH(
                   FUNCTION TRIM(WS-LOG-DETAILS)) > ZERO
                   DISPLAY '    -> '
                       FUNCTION TRIM(WS-LOG-DETAILS)
               END-IF
           ELSE
               SET WS-EOF TO TRUE
               IF SQLCODE NOT = 100
                   DISPLAY 'ERROR: Fetch error. SQLCODE: '
                       SQLCODE
               END-IF
           END-IF
           .

      ******************************************************************
      * Clean shutdown
      ******************************************************************
       9000-TERMINATE.
           EXEC SQL
               COMMIT
           END-EXEC

           EXEC SQL
               DISCONNECT ALL
           END-EXEC

           DISPLAY SPACES
           DISPLAY 'Report Generator terminated.'
           .
