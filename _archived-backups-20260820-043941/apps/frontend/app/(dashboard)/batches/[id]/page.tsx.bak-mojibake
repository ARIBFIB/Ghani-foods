"use client";

import { use, useState } from "react";
import { NavLink } from "@/components/ui/nav-link";
import { useRouter } from "next/navigation";
import { useNavigationLoading } from "@/lib/navigation-loading-context";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { toast } from "sonner";
import { useStore } from "@/lib/store";
import { overheadSchema, type OverheadFormValues } from "@/lib/schemas";

function OverheadDialog({ open, onClose, batchId }: { open: boolean; onClose: () => void; batchId: string }) {
  const allocateOverhead = useStore((s) => s.allocateOverhead);
  const {
    register,
    handleSubmit,
    reset,
    formState: { errors, isSubmitting },
  } = useForm<OverheadFormValues>({
    resolver: zodResolver(overheadSchema),
    defaultValues: { electricity: 0, gas: 0, rent: 0 },
  });

  if (!open) return null;

  const onSubmit = async (values: OverheadFormValues) => {
    allocateOverhead(batchId, values.electricity, values.gas, values.rent);
    toast.success(`Overhead of Rs. ${(values.electricity + values.gas + values.rent).toLocaleString()} allocated to ${batchId}`);
    reset();
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-3 sm:p-4">
      <form onSubmit={handleSubmit(onSubmit)} className="w-full max-w-sm rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-5 space-y-4 max-h-[90vh] overflow-y-auto">
        <h2 className="text-lg font-semibold text-[var(--foreground)]">Allocate Month-End Overhead</h2>
        <div className="space-y-3">
          <div>
            <label className="text-sm text-[var(--text-muted)]">Electricity</label>
            <input {...register("electricity")} type="number" step="any"
              className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
            {errors.electricity && <p className="text-xs text-red-400 mt-1">{errors.electricity.message}</p>}
          </div>
          <div>
            <label className="text-sm text-[var(--text-muted)]">Gas</label>
            <input {...register("gas")} type="number" step="any"
              className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
            {errors.gas && <p className="text-xs text-red-400 mt-1">{errors.gas.message}</p>}
          </div>
          <div>
            <label className="text-sm text-[var(--text-muted)]">Rent</label>
            <input {...register("rent")} type="number" step="any"
              className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
            {errors.rent && <p className="text-xs text-red-400 mt-1">{errors.rent.message}</p>}
          </div>
        </div>
        <div className="flex justify-end gap-2 pt-2">
          <button type="button" onClick={() => { reset(); onClose(); }} className="rounded-lg px-4 py-2 text-sm text-[var(--text-secondary)] hover:bg-[var(--surface-hover)]">Cancel</button>
          <button type="submit" disabled={isSubmitting}
            className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-50 dark:text-neutral-50 dark:text-neutral-950 hover:bg-neutral-200 disabled:opacity-50">
            {isSubmitting ? "Saving..." : "Save"}
          </button>
        </div>
      </form>
    </div>
  );
}

export default function BatchDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const router = useRouter();
  const { navigate } = useNavigationLoading();
  const batch = useStore((s) => s.productionBatches.find((b) => b.id === id));
  const [dialogOpen, setDialogOpen] = useState(false);

  if (!batch) {
    return (
      <div className="space-y-4">
        <NavLink href="/batches" className="text-sm text-[var(--text-muted)] hover:underline">&larr; Back to Batches</NavLink>
        <p className="text-[var(--text-muted)]">Batch not found.</p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="text-sm text-[var(--text-muted)]">
        <NavLink href="/batches" className="hover:underline text-[var(--text-secondary)]">Batches</NavLink>{" "}
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
            Overhead of Rs. {batch.overheadTotal.toLocaleString()} allocated across this batch's output.
          </div>
        )}

        {batch.leftoverSourceBatchId && batch.leftoverKgConsumed && (
          <div className="mt-2 text-xs text-blue-400">
            Includes {batch.leftoverKgConsumed} kg of leftover bulk product carried forward from{" "}
            <NavLink href={`/batches/${batch.leftoverSourceBatchId}`} className="underline">{batch.leftoverSourceBatchId}</NavLink>{" "}
            (FIFO â€” cost blended into this batch's effective cost/kg).
          </div>
        )}
      </div>

      <div className="flex gap-2">
        <button onClick={() => setDialogOpen(true)} className="rounded-lg border border-neutral-400 dark:border-neutral-600 px-4 py-2 text-sm text-[var(--foreground)] hover:bg-[var(--surface-hover)]">
          Allocate Month-End Overhead
        </button>
        <button onClick={() => navigate(`/finished-cartons?batchId=${batch.id}`)} className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-50 dark:text-neutral-50 dark:text-neutral-950 hover:opacity-90 transition-opacity">
          Send to Packaging
        </button>
      </div>

      <OverheadDialog open={dialogOpen} onClose={() => setDialogOpen(false)} batchId={batch.id} />
    </div>
  );
}