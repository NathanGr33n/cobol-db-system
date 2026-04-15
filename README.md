# COBOL-DB-System

**Enterprise Banking Backend — COBOL + SQL + Modern REST API**

---

## Overview

A simulation of an enterprise-grade banking backend built with COBOL and embedded SQL. The system demonstrates how legacy mainframe applications handle customer data, account management, financial transactions, and reporting — then bridges that world with a modern Python REST API hitting the same database.

### Key Capabilities

* Transaction-safe operations with full COMMIT/ROLLBACK
* Inter-account transfers with row-level locking (SELECT FOR UPDATE)
* Batch processing (transactions and interest calculation)
* Stored procedures for DB-side business logic
* Database views for simplified reporting
* Date-filtered and file-based report generation
* REST API (FastAPI) sharing the same PostgreSQL database
* Docker Compose for one-command setup
* 21-case automated test suite

---

## System Architecture

```
[ CLI / Input Layer ]           [ REST API (FastAPI) ]
          |                              |
[ COBOL Programs ]              [ Python / psycopg2 ]
          |                              |
[ Embedded SQL ]                [ Stored Procedures ]
          |                              |
          +--------- PostgreSQL ---------+
                        |
                [ Views / Audit Log ]
```

---

## Database Schema

### CUSTOMERS
Primary entity. Fields: `CUSTOMER_ID`, `FIRST_NAME`, `LAST_NAME`, `EMAIL`, `CREATED_AT`.

### ACCOUNTS
Linked to CUSTOMERS via FK. Fields: `ACCOUNT_ID`, `CUSTOMER_ID`, `BALANCE`, `ACCOUNT_TYPE` (CHECKING/SAVINGS), `STATUS` (ACTIVE/CLOSED), `INTEREST_RATE`.

### TRANSACTIONS
Linked to ACCOUNTS via FK. Fields: `TXN_ID`, `ACCOUNT_ID`, `AMOUNT`, `TXN_TYPE` (DEPOSIT/WITHDRAW/TRANSFER/INTEREST), `CREATED_AT`.

### AUDIT_LOG
Independent activity log. Fields: `LOG_ID`, `ACTION`, `STATUS` (SUCCESS/FAILURE), `CREATED_AT`.

---

## COBOL Programs

| Program | Description |
|---------|-------------|
| `custmgr.cbl` | Create, retrieve, and list customers |
| `acctmgr.cbl` | Create accounts, check balances, update status with closure safeguards |
| `txnproc.cbl` | Process deposits/withdrawals with row locking, batch processing, audit logging |
| `xfermgr.cbl` | Atomic inter-account transfers with dual-row locking and multi-table transactions |
| `rptgen.cbl` | Account summaries, transaction history, date-filtered reports, file export |
| `intcalc.cbl` | Batch monthly interest calculation for SAVINGS accounts |

All programs use a shared copybook (`dbconfig.cpy`) for database configuration.

---

## REST API Endpoints

Run with: `uvicorn api.main:app --reload`

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/customers` | List all customers |
| GET | `/customers/{id}` | Get customer by ID |
| POST | `/customers` | Create customer |
| GET | `/accounts/{id}` | Get account details |
| GET | `/accounts/{id}/balance` | Check balance |
| POST | `/transactions/deposit` | Process deposit (via stored procedure) |
| POST | `/transactions/withdraw` | Process withdrawal (via stored procedure) |
| POST | `/transactions/transfer` | Inter-account transfer (via stored procedure) |
| GET | `/reports/account-summary` | Account summary (via database view) |
| GET | `/reports/transactions/{id}` | Transaction history with optional date filters |

Interactive docs available at `http://localhost:8000/docs` when running.

---

## Project Structure

```
cobol-db-system/
├── api/                    Python REST API
│   ├── Dockerfile
│   ├── main.py             FastAPI application
│   ├── db.py               Connection pool
│   ├── models.py           Pydantic schemas
│   └── requirements.txt
├── config/                 Environment configuration
│   ├── dev.env
│   └── test.env
├── data/                   Runtime input files
│   └── batch_transactions.txt
├── docs/                   Architecture documentation
│   └── architecture.md
├── reports/                Generated report output
├── sql/                    Database DDL and DML
│   ├── schema.sql          Table definitions
│   ├── seed_data.sql       Sample data
│   ├── procedures.sql      Stored procedures
│   └── views.sql           Reporting views
├── src/                    COBOL source programs
│   ├── dbconfig.cpy        Shared DB configuration copybook
│   ├── custmgr.cbl
│   ├── acctmgr.cbl
│   ├── txnproc.cbl
│   ├── xfermgr.cbl
│   ├── rptgen.cbl
│   └── intcalc.cbl
├── tests/                  Test suite
│   ├── setup-testdb.sql
│   ├── teardown-testdb.sql
│   ├── test-banking.cbl    21-case COBOL test suite
│   ├── run-tests.ps1       PowerShell test runner
│   └── run-tests.sh        Bash test runner
├── docker-compose.yml
├── Makefile
└── README.md
```

---

## Getting Started

### Prerequisites

* GnuCOBOL compiler (`cobc`)
* PostgreSQL (local) or Docker
* Python 3.10+ (for REST API)
* GNU Make (optional, for build automation)

### Option 1: Docker (Recommended)

```
docker-compose up
```

This starts PostgreSQL (with schema, seed data, procedures, and views auto-applied) and the FastAPI server on port 8000.

### Option 2: Local Setup

1. **Database:**
```
psql -U coboluser -d coboldb -f sql/schema.sql
psql -U coboluser -d coboldb -f sql/seed_data.sql
psql -U coboluser -d coboldb -f sql/procedures.sql
psql -U coboluser -d coboldb -f sql/views.sql
```

2. **COBOL programs:**
```
make all
```
Or individually: `make bin/txnproc`

3. **REST API:**
```
pip install -r api/requirements.txt
uvicorn api.main:app --reload
```

4. **Run a program:**
```
bin/txnproc
```

---

## Testing

### Automated test suite (21 tests):
```
# PowerShell
.\tests\run-tests.ps1

# Bash
bash tests/run-tests.sh

# Via Makefile
make test
```

### Test coverage:
* Deposits and withdrawals (success + balance verification)
* Overdraft rejection with balance preservation
* Closed and non-existent account rejection
* Transaction and audit record verification
* Compound operations (multiple deposits, deposit-then-withdraw)
* Inter-account transfers (success, balances, insufficient funds, same-account, closed target)
* DB constraint enforcement (zero-amount rejection)
* Transfer record verification

---

## Concepts Demonstrated

* Enterprise COBOL development with modular program structure
* Embedded SQL (EXEC SQL) with host variables and SQLCA
* Transaction safety (COMMIT/ROLLBACK)
* Row-level locking (SELECT FOR UPDATE)
* Cursor-based multi-row processing
* COBOL copybooks for shared configuration
* Batch processing (transactions and interest calculation)
* Stored procedures (PL/pgSQL)
* Database views for reporting
* File I/O (report generation to flat files)
* Legacy-modern integration (COBOL + Python REST API on shared DB)
* Containerized deployment (Docker Compose)
* Automated testing with deterministic test data

---

## License

MIT License

---

## Author

GitHub: https://github.com/NathanGr33n
