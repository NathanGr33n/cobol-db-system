      ******************************************************************
      * WSCOMMON.CPY - Shared Working-Storage Items
      * Common variables used across all banking programs
      ******************************************************************
       01  WS-MENU-CHOICE          PIC 9          VALUE ZERO.
       01  WS-CONTINUE-FLAG        PIC X          VALUE 'Y'.
           88 WS-CONTINUE                         VALUE 'Y' 'y'.
           88 WS-EXIT                             VALUE 'N' 'n'.
       01  WS-EOF-FLAG             PIC X          VALUE 'N'.
           88 WS-EOF                              VALUE 'Y'.
           88 WS-NOT-EOF                          VALUE 'N'.
       01  WS-RECORD-COUNT         PIC 9(6)       VALUE ZEROS.
       01  WS-SAVED-SQLCODE        PIC S9(9)      VALUE ZEROS.
