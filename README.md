# Cobol-DB-System

**COBOL + SQL/DB2 Integration Project**

---

## Overview

This project is a **simulation of an enterprise-grade banking backend system** built using COBOL and a relational database (DB2 or PostgreSQL for development). It demonstrates how legacy systems handle **customer data, account management, and financial transactions** using embedded SQL.

The system is designed to mirror real-world mainframe applications by combining:

* Transaction-safe database operations
* Batch and real-time processing
* Modular COBOL program structure

---

## Goals

* Implement **transaction-safe financial operations (COMMIT/ROLLBACK)**
* Simulate **real-world banking workflows**
* Bridge **legacy systems with modern development practices**

---

## System Architecture

```
[ CLI / Input Layer ]
          ↓
[ COBOL Programs (Business Logic) ]
          ↓
[ Embedded SQL (EXEC SQL) ]
          ↓
[ Relational Database (DB2/PostgreSQL) ]
```

Optional modern extension:

```
[ Python API Layer ] → [ COBOL Backend ] → [ Database ]
```

---

## 🗃️ Database Schema

### CUSTOMERS

Stores customer information.

| Column      | Type         | Description           |
| ----------- | ------------ | --------------------- |
| CUSTOMER_ID | INT (PK)     | Unique customer ID    |
| FIRST_NAME  | VARCHAR(50)  | First name            |
| LAST_NAME   | VARCHAR(50)  | Last name             |
| EMAIL       | VARCHAR(100) | Contact email         |
| CREATED_AT  | DATE         | Account creation date |

---

### ACCOUNTS

Stores bank account data.

| Column       | Type          | Description       |
| ------------ | ------------- | ----------------- |
| ACCOUNT_ID   | INT (PK)      | Unique account ID |
| CUSTOMER_ID  | INT (FK)      | Linked customer   |
| BALANCE      | DECIMAL(12,2) | Current balance   |
| ACCOUNT_TYPE | VARCHAR(20)   | Checking/Savings  |
| STATUS       | VARCHAR(20)   | Active/Closed     |

---

### TRANSACTIONS

Stores financial transaction records.

| Column     | Type          | Description        |
| ---------- | ------------- | ------------------ |
| TXN_ID     | INT (PK)      | Transaction ID     |
| ACCOUNT_ID | INT (FK)      | Related account    |
| AMOUNT     | DECIMAL(12,2) | Transaction amount |
| TXN_TYPE   | VARCHAR(10)   | DEPOSIT/WITHDRAW   |
| CREATED_AT | TIMESTAMP     | Timestamp          |

---

### AUDIT_LOG (Optional)

Tracks system activity.

| Column     | Type        | Description         |
| ---------- | ----------- | ------------------- |
| LOG_ID     | INT         | Log entry ID        |
| ACTION     | VARCHAR(50) | Operation performed |
| STATUS     | VARCHAR(20) | SUCCESS/FAILURE     |
| CREATED_AT | TIMESTAMP   | Timestamp           |

---

## Core COBOL Programs

### 1. Customer Manager (`custmgr.cbl`)

* Create new customers
* Retrieve customer details

---

### 2. Account Manager (`acctmgr.cbl`)

* Create accounts
* Check balances
* Update account status

---

### 3. Transaction Processor (`txnproc.cbl`)

* Process deposits and withdrawals
* Update balances
* Record transactions
* Handle transaction safety (commit/rollback)

---

### 4. Report Generator (`rptgen.cbl`)

* Generate account summaries
* Produce transaction reports
* Use cursors for multi-row processing

---

## Key Features

### Embedded SQL Integration

* Direct SQL queries inside COBOL programs
* Data retrieval and updates using `EXEC SQL`

### Transaction Safety

* Ensures consistency using:

  * `COMMIT`
  * `ROLLBACK`

### Batch Processing

* Process large transaction files
* Simulate real-world banking batch jobs

### Cursor-Based Data Handling

* Efficiently iterate through large datasets

### Modular Design

* Separate COBOL programs for each domain

---

## 🔄 Example Workflow

### Deposit Transaction

1. User inputs:

```
Account ID: 1001
Amount: 500
```

2. System actions:

* Validate account exists
* Update balance
* Insert transaction record
* Commit transaction

3. Output:

```
SUCCESS: New Balance = 5500.00
```

---

## Project Structure

```
cobol-db-system/
│
├── src/
│   ├── custmgr.cbl
│   ├── acctmgr.cbl
│   ├── txnproc.cbl
│   └── rptgen.cbl
│
├── sql/
│   ├── schema.sql
│   └── seed_data.sql
│
├── data/
│   └── batch_transactions.txt
│
├── docs/
│   └── architecture.md
│
└── README.md
```

---

## Getting Started

### Prerequisites

* COBOL compiler (GnuCOBOL recommended)
* Database:

  * DB2 (enterprise option), or
  * PostgreSQL (local development)
* SQL precompiler (if required)

---

### Setup Steps

1. Clone the repository:

```
git clone https://github.com/yourusername/cobol-db-system.git
cd cobol-db-system
```

2. Set up the database:

```
psql -U user -d dbname -f sql/schema.sql
psql -U user -d dbname -f sql/seed_data.sql
```

3. Compile COBOL programs:

```
cobc -x src/txnproc.cbl
```

4. Run the program:

```
./txnproc
```

---

## Batch Processing Example

Input file (`batch_transactions.txt`):

```
1001,200,DEPOSIT
1002,50,WITHDRAW
```

Run batch processor to:

* Update balances
* Insert transaction logs
* Generate output report

---

## Concepts Demonstrated

* Enterprise COBOL development
* Relational database design
* Embedded SQL usage
* Transaction control and data integrity
* Batch vs real-time processing
* Financial system design patterns

---

## Advanced Enhancements

* Add REST API layer (Python / FastAPI)
* Implement stored procedures
* Add concurrency testing
* Build a web dashboard frontend
* Introduce authentication/authorization
* Scale to large datasets (100k+ records)


## License

MIT License (or your preferred license)

---

## Author

Your Name
GitHub: https://github.com/NathanGr33n

---

## Future Vision

This project can evolve into a **modernized legacy system platform**, combining:

* COBOL for core logic
* Python for APIs
* Cloud-based database infrastructure

A powerful demonstration of bridging **old-world systems with modern engineering**.
