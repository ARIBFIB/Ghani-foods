"use client";

import { useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { rawMaterials } from "@/lib/mock-data/raw-materials";
import { productionBatches } from "@/lib/mock-data/batches";

type ConsumptionRow = { id: string; rawMaterialId: string; qty: string };

export default function NewBatchPage() {
  const router = useRouter();
  const [rows, setRows] = useState<ConsumptionRow[]>([
    { id: crypto.randomUUID(), rawMaterialId: rawMaterials[0]?.id ?? "", qty: "" },
  ]);
  const [outputYield, setOutputYield] = useState("");
  const [wastage, setWastage] = useState("");
  const [useLeftoverFirst, setUseLeftoverFirst] = useState(false);
  const [leftoverBatchId, setLeftoverBatchId] = useState("");

  const leftoverBatches = productionBatches.filter((b) => b.leftoverQtyKg > 0);

  const addRow = () => {
    setRows((prev) => [...prev, { id: crypto.randomUUID(), rawMaterialId: rawMaterials[0]?.id ?? "", qty: "" }]);
  };

  const removeRow = (id: string) => {
    setRows((prev) => (prev.length > 1 ? prev.filter((r) => r.id !== id) : prev));
  };

  const updateRow = (id: string, patch: Partial<ConsumptionRow>) => {
    setRows((prev) => prev.map((r) => (r.id === id ? { ...r, ...patch } : r)));
  };

  const estimatedCost = useMemo(() => {
    return rows.reduce((total, row) => {
      const material = rawMaterials.find((m) => m.id === row.rawMaterialId);
      const qty = Number(row.qty) || 0;
      if (!material) return total;
      return total + qty * material.avgUnitCost;
    }, 0);
  }, [rows]);

  const estimatedCostPerKg = useMemo(() => {
    const yieldKg = Number(outputYield) || 0;
    if (yieldKg <= 0) return 0;
    return estimatedCost / yieldKg;
  }, [estimatedCost, outputYield]);

  const handleSave = () => {
    // Demo build: no real persistence, just navigate to an existing batch detail.
    router.push(`/batches/${productionBatches[0]?.id ?? ""}`);
  };

  return (
    <div className="space-y-6 max-w-3xl">
      <h1 className="text-xl font-semibold text-neutral-50">New Production Batch</h1>

      <div className="rounded-xl border border-neutral-800 bg-neutral-900 p-5 space-y-4">
        <div className="flex items-center justify-between">
          <h2 className="text-sm font-semibold text-neutral-200">Raw Material Consumption</h2>
          <button
            onClick={addRow}
            className="rounded-lg border border-neutral-700 px-3 py-1.5 text-xs text-neutral-200 hover:bg-neutral-800"
          >
            + Add Material Row
          </button>
        </div>

        <div className="space-y-3">
          {rows.map((row) => (
            <div key={row.id} className="flex items-center gap-2">
              <select
                value={row.rawMaterialId}
                onChange={(e) => updateRow(row.id, { rawMaterialId: e.target.value })}
                className="flex-1 rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600"
              >
                {rawMaterials.map((m) => (
                  <option key={m.id} value={m.id}>
                    {m.name} ({m.unit})
                  </option>
                ))}
              </select>
              <input
                value={row.qty}
                onChange={(e) => updateRow(row.id, { qty: e.target.value })}
                type="number"
                placeholder="Qty"
                className="w-28 rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600"
              />
              <button
                onClick={() => removeRow(row.id)}
                className="rounded-lg border border-neutral-800 px-3 py-2 text-sm text-neutral-400 hover:bg-neutral-800"
              >
                â€“
              </button>
            </div>
          ))}
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
          <input
            value={outputYield}
            onChange={(e) => setOutputYield(e.target.value)}
            type="number"
            className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600"
          />
        </div>
        <div>
          <label className="text-sm text-neutral-400">Wastage (kg)</label>
          <input
            value={wastage}
            onChange={(e) => setWastage(e.target.value)}
            type="number"
            className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600"
          />
        </div>
      </div>

      <div className="rounded-xl border border-neutral-800 bg-neutral-900 p-5 space-y-3">
        <label className="flex items-center gap-3 cursor-pointer">
          <input
            type="checkbox"
            checked={useLeftoverFirst}
            onChange={(e) => setUseLeftoverFirst(e.target.checked)}
            className="size-4 rounded border-neutral-700 bg-neutral-950"
          />
          <span className="text-sm text-neutral-200">Use Leftover From Previous Batch First</span>
        </label>

        {useLeftoverFirst && (
          <select
            value={leftoverBatchId}
            onChange={(e) => setLeftoverBatchId(e.target.value)}
            className="w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600"
          >
            <option value="">Select leftover batch...</option>
            {leftoverBatches.map((b) => (
              <option key={b.id} value={b.id}>
                {b.id} â€” {b.leftoverQtyKg} kg leftover
              </option>
            ))}
          </select>
        )}
      </div>

      <div className="flex justify-end gap-2">
        <button
          onClick={() => router.push("/batches")}
          className="rounded-lg px-4 py-2 text-sm text-neutral-300 hover:bg-neutral-800"
        >
          Cancel
        </button>
        <button
          onClick={handleSave}
          className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200"
        >
          Save Batch
        </button>
      </div>
    </div>
  );
}