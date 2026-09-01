<#
  Finish-SupplierLedgerVerification.ps1
  -----------------------------------------------------------------------
  Closes the 3 remaining open items from the supplier-ledger fix before
  it can be marked DONE:

    1. Runs the two verification queries for real, via psql, instead of
       just telling you to paste them into the SQL editor:
         select proname from pg_proc where proname = 'fn_supplier_balance';
         select viewname from pg_views where viewname = 'v_supplier_ledger_orphans';

    2. Runs `select * from v_supplier_ledger_orphans;` and prints the
       actual rows, so you can see the orphan Rs. 150,000 entry (and
       anything else) and decide delete vs backfill with real data in
       front of you - not a blind guess.

    3. Fixes the missing red/green color coding on the supplier detail
       page's Outstanding Balance. apps/frontend/app/(dashboard)/
       suppliers/[id]/page.tsx currently renders it in plain foreground
       color with no positive/negative styling. The customer detail
       page (apps/frontend/app/(dashboard)/customers/[id]/page.tsx)
       already has this exact pattern:
         customer.currentBalance > 0 ? "text-red-400" : "text-green-400"
       with Math.abs() on the displayed number. This script applies the
       same convention to the supplier page (positive = we owe the
       supplier = red; zero/negative = green), so both pages behave
       consistently.

  REQUIRES psql on PATH for steps 1 and 2 (Postgres client tools). If
  it's not installed, this script tells you exactly what's missing and
  what to install, rather than silently skipping and claiming success.

  USAGE
    cd "D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods"
    .\Finish-SupplierLedgerVerification.ps1 -DbPassword "your-db-password"

  Idempotent - safe to re-run. The color-coding edit only fires if the
  old plain-color line is still present.
#>

[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path,
    [Parameter(Mandatory = $true)]
    [string]$DbPassword,
    [string]$ConnectionString = $null
)

$ErrorActionPreference = "Stop"

function Write-Step($msg)  { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)    { Write-Host "    OK: $msg" -ForegroundColor Green }
function Write-Warn2($msg) { Write-Host "    WARNING: $msg" -ForegroundColor Yellow }
function Write-Fail($msg)  { Write-Host "    FAILED: $msg" -ForegroundColor Red }

# -------------------------------------------------------------------------
# 0. Locate project root
# -------------------------------------------------------------------------
Write-Step "Locating project..."

$candidatePaths = @($ProjectRoot, "D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods")
$resolvedRoot = $null
foreach ($p in $candidatePaths) {
    if (Test-Path (Join-Path $p "apps\frontend\lib\store.ts")) { $resolvedRoot = $p; break }
}
if (-not $resolvedRoot) {
    Write-Warn2 "Could not auto-detect the project. Run this script FROM the project root."
    throw "Project root not found."
}
$ProjectRoot = $resolvedRoot
$BackendDir  = Join-Path $ProjectRoot "apps\backend"
$SupplierPageFile = Join-Path $ProjectRoot "apps\frontend\app\(dashboard)\suppliers\[id]\page.tsx"

Write-Ok "Project root: $ProjectRoot"

# -------------------------------------------------------------------------
# 1. Fix the missing red/green color coding on Outstanding Balance
# -------------------------------------------------------------------------
Write-Step "Fixing Outstanding Balance color coding on the supplier detail page..."

if (-not (Test-Path -LiteralPath $SupplierPageFile)) {
    Write-Warn2 "Could not find $SupplierPageFile - skipping. Check the path manually."
}
else {
    $pageContent = Get-Content -LiteralPath $SupplierPageFile -Raw

    $oldLine = '<div className="text-lg font-semibold text-[var(--foreground)] mt-1">Rs. {supplier.currentBalance.toLocaleString()}</div>'
    $newLine = '<div className={`text-lg font-semibold mt-1 ${supplier.currentBalance > 0 ? "text-red-400" : "text-green-400"}`}>Rs. {Math.abs(supplier.currentBalance).toLocaleString()}</div>'

    if ($pageContent.Contains('supplier.currentBalance > 0 ? "text-red-400"')) {
        Write-Ok "Color coding already present on the supplier page - no change needed."
    }
    elseif ($pageContent.Contains($oldLine)) {
        $pageContent = $pageContent.Replace($oldLine, $newLine)
        Set-Content -LiteralPath $SupplierPageFile -Value $pageContent -Encoding UTF8 -NoNewline
        Write-Ok "Added red/green color coding to match the customer detail page convention (positive balance = red = we owe the supplier, zero/negative = green)."
    }
    else {
        Write-Warn2 "Could not find the expected exact Outstanding Balance line to replace - it may have changed since the code export."
        Write-Warn2 "Open $SupplierPageFile manually and apply the same pattern used in customers/[id]/page.tsx:"
        Write-Warn2 '  className={`text-lg font-semibold mt-1 ${supplier.currentBalance > 0 ? "text-red-400" : "text-green-400"}`}'
        Write-Warn2 "  and wrap the displayed number in Math.abs(...)."
    }
}

# -------------------------------------------------------------------------
# 2. Locate the linked Supabase project ref
# -------------------------------------------------------------------------
Write-Step "Locating linked Supabase project..."

$projectRef = $null
foreach ($linkedFile in @(
    (Join-Path $BackendDir "supabase\.temp\linked-project.json"),
    (Join-Path $ProjectRoot "supabase\.temp\linked-project.json")
)) {
    if (Test-Path $linkedFile) {
        try {
            $projectRef = (Get-Content $linkedFile -Raw | ConvertFrom-Json).ref
            if ($projectRef) { break }
        }
        catch {}
    }
}

if (-not $projectRef) {
    Write-Fail "Could not find a linked Supabase project ref (checked apps/backend/supabase/.temp and supabase/.temp). Cannot run DB verification queries."
    Write-Warn2 "Run these manually in the Supabase SQL editor instead:"
    Write-Host ""
    Write-Host "    select proname from pg_proc where proname = 'fn_supplier_balance';" -ForegroundColor White
    Write-Host "    select viewname from pg_views where viewname = 'v_supplier_ledger_orphans';" -ForegroundColor White
    Write-Host "    select * from v_supplier_ledger_orphans;" -ForegroundColor White
    Write-Host ""
    exit 1
}
Write-Ok "Linked project ref: $projectRef"

# -------------------------------------------------------------------------
# 3. Run the 3 verification/audit queries for real via psql
# -------------------------------------------------------------------------
Write-Step "Checking for psql..."

$psqlCli = Get-Command psql -ErrorAction SilentlyContinue
$nodeCli = Get-Command node -ErrorAction SilentlyContinue
$npmCli  = Get-Command npm -ErrorAction SilentlyContinue
$queryMethod = $null

if ($psqlCli) {
    Write-Ok "psql found: $($psqlCli.Source)"
    $queryMethod = "psql"
}
elseif ($nodeCli -and $npmCli) {
    Write-Warn2 "psql not found - falling back to Node.js + the 'pg' npm package (no extra install needed, node/npm are already on this machine)."
    $queryMethod = "node"
}
else {
    Write-Fail "Neither psql nor Node.js/npm are available. Cannot run the verification queries automatically."
    Write-Warn2 "Run these manually in the Supabase SQL editor instead:"
    Write-Host ""
    Write-Host "    select proname from pg_proc where proname = 'fn_supplier_balance';" -ForegroundColor White
    Write-Host "    select viewname from pg_views where viewname = 'v_supplier_ledger_orphans';" -ForegroundColor White
    Write-Host "    select * from v_supplier_ledger_orphans;" -ForegroundColor White
    Write-Host ""
    exit 1
}

if ($ConnectionString) {
    $connStr = $ConnectionString
    Write-Ok "Using the connection string you provided directly."
}
else {
    $connStr = "postgresql://postgres:$DbPassword@db.$projectRef.supabase.co:5432/postgres"

    # Preflight: the direct db.<ref>.supabase.co host is IPv6-only on many
    # Supabase projects now, which fails DNS resolution (ENOTFOUND) on a
    # lot of regular networks/ISPs. Check DNS BEFORE running the real
    # queries, so a connectivity problem never gets misreported as
    # "function/view not found".
    $dnsOk = $false
    try {
        [void][System.Net.Dns]::GetHostEntry("db.$projectRef.supabase.co")
        $dnsOk = $true
    }
    catch {
        $dnsOk = $false
    }

    if (-not $dnsOk) {
        Write-Fail "Cannot resolve db.$projectRef.supabase.co (DNS lookup failed). This is a CONNECTIVITY problem, not proof anything is missing in the DB - do not treat any 'not found' result below as real until this is fixed."
        Write-Warn2 "This project's direct DB host is very likely IPv6-only now (a known Supabase change), which many networks can't reach."
        Write-Warn2 "Fix: open Supabase Dashboard -> Project Settings -> Database -> 'Connection string' -> select 'Session pooler' (or 'Transaction pooler'), copy that full connection string, then re-run this script as:"
        Write-Host ""
        Write-Host "    .\Finish-SupplierLedgerVerification.ps1 -DbPassword `"...`" -ConnectionString `"paste-the-pooler-connection-string-here`"" -ForegroundColor White
        Write-Host ""
        exit 1
    }
}

# One-time setup for the Node.js fallback: install the 'pg' package into a
# scratch folder (not the project) so this never touches the app's own
# package.json/node_modules.
$NodeScratchDir = $null
if ($queryMethod -eq "node") {
    $NodeScratchDir = Join-Path $env:TEMP "supplier-ledger-pg-check"

    # Wipe and recreate fresh every time - a stale/contaminated scratch dir
    # (e.g. from an unrelated prior npm run reusing this path, or npm
    # hoisting into some parent node_modules) is exactly what caused the
    # previous "up to date, nothing installed" false result.
    if (Test-Path $NodeScratchDir) {
        Remove-Item -Path $NodeScratchDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $NodeScratchDir | Out-Null

    # A minimal package.json anchors this as its OWN npm project root, so
    # npm cannot hoist the install up into some unrelated parent folder's
    # node_modules.
    Set-Content -Path (Join-Path $NodeScratchDir "package.json") -Value '{"name":"supplier-ledger-pg-check","private":true}' -Encoding UTF8

    Write-Step "Installing the 'pg' package into a fresh scratch folder (not your project)..."
    Push-Location $NodeScratchDir
    try {
        $npmOutput = cmd.exe /c "npm install pg --no-save 2>&1"
        $npmOutput = $npmOutput | Out-String
        Write-Host $npmOutput

        # Authoritative check: ask Node itself, from inside this folder,
        # whether it can actually resolve 'pg' - not a guess based on
        # folder existence.
        $resolveCheck = cmd.exe /c "node -e ""console.log(require.resolve('pg'))"" 2>&1" | Out-String
    }
    finally {
        Pop-Location
    }

    if ($resolveCheck -notmatch 'pg') {
        Write-Fail "Could not install/resolve the 'pg' package. npm output above. node's own resolve check said:"
        Write-Host $resolveCheck
        Write-Warn2 "Directory listing of $NodeScratchDir for diagnosis:"
        Get-ChildItem -Path $NodeScratchDir -Recurse -Depth 1 -ErrorAction SilentlyContinue | Select-Object FullName | Format-Table -AutoSize | Out-String | Write-Host
        exit 1
    }
    Write-Ok "pg package confirmed installed and resolvable."

    $queryScript = @'
const { Client } = require("pg");

async function main() {
  const client = new Client({
    connectionString: process.env.PG_CONN,
    ssl: { rejectUnauthorized: false },
  });
  await client.connect();
  try {
    const res = await client.query(process.env.PG_SQL);
    if (res.rows.length === 0) {
      console.log("(0 rows)");
    } else {
      console.table(res.rows);
    }
  } finally {
    await client.end();
  }
}

main().catch((err) => {
  console.error("QUERY_ERROR: " + err.message);
  process.exit(1);
});
'@
    Set-Content -Path (Join-Path $NodeScratchDir "query.js") -Value $queryScript -Encoding UTF8
}

function Invoke-PgQuery($sql, $label) {
    Write-Step $label
    Write-Host "    Running: $sql" -ForegroundColor Gray

    if ($queryMethod -eq "psql") {
        $env:PGPASSWORD = $DbPassword
        try {
            $result = & psql $connStr -c $sql 2>&1 | Out-String
        }
        finally {
            Remove-Item Env:\PGPASSWORD -ErrorAction SilentlyContinue
        }
    }
    else {
        Push-Location $NodeScratchDir
        $env:PG_CONN = $connStr
        $env:PG_SQL  = $sql
        try {
            $result = cmd.exe /c "node query.js 2>&1" | Out-String
        }
        finally {
            Remove-Item Env:\PG_CONN -ErrorAction SilentlyContinue
            Remove-Item Env:\PG_SQL -ErrorAction SilentlyContinue
            Pop-Location
        }
    }

    Write-Host $result
    return $result
}

$fnResult   = Invoke-PgQuery "select proname from pg_proc where proname = 'fn_supplier_balance';" "Checking fn_supplier_balance exists..."
$viewResult = Invoke-PgQuery "select viewname from pg_views where viewname = 'v_supplier_ledger_orphans';" "Checking v_supplier_ledger_orphans exists..."

$fnHadError   = $fnResult -match 'QUERY_ERROR'
$viewHadError = $viewResult -match 'QUERY_ERROR'
$fnExists   = (-not $fnHadError) -and ($fnResult -match 'fn_supplier_balance')
$viewExists = (-not $viewHadError) -and ($viewResult -match 'v_supplier_ledger_orphans')

if ($fnHadError) { Write-Fail "Could not check fn_supplier_balance - query errored (see output above), NOT confirmed missing." }
elseif ($fnExists) { Write-Ok "fn_supplier_balance confirmed to exist in the live DB." }
else { Write-Fail "fn_supplier_balance was NOT found in the live DB." }

if ($viewHadError) { Write-Fail "Could not check v_supplier_ledger_orphans - query errored (see output above), NOT confirmed missing." }
elseif ($viewExists) { Write-Ok "v_supplier_ledger_orphans confirmed to exist in the live DB." }
else { Write-Fail "v_supplier_ledger_orphans was NOT found in the live DB." }

if ($viewExists) {
    Invoke-PgQuery "select * from v_supplier_ledger_orphans;" "Fetching orphan ledger entries (this is your Rs. 150,000 audit data)..." | Out-Null
}
elseif ($viewHadError) {
    Write-Warn2 "Skipping orphan-entry query - connection/query error above needs to be fixed first, this is not a real 'view missing' situation."
}
else {
    Write-Warn2 "Skipping orphan-entry query since the view doesn't exist - the earlier migration verification needs to be revisited first."
}

# -------------------------------------------------------------------------
# 4. Summary
# -------------------------------------------------------------------------
Write-Step "Summary"
if ($fnExists -and $viewExists) {
    Write-Ok "Both fn_supplier_balance and v_supplier_ledger_orphans are confirmed live. Review the orphan rows printed above to decide delete vs backfill."
}
elseif ($fnHadError -or $viewHadError) {
    Write-Fail "Could not reach the database to verify - this is a CONNECTIVITY problem, not confirmation that anything is missing. Fix the connection (see warning above about the pooler connection string) and re-run before concluding anything."
}
else {
    Write-Fail "One or both DB objects are genuinely missing (connection worked, they just weren't found) - do NOT mark Issue 10 as done yet. Re-check the migration push."
}