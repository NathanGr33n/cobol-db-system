       IDENTIFICATION DIVISION.
       PROGRAM-ID. INTCALC.
      *> ============================================================
      *> INTEREST CALCULATOR (Batch)
      *> Iterates all active SAVINGS accounts with a non-zero
      *> interest rate, computes monthly interest, credits it as
      *> an INTEREST transaction, and produces a summary report.
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
       01  HV-INTEREST-RATE      PIC S9(1)V9(4) COMP-3.
       01  HV-INTEREST-AMOUNT    PIC S9(10)V99 COMP-3.
       01  HV-NEW-BALANCE        PIC S9(10)V99 COMP-3.
       01  HV-TXN-TYPE           PIC X(10).
       01  HV-AUDIT-ACTION       PIC X(50).
       01  HV-AUDIT-STATUS       PIC X(20).
           EXEC SQL END DECLARE SECTION END-EXEC.

      *> ----- Database Configuration -----
           COPY 'dbconfig.cpy'.

      *> ----- Working Fields -----
       01  WS-ACCT-COUNT         PIC 9(5) VALUE 0.
       01  WS-PROCESSED          PIC 9(5) VALUE 0.
       01  WS-TOTAL-INTEREST     PIC S9(12)V99 VALUE 0.
       01  WS-DISPLAY-BALANCE    PIC Z(9)9.99.
       01  WS-DISPLAY-INTEREST   PIC Z(9)9.99.
       01  WS-DISPLAY-TOTAL      PIC Z(12)9.99.
       01  WS-DISPLAY-RATE       PIC 9.9999.

       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-CONNECT-DB
           PERFORM 2000-RUN-INTEREST-BATCH
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
      *> BATCH INTEREST CALCULATION
      *> ============================================================
       2000-RUN-INTEREST-BATCH.
           DISPLAY SPACES
           DISPLAY "============================================="
           DISPLAY " MONTHLY INTEREST CALCULATION"
           DISPLAY "============================================="
           DISPLAY SPACES

           EXEC SQL
               DECLARE CSR-SAVINGS CURSOR FOR
               SELECT ACCOUNT_ID,
                      CUSTOMER_ID,
                      BALANCE,
                      INTEREST_RATE
               FROM   ACCOUNTS
               WHERE  ACCOUNT_TYPE = 'SAVINGS'
               AND    STATUS       = 'ACTIVE'
               AND    INTEREST_RATE > 0
               ORDER BY ACCOUNT_ID
               FOR UPDATE
           END-EXEC

           EXEC SQL OPEN CSR-SAVINGS END-EXEC

           IF SQLCODE NOT = 0
               DISPLAY "ERROR: Could not open savings cursor."
               DISPLAY "SQLCODE: " SQLCODE
               EXIT PARAGRAPH
           END-IF

           DISPLAY "ACCT ID   BALANCE       RATE    INTEREST"
           DISPLAY "---------------------------------------------"

           MOVE 0 TO WS-ACCT-COUNT
           MOVE 0 TO WS-PROCESSED
           MOVE 0 TO WS-TOTAL-INTEREST

           PERFORM 2100-FETCH-AND-CREDIT
               UNTIL SQLCODE NOT = 0

           EXEC SQL CLOSE CSR-SAVINGS END-EXEC

           MOVE WS-TOTAL-INTEREST TO WS-DISPLAY-TOTAL
           DISPLAY "---------------------------------------------"
           DISPLAY "Accounts processed: " WS-PROCESSED
           DISPLAY "Total interest:     $" WS-DISPLAY-TOTAL
           DISPLAY "============================================="

           MOVE "INTEREST BATCH RUN" TO HV-AUDIT-ACTION
           MOVE "SUCCESS" TO HV-AUDIT-STATUS
           PERFORM 8000-WRITE-AUDIT.

      *> ============================================================
      *> FETCH AND CREDIT INTEREST
      *> ============================================================
       2100-FETCH-AND-CREDIT.
           EXEC SQL
               FETCH CSR-SAVINGS
               INTO  :HV-ACCOUNT-ID,
                     :HV-CUSTOMER-ID,
                     :HV-BALANCE,
                     :HV-INTEREST-RATE
           END-EXEC

           IF SQLCODE NOT = 0
               EXIT PARAGRAPH
           END-IF

           ADD 1 TO WS-ACCT-COUNT

      *>   Monthly interest = BALANCE * RATE / 12
           COMPUTE HV-INTEREST-AMOUNT ROUNDED =
               HV-BALANCE * HV-INTEREST-RATE / 12

      *>   Skip if interest rounds to zero
           IF HV-INTEREST-AMOUNT <= 0
               EXIT PARAGRAPH
           END-IF

      *>   Credit the interest
           COMPUTE HV-NEW-BALANCE =
               HV-BALANCE + HV-INTEREST-AMOUNT

           EXEC SQL
               UPDATE ACCOUNTS
               SET    BALANCE = :HV-NEW-BALANCE
               WHERE  ACCOUNT_ID = :HV-ACCOUNT-ID
           END-EXEC

           IF SQLCODE NOT = 0
               DISPLAY "ERROR: Update failed ACCT "
                       HV-ACCOUNT-ID
               EXEC SQL ROLLBACK END-EXEC
               EXIT PARAGRAPH
           END-IF

      *>   Record interest transaction
           MOVE "INTEREST" TO HV-TXN-TYPE
           EXEC SQL
               INSERT INTO TRANSACTIONS
                   (ACCOUNT_ID, AMOUNT, TXN_TYPE)
               VALUES
                   (:HV-ACCOUNT-ID, :HV-INTEREST-AMOUNT,
                    :HV-TXN-TYPE)
           END-EXEC

           IF SQLCODE NOT = 0
               DISPLAY "ERROR: Transaction insert failed ACCT "
                       HV-ACCOUNT-ID
               EXEC SQL ROLLBACK END-EXEC
               EXIT PARAGRAPH
           END-IF

           EXEC SQL COMMIT END-EXEC

           ADD 1 TO WS-PROCESSED
           ADD HV-INTEREST-AMOUNT TO WS-TOTAL-INTEREST

           MOVE HV-BALANCE         TO WS-DISPLAY-BALANCE
           MOVE HV-INTEREST-RATE   TO WS-DISPLAY-RATE
           MOVE HV-INTEREST-AMOUNT TO WS-DISPLAY-INTEREST
           DISPLAY HV-ACCOUNT-ID "   $"
                   WS-DISPLAY-BALANCE "  "
                   WS-DISPLAY-RATE "  $"
                   WS-DISPLAY-INTEREST.

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
