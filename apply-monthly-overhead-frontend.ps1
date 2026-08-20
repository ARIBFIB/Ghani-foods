<#
  apply-monthly-overhead-frontend.ps1
  ------------------------------------------------------------------
  Run this from the project ROOT (same folder as export-code.ps1):
    D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods

  What this does (frontend-only — your backend/DB migrations from
  0007_batch_and_monthly_expenses.sql are already correct and untouched):

    1. lib/schemas.ts          -> adds batchExpenseSchema, monthlyExpenseSchema
    2. lib/store.ts             -> adds overheadAllocationMethod to AppSettings
    3. app/(dashboard)/batches/[id]/page.tsx
                                 -> replaces the old "Allocate Month-End
                                    Overhead" dialog (fn_allocate_overhead,
                                    which conflicts with the new system) with
                                    an "Add Expense" dialog (fn_add_batch_expense)
                                    + shows batch_expenses and
                                    batch_monthly_overhead_allocations
    4. app/(dashboard)/monthly-expenses/page.tsx  -> NEW page: add/remove
                                    monthly expenses + run fn_allocate_monthly_overhead
    5. components/ui/sidebar-component.tsx -> adds "Monthly Expenses" nav link
    6. app/(dashboard)/settings/page.tsx -> adds Overhead Allocation Method toggle
    7. apps/backend/supabase/functions/batches-overhead -> disabled (renamed),
       since it is dead code (frontend calls supabase.rpc directly and never
       hit this edge function) and calls the OLD conflicting fn_allocate_overhead.

  SAFETY:
    - Every modified file is copied to <file>.bak-<timestamp> first,
      matching your project's own backup convention.
    - Each text patch only applies if its exact anchor text is found
      EXACTLY ONCE in the file. If not found (e.g. you've since edited
      the file), that step is SKIPPED with a warning — nothing is
      force-applied or corrupted.
    - After running, remember to:
        supabase functions deploy   (only if you re-enable batches-overhead later)
        cd apps/frontend && npm run build   (to verify it compiles)
------------------------------------------------------------------#>

$ErrorActionPreference = "Stop"
$root = Get-Location
$ts = Get-Date -Format "yyyyMMdd-HHmmss"

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  Monthly Overhead / Batch Expenses Frontend Patch" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Root: $root`n"

function Backup-File($path) {
    if (Test-Path $path) {
        $bak = "$path.bak-$ts"
        Copy-Item $path $bak -Force
        Write-Host "  Backed up -> $bak" -ForegroundColor DarkGray
    }
}

function Edit-File($path, $old, $new, $label) {
    if (-not (Test-Path $path)) {
        Write-Warning "SKIP [$label]: file not found -> $path"
        return
    }
    $content = Get-Content -Raw -LiteralPath $path
    $count = ([regex]::Matches($content, [regex]::Escape($old))).Count
    if ($count -eq 1) {
        $newContent = $content.Replace($old, $new)
        Set-Content -LiteralPath $path -Value $newContent -NoNewline -Encoding UTF8
        Write-Host "  OK   [$label]" -ForegroundColor Green
    } elseif ($count -eq 0) {
        Write-Warning "SKIP [$label]: anchor text not found (file may already be edited) -> $path"
    } else {
        Write-Warning "SKIP [$label]: anchor text found $count times (expected 1, ambiguous) -> $path"
    }
}

# ------------------------------------------------------------------
# 1. lib/schemas.ts
# ------------------------------------------------------------------
$schemasPath = Join-Path $root "apps\frontend\lib\schemas.ts"
Write-Host "`n[1/7] apps/frontend/lib/schemas.ts"
Backup-File $schemasPath
Edit-File $schemasPath `
@'
export type OverheadFormValues = z.infer<typeof overheadSchema>;
'@ `
@'
export type OverheadFormValues = z.infer<typeof overheadSchema>;

// ---------------------------------------------------------------------------
// Batch Expenses & Monthly Overhead (0007)
// ---------------------------------------------------------------------------

export const batchExpenseSchema = z.object({
  name: z.string().trim().min(1, "Expense name is required"),
  amount: z.coerce.number().min(0, "Cannot be negative"),
});
export type BatchExpenseFormValues = z.infer<typeof batchExpenseSchema>;

export const monthlyExpenseSchema = z.object({
  month: z.string().min(1, "Month is required"),
  name: z.string().trim().min(1, "Expense name is required"),
  amount: z.coerce.number().min(0, "Cannot be negative"),
});
export type MonthlyExpenseFormValues = z.infer<typeof monthlyExpenseSchema>;
'@ `
"schemas.ts: add batchExpenseSchema/monthlyExpenseSchema"

# ------------------------------------------------------------------
# 2. lib/store.ts  (AppSettings gains overheadAllocationMethod)
# ------------------------------------------------------------------
$storePath = Join-Path $root "apps\frontend\lib\store.ts"
Write-Host "`n[2/7] apps/frontend/lib/store.ts"
Backup-File $storePath

Edit-File $storePath `
@'
function mapSettingsRow(row: any): AppSettings {
  return {
    businessName: row.business_name,
    address: row.address,
    invoiceFooterText: row.invoice_footer_text ?? "",
    defaultProfitMarginPercent: Number(row.default_profit_margin_percent),
    lowStockThresholdDefault: Number(row.low_stock_threshold_default),
  };
}
'@ `
@'
function mapSettingsRow(row: any): AppSettings {
  return {
    businessName: row.business_name,
    address: row.address,
    invoiceFooterText: row.invoice_footer_text ?? "",
    defaultProfitMarginPercent: Number(row.default_profit_margin_percent),
    lowStockThresholdDefault: Number(row.low_stock_threshold_default),
    overheadAllocationMethod: (row.overhead_allocation_method ?? "equal") as "equal" | "proportional_kg",
  };
}
'@ `
"store.ts: mapSettingsRow"

Edit-File $storePath `
@'
export type AppSettings = {
  businessName: string;
  address: string;
  invoiceFooterText: string;
  defaultProfitMarginPercent: number;
  lowStockThresholdDefault: number;
};
'@ `
@'
export type AppSettings = {
  businessName: string;
  address: string;
  invoiceFooterText: string;
  defaultProfitMarginPercent: number;
  lowStockThresholdDefault: number;
  overheadAllocationMethod: "equal" | "proportional_kg";
};
'@ `
"store.ts: AppSettings type"

Edit-File $storePath `
@'
const emptySettings: AppSettings = {
  businessName: "",
  address: "",
  invoiceFooterText: "",
  defaultProfitMarginPercent: 20,
  lowStockThresholdDefault: 50,
};
'@ `
@'
const emptySettings: AppSettings = {
  businessName: "",
  address: "",
  invoiceFooterText: "",
  defaultProfitMarginPercent: 20,
  lowStockThresholdDefault: 50,
  overheadAllocationMethod: "equal",
};
'@ `
"store.ts: emptySettings"

Edit-File $storePath `
@'
    if (patch.lowStockThresholdDefault !== undefined) payload.low_stock_threshold_default = patch.lowStockThresholdDefault;

    const { data, error } = await supabase.from("app_settings").upsert(payload).select().single();
'@ `
@'
    if (patch.lowStockThresholdDefault !== undefined) payload.low_stock_threshold_default = patch.lowStockThresholdDefault;
    if (patch.overheadAllocationMethod !== undefined) payload.overhead_allocation_method = patch.overheadAllocationMethod;

    const { data, error } = await supabase.from("app_settings").upsert(payload).select().single();
'@ `
"store.ts: updateSettings payload mapping"

# ------------------------------------------------------------------
# 3. app/(dashboard)/batches/[id]/page.tsx  -> full rewrite
# ------------------------------------------------------------------
$batchDetailPath = Join-Path $root "apps\frontend\app\(dashboard)\batches\[id]\page.tsx"
Write-Host "`n[3/7] apps/frontend/app/(dashboard)/batches/[id]/page.tsx"
if (Test-Path $batchDetailPath) {
    Backup-File $batchDetailPath
    $batchDetailContent = @'
"use client";

import { use, useEffect, useState } from "react";
import { NavLink } from "@/components/ui/nav-link";
import { useNavigationLoading } from "@/lib/navigation-loading-context";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { toast } from "@/components/ui/toast";
import { useStore } from "@/lib/store";
import { createClient } from "@/lib/supabase/client";
import { batchExpenseSchema, type BatchExpenseFormValues } from "@/lib/schemas";

const supabase = createClient();

type BatchExpenseRow = { id: string; name: string; amount: number; createdAt: string };
type OverheadAllocationRow = {
  id: string;
  month: string;
  allocationMethod: string;
  totalMonthExpense: number;
  batchShare: number;
};

function AddExpenseDialog({
  open,
  onClose,
  batchId,
  onAdded,
}: {
  open: boolean;
  onClose: () => void;
  batchId: string;
  onAdded: () => void;
}) {
  const {
    register,
    handleSubmit,
    reset,
    formState: { errors, isSubmitting },
  } = useForm<BatchExpenseFormValues>({
    resolver: zodResolver(batchExpenseSchema),
    defaultValues: { name: "", amount: 0 },
  });

  if (!open) return null;

  const onSubmit = async (values: BatchExpenseFormValues) => {
    const { error } = await supabase.rpc("fn_add_batch_expense", {
      p_batch_id: batchId,
      p_name: values.name,
      p_amount: values.amount,
    });
    if (error) {
      toast.error(error.message);
      return;
    }
    toast.success(`Expense "${values.name}" (Rs. ${values.amount.toLocaleString()}) added to ${batchId}`);
    reset();
    onAdded();
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-3 sm:p-4">
      <form
        onSubmit={handleSubmit(onSubmit)}
        className="w-full max-w-sm rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-5 space-y-4 max-h-[90vh] overflow-y-auto"
      >
        <h2 className="text-lg font-semibold text-[var(--foreground)]">Add Batch Expense</h2>
        <p className="text-xs text-[var(--text-faint)] -mt-2">
          Labour, packaging, misc. costs for this batch alone. For shared costs (electricity, rent, gas) use the
          Monthly Expenses page instead.
        </p>
        <div className="space-y-3">
          <div>
            <label className="text-sm text-[var(--text-muted)]">Expense Name</label>
            <input
              {...register("name")}
              type="text"
              placeholder="e.g. Labour - Ali"
              className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]"
            />
            {errors.name && <p className="text-xs text-red-400 mt-1">{errors.name.message}</p>}
          </div>
          <div>
            <label className="text-sm text-[var(--text-muted)]">Amount</label>
            <input
              {...register("amount")}
              type="number"
              step="any"
              className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]"
            />
            {errors.amount && <p className="text-xs text-red-400 mt-1">{errors.amount.message}</p>}
          </div>
        </div>
        <div className="flex justify-end gap-2 pt-2">
          <button
            type="button"
            onClick={() => {
              reset();
              onClose();
            }}
            className="rounded-lg px-4 py-2 text-sm text-[var(--text-secondary)] hover:bg-[var(--surface-hover)]"
          >
            Cancel
          </button>
          <button
            type="submit"
            disabled={isSubmitting}
            className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-50 dark:text-neutral-50 dark:text-neutral-950 hover:bg-neutral-200 disabled:opacity-50"
          >
            {isSubmitting ? "Saving..." : "Save"}
          </button>
        </div>
      </form>
    </div>
  );
}

export default function BatchDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const { navigate } = useNavigationLoading();
  const batch = useStore((s) => s.productionBatches.find((b) => b.id === id));
  const loadProductionBatches = useStore((s) => s.loadProductionBatches);
  const [dialogOpen, setDialogOpen] = useState(false);
  const [expenses, setExpenses] = useState<BatchExpenseRow[]>([]);
  const [allocations, setAllocations] = useState<OverheadAllocationRow[]>([]);
  const [loadingExtras, setLoadingExtras] = useState(false);

  const loadExtras = async () => {
    if (!id) return;
    setLoadingExtras(true);
    const [expensesRes, allocationsRes] = await Promise.all([
      supabase.from("batch_expenses").select("*").eq("batch_id", id).order("created_at", { ascending: false }),
      supabase
        .from("batch_monthly_overhead_allocations")
        .select("*")
        .eq("batch_id", id)
        .order("month", { ascending: false }),
    ]);
    setExpenses(
      (expensesRes.data ?? []).map((r: any) => ({
        id: r.id,
        name: r.name,
        amount: Number(r.amount),
        createdAt: r.created_at,
      }))
    );
    setAllocations(
      (allocationsRes.data ?? []).map((r: any) => ({
        id: r.id,
        month: r.month,
        allocationMethod: r.allocation_method,
        totalMonthExpense: Number(r.total_month_expense),
        batchShare: Number(r.batch_share),
      }))
    );
    setLoadingExtras(false);
  };

  useEffect(() => {
    loadExtras();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [id]);

  const handleAdded = async () => {
    await Promise.all([loadExtras(), loadProductionBatches()]);
  };

  if (!batch) {
    return (
      <div className="space-y-4">
        <NavLink href="/batches" className="text-sm text-[var(--text-muted)] hover:underline">
          &larr; Back to Batches
        </NavLink>
        <p className="text-[var(--text-muted)]">Batch not found.</p>
      </div>
    );
  }

  const expensesTotal = expenses.reduce((t, e) => t + e.amount, 0);
  const allocationsTotal = allocations.reduce((t, a) => t + a.batchShare, 0);

  return (
    <div className="space-y-6">
      <div className="text-sm text-[var(--text-muted)]">
        <NavLink href="/batches" className="hover:underline text-[var(--text-secondary)]">
          Batches
        </NavLink>{" "}
        / <span className="text-[var(--foreground)]">{batch.id}</span>
      </div>

      <div className="rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-5">
        <h1 className="text-xl font-semibold text-[var(--foreground)]">{batch.id}</h1>
        <p className="text-sm text-[var(--text-muted)] mt-1">Batch Date: {batch.batchDate}</p>

        <div className="mt-5 grid grid-cols-2 sm:grid-cols-4 gap-4">
          <div>
            <div className="text-[var(--text-muted)] text-xs">Output Yield</div>
            <div className="text-lg font-semibold text-[var(--foreground)] mt-1">{batch.outputYieldKg} kg</div>
          </div>
          <div>
            <div className="text-[var(--text-muted)] text-xs">Wastage</div>
            <div className="text-lg font-semibold text-[var(--foreground)] mt-1">{batch.wastageKg} kg</div>
          </div>
          <div>
            <div className="text-[var(--text-muted)] text-xs">Leftover Remaining</div>
            <div className="text-lg font-semibold text-[var(--foreground)] mt-1">{batch.leftoverQtyKg} kg</div>
          </div>
          <div>
            <div className="text-[var(--text-muted)] text-xs">Effective Cost/Kg</div>
            <div className="text-lg font-semibold text-[var(--foreground)] mt-1">
              Rs. {batch.bulkCostPerKg.toLocaleString(undefined, { maximumFractionDigits: 2 })}
            </div>
          </div>
        </div>

        {batch.overheadTotal > 0 && (
          <div className="mt-4 text-xs text-amber-400">
            Rs. {batch.overheadTotal.toLocaleString()} in expenses + monthly overhead spread across this batch's
            output.
          </div>
        )}

        {batch.leftoverSourceBatchId && batch.leftoverKgConsumed && (
          <div className="mt-2 text-xs text-blue-400">
            Includes {batch.leftoverKgConsumed} kg of leftover bulk product carried forward from{" "}
            <NavLink href={`/batches/${batch.leftoverSourceBatchId}`} className="underline">
              {batch.leftoverSourceBatchId}
            </NavLink>{" "}
            (FIFO — cost blended into this batch's effective cost/kg).
          </div>
        )}
      </div>

      <div className="rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-5 space-y-4">
        <div className="flex items-center justify-between">
          <h2 className="text-sm font-semibold text-[var(--foreground)]">Other Expenses (this batch)</h2>
          <button
            onClick={() => setDialogOpen(true)}
            className="rounded-lg border border-neutral-400 dark:border-neutral-600 px-3 py-1.5 text-xs text-[var(--foreground)] hover:bg-[var(--surface-hover)]"
          >
            + Add Expense
          </button>
        </div>
        {loadingExtras ? (
          <p className="text-xs text-[var(--text-faint)]">Loading...</p>
        ) : expenses.length === 0 ? (
          <p className="text-xs text-[var(--text-faint)]">No expenses added for this batch yet.</p>
        ) : (
          <div className="space-y-1">
            {expenses.map((e) => (
              <div key={e.id} className="flex items-center justify-between text-sm">
                <span className="text-[var(--text-secondary)]">{e.name}</span>
                <span className="text-[var(--foreground)]">Rs. {e.amount.toLocaleString()}</span>
              </div>
            ))}
            <div className="flex items-center justify-between text-sm border-t border-[var(--surface-border)] pt-1 mt-1 font-medium">
              <span className="text-[var(--text-muted)]">Total</span>
              <span className="text-[var(--foreground)]">Rs. {expensesTotal.toLocaleString()}</span>
            </div>
          </div>
        )}
      </div>

      <div className="rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-5 space-y-4">
        <h2 className="text-sm font-semibold text-[var(--foreground)]">Monthly Overhead Share</h2>
        <p className="text-xs text-[var(--text-faint)] -mt-2">
          Set via the{" "}
          <NavLink href="/monthly-expenses" className="underline">
            Monthly Expenses
          </NavLink>{" "}
          page. Re-running allocation for a month replaces this batch's share.
        </p>
        {allocations.length === 0 ? (
          <p className="text-xs text-[var(--text-faint)]">No monthly overhead allocated to this batch yet.</p>
        ) : (
          <div className="space-y-1">
            {allocations.map((a) => (
              <div key={a.id} className="flex items-center justify-between text-sm">
                <span className="text-[var(--text-secondary)]">
                  {a.month} ({a.allocationMethod === "proportional_kg" ? "by output kg" : "equal split"})
                </span>
                <span className="text-[var(--foreground)]">
                  Rs. {a.batchShare.toLocaleString(undefined, { maximumFractionDigits: 2 })}
                </span>
              </div>
            ))}
            <div className="flex items-center justify-between text-sm border-t border-[var(--surface-border)] pt-1 mt-1 font-medium">
              <span className="text-[var(--text-muted)]">Total</span>
              <span className="text-[var(--foreground)]">
                Rs. {allocationsTotal.toLocaleString(undefined, { maximumFractionDigits: 2 })}
              </span>
            </div>
          </div>
        )}
      </div>

      <div className="flex gap-2">
        <button
          onClick={() => navigate(`/finished-cartons?batchId=${batch.id}`)}
          className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-50 dark:text-neutral-50 dark:text-neutral-950 hover:opacity-90 transition-opacity"
        >
          Send to Packaging
        </button>
      </div>

      <AddExpenseDialog open={dialogOpen} onClose={() => setDialogOpen(false)} batchId={batch.id} onAdded={handleAdded} />
    </div>
  );
}
'@
    Set-Content -LiteralPath $batchDetailPath -Value $batchDetailContent -NoNewline -Encoding UTF8
    Write-Host "  OK   [batches/[id]/page.tsx rewritten]" -ForegroundColor Green
} else {
    Write-Warning "SKIP: apps/frontend/app/(dashboard)/batches/[id]/page.tsx not found"
}

# ------------------------------------------------------------------
# 4. app/(dashboard)/monthly-expenses/page.tsx  -> NEW FILE
# ------------------------------------------------------------------
Write-Host "`n[4/7] apps/frontend/app/(dashboard)/monthly-expenses/page.tsx (new)"
$monthlyExpensesDir = Join-Path $root "apps\frontend\app\(dashboard)\monthly-expenses"
New-Item -ItemType Directory -Force -Path $monthlyExpensesDir | Out-Null
$monthlyExpensesPath = Join-Path $monthlyExpensesDir "page.tsx"
Backup-File $monthlyExpensesPath
$monthlyExpensesContent = @'
"use client";

import { useEffect, useMemo, useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { toast } from "@/components/ui/toast";
import { useStore } from "@/lib/store";
import { createClient } from "@/lib/supabase/client";
import { monthlyExpenseSchema, type MonthlyExpenseFormValues } from "@/lib/schemas";

const supabase = createClient();

type MonthlyExpenseRow = { id: string; month: string; name: string; amount: number };
type AllocationResultRow = { batchId: string; outputYieldKg: number; share: number };

function currentMonthValue(): string {
  const now = new Date();
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}`;
}

function nextMonthStr(m: string): string {
  const [y, mo] = m.split("-").map(Number);
  const d = new Date(y, mo, 1); // JS month is 0-indexed, so mo (1-12) rolls forward correctly
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-01`;
}

export default function MonthlyExpensesPage() {
  const settings = useStore((s) => s.settings);
  const loadProductionBatches = useStore((s) => s.loadProductionBatches);

  const [month, setMonth] = useState(currentMonthValue());
  const [rows, setRows] = useState<MonthlyExpenseRow[]>([]);
  const [loading, setLoading] = useState(false);
  const [method, setMethod] = useState<"equal" | "proportional_kg">("equal");
  const [allocating, setAllocating] = useState(false);
  const [lastResult, setLastResult] = useState<{
    batchCount: number;
    totalExpense: number;
    allocations: AllocationResultRow[];
  } | null>(null);

  const {
    register,
    handleSubmit,
    reset,
    formState: { errors, isSubmitting },
  } = useForm<MonthlyExpenseFormValues>({
    resolver: zodResolver(monthlyExpenseSchema),
    defaultValues: { month: currentMonthValue(), name: "", amount: 0 },
  });

  useEffect(() => {
    setMethod(settings.overheadAllocationMethod ?? "equal");
  }, [settings.overheadAllocationMethod]);

  const loadRows = async (m: string) => {
    setLoading(true);
    const { data } = await supabase
      .from("monthly_expenses")
      .select("*")
      .gte("month", `${m}-01`)
      .lt("month", nextMonthStr(m))
      .order("created_at", { ascending: false });
    setRows((data ?? []).map((r: any) => ({ id: r.id, month: r.month, name: r.name, amount: Number(r.amount) })));
    setLoading(false);
  };

  useEffect(() => {
    loadRows(month);
    setLastResult(null);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [month]);

  const total = useMemo(() => rows.reduce((t, r) => t + r.amount, 0), [rows]);

  const onSubmit = async (values: MonthlyExpenseFormValues) => {
    const { error } = await supabase.from("monthly_expenses").insert({
      month: `${month}-01`,
      name: values.name,
      amount: values.amount,
    });
    if (error) {
      toast.error(error.message);
      return;
    }
    toast.success(`"${values.name}" (Rs. ${values.amount.toLocaleString()}) added for ${month}`);
    reset({ month, name: "", amount: 0 });
    await loadRows(month);
  };

  const deleteRow = async (id: string) => {
    const { error } = await supabase.from("monthly_expenses").delete().eq("id", id);
    if (error) {
      toast.error(error.message);
      return;
    }
    await loadRows(month);
  };

  const runAllocation = async () => {
    setAllocating(true);
    const { data, error } = await supabase.rpc("fn_allocate_monthly_overhead", {
      p_month: `${month}-01`,
      p_method: method,
    });
    setAllocating(false);
    if (error) {
      toast.error(error.message);
      return;
    }
    const result = data as any;
    if (result?.warning) {
      toast.error(result.warning);
      setLastResult({ batchCount: 0, totalExpense: Number(result.totalExpense ?? 0), allocations: [] });
      return;
    }
    setLastResult({
      batchCount: result.batchCount,
      totalExpense: Number(result.totalExpense),
      allocations: (result.allocations ?? []).map((a: any) => ({
        batchId: a.batchId,
        outputYieldKg: Number(a.outputYieldKg),
        share: Number(a.share),
      })),
    });
    toast.success(`Allocated Rs. ${Number(result.totalExpense).toLocaleString()} across ${result.batchCount} batch(es) for ${month}`);
    await loadProductionBatches();
  };

  return (
    <div className="space-y-6 max-w-3xl">
      <h1 className="text-xl font-semibold text-[var(--foreground)]">Monthly Expenses</h1>
      <p className="text-sm text-[var(--text-muted)]">
        Accumulative shared costs (electricity, gas, rent, etc.) for a month, split across every batch produced that
        month.
      </p>

      <div className="rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-5 space-y-4">
        <div>
          <label className="text-sm text-[var(--text-muted)]">Month</label>
          <input
            type="month"
            value={month}
            onChange={(e) => setMonth(e.target.value)}
            className="mt-1 w-full sm:w-48 rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]"
          />
        </div>

        <form onSubmit={handleSubmit(onSubmit)} className="flex flex-col sm:flex-row items-stretch sm:items-end gap-2">
          <div className="flex-1">
            <label className="text-sm text-[var(--text-muted)]">Expense Name</label>
            <input
              {...register("name")}
              type="text"
              placeholder="e.g. Electricity"
              className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]"
            />
            {errors.name && <p className="text-xs text-red-400 mt-1">{errors.name.message}</p>}
          </div>
          <div className="w-full sm:w-40">
            <label className="text-sm text-[var(--text-muted)]">Amount</label>
            <input
              {...register("amount")}
              type="number"
              step="any"
              className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]"
            />
            {errors.amount && <p className="text-xs text-red-400 mt-1">{errors.amount.message}</p>}
          </div>
          <button
            type="submit"
            disabled={isSubmitting}
            className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-50 dark:text-neutral-50 dark:text-neutral-950 hover:bg-neutral-200 disabled:opacity-50"
          >
            {isSubmitting ? "Adding..." : "+ Add"}
          </button>
        </form>

        {loading ? (
          <p className="text-xs text-[var(--text-faint)]">Loading...</p>
        ) : rows.length === 0 ? (
          <p className="text-xs text-[var(--text-faint)]">No expenses added for {month} yet.</p>
        ) : (
          <div className="space-y-1">
            {rows.map((r) => (
              <div key={r.id} className="flex items-center justify-between text-sm">
                <span className="text-[var(--text-secondary)]">{r.name}</span>
                <div className="flex items-center gap-3">
                  <span className="text-[var(--foreground)]">Rs. {r.amount.toLocaleString()}</span>
                  <button onClick={() => deleteRow(r.id)} className="text-xs text-red-400 hover:underline">
                    Remove
                  </button>
                </div>
              </div>
            ))}
            <div className="flex items-center justify-between text-sm border-t border-[var(--surface-border)] pt-1 mt-1 font-medium">
              <span className="text-[var(--text-muted)]">Total for {month}</span>
              <span className="text-[var(--foreground)]">Rs. {total.toLocaleString()}</span>
            </div>
          </div>
        )}
      </div>

      <div className="rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-5 space-y-4">
        <h2 className="text-sm font-semibold text-[var(--foreground)]">Run Allocation</h2>
        <p className="text-xs text-[var(--text-faint)] -mt-2">
          Splits {month}'s total (Rs. {total.toLocaleString()}) across every batch created that month. Safe to
          re-run — it replaces the previous allocation for this month only.
        </p>

        <div>
          <label className="text-sm text-[var(--text-muted)]">Allocation Method</label>
          <select
            value={method}
            onChange={(e) => setMethod(e.target.value as "equal" | "proportional_kg")}
            className="mt-1 w-full sm:w-64 rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]"
          >
            <option value="equal">Equal split across batches</option>
            <option value="proportional_kg">Proportional to output (kg)</option>
          </select>
        </div>

        <button
          onClick={runAllocation}
          disabled={allocating || total <= 0}
          className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-50 dark:text-neutral-50 dark:text-neutral-950 hover:bg-neutral-200 disabled:opacity-50"
        >
          {allocating ? "Allocating..." : `Allocate ${month}'s Expenses`}
        </button>

        {lastResult && (
          <div className="mt-3 space-y-1 rounded-lg border border-[var(--surface-border)] bg-[var(--background)] p-3">
            {lastResult.allocations.length === 0 ? (
              <p className="text-xs text-[var(--text-faint)]">No batches found in {month} — nothing allocated.</p>
            ) : (
              <>
                <p className="text-xs text-[var(--text-muted)]">
                  Rs. {lastResult.totalExpense.toLocaleString()} split across {lastResult.batchCount} batch(es):
                </p>
                {lastResult.allocations.map((a) => (
                  <div key={a.batchId} className="flex items-center justify-between text-sm">
                    <span className="text-[var(--text-secondary)]">
                      {a.batchId} ({a.outputYieldKg} kg)
                    </span>
                    <span className="text-[var(--foreground)]">
                      Rs. {a.share.toLocaleString(undefined, { maximumFractionDigits: 2 })}
                    </span>
                  </div>
                ))}
              </>
            )}
          </div>
        )}
      </div>
    </div>
  );
}
'@
Set-Content -LiteralPath $monthlyExpensesPath -Value $monthlyExpensesContent -NoNewline -Encoding UTF8
Write-Host "  OK   [monthly-expenses/page.tsx created]" -ForegroundColor Green

# ------------------------------------------------------------------
# 5. components/ui/sidebar-component.tsx  -> add nav link
# ------------------------------------------------------------------
$sidebarPath = Join-Path $root "apps\frontend\components\ui\sidebar-component.tsx"
Write-Host "`n[5/7] apps/frontend/components/ui/sidebar-component.tsx"
Backup-File $sidebarPath
Edit-File $sidebarPath `
@'
            { icon: <Task size={16} className="text-[var(--foreground)]" />, label: "All Batches", href: "/batches" },
            { icon: <AddLarge size={16} className="text-[var(--foreground)]" />, label: "New Batch", href: "/batches/new" },
          ],
        },
      ],
    },
    "finished-cartons": {
'@ `
@'
            { icon: <Task size={16} className="text-[var(--foreground)]" />, label: "All Batches", href: "/batches" },
            { icon: <AddLarge size={16} className="text-[var(--foreground)]" />, label: "New Batch", href: "/batches/new" },
          ],
        },
        {
          title: "Costs",
          items: [
            { icon: <Report size={16} className="text-[var(--foreground)]" />, label: "Monthly Expenses", href: "/monthly-expenses" },
          ],
        },
      ],
    },
    "finished-cartons": {
'@ `
"sidebar-component.tsx: add Monthly Expenses nav link"

# ------------------------------------------------------------------
# 6. app/(dashboard)/settings/page.tsx  -> allocation method toggle
# ------------------------------------------------------------------
$settingsPagePath = Join-Path $root "apps\frontend\app\(dashboard)\settings\page.tsx"
Write-Host "`n[6/7] apps/frontend/app/(dashboard)/settings/page.tsx"
Backup-File $settingsPagePath

Edit-File $settingsPagePath `
@'
const settingsSchema = z.object({
  businessName: z.string().trim().min(2, "Business name required"),
  address: z.string().trim().min(5, "Address required"),
  invoiceFooterText: z.string().trim(),
  defaultProfitMarginPercent: z.coerce.number().min(0, "Cannot be negative"),
  lowStockThresholdDefault: z.coerce.number().min(0, "Cannot be negative"),
});
'@ `
@'
const settingsSchema = z.object({
  businessName: z.string().trim().min(2, "Business name required"),
  address: z.string().trim().min(5, "Address required"),
  invoiceFooterText: z.string().trim(),
  defaultProfitMarginPercent: z.coerce.number().min(0, "Cannot be negative"),
  lowStockThresholdDefault: z.coerce.number().min(0, "Cannot be negative"),
  overheadAllocationMethod: z.enum(["equal", "proportional_kg"]),
});
'@ `
"settings/page.tsx: schema"

Edit-File $settingsPagePath `
@'
            <div>
              <label className="text-sm text-[var(--text-muted)]">Low-Stock Threshold Default</label>
              <input {...register("lowStockThresholdDefault")} type="number"
                className="mt-1 w-48 rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
              {errors.lowStockThresholdDefault && <p className="text-xs text-red-400 mt-1">{errors.lowStockThresholdDefault.message}</p>}
            </div>
          </div>
'@ `
@'
            <div>
              <label className="text-sm text-[var(--text-muted)]">Low-Stock Threshold Default</label>
              <input {...register("lowStockThresholdDefault")} type="number"
                className="mt-1 w-48 rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
              {errors.lowStockThresholdDefault && <p className="text-xs text-red-400 mt-1">{errors.lowStockThresholdDefault.message}</p>}
            </div>

            <div>
              <label className="text-sm text-[var(--text-muted)]">Monthly Overhead Allocation Method</label>
              <select {...register("overheadAllocationMethod")}
                className="mt-1 w-full sm:w-64 rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]">
                <option value="equal">Equal split across batches</option>
                <option value="proportional_kg">Proportional to output (kg)</option>
              </select>
              <p className="text-xs text-[var(--text-faint)] mt-1">
                Default method pre-selected on the Monthly Expenses page when splitting electricity/gas/rent across batches.
              </p>
            </div>
          </div>
'@ `
"settings/page.tsx: allocation method field"

# ------------------------------------------------------------------
# 7. Disable dead/conflicting edge function: batches-overhead
#    (frontend calls supabase.rpc('fn_allocate_overhead', ...) directly
#    via store.ts's old allocateOverhead action, which we've stopped
#    calling from the UI in step 3 above — this edge function was never
#    actually invoked by the frontend, but we disable it to avoid
#    accidental future use of the OLD conflicting allocation logic)
# ------------------------------------------------------------------
Write-Host "`n[7/7] Disabling dead edge function: batches-overhead"
$overheadFnDir = Join-Path $root "apps\backend\supabase\functions\batches-overhead"
$overheadFnDisabledDir = Join-Path $root "apps\backend\supabase\functions\_disabled-batches-overhead-$ts"
if (Test-Path $overheadFnDir) {
    Move-Item $overheadFnDir $overheadFnDisabledDir
    Write-Host "  OK   Renamed -> $overheadFnDisabledDir" -ForegroundColor Green
    Write-Host "       (safe to delete later once you confirm nothing references it)" -ForegroundColor DarkGray
} else {
    Write-Warning "SKIP: apps/backend/supabase/functions/batches-overhead not found"
}

Write-Host "`n==================================================" -ForegroundColor Cyan
Write-Host "  DONE" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host @"

Next steps:
  1. Run the DB migration if you haven't already:
       supabase db push
     (0007_batch_and_monthly_expenses.sql was already correct/applied per
     your earlier confirmation — this script only touched frontend files
     plus renamed the unused batches-overhead edge function.)

  2. Build check:
       cd apps\frontend
       npm run build

  3. Manually spot-check in the browser:
       - /batches/<id>            -> "Add Expense" button + expense list + overhead share list
       - /monthly-expenses         -> add expenses, run allocation
       - /settings?tab=profile     -> "Monthly Overhead Allocation Method" dropdown

  4. If anything looks off, every changed file has a .bak-$ts copy sitting
     right next to it in the same folder — just rename it back.

"@ -ForegroundColor Yellow