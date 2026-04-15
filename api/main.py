"""COBOL-DB-SYSTEM REST API.

A modern FastAPI wrapper that hits the same PostgreSQL database used
by the COBOL programs, demonstrating legacy-modern coexistence.
"""

from contextlib import asynccontextmanager
from decimal import Decimal
from typing import List

from fastapi import FastAPI, HTTPException, Query

from api.db import close_pool, get_cursor
from api.models import (
    AccountResponse,
    AccountSummaryRow,
    BalanceResponse,
    CustomerCreate,
    CustomerResponse,
    DepositRequest,
    TransactionResponse,
    TransactionResult,
    TransferRequest,
    WithdrawRequest,
)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup/shutdown: manage DB connection pool."""
    yield
    close_pool()


app = FastAPI(
    title="COBOL-DB-SYSTEM API",
    description="REST API for the COBOL banking backend",
    version="1.0.0",
    lifespan=lifespan,
)


# ----------------------------------------------------------------
# Customers
# ----------------------------------------------------------------

@app.get("/customers", response_model=List[CustomerResponse])
def list_customers():
    """List all customers."""
    with get_cursor() as cur:
        cur.execute(
            "SELECT customer_id, first_name, last_name, email, created_at "
            "FROM customers ORDER BY customer_id"
        )
        return cur.fetchall()


@app.get("/customers/{customer_id}", response_model=CustomerResponse)
def get_customer(customer_id: int):
    """Retrieve a customer by ID."""
    with get_cursor() as cur:
        cur.execute(
            "SELECT customer_id, first_name, last_name, email, created_at "
            "FROM customers WHERE customer_id = %s",
            (customer_id,),
        )
        row = cur.fetchone()
    if not row:
        raise HTTPException(404, f"Customer {customer_id} not found")
    return row


@app.post("/customers", response_model=CustomerResponse, status_code=201)
def create_customer(body: CustomerCreate):
    """Create a new customer."""
    with get_cursor(commit=True) as cur:
        cur.execute(
            "INSERT INTO customers (first_name, last_name, email) "
            "VALUES (%s, %s, %s) "
            "RETURNING customer_id, first_name, last_name, email, created_at",
            (body.first_name, body.last_name, body.email),
        )
        return cur.fetchone()


# ----------------------------------------------------------------
# Accounts
# ----------------------------------------------------------------

@app.get("/accounts/{account_id}", response_model=AccountResponse)
def get_account(account_id: int):
    """Retrieve account details."""
    with get_cursor() as cur:
        cur.execute(
            "SELECT account_id, customer_id, balance, account_type, "
            "status, interest_rate FROM accounts WHERE account_id = %s",
            (account_id,),
        )
        row = cur.fetchone()
    if not row:
        raise HTTPException(404, f"Account {account_id} not found")
    return row


@app.get("/accounts/{account_id}/balance", response_model=BalanceResponse)
def get_balance(account_id: int):
    """Check account balance."""
    with get_cursor() as cur:
        cur.execute(
            "SELECT account_id, balance, status "
            "FROM accounts WHERE account_id = %s",
            (account_id,),
        )
        row = cur.fetchone()
    if not row:
        raise HTTPException(404, f"Account {account_id} not found")
    return row


# ----------------------------------------------------------------
# Transactions
# ----------------------------------------------------------------

@app.post("/transactions/deposit", response_model=TransactionResult)
def process_deposit(body: DepositRequest):
    """Process a deposit using the fn_process_deposit stored procedure."""
    try:
        with get_cursor(commit=True) as cur:
            cur.execute(
                "SELECT fn_process_deposit(%s, %s) AS new_balance",
                (body.account_id, body.amount),
            )
            result = cur.fetchone()
            return TransactionResult(
                success=True,
                message=f"Deposit of ${body.amount} processed",
                new_balance=result["new_balance"],
            )
    except Exception as e:
        raise HTTPException(400, str(e))


@app.post("/transactions/withdraw", response_model=TransactionResult)
def process_withdrawal(body: WithdrawRequest):
    """Process a withdrawal using the fn_process_withdrawal stored procedure."""
    try:
        with get_cursor(commit=True) as cur:
            cur.execute(
                "SELECT fn_process_withdrawal(%s, %s) AS new_balance",
                (body.account_id, body.amount),
            )
            result = cur.fetchone()
            return TransactionResult(
                success=True,
                message=f"Withdrawal of ${body.amount} processed",
                new_balance=result["new_balance"],
            )
    except Exception as e:
        raise HTTPException(400, str(e))


@app.post("/transactions/transfer", response_model=TransactionResult)
def process_transfer(body: TransferRequest):
    """Process an inter-account transfer using the fn_transfer stored procedure."""
    if body.source_account_id == body.target_account_id:
        raise HTTPException(400, "Source and target accounts must differ")
    try:
        with get_cursor(commit=True) as cur:
            cur.execute(
                "SELECT fn_transfer(%s, %s, %s) AS new_balance",
                (body.source_account_id, body.target_account_id, body.amount),
            )
            result = cur.fetchone()
            return TransactionResult(
                success=True,
                message=f"Transfer of ${body.amount} processed",
                new_balance=result["new_balance"],
            )
    except Exception as e:
        raise HTTPException(400, str(e))


# ----------------------------------------------------------------
# Reports
# ----------------------------------------------------------------

@app.get("/reports/account-summary", response_model=List[AccountSummaryRow])
def account_summary():
    """Generate account summary report using the v_account_summary view."""
    with get_cursor() as cur:
        cur.execute("SELECT * FROM v_account_summary")
        return cur.fetchall()


@app.get(
    "/reports/transactions/{account_id}",
    response_model=List[TransactionResponse],
)
def transaction_history(
    account_id: int,
    start_date: str = Query(None, description="Start date (YYYY-MM-DD)"),
    end_date: str = Query(None, description="End date (YYYY-MM-DD)"),
):
    """Get transaction history for an account, optionally filtered by date."""
    query = (
        "SELECT txn_id, account_id, amount, txn_type, created_at "
        "FROM transactions WHERE account_id = %s"
    )
    params: list = [account_id]

    if start_date:
        query += " AND created_at >= %s::date"
        params.append(start_date)
    if end_date:
        query += " AND created_at < %s::date + interval '1 day'"
        params.append(end_date)

    query += " ORDER BY created_at DESC"

    with get_cursor() as cur:
        cur.execute(query, params)
        return cur.fetchall()
