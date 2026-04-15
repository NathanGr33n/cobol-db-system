"""Pydantic models for the COBOL-DB-SYSTEM REST API."""

from datetime import date, datetime
from decimal import Decimal
from typing import Optional

from pydantic import BaseModel, Field


# ---------- Customers ----------

class CustomerCreate(BaseModel):
    first_name: str = Field(..., max_length=50)
    last_name: str = Field(..., max_length=50)
    email: str = Field(..., max_length=100)


class CustomerResponse(BaseModel):
    customer_id: int
    first_name: str
    last_name: str
    email: str
    created_at: date

    class Config:
        from_attributes = True


# ---------- Accounts ----------

class AccountResponse(BaseModel):
    account_id: int
    customer_id: int
    balance: Decimal
    account_type: str
    status: str
    interest_rate: Decimal

    class Config:
        from_attributes = True


class BalanceResponse(BaseModel):
    account_id: int
    balance: Decimal
    status: str


# ---------- Transactions ----------

class DepositRequest(BaseModel):
    account_id: int
    amount: Decimal = Field(..., gt=0)


class WithdrawRequest(BaseModel):
    account_id: int
    amount: Decimal = Field(..., gt=0)


class TransferRequest(BaseModel):
    source_account_id: int
    target_account_id: int
    amount: Decimal = Field(..., gt=0)


class TransactionResponse(BaseModel):
    txn_id: int
    account_id: int
    amount: Decimal
    txn_type: str
    created_at: datetime

    class Config:
        from_attributes = True


class TransactionResult(BaseModel):
    success: bool
    message: str
    new_balance: Optional[Decimal] = None


# ---------- Reports ----------

class AccountSummaryRow(BaseModel):
    account_id: int
    customer_id: int
    first_name: str
    last_name: str
    balance: Decimal
    account_type: str
    status: str
