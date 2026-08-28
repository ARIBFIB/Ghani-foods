<#
  fix-invoice-payment-dialog-bank-cash.ps1
  GhaniFoods - Batch B1 follow-up: fixes the one piece that failed to
  patch in add-payment-method-bank-cash.ps1 (apps/frontend/app/(dashboard)
  /invoices/[id]/page.tsx), because that file uses a literal "\u2014"
  instead of "&mdash;" for the em dash in "Record Payment \u2014 {customerName}".

  This script ONLY touches that one file. The other three files patched by
  add-payment-method-bank-cash.ps1 (store.ts, schemas.ts, payments/page.tsx)
  are untouched here - make sure you already ran that script for real
  (without -WhatIf) before running this one.

  Idempotent - safe to re-run.

  Run this from the repo root:
    D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods>

  Usage:
    .\fix-invoice-payment-dialog-bank-cash.ps1
    .\fix-invoice-payment-dialog-bank-cash.ps1 -WhatIf
#>

param(
    [switch]$WhatIf
)

function Write-Step { param([string]$Text) Write-Host ""; Write-Host $Text -ForegroundColor Yellow }
function Write-Ok    { param([string]$Text) Write-Host "  -> $Text" -ForegroundColor Green }
function Write-Skip  { param([string]$Text) Write-Host "  -- $Text" -ForegroundColor DarkYellow }
function Write-Fail  { param([string]$Text) Write-Host "  ERROR: $Text" -ForegroundColor Red }

function Write-FileUtf8NoBom {
    param([string]$Path, [string]$Content)
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

$root = (Get-Location).Path
Write-Host "Repo root: $root" -ForegroundColor Cyan
if ($WhatIf) { Write-Host "Running in -WhatIf preview mode. No files will be changed." -ForegroundColor Magenta }

$invoiceDetailPath = Join-Path $root "apps\frontend\app\(dashboard)\invoices\[id]\page.tsx"

if (-not (Test-Path -LiteralPath $invoiceDetailPath)) {
    Write-Fail "Not found: $invoiceDetailPath"
    exit 1
}

Write-Step "[1/1] Patching RecordPaymentDialog in invoices/[id]/page.tsx..."

$content = Get-Content -LiteralPath $invoiceDetailPath -Raw -Encoding UTF8
$changed = $false

# --- paymentAmountSchema: add method field (same as before - re-check in case not yet applied) ---
$oldSchemaBlock = @'
const paymentAmountSchema = z.object({
  amount: z.coerce.number().positive("Amount must be greater than 0"),
});
'@
$newSchemaBlock = @'
const paymentAmountSchema = z.object({
  amount: z.coerce.number().positive("Amount must be greater than 0"),
  method: z.enum(["bank", "cash"], { required_error: "Select Bank or Cash" }),
});
'@

if ($content.Contains($newSchemaBlock)) {
    Write-Skip "paymentAmountSchema - already patched."
} elseif ($content.Contains($oldSchemaBlock)) {
    $content = $content.Replace($oldSchemaBlock, $newSchemaBlock)
    $changed = $true
    Write-Ok "paymentAmountSchema - patched."
} else {
    Write-Fail "paymentAmountSchema - block not found (unexpected - check file manually)."
}

# --- RecordPaymentDialog body: exact match using the real "\u2014" text ---
$oldDialogBody = @'
function RecordPaymentDialog({ open, onClose, customerId, customerName }: { open: boolean; onClose: () => void; customerId: string; customerName: string }) {
  // NOTE: this dialog still only records a "received" payment with no
  // direction selector. The full +/- direction UI (BRS v1.2 item 6 /
  // Spec v2.2 5.12) is Step 7 scope. This wiring is switched from the
  // removed s.recordPayment() to the real s.recordLedgerEntry() so the
  // page compiles against the current store in the meantime.
  const recordLedgerEntry = useStore((s) => s.recordLedgerEntry);
  const {
    register,
    handleSubmit,
    reset,
    formState: { errors, isSubmitting },
  } = useForm<PaymentAmountValues>({ resolver: zodResolver(paymentAmountSchema) });

  if (!open) return null;

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

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-3 sm:p-4">
      <form onSubmit={handleSubmit(onSubmit)} className="w-full max-w-sm rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-5 space-y-4 max-h-[90vh] overflow-y-auto">
        <h2 className="text-lg font-semibold text-[var(--foreground)]">Record Payment \u2014 {customerName}</h2>
        <div>
          <label className="text-sm text-[var(--text-muted)]">Amount</label>
          <input {...register("amount")} type="number" step="any"
            className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
          {errors.amount && <p className="text-xs text-red-400 mt-1">{errors.amount.message}</p>}
        </div>
        <div className="flex justify-end gap-2 pt-2">
'@

$newDialogBody = @'
function RecordPaymentDialog({ open, onClose, customerId, customerName }: { open: boolean; onClose: () => void; customerId: string; customerName: string }) {
  const recordLedgerEntry = useStore((s) => s.recordLedgerEntry);
  const {
    register,
    handleSubmit,
    reset,
    watch,
    setValue,
    formState: { errors, isSubmitting },
  } = useForm<PaymentAmountValues>({ resolver: zodResolver(paymentAmountSchema), defaultValues: { method: "cash" } });
  const method = watch("method");

  if (!open) return null;

  const onSubmit = async (values: PaymentAmountValues) => {
    try {
      await recordLedgerEntry(customerId, values.amount, "received", values.method, "Payment against invoice");
      toast.success(`Payment of Rs. ${values.amount.toLocaleString()} recorded for ${customerName}`);
      reset();
      onClose();
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Failed to record payment");
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-3 sm:p-4">
      <form onSubmit={handleSubmit(onSubmit)} className="w-full max-w-sm rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-5 space-y-4 max-h-[90vh] overflow-y-auto">
        <h2 className="text-lg font-semibold text-[var(--foreground)]">Record Payment \u2014 {customerName}</h2>
        <div>
          <label className="text-sm text-[var(--text-muted)]">Amount</label>
          <input {...register("amount")} type="number" step="any"
            className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
          {errors.amount && <p className="text-xs text-red-400 mt-1">{errors.amount.message}</p>}
        </div>
        <div>
          <label className="text-sm text-[var(--text-muted)]">Received In</label>
          <div className="mt-1 grid grid-cols-2 gap-2">
            <button
              type="button"
              onClick={() => setValue("method", "cash", { shouldValidate: true })}
              className={`rounded-lg border px-3 py-2 text-xs font-medium transition-colors ${
                method === "cash"
                  ? "border-[var(--surface-border-strong)] bg-[var(--surface-hover)] text-[var(--foreground)]"
                  : "border-[var(--surface-border)] text-[var(--text-secondary)] hover:bg-[var(--surface-hover)]"
              }`}
            >
              Cash
            </button>
            <button
              type="button"
              onClick={() => setValue("method", "bank", { shouldValidate: true })}
              className={`rounded-lg border px-3 py-2 text-xs font-medium transition-colors ${
                method === "bank"
                  ? "border-[var(--surface-border-strong)] bg-[var(--surface-hover)] text-[var(--foreground)]"
                  : "border-[var(--surface-border)] text-[var(--text-secondary)] hover:bg-[var(--surface-hover)]"
              }`}
            >
              Bank
            </button>
          </div>
          <input type="hidden" {...register("method")} />
          {errors.method && <p className="text-xs text-red-400 mt-1">{errors.method.message}</p>}
        </div>
        <div className="flex justify-end gap-2 pt-2">
'@

if ($content.Contains("Received In</label>")) {
    Write-Skip "RecordPaymentDialog Bank/Cash UI - already patched."
} elseif ($content.Contains($oldDialogBody)) {
    $content = $content.Replace($oldDialogBody, $newDialogBody)
    $changed = $true
    Write-Ok "RecordPaymentDialog Bank/Cash UI - patched."
} else {
    Write-Fail "RecordPaymentDialog Bank/Cash UI - still not an exact match."
    Write-Fail "Paste the output of this and send it to me:"
    Write-Host '  $c = Get-Content -LiteralPath "apps\frontend\app\(dashboard)\invoices\[id]\page.tsx" -Raw' -ForegroundColor DarkYellow
    Write-Host '  $start = $c.IndexOf("function RecordPaymentDialog")' -ForegroundColor DarkYellow
    Write-Host '  $c.Substring($start, 1400) | Set-Clipboard' -ForegroundColor DarkYellow
    Write-Host '  Get-Clipboard' -ForegroundColor DarkYellow
}

if ($changed) {
    if ($WhatIf) {
        Write-Host ""
        Write-Host "WhatIf mode - would save: $invoiceDetailPath" -ForegroundColor Magenta
    } else {
        Write-FileUtf8NoBom -Path $invoiceDetailPath -Content $content
        Write-Host ""
        Write-Host "Saved: $invoiceDetailPath" -ForegroundColor Green
    }
} else {
    Write-Host ""
    Write-Host "No changes written (see messages above)." -ForegroundColor DarkYellow
}

Write-Host ""
Write-Host "Done. Restart your dev server, then test Record Payment from an invoice" -ForegroundColor Cyan
Write-Host "detail page (Cash, then Bank) and check treasury_accounts in Supabase." -ForegroundColor Cyan
Write-Host ""
Write-Host "Once ALL of Batch B1 is confirmed working (Payments page + invoice-detail" -ForegroundColor Cyan
Write-Host "payment dialog, both Cash and Bank), tell me and I'll give you Batch B2:" -ForegroundColor Cyan
Write-Host "Purchase Order screens + Purchase Receipt form requiring a PO." -ForegroundColor Cyan