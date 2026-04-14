      ******************************************************************
      * TXNPROC.CBL - Transaction Processor
      * Banking System - Deposit / Withdrawal Processing
      * Uses Embedded SQL (EXEC SQL) for PostgreSQL via ocesql
      * Implements COMMIT/ROLLBACK for transaction safety
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. TXNPROC.
       AUTHOR. COBOL-DB-SYSTEM.
       DATE-WRITTEN. 2024-06-01.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       REPOSITORY.
           FUNCTION ALL INTRINSIC.

       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT BATCH-FILE
               ASSIGN TO 'data/batch_transactions.txt'
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-FILE-STATUS.

       DATA DIVISION.

       FILE SECTION.
       FD  BATCH-FILE.
       01  BATCH-RECORD              PIC X(80).

       WORKING-STORAGE SECTION.

      ******************************************************************
      * SQL Communication Area
      ******************************************************************
           EXEC SQL
               INCLUDE SQLCA
           END-EXEC.

      ******************************************************************
      * Host Variables
      ******************************************************************
       01  WS-ACCOUNT-ID            PIC 9(8)       VALUE ZEROS.
       01  WS-BALANCE               PIC S9(10)V99  VALUE ZEROS.
       01  WS-AMOUNT                PIC S9(10)V99  VALUE ZEROS.
       01  WS-NEW-BALANCE           PIC S9(10)V99  VALUE ZEROS.
       01  WS-TXN-TYPE              PIC X(10)      VALUE SPACES.
       01  WS-ACCOUNT-STATUS        PIC X(20)      VALUE SPACES.

      ******************************************************************
      * Batch Processing Variables
      ******************************************************************
       01  WS-BATCH-LINE            PIC X(80)      VALUE SPACES.
       01  WS-BATCH-ACCT-ID         PIC 9(8)       VALUE ZEROS.
       01  WS-BATCH-AMOUNT          PIC S9(10)V99  VALUE ZEROS.
       01  WS-BATCH-TYPE            PIC X(10)      VALUE SPACES.
       01  WS-COMMA-POS1            PIC 9(3)       VALUE ZEROS.
       01  WS-COMMA-POS2            PIC 9(3)       VALUE ZEROS.
       01  WS-FIELD-LEN             PIC 9(3)       VALUE ZEROS.
       01  WS-TEMP-FIELD            PIC X(20)      VALUE SPACES.

      ******************************************************************
      * Program Control Variables
      ******************************************************************
       01  WS-MENU-CHOICE           PIC 9          VALUE ZERO.
       01  WS-CONTINUE-FLAG         PIC X          VALUE 'Y'.
           88 WS-CONTINUE                          VALUE 'Y' 'y'.
           88 WS-EXIT                              VALUE 'N' 'n'.
       01  WS-FILE-STATUS           PIC XX         VALUE '00'.
       01  WS-EOF-FLAG              PIC X          VALUE 'N'.
           88 WS-EOF                               VALUE 'Y'.
           88 WS-NOT-EOF                           VALUE 'N'.
       01  WS-TXN-SUCCESS-FLAG      PIC X          VALUE 'N'.
           88 WS-TXN-SUCCESS                       VALUE 'Y'.
           88 WS-TXN-FAILED                        VALUE 'N'.

      ******************************************************************
      * Counters for batch processing
      ******************************************************************
       01  WS-BATCH-TOTAL           PIC 9(6)       VALUE ZEROS.
       01  WS-BATCH-SUCCESS         PIC 9(6)       VALUE ZEROS.
       01  WS-BATCH-FAILED          PIC 9(6)       VALUE ZEROS.

      ******************************************************************
      * Database Configuration
      ******************************************************************
           COPY 'cpy/dbconfig.cpy'.

      ******************************************************************
      * Display Formatting
      ******************************************************************
       01  WS-SEPARATOR             PIC X(60)      VALUE ALL '-'.
       01  WS-DISPLAY-ID            PIC Z(7)9.
       01  WS-DISPLAY-BALANCE       PIC $$$,$$$,$$9.99.
       01  WS-DISPLAY-AMOUNT        PIC $$$,$$$,$$9.99.

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
           DISPLAY '============================================'
           DISPLAY '  COBOL BANKING SYSTEM - TRANSACTION PROCESSOR'
           DISPLAY '============================================'
           .

      ******************************************************************
      * Main menu loop
      ******************************************************************
       2000-PROCESS-MENU.
           DISPLAY SPACES
           DISPLAY WS-SEPARATOR
           DISPLAY '  TRANSACTION PROCESSOR MENU'
           DISPLAY WS-SEPARATOR
           DISPLAY '  1. Process Deposit'
           DISPLAY '  2. Process Withdrawal'
           DISPLAY '  3. Process Batch Transactions'
           DISPLAY '  9. Exit'
           DISPLAY WS-SEPARATOR
           DISPLAY 'Enter choice: ' WITH NO ADVANCING
           ACCEPT WS-MENU-CHOICE

           EVALUATE WS-MENU-CHOICE
               WHEN 1
                   MOVE 'DEPOSIT' TO WS-TXN-TYPE
                   PERFORM 3000-GET-TRANSACTION-INPUT
               WHEN 2
                   MOVE 'WITHDRAW' TO WS-TXN-TYPE
                   PERFORM 3000-GET-TRANSACTION-INPUT
               WHEN 3
                   PERFORM 6000-PROCESS-BATCH
               WHEN 9
                   SET WS-EXIT TO TRUE
               WHEN OTHER
                   DISPLAY 'ERROR: Invalid choice. Try again.'
           END-EVALUATE
           .

      ******************************************************************
      * Get transaction input from user
      ******************************************************************
       3000-GET-TRANSACTION-INPUT.
           DISPLAY SPACES
           DISPLAY '--- PROCESS '
               FUNCTION TRIM(WS-TXN-TYPE) ' ---'

           DISPLAY 'Enter Account ID: ' WITH NO ADVANCING
           ACCEPT WS-ACCOUNT-ID

           IF WS-ACCOUNT-ID = ZEROS
               DISPLAY 'ERROR: Invalid Account ID.'
               GO TO 3000-EXIT
           END-IF

           DISPLAY 'Enter Amount: ' WITH NO ADVANCING
           ACCEPT WS-AMOUNT

           IF WS-AMOUNT <= ZEROS
               DISPLAY 'ERROR: Amount must be greater than zero.'
               GO TO 3000-EXIT
           END-IF

           PERFORM 4000-EXECUTE-TRANSACTION
           .
       3000-EXIT.
           EXIT
           .

      ******************************************************************
      * Execute the transaction with full COMMIT/ROLLBACK safety
      ******************************************************************
       4000-EXECUTE-TRANSACTION.
           SET WS-TXN-FAILED TO TRUE
      *    Step 1: Validate account exists and is active
           EXEC SQL
               SELECT BALANCE, STATUS
               INTO :WS-BALANCE, :WS-ACCOUNT-STATUS
               FROM ACCOUNTS
               WHERE ACCOUNT_ID = :WS-ACCOUNT-ID
           END-EXEC

           IF SQLCODE = 100
               DISPLAY 'ERROR: Account ' WS-ACCOUNT-ID
                   ' not found.'
               PERFORM 5000-LOG-FAILURE
               GO TO 4000-EXIT
           END-IF

           IF SQLCODE NOT = ZERO
               DISPLAY 'ERROR: Database error. SQLCODE: ' SQLCODE
               PERFORM 5000-LOG-FAILURE
               GO TO 4000-EXIT
           END-IF

      *    Step 2: Verify account is active
           IF WS-ACCOUNT-STATUS NOT = 'ACTIVE'
               DISPLAY 'ERROR: Account is not active.'
               DISPLAY '  Status: '
                   FUNCTION TRIM(WS-ACCOUNT-STATUS)
               PERFORM 5000-LOG-FAILURE
               GO TO 4000-EXIT
           END-IF

      *    Step 3: Calculate new balance
           IF WS-TXN-TYPE = 'DEPOSIT'
               COMPUTE WS-NEW-BALANCE =
                   WS-BALANCE + WS-AMOUNT
           ELSE
      *        Withdrawal - check sufficient funds
               IF WS-AMOUNT > WS-BALANCE
                   MOVE WS-BALANCE TO WS-DISPLAY-BALANCE
                   MOVE WS-AMOUNT TO WS-DISPLAY-AMOUNT
                   DISPLAY 'ERROR: Insufficient funds.'
                   DISPLAY '  Requested: ' WS-DISPLAY-AMOUNT
                   DISPLAY '  Available: ' WS-DISPLAY-BALANCE
                   PERFORM 5000-LOG-FAILURE
                   GO TO 4000-EXIT
               END-IF
               COMPUTE WS-NEW-BALANCE =
                   WS-BALANCE - WS-AMOUNT
           END-IF

      *    Step 4: Update balance
           EXEC SQL
               UPDATE ACCOUNTS
               SET BALANCE = :WS-NEW-BALANCE
               WHERE ACCOUNT_ID = :WS-ACCOUNT-ID
           END-EXEC

           IF SQLCODE NOT = ZERO
               DISPLAY 'ERROR: Balance update failed.'
               DISPLAY 'SQLCODE: ' SQLCODE
               EXEC SQL ROLLBACK END-EXEC
               PERFORM 5000-LOG-FAILURE
               GO TO 4000-EXIT
           END-IF

      *    Step 5: Insert transaction record
           EXEC SQL
               INSERT INTO TRANSACTIONS
                   (ACCOUNT_ID, AMOUNT, TXN_TYPE)
               VALUES
                   (:WS-ACCOUNT-ID, :WS-AMOUNT, :WS-TXN-TYPE)
           END-EXEC

           IF SQLCODE NOT = ZERO
               DISPLAY 'ERROR: Transaction record insert failed.'
               DISPLAY 'SQLCODE: ' SQLCODE
               EXEC SQL ROLLBACK END-EXEC
               PERFORM 5000-LOG-FAILURE
               GO TO 4000-EXIT
           END-IF

      *    Step 6: COMMIT the transaction
           EXEC SQL COMMIT END-EXEC

           IF SQLCODE NOT = ZERO
               DISPLAY 'ERROR: Commit failed. SQLCODE: ' SQLCODE
               EXEC SQL ROLLBACK END-EXEC
               PERFORM 5000-LOG-FAILURE
               GO TO 4000-EXIT
           END-IF

      *    Step 7: Mark success and display results
           SET WS-TXN-SUCCESS TO TRUE
           MOVE WS-NEW-BALANCE TO WS-DISPLAY-BALANCE
           MOVE WS-AMOUNT TO WS-DISPLAY-AMOUNT
           DISPLAY 'SUCCESS: '
               FUNCTION TRIM(WS-TXN-TYPE) ' processed.'
           DISPLAY '  Amount      : ' WS-DISPLAY-AMOUNT
           DISPLAY '  New Balance : ' WS-DISPLAY-BALANCE

      *    Step 8: Audit log
           EXEC SQL
               INSERT INTO AUDIT_LOG (ACTION, STATUS, DETAILS)
               VALUES (:WS-TXN-TYPE, 'SUCCESS',
                       TRIM(:WS-TXN-TYPE) || ' of ' ||
                       CAST(:WS-AMOUNT AS VARCHAR(15)) ||
                       ' on account ' ||
                       CAST(:WS-ACCOUNT-ID AS VARCHAR(8)))
           END-EXEC
           EXEC SQL COMMIT END-EXEC
           .
       4000-EXIT.
           EXIT
           .

      ******************************************************************
      * Log transaction failure to audit
      ******************************************************************
       5000-LOG-FAILURE.
           EXEC SQL
               INSERT INTO AUDIT_LOG (ACTION, STATUS, DETAILS)
               VALUES (:WS-TXN-TYPE, 'FAILURE',
                       'Failed ' || TRIM(:WS-TXN-TYPE) ||
                       ' on account ' ||
                       CAST(:WS-ACCOUNT-ID AS VARCHAR(8)))
           END-EXEC
           EXEC SQL COMMIT END-EXEC
           .

      ******************************************************************
      * Batch processing - read CSV file and process each line
      ******************************************************************
       6000-PROCESS-BATCH.
           DISPLAY SPACES
           DISPLAY '--- BATCH TRANSACTION PROCESSING ---'

           MOVE ZEROS TO WS-BATCH-TOTAL
           MOVE ZEROS TO WS-BATCH-SUCCESS
           MOVE ZEROS TO WS-BATCH-FAILED
           SET WS-NOT-EOF TO TRUE

           OPEN INPUT BATCH-FILE

           IF WS-FILE-STATUS NOT = '00'
               DISPLAY 'ERROR: Cannot open batch file.'
               DISPLAY '  File Status: ' WS-FILE-STATUS
               DISPLAY '  Expected: data/batch_transactions.txt'
               GO TO 6000-EXIT
           END-IF

           DISPLAY 'Processing batch file...'
           DISPLAY SPACES

           PERFORM 6100-READ-BATCH-RECORD
               UNTIL WS-EOF

           CLOSE BATCH-FILE

           DISPLAY SPACES
           DISPLAY WS-SEPARATOR
           DISPLAY '  BATCH PROCESSING SUMMARY'
           DISPLAY WS-SEPARATOR
           DISPLAY '  Total Processed : ' WS-BATCH-TOTAL
           DISPLAY '  Successful      : ' WS-BATCH-SUCCESS
           DISPLAY '  Failed          : ' WS-BATCH-FAILED
           DISPLAY WS-SEPARATOR
           .
       6000-EXIT.
           EXIT
           .

      ******************************************************************
      * Read and parse a single batch record (CSV: ACCT,AMT,TYPE)
      ******************************************************************
       6100-READ-BATCH-RECORD.
           READ BATCH-FILE INTO WS-BATCH-LINE
               AT END
                   SET WS-EOF TO TRUE
               NOT AT END
                   ADD 1 TO WS-BATCH-TOTAL
                   PERFORM 6200-PARSE-BATCH-LINE
                   PERFORM 6300-PROCESS-BATCH-TXN
           END-READ
           .

      ******************************************************************
      * Parse CSV line: ACCOUNT_ID,AMOUNT,TXN_TYPE
      ******************************************************************
       6200-PARSE-BATCH-LINE.
           MOVE SPACES TO WS-TEMP-FIELD
           MOVE ZEROS TO WS-COMMA-POS1
           MOVE ZEROS TO WS-COMMA-POS2

      *    Find first comma
           INSPECT WS-BATCH-LINE TALLYING WS-COMMA-POS1
               FOR CHARACTERS BEFORE INITIAL ','

           IF WS-COMMA-POS1 = ZERO OR
              WS-COMMA-POS1 >= FUNCTION LENGTH(WS-BATCH-LINE)
               DISPLAY 'WARNING: Malformed batch record skipped.'
               MOVE ZEROS TO WS-BATCH-ACCT-ID
               GO TO 6200-EXIT
           END-IF

      *    Extract account ID
           MOVE WS-BATCH-LINE(1:WS-COMMA-POS1) TO WS-TEMP-FIELD
           COMPUTE WS-BATCH-ACCT-ID =
               FUNCTION NUMVAL(FUNCTION TRIM(WS-TEMP-FIELD))

      *    Find second comma (search from after first comma)
           MOVE ZEROS TO WS-COMMA-POS2
           COMPUTE WS-FIELD-LEN =
               FUNCTION LENGTH(FUNCTION TRIM(WS-BATCH-LINE))
               - WS-COMMA-POS1 - 1

           MOVE WS-BATCH-LINE(WS-COMMA-POS1 + 2:WS-FIELD-LEN)
               TO WS-TEMP-FIELD

           MOVE ZEROS TO WS-COMMA-POS2
           INSPECT WS-TEMP-FIELD TALLYING WS-COMMA-POS2
               FOR CHARACTERS BEFORE INITIAL ','

      *    Extract amount
           MOVE SPACES TO WS-TEMP-FIELD
           MOVE WS-BATCH-LINE(WS-COMMA-POS1 + 2:WS-COMMA-POS2)
               TO WS-TEMP-FIELD
           COMPUTE WS-BATCH-AMOUNT =
               FUNCTION NUMVAL(FUNCTION TRIM(WS-TEMP-FIELD))

      *    Extract transaction type (rest of line after second comma)
           COMPUTE WS-FIELD-LEN =
               WS-COMMA-POS1 + WS-COMMA-POS2 + 2
           MOVE SPACES TO WS-BATCH-TYPE
           MOVE WS-BATCH-LINE(WS-FIELD-LEN + 1:10)
               TO WS-BATCH-TYPE
           MOVE FUNCTION TRIM(WS-BATCH-TYPE) TO WS-BATCH-TYPE
           MOVE FUNCTION UPPER-CASE(WS-BATCH-TYPE)
               TO WS-BATCH-TYPE
           .
       6200-EXIT.
           EXIT
           .

      ******************************************************************
      * Process a single batch transaction
      ******************************************************************
       6300-PROCESS-BATCH-TXN.
           IF WS-BATCH-ACCT-ID = ZEROS
               ADD 1 TO WS-BATCH-FAILED
               GO TO 6300-EXIT
           END-IF

      *    Validate transaction type
           IF WS-BATCH-TYPE NOT = 'DEPOSIT' AND
              WS-BATCH-TYPE NOT = 'WITHDRAW'
               DISPLAY '  SKIP: Invalid type "'
                   FUNCTION TRIM(WS-BATCH-TYPE)
                   '" for account ' WS-BATCH-ACCT-ID
               ADD 1 TO WS-BATCH-FAILED
               GO TO 6300-EXIT
           END-IF

      *    Set up transaction variables and execute
           MOVE WS-BATCH-ACCT-ID TO WS-ACCOUNT-ID
           MOVE WS-BATCH-AMOUNT TO WS-AMOUNT
           MOVE WS-BATCH-TYPE TO WS-TXN-TYPE

           MOVE WS-AMOUNT TO WS-DISPLAY-AMOUNT
           DISPLAY '  Processing: Account '
               WS-ACCOUNT-ID ' '
               FUNCTION TRIM(WS-TXN-TYPE) ' '
               WS-DISPLAY-AMOUNT

           PERFORM 4000-EXECUTE-TRANSACTION

      *    Check if the financial transaction succeeded
           IF WS-TXN-SUCCESS
               ADD 1 TO WS-BATCH-SUCCESS
           ELSE
               ADD 1 TO WS-BATCH-FAILED
           END-IF
           .
       6300-EXIT.
           EXIT
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
           DISPLAY 'Transaction Processor terminated.'
           .
