       IDENTIFICATION DIVISION.
       PROGRAM-ID. CUSTMGR.
      *> ============================================================
      *> CUSTOMER MANAGER
      *> Creates, retrieves, and lists customer records using
      *> embedded SQL against the CUSTOMERS table.
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
       01  HV-CUSTOMER-ID        PIC S9(9) COMP.
       01  HV-FIRST-NAME         PIC X(50).
       01  HV-LAST-NAME          PIC X(50).
       01  HV-EMAIL              PIC X(100).
       01  HV-CREATED-AT         PIC X(10).
           EXEC SQL END DECLARE SECTION END-EXEC.

      *> ----- Working Fields -----
       01  WS-MENU-CHOICE        PIC 9(1) VALUE 0.
       01  WS-CONTINUE-FLAG      PIC X(1) VALUE 'Y'.
           88 WS-CONTINUE        VALUE 'Y' 'y'.
       01  WS-DISPLAY-LINE       PIC X(80) VALUE SPACES.

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
               CONNECT TO 'coboldb'
               USER 'coboluser'
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
           DISPLAY "       CUSTOMER MANAGER"
           DISPLAY "========================================"
           DISPLAY "  1. Create New Customer"
           DISPLAY "  2. Retrieve Customer by ID"
           DISPLAY "  3. List All Customers"
           DISPLAY "  0. Exit"
           DISPLAY "========================================"
           DISPLAY "Enter choice: " WITH NO ADVANCING
           ACCEPT WS-MENU-CHOICE

           EVALUATE WS-MENU-CHOICE
               WHEN 1
                   PERFORM 3000-CREATE-CUSTOMER
               WHEN 2
                   PERFORM 4000-RETRIEVE-CUSTOMER
               WHEN 3
                   PERFORM 5000-LIST-CUSTOMERS
               WHEN 0
                   MOVE 'N' TO WS-CONTINUE-FLAG
               WHEN OTHER
                   DISPLAY "Invalid choice. Try again."
           END-EVALUATE.

      *> ============================================================
      *> CREATE CUSTOMER
      *> ============================================================
       3000-CREATE-CUSTOMER.
           DISPLAY SPACES
           DISPLAY "--- Create New Customer ---"

           DISPLAY "First Name: " WITH NO ADVANCING
           ACCEPT HV-FIRST-NAME

           DISPLAY "Last Name:  " WITH NO ADVANCING
           ACCEPT HV-LAST-NAME

           DISPLAY "Email:      " WITH NO ADVANCING
           ACCEPT HV-EMAIL

           EXEC SQL
               INSERT INTO CUSTOMERS
                   (FIRST_NAME, LAST_NAME, EMAIL)
               VALUES
                   (:HV-FIRST-NAME, :HV-LAST-NAME, :HV-EMAIL)
           END-EXEC

           IF SQLCODE = 0
               EXEC SQL COMMIT END-EXEC
               DISPLAY "Customer created successfully."
           ELSE
               EXEC SQL ROLLBACK END-EXEC
               DISPLAY "ERROR: Could not create customer."
               DISPLAY "SQLCODE: " SQLCODE
           END-IF.

      *> ============================================================
      *> RETRIEVE CUSTOMER BY ID
      *> ============================================================
       4000-RETRIEVE-CUSTOMER.
           DISPLAY SPACES
           DISPLAY "--- Retrieve Customer ---"
           DISPLAY "Customer ID: " WITH NO ADVANCING
           ACCEPT HV-CUSTOMER-ID

           EXEC SQL
               SELECT CUSTOMER_ID,
                      FIRST_NAME,
                      LAST_NAME,
                      EMAIL,
                      CREATED_AT
               INTO   :HV-CUSTOMER-ID,
                      :HV-FIRST-NAME,
                      :HV-LAST-NAME,
                      :HV-EMAIL,
                      :HV-CREATED-AT
               FROM   CUSTOMERS
               WHERE  CUSTOMER_ID = :HV-CUSTOMER-ID
           END-EXEC

           IF SQLCODE = 0
               DISPLAY "----------------------------------------"
               DISPLAY "ID:         " HV-CUSTOMER-ID
               DISPLAY "Name:       " HV-FIRST-NAME
               DISPLAY "            " HV-LAST-NAME
               DISPLAY "Email:      " HV-EMAIL
               DISPLAY "Created:    " HV-CREATED-AT
               DISPLAY "----------------------------------------"
           ELSE IF SQLCODE = 100
               DISPLAY "Customer not found."
           ELSE
               DISPLAY "ERROR retrieving customer."
               DISPLAY "SQLCODE: " SQLCODE
           END-IF.

      *> ============================================================
      *> LIST ALL CUSTOMERS (Cursor)
      *> ============================================================
       5000-LIST-CUSTOMERS.
           EXEC SQL
               DECLARE CSR-CUSTOMERS CURSOR FOR
               SELECT CUSTOMER_ID,
                      FIRST_NAME,
                      LAST_NAME,
                      EMAIL,
                      CREATED_AT
               FROM   CUSTOMERS
               ORDER BY CUSTOMER_ID
           END-EXEC

           EXEC SQL OPEN CSR-CUSTOMERS END-EXEC

           IF SQLCODE NOT = 0
               DISPLAY "ERROR: Could not open customer cursor."
               DISPLAY "SQLCODE: " SQLCODE
               EXIT PARAGRAPH
           END-IF

           DISPLAY SPACES
           DISPLAY "--- Customer List ---"
           DISPLAY "ID       FIRST NAME"
           DISPLAY "         LAST NAME            EMAIL"
           DISPLAY "----------------------------------------"

           PERFORM 5100-FETCH-CUSTOMER
               UNTIL SQLCODE NOT = 0

           EXEC SQL CLOSE CSR-CUSTOMERS END-EXEC.

       5100-FETCH-CUSTOMER.
           EXEC SQL
               FETCH CSR-CUSTOMERS
               INTO  :HV-CUSTOMER-ID,
                     :HV-FIRST-NAME,
                     :HV-LAST-NAME,
                     :HV-EMAIL,
                     :HV-CREATED-AT
           END-EXEC

           IF SQLCODE = 0
               DISPLAY HV-CUSTOMER-ID " "
                       HV-FIRST-NAME
               DISPLAY "         "
                       HV-LAST-NAME "  "
                       HV-EMAIL
           END-IF.

      *> ============================================================
      *> DISCONNECT
      *> ============================================================
       9000-DISCONNECT-DB.
           EXEC SQL
               DISCONNECT ALL
           END-EXEC.
