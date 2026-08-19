<#
  fix-error-handling.ps1
  ------------------------
  Run this from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods

  Adds await + try/catch error handling to 6 forms that were calling async
  store actions without awaiting them or catching failures. Without this,
  if the backend call fails (network issue, insufficient stock, validation
  error, etc.) the form just silently closes as if it succeeded and the
  user is never told anything went wrong.

  Files touched:
   1) apps/frontend/app/(dashboard)/customers/page.tsx
   2) apps/frontend/app/(dashboard)/payments/page.tsx
   3) apps/frontend/app/(dashboard)/packaging/carton-config/page.tsx
   4) apps/frontend/app/(dashboard)/settings/page.tsx
   5) apps/frontend/app/(dashboard)/finished-cartons/page.tsx
   6) apps/frontend/app/(dashboard)/invoices/[id]/page.tsx

  Safe to re-run - already-fixed files are skipped.
#>

$ErrorActionPreference = "Stop"
$root = Get-Location
Write-Host "Running in: $root" -ForegroundColor Cyan
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"

function Apply-Fix {
    param(
        [string]$RelativePath,
        [string]$OldBlock,
        [string]$NewBlock,
        [string]$AlreadyFixedMarker
    )

    $path = Join-Path $root $RelativePath
    if (-not (Test-Path $path)) {
        Write-Host "ERROR: Could not find $path" -ForegroundColor Red
        return
    }

    $content = Get-Content -Raw -LiteralPath $path

    if ($content -match [regex]::Escape($AlreadyFixedMarker)) {
        Write-Host "$RelativePath already fixed - skipping." -ForegroundColor Yellow
        return
    }

    if ($content -notmatch [regex]::Escape($OldBlock.Trim())) {
        Write-Host "ERROR: Expected block not found in $RelativePath - skipping (check file by hand)." -ForegroundColor Red
        return
    }

    Copy-Item -LiteralPath $path -Destination "$path.bak-$stamp"
    $fixed = $content.Replace($OldBlock.Trim(), $NewBlock.Trim())
    Set-Content -LiteralPath $path -Value $fixed -NoNewline
    Write-Host "Fixed: $RelativePath" -ForegroundColor Green
}

# ---------------------------------------------------------------------
# 1) customers/page.tsx
# ---------------------------------------------------------------------
$old1 = @'
  const onSubmit = async (values: CustomerFormValues) => {
    addCustomer(values);
    toast.success(`Customer "${values.name}" added`);
    reset(); onClose();
  };
'@
$new1 = @'
  const onSubmit = async (values: CustomerFormValues) => {
    try {
      await addCustomer(values);
      toast.success(`Customer "${values.name}" added`);
      reset(); onClose();
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Failed to add customer");
    }
  };
'@
Apply-Fix -RelativePath 'apps\frontend\app\(dashboard)\customers\page.tsx' -OldBlock $old1 -NewBlock $new1 -AlreadyFixedMarker 'Failed to add customer'

# ---------------------------------------------------------------------
# 2) payments/page.tsx
# ---------------------------------------------------------------------
$old2 = @'
  const onSubmit = async (values: PaymentFormValues) => {
    recordLedgerEntry(values.customerId, values.amount, values.direction, values.note ?? "");
    toast.success(
      values.direction === "received"
        ? `Payment of Rs. ${values.amount.toLocaleString()} received`
        : `Rs. ${values.amount.toLocaleString()} recorded as given / credit adjustment`
    );
    reset();
    onClose();
  };
'@
$new2 = @'
  const onSubmit = async (values: PaymentFormValues) => {
    try {
      await recordLedgerEntry(values.customerId, values.amount, values.direction, values.note ?? "");
      toast.success(
        values.direction === "received"
          ? `Payment of Rs. ${values.amount.toLocaleString()} received`
          : `Rs. ${values.amount.toLocaleString()} recorded as given / credit adjustment`
      );
      reset();
      onClose();
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Failed to record payment");
    }
  };
'@
Apply-Fix -RelativePath 'apps\frontend\app\(dashboard)\payments\page.tsx' -OldBlock $old2 -NewBlock $new2 -AlreadyFixedMarker 'Failed to record payment'

# ---------------------------------------------------------------------
# 3) packaging/carton-config/page.tsx
# ---------------------------------------------------------------------
$old3 = @'
  const onSubmit = async (values: CartonConfigFormValues) => {
    addCartonConfiguration(values);
    toast.success("Carton configuration created");
    reset();
    onClose();
  };
'@
$new3 = @'
  const onSubmit = async (values: CartonConfigFormValues) => {
    try {
      await addCartonConfiguration(values);
      toast.success("Carton configuration created");
      reset();
      onClose();
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Failed to create carton configuration");
    }
  };
'@
Apply-Fix -RelativePath 'apps\frontend\app\(dashboard)\packaging\carton-config\page.tsx' -OldBlock $old3 -NewBlock $new3 -AlreadyFixedMarker 'Failed to create carton configuration'

# ---------------------------------------------------------------------
# 4) settings/page.tsx
# ---------------------------------------------------------------------
$old4 = @'
  const onSubmit = async (values: SettingsFormValues) => {
    updateSettings(values);
    toast.success("Settings saved");
  };
'@
$new4 = @'
  const onSubmit = async (values: SettingsFormValues) => {
    try {
      await updateSettings(values);
      toast.success("Settings saved");
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Failed to save settings");
    }
  };
'@
Apply-Fix -RelativePath 'apps\frontend\app\(dashboard)\settings\page.tsx' -OldBlock $old4 -NewBlock $new4 -AlreadyFixedMarker 'Failed to save settings'

# ---------------------------------------------------------------------
# 5) finished-cartons/page.tsx (handleConfirm)
# ---------------------------------------------------------------------
$old5 = @'
  const handleConfirm = () => {
    if (!batch || !config) return;
    if (cartons <= 0) {
      toast.error("Enter a valid number of cartons");
      return;
    }
    if (insufficientBulk) {
      toast.error("Not enough bulk product left in the selected batch");
      return;
    }
    if (insufficientWrapper) {
      toast.error(`Not enough ${wrapper?.name} in stock`);
      return;
    }
    if (insufficientBox) {
      toast.error(`Not enough ${box?.name} in stock`);
      return;
    }
    createPackingRun({ batchId, configId, cartonsProduced: cartons });
    toast.success(`Packing run confirmed - ${cartons} cartons added to ready stock`);
    reset();
    onClose();
  };
'@
$new5 = @'
  const handleConfirm = async () => {
    if (!batch || !config) return;
    if (cartons <= 0) {
      toast.error("Enter a valid number of cartons");
      return;
    }
    if (insufficientBulk) {
      toast.error("Not enough bulk product left in the selected batch");
      return;
    }
    if (insufficientWrapper) {
      toast.error(`Not enough ${wrapper?.name} in stock`);
      return;
    }
    if (insufficientBox) {
      toast.error(`Not enough ${box?.name} in stock`);
      return;
    }
    try {
      await createPackingRun({ batchId, configId, cartonsProduced: cartons });
      toast.success(`Packing run confirmed - ${cartons} cartons added to ready stock`);
      reset();
      onClose();
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Failed to confirm packing run");
    }
  };
'@
Apply-Fix -RelativePath 'apps\frontend\app\(dashboard)\finished-cartons\page.tsx' -OldBlock $old5 -NewBlock $new5 -AlreadyFixedMarker 'Failed to confirm packing run'

# ---------------------------------------------------------------------
# 6) invoices/[id]/page.tsx
# ---------------------------------------------------------------------
$old6 = @'
  const onSubmit = async (values: PaymentAmountValues) => {
    recordLedgerEntry(customerId, values.amount, "received", "Payment against invoice");
    toast.success(`Payment of Rs. ${values.amount.toLocaleString()} recorded for ${customerName}`);
    reset();
    onClose();
  };
'@
$new6 = @'
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
Apply-Fix -RelativePath 'apps\frontend\app\(dashboard)\invoices\[id]\page.tsx' -OldBlock $old6 -NewBlock $new6 -AlreadyFixedMarker 'Failed to record payment'

Write-Host ""
Write-Host "Done. Next steps:" -ForegroundColor Cyan
Write-Host "  1. cd apps\frontend; npm run dev"
Write-Host "  2. Sanity check each of the 6 forms still saves normally."
Write-Host "  3. Optionally test a failure case (e.g. turn off wifi briefly, submit a form)"
Write-Host "     and confirm you now see a red error toast instead of a silent close."
Write-Host "  4. Once confirmed, delete the .bak-$stamp files this script made."