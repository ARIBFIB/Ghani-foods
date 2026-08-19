<#
  fix-invoice-id-page.ps1
  -------------------------
  Run this from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods

  fix-error-handling.ps1 failed on invoices\[id]\page.tsx because PowerShell's
  Test-Path treats [id] as a wildcard pattern unless -LiteralPath is used.
  This script does the same fix, correctly, for that one file only.
#>

$ErrorActionPreference = "Stop"
$root = Get-Location
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"

$path = Join-Path $root 'apps\frontend\app\(dashboard)\invoices\[id]\page.tsx'

if (-not (Test-Path -LiteralPath $path)) {
    Write-Host "ERROR: Still could not find $path" -ForegroundColor Red
    Write-Host "Double-check the folder is literally named [id] under invoices\." -ForegroundColor Red
    exit 1
}

$content = Get-Content -Raw -LiteralPath $path

$oldBlock = @'
  const onSubmit = async (values: PaymentAmountValues) => {
    recordLedgerEntry(customerId, values.amount, "received", "Payment against invoice");
    toast.success(`Payment of Rs. ${values.amount.toLocaleString()} recorded for ${customerName}`);
    reset();
    onClose();
  };
'@

$newBlock = @'
  const onSubmit = async (values: PaymentAmountValues) => {
    try {
      await recordLedgerEntry(customerId, values.amount, "received", "Payment against invoice");
      toast.success(`Payment of Rs. ${values.amount.toLocaleString()} recorded for ${customerName}`);
      reset();
      onClose();
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Failed to record payment");
    }
  };
'@

if ($content -match [regex]::Escape('Failed to record payment')) {
    Write-Host "invoices\[id]\page.tsx already fixed - skipping." -ForegroundColor Yellow
}
elseif ($content -notmatch [regex]::Escape($oldBlock.Trim())) {
    Write-Host "ERROR: Expected block not found - file may differ from what I expect. Check by hand." -ForegroundColor Red
    exit 1
}
else {
    Copy-Item -LiteralPath $path -Destination "$path.bak-$stamp"
    $fixed = $content.Replace($oldBlock.Trim(), $newBlock.Trim())
    Set-Content -LiteralPath $path -Value $fixed -NoNewline
    Write-Host "Fixed: apps\frontend\app\(dashboard)\invoices\[id]\page.tsx" -ForegroundColor Green
}