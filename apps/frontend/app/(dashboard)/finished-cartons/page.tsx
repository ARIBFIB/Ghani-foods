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
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4">
      <div className="w-full max-w-md rounded-xl border border-neutral-800 bg-neutral-900 p-5 space-y-4">
        <h2 className="text-lg font-semibold text-neutral-50">New Packing Run â€” Step {step} of 3</h2>

        {step === 1 && (
          <div>
            <label className="text-sm text-neutral-400">Select Batch</label>
            <select value={batchId} onChange={(e) => setBatchId(e.target.value)}
              className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600">
              {productionBatches.map((b) => (
                <option key={b.id} value={b.id}>{b.id} â€” {b.leftoverQtyKg} kg available</option>
              ))}
            </select>
          </div>
        )}

        {step === 2 && (
          <div className="space-y-3">
            <div>
              <label className="text-sm text-neutral-400">Packaging Material</label>
              <select value={packagingId} onChange={(e) => setPackagingId(e.target.value)}
                className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600">
                {packagingMaterials.map((p) => (
                  <option key={p.id} value={p.id}>{p.name} â€” {p.stockQty} in stock</option>
                ))}
              </select>
            </div>
            <div>
              <label className="text-sm text-neutral-400">Packets per Carton</label>
              <input value={packetsPerCarton} onChange={(e) => setPacketsPerCarton(e.target.value)} type="number"
                className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
            </div>
            <div>
              <label className="text-sm text-neutral-400">Number of Cartons</label>
              <input value={cartons} onChange={(e) => setCartons(e.target.value)} type="number"
                className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
            </div>
            <div>
              <label className="text-sm text-neutral-400">Bulk Product Used (kg)</label>
              <input value={bulkKgUsed} onChange={(e) => setBulkKgUsed(e.target.value)} type="number"
                className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
            </div>
          </div>
        )}

        {step === 3 && (
          <div className="rounded-lg border border-neutral-800 bg-neutral-950 p-4 space-y-2">
            <div className="flex justify-between text-sm"><span className="text-neutral-400">Source Batch</span><span className="text-neutral-50">{batchId}</span></div>
            <div className="flex justify-between text-sm"><span className="text-neutral-400">Packaging</span><span className="text-neutral-50">{packaging?.name}</span></div>
            <div className="flex justify-between text-sm"><span className="text-neutral-400">Cartons</span><span className="text-neutral-50">{cartons}</span></div>
            <div className="flex justify-between text-sm"><span className="text-neutral-400">Bulk Used</span><span className="text-neutral-50">{bulkKgUsed} kg</span></div>
            <div className="flex justify-between text-sm pt-2 border-t border-neutral-800">
              <span className="text-neutral-400">Est. Cost / Carton</span>
              <span className="text-neutral-50 font-semibold">Rs. {costPerCarton.toFixed(2)}</span>
            </div>
          </div>
        )}

        <div className="flex justify-between pt-2">
          <button onClick={() => (step === 1 ? onClose() : setStep(step - 1))} className="rounded-lg px-4 py-2 text-sm text-neutral-300 hover:bg-neutral-800">
            {step === 1 ? "Cancel" : "Back"}
          </button>
          {step < 3 ? (
            <button onClick={() => setStep(step + 1)} className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200">Next</button>
          ) : (
            <button onClick={handleConfirm} className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200">Confirm Packing</button>
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
        <h1 className="text-xl font-semibold text-neutral-50">Finished Cartons</h1>
        <button onClick={() => setDialogOpen(true)} className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200">
          + New Packing Run
        </button>
      </div>

      <div className="flex gap-2 border-b border-neutral-800">
        <button onClick={() => setTab("ready")} className={`px-4 py-2 text-sm font-medium border-b-2 ${tab === "ready" ? "border-neutral-50 text-neutral-50" : "border-transparent text-neutral-400"}`}>
          Ready for Sale
        </button>
        <button onClick={() => setTab("leftover")} className={`px-4 py-2 text-sm font-medium border-b-2 ${tab === "leftover" ? "border-neutral-50 text-neutral-50" : "border-transparent text-neutral-400"}`}>
          Unpacked / Leftover
        </button>
      </div>

      {tab === "ready" ? (
        <div className="overflow-hidden rounded-xl border border-neutral-800">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-neutral-800 bg-neutral-900 text-left text-neutral-400">
                <th className="px-4 py-3 font-medium">Carton</th>
                <th className="px-4 py-3 font-medium">Source Batch</th>
                <th className="px-4 py-3 font-medium">Packets/Carton</th>
                <th className="px-4 py-3 font-medium">Cost/Carton</th>
                <th className="px-4 py-3 font-medium">Stock Qty</th>
              </tr>
            </thead>
            <tbody>
              {cartons.map((c) => (
                <tr key={c.id} className="border-b border-neutral-900 last:border-0 hover:bg-neutral-900/60">
                  <td className="px-4 py-3 text-neutral-50">{c.name}</td>
                  <td className="px-4 py-3 text-neutral-300">{c.sourceBatchId}</td>
                  <td className="px-4 py-3 text-neutral-300">{c.packetsPerCarton}</td>
                  <td className="px-4 py-3 text-neutral-300">Rs. {c.costPerCarton.toLocaleString()}</td>
                  <td className="px-4 py-3 text-neutral-300">{c.stockQty}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      ) : (
        <div className="overflow-hidden rounded-xl border border-neutral-800">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-neutral-800 bg-neutral-900 text-left text-neutral-400">
                <th className="px-4 py-3 font-medium">Batch</th>
                <th className="px-4 py-3 font-medium">Leftover Bulk (kg)</th>
                <th className="px-4 py-3 font-medium">Bulk Cost/Kg</th>
              </tr>
            </thead>
            <tbody>
              {leftoverBatches.map((b) => (
                <tr key={b.id} className="border-b border-neutral-900 last:border-0 hover:bg-neutral-900/60">
                  <td className="px-4 py-3 text-neutral-50">{b.id}</td>
                  <td className="px-4 py-3 text-neutral-300">{b.leftoverQtyKg} kg</td>
                  <td className="px-4 py-3 text-neutral-300">Rs. {b.bulkCostPerKg.toLocaleString()}</td>
                </tr>
              ))}
              {leftoverBatches.length === 0 && (
                <tr><td colSpan={3} className="px-4 py-8 text-center text-neutral-500">No leftover bulk product.</td></tr>
              )}
            </tbody>
          </table>
        </div>
      )}

      <NewPackingRunDialog open={dialogOpen} onClose={() => setDialogOpen(false)} />
    </div>
  );
}