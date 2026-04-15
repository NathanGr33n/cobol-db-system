      *> ============================================================
      *> DATABASE CONFIGURATION COPYBOOK
      *> Shared connection parameters and connect/disconnect
      *> paragraphs. COPY this into WORKING-STORAGE and
      *> PROCEDURE DIVISION of every program.
      *> ============================================================

      *> ----- Connection Parameters -----
       01  WS-DB-NAME             PIC X(50) VALUE 'coboldb'.
       01  WS-DB-USER             PIC X(50) VALUE 'coboluser'.
