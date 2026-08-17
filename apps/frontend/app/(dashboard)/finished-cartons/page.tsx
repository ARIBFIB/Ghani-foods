"use client";

import { useMemo, useState } from "react";
import { toast } from "sonner";
import { useStore } from "@/lib/store";

function NewPackingRunDialog({ open, onClose }: { open: boolean; onClose: () => void }) {
  const productionBatches = useStore((s) => s.productionBatches);
  const packagingMaterials = useStore((s) => s.packagingMaterials);
  const createPackingRun = useStore((s) => s.createPackingRun);

  const [step, setStep] = useState(1);
  const [batchId, setBatchId] = useState(productionBatches.find((b) => b.leftoverQtyKg > 0)?.id ?? productionBatches[0]?.id ?? "");
  const [packagingId, setPackagingId] = useState(packagingMaterials[0]?.id ?? "");
  const [packetsPerCarton, setPacketsPerCarton] = useState("24");
  const [cartons, setCartons] = useState("10");
  const [bulkKgUsed, setBulkKgUsed] = useState("10");

  if (!open) return null;

  const batch = productionBatches.find((b) => b.id === batchId);
  const packaging = packagingMaterials.find((p) => p.id === packagingId);

  const costPerCarton = useMemo(() => {
    const cartonQty = Number(cartons) || 0;
    if (cartonQty === 0) return 0;
    const bulkCostShare = (batch?.bulkCostPerKg ?? 0) * (Number(bulkKgUsed) || 0);
    const packagingCostShare = (packaging?.unitCost ?? 0) * cartonQty;
    return (bulkCostShare + packagingCostShare) / cartonQty;
  }, [batch, packaging, cartons, bulkKgUsed]);

  const reset = () => {
    setStep(1);
    setPacketsPerCarton("24");
    setCartons("10");
    setBulkKgUsed("10");
  };

  const handleConfirm = () => {
    if (!batch) return;
    const kgUsed = Number(bulkKgUsed) || 0;
    if (kgUsed > batch.leftoverQtyKg) {
      toast.error(`Only ${batch.leftoverQtyKg} kg leftover available in ${batch.id}`);
      return;
    }
    createPackingRun({
      batchId,
      packagingMaterialId: packagingId,
      packetsPerCarton: Number(packetsPerCarton) || 0,
      cartonQty: Number(cartons) || 0,
      bulkKgUsed: kgUsed,
    });
    toast.success(`Packing run confirmed â€” ${cartons} cartons added to ready stock`);
    reset();
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-3 sm:p-4">
      <div className="w-full max-w-md rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-5 space-y-4">
        <h2 className="text-lg font-semibold text-[var(--foreground)]">New Packing Run â€” Step {step} of 3</h2>

        {step === 1 && (
          <div>
            <label className="text-sm text-[var(--text-muted)]">Select Batch</label>
            <select value={batchId} onChange={(e) => setBatchId(e.target.value)}
              className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]">
              {productionBatches.map((b) => (
                <option key={b.id} value={b.id}>{b.id} â€” {b.leftoverQtyKg} kg available</option>
              ))}
            </select>
          </div>
        )}

        {step === 2 && (
          <div className="space-y-3">
            <div>
              <label className="text-sm text-[var(--text-muted)]">Packaging Material</label>
              <select value={packagingId} onChange={(e) => setPackagingId(e.target.value)}
                className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]">
                {packagingMaterials.map((p) => (
                  <option key={p.id} value={p.id}>{p.name} â€” {p.stockQty} in stock</option>
                ))}
              </select>
            </div>
            <div>
              <label className="text-sm text-[var(--text-muted)]">Packets per Carton</label>
              <input value={packetsPerCarton} onChange={(e) => setPacketsPerCarton(e.target.value)} type="number"
                className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
            </div>
            <div>
              <label className="text-sm text-[var(--text-muted)]">Number of Cartons</label>
              <input value={cartons} onChange={(e) => setCartons(e.target.value)} type="number"
                className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
            </div>
            <div>
              <label className="text-sm text-[var(--text-muted)]">Bulk Product Used (kg)</label>
              <input value={bulkKgUsed} onChange={(e) => setBulkKgUsed(e.target.value)} type="number"
                className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
            </div>
          </div>
        )}

        {step === 3 && (
          <div className="rounded-lg border border-[var(--surface-border)] bg-[var(--background)] p-4 space-y-2">
            <div className="flex justify-between text-sm"><span className="text-[var(--text-muted)]">Source Batch</span><span className="text-[var(--foreground)]">{batchId}</span></div>
            <div className="flex justify-between text-sm"><span className="text-[var(--text-muted)]">Packaging</span><span className="text-[var(--foreground)]">{packaging?.name}</span></div>
            <div className="flex justify-between text-sm"><span className="text-[var(--text-muted)]">Cartons</span><span className="text-[var(--foreground)]">{cartons}</span></div>
            <div className="flex justify-between text-sm"><span className="text-[var(--text-muted)]">Bulk Used</span><span className="text-[var(--foreground)]">{bulkKgUsed} kg</span></div>
            <div className="flex justify-between text-sm pt-2 border-t border-[var(--surface-border)]">
              <span className="text-[var(--text-muted)]">Est. Cost / Carton</span>
              <span className="text-[var(--foreground)] font-semibold">Rs. {costPerCarton.toFixed(2)}</span>
            </div>
          </div>
        )}

        <div className="flex justify-between pt-2">
          <button onClick={() => (step === 1 ? onClose() : setStep(step - 1))} className="rounded-lg px-4 py-2 text-sm text-[var(--text-secondary)] hover:bg-[var(--surface-hover)]">
            {step === 1 ? "Cancel" : "Back"}
          </button>
          {step < 3 ? (
            <button onClick={() => setStep(step + 1)} className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-50 dark:text-neutral-50 dark:text-neutral-950 hover:opacity-90 transition-opacity">Next</button>
          ) : (
            <button onClick={handleConfirm} className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-50 dark:text-neutral-50 dark:text-neutral-950 hover:opacity-90 transition-opacity">Confirm Packing</button>
          )}
        </div>
      </div>
    </div>
  );
}

export default function FinishedCartonsPage() {
  const cartons = useStore((s) => s.finishedCartons);
  const productionBatches = useStore((s) => s.productionBatches);
  const [tab, setTab] = useState<"ready" | "leftover">("ready");
  const [dialogOpen, setDialogOpen] = useState(false);

  const leftoverBatches = productionBatches.filter((b) => b.leftoverQtyKg > 0);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-semibold text-[var(--foreground)]">Finished Cartons</h1>
        <button onClick={() => setDialogOpen(true)} className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-50 dark:text-neutral-50 dark:text-neutral-950 hover:opacity-90 transition-opacity">
          + New Packing Run
        </button>
      </div>

      <div className="flex gap-2 border-b border-[var(--surface-border)]">
        <button onClick={() => setTab("ready")} className={`px-4 py-2 text-sm font-medium border-b-2 ${tab === "ready" ? "border-neutral-50 text-[var(--foreground)]" : "border-transparent text-[var(--text-muted)]"}`}>
          Ready for Sale
        </button>
        <button onClick={() => setTab("leftover")} className={`px-4 py-2 text-sm font-medium border-b-2 ${tab === "leftover" ? "border-neutral-50 text-[var(--foreground)]" : "border-transparent text-[var(--text-muted)]"}`}>
          Unpacked / Leftover
        </button>
      </div>

      {tab === "ready" ? (
        <div className="overflow-x-auto rounded-xl border border-[var(--surface-border)]">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-[var(--surface-border)] bg-[var(--surface)] text-left text-[var(--text-muted)]">
                <th className="px-4 py-3 font-medium">Carton</th>
                <th className="px-4 py-3 font-medium">Source Batch</th>
                <th className="px-4 py-3 font-medium">Packets/Carton</th>
                <th className="px-4 py-3 font-medium">Cost/Carton</th>
                <th className="px-4 py-3 font-medium">Stock Qty</th>
              </tr>
            </thead>
            <tbody>
              {cartons.map((c) => (
                <tr key={c.id} className="border-b border-[var(--surface-border)] last:border-0 hover:bg-[var(--surface)]/60">
                  <td className="px-4 py-3 text-[var(--foreground)]">{c.name}</td>
                  <td className="px-4 py-3 text-[var(--text-secondary)]">{c.sourceBatchId}</td>
                  <td className="px-4 py-3 text-[var(--text-secondary)]">{c.packetsPerCarton}</td>
                  <td className="px-4 py-3 text-[var(--text-secondary)]">Rs. {c.costPerCarton.toLocaleString()}</td>
                  <td className="px-4 py-3 text-[var(--text-secondary)]">{c.stockQty}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      ) : (
        <div className="overflow-x-auto rounded-xl border border-[var(--surface-border)]">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-[var(--surface-border)] bg-[var(--surface)] text-left text-[var(--text-muted)]">
                <th className="px-4 py-3 font-medium">Batch</th>
                <th className="px-4 py-3 font-medium">Leftover Bulk (kg)</th>
                <th className="px-4 py-3 font-medium">Bulk Cost/Kg</th>
              </tr>
            </thead>
            <tbody>
              {leftoverBatches.map((b) => (
                <tr key={b.id} className="border-b border-[var(--surface-border)] last:border-0 hover:bg-[var(--surface)]/60">
                  <td className="px-4 py-3 text-[var(--foreground)]">{b.id}</td>
                  <td className="px-4 py-3 text-[var(--text-secondary)]">{b.leftoverQtyKg} kg</td>
                  <td className="px-4 py-3 text-[var(--text-secondary)]">Rs. {b.bulkCostPerKg.toLocaleString()}</td>
                </tr>
              ))}
              {leftoverBatches.length === 0 && (
                <tr><td colSpan={3} className="px-4 py-8 text-center text-[var(--foreground)]0">No leftover bulk product.</td></tr>
              )}
            </tbody>
          </table>
        </div>
      )}

      <NewPackingRunDialog open={dialogOpen} onClose={() => setDialogOpen(false)} />
    </div>
  );
}