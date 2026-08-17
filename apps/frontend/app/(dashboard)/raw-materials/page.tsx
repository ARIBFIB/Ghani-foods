"use client";

import { useMemo, useState } from "react";
import Link from "next/link";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { toast } from "sonner";
import { useStore } from "@/lib/store";
import { rawMaterialSchema, type RawMaterialFormValues } from "@/lib/schemas";

function StatusBadge({ isLow }: { isLow: boolean }) {
  return (
    <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ${
      isLow ? "bg-red-950 text-red-400 border border-red-900" : "bg-green-950 text-green-400 border border-green-900"
    }`}>
      {isLow ? "Low Stock" : "OK"}
    </span>
  );
}

function AddRawMaterialDialog({ open, onClose }: { open: boolean; onClose: () => void }) {
  const addRawMaterial = useStore((s) => s.addRawMaterial);
  const {
    register,
    handleSubmit,
    reset,
    formState: { errors, isSubmitting },
  } = useForm<RawMaterialFormValues>({
    resolver: zodResolver(rawMaterialSchema),
    defaultValues: { name: "", unit: "kg", lowStockThreshold: 50 },
  });

  if (!open) return null;

  const onSubmit = async (values: RawMaterialFormValues) => {
    addRawMaterial(values);
    toast.success(`Raw material "${values.name}" added`);
    reset();
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4">
      <form onSubmit={handleSubmit(onSubmit)} className="w-full max-w-sm rounded-xl border border-neutral-800 bg-neutral-900 p-5 space-y-4">
        <h2 className="text-lg font-semibold text-neutral-50">Add Raw Material</h2>
        <div className="space-y-3">
          <div>
            <label className="text-sm text-neutral-400">Name</label>
            <input {...register("name")} placeholder="e.g. Atta (Flour)"
              className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
            {errors.name && <p className="text-xs text-red-400 mt-1">{errors.name.message}</p>}
          </div>
          <div>
            <label className="text-sm text-neutral-400">Unit of Purchase</label>
            <input {...register("unit")} placeholder="kg, litre, etc."
              className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
            {errors.unit && <p className="text-xs text-red-400 mt-1">{errors.unit.message}</p>}
          </div>
          <div>
            <label className="text-sm text-neutral-400">Low Stock Threshold</label>
            <input {...register("lowStockThreshold")} type="number"
              className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
            {errors.lowStockThreshold && <p className="text-xs text-red-400 mt-1">{errors.lowStockThreshold.message}</p>}
          </div>
        </div>
        <div className="flex justify-end gap-2 pt-2">
          <button type="button" onClick={() => { reset(); onClose(); }} className="rounded-lg px-4 py-2 text-sm text-neutral-300 hover:bg-neutral-800">
            Cancel
          </button>
          <button type="submit" disabled={isSubmitting}
            className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200 disabled:opacity-50">
            {isSubmitting ? "Saving..." : "Save"}
          </button>
        </div>
      </form>
    </div>
  );
}

export default function RawMaterialsPage() {
  const items = useStore((s) => s.rawMaterials);
  const [search, setSearch] = useState("");
  const [dialogOpen, setDialogOpen] = useState(false);

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    if (!q) return items;
    return items.filter((m) => m.name.toLowerCase().includes(q));
  }, [items, search]);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-semibold text-neutral-50">Raw Materials</h1>
        <button onClick={() => setDialogOpen(true)} className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200">
          + Add Raw Material
        </button>
      </div>

      <input value={search} onChange={(e) => setSearch(e.target.value)} placeholder="Search raw materials..."
        className="w-full max-w-sm rounded-lg border border-neutral-800 bg-neutral-900 px-3 py-2 text-sm text-neutral-50 placeholder:text-neutral-500 outline-none focus:border-neutral-600" />

      <div className="overflow-hidden rounded-xl border border-neutral-800">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-neutral-800 bg-neutral-900 text-left text-neutral-400">
              <th className="px-4 py-3 font-medium">Name</th>
              <th className="px-4 py-3 font-medium">Unit</th>
              <th className="px-4 py-3 font-medium">Qty in Stock</th>
              <th className="px-4 py-3 font-medium">Avg Unit Cost</th>
              <th className="px-4 py-3 font-medium">Threshold</th>
              <th className="px-4 py-3 font-medium">Status</th>
            </tr>
          </thead>
          <tbody>
            {filtered.map((m) => {
              const isLow = m.quantityInStock < m.lowStockThreshold;
              return (
                <tr key={m.id} className="border-b border-neutral-900 last:border-0 hover:bg-neutral-900/60">
                  <td className="px-4 py-3">
                    <Link href={`/raw-materials/${m.id}`} className="text-neutral-50 hover:underline">{m.name}</Link>
                  </td>
                  <td className="px-4 py-3 text-neutral-300">{m.unit}</td>
                  <td className="px-4 py-3 text-neutral-300">{m.quantityInStock}</td>
                  <td className="px-4 py-3 text-neutral-300">Rs. {m.avgUnitCost.toLocaleString()}</td>
                  <td className="px-4 py-3 text-neutral-300">{m.lowStockThreshold}</td>
                  <td className="px-4 py-3"><StatusBadge isLow={isLow} /></td>
                </tr>
              );
            })}
            {filtered.length === 0 && (
              <tr><td colSpan={6} className="px-4 py-8 text-center text-neutral-500">No raw materials found.</td></tr>
            )}
          </tbody>
        </table>
      </div>

      <AddRawMaterialDialog open={dialogOpen} onClose={() => setDialogOpen(false)} />
    </div>
  );
}