       IDENTIFICATION DIVISION.
       PROGRAM-ID. RPTGEN.
      *> ============================================================
      *> REPORT GENERATOR
      *> Produces account summaries and transaction history reports
      *> using cursor-based multi-row processing.
      *> ============================================================

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       REPOSITORY.

       DATA DIVISION.
       WORKING-STORAGE SECTION.

      *> ----- SQL Communication Area -----
           EXEC SQL
               INCLUDE SQLCA
           END-EXEC.

      *> ----- Host Variables -----
           EXEC SQL BEGIN DECLARE SECTION END-EXEC.
       01  HV-ACCOUNT-ID         PIC S9(9) COMP.
       01  HV-CUSTOMER-ID        PIC S9(9) COMP.
       01  HV-FIRST-NAME         PIC X(50).
       01  HV-LAST-NAME          PIC X(50).
       01  HV-BALANCE            PIC S9(10)V99 COMP-3.
       01  HV-ACCOUNT-TYPE       PIC X(20).
       01  HV-STATUS             PIC X(20).
       01  HV-TXN-ID             PIC S9(9) COMP.
       01  HV-AMOUNT             PIC S9(10)V99 COMP-3.
       01  HV-TXN-TYPE           PIC X(10).
       01  HV-TXN-DATE           PIC X(26).
       01  HV-TOTAL-DEPOSITS     PIC S9(12)V99 COMP-3.
       01  HV-TOTAL-WITHDRAWALS  PIC S9(12)V99 COMP-3.
       01  HV-TXN-COUNT          PIC S9(9) COMP.
           EXEC SQL END DECLARE SECTION END-EXEC.

      *> ----- Database Configuration -----
           COPY 'dbconfig.cpy'.

      *> ----- Working Fields -----
       01  WS-MENU-CHOICE        PIC 9(1) VALUE 0.
       01  WS-CONTINUE-FLAG      PIC X(1) VALUE 'Y'.
           88 WS-CONTINUE        VALUE 'Y' 'y'.
       01  WS-DISPLAY-BALANCE    PIC Z(9)9.99.
       01  WS-DISPLAY-AMOUNT     PIC Z(9)9.99.
       01  WS-DISPLAY-TOTAL      PIC Z(12)9.99.
       01  WS-ROW-COUNT          PIC 9(5) VALUE 0.

       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-CONNECT-DB
           PERFORM 2000-MAIN-MENU
               UNTIL NOT WS-CONTINUE
           PERFORM 9000-DISCONNECT-DB
           STOP RUN.

      *> ============================================================
      *> DATABASE CONNECTION
      *> ============================================================
       1000-CONNECT-DB.
           EXEC SQL
               CONNECT TO :WS-DB-NAME
               USER :WS-DB-USER
           END-EXEC

           IF SQLCODE NOT = 0
               DISPLAY "ERROR: Database connection failed."
               DISPLAY "SQLCODE: " SQLCODE
               STOP RUN
           END-IF.

      *> ============================================================
      *> MAIN MENU
      *> ============================================================
       2000-MAIN-MENU.
           DISPLAY SPACES
           DISPLAY "========================================"
           DISPLAY "        REPORT GENERATOR"
           DISPLAY "========================================"
           DISPLAY "  1. Account Summary (All Accounts)"
           DISPLAY "  2. Transaction History by Account"
           DISPLAY "  3. Account Totals Summary"
           DISPLAY "  0. Exit"
           DISPLAY "========================================"
           DISPLAY "Enter choice: " WITH NO ADVANCING
           ACCEPT WS-MENU-CHOICE

           EVALUATE WS-MENU-CHOICE
               WHEN 1
                   PERFORM 3000-ACCOUNT-SUMMARY
               WHEN 2
                   PERFORM 4000-TRANSACTION-HISTORY
               WHEN 3
                   PERFORM 5000-ACCOUNT-TOTALS
               WHEN 0
                   MOVE 'N' TO WS-CONTINUE-FLAG
               WHEN OTHER
                   DISPLAY "Invalid choice. Try again."
           END-EVALUATE.

      *> ============================================================
      *> ACCOUNT SUMMARY - All accounts with customer info
      *> ============================================================
       3000-ACCOUNT-SUMMARY.
           EXEC SQL
               DECLARE CSR-ACCT-SUMMARY CURSOR FOR
               SELECT A.ACCOUNT_ID,
                      C.CUSTOMER_ID,
                      C.FIRST_NAME,
                      C.LAST_NAME,
                      A.BALANCE,
                      A.ACCOUNT_TYPE,
                      A.STATUS
               FROM   ACCOUNTS A
               JOIN   CUSTOMERS C
                 ON   A.CUSTOMER_ID = C.CUSTOMER_ID
               ORDER BY A.ACCOUNT_ID
           END-EXEC

           EXEC SQL OPEN CSR-ACCT-SUMMARY END-EXEC

           IF SQLCODE NOT = 0
               DISPLAY "ERROR: Could not open summary cursor."
               DISPLAY "SQLCODE: " SQLCODE
               EXIT PARAGRAPH
           END-IF

           DISPLAY SPACES
           DISPLAY "============================================="
           DISPLAY "         ACCOUNT SUMMARY REPORT"
           DISPLAY "============================================="
           DISPLAY "ACCT    CUSTOMER            TYPE"
           DISPLAY "        STATUS   BALANCE"
           DISPLAY "---------------------------------------------"

           MOVE 0 TO WS-ROW-COUNT
           PERFORM 3100-FETCH-SUMMARY
               UNTIL SQLCODE NOT = 0

           EXEC SQL CLOSE CSR-ACCT-SUMMARY END-EXEC

           DISPLAY "---------------------------------------------"
           DISPLAY "Total accounts: " WS-ROW-COUNT.

       3100-FETCH-SUMMARY.
           EXEC SQL
               FETCH CSR-ACCT-SUMMARY
               INTO  :HV-ACCOUNT-ID,
                     :HV-CUSTOMER-ID,
                     :HV-FIRST-NAME,
                     :HV-LAST-NAME,
                     :HV-BALANCE,
                     :HV-ACCOUNT-TYPE,
                     :HV-STATUS
           END-EXEC

           IF SQLCODE = 0
               ADD 1 TO WS-ROW-COUNT
               MOVE HV-BALANCE TO WS-DISPLAY-BALANCE
               DISPLAY HV-ACCOUNT-ID "   "
                       HV-FIRST-NAME " "
                       HV-LAST-NAME "   "
                       HV-ACCOUNT-TYPE
               DISPLAY "        "
                       HV-STATUS "   $"
                       WS-DISPLAY-BALANCE
           END-IF.

      *> ============================================================
      *> TRANSACTION HISTORY - for a specific account
      *> ============================================================
       4000-TRANSACTION-HISTORY.
           DISPLAY SPACES
           DISPLAY "--- Transaction History ---"
           DISPLAY "Account ID: " WITH NO ADVANCING
           ACCEPT HV-ACCOUNT-ID

           EXEC SQL
               DECLARE CSR-TXN-HISTORY CURSOR FOR
               SELECT TXN_ID,
                      AMOUNT,
                      TXN_TYPE,
                      CREATED_AT
               FROM   TRANSACTIONS
               WHERE  ACCOUNT_ID = :HV-ACCOUNT-ID
               ORDER BY CREATED_AT DESC
           END-EXEC

           EXEC SQL OPEN CSR-TXN-HISTORY END-EXEC

           IF SQLCODE NOT = 0
               DISPLAY "ERROR: Could not open transaction cursor."
               DISPLAY "SQLCODE: " SQLCODE
               EXIT PARAGRAPH
           END-IF

           DISPLAY "============================================="
           DISPLAY " TRANSACTION HISTORY - ACCOUNT " HV-ACCOUNT-ID
           DISPLAY "============================================="
           DISPLAY "TXN ID    TYPE       AMOUNT       DATE"
           DISPLAY "---------------------------------------------"

           MOVE 0 TO WS-ROW-COUNT
           PERFORM 4100-FETCH-TXN
               UNTIL SQLCODE NOT = 0

           EXEC SQL CLOSE CSR-TXN-HISTORY END-EXEC

           IF WS-ROW-COUNT = 0
               DISPLAY "No transactions found."
           ELSE
               DISPLAY "---------------------------------------------"
               DISPLAY "Total transactions: " WS-ROW-COUNT
           END-IF.

       4100-FETCH-TXN.
           EXEC SQL
               FETCH CSR-TXN-HISTORY
               INTO  :HV-TXN-ID,
                     :HV-AMOUNT,
                     :HV-TXN-TYPE,
                     :HV-TXN-DATE
           END-EXEC

           IF SQLCODE = 0
               ADD 1 TO WS-ROW-COUNT
               MOVE HV-AMOUNT TO WS-DISPLAY-AMOUNT
               DISPLAY HV-TXN-ID "   "
                       HV-TXN-TYPE "   $"
                       WS-DISPLAY-AMOUNT "   "
                       HV-TXN-DATE
           END-IF.

      *> ============================================================
      *> ACCOUNT TOTALS - aggregate deposits/withdrawals per account
      *> ============================================================
       5000-ACCOUNT-TOTALS.
           DISPLAY SPACES
           DISPLAY "--- Account Totals ---"
           DISPLAY "Account ID: " WITH NO ADVANCING
           ACCEPT HV-ACCOUNT-ID

      *>   Total deposits
           EXEC SQL
               SELECT COALESCE(SUM(AMOUNT), 0),
                      COUNT(*)
               INTO   :HV-TOTAL-DEPOSITS,
                      :HV-TXN-COUNT
               FROM   TRANSACTIONS
               WHERE  ACCOUNT_ID = :HV-ACCOUNT-ID
               AND    TXN_TYPE   = 'DEPOSIT'
           END-EXEC

           IF SQLCODE NOT = 0
               DISPLAY "ERROR: Could not retrieve deposit totals."
               EXIT PARAGRAPH
           END-IF

           MOVE HV-TOTAL-DEPOSITS TO WS-DISPLAY-TOTAL

           DISPLAY "============================================="
           DISPLAY " TOTALS - ACCOUNT " HV-ACCOUNT-ID
           DISPLAY "============================================="
           DISPLAY "Total Deposits:     $" WS-DISPLAY-TOTAL
           DISPLAY "  Deposit Count:     " HV-TXN-COUNT

      *>   Total withdrawals
           EXEC SQL
               SELECT COALESCE(SUM(AMOUNT), 0),
                      COUNT(*)
               INTO   :HV-TOTAL-WITHDRAWALS,
                      :HV-TXN-COUNT
               FROM   TRANSACTIONS
               WHERE  ACCOUNT_ID = :HV-ACCOUNT-ID
               AND    TXN_TYPE   = 'WITHDRAW'
           END-EXEC

           IF SQLCODE NOT = 0
               DISPLAY "ERROR: Could not retrieve withdrawal totals."
               EXIT PARAGRAPH
           END-IF

           MOVE HV-TOTAL-WITHDRAWALS TO WS-DISPLAY-TOTAL
           DISPLAY "Total Withdrawals:  $" WS-DISPLAY-TOTAL
           DISPLAY "  Withdrawal Count:  " HV-TXN-COUNT

      *>   Current balance
           EXEC SQL
               SELECT BALANCE
               INTO   :HV-BALANCE
               FROM   ACCOUNTS
               WHERE  ACCOUNT_ID = :HV-ACCOUNT-ID
           END-EXEC

           IF SQLCODE = 0
               MOVE HV-BALANCE TO WS-DISPLAY-BALANCE
               DISPLAY "Current Balance:    $" WS-DISPLAY-BALANCE
           END-IF

           DISPLAY "=============================================".

      *> ============================================================
      *> DISCONNECT
      *> ============================================================
       9000-DISCONNECT-DB.
           EXEC SQL
               DISCONNECT ALL
           END-EXEC.
