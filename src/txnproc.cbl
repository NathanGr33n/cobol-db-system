       IDENTIFICATION DIVISION.
       PROGRAM-ID. TXNPROC.
      *> ============================================================
      *> TRANSACTION PROCESSOR
      *> Processes deposits and withdrawals with balance validation,
      *> transaction recording, audit logging, and full COMMIT/
      *> ROLLBACK safety.
      *> ============================================================

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       REPOSITORY.

       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT BATCH-FILE ASSIGN TO 'data/batch_transactions.txt'
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-BATCH-STATUS.

       DATA DIVISION.

       FILE SECTION.
       FD  BATCH-FILE.
       01  BATCH-RECORD             PIC X(100).

       WORKING-STORAGE SECTION.

      *> ----- SQL Communication Area -----
           EXEC SQL
               INCLUDE SQLCA
           END-EXEC.

      *> ----- Host Variables -----
           EXEC SQL BEGIN DECLARE SECTION END-EXEC.
       01  HV-ACCOUNT-ID         PIC S9(9) COMP.
       01  HV-BALANCE            PIC S9(10)V99 COMP-3.
       01  HV-AMOUNT             PIC S9(10)V99 COMP-3.
       01  HV-TXN-TYPE           PIC X(10).
       01  HV-STATUS             PIC X(20).
       01  HV-AUDIT-ACTION       PIC X(50).
       01  HV-AUDIT-STATUS       PIC X(20).
           EXEC SQL END DECLARE SECTION END-EXEC.

      *> ----- Database Configuration -----
           COPY 'dbconfig.cpy'.

      *> ----- Working Fields -----
       01  WS-MENU-CHOICE        PIC 9(1) VALUE 0.
       01  WS-CONTINUE-FLAG      PIC X(1) VALUE 'Y'.
           88 WS-CONTINUE        VALUE 'Y' 'y'.
       01  WS-DISPLAY-BALANCE    PIC Z(9)9.99.
       01  WS-DISPLAY-AMOUNT     PIC Z(9)9.99.
       01  WS-INPUT-AMOUNT       PIC 9(10)V99.
       01  WS-NEW-BALANCE        PIC S9(10)V99.

      *> ----- Batch Processing Fields -----
       01  WS-BATCH-STATUS       PIC XX VALUE SPACES.
       01  WS-BATCH-EOF          PIC X(1) VALUE 'N'.
           88 WS-BATCH-DONE      VALUE 'Y'.
       01  WS-BATCH-ACCT         PIC 9(9).
       01  WS-BATCH-AMT          PIC 9(10)V99.
       01  WS-BATCH-TYPE         PIC X(10).
       01  WS-BATCH-COUNT        PIC 9(5) VALUE 0.
       01  WS-BATCH-SUCCESS      PIC 9(5) VALUE 0.
       01  WS-BATCH-FAIL         PIC 9(5) VALUE 0.

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
           DISPLAY "     TRANSACTION PROCESSOR"
           DISPLAY "========================================"
           DISPLAY "  1. Process Deposit"
           DISPLAY "  2. Process Withdrawal"
           DISPLAY "  3. Run Batch Transactions"
           DISPLAY "  0. Exit"
           DISPLAY "========================================"
           DISPLAY "Enter choice: " WITH NO ADVANCING
           ACCEPT WS-MENU-CHOICE

           EVALUATE WS-MENU-CHOICE
               WHEN 1
                   PERFORM 3000-PROCESS-DEPOSIT
               WHEN 2
                   PERFORM 4000-PROCESS-WITHDRAWAL
               WHEN 3
                   PERFORM 5000-BATCH-PROCESS
               WHEN 0
                   MOVE 'N' TO WS-CONTINUE-FLAG
               WHEN OTHER
                   DISPLAY "Invalid choice. Try again."
           END-EVALUATE.

      *> ============================================================
      *> PROCESS DEPOSIT
      *> ============================================================
       3000-PROCESS-DEPOSIT.
           DISPLAY SPACES
           DISPLAY "--- Process Deposit ---"
           DISPLAY "Account ID: " WITH NO ADVANCING
           ACCEPT HV-ACCOUNT-ID

      *>   Validate account exists and is active
           PERFORM 7000-VALIDATE-ACCOUNT
           IF HV-STATUS NOT = "ACTIVE"
               EXIT PARAGRAPH
           END-IF

           DISPLAY "Amount: " WITH NO ADVANCING
           ACCEPT WS-INPUT-AMOUNT
           MOVE WS-INPUT-AMOUNT TO HV-AMOUNT

           IF HV-AMOUNT <= 0
               DISPLAY "ERROR: Amount must be greater than zero."
               EXIT PARAGRAPH
           END-IF

      *>   Calculate new balance
           COMPUTE WS-NEW-BALANCE = HV-BALANCE + HV-AMOUNT

      *>   Update balance
           EXEC SQL
               UPDATE ACCOUNTS
               SET    BALANCE = :WS-NEW-BALANCE
               WHERE  ACCOUNT_ID = :HV-ACCOUNT-ID
           END-EXEC

           IF SQLCODE NOT = 0
               PERFORM 8100-ROLLBACK-TXN
               MOVE "DEPOSIT"  TO HV-AUDIT-ACTION
               MOVE "FAILURE"  TO HV-AUDIT-STATUS
               PERFORM 8000-WRITE-AUDIT
               DISPLAY "ERROR: Balance update failed."
               EXIT PARAGRAPH
           END-IF

      *>   Record the transaction
           MOVE "DEPOSIT" TO HV-TXN-TYPE
           EXEC SQL
               INSERT INTO TRANSACTIONS
                   (ACCOUNT_ID, AMOUNT, TXN_TYPE)
               VALUES
                   (:HV-ACCOUNT-ID, :HV-AMOUNT, :HV-TXN-TYPE)
           END-EXEC

           IF SQLCODE NOT = 0
               PERFORM 8100-ROLLBACK-TXN
               DISPLAY "ERROR: Transaction record failed."
               EXIT PARAGRAPH
           END-IF

      *>   Commit and audit
           EXEC SQL COMMIT END-EXEC

           STRING "DEPOSIT  - ACCT " HV-ACCOUNT-ID
               DELIMITED BY SIZE INTO HV-AUDIT-ACTION
           MOVE "SUCCESS" TO HV-AUDIT-STATUS
           PERFORM 8000-WRITE-AUDIT

           MOVE WS-NEW-BALANCE TO WS-DISPLAY-BALANCE
           DISPLAY "SUCCESS: New Balance = $"
                   WS-DISPLAY-BALANCE.

      *> ============================================================
      *> PROCESS WITHDRAWAL
      *> ============================================================
       4000-PROCESS-WITHDRAWAL.
           DISPLAY SPACES
           DISPLAY "--- Process Withdrawal ---"
           DISPLAY "Account ID: " WITH NO ADVANCING
           ACCEPT HV-ACCOUNT-ID

      *>   Validate account
           PERFORM 7000-VALIDATE-ACCOUNT
           IF HV-STATUS NOT = "ACTIVE"
               EXIT PARAGRAPH
           END-IF

           DISPLAY "Amount: " WITH NO ADVANCING
           ACCEPT WS-INPUT-AMOUNT
           MOVE WS-INPUT-AMOUNT TO HV-AMOUNT

           IF HV-AMOUNT <= 0
               DISPLAY "ERROR: Amount must be greater than zero."
               EXIT PARAGRAPH
           END-IF

      *>   Check sufficient funds
           COMPUTE WS-NEW-BALANCE = HV-BALANCE - HV-AMOUNT
           IF WS-NEW-BALANCE < 0
               DISPLAY "ERROR: Insufficient funds."
               DISPLAY "Current Balance: $" HV-BALANCE
               STRING "WITHDRAW - ACCT " HV-ACCOUNT-ID
                   DELIMITED BY SIZE INTO HV-AUDIT-ACTION
               MOVE "FAILURE" TO HV-AUDIT-STATUS
               PERFORM 8000-WRITE-AUDIT
               EXIT PARAGRAPH
           END-IF

      *>   Update balance
           EXEC SQL
               UPDATE ACCOUNTS
               SET    BALANCE = :WS-NEW-BALANCE
               WHERE  ACCOUNT_ID = :HV-ACCOUNT-ID
           END-EXEC

           IF SQLCODE NOT = 0
               PERFORM 8100-ROLLBACK-TXN
               DISPLAY "ERROR: Balance update failed."
               EXIT PARAGRAPH
           END-IF

      *>   Record the transaction
           MOVE "WITHDRAW" TO HV-TXN-TYPE
           EXEC SQL
               INSERT INTO TRANSACTIONS
                   (ACCOUNT_ID, AMOUNT, TXN_TYPE)
               VALUES
                   (:HV-ACCOUNT-ID, :HV-AMOUNT, :HV-TXN-TYPE)
           END-EXEC

           IF SQLCODE NOT = 0
               PERFORM 8100-ROLLBACK-TXN
               DISPLAY "ERROR: Transaction record failed."
               EXIT PARAGRAPH
           END-IF

      *>   Commit and audit
           EXEC SQL COMMIT END-EXEC

           STRING "WITHDRAW - ACCT " HV-ACCOUNT-ID
               DELIMITED BY SIZE INTO HV-AUDIT-ACTION
           MOVE "SUCCESS" TO HV-AUDIT-STATUS
           PERFORM 8000-WRITE-AUDIT

           MOVE WS-NEW-BALANCE TO WS-DISPLAY-BALANCE
           DISPLAY "SUCCESS: New Balance = $"
                   WS-DISPLAY-BALANCE.

      *> ============================================================
      *> BATCH PROCESSING
      *> Reads batch_transactions.txt and processes each line.
      *> Format: ACCOUNT_ID,AMOUNT,TXN_TYPE
      *> ============================================================
       5000-BATCH-PROCESS.
           DISPLAY SPACES
           DISPLAY "--- Batch Transaction Processing ---"

           OPEN INPUT BATCH-FILE
           IF WS-BATCH-STATUS NOT = "00"
               DISPLAY "ERROR: Could not open batch file."
               DISPLAY "File status: " WS-BATCH-STATUS
               EXIT PARAGRAPH
           END-IF

           MOVE 0 TO WS-BATCH-COUNT
           MOVE 0 TO WS-BATCH-SUCCESS
           MOVE 0 TO WS-BATCH-FAIL
           MOVE 'N' TO WS-BATCH-EOF

           PERFORM 5100-READ-BATCH
           PERFORM 5200-PROCESS-BATCH-LINE
               UNTIL WS-BATCH-DONE

           CLOSE BATCH-FILE

           DISPLAY "----------------------------------------"
           DISPLAY "Batch Complete."
           DISPLAY "Total:     " WS-BATCH-COUNT
           DISPLAY "Succeeded: " WS-BATCH-SUCCESS
           DISPLAY "Failed:    " WS-BATCH-FAIL
           DISPLAY "----------------------------------------".

       5100-READ-BATCH.
           READ BATCH-FILE INTO BATCH-RECORD
               AT END
                   MOVE 'Y' TO WS-BATCH-EOF
           END-READ.

       5200-PROCESS-BATCH-LINE.
           IF WS-BATCH-DONE
               EXIT PARAGRAPH
           END-IF

           ADD 1 TO WS-BATCH-COUNT

      *>   Parse CSV: ACCOUNT_ID,AMOUNT,TXN_TYPE
           UNSTRING BATCH-RECORD DELIMITED BY ","
               INTO WS-BATCH-ACCT
                    WS-BATCH-AMT
                    WS-BATCH-TYPE
           END-UNSTRING

           MOVE WS-BATCH-ACCT TO HV-ACCOUNT-ID
           MOVE WS-BATCH-AMT  TO HV-AMOUNT
           MOVE WS-BATCH-TYPE  TO HV-TXN-TYPE

      *>   Validate account
           PERFORM 7000-VALIDATE-ACCOUNT

           IF HV-STATUS NOT = "ACTIVE"
               ADD 1 TO WS-BATCH-FAIL
               PERFORM 5100-READ-BATCH
               EXIT PARAGRAPH
           END-IF

      *>   Process based on type
           EVALUATE TRUE
               WHEN HV-TXN-TYPE = "DEPOSIT"
                   COMPUTE WS-NEW-BALANCE =
                       HV-BALANCE + HV-AMOUNT
               WHEN HV-TXN-TYPE = "WITHDRAW"
                   COMPUTE WS-NEW-BALANCE =
                       HV-BALANCE - HV-AMOUNT
                   IF WS-NEW-BALANCE < 0
                       ADD 1 TO WS-BATCH-FAIL
                       DISPLAY "SKIP: Insufficient funds ACCT "
                               HV-ACCOUNT-ID
                       PERFORM 5100-READ-BATCH
                       EXIT PARAGRAPH
                   END-IF
               WHEN OTHER
                   ADD 1 TO WS-BATCH-FAIL
                   DISPLAY "SKIP: Unknown type " HV-TXN-TYPE
                   PERFORM 5100-READ-BATCH
                   EXIT PARAGRAPH
           END-EVALUATE

      *>   Update balance
           EXEC SQL
               UPDATE ACCOUNTS
               SET    BALANCE = :WS-NEW-BALANCE
               WHERE  ACCOUNT_ID = :HV-ACCOUNT-ID
           END-EXEC

           IF SQLCODE NOT = 0
               PERFORM 8100-ROLLBACK-TXN
               ADD 1 TO WS-BATCH-FAIL
               PERFORM 5100-READ-BATCH
               EXIT PARAGRAPH
           END-IF

      *>   Record transaction
           EXEC SQL
               INSERT INTO TRANSACTIONS
                   (ACCOUNT_ID, AMOUNT, TXN_TYPE)
               VALUES
                   (:HV-ACCOUNT-ID, :HV-AMOUNT, :HV-TXN-TYPE)
           END-EXEC

           IF SQLCODE NOT = 0
               PERFORM 8100-ROLLBACK-TXN
               ADD 1 TO WS-BATCH-FAIL
               PERFORM 5100-READ-BATCH
               EXIT PARAGRAPH
           END-IF

           EXEC SQL COMMIT END-EXEC
           ADD 1 TO WS-BATCH-SUCCESS

           STRING HV-TXN-TYPE " - ACCT " HV-ACCOUNT-ID
               DELIMITED BY SIZE INTO HV-AUDIT-ACTION
           MOVE "SUCCESS" TO HV-AUDIT-STATUS
           PERFORM 8000-WRITE-AUDIT

           PERFORM 5100-READ-BATCH.

      *> ============================================================
      *> VALIDATE ACCOUNT - shared helper
      *> Locks the row with FOR UPDATE to prevent concurrent
      *> modification. Sets HV-BALANCE and HV-STATUS.
      *> On failure, displays error and sets HV-STATUS to spaces.
      *> ============================================================
       7000-VALIDATE-ACCOUNT.
           EXEC SQL
               SELECT BALANCE,
                      STATUS
               INTO   :HV-BALANCE,
                      :HV-STATUS
               FROM   ACCOUNTS
               WHERE  ACCOUNT_ID = :HV-ACCOUNT-ID
               FOR UPDATE
           END-EXEC

           EVALUATE TRUE
               WHEN SQLCODE = 100
                   DISPLAY "ERROR: Account not found."
                   MOVE SPACES TO HV-STATUS
               WHEN SQLCODE NOT = 0
                   DISPLAY "ERROR: Account lookup failed."
                   DISPLAY "SQLCODE: " SQLCODE
                   MOVE SPACES TO HV-STATUS
               WHEN HV-STATUS NOT = "ACTIVE"
                   DISPLAY "ERROR: Account is not active."
           END-EVALUATE.

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
