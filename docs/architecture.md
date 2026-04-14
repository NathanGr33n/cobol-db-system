# System Architecture

## Overview

The COBOL-DB Banking System is a modular, enterprise-style backend that processes banking operations through four independent COBOL programs, each communicating with a PostgreSQL database via embedded SQL (EXEC SQL).

## System Layers

```
┌─────────────────────────────────────────────────┐
│                  CLI / Input Layer               │
│   (Interactive Menus & Batch File Input)         │
└───────────────────────┬─────────────────────────┘
                        │
┌───────────────────────▼─────────────────────────┐
│            COBOL Business Logic Layer            │
│                                                  │
│  ┌──────────┐ ┌──────────┐ ┌─────────┐ ┌──────┐│
│  │ custmgr  │ │ acctmgr  │ │ txnproc │ │rptgen││
│  │ Customer │ │ Account  │ │  Txn    │ │Report││
│  │ Manager  │ │ Manager  │ │ Process │ │ Gen  ││
│  └────┬─────┘ └────┬─────┘ └───┬─────┘ └──┬───┘│
└───────┼────────────┼───────────┼───────────┼────┘
        │            │           │           │
┌───────▼────────────▼───────────▼───────────▼────┐
│          Embedded SQL Layer (EXEC SQL)           │
│       SQLCA / COMMIT / ROLLBACK / Cursors        │
└───────────────────────┬─────────────────────────┘
                        │
┌───────────────────────▼─────────────────────────┐
│          PostgreSQL Database (cobol_bank)         │
│                                                  │
│  CUSTOMERS ─── ACCOUNTS ─── TRANSACTIONS         │
│                                  │               │
│                              AUDIT_LOG           │
└──────────────────────────────────────────────────┘
```

## Program Responsibilities

### custmgr.cbl — Customer Manager
- Create new customers with input validation
- Retrieve customer details by ID
- List all customers via cursor iteration
- Audit logs all create operations

### acctmgr.cbl — Account Manager
- Create accounts with customer FK validation
- Check account balances
- Update account status (ACTIVE/CLOSED)
- Prevents closing accounts with positive balance
- Audit logs all account operations

### txnproc.cbl — Transaction Processor
- Interactive deposit and withdrawal processing
- Batch file processing (CSV: `ACCOUNT_ID,AMOUNT,TXN_TYPE`)
- Full transaction safety with COMMIT/ROLLBACK
- Validates: account exists, is active, sufficient funds
- Records all transactions and audit entries

### rptgen.cbl — Report Generator
- Account summary by customer (cursor-based)
- Transaction history by account (cursor-based, descending)
- Full account report across all customers (JOIN query)
- Aggregate transaction summary (deposits/withdrawals totals)
- Audit log report (last 50 entries)

## Database Design

### Integrity Constraints
- `CUSTOMERS.EMAIL` — UNIQUE, NOT NULL
- `ACCOUNTS.CUSTOMER_ID` — FK to CUSTOMERS, ON DELETE RESTRICT
- `ACCOUNTS.BALANCE` — CHECK >= 0 (enforced at DB level)
- `ACCOUNTS.ACCOUNT_TYPE` — CHECK IN ('CHECKING', 'SAVINGS')
- `ACCOUNTS.STATUS` — CHECK IN ('ACTIVE', 'CLOSED')
- `TRANSACTIONS.AMOUNT` — CHECK > 0
- `TRANSACTIONS.TXN_TYPE` — CHECK IN ('DEPOSIT', 'WITHDRAW')
- `TRANSACTIONS.ACCOUNT_ID` — FK to ACCOUNTS, ON DELETE RESTRICT

### Indexes
- `idx_customers_email` — fast email lookups
- `idx_customers_name` — name-based queries
- `idx_accounts_customer` — customer-to-accounts join
- `idx_accounts_status` — filter active accounts
- `idx_txn_account` — transaction-to-account join
- `idx_txn_created_at` — chronological queries
- `idx_audit_created_at` — audit log time queries

### Audit Trigger
A PostgreSQL trigger (`trg_audit_balance`) automatically logs balance changes to `AUDIT_LOG` when `ACCOUNTS.BALANCE` is updated. This provides a secondary audit trail independent of application-level logging.

## Transaction Safety Model

All state-changing operations follow this pattern:

1. **Validate** — Check all preconditions (account exists, active, sufficient funds)
2. **Execute** — Perform the UPDATE/INSERT operations
3. **Verify** — Check SQLCODE after each SQL statement
4. **Commit or Rollback** — COMMIT on success, ROLLBACK on any failure
5. **Audit** — Log the outcome to AUDIT_LOG

If any step fails, all prior changes within that transaction are rolled back.

## Build & Run

### Prerequisites
- GnuCOBOL (`cobc`) compiler
- PostgreSQL 14+
- `ocesql` precompiler (for EXEC SQL processing)

### Database Setup
```bash
createdb cobol_bank
psql -d cobol_bank -f sql/schema.sql
psql -d cobol_bank -f sql/seed_data.sql
```

### Compile (with ocesql precompiler)
```bash
# Preprocess embedded SQL, then compile
ocesql src/custmgr.cbl src/custmgr.cob
cobc -x -l ocesql src/custmgr.cob -o bin/custmgr

ocesql src/acctmgr.cbl src/acctmgr.cob
cobc -x -l ocesql src/acctmgr.cob -o bin/acctmgr

ocesql src/txnproc.cbl src/txnproc.cob
cobc -x -l ocesql src/txnproc.cob -o bin/txnproc

ocesql src/rptgen.cbl src/rptgen.cob
cobc -x -l ocesql src/rptgen.cob -o bin/rptgen
```

### Run
```bash
./bin/custmgr    # Customer management
./bin/acctmgr    # Account management
./bin/txnproc    # Transaction processing (interactive + batch)
./bin/rptgen     # Report generation
```

## Data Flow: Deposit Transaction

```
User Input: Account 2001, Amount $500, Type DEPOSIT
    │
    ▼
[txnproc] SELECT BALANCE, STATUS FROM ACCOUNTS WHERE ACCOUNT_ID = 2001
    │       → Balance: $5000.00, Status: ACTIVE
    ▼
[txnproc] COMPUTE NEW-BALANCE = 5000.00 + 500.00
    │       → New Balance: $5500.00
    ▼
[txnproc] UPDATE ACCOUNTS SET BALANCE = 5500.00 WHERE ACCOUNT_ID = 2001
    │       → SQLCODE = 0 (success)
    ▼
[txnproc] INSERT INTO TRANSACTIONS (2001, 500.00, 'DEPOSIT')
    │       → SQLCODE = 0 (success)
    ▼
[txnproc] EXEC SQL COMMIT
    │       → Transaction committed
    ▼
[trigger] trg_audit_balance fires → inserts AUDIT_LOG entry
    │
    ▼
[txnproc] INSERT INTO AUDIT_LOG ('DEPOSIT', 'SUCCESS', ...)
    │
    ▼
Output: "SUCCESS: New Balance = $5,500.00"
```
