#!/usr/bin/env bash
# ============================================================
# COBOL-DB-SYSTEM Test Runner (Bash)
# Runs the full test lifecycle: setup -> compile -> test -> teardown
# Exit code 0 = all tests passed, 1 = failures detected
# ============================================================

set -euo pipefail

DB_NAME="${DB_NAME:-coboldb}"
DB_USER="${DB_USER:-coboluser}"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BIN_DIR="$PROJECT_ROOT/bin"
TEST_DIR="$PROJECT_ROOT/tests"
SRC_DIR="$PROJECT_ROOT/src"
PSQL_FLAGS="-h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME"

echo "================================================"
echo " COBOL-DB-SYSTEM Test Runner"
echo "================================================"
echo ""

# Ensure bin directory exists
mkdir -p "$BIN_DIR"

# Step 1: Setup test database
echo "[1/4] Setting up test database..."
if psql $PSQL_FLAGS -f "$TEST_DIR/setup-testdb.sql" > /dev/null 2>&1; then
    echo "      OK"
else
    echo "      FAILED: Could not set up test database."
    exit 1
fi

# Step 2: Compile test program
echo "[2/4] Compiling test-banking.cbl..."
if cobc -x -I "$SRC_DIR" -o "$BIN_DIR/test-banking" "$TEST_DIR/test-banking.cbl"; then
    echo "      OK"
else
    echo "      FAILED: Compilation error."
    exit 1
fi

# Step 3: Run tests
echo "[3/4] Running test suite..."
echo ""

TEST_OUTPUT=$("$BIN_DIR/test-banking" 2>&1) || true
echo "$TEST_OUTPUT"

echo ""

# Step 4: Teardown
echo "[4/4] Cleaning up test database..."
if psql $PSQL_FLAGS -f "$TEST_DIR/teardown-testdb.sql" > /dev/null 2>&1; then
    echo "      OK"
else
    echo "      WARNING: Teardown failed."
fi

# Check results
if echo "$TEST_OUTPUT" | grep -q "ALL TESTS PASSED"; then
    echo ""
    echo "Result: ALL TESTS PASSED"
    exit 0
else
    echo ""
    echo "Result: FAILURES DETECTED"
    exit 1
fi
