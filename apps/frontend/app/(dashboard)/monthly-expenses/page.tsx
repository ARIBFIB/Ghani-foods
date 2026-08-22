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
    setRows((data ?? []).map((r: Record<string, unknown>) => ({ id: r.id, month: r.month, name: r.name, amount: Number(r.amount) })));
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
      allocations: (result.allocations ?? []).map((a: Record<string, unknown>) => ({
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
          re-run â€” it replaces the previous allocation for this month only.
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
              <p className="text-xs text-[var(--text-faint)]">No batches found in {month} â€” nothing allocated.</p>
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