# ============================================================
# COBOL-DB-SYSTEM Test Runner (PowerShell)
# Runs the full test lifecycle: setup -> compile -> test -> teardown
# Exit code 0 = all tests passed, 1 = failures detected
# ============================================================

param(
    [string]$DbName   = "coboldb",
    [string]$DbUser   = "coboluser",
    [string]$DbHost   = "localhost",
    [string]$DbPort   = "5432"
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$BinDir      = Join-Path $ProjectRoot "bin"
$TestDir     = Join-Path $ProjectRoot "tests"
$SrcDir      = Join-Path $ProjectRoot "src"
$PsqlFlags   = "-h", $DbHost, "-p", $DbPort, "-U", $DbUser, "-d", $DbName

Write-Host "================================================"
Write-Host " COBOL-DB-SYSTEM Test Runner"
Write-Host "================================================"
Write-Host ""

# Ensure bin directory exists
if (-not (Test-Path $BinDir)) {
    New-Item -ItemType Directory -Path $BinDir | Out-Null
}

# Step 1: Setup test database
Write-Host "[1/4] Setting up test database..."
try {
    & psql @PsqlFlags -f (Join-Path $TestDir "setup-testdb.sql") 2>&1 | Out-Null
    Write-Host "      OK"
} catch {
    Write-Host "      FAILED: Could not set up test database."
    Write-Host "      $_"
    exit 1
}

# Step 2: Compile test program
Write-Host "[2/4] Compiling test-banking.cbl..."
try {
    $TestBinary = Join-Path $BinDir "test-banking"
    & cobc -x -I $SrcDir -o $TestBinary (Join-Path $TestDir "test-banking.cbl") 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Compilation failed" }
    Write-Host "      OK"
} catch {
    Write-Host "      FAILED: Compilation error."
    Write-Host "      $_"
    exit 1
}

# Step 3: Run tests
Write-Host "[3/4] Running test suite..."
Write-Host ""

$TestOutput = & $TestBinary 2>&1
$TestOutput | ForEach-Object { Write-Host $_ }

Write-Host ""

# Step 4: Teardown
Write-Host "[4/4] Cleaning up test database..."
try {
    & psql @PsqlFlags -f (Join-Path $TestDir "teardown-testdb.sql") 2>&1 | Out-Null
    Write-Host "      OK"
} catch {
    Write-Host "      WARNING: Teardown failed."
}

# Check results
$Passed = ($TestOutput | Select-String "ALL TESTS PASSED").Count -gt 0
if ($Passed) {
    Write-Host ""
    Write-Host "Result: ALL TESTS PASSED"
    exit 0
} else {
    Write-Host ""
    Write-Host "Result: FAILURES DETECTED"
    exit 1
}
