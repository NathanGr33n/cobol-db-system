      ******************************************************************
      * MAINMENU.CBL - Main Menu Dispatcher
      * Banking System - Central Entry Point
      * Dispatches to individual program modules via CALL
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. MAINMENU.
       AUTHOR. COBOL-DB-SYSTEM.
       DATE-WRITTEN. 2024-06-01.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       REPOSITORY.
           FUNCTION ALL INTRINSIC.

       DATA DIVISION.
       WORKING-STORAGE SECTION.

       01  WS-MENU-CHOICE          PIC 9          VALUE ZERO.
       01  WS-CONTINUE-FLAG        PIC X          VALUE 'Y'.
           88 WS-CONTINUE                         VALUE 'Y' 'y'.
           88 WS-EXIT                             VALUE 'N' 'n'.
       01  WS-SEPARATOR            PIC X(50)      VALUE ALL '='.

       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-DISPLAY-BANNER
           PERFORM 2000-PROCESS-MENU
               UNTIL WS-EXIT
           PERFORM 9000-TERMINATE
           STOP RUN
           .

       1000-DISPLAY-BANNER.
           DISPLAY SPACES
           DISPLAY WS-SEPARATOR
           DISPLAY '  COBOL-DB BANKING SYSTEM'
           DISPLAY '  Enterprise Banking Backend'
           DISPLAY WS-SEPARATOR
           .

       2000-PROCESS-MENU.
           DISPLAY SPACES
           DISPLAY WS-SEPARATOR
           DISPLAY '  MAIN MENU'
           DISPLAY WS-SEPARATOR
           DISPLAY '  1. Customer Manager'
           DISPLAY '  2. Account Manager'
           DISPLAY '  3. Transaction Processor'
           DISPLAY '  4. Report Generator'
           DISPLAY '  9. Exit System'
           DISPLAY WS-SEPARATOR
           DISPLAY 'Enter choice: ' WITH NO ADVANCING
           ACCEPT WS-MENU-CHOICE

           EVALUATE WS-MENU-CHOICE
               WHEN 1
                   CALL 'CUSTMGR'
                   CANCEL 'CUSTMGR'
               WHEN 2
                   CALL 'ACCTMGR'
                   CANCEL 'ACCTMGR'
               WHEN 3
                   CALL 'TXNPROC'
                   CANCEL 'TXNPROC'
               WHEN 4
                   CALL 'RPTGEN'
                   CANCEL 'RPTGEN'
               WHEN 9
                   SET WS-EXIT TO TRUE
               WHEN OTHER
                   DISPLAY 'ERROR: Invalid choice. Try again.'
           END-EVALUATE
           .

       9000-TERMINATE.
           DISPLAY SPACES
           DISPLAY WS-SEPARATOR
           DISPLAY '  System shutdown complete.'
           DISPLAY WS-SEPARATOR
           .
