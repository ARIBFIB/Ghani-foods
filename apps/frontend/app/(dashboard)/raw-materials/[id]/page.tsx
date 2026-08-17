"use client";

import { use, useMemo, useState } from "react";
import Link from "next/link";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { toast } from "sonner";
import { useStore } from "@/lib/store";
import { purchaseSchema, type PurchaseFormValues } from "@/lib/schemas";

function RecordPurchaseDialog({ open, onClose, materialId }: { open: boolean; onClose: () => void; materialId: string }) {
  const recordPurchase = useStore((s) => s.recordPurchase);
  const {
    register,
    handleSubmit,
    reset,
    formState: { errors, isSubmitting },
  } = useForm<PurchaseFormValues>({ resolver: zodResolver(purchaseSchema) });

  if (!open) return null;

  const onSubmit = async (values: PurchaseFormValues) => {
    recordPurchase(materialId, values.qty, values.cost);
    toast.success("Purchase recorded â€” average cost updated");
    reset();
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-3 sm:p-4">
      <form onSubmit={handleSubmit(onSubmit)} className="w-full max-w-sm rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-5 space-y-4 max-h-[90vh] overflow-y-auto">
        <h2 className="text-lg font-semibold text-[var(--foreground)]">Record Purchase</h2>
        <div className="space-y-3">
          <div>
            <label className="text-sm text-[var(--text-muted)]">Quantity</label>
            <input {...register("qty")} type="number" step="any"
              className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
            {errors.qty && <p className="text-xs text-red-400 mt-1">{errors.qty.message}</p>}
          </div>
          <div>
            <label className="text-sm text-[var(--text-muted)]">Purchase Cost (per unit)</label>
            <input {...register("cost")} type="number" step="any"
              className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
            {errors.cost && <p className="text-xs text-red-400 mt-1">{errors.cost.message}</p>}
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

export default function RawMaterialDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const material = useStore((s) => s.rawMaterials.find((m) => m.id === id));
  const allReceipts = useStore((s) => s.receipts);
  const [dialogOpen, setDialogOpen] = useState(false);

  const receipts = useMemo(() => allReceipts.filter((r) => r.rawMaterialId === id), [allReceipts, id]);

  if (!material) {
    return (
      <div className="space-y-4">
        <Link href="/raw-materials" className="text-sm text-[var(--text-muted)] hover:underline">&larr; Back to Raw Materials</Link>
        <p className="text-[var(--text-muted)]">Raw material not found.</p>
      </div>
    );
  }

  const isLow = material.quantityInStock < material.lowStockThreshold;

  return (
    <div className="space-y-6">
      <div className="text-sm text-[var(--text-muted)]">
        <Link href="/raw-materials" className="hover:underline text-[var(--text-secondary)]">Raw Materials</Link>{" "}
        / <span className="text-[var(--foreground)]">{material.name}</span>
      </div>

      <div className="rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-5">
        <div className="flex items-start justify-between">
          <div>
            <h1 className="text-xl font-semibold text-[var(--foreground)]">{material.name}</h1>
            <p className="text-sm text-[var(--text-muted)] mt-1">Unit: {material.unit}</p>
          </div>
          <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ${
            isLow ? "bg-red-950 text-red-400 border border-red-900" : "bg-green-950 text-green-400 border border-green-900"
          }`}>
            {isLow ? "Low Stock" : "OK"}
          </span>
        </div>

        <div className="mt-5 grid grid-cols-2 sm:grid-cols-4 gap-4">
          <div>
            <div className="text-[var(--text-muted)] text-xs">Current Stock</div>
            <div className="text-lg font-semibold text-[var(--foreground)] mt-1">{material.quantityInStock} {material.unit}</div>
          </div>
          <div>
            <div className="text-[var(--text-muted)] text-xs">Avg Unit Cost</div>
            <div className="text-lg font-semibold text-[var(--foreground)] mt-1">Rs. {material.avgUnitCost.toLocaleString()}</div>
          </div>
          <div>
            <div className="text-[var(--text-muted)] text-xs">Low Stock Threshold</div>
            <div className="text-lg font-semibold text-[var(--foreground)] mt-1">{material.lowStockThreshold}</div>
          </div>
          <div>
            <div className="text-[var(--text-muted)] text-xs">Stock Value</div>
            <div className="text-lg font-semibold text-[var(--foreground)] mt-1">Rs. {(material.quantityInStock * material.avgUnitCost).toLocaleString()}</div>
          </div>
        </div>
      </div>

      <div className="flex items-center justify-between">
        <h2 className="text-lg font-semibold text-[var(--foreground)]">Purchase History</h2>
        <button onClick={() => setDialogOpen(true)} className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-50 dark:text-neutral-50 dark:text-neutral-950 hover:opacity-90 transition-opacity">
          + Record Purchase
        </button>
      </div>

      <div className="overflow-x-auto rounded-xl border border-[var(--surface-border)]">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-[var(--surface-border)] bg-[var(--surface)] text-left text-[var(--text-muted)]">
              <th className="px-4 py-3 font-medium">Date</th>
              <th className="px-4 py-3 font-medium">Quantity</th>
              <th className="px-4 py-3 font-medium">Cost / Unit</th>
              <th className="px-4 py-3 font-medium">Total</th>
            </tr>
          </thead>
          <tbody>
            {receipts.map((r) => (
              <tr key={r.id} className="border-b border-[var(--surface-border)] last:border-0 hover:bg-[var(--surface)]/60">
                <td className="px-4 py-3 text-[var(--text-secondary)]">{r.date}</td>
                <td className="px-4 py-3 text-[var(--text-secondary)]">{r.qty} {material.unit}</td>
                <td className="px-4 py-3 text-[var(--text-secondary)]">Rs. {r.cost.toLocaleString()}</td>
                <td className="px-4 py-3 text-[var(--text-secondary)]">Rs. {(r.qty * r.cost).toLocaleString()}</td>
              </tr>
            ))}
            {receipts.length === 0 && (
              <tr><td colSpan={4} className="px-4 py-8 text-center text-[var(--foreground)]0">No purchases recorded yet.</td></tr>
            )}
          </tbody>
        </table>
      </div>

      <RecordPurchaseDialog open={dialogOpen} onClose={() => setDialogOpen(false)} materialId={material.id} />
    </div>
  );
}