#
# step1-batch-other-expenses.ps1
# -----------------------------------
# Run this from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods
#
# STEP 1 of the "Batch + Monthly Expenses" frontend rollout.
#
# What this does:
#   1. apps/frontend/lib/store.ts
#        - createBatch() input type gets an optional `otherExpenses` field
#        - createBatch() implementation passes `p_other_expenses` to the
#          fn_create_production_batch RPC (backend already supports this)
#   2. apps/frontend/app/(dashboard)/batches/new/page.tsx
#        - New "Other Expenses (this batch)" card: Name + Amount rows,
#          "+ Add Expense" button, same pattern as raw material rows
#        - Estimated Batch Cost box now includes these expenses in the total
#          and shows a breakdown line
#        - On submit, non-empty expense rows are sent as `otherExpenses`
#
# NOT included in this script (coming in later steps):
#   - Monthly Expenses page + sidebar link
#   - Settings page overhead_allocation_method toggle
#   - Batch detail page cost breakdown (batch_expenses + monthly share)
#   - Retiring the old hardcoded Overhead dialog
#
# Safe to re-run - if the target text isn't found (already patched), that
# file is skipped with a warning instead of corrupting anything.
# Backups made before any edit: <file>.bak-<timestamp>
#

$ErrorActionPreference = "Stop"
$root = Get-Location
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
Write-Host "Running in: $root" -ForegroundColor Cyan

function Backup-File($path) {
  if (Test-Path $path) {
    Copy-Item $path "$path.bak-$stamp" -Force
    Write-Host "  backed up -> $path.bak-$stamp" -ForegroundColor DarkGray
  }
}

function Write-FileUtf8NoBom([string]$Path, [string]$Content) {
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

# Normalizes CRLF -> LF so literal-text matching works regardless of how
# this .ps1 file itself got saved/transferred (avoids the whitespace
# mismatch problem we've hit before with anchor-based replacement).
function Normalize([string]$s) { return $s -replace "`r`n", "`n" }
function Denormalize([string]$s) { return $s -replace "`n", "`r`n" }

function Apply-Replacement {
  param(
    [string]$FilePath,
    [string]$Old,
    [string]$New,
    [string]$Label
  )
  if (-not (Test-Path $FilePath)) {
    Write-Warning "File not found, skipping: $FilePath"
    return
  }
  $raw = Get-Content -Raw -Encoding UTF8 $FilePath
  $normalized = Normalize $raw
  $oldN = Normalize $Old
  $newN = Normalize $New

  if ($normalized.Contains($newN)) {
    Write-Host "  [$Label] already applied, skipping" -ForegroundColor Yellow
    return $false
  }
  if (-not $normalized.Contains($oldN)) {
    Write-Warning "  [$Label] anchor text not found in $FilePath - skipping this edit (file may have changed)."
    return $false
  }

  $updated = $normalized.Replace($oldN, $newN)
  $final = Denormalize $updated
  Write-FileUtf8NoBom -Path $FilePath -Content $final
  Write-Host "  [$Label] applied" -ForegroundColor Green
  return $true
}

# =====================================================================
# 1. apps/frontend/lib/store.ts
# =====================================================================
$storePath = Join-Path $root "apps/frontend/lib/store.ts"
Write-Host "`nPatching: $storePath" -ForegroundColor Cyan
Backup-File $storePath

# 1a. Type signature - add otherExpenses field
$old1a = @'
  createBatch: (input: {
    consumptions: { rawMaterialId: string; qty: number }[];
    outputYieldKg: number;
    wastageKg: number;
    leftoverBatchId?: string;
    leftoverKgUsed?: number;
  }) => Promise<string>;
'@

$new1a = @'
  createBatch: (input: {
    consumptions: { rawMaterialId: string; qty: number }[];
    outputYieldKg: number;
    wastageKg: number;
    leftoverBatchId?: string;
    leftoverKgUsed?: number;
    otherExpenses?: { name: string; amount: number }[];
  }) => Promise<string>;
'@

Apply-Replacement -FilePath $storePath -Old $old1a -New $new1a -Label "store.ts: createBatch type"

# 1b. Implementation - pass p_other_expenses to the RPC
$old1b = @'
  createBatch: async (input) => {
    const { data, error } = await supabase.rpc("fn_create_production_batch", {
      p_consumptions: input.consumptions,
      p_output_yield_kg: input.outputYieldKg,
      p_wastage_kg: input.wastageKg,
      p_leftover_batch_id: input.leftoverBatchId ?? null,
      p_leftover_kg_used: input.leftoverKgUsed ?? null,
    });
'@

$new1b = @'
  createBatch: async (input) => {
    const { data, error } = await supabase.rpc("fn_create_production_batch", {
      p_consumptions: input.consumptions,
      p_output_yield_kg: input.outputYieldKg,
      p_wastage_kg: input.wastageKg,
      p_leftover_batch_id: input.leftoverBatchId ?? null,
      p_leftover_kg_used: input.leftoverKgUsed ?? null,
      p_other_expenses: input.otherExpenses ?? [],
    });
'@

Apply-Replacement -FilePath $storePath -Old $old1b -New $new1b -Label "store.ts: createBatch RPC call"

# =====================================================================
# 2. apps/frontend/app/(dashboard)/batches/new/page.tsx
# =====================================================================
$newBatchPath = Join-Path $root "apps/frontend/app/(dashboard)/batches/new/page.tsx"
Write-Host "`nPatching: $newBatchPath" -ForegroundColor Cyan
Backup-File $newBatchPath

# 2a. Add ExpenseRow type
$old2a = @'
type ConsumptionRow = { id: string; rawMaterialId: string; qty: string; unit: string };
'@

$new2a = @'
type ConsumptionRow = { id: string; rawMaterialId: string; qty: string; unit: string };
type ExpenseRow = { id: string; name: string; amount: string };
'@

Apply-Replacement -FilePath $newBatchPath -Old $old2a -New $new2a -Label "new/page.tsx: ExpenseRow type"

# 2b. Add expenseRows state + add/remove/update handlers
$old2b = @'
  const [leftoverKgUsed, setLeftoverKgUsed] = useState("");

  const leftoverBatches = productionBatches.filter((b) => b.leftoverQtyKg > 0);
'@

$new2b = @'
  const [leftoverKgUsed, setLeftoverKgUsed] = useState("");

  const [expenseRows, setExpenseRows] = useState<ExpenseRow[]>([]);
  const addExpenseRow = () =>
    setExpenseRows((prev) => [...prev, { id: crypto.randomUUID(), name: "", amount: "" }]);
  const removeExpenseRow = (id: string) =>
    setExpenseRows((prev) => prev.filter((r) => r.id !== id));
  const updateExpenseRow = (id: string, patch: Partial<ExpenseRow>) =>
    setExpenseRows((prev) => prev.map((r) => (r.id === id ? { ...r, ...patch } : r)));

  const leftoverBatches = productionBatches.filter((b) => b.leftoverQtyKg > 0);
'@

Apply-Replacement -FilePath $newBatchPath -Old $old2b -New $new2b -Label "new/page.tsx: expense state + handlers"

# 2c. Include expenses in the estimated cost total
$old2c = @'
  const estimatedTotalCost = estimatedRawMaterialCost + estimatedLeftoverCost;
'@

$new2c = @'
  const estimatedExpensesTotal = useMemo(() => {
    return expenseRows.reduce((total, row) => total + (Number(row.amount) || 0), 0);
  }, [expenseRows]);

  const estimatedTotalCost = estimatedRawMaterialCost + estimatedLeftoverCost + estimatedExpensesTotal;
'@

Apply-Replacement -FilePath $newBatchPath -Old $old2c -New $new2c -Label "new/page.tsx: cost total includes expenses"

# 2d. Build otherExpenses payload and send it on submit
$old2d = @'
    try {
      const newId = await createBatch({
        consumptions,
        outputYieldKg: values.outputYieldKg,
        wastageKg: values.wastageKg,
        leftoverBatchId: useLeftoverFirst ? leftoverBatchId : undefined,
        leftoverKgUsed: useLeftoverFirst ? Number(leftoverKgUsed) || 0 : undefined,
      });
'@

$new2d = @'
    const otherExpenses = expenseRows
      .filter((r) => r.name.trim() && Number(r.amount) > 0)
      .map((r) => ({ name: r.name.trim(), amount: Number(r.amount) }));

    try {
      const newId = await createBatch({
        consumptions,
        outputYieldKg: values.outputYieldKg,
        wastageKg: values.wastageKg,
        leftoverBatchId: useLeftoverFirst ? leftoverBatchId : undefined,
        leftoverKgUsed: useLeftoverFirst ? Number(leftoverKgUsed) || 0 : undefined,
        otherExpenses,
      });
'@

Apply-Replacement -FilePath $newBatchPath -Old $old2d -New $new2d -Label "new/page.tsx: submit sends otherExpenses"

# 2e. Cost box - show a breakdown line when there are other expenses
$old2e = @'
          {estimatedLeftoverCost > 0 && (
            <div className="text-xs text-[var(--text-faint)] mt-1">
              includes Rs. {estimatedLeftoverCost.toLocaleString(undefined, { maximumFractionDigits: 2 })} carried over from leftover
            </div>
          )}
'@

$new2e = @'
          {estimatedLeftoverCost > 0 && (
            <div className="text-xs text-[var(--text-faint)] mt-1">
              includes Rs. {estimatedLeftoverCost.toLocaleString(undefined, { maximumFractionDigits: 2 })} carried over from leftover
            </div>
          )}
          {estimatedExpensesTotal > 0 && (
            <div className="text-xs text-[var(--text-faint)] mt-1">
              includes Rs. {estimatedExpensesTotal.toLocaleString(undefined, { maximumFractionDigits: 2 })} other expenses (labour, etc.)
            </div>
          )}
'@

Apply-Replacement -FilePath $newBatchPath -Old $old2e -New $new2e -Label "new/page.tsx: cost box breakdown line"

# 2f. Insert the "Other Expenses (this batch)" card between the raw
#     material card and the Output Yield / Wastage card.
$old2f = @'
      </div>

      <div className="rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-5 grid grid-cols-1 sm:grid-cols-2 gap-4">
        <div>
          <label className="text-sm text-[var(--text-muted)]">Output Yield (kg)</label>
'@

$new2f = @'
      </div>

      <div className="rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-5 space-y-4">
        <div className="flex items-center justify-between">
          <h2 className="text-sm font-semibold text-[var(--foreground)]">Other Expenses (this batch)</h2>
          <button type="button" onClick={addExpenseRow} className="rounded-lg border border-neutral-400 dark:border-neutral-600 px-3 py-1.5 text-xs text-[var(--foreground)] hover:bg-[var(--surface-hover)]">
            + Add Expense
          </button>
        </div>
        <p className="text-xs text-[var(--text-faint)] -mt-2">
          Labour, packaging, misc. costs for this batch alone. For shared monthly costs (electricity, rent, gas) use Monthly Expenses instead.
        </p>

        {expenseRows.length === 0 ? (
          <p className="text-xs text-[var(--text-faint)]">No other expenses added for this batch yet.</p>
        ) : (
          <div className="space-y-2">
            {expenseRows.map((row) => (
              <div key={row.id} className="flex flex-col sm:flex-row items-stretch sm:items-center gap-2">
                <input
                  value={row.name}
                  onChange={(e) => updateExpenseRow(row.id, { name: e.target.value })}
                  type="text"
                  placeholder="e.g. Labour - Ali"
                  className="flex-1 rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]"
                />
                <input
                  value={row.amount}
                  onChange={(e) => updateExpenseRow(row.id, { amount: e.target.value })}
                  type="number"
                  step="any"
                  placeholder="Amount"
                  className="w-full sm:w-32 rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]"
                />
                <button type="button" onClick={() => removeExpenseRow(row.id)} className="rounded-lg border border-[var(--surface-border)] px-3 py-2 text-sm text-[var(--text-muted)] hover:bg-[var(--surface-hover)]">-</button>
              </div>
            ))}
          </div>
        )}
      </div>

      <div className="rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-5 grid grid-cols-1 sm:grid-cols-2 gap-4">
        <div>
          <label className="text-sm text-[var(--text-muted)]">Output Yield (kg)</label>
'@

Apply-Replacement -FilePath $newBatchPath -Old $old2f -New $new2f -Label "new/page.tsx: Other Expenses card"

Write-Host "`nStep 1 complete." -ForegroundColor Cyan
Write-Host "Next: restart your frontend dev server (pnpm dev) and check /batches/new" -ForegroundColor Cyan
Write-Host "Backend is already deployed for this (batch_expenses table + fn_create_production_batch p_other_expenses param)." -ForegroundColor Cyan
Write-Host "Next steps still coming: Monthly Expenses page, Settings allocation-method toggle, Batch detail cost breakdown." -ForegroundColor DarkCyan