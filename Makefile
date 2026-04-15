# ============================================================
# COBOL-DB-SYSTEM Makefile
# Requires: GnuCOBOL (cobc), PostgreSQL (psql)
# ============================================================

# Compiler
COBC       = cobc
COBFLAGS   = -x -I src

# Directories
SRC_DIR    = src
BIN_DIR    = bin
SQL_DIR    = sql
TEST_DIR   = tests
CONFIG_DIR = config

# Environment (override with: make ENV=test)
ENV        = dev
-include $(CONFIG_DIR)/$(ENV).env
export

# Programs
PROGRAMS   = custmgr acctmgr txnproc rptgen xfermgr intcalc
SOURCES    = $(addprefix $(SRC_DIR)/, $(addsuffix .cbl, $(PROGRAMS)))
BINARIES   = $(addprefix $(BIN_DIR)/, $(PROGRAMS))

# Database
PSQL       = psql
PSQL_FLAGS = -h $(DB_HOST) -p $(DB_PORT) -U $(DB_USER) -d $(DB_NAME)

# ============================================================
# TARGETS
# ============================================================

.PHONY: all clean db-setup db-seed db-reset db-test-setup db-test-teardown test help

all: $(BIN_DIR) $(BINARIES)
	@echo Build complete.

$(BIN_DIR):
	@mkdir -p $(BIN_DIR)

# Individual program targets
$(BIN_DIR)/custmgr: $(SRC_DIR)/custmgr.cbl $(SRC_DIR)/dbconfig.cpy | $(BIN_DIR)
	$(COBC) $(COBFLAGS) -o $@ $<

$(BIN_DIR)/acctmgr: $(SRC_DIR)/acctmgr.cbl $(SRC_DIR)/dbconfig.cpy | $(BIN_DIR)
	$(COBC) $(COBFLAGS) -o $@ $<

$(BIN_DIR)/txnproc: $(SRC_DIR)/txnproc.cbl $(SRC_DIR)/dbconfig.cpy | $(BIN_DIR)
	$(COBC) $(COBFLAGS) -o $@ $<

$(BIN_DIR)/rptgen: $(SRC_DIR)/rptgen.cbl $(SRC_DIR)/dbconfig.cpy | $(BIN_DIR)
	$(COBC) $(COBFLAGS) -o $@ $<

$(BIN_DIR)/xfermgr: $(SRC_DIR)/xfermgr.cbl $(SRC_DIR)/dbconfig.cpy | $(BIN_DIR)
	$(COBC) $(COBFLAGS) -o $@ $<

$(BIN_DIR)/intcalc: $(SRC_DIR)/intcalc.cbl $(SRC_DIR)/dbconfig.cpy | $(BIN_DIR)
	$(COBC) $(COBFLAGS) -o $@ $<

# Database targets
db-setup:
	$(PSQL) $(PSQL_FLAGS) -f $(SQL_DIR)/schema.sql

db-seed:
	$(PSQL) $(PSQL_FLAGS) -f $(SQL_DIR)/seed_data.sql

db-reset: db-setup db-seed

db-test-setup:
	$(PSQL) $(PSQL_FLAGS) -f $(TEST_DIR)/setup-testdb.sql

db-test-teardown:
	$(PSQL) $(PSQL_FLAGS) -f $(TEST_DIR)/teardown-testdb.sql

# Test target
test: $(BIN_DIR) db-test-setup
	$(COBC) $(COBFLAGS) -o $(BIN_DIR)/test-banking $(TEST_DIR)/test-banking.cbl
	$(BIN_DIR)/test-banking
	@$(MAKE) db-test-teardown

clean:
	@rm -rf $(BIN_DIR)
	@echo Clean complete.

help:
	@echo "Usage: make [target] [ENV=dev|test]"
	@echo ""
	@echo "Build targets:"
	@echo "  all              Build all COBOL programs (default)"
	@echo "  clean            Remove compiled binaries"
	@echo ""
	@echo "Database targets:"
	@echo "  db-setup         Run schema.sql to create tables"
	@echo "  db-seed          Run seed_data.sql to populate tables"
	@echo "  db-reset         Drop and recreate with seed data"
	@echo "  db-test-setup    Set up test database state"
	@echo "  db-test-teardown Clean up test database state"
	@echo ""
	@echo "Test targets:"
	@echo "  test             Run test suite (setup -> test -> teardown)"
	@echo ""
	@echo "Options:"
	@echo "  ENV=dev          Use development config (default)"
	@echo "  ENV=test         Use test config"
