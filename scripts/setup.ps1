# ============================================================
# COBOL-DB Banking System - Setup Script (Windows PowerShell)
# ============================================================

Write-Host "============================================"
Write-Host "  COBOL-DB Banking System - Setup"
Write-Host "============================================"
Write-Host ""

# Check prerequisites
$missing = 0

function Check-Command($cmd) {
    $path = Get-Command $cmd -ErrorAction SilentlyContinue
    if ($path) {
        Write-Host "OK: $cmd found at $($path.Source)" -ForegroundColor Green
    } else {
        Write-Host "MISSING: $cmd is not installed." -ForegroundColor Red
        $script:missing = 1
    }
}

Write-Host "Checking prerequisites..."
Check-Command "cobc"
Check-Command "ocesql"
Check-Command "psql"
Check-Command "createdb"

if ($missing -eq 1) {
    Write-Host ""
    Write-Host "Some prerequisites are missing. Please install them and try again." -ForegroundColor Red
    Write-Host "  - GnuCOBOL: https://gnucobol.sourceforge.io/"
    Write-Host "  - ocesql:    https://github.com/ocesql/ocesql"
    Write-Host "  - PostgreSQL: https://www.postgresql.org/download/"
    exit 1
}

Write-Host ""
Write-Host "All prerequisites found."
Write-Host ""

# Database setup
$DB_NAME = "cobol_bank"
Write-Host "Setting up database '$DB_NAME'..."

$dbExists = psql -lqt 2>$null | Select-String -Pattern "\b$DB_NAME\b"
if ($dbExists) {
    Write-Host "Database '$DB_NAME' already exists."
    $confirm = Read-Host "Drop and recreate? (y/N)"
    if ($confirm -eq "y" -or $confirm -eq "Y") {
        dropdb $DB_NAME
        Write-Host "Dropped '$DB_NAME'."
        $dbExists = $null
    } else {
        Write-Host "Skipping database creation."
    }
}

if (-not $dbExists) {
    createdb $DB_NAME
    Write-Host "Created database '$DB_NAME'."
}

Write-Host "Applying schema..."
psql -d $DB_NAME -f sql/schema.sql -q

Write-Host "Loading seed data..."
psql -d $DB_NAME -f sql/seed_data.sql -q

Write-Host ""

# Build
Write-Host "Building COBOL programs..."
if (-not (Test-Path "bin")) {
    New-Item -ItemType Directory -Path "bin" | Out-Null
}

$programs = @("custmgr", "acctmgr", "txnproc", "rptgen")
foreach ($prog in $programs) {
    Write-Host "  Preprocessing src\${prog}.cbl..."
    ocesql "src\${prog}.cbl" "src\${prog}.cob"
    Write-Host "  Compiling src\${prog}.cob..."
    cobc -x -I cpy -l ocesql "src\${prog}.cob" -o "bin\${prog}.exe"
}

Write-Host ""
Write-Host "Setup complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Run programs with:"
Write-Host "  .\bin\custmgr.exe    # Customer Manager"
Write-Host "  .\bin\acctmgr.exe    # Account Manager"
Write-Host "  .\bin\txnproc.exe    # Transaction Processor"
Write-Host "  .\bin\rptgen.exe     # Report Generator"
