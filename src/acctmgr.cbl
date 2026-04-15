       IDENTIFICATION DIVISION.
       PROGRAM-ID. ACCTMGR.
      *> ============================================================
      *> ACCOUNT MANAGER
      *> Creates accounts, checks balances, and updates account
      *> status using embedded SQL against the ACCOUNTS table.
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
       01  HV-BALANCE            PIC S9(10)V99 COMP-3.
       01  HV-ACCOUNT-TYPE       PIC X(20).
       01  HV-STATUS             PIC X(20).
       01  HV-TXN-COUNT          PIC S9(9) COMP.
       01  HV-AUDIT-ACTION       PIC X(50).
       01  HV-AUDIT-STATUS       PIC X(20).
           EXEC SQL END DECLARE SECTION END-EXEC.

      *> ----- Database Configuration -----
           COPY 'dbconfig.cpy'.

      *> ----- Working Fields -----
       01  WS-MENU-CHOICE        PIC 9(1) VALUE 0.
       01  WS-CONTINUE-FLAG      PIC X(1) VALUE 'Y'.
           88 WS-CONTINUE        VALUE 'Y' 'y'.
       01  WS-TYPE-CHOICE        PIC 9(1) VALUE 0.
       01  WS-STATUS-CHOICE      PIC 9(1) VALUE 0.
       01  WS-DISPLAY-BALANCE    PIC Z(9)9.99.

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
           DISPLAY "        ACCOUNT MANAGER"
           DISPLAY "========================================"
           DISPLAY "  1. Create New Account"
           DISPLAY "  2. Check Balance"
           DISPLAY "  3. Update Account Status"
           DISPLAY "  4. List Accounts for Customer"
           DISPLAY "  0. Exit"
           DISPLAY "========================================"
           DISPLAY "Enter choice: " WITH NO ADVANCING
           ACCEPT WS-MENU-CHOICE

           EVALUATE WS-MENU-CHOICE
               WHEN 1
                   PERFORM 3000-CREATE-ACCOUNT
               WHEN 2
                   PERFORM 4000-CHECK-BALANCE
               WHEN 3
                   PERFORM 5000-UPDATE-STATUS
               WHEN 4
                   PERFORM 6000-LIST-ACCOUNTS
               WHEN 0
                   MOVE 'N' TO WS-CONTINUE-FLAG
               WHEN OTHER
                   DISPLAY "Invalid choice. Try again."
           END-EVALUATE.

      *> ============================================================
      *> CREATE ACCOUNT
      *> ============================================================
       3000-CREATE-ACCOUNT.
           DISPLAY SPACES
           DISPLAY "--- Create New Account ---"

           DISPLAY "Customer ID: " WITH NO ADVANCING
           ACCEPT HV-CUSTOMER-ID

      *>   Validate customer exists
           EXEC SQL
               SELECT CUSTOMER_ID
               INTO   :HV-CUSTOMER-ID
               FROM   CUSTOMERS
               WHERE  CUSTOMER_ID = :HV-CUSTOMER-ID
           END-EXEC

           IF SQLCODE NOT = 0
               DISPLAY "ERROR: Customer ID not found."
               EXIT PARAGRAPH
           END-IF

           DISPLAY "Account Type (1=CHECKING, 2=SAVINGS): "
               WITH NO ADVANCING
           ACCEPT WS-TYPE-CHOICE

           EVALUATE WS-TYPE-CHOICE
               WHEN 1
                   MOVE "CHECKING" TO HV-ACCOUNT-TYPE
               WHEN 2
                   MOVE "SAVINGS"  TO HV-ACCOUNT-TYPE
               WHEN OTHER
                   DISPLAY "Invalid type. Defaulting to CHECKING."
                   MOVE "CHECKING" TO HV-ACCOUNT-TYPE
           END-EVALUATE

           MOVE 0 TO HV-BALANCE

           EXEC SQL
               INSERT INTO ACCOUNTS
                   (CUSTOMER_ID, BALANCE, ACCOUNT_TYPE, STATUS)
               VALUES
                   (:HV-CUSTOMER-ID, :HV-BALANCE,
                    :HV-ACCOUNT-TYPE, 'ACTIVE')
           END-EXEC

           IF SQLCODE = 0
               EXEC SQL COMMIT END-EXEC
               DISPLAY "Account created successfully."
           ELSE
               EXEC SQL ROLLBACK END-EXEC
               DISPLAY "ERROR: Could not create account."
               DISPLAY "SQLCODE: " SQLCODE
           END-IF.

      *> ============================================================
      *> CHECK BALANCE
      *> ============================================================
       4000-CHECK-BALANCE.
           DISPLAY SPACES
           DISPLAY "--- Check Balance ---"
           DISPLAY "Account ID: " WITH NO ADVANCING
           ACCEPT HV-ACCOUNT-ID

           EXEC SQL
               SELECT BALANCE,
                      ACCOUNT_TYPE,
                      STATUS
               INTO   :HV-BALANCE,
                      :HV-ACCOUNT-TYPE,
                      :HV-STATUS
               FROM   ACCOUNTS
               WHERE  ACCOUNT_ID = :HV-ACCOUNT-ID
           END-EXEC

           IF SQLCODE = 0
               MOVE HV-BALANCE TO WS-DISPLAY-BALANCE
               DISPLAY "----------------------------------------"
               DISPLAY "Account:  " HV-ACCOUNT-ID
               DISPLAY "Type:     " HV-ACCOUNT-TYPE
               DISPLAY "Status:   " HV-STATUS
               DISPLAY "Balance:  $" WS-DISPLAY-BALANCE
               DISPLAY "----------------------------------------"
           ELSE IF SQLCODE = 100
               DISPLAY "Account not found."
           ELSE
               DISPLAY "ERROR retrieving account."
               DISPLAY "SQLCODE: " SQLCODE
           END-IF.

      *> ============================================================
      *> UPDATE ACCOUNT STATUS
      *> Includes closure safeguards: rejects closure when balance
      *> is non-zero or recent transactions exist (last 30 days).
      *> ============================================================
       5000-UPDATE-STATUS.
           DISPLAY SPACES
           DISPLAY "--- Update Account Status ---"
           DISPLAY "Account ID: " WITH NO ADVANCING
           ACCEPT HV-ACCOUNT-ID

           DISPLAY "New Status (1=ACTIVE, 2=CLOSED): "
               WITH NO ADVANCING
           ACCEPT WS-STATUS-CHOICE

           EVALUATE WS-STATUS-CHOICE
               WHEN 1
                   MOVE "ACTIVE" TO HV-STATUS
               WHEN 2
                   MOVE "CLOSED" TO HV-STATUS
               WHEN OTHER
                   DISPLAY "Invalid status."
                   EXIT PARAGRAPH
           END-EVALUATE

      *>   Closure safeguards
           IF HV-STATUS = "CLOSED"
               PERFORM 5100-VALIDATE-CLOSURE
               IF HV-STATUS NOT = "CLOSED"
                   EXIT PARAGRAPH
               END-IF
           END-IF

           EXEC SQL
               UPDATE ACCOUNTS
               SET    STATUS = :HV-STATUS
               WHERE  ACCOUNT_ID = :HV-ACCOUNT-ID
           END-EXEC

           IF SQLCODE = 0
               EXEC SQL COMMIT END-EXEC
               STRING "CLOSE ACCT " HV-ACCOUNT-ID
                   DELIMITED BY SIZE INTO HV-AUDIT-ACTION
               MOVE "SUCCESS" TO HV-AUDIT-STATUS
               PERFORM 8000-WRITE-AUDIT
               DISPLAY "Account status updated to "
                       HV-STATUS "."
           ELSE
               EXEC SQL ROLLBACK END-EXEC
               DISPLAY "ERROR: Could not update status."
               DISPLAY "SQLCODE: " SQLCODE
           END-IF.

      *> ============================================================
      *> VALIDATE CLOSURE
      *> Checks balance is zero and no recent transactions.
      *> Clears HV-STATUS on failure to signal rejection.
      *> ============================================================
       5100-VALIDATE-CLOSURE.
      *>   Check current balance
           EXEC SQL
               SELECT BALANCE
               INTO   :HV-BALANCE
               FROM   ACCOUNTS
               WHERE  ACCOUNT_ID = :HV-ACCOUNT-ID
           END-EXEC

           IF SQLCODE = 100
               DISPLAY "ERROR: Account not found."
               MOVE SPACES TO HV-STATUS
               EXIT PARAGRAPH
           END-IF
           IF SQLCODE NOT = 0
               DISPLAY "ERROR: Account lookup failed."
               MOVE SPACES TO HV-STATUS
               EXIT PARAGRAPH
           END-IF

           IF HV-BALANCE > 0
               MOVE HV-BALANCE TO WS-DISPLAY-BALANCE
               DISPLAY "ERROR: Cannot close account with"
               DISPLAY "       balance of $" WS-DISPLAY-BALANCE
               DISPLAY "       Withdraw or transfer funds first."
               STRING "CLOSE ACCT " HV-ACCOUNT-ID
                   DELIMITED BY SIZE INTO HV-AUDIT-ACTION
               MOVE "FAILURE" TO HV-AUDIT-STATUS
               PERFORM 8000-WRITE-AUDIT
               MOVE SPACES TO HV-STATUS
               EXIT PARAGRAPH
           END-IF

      *>   Check for recent transactions (last 30 days)
           EXEC SQL
               SELECT COUNT(*)
               INTO   :HV-TXN-COUNT
               FROM   TRANSACTIONS
               WHERE  ACCOUNT_ID = :HV-ACCOUNT-ID
               AND    CREATED_AT >= CURRENT_TIMESTAMP
                                  - INTERVAL '30 days'
           END-EXEC

           IF HV-TXN-COUNT > 0
               DISPLAY "ERROR: Cannot close account with"
               DISPLAY "       recent transactions (last 30"
               DISPLAY "       days). Count: " HV-TXN-COUNT
               STRING "CLOSE ACCT " HV-ACCOUNT-ID
                   DELIMITED BY SIZE INTO HV-AUDIT-ACTION
               MOVE "FAILURE" TO HV-AUDIT-STATUS
               PERFORM 8000-WRITE-AUDIT
               MOVE SPACES TO HV-STATUS
           END-IF.

      *> ============================================================
      *> LIST ACCOUNTS FOR A CUSTOMER (Cursor)
      *> ============================================================
       6000-LIST-ACCOUNTS.
           DISPLAY SPACES
           DISPLAY "--- List Accounts ---"
           DISPLAY "Customer ID: " WITH NO ADVANCING
           ACCEPT HV-CUSTOMER-ID

           EXEC SQL
               DECLARE CSR-ACCOUNTS CURSOR FOR
               SELECT ACCOUNT_ID,
                      BALANCE,
                      ACCOUNT_TYPE,
                      STATUS
               FROM   ACCOUNTS
               WHERE  CUSTOMER_ID = :HV-CUSTOMER-ID
               ORDER BY ACCOUNT_ID
           END-EXEC

           EXEC SQL OPEN CSR-ACCOUNTS END-EXEC

           IF SQLCODE NOT = 0
               DISPLAY "ERROR: Could not open account cursor."
               DISPLAY "SQLCODE: " SQLCODE
               EXIT PARAGRAPH
           END-IF

           DISPLAY "ACCT ID   TYPE         STATUS"
           DISPLAY "          BALANCE"
           DISPLAY "----------------------------------------"

           PERFORM 6100-FETCH-ACCOUNT
               UNTIL SQLCODE NOT = 0

           EXEC SQL CLOSE CSR-ACCOUNTS END-EXEC.

       6100-FETCH-ACCOUNT.
           EXEC SQL
               FETCH CSR-ACCOUNTS
               INTO  :HV-ACCOUNT-ID,
                     :HV-BALANCE,
                     :HV-ACCOUNT-TYPE,
                     :HV-STATUS
           END-EXEC

           IF SQLCODE = 0
               MOVE HV-BALANCE TO WS-DISPLAY-BALANCE
               DISPLAY HV-ACCOUNT-ID " "
                       HV-ACCOUNT-TYPE "  "
                       HV-STATUS
               DISPLAY "          $" WS-DISPLAY-BALANCE
           END-IF.

      *> ============================================================
      *> AUDIT LOG
      *> ============================================================
       8000-WRITE-AUDIT.
           EXEC SQL
               INSERT INTO AUDIT_LOG (ACTION, STATUS)
               VALUES (:HV-AUDIT-ACTION, :HV-AUDIT-STATUS)
           END-EXEC

           IF SQLCODE = 0
               EXEC SQL COMMIT END-EXEC
           END-IF.

      *> ============================================================
      *> DISCONNECT
      *> ============================================================
       9000-DISCONNECT-DB.
           EXEC SQL
               DISCONNECT ALL
           END-EXEC.
