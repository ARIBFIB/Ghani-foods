"use client";

import { useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { useNavigationLoading } from "@/lib/navigation-loading-context";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { toast } from "@/components/ui/toast";
import { useStore } from "@/lib/store";
import { batchSchema, type BatchFormValues } from "@/lib/schemas";

type ConsumptionRow = { id: string; rawMaterialId: string; qty: string; unit: string };

// Base unit -> smaller unit it can also be entered in, and the conversion
// factor (how many "sub" units make one "base" unit). Only kg/g and
// litre/ml are convertible; "piece" and anything else has no sub-unit.
const UNIT_CONVERSIONS: Record<string, { subUnit: string; factor: number }> = {
  kg: { subUnit: "g", factor: 1000 },
  litre: { subUnit: "ml", factor: 1000 },
};

function unitOptionsFor(baseUnit: string): string[] {
  const conv = UNIT_CONVERSIONS[baseUnit];
  return conv ? [baseUnit, conv.subUnit] : [baseUnit];
}

// Converts a quantity entered in `inputUnit` into the raw material's base
// unit (the unit its stock is tracked in), e.g. 500 g -> 0.5 kg.
function toBaseQty(qty: number, inputUnit: string, baseUnit: string): number {
  if (inputUnit === baseUnit) return qty;
  const conv = UNIT_CONVERSIONS[baseUnit];
  if (conv && conv.subUnit === inputUnit) return qty / conv.factor;
  return qty;
}

export default function NewBatchPage() {
  const router = useRouter();
  const { navigate } = useNavigationLoading();
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
    { id: crypto.randomUUID(), rawMaterialId: rawMaterials[0]?.id ?? "", qty: "", unit: rawMaterials[0]?.unit ?? "kg" },
  ]);
  const [rowError, setRowError] = useState("");
  const [useLeftoverFirst, setUseLeftoverFirst] = useState(false);
  const [leftoverBatchId, setLeftoverBatchId] = useState("");
  const [leftoverKgUsed, setLeftoverKgUsed] = useState("");

  const leftoverBatches = productionBatches.filter((b) => b.leftoverQtyKg > 0);
  const selectedLeftoverBatch = leftoverBatches.find((b) => b.id === leftoverBatchId);

  const addRow = () =>
    setRows((prev) => [
      ...prev,
      { id: crypto.randomUUID(), rawMaterialId: rawMaterials[0]?.id ?? "", qty: "", unit: rawMaterials[0]?.unit ?? "kg" },
    ]);
  const removeRow = (id: string) => setRows((prev) => (prev.length > 1 ? prev.filter((r) => r.id !== id) : prev));
  const updateRow = (id: string, patch: Partial<ConsumptionRow>) =>
    setRows((prev) => prev.map((r) => (r.id === id ? { ...r, ...patch } : r)));

  // When the selected raw material changes, reset the row's unit to that
  // material's base unit (its stock quantity is always tracked in that unit).
  const handleMaterialChange = (id: string, rawMaterialId: string) => {
    const material = rawMaterials.find((m) => m.id === rawMaterialId);
    updateRow(id, { rawMaterialId, unit: material?.unit ?? "kg" });
  };

  const baseQtyForRow = (row: ConsumptionRow) => {
    const material = rawMaterials.find((m) => m.id === row.rawMaterialId);
    if (!material) return 0;
    return toBaseQty(Number(row.qty) || 0, row.unit, material.unit);
  };

  const estimatedRawMaterialCost = useMemo(() => {
    return rows.reduce((total, row) => {
      const material = rawMaterials.find((m) => m.id === row.rawMaterialId);
      if (!material) return total;
      return total + baseQtyForRow(row) * material.avgUnitCost;
    }, 0);
  }, [rows, rawMaterials]);

  const estimatedLeftoverCost = useMemo(() => {
    if (!useLeftoverFirst || !selectedLeftoverBatch) return 0;
    const kg = Math.min(Number(leftoverKgUsed) || 0, selectedLeftoverBatch.leftoverQtyKg);
    return kg * selectedLeftoverBatch.bulkCostPerKg;
  }, [useLeftoverFirst, selectedLeftoverBatch, leftoverKgUsed]);

  const estimatedTotalCost = estimatedRawMaterialCost + estimatedLeftoverCost;

  const effectiveKgUsedFromLeftover = useMemo(() => {
    if (!useLeftoverFirst || !selectedLeftoverBatch) return 0;
    return Math.min(Number(leftoverKgUsed) || 0, selectedLeftoverBatch.leftoverQtyKg);
  }, [useLeftoverFirst, selectedLeftoverBatch, leftoverKgUsed]);

  const estimatedTotalKg = (Number(outputYield) || 0) + effectiveKgUsedFromLeftover;

  const estimatedCostPerKg = useMemo(() => {
    if (estimatedTotalKg <= 0) return 0;
    return estimatedTotalCost / estimatedTotalKg;
  }, [estimatedTotalCost, estimatedTotalKg]);

  const onSubmit = async (values: BatchFormValues) => {
    setRowError("");
    const consumptions = rows
      .filter((r) => r.rawMaterialId && Number(r.qty) > 0)
      .map((r) => ({ rawMaterialId: r.rawMaterialId, qty: baseQtyForRow(r) }));

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

    if (useLeftoverFirst) {
      if (!leftoverBatchId) {
        setRowError("Select a leftover batch, or turn off 'Use Leftover From Previous Batch First'");
        return;
      }
      const kg = Number(leftoverKgUsed) || 0;
      if (kg <= 0) {
        setRowError("Enter how many kg of leftover to use");
        return;
      }
      if (selectedLeftoverBatch && kg > selectedLeftoverBatch.leftoverQtyKg) {
        setRowError(`Only ${selectedLeftoverBatch.leftoverQtyKg} kg leftover available in ${selectedLeftoverBatch.id}`);
        return;
      }
    }

    try {
      const newId = await createBatch({
        consumptions,
        outputYieldKg: values.outputYieldKg,
        wastageKg: values.wastageKg,
        leftoverBatchId: useLeftoverFirst ? leftoverBatchId : undefined,
        leftoverKgUsed: useLeftoverFirst ? Number(leftoverKgUsed) || 0 : undefined,
      });

      if (useLeftoverFirst) {
        toast.success(`Batch ${newId} created — raw material stock deducted and ${leftoverKgUsed} kg leftover from ${leftoverBatchId} consumed`);
      } else {
        toast.success(`Batch ${newId} created — raw material stock deducted`);
      }
      navigate(`/batches/${newId}`);
    } catch (err) {
      setRowError(err instanceof Error ? err.message : "Failed to create batch");
    }
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)} className="space-y-6 max-w-3xl">
      <h1 className="text-xl font-semibold text-[var(--foreground)]">New Production Batch</h1>

      <div className="rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-5 space-y-4">
        <div className="flex items-center justify-between">
          <h2 className="text-sm font-semibold text-[var(--foreground)]">Raw Material Consumption</h2>
          <button type="button" onClick={addRow} className="rounded-lg border border-neutral-400 dark:border-neutral-600 px-3 py-1.5 text-xs text-[var(--foreground)] hover:bg-[var(--surface-hover)]">
            + Add Material Row
          </button>
        </div>

        <div className="space-y-3">
          {rows.map((row) => {
            const material = rawMaterials.find((m) => m.id === row.rawMaterialId);
            const options = material ? unitOptionsFor(material.unit) : ["kg"];
            const baseQty = baseQtyForRow(row);
            const overStock = !!material && baseQty > material.quantityInStock;
            return (
              <div key={row.id} className="space-y-1">
                <div className="flex flex-col sm:flex-row items-stretch sm:items-center gap-2">
                  <select value={row.rawMaterialId} onChange={(e) => handleMaterialChange(row.id, e.target.value)}
                    className="flex-1 rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]">
                    {rawMaterials.map((m) => (
                      <option key={m.id} value={m.id}>{m.name} ({m.unit}) — {m.quantityInStock} in stock</option>
                    ))}
                  </select>
                  <input value={row.qty} onChange={(e) => updateRow(row.id, { qty: e.target.value })} type="number" placeholder="Qty"
                    className="w-full sm:w-24 rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
                  {options.length > 1 ? (
                    <select value={row.unit} onChange={(e) => updateRow(row.id, { unit: e.target.value })}
                      className="w-full sm:w-24 rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]">
                      {options.map((u) => <option key={u} value={u}>{u}</option>)}
                    </select>
                  ) : (
                    <span className="w-full sm:w-24 px-3 py-2 text-sm text-[var(--text-faint)]">{options[0]}</span>
                  )}
                  <button type="button" onClick={() => removeRow(row.id)} className="rounded-lg border border-[var(--surface-border)] px-3 py-2 text-sm text-[var(--text-muted)] hover:bg-[var(--surface-hover)]">-</button>
                </div>
                {material && row.unit !== material.unit && Number(row.qty) > 0 && (
                  <p className="text-xs text-[var(--text-faint)]">
                    = {baseQty.toLocaleString(undefined, { maximumFractionDigits: 3 })} {material.unit}
                  </p>
                )}
                {overStock && (
                  <p className="text-xs text-red-400">Only {material!.quantityInStock} {material!.unit} available</p>
                )}
              </div>
            );
          })}
          {rowError && <p className="text-xs text-red-400">{rowError}</p>}
        </div>

        <div className="rounded-lg border border-[var(--surface-border)] bg-[var(--background)] p-4">
          <div className="text-xs text-[var(--text-muted)]">Estimated Batch Cost</div>
          <div className="text-lg font-semibold text-[var(--foreground)] mt-1">
            Rs. {estimatedTotalCost.toLocaleString(undefined, { maximumFractionDigits: 2 })}
          </div>
          {estimatedLeftoverCost > 0 && (
            <div className="text-xs text-[var(--text-faint)] mt-1">
              includes Rs. {estimatedLeftoverCost.toLocaleString(undefined, { maximumFractionDigits: 2 })} carried over from leftover
            </div>
          )}
          {estimatedTotalKg > 0 && (
            <div className="text-xs text-[var(--text-muted)] mt-1">
              Est. cost/kg: Rs. {estimatedCostPerKg.toLocaleString(undefined, { maximumFractionDigits: 2 })}
              {" "}(on {estimatedTotalKg} kg total{effectiveKgUsedFromLeftover > 0 ? `, incl. ${effectiveKgUsedFromLeftover} kg leftover` : ""})
            </div>
          )}
        </div>
      </div>

      <div className="rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-5 grid grid-cols-1 sm:grid-cols-2 gap-4">
        <div>
          <label className="text-sm text-[var(--text-muted)]">Output Yield (kg)</label>
          <input {...register("outputYieldKg")} type="number" step="any"
            className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
          {errors.outputYieldKg && <p className="text-xs text-red-400 mt-1">{errors.outputYieldKg.message}</p>}
        </div>
        <div>
          <label className="text-sm text-[var(--text-muted)]">Wastage (kg)</label>
          <input {...register("wastageKg")} type="number" step="any"
            className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
          {errors.wastageKg && <p className="text-xs text-red-400 mt-1">{errors.wastageKg.message}</p>}
        </div>
      </div>

      <div className="rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-5 space-y-3">
        <label className="flex items-center gap-3 cursor-pointer">
          <input
            type="checkbox"
            checked={useLeftoverFirst}
            onChange={(e) => {
              setUseLeftoverFirst(e.target.checked);
              if (!e.target.checked) {
                setLeftoverBatchId("");
                setLeftoverKgUsed("");
              }
            }}
            className="size-4 rounded border-[var(--surface-border-strong)] bg-[var(--background)]"
          />
          <span className="text-sm text-[var(--foreground)]">Use Leftover From Previous Batch First</span>
        </label>

        {useLeftoverFirst && (
          <div className="space-y-3">
            <div>
              <label className="text-sm text-[var(--text-muted)]">Leftover Batch</label>
              <select
                value={leftoverBatchId}
                onChange={(e) => { setLeftoverBatchId(e.target.value); setLeftoverKgUsed(""); }}
                className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]"
              >
                <option value="">Select leftover batch...</option>
                {leftoverBatches.map((b) => (
                  <option key={b.id} value={b.id}>{b.id} — {b.leftoverQtyKg} kg available @ Rs. {b.bulkCostPerKg}/kg</option>
                ))}
              </select>
            </div>

            {selectedLeftoverBatch && (
              <div>
                <label className="text-sm text-[var(--text-muted)]">Leftover Qty to Use (kg)</label>
                <input
                  value={leftoverKgUsed}
                  onChange={(e) => setLeftoverKgUsed(e.target.value)}
                  type="number"
                  step="any"
                  max={selectedLeftoverBatch.leftoverQtyKg}
                  placeholder={`Up to ${selectedLeftoverBatch.leftoverQtyKg} kg`}
                  className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]"
                />
                {Number(leftoverKgUsed) > selectedLeftoverBatch.leftoverQtyKg && (
                  <p className="text-xs text-red-400 mt-1">Only {selectedLeftoverBatch.leftoverQtyKg} kg available in this batch</p>
                )}
              </div>
            )}
          </div>
        )}
      </div>

      <div className="flex justify-end gap-2">
        <button type="button" onClick={() => navigate("/batches")} className="rounded-lg px-4 py-2 text-sm text-[var(--text-secondary)] hover:bg-[var(--surface-hover)]">Cancel</button>
        <button type="submit" disabled={isSubmitting}
          className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-50 dark:text-neutral-50 dark:text-neutral-950 hover:bg-neutral-200 disabled:opacity-50">
          {isSubmitting ? "Saving..." : "Save Batch"}
        </button>
      </div>
    </form>
  );
}
