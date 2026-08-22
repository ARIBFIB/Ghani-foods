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
      (expensesRes.data ?? []).map((r: Record<string, unknown>) => ({
        id: r.id,
        name: r.name,
        amount: Number(r.amount),
        createdAt: r.created_at,
      }))
    );
    setAllocations(
      (allocationsRes.data ?? []).map((r: Record<string, unknown>) => ({
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
            (FIFO â€” cost blended into this batch's effective cost/kg).
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