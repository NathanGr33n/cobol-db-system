#!/usr/bin/env bash
# ============================================================
# COBOL-DB Banking System - Setup Script (Linux/macOS)
# ============================================================
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo "============================================"
echo "  COBOL-DB Banking System - Setup"
echo "============================================"
echo ""

# Check prerequisites
MISSING=0

check_cmd() {
    if ! command -v "$1" &> /dev/null; then
        echo -e "${RED}MISSING:${NC} $1 is not installed."
        MISSING=1
    else
        echo -e "${GREEN}OK:${NC} $1 found at $(command -v "$1")"
    fi
}

echo "Checking prerequisites..."
check_cmd cobc
check_cmd ocesql
check_cmd psql
check_cmd createdb

if [ "$MISSING" -eq 1 ]; then
    echo ""
    echo -e "${RED}Some prerequisites are missing. Please install them and try again.${NC}"
    echo "  - GnuCOBOL: https://gnucobol.sourceforge.io/"
    echo "  - ocesql:    https://github.com/ocesql/ocesql"
    echo "  - PostgreSQL: https://www.postgresql.org/download/"
    exit 1
fi

echo ""
echo "All prerequisites found."
echo ""

# Database setup
DB_NAME="cobol_bank"
echo "Setting up database '$DB_NAME'..."

if psql -lqt | cut -d \| -f 1 | grep -qw "$DB_NAME"; then
    echo "Database '$DB_NAME' already exists."
    read -p "Drop and recreate? (y/N): " CONFIRM
    if [ "$CONFIRM" = "y" ] || [ "$CONFIRM" = "Y" ]; then
        dropdb "$DB_NAME"
        echo "Dropped '$DB_NAME'."
    else
        echo "Skipping database creation."
    fi
fi

if ! psql -lqt | cut -d \| -f 1 | grep -qw "$DB_NAME"; then
    createdb "$DB_NAME"
    echo "Created database '$DB_NAME'."
fi

echo "Applying schema..."
psql -d "$DB_NAME" -f sql/schema.sql -q

echo "Loading seed data..."
psql -d "$DB_NAME" -f sql/seed_data.sql -q

echo ""

# Build
echo "Building COBOL programs..."
mkdir -p bin

for prog in custmgr acctmgr txnproc rptgen; do
    echo "  Preprocessing src/${prog}.cbl..."
    ocesql "src/${prog}.cbl" "src/${prog}.cob"
    echo "  Compiling src/${prog}.cob..."
    cobc -x -I cpy -l ocesql "src/${prog}.cob" -o "bin/${prog}"
done

echo ""
echo -e "${GREEN}Setup complete!${NC}"
echo ""
echo "Run programs with:"
echo "  ./bin/custmgr    # Customer Manager"
echo "  ./bin/acctmgr    # Account Manager"
echo "  ./bin/txnproc    # Transaction Processor"
echo "  ./bin/rptgen     # Report Generator"
