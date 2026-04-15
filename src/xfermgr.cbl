       IDENTIFICATION DIVISION.
       PROGRAM-ID. XFERMGR.
      *> ============================================================
      *> TRANSFER MANAGER
      *> Processes inter-account transfers with atomic multi-table
      *> transactions, row-level locking, balance validation,
      *> and full COMMIT/ROLLBACK safety.
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
       01  HV-SOURCE-ACCT-ID     PIC S9(9) COMP.
       01  HV-TARGET-ACCT-ID     PIC S9(9) COMP.
       01  HV-SOURCE-BALANCE     PIC S9(10)V99 COMP-3.
       01  HV-TARGET-BALANCE     PIC S9(10)V99 COMP-3.
       01  HV-AMOUNT             PIC S9(10)V99 COMP-3.
       01  HV-SOURCE-STATUS      PIC X(20).
       01  HV-TARGET-STATUS      PIC X(20).
       01  HV-TXN-TYPE           PIC X(10).
       01  HV-AUDIT-ACTION       PIC X(50).
       01  HV-AUDIT-STATUS       PIC X(20).
           EXEC SQL END DECLARE SECTION END-EXEC.

      *> ----- Database Configuration -----
           COPY 'dbconfig.cpy'.

      *> ----- Working Fields -----
       01  WS-MENU-CHOICE        PIC 9(1) VALUE 0.
       01  WS-CONTINUE-FLAG      PIC X(1) VALUE 'Y'.
           88 WS-CONTINUE        VALUE 'Y' 'y'.
       01  WS-INPUT-AMOUNT       PIC 9(10)V99.
       01  WS-NEW-SOURCE-BAL     PIC S9(10)V99.
       01  WS-NEW-TARGET-BAL     PIC S9(10)V99.
       01  WS-DISPLAY-AMOUNT     PIC Z(9)9.99.
       01  WS-DISPLAY-SRC-BAL    PIC Z(9)9.99.
       01  WS-DISPLAY-TGT-BAL    PIC Z(9)9.99.

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
           DISPLAY "       TRANSFER MANAGER"
           DISPLAY "========================================"
           DISPLAY "  1. Transfer Between Accounts"
           DISPLAY "  0. Exit"
           DISPLAY "========================================"
           DISPLAY "Enter choice: " WITH NO ADVANCING
           ACCEPT WS-MENU-CHOICE

           EVALUATE WS-MENU-CHOICE
               WHEN 1
                   PERFORM 3000-PROCESS-TRANSFER
               WHEN 0
                   MOVE 'N' TO WS-CONTINUE-FLAG
               WHEN OTHER
                   DISPLAY "Invalid choice. Try again."
           END-EVALUATE.

      *> ============================================================
      *> PROCESS TRANSFER
      *> Atomic operation: debit source, credit target, record
      *> two transaction rows, audit. Full ROLLBACK on any failure.
      *> ============================================================
       3000-PROCESS-TRANSFER.
           DISPLAY SPACES
           DISPLAY "--- Inter-Account Transfer ---"

           DISPLAY "Source Account ID: " WITH NO ADVANCING
           ACCEPT HV-SOURCE-ACCT-ID

           DISPLAY "Target Account ID: " WITH NO ADVANCING
           ACCEPT HV-TARGET-ACCT-ID

      *>   Reject same-account transfers
           IF HV-SOURCE-ACCT-ID = HV-TARGET-ACCT-ID
               DISPLAY "ERROR: Source and target must differ."
               EXIT PARAGRAPH
           END-IF

           DISPLAY "Amount: " WITH NO ADVANCING
           ACCEPT WS-INPUT-AMOUNT
           MOVE WS-INPUT-AMOUNT TO HV-AMOUNT

           IF HV-AMOUNT <= 0
               DISPLAY "ERROR: Amount must be greater than zero."
               EXIT PARAGRAPH
           END-IF

      *>   Lock and validate source account
           EXEC SQL
               SELECT BALANCE, STATUS
               INTO   :HV-SOURCE-BALANCE, :HV-SOURCE-STATUS
               FROM   ACCOUNTS
               WHERE  ACCOUNT_ID = :HV-SOURCE-ACCT-ID
               FOR UPDATE
           END-EXEC

           IF SQLCODE = 100
               DISPLAY "ERROR: Source account not found."
               PERFORM 8100-ROLLBACK-TXN
               EXIT PARAGRAPH
           END-IF
           IF SQLCODE NOT = 0
               DISPLAY "ERROR: Source account lookup failed."
               DISPLAY "SQLCODE: " SQLCODE
               PERFORM 8100-ROLLBACK-TXN
               EXIT PARAGRAPH
           END-IF
           IF HV-SOURCE-STATUS NOT = "ACTIVE"
               DISPLAY "ERROR: Source account is not active."
               PERFORM 8100-ROLLBACK-TXN
               EXIT PARAGRAPH
           END-IF

      *>   Check sufficient funds
           COMPUTE WS-NEW-SOURCE-BAL =
               HV-SOURCE-BALANCE - HV-AMOUNT
           IF WS-NEW-SOURCE-BAL < 0
               DISPLAY "ERROR: Insufficient funds in source."
               MOVE HV-SOURCE-BALANCE TO WS-DISPLAY-SRC-BAL
               DISPLAY "Source Balance: $" WS-DISPLAY-SRC-BAL
               STRING "TRANSFER - SRC " HV-SOURCE-ACCT-ID
                      " TGT " HV-TARGET-ACCT-ID
                   DELIMITED BY SIZE INTO HV-AUDIT-ACTION
               MOVE "FAILURE" TO HV-AUDIT-STATUS
               PERFORM 8100-ROLLBACK-TXN
               PERFORM 8000-WRITE-AUDIT
               EXIT PARAGRAPH
           END-IF

      *>   Lock and validate target account
           EXEC SQL
               SELECT BALANCE, STATUS
               INTO   :HV-TARGET-BALANCE, :HV-TARGET-STATUS
               FROM   ACCOUNTS
               WHERE  ACCOUNT_ID = :HV-TARGET-ACCT-ID
               FOR UPDATE
           END-EXEC

           IF SQLCODE = 100
               DISPLAY "ERROR: Target account not found."
               PERFORM 8100-ROLLBACK-TXN
               EXIT PARAGRAPH
           END-IF
           IF SQLCODE NOT = 0
               DISPLAY "ERROR: Target account lookup failed."
               DISPLAY "SQLCODE: " SQLCODE
               PERFORM 8100-ROLLBACK-TXN
               EXIT PARAGRAPH
           END-IF
           IF HV-TARGET-STATUS NOT = "ACTIVE"
               DISPLAY "ERROR: Target account is not active."
               PERFORM 8100-ROLLBACK-TXN
               EXIT PARAGRAPH
           END-IF

      *>   Calculate new balances
           COMPUTE WS-NEW-TARGET-BAL =
               HV-TARGET-BALANCE + HV-AMOUNT

      *>   Debit source
           EXEC SQL
               UPDATE ACCOUNTS
               SET    BALANCE = :WS-NEW-SOURCE-BAL
               WHERE  ACCOUNT_ID = :HV-SOURCE-ACCT-ID
           END-EXEC

           IF SQLCODE NOT = 0
               DISPLAY "ERROR: Source debit failed."
               PERFORM 8100-ROLLBACK-TXN
               EXIT PARAGRAPH
           END-IF

      *>   Credit target
           EXEC SQL
               UPDATE ACCOUNTS
               SET    BALANCE = :WS-NEW-TARGET-BAL
               WHERE  ACCOUNT_ID = :HV-TARGET-ACCT-ID
           END-EXEC

           IF SQLCODE NOT = 0
               DISPLAY "ERROR: Target credit failed."
               PERFORM 8100-ROLLBACK-TXN
               EXIT PARAGRAPH
           END-IF

      *>   Record withdrawal from source
           MOVE "TRANSFER" TO HV-TXN-TYPE
           EXEC SQL
               INSERT INTO TRANSACTIONS
                   (ACCOUNT_ID, AMOUNT, TXN_TYPE)
               VALUES
                   (:HV-SOURCE-ACCT-ID, :HV-AMOUNT,
                    :HV-TXN-TYPE)
           END-EXEC

           IF SQLCODE NOT = 0
               DISPLAY "ERROR: Source transaction record failed."
               PERFORM 8100-ROLLBACK-TXN
               EXIT PARAGRAPH
           END-IF

      *>   Record deposit to target
           EXEC SQL
               INSERT INTO TRANSACTIONS
                   (ACCOUNT_ID, AMOUNT, TXN_TYPE)
               VALUES
                   (:HV-TARGET-ACCT-ID, :HV-AMOUNT,
                    :HV-TXN-TYPE)
           END-EXEC

           IF SQLCODE NOT = 0
               DISPLAY "ERROR: Target transaction record failed."
               PERFORM 8100-ROLLBACK-TXN
               EXIT PARAGRAPH
           END-IF

      *>   Commit the atomic transfer
           EXEC SQL COMMIT END-EXEC

           STRING "TRANSFER - SRC " HV-SOURCE-ACCT-ID
                  " TGT " HV-TARGET-ACCT-ID
               DELIMITED BY SIZE INTO HV-AUDIT-ACTION
           MOVE "SUCCESS" TO HV-AUDIT-STATUS
           PERFORM 8000-WRITE-AUDIT

           MOVE HV-AMOUNT         TO WS-DISPLAY-AMOUNT
           MOVE WS-NEW-SOURCE-BAL TO WS-DISPLAY-SRC-BAL
           MOVE WS-NEW-TARGET-BAL TO WS-DISPLAY-TGT-BAL
           DISPLAY "SUCCESS: Transfer of $" WS-DISPLAY-AMOUNT
           DISPLAY "  Source new balance: $" WS-DISPLAY-SRC-BAL
           DISPLAY "  Target new balance: $" WS-DISPLAY-TGT-BAL.

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

       8100-ROLLBACK-TXN.
           EXEC SQL ROLLBACK END-EXEC
           DISPLAY "Transaction rolled back.".

      *> ============================================================
      *> DISCONNECT
      *> ============================================================
       9000-DISCONNECT-DB.
           EXEC SQL
               DISCONNECT ALL
           END-EXEC.
