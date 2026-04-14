# ============================================================
# COBOL-DB Banking System - Makefile
# ============================================================

DB_NAME    = cobol_bank
DB_USER    = $(USER)
SRC_DIR    = src
CPY_DIR    = cpy
BIN_DIR    = bin
SQL_DIR    = sql

PROGRAMS   = custmgr acctmgr txnproc rptgen
SOURCES    = $(addprefix $(SRC_DIR)/, $(addsuffix .cbl, $(PROGRAMS)))
COBFILES   = $(addprefix $(SRC_DIR)/, $(addsuffix .cob, $(PROGRAMS)))
BINARIES   = $(addprefix $(BIN_DIR)/, $(PROGRAMS))

OCESQL     = ocesql
COBC       = cobc
COBC_FLAGS = -x -I $(CPY_DIR)
PSQL       = psql

.PHONY: all build preprocess clean db-setup db-reset db-seed help

# ------------------------------------------------------------
# Default target
# ------------------------------------------------------------
all: build

help:
	@echo "Available targets:"
	@echo "  make build      - Preprocess and compile all COBOL programs"
	@echo "  make preprocess - Run ocesql on all .cbl files"
	@echo "  make clean      - Remove compiled binaries and intermediates"
	@echo "  make db-setup   - Create database, apply schema and seed data"
	@echo "  make db-reset   - Drop and recreate database from scratch"
	@echo "  make db-seed    - Insert seed data only"
	@echo "  make all        - Build all programs (default)"

# ------------------------------------------------------------
# Build targets
# ------------------------------------------------------------
build: preprocess $(BINARIES)

preprocess: $(COBFILES)

$(SRC_DIR)/%.cob: $(SRC_DIR)/%.cbl
	$(OCESQL) $< $@

$(BIN_DIR)/%: $(SRC_DIR)/%.cob | $(BIN_DIR)
	$(COBC) $(COBC_FLAGS) -l ocesql $< -o $@

$(BIN_DIR):
	mkdir -p $(BIN_DIR)

# ------------------------------------------------------------
# Database targets
# ------------------------------------------------------------
db-setup:
	createdb $(DB_NAME) 2>/dev/null || true
	$(PSQL) -d $(DB_NAME) -f $(SQL_DIR)/schema.sql
	$(PSQL) -d $(DB_NAME) -f $(SQL_DIR)/seed_data.sql

db-seed:
	$(PSQL) -d $(DB_NAME) -f $(SQL_DIR)/seed_data.sql

db-reset:
	dropdb --if-exists $(DB_NAME)
	$(MAKE) db-setup

# ------------------------------------------------------------
# Cleanup
# ------------------------------------------------------------
clean:
	rm -f $(SRC_DIR)/*.cob
	rm -rf $(BIN_DIR)
