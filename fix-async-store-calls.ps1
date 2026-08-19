# =============================================================================
# GhaniFoods - Fix "await" issues after store.ts actions became async
# Patches the known failing line in packaging/page.tsx, then scans the whole
# frontend for other likely un-awaited calls to the same store actions.
# =============================================================================

$ErrorActionPreference = "Stop"

function Write-Step($msg) { Write-Host "`n=== $msg ===" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "  $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "  $msg" -ForegroundColor Yellow }
function Write-Err($msg)  { Write-Host "  $msg" -ForegroundColor Red }

# -----------------------------------------------------------------------
# 0. Auto-locate apps\frontend (use FULL paths everywhere from here on -
#    relative paths + [System.IO.File] do not reliably follow
#    Set-Location, especially with parenthesis folders like (dashboard))
# -----------------------------------------------------------------------
Write-Step "Locating apps\frontend"

$cwd = (Get-Location).Path
$frontendDir = $null

if (Test-Path (Join-Path $cwd "app\(dashboard)")) {
    $frontendDir = $cwd
} elseif (Test-Path (Join-Path $cwd "apps\frontend\app\(dashboard)")) {
    $frontendDir = Join-Path $cwd "apps\frontend"
} else {
    $candidate = Get-ChildItem -Path $cwd -Directory -Recurse -Depth 3 -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match "apps\\frontend$" } | Select-Object -First 1
    if ($candidate) { $frontendDir = $candidate.FullName }
}

if (-not $frontendDir) {
    Write-Err "Could not find apps\frontend under $cwd"
    exit 1
}

$frontendDir = (Resolve-Path $frontendDir).Path
Write-Ok "Using frontend dir: $frontendDir"

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

function Backup-File($fullPath) {
    $backup = "$fullPath.bak-$timestamp"
    Copy-Item -LiteralPath $fullPath -Destination $backup -Force
    Write-Host "    Backed up -> $backup" -ForegroundColor DarkGray
}

# -----------------------------------------------------------------------
# 1. Fix the exact known failing line in packaging/page.tsx (full path)
# -----------------------------------------------------------------------
Write-Step "Fixing app\(dashboard)\packaging\page.tsx"

$packagingPage = Join-Path $frontendDir "app\(dashboard)\packaging\page.tsx"

if (Test-Path -LiteralPath $packagingPage) {
    $content = Get-Content -LiteralPath $packagingPage -Raw
    $oldLine = 'const result = kind === "wrapper" ? produceWrapper(item.id, values.quantityProduced) : produceBox(item.id, values.quantityProduced);'
    $newLine = 'const result = kind === "wrapper" ? await produceWrapper(item.id, values.quantityProduced) : await produceBox(item.id, values.quantityProduced);'

    if ($content -match [regex]::Escape($oldLine)) {
        Backup-File $packagingPage
        $content = $content.Replace($oldLine, $newLine)
        [System.IO.File]::WriteAllText($packagingPage, $content, [System.Text.Encoding]::UTF8)
        Write-Ok "Patched: added await to produceWrapper/produceBox call"
    } else {
        Write-Warn "Exact line not found (may already be fixed, or wording differs slightly)."
        Write-Warn "Will still be caught by the scan below if unfixed."
    }
} else {
    Write-Warn "$packagingPage not found - skipping targeted fix."
}

# -----------------------------------------------------------------------
# 2. Scan the whole frontend for other likely un-awaited calls to the
#    now-async store actions (converted in the store.ts rewrite).
# -----------------------------------------------------------------------
Write-Step "Scanning for other un-awaited async store calls"

$asyncActions = @(
    "addSupplier", "addRawMaterial", "createPurchaseReceipt", "loadRawMaterialsModule",
    "loadPackagingModule", "addWrapper", "produceWrapper", "addBox", "produceBox",
    "loadCartonConfigurations", "addCartonConfiguration", "updateCartonConfiguration",
    "loadProductionBatches", "createBatch", "allocateOverhead",
    "loadFinishedCartons", "createPackingRun",
    "loadCustomersModule", "addCustomer", "recordLedgerEntry", "createInvoice",
    "loadSettings", "updateSettings", "loadAll"
)

$pattern = "(?<!await\s)\b(" + ($asyncActions -join "|") + ")\s*\("
$tsxFiles = Get-ChildItem -LiteralPath (Join-Path $frontendDir "app") -Filter "*.tsx" -Recurse -ErrorAction SilentlyContinue
$tsxFiles += Get-ChildItem -LiteralPath (Join-Path $frontendDir "components") -Filter "*.tsx" -Recurse -ErrorAction SilentlyContinue
$tsxFiles = $tsxFiles | Where-Object { $_.Name -notmatch "\.bak" }

$hits = @()
foreach ($file in $tsxFiles) {
    $lines = Get-Content -LiteralPath $file.FullName
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        if ($line -match "^\s*(export\s+)?(const|function)\s") { continue }
        if ($line -match "^\s*import\b") { continue }
        if ($line -match "useStore\s*\(") { continue }

        if ([regex]::IsMatch($line, $pattern)) {
            $hits += [PSCustomObject]@{
                File = $file.FullName.Replace($frontendDir + "\", "")
                Line = $i + 1
                Text = $line.Trim()
            }
        }
    }
}

if ($hits.Count -eq 0) {
    Write-Ok "No other un-awaited async store calls found."
} else {
    Write-Warn "Found $($hits.Count) line(s) that may need 'await' added - review each:"
    $hits | ForEach-Object {
        Write-Host "  $($_.File):$($_.Line)" -ForegroundColor Red
        Write-Host "    $($_.Text)" -ForegroundColor DarkGray
    }
    Write-Warn "`nNote: this is a best-effort text scan, not a TypeScript AST check."
    Write-Warn "Some hits may be false positives (e.g. unrelated local functions with the same name)."
    Write-Warn "Fix each by adding 'await' before the call, and mark the enclosing function 'async' if it isn't already."
}

Write-Host "`n=============================================================================" -ForegroundColor Cyan
Write-Host "DONE. Next: commit and push, then re-check the Vercel build log." -ForegroundColor Cyan
Write-Host "If the scan above found more hits, fix those first or paste them back for a patch." -ForegroundColor Cyan
Write-Host "=============================================================================" -ForegroundColor Cyan