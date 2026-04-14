      ******************************************************************
      * SQLERROR-PARA.CPY - SQL Error Display Paragraph
      * COPY this into PROCEDURE DIVISION
      * Set WS-ERR-CONTEXT and WS-ERR-SQLCODE before calling
      ******************************************************************
       8800-DISPLAY-SQL-ERROR.
           DISPLAY 'ERROR: ' FUNCTION TRIM(WS-ERR-CONTEXT)
           DISPLAY '  SQLCODE: ' WS-ERR-SQLCODE
           IF WS-ERR-SQLCODE = 100
               DISPLAY '  (No data found)'
           END-IF
           IF WS-ERR-SQLCODE = -803
               DISPLAY '  (Unique constraint violation)'
           END-IF
           IF WS-ERR-SQLCODE = -530
               DISPLAY '  (Foreign key violation)'
           END-IF
           .
