      ******************************************************************
      * CUSTMGR.CBL - Customer Manager
      * Banking System - Customer CRUD Operations
      * Uses Embedded SQL (EXEC SQL) for PostgreSQL via ocesql
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. CUSTMGR.
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
      * Host Variables for CUSTOMERS table
      ******************************************************************
       01  WS-CUSTOMER-ID          PIC 9(8)     VALUE ZEROS.
       01  WS-FIRST-NAME           PIC X(50)    VALUE SPACES.
       01  WS-LAST-NAME            PIC X(50)    VALUE SPACES.
       01  WS-EMAIL                PIC X(100)   VALUE SPACES.
       01  WS-CREATED-AT           PIC X(10)    VALUE SPACES.

      ******************************************************************
      * Program Control Variables
      ******************************************************************
       01  WS-MENU-CHOICE          PIC 9        VALUE ZERO.
       01  WS-CONTINUE-FLAG        PIC X        VALUE 'Y'.
           88 WS-CONTINUE                       VALUE 'Y' 'y'.
           88 WS-EXIT                           VALUE 'N' 'n'.
       01  WS-SAVED-SQLCODE        PIC S9(9)    VALUE ZEROS.
       01  WS-RECORD-COUNT         PIC 9(6)     VALUE ZEROS.
       01  WS-AT-COUNT             PIC 9        VALUE ZEROS.
       01  WS-INPUT-LEN            PIC 9(3)     VALUE ZEROS.
       01  WS-EOF-FLAG             PIC X        VALUE 'N'.
           88 WS-EOF                            VALUE 'Y'.
           88 WS-NOT-EOF                        VALUE 'N'.

      ******************************************************************
      * Database Configuration
      ******************************************************************
           COPY 'cpy/dbconfig.cpy'.

      ******************************************************************
      * Display Formatting
      ******************************************************************
       01  WS-SEPARATOR            PIC X(60)    VALUE ALL '-'.
       01  WS-DISPLAY-ID           PIC Z(7)9.

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
           DISPLAY '  COBOL BANKING SYSTEM - CUSTOMER MANAGER'
           DISPLAY '=========================================='
           .

      ******************************************************************
      * Main menu loop
      ******************************************************************
       2000-PROCESS-MENU.
           DISPLAY SPACES
           DISPLAY WS-SEPARATOR
           DISPLAY '  CUSTOMER MANAGER MENU'
           DISPLAY WS-SEPARATOR
           DISPLAY '  1. Create New Customer'
           DISPLAY '  2. Retrieve Customer by ID'
           DISPLAY '  3. List All Customers'
           DISPLAY '  9. Exit'
           DISPLAY WS-SEPARATOR
           DISPLAY 'Enter choice: ' WITH NO ADVANCING
           ACCEPT WS-MENU-CHOICE

           EVALUATE WS-MENU-CHOICE
               WHEN 1
                   PERFORM 3000-CREATE-CUSTOMER
               WHEN 2
                   PERFORM 4000-RETRIEVE-CUSTOMER
               WHEN 3
                   PERFORM 5000-LIST-CUSTOMERS
               WHEN 9
                   SET WS-EXIT TO TRUE
               WHEN OTHER
                   DISPLAY 'ERROR: Invalid choice. Try again.'
           END-EVALUATE
           .

      ******************************************************************
      * Create a new customer
      ******************************************************************
       3000-CREATE-CUSTOMER.
           DISPLAY SPACES
           DISPLAY '--- CREATE NEW CUSTOMER ---'

           DISPLAY 'Enter First Name (max 50): ' WITH NO ADVANCING
           ACCEPT WS-FIRST-NAME
           COMPUTE WS-INPUT-LEN =
               FUNCTION LENGTH(FUNCTION TRIM(WS-FIRST-NAME))
           IF WS-INPUT-LEN = ZERO
               DISPLAY 'ERROR: First name is required.'
               GO TO 3000-EXIT
           END-IF
           IF WS-INPUT-LEN > 50
               DISPLAY 'ERROR: First name exceeds 50 characters.'
               GO TO 3000-EXIT
           END-IF

           DISPLAY 'Enter Last Name (max 50): ' WITH NO ADVANCING
           ACCEPT WS-LAST-NAME
           COMPUTE WS-INPUT-LEN =
               FUNCTION LENGTH(FUNCTION TRIM(WS-LAST-NAME))
           IF WS-INPUT-LEN = ZERO
               DISPLAY 'ERROR: Last name is required.'
               GO TO 3000-EXIT
           END-IF
           IF WS-INPUT-LEN > 50
               DISPLAY 'ERROR: Last name exceeds 50 characters.'
               GO TO 3000-EXIT
           END-IF

           DISPLAY 'Enter Email (max 100): ' WITH NO ADVANCING
           ACCEPT WS-EMAIL
           COMPUTE WS-INPUT-LEN =
               FUNCTION LENGTH(FUNCTION TRIM(WS-EMAIL))
           IF WS-INPUT-LEN = ZERO
               DISPLAY 'ERROR: Email is required.'
               GO TO 3000-EXIT
           END-IF
           IF WS-INPUT-LEN > 100
               DISPLAY 'ERROR: Email exceeds 100 characters.'
               GO TO 3000-EXIT
           END-IF

      *    Validate email format: must contain exactly one @
           MOVE ZERO TO WS-AT-COUNT
           INSPECT WS-EMAIL TALLYING WS-AT-COUNT
               FOR ALL '@'
           IF WS-AT-COUNT NOT = 1
               DISPLAY 'ERROR: Invalid email format.'
               GO TO 3000-EXIT
           END-IF

           EXEC SQL
               INSERT INTO CUSTOMERS
                   (FIRST_NAME, LAST_NAME, EMAIL)
               VALUES
                   (:WS-FIRST-NAME, :WS-LAST-NAME, :WS-EMAIL)
           END-EXEC

           IF SQLCODE = ZERO
               EXEC SQL
                   SELECT CURRVAL('customers_customer_id_seq')
                   INTO :WS-CUSTOMER-ID
               END-EXEC

               EXEC SQL COMMIT END-EXEC

               MOVE WS-CUSTOMER-ID TO WS-DISPLAY-ID
               DISPLAY 'SUCCESS: Customer created.'
               DISPLAY '  Customer ID: ' WS-DISPLAY-ID

               PERFORM 8000-LOG-AUDIT-SUCCESS
           ELSE
               MOVE SQLCODE TO WS-SAVED-SQLCODE
               EXEC SQL ROLLBACK END-EXEC

               IF WS-SAVED-SQLCODE = -803
                   DISPLAY 'ERROR: Email already exists.'
               ELSE
                   DISPLAY 'ERROR: Could not create customer.'
                   DISPLAY 'SQLCODE: ' WS-SAVED-SQLCODE
               END-IF

               PERFORM 8100-LOG-AUDIT-FAILURE
           END-IF
           .
       3000-EXIT.
           EXIT
           .

      ******************************************************************
      * Retrieve customer by ID
      ******************************************************************
       4000-RETRIEVE-CUSTOMER.
           DISPLAY SPACES
           DISPLAY '--- RETRIEVE CUSTOMER ---'
           DISPLAY 'Enter Customer ID: ' WITH NO ADVANCING
           ACCEPT WS-CUSTOMER-ID

           IF WS-CUSTOMER-ID = ZEROS
               DISPLAY 'ERROR: Invalid Customer ID.'
               GO TO 4000-EXIT
           END-IF

           EXEC SQL
               SELECT CUSTOMER_ID, FIRST_NAME, LAST_NAME,
                      EMAIL, CREATED_AT
               INTO :WS-CUSTOMER-ID, :WS-FIRST-NAME,
                    :WS-LAST-NAME, :WS-EMAIL, :WS-CREATED-AT
               FROM CUSTOMERS
               WHERE CUSTOMER_ID = :WS-CUSTOMER-ID
           END-EXEC

           IF SQLCODE = ZERO
               MOVE WS-CUSTOMER-ID TO WS-DISPLAY-ID
               DISPLAY SPACES
               DISPLAY '  Customer ID : ' WS-DISPLAY-ID
               DISPLAY '  First Name  : '
                   FUNCTION TRIM(WS-FIRST-NAME)
               DISPLAY '  Last Name   : '
                   FUNCTION TRIM(WS-LAST-NAME)
               DISPLAY '  Email       : '
                   FUNCTION TRIM(WS-EMAIL)
               DISPLAY '  Created At  : '
                   FUNCTION TRIM(WS-CREATED-AT)
           ELSE
               IF SQLCODE = 100
                   DISPLAY 'INFO: No customer found with ID '
                       WS-CUSTOMER-ID
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
      * List all customers using a cursor
      ******************************************************************
       5000-LIST-CUSTOMERS.
           MOVE ZERO TO WS-RECORD-COUNT
           SET WS-NOT-EOF TO TRUE

           EXEC SQL
               DECLARE CSR-CUSTOMERS CURSOR FOR
               SELECT CUSTOMER_ID, FIRST_NAME, LAST_NAME,
                      EMAIL, CREATED_AT
               FROM CUSTOMERS
               ORDER BY CUSTOMER_ID
           END-EXEC

           EXEC SQL
               OPEN CSR-CUSTOMERS
           END-EXEC

           IF SQLCODE NOT = ZERO
               DISPLAY 'ERROR: Could not open customer cursor.'
               DISPLAY 'SQLCODE: ' SQLCODE
               GO TO 5000-EXIT
           END-IF

           DISPLAY SPACES
           DISPLAY '--- ALL CUSTOMERS ---'
           DISPLAY WS-SEPARATOR

           PERFORM 5100-FETCH-CUSTOMER
               UNTIL WS-EOF

           EXEC SQL
               CLOSE CSR-CUSTOMERS
           END-EXEC

           DISPLAY WS-SEPARATOR
           DISPLAY 'Total Customers: ' WS-RECORD-COUNT
           .
       5000-EXIT.
           EXIT
           .

       5100-FETCH-CUSTOMER.
           EXEC SQL
               FETCH CSR-CUSTOMERS
               INTO :WS-CUSTOMER-ID, :WS-FIRST-NAME,
                    :WS-LAST-NAME, :WS-EMAIL, :WS-CREATED-AT
           END-EXEC

           IF SQLCODE = ZERO
               ADD 1 TO WS-RECORD-COUNT
               MOVE WS-CUSTOMER-ID TO WS-DISPLAY-ID
               DISPLAY '  ID: ' WS-DISPLAY-ID
                   '  Name: '
                   FUNCTION TRIM(WS-FIRST-NAME) ' '
                   FUNCTION TRIM(WS-LAST-NAME)
                   '  Email: '
                   FUNCTION TRIM(WS-EMAIL)
           ELSE
               SET WS-EOF TO TRUE
               IF SQLCODE NOT = 100
                   DISPLAY 'ERROR: Fetch error. SQLCODE: '
                       SQLCODE
               END-IF
           END-IF
           .

      ******************************************************************
      * Audit logging helpers
      ******************************************************************
       8000-LOG-AUDIT-SUCCESS.
           EXEC SQL
               INSERT INTO AUDIT_LOG (ACTION, STATUS, DETAILS)
               VALUES ('CUSTOMER_CREATE', 'SUCCESS',
                       'Created customer ' ||
                       TRIM(:WS-FIRST-NAME) || ' ' ||
                       TRIM(:WS-LAST-NAME))
           END-EXEC

           IF SQLCODE NOT = ZERO
               DISPLAY 'WARNING: Audit log write failed.'
           END-IF

           EXEC SQL COMMIT END-EXEC
           .

       8100-LOG-AUDIT-FAILURE.
           EXEC SQL
               INSERT INTO AUDIT_LOG (ACTION, STATUS, DETAILS)
               VALUES ('CUSTOMER_CREATE', 'FAILURE',
                       'Failed to create customer')
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
           DISPLAY 'Customer Manager terminated.'
           .
