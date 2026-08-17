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
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4">
      <form onSubmit={handleSubmit(onSubmit)} className="w-full max-w-sm rounded-xl border border-neutral-800 bg-neutral-900 p-5 space-y-4">
        <h2 className="text-lg font-semibold text-neutral-50">Record Purchase</h2>
        <div className="space-y-3">
          <div>
            <label className="text-sm text-neutral-400">Quantity</label>
            <input {...register("qty")} type="number" step="any"
              className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
            {errors.qty && <p className="text-xs text-red-400 mt-1">{errors.qty.message}</p>}
          </div>
          <div>
            <label className="text-sm text-neutral-400">Purchase Cost (per unit)</label>
            <input {...register("cost")} type="number" step="any"
              className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
            {errors.cost && <p className="text-xs text-red-400 mt-1">{errors.cost.message}</p>}
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

export default function RawMaterialDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const material = useStore((s) => s.rawMaterials.find((m) => m.id === id));
  const allReceipts = useStore((s) => s.receipts);
  const [dialogOpen, setDialogOpen] = useState(false);

  const receipts = useMemo(() => allReceipts.filter((r) => r.rawMaterialId === id), [allReceipts, id]);

  if (!material) {
    return (
      <div className="space-y-4">
        <Link href="/raw-materials" className="text-sm text-neutral-400 hover:underline">&larr; Back to Raw Materials</Link>
        <p className="text-neutral-400">Raw material not found.</p>
      </div>
    );
  }

  const isLow = material.quantityInStock < material.lowStockThreshold;

  return (
    <div className="space-y-6">
      <div className="text-sm text-neutral-400">
        <Link href="/raw-materials" className="hover:underline text-neutral-300">Raw Materials</Link>{" "}
        / <span className="text-neutral-50">{material.name}</span>
      </div>

      <div className="rounded-xl border border-neutral-800 bg-neutral-900 p-5">
        <div className="flex items-start justify-between">
          <div>
            <h1 className="text-xl font-semibold text-neutral-50">{material.name}</h1>
            <p className="text-sm text-neutral-400 mt-1">Unit: {material.unit}</p>
          </div>
          <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ${
            isLow ? "bg-red-950 text-red-400 border border-red-900" : "bg-green-950 text-green-400 border border-green-900"
          }`}>
            {isLow ? "Low Stock" : "OK"}
          </span>
        </div>

        <div className="mt-5 grid grid-cols-2 sm:grid-cols-4 gap-4">
          <div>
            <div className="text-neutral-400 text-xs">Current Stock</div>
            <div className="text-lg font-semibold text-neutral-50 mt-1">{material.quantityInStock} {material.unit}</div>
          </div>
          <div>
            <div className="text-neutral-400 text-xs">Avg Unit Cost</div>
            <div className="text-lg font-semibold text-neutral-50 mt-1">Rs. {material.avgUnitCost.toLocaleString()}</div>
          </div>
          <div>
            <div className="text-neutral-400 text-xs">Low Stock Threshold</div>
            <div className="text-lg font-semibold text-neutral-50 mt-1">{material.lowStockThreshold}</div>
          </div>
          <div>
            <div className="text-neutral-400 text-xs">Stock Value</div>
            <div className="text-lg font-semibold text-neutral-50 mt-1">Rs. {(material.quantityInStock * material.avgUnitCost).toLocaleString()}</div>
          </div>
        </div>
      </div>

      <div className="flex items-center justify-between">
        <h2 className="text-lg font-semibold text-neutral-50">Purchase History</h2>
        <button onClick={() => setDialogOpen(true)} className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200">
          + Record Purchase
        </button>
      </div>

      <div className="overflow-hidden rounded-xl border border-neutral-800">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-neutral-800 bg-neutral-900 text-left text-neutral-400">
              <th className="px-4 py-3 font-medium">Date</th>
              <th className="px-4 py-3 font-medium">Quantity</th>
              <th className="px-4 py-3 font-medium">Cost / Unit</th>
              <th className="px-4 py-3 font-medium">Total</th>
            </tr>
          </thead>
          <tbody>
            {receipts.map((r) => (
              <tr key={r.id} className="border-b border-neutral-900 last:border-0 hover:bg-neutral-900/60">
                <td className="px-4 py-3 text-neutral-300">{r.date}</td>
                <td className="px-4 py-3 text-neutral-300">{r.qty} {material.unit}</td>
                <td className="px-4 py-3 text-neutral-300">Rs. {r.cost.toLocaleString()}</td>
                <td className="px-4 py-3 text-neutral-300">Rs. {(r.qty * r.cost).toLocaleString()}</td>
              </tr>
            ))}
            {receipts.length === 0 && (
              <tr><td colSpan={4} className="px-4 py-8 text-center text-neutral-500">No purchases recorded yet.</td></tr>
            )}
          </tbody>
        </table>
      </div>

      <RecordPurchaseDialog open={dialogOpen} onClose={() => setDialogOpen(false)} materialId={material.id} />
    </div>
  );
}