<#
  fix-logout-and-invoice-bugs.ps1
  ---------------------------------
  Run this from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods

  Fixes:
   1) Logout button was clearing a fake "ghanifoods-auth" cookie instead of
      calling supabase.auth.signOut() -> real session stayed alive.
   2) invoices/new/page.tsx was calling the async createInvoice() without
      "await", so the invoice number shown in the toast was a Promise object.

  What it does:
   - Backs up the two affected files with a timestamp suffix (like the
     .bak files already in this repo).
   - Applies the fix via exact text replacement.
   - Verifies the replacement actually happened before declaring success.

  Safe to re-run: if a file is already fixed, the script just reports that
  and does nothing.
#>

$ErrorActionPreference = "Stop"

$root = Get-Location
Write-Host "Running in: $root" -ForegroundColor Cyan

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"

# ---------------------------------------------------------------------
# File 1: topbar.tsx - fix logout
# ---------------------------------------------------------------------
$topbarPath = Join-Path $root "apps\frontend\components\ui\topbar.tsx"

if (-not (Test-Path $topbarPath)) {
    Write-Host "ERROR: Could not find $topbarPath" -ForegroundColor Red
    Write-Host "Make sure you're running this from the GhaniFoods repo root." -ForegroundColor Red
    exit 1
}

$topbarContent = Get-Content -Raw -LiteralPath $topbarPath

$oldImport = 'import { useNavigationLoading } from "@/lib/navigation-loading-context";'
$newImport = 'import { useNavigationLoading } from "@/lib/navigation-loading-context";' + "`r`n" + 'import { createClient } from "@/lib/supabase/client";'

$oldLogout = @'
  const handleLogout = () => {
    setOpen(false);
    document.cookie = "ghanifoods-auth=; path=/; max-age=0";
    navigate("/login");
  };
'@

$newLogout = @'
  const handleLogout = async () => {
    setOpen(false);
    const supabase = createClient();
    await supabase.auth.signOut();
    navigate("/login");
  };
'@

if ($topbarContent -match [regex]::Escape('import { createClient } from "@/lib/supabase/client";') -and
    $topbarContent -match [regex]::Escape('await supabase.auth.signOut()')) {
    Write-Host "topbar.tsx already fixed - skipping." -ForegroundColor Yellow
}
elseif ($topbarContent -notmatch [regex]::Escape($oldLogout.Trim())) {
    Write-Host "ERROR: Could not find the expected handleLogout block in topbar.tsx." -ForegroundColor Red
    Write-Host "The file may have already been edited manually. Please check it by hand." -ForegroundColor Red
    exit 1
}
else {
    Copy-Item -LiteralPath $topbarPath -Destination "$topbarPath.bak-$stamp"
    Write-Host "Backed up topbar.tsx -> topbar.tsx.bak-$stamp"

    $fixed = $topbarContent.Replace($oldImport, $newImport)
    $fixed = $fixed.Replace($oldLogout.Trim(), $newLogout.Trim())

    Set-Content -LiteralPath $topbarPath -Value $fixed -NoNewline
    Write-Host "Fixed logout in topbar.tsx" -ForegroundColor Green
}

# ---------------------------------------------------------------------
# File 2: invoices/new/page.tsx - fix missing await
# ---------------------------------------------------------------------
$invoicePath = Join-Path $root "apps\frontend\app\(dashboard)\invoices\new\page.tsx"

if (-not (Test-Path $invoicePath)) {
    Write-Host "ERROR: Could not find $invoicePath" -ForegroundColor Red
    exit 1
}

$invoiceContent = Get-Content -Raw -LiteralPath $invoicePath

$oldLine = 'const newId = createInvoice({ customerId: values.customerId, lines: parsedLines });'
$newLine = 'const newId = await createInvoice({ customerId: values.customerId, lines: parsedLines });'

if ($invoiceContent -match [regex]::Escape($newLine)) {
    Write-Host "invoices/new/page.tsx already fixed - skipping." -ForegroundColor Yellow
}
elseif ($invoiceContent -notmatch [regex]::Escape($oldLine)) {
    Write-Host "ERROR: Could not find the expected createInvoice line in invoices/new/page.tsx." -ForegroundColor Red
    Write-Host "The file may have already been edited manually. Please check it by hand." -ForegroundColor Red
    exit 1
}
else {
    Copy-Item -LiteralPath $invoicePath -Destination "$invoicePath.bak-$stamp"
    Write-Host "Backed up invoices/new/page.tsx -> page.tsx.bak-$stamp"

    $fixed = $invoiceContent.Replace($oldLine, $newLine)
    Set-Content -LiteralPath $invoicePath -Value $fixed -NoNewline
    Write-Host "Fixed missing await in invoices/new/page.tsx" -ForegroundColor Green
}

Write-Host ""
Write-Host "Done. Next steps:" -ForegroundColor Cyan
Write-Host "  1. cd apps\frontend"
Write-Host "  2. npm run dev   (or your usual run script) and test:"
Write-Host "       - Log in, then click Log out -> you should land on /login"
Write-Host "         AND refreshing/navigating back should NOT restore the session."
Write-Host "       - Create a new invoice -> toast should show a real invoice number,"
Write-Host "         not '[object Promise]'."
Write-Host "  3. If everything looks good, delete the .bak-$stamp files this script made."