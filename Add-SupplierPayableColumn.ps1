<#
  Add-SupplierPayableColumn.ps1
  -----------------------------------------------------------------------
  ISSUE 11: Suppliers list page missing "Amount Payable" column.

  Client's requirement: on the main Suppliers list (Name, Phone, Total
  Purchases, Last Purchase Date), add a column showing how much is owed
  to each supplier at a glance - without clicking into the detail page.

  WHY NO BACKEND / DB CHANGE IS NEEDED:
  Checked apps/frontend/lib/store.ts - the `suppliers` table is already
  fetched with `select("*")` in loadRawMaterialsModule(), and the
  Supplier type / mapSupplierRow() already include `currentBalance`
  (mapped from the `current_balance` column, the same value the Supplier
  Detail page - Issue 10 - already shows). That means the payable balance
  for every supplier is ALREADY sitting in the frontend store the moment
  the Suppliers list loads. There is no N+1 query problem to solve and no
  new Supabase function/migration needed - this is a pure frontend change:
  add one column to the list table.

  WHAT THIS SCRIPT DOES:
    - Edits apps/frontend/app/(dashboard)/suppliers/page.tsx:
      adds a new "Amount Payable" column to the Suppliers list table,
      using the same direction-aware color coding as the Supplier Detail
      page (red = we owe the supplier, green = zero/credit balance).

  USAGE:
    cd "D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods"
    .\Add-SupplierPayableColumn.ps1

  Idempotent - safe to re-run. Edits only the one file listed above.
#>

[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path
)

$ErrorActionPreference = "Stop"

function Write-Step($msg)  { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)    { Write-Host "    OK: $msg" -ForegroundColor Green }
function Write-Warn2($msg) { Write-Host "    WARNING: $msg" -ForegroundColor Yellow }

function ConvertTo-LF([string]$text) { return $text -replace "`r`n", "`n" }
function ConvertTo-CRLF([string]$text) { return $text -replace "`n", "`r`n" }

function Apply-Edit {
    param([string]$content, [string]$anchor, [string]$replacement, [string]$description)
    $anchorLF = ConvertTo-LF $anchor
    $replacementLF = ConvertTo-LF $replacement
    if ($content.Contains($replacementLF)) {
        Write-Ok "$description - already applied, skipping."
        return @($content, $false)
    }
    $idx = $content.IndexOf($anchorLF)
    if ($idx -lt 0) {
        Write-Warn2 "$description - anchor not found. Paste this file and I will give the exact edit."
        return @($content, $false)
    }
    $newContent = $content.Substring(0, $idx) + $replacementLF + $content.Substring($idx + $anchorLF.Length)
    Write-Ok "$description - wired."
    return @($newContent, $true)
}

function Edit-FileWithSteps {
    param([string]$Path, [array]$Steps)
    if (-not (Test-Path $Path)) { Write-Warn2 "$Path not found - skipping."; return }
    $raw = Get-Content -Path $Path -Raw -Encoding UTF8
    $usesCRLF = $raw -match "`r`n"
    $content = ConvertTo-LF $raw
    $anyChange = $false
    foreach ($step in $Steps) {
        $result = Apply-Edit -content $content -anchor $step.anchor -replacement $step.replacement -description $step.description
        $content = $result[0]
        if ($result[1]) { $anyChange = $true }
    }
    if ($anyChange) {
        $final = if ($usesCRLF) { ConvertTo-CRLF $content } else { $content }
        $backup = "$Path.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item -Path $Path -Destination $backup -Force
        Write-Ok "Backup: $backup"
        Set-Content -Path $Path -Value $final -Encoding UTF8 -NoNewline
        Write-Ok "Saved: $Path"
    }
    else {
        Write-Ok "No changes needed for: $Path"
    }
}

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
$SuppliersPagePath = Join-Path $ProjectRoot "apps\frontend\app\(dashboard)\suppliers\page.tsx"

Write-Ok "Project root: $ProjectRoot"

# -------------------------------------------------------------------------
# 1. Suppliers list page: add "Amount Payable" column
# -------------------------------------------------------------------------
Write-Step "Updating suppliers/page.tsx..."

$SuppliersPageSteps = @(
    @{
        description = "Amount Payable column on Suppliers list"
        anchor = @"
    { accessorKey: "phone", header: "Phone" },
    { accessorKey: "totalPurchases", header: "Total Purchases" },
    { accessorKey: "lastPurchaseDate", header: "Last Purchase Date" },
  ], []);
"@
        replacement = @"
    { accessorKey: "phone", header: "Phone" },
    { accessorKey: "totalPurchases", header: "Total Purchases" },
    { accessorKey: "lastPurchaseDate", header: "Last Purchase Date" },
    {
      accessorKey: "currentBalance",
      header: "Amount Payable",
      cell: ({ row }) => {
        const bal = row.original.currentBalance;
        return (
          <span className={bal > 0 ? "text-red-400" : "text-green-400"}>
            Rs. {Math.abs(bal).toLocaleString()}
          </span>
        );
      },
    },
  ], []);
"@
    }
)

Edit-FileWithSteps -Path $SuppliersPagePath -Steps $SuppliersPageSteps

Write-Step "Done."
Write-Ok "Restart/refresh the frontend dev server (or rebuild) to see the new column."
Write-Ok "No database migration or backend function was needed - current_balance was already being fetched."