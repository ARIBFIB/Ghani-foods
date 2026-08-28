<#
  add-payment-method-bank-cash.ps1
  GhaniFoods - Phase 0 / Batch B1: frontend wiring for Bank/Cash payment method

  This is the URGENT follow-up to 0008_purchase_orders_and_treasury.sql.
  That migration changed fn_record_payment(...) to require a 5th argument
  (p_method: 'bank' | 'cash'). Until this script runs, every "Record
  Payment" action in the app (both the Payments page and the invoice
  detail page's Record Payment dialog) is broken, because they still call
  the old 4-argument shape.

  Changes made by this script:

  [1] apps/frontend/lib/store.ts
      - recordLedgerEntry(...) signature gets a new required `method`
        parameter ('bank' | 'cash'), passed through to fn_record_payment
        as p_method.
      - Store now also loads treasury_accounts (Bank/Cash balances) as
        part of loadCustomersModule(), and exposes s.treasuryAccounts so
        the UI can show live Bank/Cash balances (client requirement:
        "Sara balance mantain ho").

  [2] apps/frontend/lib/schemas.ts
      - paymentSchema gets a new required `method` field ('bank' | 'cash').

  [3] apps/frontend/app/(dashboard)/payments/page.tsx
      - RecordPaymentDialog gets a Bank/Cash toggle (same visual pattern
        as the existing Received/Given toggle) and passes it through.

  [4] apps/frontend/app/(dashboard)/invoices/[id]/page.tsx
      - RecordPaymentDialog (the simpler one used from an invoice) also
        gets a Bank/Cash toggle and passes it through.

  This script is idempotent - safe to re-run.

  Run this from the repo root:
    D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods>

  Usage:
    .\add-payment-method-bank-cash.ps1
    .\add-payment-method-bank-cash.ps1 -WhatIf
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

function Apply-Patch {
    param(
        [string]$FilePath,
        [string]$OldBlock,
        [string]$NewBlock,
        [string]$Description
    )
    if (-not (Test-Path -LiteralPath $FilePath)) {
        Write-Fail "Not found: $FilePath"
        return $null
    }
    $text = Get-Content -LiteralPath $FilePath -Raw -Encoding UTF8
    if ($text.Contains($NewBlock)) {
        Write-Skip "$Description - already patched."
        return $text
    }
    if ($text.Contains($OldBlock)) {
        $text = $text.Replace($OldBlock, $NewBlock)
        Write-Ok "$Description - patched."
        return $text
    }
    Write-Fail "$Description - could not find the expected block to patch. File may already differ; no change made for this piece."
    return $text
}

$root = (Get-Location).Path
Write-Host "Repo root: $root" -ForegroundColor Cyan
if ($WhatIf) { Write-Host "Running in -WhatIf preview mode. No files will be changed." -ForegroundColor Magenta }

# =======================================================================
# [1] store.ts
# =======================================================================
Write-Step "[1/4] Patching apps/frontend/lib/store.ts..."

$storePath = Join-Path $root "apps\frontend\lib\store.ts"
if (-not (Test-Path -LiteralPath $storePath)) {
    Write-Fail "Not found: $storePath"
    exit 1
}
$storeContent = Get-Content -LiteralPath $storePath -Raw -Encoding UTF8
$storeChanged = $false

# --- 1a. interface signature ---
$oldSig = 'recordLedgerEntry: (customerId: string, amount: number, direction: LedgerDirection, note: string) => Promise<void>;'
$newSig = 'recordLedgerEntry: (customerId: string, amount: number, direction: LedgerDirection, method: ''bank'' | ''cash'', note: string) => Promise<void>;'
if ($storeContent.Contains($newSig)) {
    Write-Skip "recordLedgerEntry interface signature - already patched."
} elseif ($storeContent.Contains($oldSig)) {
    $storeContent = $storeContent.Replace($oldSig, $newSig)
    $storeChanged = $true
    Write-Ok "recordLedgerEntry interface signature - patched."
} else {
    Write-Fail "recordLedgerEntry interface signature - block not found."
}

# --- 1b. implementation ---
$oldImpl = @'
  recordLedgerEntry: async (customerId, amount, direction, note) => {
    const { error } = await supabase.rpc("fn_record_payment", {
      p_customer_id: customerId,
      p_amount: amount,
      p_direction: direction,
      p_note: note || null,
    });
    if (error) throw new Error(error.message);
    await get().loadCustomersModule();
  },
'@

$newImpl = @'
  recordLedgerEntry: async (customerId, amount, direction, method, note) => {
    const { error } = await supabase.rpc("fn_record_payment", {
      p_customer_id: customerId,
      p_amount: amount,
      p_direction: direction,
      p_method: method,
      p_note: note || null,
    });
    if (error) throw new Error(error.message);
    await Promise.all([get().loadCustomersModule(), get().loadTreasuryAccounts()]);
  },
'@

if ($storeContent.Contains($newImpl)) {
    Write-Skip "recordLedgerEntry implementation - already patched."
} elseif ($storeContent.Contains($oldImpl)) {
    $storeContent = $storeContent.Replace($oldImpl, $newImpl)
    $storeChanged = $true
    Write-Ok "recordLedgerEntry implementation - patched."
} else {
    Write-Fail "recordLedgerEntry implementation - block not found."
}

# --- 1c. add treasuryAccounts to state shape + loader ---
$oldStateDecl = @'
  invoices: Invoice[];
  ledgerEntries: LedgerEntry[];
  payments: Payment[];
  settings: AppSettings;
  hydrated: boolean;

  loadAll: () => Promise<void>;
'@

$newStateDecl = @'
  invoices: Invoice[];
  ledgerEntries: LedgerEntry[];
  payments: Payment[];
  treasuryAccounts: { id: string; name: 'Bank' | 'Cash'; balance: number }[];
  settings: AppSettings;
  hydrated: boolean;

  loadAll: () => Promise<void>;
  loadTreasuryAccounts: () => Promise<void>;
'@

if ($storeContent.Contains($newStateDecl)) {
    Write-Skip "treasuryAccounts state/type declaration - already patched."
} elseif ($storeContent.Contains($oldStateDecl)) {
    $storeContent = $storeContent.Replace($oldStateDecl, $newStateDecl)
    $storeChanged = $true
    Write-Ok "treasuryAccounts state/type declaration - patched."
} else {
    Write-Fail "treasuryAccounts state/type declaration - block not found."
}

# --- 1d. initial value + loadAll wiring ---
$oldInitial = @'
settings: emptySettings,
  hydrated: false,

  loadAll: async () => {
    await Promise.all([
      get().loadRawMaterialsModule(),
      get().loadPackagingModule(),
      get().loadCartonConfigurations(),
      get().loadProductionBatches(),
      get().loadFinishedCartons(),
      get().loadCustomersModule(),
      get().loadSettings(),
    ]);
    set({ hydrated: true });
  },
'@

$newInitial = @'
settings: emptySettings,
  treasuryAccounts: [],
  hydrated: false,

  loadAll: async () => {
    await Promise.all([
      get().loadRawMaterialsModule(),
      get().loadPackagingModule(),
      get().loadCartonConfigurations(),
      get().loadProductionBatches(),
      get().loadFinishedCartons(),
      get().loadCustomersModule(),
      get().loadTreasuryAccounts(),
      get().loadSettings(),
    ]);
    set({ hydrated: true });
  },

  loadTreasuryAccounts: async () => {
    const { data } = await supabase.from("treasury_accounts").select("*").order("name");
    set({
      treasuryAccounts: (data ?? []).map((row: Record<string, any>) => ({
        id: row.id,
        name: row.name as 'Bank' | 'Cash',
        balance: Number(row.balance),
      })),
    });
  },
'@

if ($storeContent.Contains($newInitial)) {
    Write-Skip "treasuryAccounts initial value / loadAll wiring - already patched."
} elseif ($storeContent.Contains($oldInitial)) {
    $storeContent = $storeContent.Replace($oldInitial, $newInitial)
    $storeChanged = $true
    Write-Ok "treasuryAccounts initial value / loadAll wiring - patched."
} else {
    Write-Fail "treasuryAccounts initial value / loadAll wiring - block not found."
}

if ($storeChanged -and -not $WhatIf) {
    Write-FileUtf8NoBom -Path $storePath -Content $storeContent
    Write-Host "  Saved: $storePath" -ForegroundColor Green
} elseif ($storeChanged -and $WhatIf) {
    Write-Host "  WhatIf: would save $storePath" -ForegroundColor Magenta
}

# =======================================================================
# [2] schemas.ts
# =======================================================================
Write-Step "[2/4] Patching apps/frontend/lib/schemas.ts..."

$schemasPath = Join-Path $root "apps\frontend\lib\schemas.ts"
$oldSchema = @'
export const paymentSchema = z.object({
  customerId: z.string().min(1, "Select a customer"),
  amount: z.coerce.number().positive("Amount must be greater than 0"),
  direction: z.enum(["received", "given"], {
    required_error: "Select a direction",
  }),
  note: z.string().trim().optional(),
});
'@

$newSchema = @'
export const paymentSchema = z.object({
  customerId: z.string().min(1, "Select a customer"),
  amount: z.coerce.number().positive("Amount must be greater than 0"),
  direction: z.enum(["received", "given"], {
    required_error: "Select a direction",
  }),
  method: z.enum(["bank", "cash"], {
    required_error: "Select Bank or Cash",
  }),
  note: z.string().trim().optional(),
});
'@

if (Test-Path -LiteralPath $schemasPath) {
    $schemasContent = Get-Content -LiteralPath $schemasPath -Raw -Encoding UTF8
    if ($schemasContent.Contains($newSchema)) {
        Write-Skip "paymentSchema - already patched."
    } elseif ($schemasContent.Contains($oldSchema)) {
        $schemasContent = $schemasContent.Replace($oldSchema, $newSchema)
        if (-not $WhatIf) {
            Write-FileUtf8NoBom -Path $schemasPath -Content $schemasContent
        }
        Write-Ok "paymentSchema - patched."
    } else {
        Write-Fail "paymentSchema - block not found."
    }
} else {
    Write-Fail "Not found: $schemasPath"
}

# =======================================================================
# [3] payments/page.tsx
# =======================================================================
Write-Step "[3/4] Patching apps/frontend/app/(dashboard)/payments/page.tsx..."

$paymentsPagePath = Join-Path $root "apps\frontend\app\(dashboard)\payments\page.tsx"

$oldPaymentsDefaults = @'
    defaultValues: { customerId: customers[0]?.id ?? "", amount: 0, direction: "received", note: "" },
'@
$newPaymentsDefaults = @'
    defaultValues: { customerId: customers[0]?.id ?? "", amount: 0, direction: "received", method: "cash", note: "" },
'@

$oldPaymentsSubmit = @'
      await recordLedgerEntry(values.customerId, values.amount, values.direction, values.note ?? "");
'@
$newPaymentsSubmit = @'
      await recordLedgerEntry(values.customerId, values.amount, values.direction, values.method, values.note ?? "");
'@

$oldPaymentsDirectionBlock = @'
            <input type="hidden" {...register("direction")} />
            {errors.direction && <p className="text-xs text-red-400 mt-1">{errors.direction.message}</p>}
          </div>
          <div>
            <label className="text-sm text-[var(--text-muted)]">Note</label>
'@
$newPaymentsDirectionBlock = @'
            <input type="hidden" {...register("direction")} />
            {errors.direction && <p className="text-xs text-red-400 mt-1">{errors.direction.message}</p>}
          </div>
          <div>
            <label className="text-sm text-[var(--text-muted)]">Received In / Paid From</label>
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
          <div>
            <label className="text-sm text-[var(--text-muted)]">Note</label>
'@

$oldPaymentsWatch = 'const direction = watch("direction");'
$newPaymentsWatch = @'
const direction = watch("direction");
  const method = watch("method");
'@

if (Test-Path -LiteralPath $paymentsPagePath) {
    $ppContent = Get-Content -LiteralPath $paymentsPagePath -Raw -Encoding UTF8
    $ppChanged = $false

    if ($ppContent.Contains($newPaymentsWatch)) {
        Write-Skip "payments/page.tsx watch(method) - already patched."
    } elseif ($ppContent.Contains($oldPaymentsWatch)) {
        $ppContent = $ppContent.Replace($oldPaymentsWatch, $newPaymentsWatch)
        $ppChanged = $true
        Write-Ok "payments/page.tsx watch(method) - patched."
    } else {
        Write-Fail "payments/page.tsx watch(method) - block not found."
    }

    if ($ppContent.Contains($newPaymentsDefaults)) {
        Write-Skip "payments/page.tsx defaultValues - already patched."
    } elseif ($ppContent.Contains($oldPaymentsDefaults)) {
        $ppContent = $ppContent.Replace($oldPaymentsDefaults, $newPaymentsDefaults)
        $ppChanged = $true
        Write-Ok "payments/page.tsx defaultValues - patched."
    } else {
        Write-Fail "payments/page.tsx defaultValues - block not found."
    }

    if ($ppContent.Contains($newPaymentsSubmit)) {
        Write-Skip "payments/page.tsx onSubmit call - already patched."
    } elseif ($ppContent.Contains($oldPaymentsSubmit)) {
        $ppContent = $ppContent.Replace($oldPaymentsSubmit, $newPaymentsSubmit)
        $ppChanged = $true
        Write-Ok "payments/page.tsx onSubmit call - patched."
    } else {
        Write-Fail "payments/page.tsx onSubmit call - block not found."
    }

    if ($ppContent.Contains("Received In / Paid From")) {
        Write-Skip "payments/page.tsx Bank/Cash toggle UI - already patched."
    } elseif ($ppContent.Contains($oldPaymentsDirectionBlock)) {
        $ppContent = $ppContent.Replace($oldPaymentsDirectionBlock, $newPaymentsDirectionBlock)
        $ppChanged = $true
        Write-Ok "payments/page.tsx Bank/Cash toggle UI - patched."
    } else {
        Write-Fail "payments/page.tsx Bank/Cash toggle UI - block not found."
    }

    if ($ppChanged -and -not $WhatIf) {
        Write-FileUtf8NoBom -Path $paymentsPagePath -Content $ppContent
        Write-Host "  Saved: $paymentsPagePath" -ForegroundColor Green
    } elseif ($ppChanged -and $WhatIf) {
        Write-Host "  WhatIf: would save $paymentsPagePath" -ForegroundColor Magenta
    }
} else {
    Write-Fail "Not found: $paymentsPagePath"
}

# =======================================================================
# [4] invoices/[id]/page.tsx
# =======================================================================
Write-Step "[4/4] Patching apps/frontend/app/(dashboard)/invoices/[id]/page.tsx..."

$invoiceDetailPath = Join-Path $root "apps\frontend\app\(dashboard)\invoices\[id]\page.tsx"

$oldInvoiceDialogImport = @'
const paymentAmountSchema = z.object({
  amount: z.coerce.number().positive("Amount must be greater than 0"),
});
'@
$newInvoiceDialogImport = @'
const paymentAmountSchema = z.object({
  amount: z.coerce.number().positive("Amount must be greater than 0"),
  method: z.enum(["bank", "cash"], { required_error: "Select Bank or Cash" }),
});
'@

$oldInvoiceDialogBody = @'
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
        <h2 className="text-lg font-semibold text-[var(--foreground)]">Record Payment &mdash; {customerName}</h2>
        <div>
          <label className="text-sm text-[var(--text-muted)]">Amount</label>
          <input {...register("amount")} type="number" step="any"
            className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
          {errors.amount && <p className="text-xs text-red-400 mt-1">{errors.amount.message}</p>}
        </div>
        <div className="flex justify-end gap-2 pt-2">
'@

$newInvoiceDialogBody = @'
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
        <h2 className="text-lg font-semibold text-[var(--foreground)]">Record Payment &mdash; {customerName}</h2>
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

if (Test-Path -LiteralPath $invoiceDetailPath) {
    $idContent = Get-Content -LiteralPath $invoiceDetailPath -Raw -Encoding UTF8
    $idChanged = $false

    if ($idContent.Contains($newInvoiceDialogImport)) {
        Write-Skip "invoices/[id]/page.tsx paymentAmountSchema - already patched."
    } elseif ($idContent.Contains($oldInvoiceDialogImport)) {
        $idContent = $idContent.Replace($oldInvoiceDialogImport, $newInvoiceDialogImport)
        $idChanged = $true
        Write-Ok "invoices/[id]/page.tsx paymentAmountSchema - patched."
    } else {
        Write-Fail "invoices/[id]/page.tsx paymentAmountSchema - block not found."
    }

    if ($idContent.Contains("Received In</label>")) {
        Write-Skip "invoices/[id]/page.tsx RecordPaymentDialog Bank/Cash UI - already patched."
    } elseif ($idContent.Contains($oldInvoiceDialogBody)) {
        $idContent = $idContent.Replace($oldInvoiceDialogBody, $newInvoiceDialogBody)
        $idChanged = $true
        Write-Ok "invoices/[id]/page.tsx RecordPaymentDialog Bank/Cash UI - patched."
    } else {
        Write-Fail "invoices/[id]/page.tsx RecordPaymentDialog Bank/Cash UI - block not found (this can happen if the Phase 1 script changed surrounding lines - share the current file if this keeps failing)."
    }

    if ($idChanged -and -not $WhatIf) {
        Write-FileUtf8NoBom -Path $invoiceDetailPath -Content $idContent
        Write-Host "  Saved: $invoiceDetailPath" -ForegroundColor Green
    } elseif ($idChanged -and $WhatIf) {
        Write-Host "  WhatIf: would save $invoiceDetailPath" -ForegroundColor Magenta
    }
} else {
    Write-Fail "Not found: $invoiceDetailPath"
}

Write-Host ""
Write-Host "Done. Next steps:" -ForegroundColor Cyan
Write-Host "  1. Restart your dev server." -ForegroundColor Cyan
Write-Host "  2. Test Record Payment from the Payments page - pick Cash, then Bank -" -ForegroundColor Cyan
Write-Host "     confirm it succeeds (no more 4-vs-5-argument error)." -ForegroundColor Cyan
Write-Host "  3. Test Record Payment from an invoice detail page the same way." -ForegroundColor Cyan
Write-Host "  4. In Supabase, check treasury_accounts - Bank/Cash balances should move" -ForegroundColor Cyan
Write-Host "     up or down to match what you recorded, and treasury_transactions" -ForegroundColor Cyan
Write-Host "     should show a new row for each payment." -ForegroundColor Cyan
Write-Host ""
Write-Host "Once confirmed, tell me and I will give you Batch B2: Purchase Order" -ForegroundColor Cyan
Write-Host "screens (create/view PO) and updating the Purchase Receipt form to" -ForegroundColor Cyan
Write-Host "require selecting a PO instead of free entry." -ForegroundColor Cyan