# System Architecture

## Overview

The COBOL-DB-System is a modular banking backend simulation built with COBOL and embedded SQL (EXEC SQL). It uses PostgreSQL for local development and is designed to be DB2-compatible for enterprise environments.

---

## Data Flow

```
User Input (CLI)
     │
     ▼
┌────────────────────┐
│  COBOL Program     │  (custmgr / acctmgr / txnproc / rptgen)
│  ┌──────────────┐  │
│  │ EXEC SQL     │──┼──► PostgreSQL / DB2
│  │ (Host Vars)  │  │
│  └──────────────┘  │
│  ┌──────────────┐  │
│  │ SQLCA        │◄─┼──  Status codes (SQLCODE)
│  └──────────────┘  │
└────────────────────┘
     │
     ▼
Terminal Output / Audit Log
```

---

## Module Descriptions

### custmgr.cbl — Customer Manager

Manages the CUSTOMERS table.

- **Create**: INSERT with COMMIT on success, ROLLBACK on failure.
- **Retrieve**: SELECT INTO by CUSTOMER_ID.
- **List**: Cursor-based iteration (CSR-CUSTOMERS) ordered by ID.

### acctmgr.cbl — Account Manager

Manages the ACCOUNTS table.

- **Create**: Validates CUSTOMER_ID exists, then INSERTs with default ACTIVE status.
- **Balance Check**: SELECT BALANCE/TYPE/STATUS by ACCOUNT_ID.
- **Status Update**: UPDATE STATUS to ACTIVE or CLOSED.
- **List by Customer**: Cursor-based iteration (CSR-ACCOUNTS) filtered by CUSTOMER_ID.

### txnproc.cbl — Transaction Processor

Core financial operations against ACCOUNTS, TRANSACTIONS, and AUDIT_LOG.

- **Deposit**: Validates account is active → adds amount to balance → records transaction → commits → writes audit entry.
- **Withdrawal**: Same flow with insufficient-funds check (balance - amount >= 0). Failures are rolled back and audited.
- **Batch Processing**: Reads `data/batch_transactions.txt` (CSV format: `ACCOUNT_ID,AMOUNT,TXN_TYPE`), processes each line sequentially, tracks success/failure counts.

#### Transaction Safety Pattern

```
BEGIN (implicit)
  UPDATE ACCOUNTS SET BALANCE = ...
  INSERT INTO TRANSACTIONS (...)
  IF any SQLCODE ≠ 0 → ROLLBACK
  ELSE → COMMIT
  INSERT INTO AUDIT_LOG (...)
  COMMIT
```

### rptgen.cbl — Report Generator

Read-only reporting against all tables.

- **Account Summary**: JOIN between ACCOUNTS and CUSTOMERS via cursor (CSR-ACCT-SUMMARY).
- **Transaction History**: Cursor-based listing of TRANSACTIONS for a given account, ordered by date descending.
- **Account Totals**: Aggregate SUM/COUNT queries for deposits and withdrawals per account.

---

## Database Interaction Patterns

### Host Variables

All COBOL ↔ SQL data exchange uses host variables declared inside `EXEC SQL BEGIN/END DECLARE SECTION`. Variables are prefixed `HV-` by convention.

### Error Handling

Every SQL statement is followed by an SQLCODE check:

- `SQLCODE = 0` — Success
- `SQLCODE = 100` — No rows found
- Any other value — Error (displayed to user)

### SQLCA

Each program includes `EXEC SQL INCLUDE SQLCA END-EXEC` for access to `SQLCODE` and other diagnostic fields.

### Cursors

Multi-row result sets use DECLARE → OPEN → FETCH (in loop) → CLOSE pattern. Fetch loops terminate when `SQLCODE ≠ 0` (typically 100 for end-of-data).

---

## Database Schema

Four tables with referential integrity:

- **CUSTOMERS** — base entity, referenced by ACCOUNTS
- **ACCOUNTS** — linked to CUSTOMERS via FK, has CHECK constraints on BALANCE (≥ 0), ACCOUNT_TYPE, and STATUS
- **TRANSACTIONS** — linked to ACCOUNTS via FK, CHECK on AMOUNT (> 0) and TXN_TYPE
- **AUDIT_LOG** — independent activity log with SUCCESS/FAILURE status

See `sql/schema.sql` for full DDL.

---

## File Organization

```
src/           COBOL source programs (one per domain)
sql/           DDL and seed data
data/          Runtime input files (batch transactions)
docs/          Architecture and design documentation
```
