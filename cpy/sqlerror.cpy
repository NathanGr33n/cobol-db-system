      ******************************************************************
      * SQLERROR.CPY - Standardized SQL Error Display
      * Call 8800-DISPLAY-SQL-ERROR after setting WS-ERR-CONTEXT
      ******************************************************************
       01  WS-ERR-CONTEXT           PIC X(50)      VALUE SPACES.
       01  WS-ERR-SQLCODE           PIC S9(9)      VALUE ZEROS.

      ******************************************************************
      * In PROCEDURE DIVISION, include after other paragraphs:
      *   PERFORM 8800-DISPLAY-SQL-ERROR
      ******************************************************************
