"use client";

import { useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { toast } from "sonner";
import { useStore } from "@/lib/store";
import { batchSchema, type BatchFormValues } from "@/lib/schemas";

type ConsumptionRow = { id: string; rawMaterialId: string; qty: string };

export default function NewBatchPage() {
  const router = useRouter();
  const rawMaterials = useStore((s) => s.rawMaterials);
  const productionBatches = useStore((s) => s.productionBatches);
  const createBatch = useStore((s) => s.createBatch);

  const {
    register,
    handleSubmit,
    watch,
    formState: { errors, isSubmitting },
  } = useForm<BatchFormValues>({
    resolver: zodResolver(batchSchema),
    defaultValues: { outputYieldKg: 0, wastageKg: 0 },
  });
  const outputYield = watch("outputYieldKg");

  const [rows, setRows] = useState<ConsumptionRow[]>([
    { id: crypto.randomUUID(), rawMaterialId: rawMaterials[0]?.id ?? "", qty: "" },
  ]);
  const [rowError, setRowError] = useState("");
  const [useLeftoverFirst, setUseLeftoverFirst] = useState(false);
  const [leftoverBatchId, setLeftoverBatchId] = useState("");

  const leftoverBatches = productionBatches.filter((b) => b.leftoverQtyKg > 0);

  const addRow = () => setRows((prev) => [...prev, { id: crypto.randomUUID(), rawMaterialId: rawMaterials[0]?.id ?? "", qty: "" }]);
  const removeRow = (id: string) => setRows((prev) => (prev.length > 1 ? prev.filter((r) => r.id !== id) : prev));
  const updateRow = (id: string, patch: Partial<ConsumptionRow>) =>
    setRows((prev) => prev.map((r) => (r.id === id ? { ...r, ...patch } : r)));

  const estimatedCost = useMemo(() => {
    return rows.reduce((total, row) => {
      const material = rawMaterials.find((m) => m.id === row.rawMaterialId);
      const qty = Number(row.qty) || 0;
      if (!material) return total;
      return total + qty * material.avgUnitCost;
    }, 0);
  }, [rows, rawMaterials]);

  const estimatedCostPerKg = useMemo(() => {
    const yieldKg = Number(outputYield) || 0;
    if (yieldKg <= 0) return 0;
    return estimatedCost / yieldKg;
  }, [estimatedCost, outputYield]);

  const onSubmit = async (values: BatchFormValues) => {
    setRowError("");
    const consumptions = rows
      .filter((r) => r.rawMaterialId && Number(r.qty) > 0)
      .map((r) => ({ rawMaterialId: r.rawMaterialId, qty: Number(r.qty) }));

    if (consumptions.length === 0) {
      setRowError("Add at least one raw material row with a quantity greater than 0");
      return;
    }

    const insufficient = consumptions.find((c) => {
      const m = rawMaterials.find((rm) => rm.id === c.rawMaterialId);
      return m && c.qty > m.quantityInStock;
    });
    if (insufficient) {
      setRowError("Not enough stock for one of the selected raw materials");
      return;
    }

    const newId = createBatch({ consumptions, outputYieldKg: values.outputYieldKg, wastageKg: values.wastageKg });
    toast.success(`Batch ${newId} created â€” raw material stock deducted`);
    router.push(`/batches/${newId}`);
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)} className="space-y-6 max-w-3xl">
      <h1 className="text-xl font-semibold text-neutral-50">New Production Batch</h1>

      <div className="rounded-xl border border-neutral-800 bg-neutral-900 p-5 space-y-4">
        <div className="flex items-center justify-between">
          <h2 className="text-sm font-semibold text-neutral-200">Raw Material Consumption</h2>
          <button type="button" onClick={addRow} className="rounded-lg border border-neutral-700 px-3 py-1.5 text-xs text-neutral-200 hover:bg-neutral-800">
            + Add Material Row
          </button>
        </div>

        <div className="space-y-3">
          {rows.map((row) => {
            const material = rawMaterials.find((m) => m.id === row.rawMaterialId);
            return (
              <div key={row.id} className="space-y-1">
                <div className="flex items-center gap-2">
                  <select value={row.rawMaterialId} onChange={(e) => updateRow(row.id, { rawMaterialId: e.target.value })}
                    className="flex-1 rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600">
                    {rawMaterials.map((m) => (
                      <option key={m.id} value={m.id}>{m.name} ({m.unit}) â€” {m.quantityInStock} in stock</option>
                    ))}
                  </select>
                  <input value={row.qty} onChange={(e) => updateRow(row.id, { qty: e.target.value })} type="number" placeholder="Qty"
                    className="w-28 rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
                  <button type="button" onClick={() => removeRow(row.id)} className="rounded-lg border border-neutral-800 px-3 py-2 text-sm text-neutral-400 hover:bg-neutral-800">-</button>
                </div>
                {material && Number(row.qty) > material.quantityInStock && (
                  <p className="text-xs text-red-400">Only {material.quantityInStock} {material.unit} available</p>
                )}
              </div>
            );
          })}
          {rowError && <p className="text-xs text-red-400">{rowError}</p>}
        </div>

        <div className="rounded-lg border border-neutral-800 bg-neutral-950 p-4">
          <div className="text-xs text-neutral-400">Estimated Batch Cost</div>
          <div className="text-lg font-semibold text-neutral-50 mt-1">
            Rs. {estimatedCost.toLocaleString(undefined, { maximumFractionDigits: 2 })}
          </div>
          {Number(outputYield) > 0 && (
            <div className="text-xs text-neutral-400 mt-1">
              Est. cost/kg: Rs. {estimatedCostPerKg.toLocaleString(undefined, { maximumFractionDigits: 2 })}
            </div>
          )}
        </div>
      </div>

      <div className="rounded-xl border border-neutral-800 bg-neutral-900 p-5 grid grid-cols-1 sm:grid-cols-2 gap-4">
        <div>
          <label className="text-sm text-neutral-400">Output Yield (kg)</label>
          <input {...register("outputYieldKg")} type="number" step="any"
            className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
          {errors.outputYieldKg && <p className="text-xs text-red-400 mt-1">{errors.outputYieldKg.message}</p>}
        </div>
        <div>
          <label className="text-sm text-neutral-400">Wastage (kg)</label>
          <input {...register("wastageKg")} type="number" step="any"
            className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
          {errors.wastageKg && <p className="text-xs text-red-400 mt-1">{errors.wastageKg.message}</p>}
        </div>
      </div>

      <div className="rounded-xl border border-neutral-800 bg-neutral-900 p-5 space-y-3">
        <label className="flex items-center gap-3 cursor-pointer">
          <input type="checkbox" checked={useLeftoverFirst} onChange={(e) => setUseLeftoverFirst(e.target.checked)}
            className="size-4 rounded border-neutral-700 bg-neutral-950" />
          <span className="text-sm text-neutral-200">Use Leftover From Previous Batch First</span>
        </label>

        {useLeftoverFirst && (
          <select value={leftoverBatchId} onChange={(e) => setLeftoverBatchId(e.target.value)}
            className="w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600">
            <option value="">Select leftover batch...</option>
            {leftoverBatches.map((b) => (
              <option key={b.id} value={b.id}>{b.id} â€” {b.leftoverQtyKg} kg leftover</option>
            ))}
          </select>
        )}
      </div>

      <div className="flex justify-end gap-2">
        <button type="button" onClick={() => router.push("/batches")} className="rounded-lg px-4 py-2 text-sm text-neutral-300 hover:bg-neutral-800">Cancel</button>
        <button type="submit" disabled={isSubmitting}
          className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200 disabled:opacity-50">
          {isSubmitting ? "Saving..." : "Save Batch"}
        </button>
      </div>
    </form>
  );
}