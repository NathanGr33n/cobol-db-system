      ******************************************************************
      * ACCTMGR.CBL - Account Manager
      * Banking System - Account Operations
      * Uses Embedded SQL (EXEC SQL) for PostgreSQL via ocesql
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. ACCTMGR.
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
      * Host Variables for ACCOUNTS table
      ******************************************************************
       01  WS-ACCOUNT-ID           PIC 9(8)       VALUE ZEROS.
       01  WS-CUSTOMER-ID          PIC 9(8)       VALUE ZEROS.
       01  WS-BALANCE              PIC S9(10)V99  VALUE ZEROS.
       01  WS-ACCOUNT-TYPE         PIC X(20)      VALUE SPACES.
       01  WS-ACCOUNT-STATUS       PIC X(20)      VALUE SPACES.

      ******************************************************************
      * Host Variables for customer validation
      ******************************************************************
       01  WS-CUST-FIRST-NAME      PIC X(50)      VALUE SPACES.
       01  WS-CUST-LAST-NAME       PIC X(50)      VALUE SPACES.
       01  WS-CUSTOMER-EXISTS      PIC 9          VALUE ZEROS.

      ******************************************************************
      * Program Control Variables
      ******************************************************************
       01  WS-MENU-CHOICE          PIC 9          VALUE ZERO.
       01  WS-TYPE-CHOICE          PIC 9          VALUE ZERO.
       01  WS-STATUS-CHOICE        PIC 9          VALUE ZERO.
       01  WS-CONTINUE-FLAG        PIC X          VALUE 'Y'.
           88 WS-CONTINUE                         VALUE 'Y' 'y'.
           88 WS-EXIT                             VALUE 'N' 'n'.
       01  WS-CONFIRM              PIC X          VALUE SPACES.
       01  WS-SAVED-SQLCODE        PIC S9(9)      VALUE ZEROS.

      ******************************************************************
      * Display Formatting
      ******************************************************************
       01  WS-SEPARATOR            PIC X(60)      VALUE ALL '-'.
       01  WS-DISPLAY-ID           PIC Z(7)9.
       01  WS-DISPLAY-BALANCE      PIC $$$,$$$,$$9.99.

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
               CONNECT TO 'cobol_bank'
           END-EXEC

           IF SQLCODE NOT = ZERO
               DISPLAY 'ERROR: Database connection failed.'
               DISPLAY 'SQLCODE: ' SQLCODE
               STOP RUN
           END-IF

           DISPLAY SPACES
           DISPLAY '=========================================='
           DISPLAY '  COBOL BANKING SYSTEM - ACCOUNT MANAGER'
           DISPLAY '=========================================='
           .

      ******************************************************************
      * Main menu loop
      ******************************************************************
       2000-PROCESS-MENU.
           DISPLAY SPACES
           DISPLAY WS-SEPARATOR
           DISPLAY '  ACCOUNT MANAGER MENU'
           DISPLAY WS-SEPARATOR
           DISPLAY '  1. Create New Account'
           DISPLAY '  2. Check Account Balance'
           DISPLAY '  3. Update Account Status'
           DISPLAY '  4. View Account Details'
           DISPLAY '  9. Exit'
           DISPLAY WS-SEPARATOR
           DISPLAY 'Enter choice: ' WITH NO ADVANCING
           ACCEPT WS-MENU-CHOICE

           EVALUATE WS-MENU-CHOICE
               WHEN 1
                   PERFORM 3000-CREATE-ACCOUNT
               WHEN 2
                   PERFORM 4000-CHECK-BALANCE
               WHEN 3
                   PERFORM 5000-UPDATE-STATUS
               WHEN 4
                   PERFORM 6000-VIEW-ACCOUNT
               WHEN 9
                   SET WS-EXIT TO TRUE
               WHEN OTHER
                   DISPLAY 'ERROR: Invalid choice. Try again.'
           END-EVALUATE
           .

      ******************************************************************
      * Create a new account - validates customer exists first
      ******************************************************************
       3000-CREATE-ACCOUNT.
           DISPLAY SPACES
           DISPLAY '--- CREATE NEW ACCOUNT ---'

           DISPLAY 'Enter Customer ID: ' WITH NO ADVANCING
           ACCEPT WS-CUSTOMER-ID

           IF WS-CUSTOMER-ID = ZEROS
               DISPLAY 'ERROR: Invalid Customer ID.'
               GO TO 3000-EXIT
           END-IF

      *    Validate customer exists
           EXEC SQL
               SELECT COUNT(*)
               INTO :WS-CUSTOMER-EXISTS
               FROM CUSTOMERS
               WHERE CUSTOMER_ID = :WS-CUSTOMER-ID
           END-EXEC

           IF WS-CUSTOMER-EXISTS = ZERO
               DISPLAY 'ERROR: Customer ID '
                   WS-CUSTOMER-ID ' does not exist.'
               GO TO 3000-EXIT
           END-IF

      *    Get customer name for confirmation
           EXEC SQL
               SELECT FIRST_NAME, LAST_NAME
               INTO :WS-CUST-FIRST-NAME, :WS-CUST-LAST-NAME
               FROM CUSTOMERS
               WHERE CUSTOMER_ID = :WS-CUSTOMER-ID
           END-EXEC

           DISPLAY '  Customer: '
               FUNCTION TRIM(WS-CUST-FIRST-NAME) ' '
               FUNCTION TRIM(WS-CUST-LAST-NAME)

      *    Select account type
           DISPLAY SPACES
           DISPLAY '  Account Type:'
           DISPLAY '    1. CHECKING'
           DISPLAY '    2. SAVINGS'
           DISPLAY '  Select type: ' WITH NO ADVANCING
           ACCEPT WS-TYPE-CHOICE

           EVALUATE WS-TYPE-CHOICE
               WHEN 1
                   MOVE 'CHECKING' TO WS-ACCOUNT-TYPE
               WHEN 2
                   MOVE 'SAVINGS' TO WS-ACCOUNT-TYPE
               WHEN OTHER
                   DISPLAY 'ERROR: Invalid account type.'
                   GO TO 3000-EXIT
           END-EVALUATE

      *    Initial balance
           DISPLAY 'Enter Initial Balance: ' WITH NO ADVANCING
           ACCEPT WS-BALANCE

           IF WS-BALANCE < ZEROS
               DISPLAY 'ERROR: Balance cannot be negative.'
               GO TO 3000-EXIT
           END-IF

      *    Insert the account
           EXEC SQL
               INSERT INTO ACCOUNTS
                   (CUSTOMER_ID, BALANCE, ACCOUNT_TYPE, STATUS)
               VALUES
                   (:WS-CUSTOMER-ID, :WS-BALANCE,
                    :WS-ACCOUNT-TYPE, 'ACTIVE')
           END-EXEC

           IF SQLCODE = ZERO
               EXEC SQL
                   SELECT MAX(ACCOUNT_ID)
                   INTO :WS-ACCOUNT-ID
                   FROM ACCOUNTS
               END-EXEC

               EXEC SQL COMMIT END-EXEC

               MOVE WS-ACCOUNT-ID TO WS-DISPLAY-ID
               MOVE WS-BALANCE TO WS-DISPLAY-BALANCE
               DISPLAY 'SUCCESS: Account created.'
               DISPLAY '  Account ID : ' WS-DISPLAY-ID
               DISPLAY '  Type       : '
                   FUNCTION TRIM(WS-ACCOUNT-TYPE)
               DISPLAY '  Balance    : ' WS-DISPLAY-BALANCE

               PERFORM 8000-LOG-AUDIT
           ELSE
               MOVE SQLCODE TO WS-SAVED-SQLCODE
               EXEC SQL ROLLBACK END-EXEC
               DISPLAY 'ERROR: Could not create account.'
               DISPLAY 'SQLCODE: ' WS-SAVED-SQLCODE
           END-IF
           .
       3000-EXIT.
           EXIT
           .

      ******************************************************************
      * Check account balance
      ******************************************************************
       4000-CHECK-BALANCE.
           DISPLAY SPACES
           DISPLAY '--- CHECK ACCOUNT BALANCE ---'
           DISPLAY 'Enter Account ID: ' WITH NO ADVANCING
           ACCEPT WS-ACCOUNT-ID

           IF WS-ACCOUNT-ID = ZEROS
               DISPLAY 'ERROR: Invalid Account ID.'
               GO TO 4000-EXIT
           END-IF

           EXEC SQL
               SELECT BALANCE, ACCOUNT_TYPE, STATUS
               INTO :WS-BALANCE, :WS-ACCOUNT-TYPE,
                    :WS-ACCOUNT-STATUS
               FROM ACCOUNTS
               WHERE ACCOUNT_ID = :WS-ACCOUNT-ID
           END-EXEC

           IF SQLCODE = ZERO
               MOVE WS-ACCOUNT-ID TO WS-DISPLAY-ID
               MOVE WS-BALANCE TO WS-DISPLAY-BALANCE
               DISPLAY SPACES
               DISPLAY '  Account ID : ' WS-DISPLAY-ID
               DISPLAY '  Type       : '
                   FUNCTION TRIM(WS-ACCOUNT-TYPE)
               DISPLAY '  Status     : '
                   FUNCTION TRIM(WS-ACCOUNT-STATUS)
               DISPLAY '  Balance    : ' WS-DISPLAY-BALANCE
           ELSE
               IF SQLCODE = 100
                   DISPLAY 'INFO: No account found with ID '
                       WS-ACCOUNT-ID
               ELSE
                   DISPLAY 'ERROR: Database error occurred.'
                   DISPLAY 'SQLCODE: ' SQLCODE
               END-IF
           END-IF
           .
       4000-EXIT.
           EXIT
           .

      ******************************************************************
      * Update account status (ACTIVE/CLOSED)
      ******************************************************************
       5000-UPDATE-STATUS.
           DISPLAY SPACES
           DISPLAY '--- UPDATE ACCOUNT STATUS ---'
           DISPLAY 'Enter Account ID: ' WITH NO ADVANCING
           ACCEPT WS-ACCOUNT-ID

           IF WS-ACCOUNT-ID = ZEROS
               DISPLAY 'ERROR: Invalid Account ID.'
               GO TO 5000-EXIT
           END-IF

      *    Verify account exists and get current status
           EXEC SQL
               SELECT STATUS, BALANCE
               INTO :WS-ACCOUNT-STATUS, :WS-BALANCE
               FROM ACCOUNTS
               WHERE ACCOUNT_ID = :WS-ACCOUNT-ID
           END-EXEC

           IF SQLCODE = 100
               DISPLAY 'INFO: No account found with ID '
                   WS-ACCOUNT-ID
               GO TO 5000-EXIT
           END-IF

           IF SQLCODE NOT = ZERO
               DISPLAY 'ERROR: Database error. SQLCODE: ' SQLCODE
               GO TO 5000-EXIT
           END-IF

           DISPLAY '  Current Status: '
               FUNCTION TRIM(WS-ACCOUNT-STATUS)

      *    Select new status
           DISPLAY SPACES
           DISPLAY '  New Status:'
           DISPLAY '    1. ACTIVE'
           DISPLAY '    2. CLOSED'
           DISPLAY '  Select status: ' WITH NO ADVANCING
           ACCEPT WS-STATUS-CHOICE

           EVALUATE WS-STATUS-CHOICE
               WHEN 1
                   MOVE 'ACTIVE' TO WS-ACCOUNT-STATUS
               WHEN 2
      *            Prevent closing account with balance
                   IF WS-BALANCE > ZEROS
                       MOVE WS-BALANCE TO WS-DISPLAY-BALANCE
                       DISPLAY 'ERROR: Cannot close account with'
                           ' balance ' WS-DISPLAY-BALANCE
                       DISPLAY '  Transfer or withdraw funds '
                           'first.'
                       GO TO 5000-EXIT
                   END-IF
                   MOVE 'CLOSED' TO WS-ACCOUNT-STATUS
               WHEN OTHER
                   DISPLAY 'ERROR: Invalid status choice.'
                   GO TO 5000-EXIT
           END-EVALUATE

      *    Confirm the change
           DISPLAY 'Confirm status change to '
               FUNCTION TRIM(WS-ACCOUNT-STATUS)
               '? (Y/N): ' WITH NO ADVANCING
           ACCEPT WS-CONFIRM

           IF WS-CONFIRM NOT = 'Y' AND WS-CONFIRM NOT = 'y'
               DISPLAY 'Status change cancelled.'
               GO TO 5000-EXIT
           END-IF

           EXEC SQL
               UPDATE ACCOUNTS
               SET STATUS = :WS-ACCOUNT-STATUS
               WHERE ACCOUNT_ID = :WS-ACCOUNT-ID
           END-EXEC

           IF SQLCODE = ZERO
               EXEC SQL COMMIT END-EXEC
               DISPLAY 'SUCCESS: Account status updated to '
                   FUNCTION TRIM(WS-ACCOUNT-STATUS)

               PERFORM 8000-LOG-AUDIT
           ELSE
               MOVE SQLCODE TO WS-SAVED-SQLCODE
               EXEC SQL ROLLBACK END-EXEC
               DISPLAY 'ERROR: Could not update status.'
               DISPLAY 'SQLCODE: ' WS-SAVED-SQLCODE
           END-IF
           .
       5000-EXIT.
           EXIT
           .

      ******************************************************************
      * View full account details including customer info
      ******************************************************************
       6000-VIEW-ACCOUNT.
           DISPLAY SPACES
           DISPLAY '--- ACCOUNT DETAILS ---'
           DISPLAY 'Enter Account ID: ' WITH NO ADVANCING
           ACCEPT WS-ACCOUNT-ID

           IF WS-ACCOUNT-ID = ZEROS
               DISPLAY 'ERROR: Invalid Account ID.'
               GO TO 6000-EXIT
           END-IF

           EXEC SQL
               SELECT A.ACCOUNT_ID, A.CUSTOMER_ID,
                      A.BALANCE, A.ACCOUNT_TYPE, A.STATUS,
                      C.FIRST_NAME, C.LAST_NAME
               INTO :WS-ACCOUNT-ID, :WS-CUSTOMER-ID,
                    :WS-BALANCE, :WS-ACCOUNT-TYPE,
                    :WS-ACCOUNT-STATUS,
                    :WS-CUST-FIRST-NAME, :WS-CUST-LAST-NAME
               FROM ACCOUNTS A
               JOIN CUSTOMERS C
                   ON A.CUSTOMER_ID = C.CUSTOMER_ID
               WHERE A.ACCOUNT_ID = :WS-ACCOUNT-ID
           END-EXEC

           IF SQLCODE = ZERO
               MOVE WS-ACCOUNT-ID TO WS-DISPLAY-ID
               MOVE WS-BALANCE TO WS-DISPLAY-BALANCE
               DISPLAY SPACES
               DISPLAY '  Account ID   : ' WS-DISPLAY-ID
               MOVE WS-CUSTOMER-ID TO WS-DISPLAY-ID
               DISPLAY '  Customer ID  : ' WS-DISPLAY-ID
               DISPLAY '  Customer Name: '
                   FUNCTION TRIM(WS-CUST-FIRST-NAME) ' '
                   FUNCTION TRIM(WS-CUST-LAST-NAME)
               DISPLAY '  Account Type : '
                   FUNCTION TRIM(WS-ACCOUNT-TYPE)
               DISPLAY '  Status       : '
                   FUNCTION TRIM(WS-ACCOUNT-STATUS)
               DISPLAY '  Balance      : ' WS-DISPLAY-BALANCE
           ELSE
               IF SQLCODE = 100
                   DISPLAY 'INFO: No account found with ID '
                       WS-ACCOUNT-ID
               ELSE
                   DISPLAY 'ERROR: Database error occurred.'
                   DISPLAY 'SQLCODE: ' SQLCODE
               END-IF
           END-IF
           .
       6000-EXIT.
           EXIT
           .

      ******************************************************************
      * Audit logging
      ******************************************************************
       8000-LOG-AUDIT.
           EXEC SQL
               INSERT INTO AUDIT_LOG (ACTION, STATUS, DETAILS)
               VALUES ('ACCOUNT_UPDATE', 'SUCCESS',
                       'Account operation on ID ' ||
                       CAST(:WS-ACCOUNT-ID AS VARCHAR(8)))
           END-EXEC

           IF SQLCODE NOT = ZERO
               DISPLAY 'WARNING: Audit log write failed.'
           END-IF

           EXEC SQL COMMIT END-EXEC
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
           DISPLAY 'Account Manager terminated.'
           .
