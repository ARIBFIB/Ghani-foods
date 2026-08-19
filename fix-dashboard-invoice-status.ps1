<#
  fix-dashboard-invoice-status.ps1
  ------------------------------------------------------------------
  Fixes Vercel build error:
    Type error: Property 'status' does not exist on type 'Invoice'.
    at apps/frontend/app/(dashboard)/page.tsx:120

  Cause: Per spec v1.2/v2.2, Invoice no longer carries a
  Paid/Unpaid/Partial status. The frontend Invoice type was updated
  elsewhere, but this dashboard page still has a leftover
  StatusBadge component + <StatusBadge status={inv.status} /> cell
  that were never removed.

  This script uses EXACT literal string matches taken directly from
  your real file (not fragile regex), so it cannot partially match
  or corrupt the JSX like the previous script did.

  Run from:
  D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods
#>

$ErrorActionPreference = "Stop"

$ProjectRoot = Get-Location
$File = Join-Path $ProjectRoot "apps\frontend\app\(dashboard)\page.tsx"

if (-not (Test-Path $File)) {
    Write-Host ""
    Write-Host "ERROR: Dashboard page not found:" -ForegroundColor Red
    Write-Host $File -ForegroundColor Red
    Write-Host ""
    exit 1
}

function Write-Utf8NoBom($path, $content) {
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($path, $content, $enc)
}

# Backup first
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backup = "$File.bak-$stamp"
Copy-Item -Path $File -Destination $backup -Force
Write-Host ""
Write-Host "=== Fixing Dashboard Invoice Status ===" -ForegroundColor Cyan
Write-Host "File:   $File" -ForegroundColor Gray
Write-Host "Backup: $backup" -ForegroundColor Gray
Write-Host ""

$content = [System.IO.File]::ReadAllText($File)
$original = $content

# ------------------------------------------------------------
# 1. Remove the whole StatusBadge function (EXACT literal text,
#    taken verbatim from the real file - no regex guessing).
# ------------------------------------------------------------
$statusBadgeFunction = @'
function StatusBadge({ status }: { status: "unpaid" | "partial" | "paid" }) {
  const styles: Record<string, string> = {
    paid: "bg-green-950 text-green-400 border border-green-900",
    partial: "bg-amber-950 text-amber-400 border border-amber-900",
    unpaid: "bg-red-950 text-red-400 border border-red-900",
  };
  return (
    <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ${styles[status]}`}>
      {status[0].toUpperCase() + status.slice(1)}
    </span>
  );
}

'@

# Normalize CRLF so the literal block matches regardless of line-ending
# differences between how this script stores it and the file on disk.
$normalizedContent = $content -replace "`r`n", "`n"
$normalizedBlock = $statusBadgeFunction -replace "`r`n", "`n"
$normalizedBlock = $normalizedBlock.TrimEnd("`n") + "`n`n"

if ($normalizedContent.Contains($normalizedBlock)) {
    $normalizedContent = $normalizedContent.Replace($normalizedBlock, "")
    Write-Host "  [OK] Removed obsolete StatusBadge function." -ForegroundColor Green
}
else {
    Write-Host "  [SKIP] StatusBadge function block not found verbatim (may already be removed, or formatting differs)." -ForegroundColor Yellow
}

# ------------------------------------------------------------
# 2. Remove the table cell that renders <StatusBadge status={inv.status} />
# ------------------------------------------------------------
$statusCellLine = '                  <td className="px-4 py-3"><StatusBadge status={inv.status} /></td>' + "`n"

if ($normalizedContent.Contains($statusCellLine)) {
    $normalizedContent = $normalizedContent.Replace($statusCellLine, "")
    Write-Host "  [OK] Removed <StatusBadge status={inv.status} /> table cell." -ForegroundColor Green
}
else {
    Write-Host "  [SKIP] StatusBadge table cell not found verbatim." -ForegroundColor Yellow
}

# Convert back to CRLF to match original file convention
$content = $normalizedContent -replace "`n", "`r`n"

# ------------------------------------------------------------
# 3. Safety check - fail loudly instead of writing a broken file
# ------------------------------------------------------------
if ($content -match 'inv\.status') {
    Write-Host ""
    Write-Host "ERROR: 'inv.status' is still present after the fix attempt." -ForegroundColor Red
    Write-Host "No changes were written. Your original file is untouched." -ForegroundColor Red
    Write-Host "Please share the current file content so the exact block can be matched." -ForegroundColor Red
    exit 1
}

if ($content -match 'StatusBadge') {
    Write-Host ""
    Write-Host "ERROR: 'StatusBadge' reference still present after the fix attempt." -ForegroundColor Red
    Write-Host "No changes were written. Your original file is untouched." -ForegroundColor Red
    exit 1
}

if ($content -eq $original) {
    Write-Host ""
    Write-Host "Nothing changed - the file may already be fixed, or its content differs from what this script expects." -ForegroundColor Yellow
    Write-Host "Aborting without writing (backup can be deleted manually)." -ForegroundColor Yellow
    exit 0
}

# ------------------------------------------------------------
# 4. Write file
# ------------------------------------------------------------
Write-Utf8NoBom $File $content

Write-Host ""
Write-Host "=== Fix Applied Successfully ===" -ForegroundColor Cyan
Write-Host "Updated: apps\frontend\app\(dashboard)\page.tsx" -ForegroundColor Green
Write-Host ""
Write-Host "Next step:" -ForegroundColor Cyan
Write-Host "  cd apps\frontend"
Write-Host "  npm run build"
Write-Host ""
Write-Host "If the build passes, commit and push to GitHub for Vercel deployment." -ForegroundColor Yellow