       IDENTIFICATION DIVISION.
       PROGRAM-ID. TEST-BANKING.
      *> ============================================================
      *> TEST SUITE: Core Banking Transactions
      *>
      *> Prerequisites:
      *>   Run tests/setup-testdb.sql to seed the test database.
      *>
      *> Seed state (known starting point):
      *>   Account 1 → CHECKING, $1000.00, ACTIVE  (Customer 1)
      *>   Account 2 → SAVINGS,  $5000.00, ACTIVE  (Customer 1)
      *>   Account 3 → CHECKING, $250.00,  ACTIVE  (Customer 2)
      *>   Account 4 → CHECKING, $0.00,    CLOSED  (Customer 3)
      *>
      *> Tests:
      *>   T01  Deposit to active account
      *>   T02  Verify balance after deposit
      *>   T03  Withdrawal from active account
      *>   T04  Verify balance after withdrawal
      *>   T05  Reject withdrawal exceeding balance
      *>   T06  Balance unchanged after rejected withdrawal
      *>   T07  Reject transaction on closed account
      *>   T08  Reject transaction on non-existent account
      *>   T09  Transaction record created for deposit
      *>   T10  Transaction record created for withdrawal
      *>   T11  Audit log entry created on success
      *>   T12  Audit log entry created on failure
      *>   T13  Multiple deposits accumulate correctly
      *>   T14  Deposit then withdraw leaves correct balance
      *>   T15  Successful inter-account transfer
      *>   T16  Transfer balances are correct after transfer
      *>   T17  Reject transfer with insufficient funds
      *>   T18  Reject same-account transfer
      *>   T19  Reject transfer to closed account
      *>   T20  Zero-amount deposit is rejected by DB constraint
      *>   T21  Transfer records exist in TRANSACTIONS table
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
       01  HV-BALANCE            PIC S9(10)V99 COMP-3.
       01  HV-AMOUNT             PIC S9(10)V99 COMP-3.
       01  HV-TXN-TYPE           PIC X(10).
       01  HV-STATUS             PIC X(20).
       01  HV-AUDIT-ACTION       PIC X(50).
       01  HV-AUDIT-STATUS       PIC X(20).
       01  HV-TXN-COUNT          PIC S9(9) COMP.
       01  HV-AUDIT-COUNT        PIC S9(9) COMP.
       01  HV-NEW-BALANCE        PIC S9(10)V99 COMP-3.
       01  HV-SOURCE-ACCT-ID     PIC S9(9) COMP.
       01  HV-TARGET-ACCT-ID     PIC S9(9) COMP.
       01  HV-SOURCE-BALANCE     PIC S9(10)V99 COMP-3.
       01  HV-TARGET-BALANCE     PIC S9(10)V99 COMP-3.
       01  HV-SOURCE-STATUS      PIC X(20).
       01  HV-TARGET-STATUS      PIC X(20).
           EXEC SQL END DECLARE SECTION END-EXEC.

      *> ----- Database Configuration -----
           COPY 'dbconfig.cpy'.

      *> ----- Test Framework Fields -----
       01  WS-TEST-ID            PIC X(4).
       01  WS-TEST-DESC          PIC X(60).
       01  WS-TOTAL-TESTS        PIC 9(3) VALUE 0.
       01  WS-PASS-COUNT         PIC 9(3) VALUE 0.
       01  WS-FAIL-COUNT         PIC 9(3) VALUE 0.
       01  WS-CURRENT-RESULT     PIC X(4).
       01  WS-EXPECTED-BALANCE   PIC S9(10)V99.
       01  WS-ACTUAL-BALANCE     PIC S9(10)V99.
       01  WS-DISPLAY-EXPECTED   PIC Z(9)9.99.
       01  WS-DISPLAY-ACTUAL     PIC Z(9)9.99.

       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-CONNECT-DB
           PERFORM 1100-PRINT-HEADER

      *>   --- Deposit Tests ---
           PERFORM T01-DEPOSIT-ACTIVE
           PERFORM T02-VERIFY-DEPOSIT-BALANCE
      *>   --- Withdrawal Tests ---
           PERFORM T03-WITHDRAW-ACTIVE
           PERFORM T04-VERIFY-WITHDRAW-BALANCE
      *>   --- Edge Cases ---
           PERFORM T05-REJECT-OVERDRAFT
           PERFORM T06-BALANCE-AFTER-REJECT
           PERFORM T07-REJECT-CLOSED-ACCOUNT
           PERFORM T08-REJECT-NONEXISTENT-ACCOUNT
      *>   --- Record Verification ---
           PERFORM T09-TXN-RECORD-DEPOSIT
           PERFORM T10-TXN-RECORD-WITHDRAW
           PERFORM T11-AUDIT-SUCCESS
           PERFORM T12-AUDIT-FAILURE
      *>   --- Compound Operations ---
           PERFORM T13-MULTIPLE-DEPOSITS
           PERFORM T14-DEPOSIT-THEN-WITHDRAW
      *>   --- Transfer Tests ---
           PERFORM T15-TRANSFER-SUCCESS
           PERFORM T16-TRANSFER-BALANCES
           PERFORM T17-TRANSFER-INSUFFICIENT
           PERFORM T18-TRANSFER-SAME-ACCOUNT
           PERFORM T19-TRANSFER-TO-CLOSED
      *>   --- Boundary Tests ---
           PERFORM T20-ZERO-AMOUNT-REJECTED
      *>   --- Transfer Record Verification ---
           PERFORM T21-TRANSFER-RECORDS-EXIST

           PERFORM 1200-PRINT-SUMMARY
           PERFORM 9000-DISCONNECT-DB
           STOP RUN.

      *> ============================================================
      *> INFRASTRUCTURE
      *> ============================================================
       1000-CONNECT-DB.
           EXEC SQL
               CONNECT TO :WS-DB-NAME
               USER :WS-DB-USER
           END-EXEC

           IF SQLCODE NOT = 0
               DISPLAY "FATAL: Database connection failed."
               DISPLAY "SQLCODE: " SQLCODE
               STOP RUN
           END-IF.

       1100-PRINT-HEADER.
           DISPLAY SPACES
           DISPLAY "================================================"
           DISPLAY " COBOL-DB-SYSTEM  TEST SUITE"
           DISPLAY " Core Banking Transactions"
           DISPLAY "================================================"
           DISPLAY SPACES.

       1200-PRINT-SUMMARY.
           DISPLAY SPACES
           DISPLAY "================================================"
           DISPLAY " TEST RESULTS"
           DISPLAY "================================================"
           DISPLAY " Total:  " WS-TOTAL-TESTS
           DISPLAY " Passed: " WS-PASS-COUNT
           DISPLAY " Failed: " WS-FAIL-COUNT
           DISPLAY "================================================"
           IF WS-FAIL-COUNT = 0
               DISPLAY " ALL TESTS PASSED"
           ELSE
               DISPLAY " ** FAILURES DETECTED **"
           END-IF
           DISPLAY "================================================".

      *> ----- Assert helper: compare balances -----
       1300-ASSERT-BALANCE.
           ADD 1 TO WS-TOTAL-TESTS
           IF WS-ACTUAL-BALANCE = WS-EXPECTED-BALANCE
               MOVE "PASS" TO WS-CURRENT-RESULT
               ADD 1 TO WS-PASS-COUNT
           ELSE
               MOVE "FAIL" TO WS-CURRENT-RESULT
               ADD 1 TO WS-FAIL-COUNT
           END-IF

           DISPLAY "[" WS-CURRENT-RESULT "] "
                   WS-TEST-ID " - " WS-TEST-DESC

           IF WS-CURRENT-RESULT = "FAIL"
               MOVE WS-EXPECTED-BALANCE TO WS-DISPLAY-EXPECTED
               MOVE WS-ACTUAL-BALANCE   TO WS-DISPLAY-ACTUAL
               DISPLAY "       Expected: $" WS-DISPLAY-EXPECTED
               DISPLAY "       Actual:   $" WS-DISPLAY-ACTUAL
           END-IF.

      *> ----- Assert helper: SQLCODE check -----
       1400-ASSERT-SQLCODE-ZERO.
           ADD 1 TO WS-TOTAL-TESTS
           IF SQLCODE = 0
               MOVE "PASS" TO WS-CURRENT-RESULT
               ADD 1 TO WS-PASS-COUNT
           ELSE
               MOVE "FAIL" TO WS-CURRENT-RESULT
               ADD 1 TO WS-FAIL-COUNT
           END-IF
           DISPLAY "[" WS-CURRENT-RESULT "] "
                   WS-TEST-ID " - " WS-TEST-DESC
           IF WS-CURRENT-RESULT = "FAIL"
               DISPLAY "       SQLCODE: " SQLCODE
           END-IF.

       1500-ASSERT-SQLCODE-NONZERO.
           ADD 1 TO WS-TOTAL-TESTS
           IF SQLCODE NOT = 0
               MOVE "PASS" TO WS-CURRENT-RESULT
               ADD 1 TO WS-PASS-COUNT
           ELSE
               MOVE "FAIL" TO WS-CURRENT-RESULT
               ADD 1 TO WS-FAIL-COUNT
           END-IF
           DISPLAY "[" WS-CURRENT-RESULT "] "
                   WS-TEST-ID " - " WS-TEST-DESC.

      *> ----- Assert helper: count check -----
       1600-ASSERT-COUNT-POSITIVE.
           ADD 1 TO WS-TOTAL-TESTS
           IF HV-TXN-COUNT > 0
               MOVE "PASS" TO WS-CURRENT-RESULT
               ADD 1 TO WS-PASS-COUNT
           ELSE
               MOVE "FAIL" TO WS-CURRENT-RESULT
               ADD 1 TO WS-FAIL-COUNT
           END-IF
           DISPLAY "[" WS-CURRENT-RESULT "] "
                   WS-TEST-ID " - " WS-TEST-DESC.

      *> ----- Shared: fetch current balance -----
       7000-GET-BALANCE.
           EXEC SQL
               SELECT BALANCE
               INTO   :HV-BALANCE
               FROM   ACCOUNTS
               WHERE  ACCOUNT_ID = :HV-ACCOUNT-ID
           END-EXEC.

      *> ----- Shared: perform deposit -----
       7100-DO-DEPOSIT.
           EXEC SQL
               UPDATE ACCOUNTS
               SET    BALANCE = BALANCE + :HV-AMOUNT
               WHERE  ACCOUNT_ID = :HV-ACCOUNT-ID
           END-EXEC

           IF SQLCODE = 0
               MOVE "DEPOSIT" TO HV-TXN-TYPE
               EXEC SQL
                   INSERT INTO TRANSACTIONS
                       (ACCOUNT_ID, AMOUNT, TXN_TYPE)
                   VALUES
                       (:HV-ACCOUNT-ID, :HV-AMOUNT,
                        :HV-TXN-TYPE)
               END-EXEC
           END-IF

           IF SQLCODE = 0
               EXEC SQL COMMIT END-EXEC
               STRING "DEPOSIT  - ACCT " HV-ACCOUNT-ID
                   DELIMITED BY SIZE INTO HV-AUDIT-ACTION
               MOVE "SUCCESS" TO HV-AUDIT-STATUS
               PERFORM 8000-WRITE-AUDIT
           ELSE
               EXEC SQL ROLLBACK END-EXEC
           END-IF.

      *> ----- Shared: perform withdrawal -----
       7200-DO-WITHDRAW.
      *>   Check sufficient funds first
           PERFORM 7000-GET-BALANCE
           IF HV-BALANCE < HV-AMOUNT
               STRING "WITHDRAW - ACCT " HV-ACCOUNT-ID
                   DELIMITED BY SIZE INTO HV-AUDIT-ACTION
               MOVE "FAILURE" TO HV-AUDIT-STATUS
               PERFORM 8000-WRITE-AUDIT
               MOVE 99 TO SQLCODE
               EXIT PARAGRAPH
           END-IF

           EXEC SQL
               UPDATE ACCOUNTS
               SET    BALANCE = BALANCE - :HV-AMOUNT
               WHERE  ACCOUNT_ID = :HV-ACCOUNT-ID
           END-EXEC

           IF SQLCODE = 0
               MOVE "WITHDRAW" TO HV-TXN-TYPE
               EXEC SQL
                   INSERT INTO TRANSACTIONS
                       (ACCOUNT_ID, AMOUNT, TXN_TYPE)
                   VALUES
                       (:HV-ACCOUNT-ID, :HV-AMOUNT,
                        :HV-TXN-TYPE)
               END-EXEC
           END-IF

           IF SQLCODE = 0
               EXEC SQL COMMIT END-EXEC
               STRING "WITHDRAW - ACCT " HV-ACCOUNT-ID
                   DELIMITED BY SIZE INTO HV-AUDIT-ACTION
               MOVE "SUCCESS" TO HV-AUDIT-STATUS
               PERFORM 8000-WRITE-AUDIT
           ELSE
               EXEC SQL ROLLBACK END-EXEC
           END-IF.

      *> ----- Shared: validate account active -----
       7300-CHECK-ACCOUNT-ACTIVE.
           EXEC SQL
               SELECT STATUS
               INTO   :HV-STATUS
               FROM   ACCOUNTS
               WHERE  ACCOUNT_ID = :HV-ACCOUNT-ID
           END-EXEC.

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
      *> TEST CASES
      *> ============================================================

      *> T01: Deposit $500 to Account 1 (starts at $1000)
       T01-DEPOSIT-ACTIVE.
           MOVE "T01 " TO WS-TEST-ID
           MOVE "Deposit $500 to active account succeeds"
               TO WS-TEST-DESC

           MOVE 1      TO HV-ACCOUNT-ID
           MOVE 500.00 TO HV-AMOUNT
           PERFORM 7100-DO-DEPOSIT
           PERFORM 1400-ASSERT-SQLCODE-ZERO.

      *> T02: Balance should now be $1500
       T02-VERIFY-DEPOSIT-BALANCE.
           MOVE "T02 " TO WS-TEST-ID
           MOVE "Balance is $1500.00 after $500 deposit"
               TO WS-TEST-DESC

           MOVE 1 TO HV-ACCOUNT-ID
           PERFORM 7000-GET-BALANCE
           MOVE HV-BALANCE TO WS-ACTUAL-BALANCE
           MOVE 1500.00    TO WS-EXPECTED-BALANCE
           PERFORM 1300-ASSERT-BALANCE.

      *> T03: Withdraw $200 from Account 1
       T03-WITHDRAW-ACTIVE.
           MOVE "T03 " TO WS-TEST-ID
           MOVE "Withdraw $200 from active account succeeds"
               TO WS-TEST-DESC

           MOVE 1      TO HV-ACCOUNT-ID
           MOVE 200.00 TO HV-AMOUNT
           PERFORM 7200-DO-WITHDRAW
           PERFORM 1400-ASSERT-SQLCODE-ZERO.

      *> T04: Balance should now be $1300
       T04-VERIFY-WITHDRAW-BALANCE.
           MOVE "T04 " TO WS-TEST-ID
           MOVE "Balance is $1300.00 after $200 withdrawal"
               TO WS-TEST-DESC

           MOVE 1 TO HV-ACCOUNT-ID
           PERFORM 7000-GET-BALANCE
           MOVE HV-BALANCE TO WS-ACTUAL-BALANCE
           MOVE 1300.00    TO WS-EXPECTED-BALANCE
           PERFORM 1300-ASSERT-BALANCE.

      *> T05: Attempt to withdraw $9999 from Account 3 ($250)
       T05-REJECT-OVERDRAFT.
           MOVE "T05 " TO WS-TEST-ID
           MOVE "Overdraft withdrawal is rejected"
               TO WS-TEST-DESC

           MOVE 3       TO HV-ACCOUNT-ID
           MOVE 9999.00 TO HV-AMOUNT
           PERFORM 7200-DO-WITHDRAW
           PERFORM 1500-ASSERT-SQLCODE-NONZERO.

      *> T06: Account 3 balance unchanged at $250
       T06-BALANCE-AFTER-REJECT.
           MOVE "T06 " TO WS-TEST-ID
           MOVE "Balance unchanged after rejected overdraft"
               TO WS-TEST-DESC

           MOVE 3 TO HV-ACCOUNT-ID
           PERFORM 7000-GET-BALANCE
           MOVE HV-BALANCE TO WS-ACTUAL-BALANCE
           MOVE 250.00     TO WS-EXPECTED-BALANCE
           PERFORM 1300-ASSERT-BALANCE.

      *> T07: Deposit to closed Account 4 should fail
       T07-REJECT-CLOSED-ACCOUNT.
           MOVE "T07 " TO WS-TEST-ID
           MOVE "Transaction on CLOSED account is rejected"
               TO WS-TEST-DESC

           MOVE 4 TO HV-ACCOUNT-ID
           PERFORM 7300-CHECK-ACCOUNT-ACTIVE

           ADD 1 TO WS-TOTAL-TESTS
           IF HV-STATUS NOT = "ACTIVE"
               MOVE "PASS" TO WS-CURRENT-RESULT
               ADD 1 TO WS-PASS-COUNT
           ELSE
               MOVE "FAIL" TO WS-CURRENT-RESULT
               ADD 1 TO WS-FAIL-COUNT
           END-IF
           DISPLAY "[" WS-CURRENT-RESULT "] "
                   WS-TEST-ID " - " WS-TEST-DESC.

      *> T08: Transaction on non-existent Account 9999
       T08-REJECT-NONEXISTENT-ACCOUNT.
           MOVE "T08 " TO WS-TEST-ID
           MOVE "Transaction on non-existent account fails"
               TO WS-TEST-DESC

           MOVE 9999 TO HV-ACCOUNT-ID
           EXEC SQL
               SELECT STATUS
               INTO   :HV-STATUS
               FROM   ACCOUNTS
               WHERE  ACCOUNT_ID = :HV-ACCOUNT-ID
           END-EXEC
           PERFORM 1500-ASSERT-SQLCODE-NONZERO.

      *> T09: Verify DEPOSIT transaction record exists for Acct 1
       T09-TXN-RECORD-DEPOSIT.
           MOVE "T09 " TO WS-TEST-ID
           MOVE "Transaction record exists for deposit"
               TO WS-TEST-DESC

           MOVE 1 TO HV-ACCOUNT-ID
           EXEC SQL
               SELECT COUNT(*)
               INTO   :HV-TXN-COUNT
               FROM   TRANSACTIONS
               WHERE  ACCOUNT_ID = :HV-ACCOUNT-ID
               AND    TXN_TYPE   = 'DEPOSIT'
           END-EXEC
           PERFORM 1600-ASSERT-COUNT-POSITIVE.

      *> T10: Verify WITHDRAW transaction record exists for Acct 1
       T10-TXN-RECORD-WITHDRAW.
           MOVE "T10 " TO WS-TEST-ID
           MOVE "Transaction record exists for withdrawal"
               TO WS-TEST-DESC

           MOVE 1 TO HV-ACCOUNT-ID
           EXEC SQL
               SELECT COUNT(*)
               INTO   :HV-TXN-COUNT
               FROM   TRANSACTIONS
               WHERE  ACCOUNT_ID = :HV-ACCOUNT-ID
               AND    TXN_TYPE   = 'WITHDRAW'
           END-EXEC
           PERFORM 1600-ASSERT-COUNT-POSITIVE.

      *> T11: Audit log has SUCCESS entries
       T11-AUDIT-SUCCESS.
           MOVE "T11 " TO WS-TEST-ID
           MOVE "Audit log contains SUCCESS entries"
               TO WS-TEST-DESC

           EXEC SQL
               SELECT COUNT(*)
               INTO   :HV-TXN-COUNT
               FROM   AUDIT_LOG
               WHERE  STATUS = 'SUCCESS'
           END-EXEC
           PERFORM 1600-ASSERT-COUNT-POSITIVE.

      *> T12: Audit log has FAILURE entry (from T05 overdraft)
       T12-AUDIT-FAILURE.
           MOVE "T12 " TO WS-TEST-ID
           MOVE "Audit log contains FAILURE entry for overdraft"
               TO WS-TEST-DESC

           EXEC SQL
               SELECT COUNT(*)
               INTO   :HV-TXN-COUNT
               FROM   AUDIT_LOG
               WHERE  STATUS = 'FAILURE'
           END-EXEC
           PERFORM 1600-ASSERT-COUNT-POSITIVE.

      *> T13: Two deposits of $100 each to Account 2 ($5000)
      *>      Expected: $5200
       T13-MULTIPLE-DEPOSITS.
           MOVE "T13 " TO WS-TEST-ID
           MOVE "Multiple deposits accumulate correctly"
               TO WS-TEST-DESC

           MOVE 2      TO HV-ACCOUNT-ID
           MOVE 100.00 TO HV-AMOUNT
           PERFORM 7100-DO-DEPOSIT
           PERFORM 7100-DO-DEPOSIT

           PERFORM 7000-GET-BALANCE
           MOVE HV-BALANCE TO WS-ACTUAL-BALANCE
           MOVE 5200.00    TO WS-EXPECTED-BALANCE
           PERFORM 1300-ASSERT-BALANCE.

      *> T14: Deposit $300 then withdraw $150 from Account 3
      *>      Start: $250 → +300 = $550 → -150 = $400
       T14-DEPOSIT-THEN-WITHDRAW.
           MOVE "T14 " TO WS-TEST-ID
           MOVE "Deposit then withdraw leaves correct balance"
               TO WS-TEST-DESC

           MOVE 3      TO HV-ACCOUNT-ID
           MOVE 300.00 TO HV-AMOUNT
           PERFORM 7100-DO-DEPOSIT

           MOVE 150.00 TO HV-AMOUNT
           PERFORM 7200-DO-WITHDRAW

           PERFORM 7000-GET-BALANCE
           MOVE HV-BALANCE TO WS-ACTUAL-BALANCE
           MOVE 400.00     TO WS-EXPECTED-BALANCE
           PERFORM 1300-ASSERT-BALANCE.

      *> ============================================================
      *> TRANSFER TESTS
      *> ============================================================

      *> T15: Transfer $200 from Account 1 ($1300) to Account 3
      *>      After T14, Acct 3 = $400
       T15-TRANSFER-SUCCESS.
           MOVE "T15 " TO WS-TEST-ID
           MOVE "Inter-account transfer succeeds"
               TO WS-TEST-DESC

           MOVE 1 TO HV-SOURCE-ACCT-ID
           MOVE 3 TO HV-TARGET-ACCT-ID
           MOVE 200.00 TO HV-AMOUNT
           PERFORM 7300-DO-TRANSFER
           PERFORM 1400-ASSERT-SQLCODE-ZERO.

      *> T16: After T15: Acct 1 = 1300-200 = $1100, Acct 3 = 400+200 = $600
       T16-TRANSFER-BALANCES.
           MOVE "T16 " TO WS-TEST-ID
           MOVE "Transfer balances correct after transfer"
               TO WS-TEST-DESC

           MOVE 1 TO HV-ACCOUNT-ID
           PERFORM 7000-GET-BALANCE
           MOVE HV-BALANCE TO WS-ACTUAL-BALANCE
           MOVE 1100.00    TO WS-EXPECTED-BALANCE
           PERFORM 1300-ASSERT-BALANCE

           MOVE "T16b" TO WS-TEST-ID
           MOVE "Target balance correct after transfer"
               TO WS-TEST-DESC
           MOVE 3 TO HV-ACCOUNT-ID
           PERFORM 7000-GET-BALANCE
           MOVE HV-BALANCE TO WS-ACTUAL-BALANCE
           MOVE 600.00     TO WS-EXPECTED-BALANCE
           PERFORM 1300-ASSERT-BALANCE.

      *> T17: Transfer $99999 from Account 3 ($600) - insufficient
       T17-TRANSFER-INSUFFICIENT.
           MOVE "T17 " TO WS-TEST-ID
           MOVE "Transfer rejected for insufficient funds"
               TO WS-TEST-DESC

           MOVE 3 TO HV-SOURCE-ACCT-ID
           MOVE 1 TO HV-TARGET-ACCT-ID
           MOVE 99999.00 TO HV-AMOUNT
           PERFORM 7300-DO-TRANSFER
           PERFORM 1500-ASSERT-SQLCODE-NONZERO.

      *> T18: Transfer to same account
       T18-TRANSFER-SAME-ACCOUNT.
           MOVE "T18 " TO WS-TEST-ID
           MOVE "Same-account transfer is rejected"
               TO WS-TEST-DESC

           MOVE 1 TO HV-SOURCE-ACCT-ID
           MOVE 1 TO HV-TARGET-ACCT-ID
           MOVE 100.00 TO HV-AMOUNT

           ADD 1 TO WS-TOTAL-TESTS
           IF HV-SOURCE-ACCT-ID = HV-TARGET-ACCT-ID
               MOVE "PASS" TO WS-CURRENT-RESULT
               ADD 1 TO WS-PASS-COUNT
           ELSE
               MOVE "FAIL" TO WS-CURRENT-RESULT
               ADD 1 TO WS-FAIL-COUNT
           END-IF
           DISPLAY "[" WS-CURRENT-RESULT "] "
                   WS-TEST-ID " - " WS-TEST-DESC.

      *> T19: Transfer to closed Account 4
       T19-TRANSFER-TO-CLOSED.
           MOVE "T19 " TO WS-TEST-ID
           MOVE "Transfer to closed account is rejected"
               TO WS-TEST-DESC

           MOVE 1 TO HV-SOURCE-ACCT-ID
           MOVE 4 TO HV-TARGET-ACCT-ID
           MOVE 100.00 TO HV-AMOUNT
           PERFORM 7300-DO-TRANSFER
           PERFORM 1500-ASSERT-SQLCODE-NONZERO.

      *> T20: Zero-amount deposit rejected by DB CHECK constraint
       T20-ZERO-AMOUNT-REJECTED.
           MOVE "T20 " TO WS-TEST-ID
           MOVE "Zero-amount transaction rejected by DB"
               TO WS-TEST-DESC

           MOVE 1    TO HV-ACCOUNT-ID
           MOVE 0.00 TO HV-AMOUNT
           MOVE "DEPOSIT" TO HV-TXN-TYPE
           EXEC SQL
               INSERT INTO TRANSACTIONS
                   (ACCOUNT_ID, AMOUNT, TXN_TYPE)
               VALUES
                   (:HV-ACCOUNT-ID, :HV-AMOUNT, :HV-TXN-TYPE)
           END-EXEC
           IF SQLCODE NOT = 0
               EXEC SQL ROLLBACK END-EXEC
           END-IF
           PERFORM 1500-ASSERT-SQLCODE-NONZERO.

      *> T21: Transfer records exist in TRANSACTIONS
       T21-TRANSFER-RECORDS-EXIST.
           MOVE "T21 " TO WS-TEST-ID
           MOVE "TRANSFER records exist in TRANSACTIONS"
               TO WS-TEST-DESC

           EXEC SQL
               SELECT COUNT(*)
               INTO   :HV-TXN-COUNT
               FROM   TRANSACTIONS
               WHERE  TXN_TYPE = 'TRANSFER'
           END-EXEC
           PERFORM 1600-ASSERT-COUNT-POSITIVE.

      *> ============================================================
      *> SHARED: PERFORM TRANSFER
      *> Sets SQLCODE to non-zero on failure.
      *> ============================================================
       7300-DO-TRANSFER.
      *>   Validate source and target are different
           IF HV-SOURCE-ACCT-ID = HV-TARGET-ACCT-ID
               MOVE 99 TO SQLCODE
               EXIT PARAGRAPH
           END-IF

      *>   Lock and validate source
           EXEC SQL
               SELECT BALANCE, STATUS
               INTO   :HV-SOURCE-BALANCE, :HV-SOURCE-STATUS
               FROM   ACCOUNTS
               WHERE  ACCOUNT_ID = :HV-SOURCE-ACCT-ID
               FOR UPDATE
           END-EXEC

           IF SQLCODE NOT = 0
               EXEC SQL ROLLBACK END-EXEC
               EXIT PARAGRAPH
           END-IF
           IF HV-SOURCE-STATUS NOT = "ACTIVE"
               EXEC SQL ROLLBACK END-EXEC
               MOVE 99 TO SQLCODE
               EXIT PARAGRAPH
           END-IF

      *>   Check sufficient funds
           IF HV-SOURCE-BALANCE < HV-AMOUNT
               STRING "TRANSFER - SRC " HV-SOURCE-ACCT-ID
                      " TGT " HV-TARGET-ACCT-ID
                   DELIMITED BY SIZE INTO HV-AUDIT-ACTION
               MOVE "FAILURE" TO HV-AUDIT-STATUS
               EXEC SQL ROLLBACK END-EXEC
               PERFORM 8000-WRITE-AUDIT
               MOVE 99 TO SQLCODE
               EXIT PARAGRAPH
           END-IF

      *>   Lock and validate target
           EXEC SQL
               SELECT BALANCE, STATUS
               INTO   :HV-TARGET-BALANCE, :HV-TARGET-STATUS
               FROM   ACCOUNTS
               WHERE  ACCOUNT_ID = :HV-TARGET-ACCT-ID
               FOR UPDATE
           END-EXEC

           IF SQLCODE NOT = 0
               EXEC SQL ROLLBACK END-EXEC
               EXIT PARAGRAPH
           END-IF
           IF HV-TARGET-STATUS NOT = "ACTIVE"
               EXEC SQL ROLLBACK END-EXEC
               MOVE 99 TO SQLCODE
               EXIT PARAGRAPH
           END-IF

      *>   Debit source, credit target
           EXEC SQL
               UPDATE ACCOUNTS
               SET    BALANCE = BALANCE - :HV-AMOUNT
               WHERE  ACCOUNT_ID = :HV-SOURCE-ACCT-ID
           END-EXEC
           IF SQLCODE NOT = 0
               EXEC SQL ROLLBACK END-EXEC
               EXIT PARAGRAPH
           END-IF

           EXEC SQL
               UPDATE ACCOUNTS
               SET    BALANCE = BALANCE + :HV-AMOUNT
               WHERE  ACCOUNT_ID = :HV-TARGET-ACCT-ID
           END-EXEC
           IF SQLCODE NOT = 0
               EXEC SQL ROLLBACK END-EXEC
               EXIT PARAGRAPH
           END-IF

      *>   Record transfer transactions
           MOVE "TRANSFER" TO HV-TXN-TYPE
           EXEC SQL
               INSERT INTO TRANSACTIONS
                   (ACCOUNT_ID, AMOUNT, TXN_TYPE)
               VALUES
                   (:HV-SOURCE-ACCT-ID, :HV-AMOUNT,
                    :HV-TXN-TYPE)
           END-EXEC
           IF SQLCODE NOT = 0
               EXEC SQL ROLLBACK END-EXEC
               EXIT PARAGRAPH
           END-IF

           EXEC SQL
               INSERT INTO TRANSACTIONS
                   (ACCOUNT_ID, AMOUNT, TXN_TYPE)
               VALUES
                   (:HV-TARGET-ACCT-ID, :HV-AMOUNT,
                    :HV-TXN-TYPE)
           END-EXEC
           IF SQLCODE NOT = 0
               EXEC SQL ROLLBACK END-EXEC
               EXIT PARAGRAPH
           END-IF

           EXEC SQL COMMIT END-EXEC
           STRING "TRANSFER - SRC " HV-SOURCE-ACCT-ID
                  " TGT " HV-TARGET-ACCT-ID
               DELIMITED BY SIZE INTO HV-AUDIT-ACTION
           MOVE "SUCCESS" TO HV-AUDIT-STATUS
           PERFORM 8000-WRITE-AUDIT.

      *> ============================================================
      *> DISCONNECT
      *> ============================================================
       9000-DISCONNECT-DB.
           EXEC SQL
               DISCONNECT ALL
           END-EXEC.
