"use client";

import { use, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
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
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4">
      <form onSubmit={handleSubmit(onSubmit)} className="w-full max-w-sm rounded-xl border border-neutral-800 bg-neutral-900 p-5 space-y-4">
        <h2 className="text-lg font-semibold text-neutral-50">Allocate Month-End Overhead</h2>
        <div className="space-y-3">
          <div>
            <label className="text-sm text-neutral-400">Electricity</label>
            <input {...register("electricity")} type="number" step="any"
              className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
            {errors.electricity && <p className="text-xs text-red-400 mt-1">{errors.electricity.message}</p>}
          </div>
          <div>
            <label className="text-sm text-neutral-400">Gas</label>
            <input {...register("gas")} type="number" step="any"
              className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
            {errors.gas && <p className="text-xs text-red-400 mt-1">{errors.gas.message}</p>}
          </div>
          <div>
            <label className="text-sm text-neutral-400">Rent</label>
            <input {...register("rent")} type="number" step="any"
              className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
            {errors.rent && <p className="text-xs text-red-400 mt-1">{errors.rent.message}</p>}
          </div>
        </div>
        <div className="flex justify-end gap-2 pt-2">
          <button type="button" onClick={() => { reset(); onClose(); }} className="rounded-lg px-4 py-2 text-sm text-neutral-300 hover:bg-neutral-800">Cancel</button>
          <button type="submit" disabled={isSubmitting}
            className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200 disabled:opacity-50">
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
  const batch = useStore((s) => s.productionBatches.find((b) => b.id === id));
  const [dialogOpen, setDialogOpen] = useState(false);

  if (!batch) {
    return (
      <div className="space-y-4">
        <Link href="/batches" className="text-sm text-neutral-400 hover:underline">&larr; Back to Batches</Link>
        <p className="text-neutral-400">Batch not found.</p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="text-sm text-neutral-400">
        <Link href="/batches" className="hover:underline text-neutral-300">Batches</Link>{" "}
        / <span className="text-neutral-50">{batch.id}</span>
      </div>

      <div className="rounded-xl border border-neutral-800 bg-neutral-900 p-5">
        <h1 className="text-xl font-semibold text-neutral-50">{batch.id}</h1>
        <p className="text-sm text-neutral-400 mt-1">Batch Date: {batch.batchDate}</p>

        <div className="mt-5 grid grid-cols-2 sm:grid-cols-4 gap-4">
          <div>
            <div className="text-neutral-400 text-xs">Output Yield</div>
            <div className="text-lg font-semibold text-neutral-50 mt-1">{batch.outputYieldKg} kg</div>
          </div>
          <div>
            <div className="text-neutral-400 text-xs">Wastage</div>
            <div className="text-lg font-semibold text-neutral-50 mt-1">{batch.wastageKg} kg</div>
          </div>
          <div>
            <div className="text-neutral-400 text-xs">Leftover Remaining</div>
            <div className="text-lg font-semibold text-neutral-50 mt-1">{batch.leftoverQtyKg} kg</div>
          </div>
          <div>
            <div className="text-neutral-400 text-xs">Effective Cost/Kg</div>
            <div className="text-lg font-semibold text-neutral-50 mt-1">
              Rs. {batch.bulkCostPerKg.toLocaleString(undefined, { maximumFractionDigits: 2 })}
            </div>
          </div>
        </div>

        {batch.overheadTotal > 0 && (
          <div className="mt-4 text-xs text-amber-400">
            Overhead of Rs. {batch.overheadTotal.toLocaleString()} allocated across this batch's output.
          </div>
        )}
      </div>

      <div className="flex gap-2">
        <button onClick={() => setDialogOpen(true)} className="rounded-lg border border-neutral-700 px-4 py-2 text-sm text-neutral-200 hover:bg-neutral-800">
          Allocate Month-End Overhead
        </button>
        <button onClick={() => router.push(`/finished-cartons?batchId=${batch.id}`)} className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200">
          Send to Packaging
        </button>
      </div>

      <OverheadDialog open={dialogOpen} onClose={() => setDialogOpen(false)} batchId={batch.id} />
    </div>
  );
}