"use client";

import { useMemo, useState } from "react";
import Link from "next/link";
import { toast } from "sonner";
import { useStore } from "@/lib/store";

function NewPackingRunDialog({ open, onClose }: { open: boolean; onClose: () => void }) {
  const productionBatches = useStore((s) => s.productionBatches);
  const cartonConfigurations = useStore((s) => s.cartonConfigurations);
  const wrappers = useStore((s) => s.wrappers);
  const boxes = useStore((s) => s.boxes);
  const createPackingRun = useStore((s) => s.createPackingRun);

  const [step, setStep] = useState(1);
  const [batchId, setBatchId] = useState(productionBatches.find((b) => b.leftoverQtyKg > 0)?.id ?? productionBatches[0]?.id ?? "");
  const [configId, setConfigId] = useState(cartonConfigurations[0]?.id ?? "");
  const [cartonsProduced, setCartonsProduced] = useState("10");

  if (!open) return null;

  const batch = productionBatches.find((b) => b.id === batchId);
  const config = cartonConfigurations.find((c) => c.id === configId);
  const wrapper = wrappers.find((w) => w.id === config?.wrapperId);
  const box = boxes.find((b) => b.id === config?.boxId);

  const cartons = Number(cartonsProduced) || 0;
  const boxesNeeded = config ? cartons * config.boxesPerCarton : 0;
  const packetsNeeded = config ? boxesNeeded * config.packetsPerBox : 0;

  const insufficientWrapper = wrapper ? packetsNeeded > wrapper.stockQty : false;
  const insufficientBox = box ? boxesNeeded > box.stockQty : false;

  // Preview estimate - mirrors the store's internal calculation
  const preview = useMemo(() => {
    if (!batch || !config || !wrapper || !box || cartons <= 0) return null;
    const nominalKgPerPacket = 0.05;
    const estimatedKgNeeded = packetsNeeded * nominalKgPerPacket;
    const bulkKgUsed = Math.min(estimatedKgNeeded, batch.leftoverQtyKg);
    const bulkCostShare = batch.bulkCostPerKg * bulkKgUsed;
    const costPerPacket = packetsNeeded > 0 ? bulkCostShare / packetsNeeded + wrapper.unitCost : wrapper.unitCost;
    const costPerBox = config.packetsPerBox * costPerPacket + box.unitCost;
    const costPerCarton = config.boxesPerCarton * costPerBox;
    return { bulkKgUsed, costPerPacket, costPerBox, costPerCarton };
  }, [batch, config, wrapper, box, cartons, packetsNeeded]);

  const reset = () => {
    setStep(1);
    setCartonsProduced("10");
  };

  const handleConfirm = () => {
    if (!batch || !config) return;
    if (cartons <= 0) {
      toast.error("Enter a valid number of cartons");
      return;
    }
    if (insufficientWrapper) {
      toast.error(`Not enough ${wrapper?.name} in stock`);
      return;
    }
    if (insufficientBox) {
      toast.error(`Not enough ${box?.name} in stock`);
      return;
    }
    createPackingRun({ batchId, configId, cartonsProduced: cartons });
    toast.success(`Packing run confirmed - ${cartons} cartons added to ready stock`);
    reset();
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-3 sm:p-4">
      <div className="w-full max-w-md rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-5 space-y-4">
        <h2 className="text-lg font-semibold text-[var(--foreground)]">New Packing Run - Step {step} of 3</h2>

        {step === 1 && (
          <div>
            <label className="text-sm text-[var(--text-muted)]">Select Batch</label>
            <select value={batchId} onChange={(e) => setBatchId(e.target.value)}
              className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]">
              {productionBatches.map((b) => (
                <option key={b.id} value={b.id}>{b.id} - {b.leftoverQtyKg} kg available</option>
              ))}
            </select>
          </div>
        )}

        {step === 2 && (
          <div className="space-y-3">
            <div>
              <label className="text-sm text-[var(--text-muted)]">Carton Configuration</label>
              <select value={configId} onChange={(e) => setConfigId(e.target.value)}
                className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]">
                {cartonConfigurations.length === 0 && <option value="">No configurations available</option>}
                {cartonConfigurations.map((c) => {
                  const w = wrappers.find((wr) => wr.id === c.wrapperId);
                  const b = boxes.find((bx) => bx.id === c.boxId);
                  return (
                    <option key={c.id} value={c.id}>
                      {w?.name ?? "?"} x {c.packetsPerBox}/box - {b?.name ?? "?"} x {c.boxesPerCarton}/carton
                    </option>
                  );
                })}
              </select>
              {cartonConfigurations.length === 0 && (
                <p className="text-xs text-red-400 mt-1">
                  No carton configurations exist yet. Create one under{" "}
                  <Link href="/packaging/carton-config" className="underline">Packaging &rarr; Carton Configurations</Link>.
                </p>
              )}
            </div>
            <div>
              <label className="text-sm text-[var(--text-muted)]">Number of Cartons Produced</label>
              <input value={cartonsProduced} onChange={(e) => setCartonsProduced(e.target.value)} type="number"
                className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
            </div>
            {config && (
              <div className="rounded-lg border border-[var(--surface-border)] bg-[var(--background)] p-3 space-y-1 text-xs text-[var(--text-muted)]">
                <div>Boxes needed: <span className="text-[var(--foreground)]">{boxesNeeded}</span> {insufficientBox && <span className="text-red-400">(only {box?.stockQty} in stock)</span>}</div>
                <div>Wrappers/packets needed: <span className="text-[var(--foreground)]">{packetsNeeded}</span> {insufficientWrapper && <span className="text-red-400">(only {wrapper?.stockQty} in stock)</span>}</div>
              </div>
            )}
          </div>
        )}

        {step === 3 && (
          <div className="rounded-lg border border-[var(--surface-border)] bg-[var(--background)] p-4 space-y-2">
            <div className="flex justify-between text-sm"><span className="text-[var(--text-muted)]">Source Batch</span><span className="text-[var(--foreground)]">{batchId}</span></div>
            <div className="flex justify-between text-sm"><span className="text-[var(--text-muted)]">Wrapper</span><span className="text-[var(--foreground)]">{wrapper?.name ?? "-"}</span></div>
            <div className="flex justify-between text-sm"><span className="text-[var(--text-muted)]">Box</span><span className="text-[var(--foreground)]">{box?.name ?? "-"}</span></div>
            <div className="flex justify-between text-sm"><span className="text-[var(--text-muted)]">Cartons Produced</span><span className="text-[var(--foreground)]">{cartons}</span></div>
            {preview && (
              <>
                <div className="flex justify-between text-sm"><span className="text-[var(--text-muted)]">Bulk Product Used</span><span className="text-[var(--foreground)]">{preview.bulkKgUsed.toFixed(2)} kg</span></div>
                <div className="flex justify-between text-sm pt-2 border-t border-[var(--surface-border)]">
                  <span className="text-[var(--text-muted)]">Est. Cost / Packet</span>
                  <span className="text-[var(--foreground)]">Rs. {preview.costPerPacket.toFixed(2)}</span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-[var(--text-muted)]">Est. Cost / Box</span>
                  <span className="text-[var(--foreground)]">Rs. {preview.costPerBox.toFixed(2)}</span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-[var(--text-muted)]">Est. Cost / Carton</span>
                  <span className="text-[var(--foreground)] font-semibold">Rs. {preview.costPerCarton.toFixed(2)}</span>
                </div>
              </>
            )}
          </div>
        )}

        <div className="flex justify-between pt-2">
          <button onClick={() => (step === 1 ? onClose() : setStep(step - 1))} className="rounded-lg px-4 py-2 text-sm text-[var(--text-secondary)] hover:bg-[var(--surface-hover)]">
            {step === 1 ? "Cancel" : "Back"}
          </button>
          {step < 3 ? (
            <button
              onClick={() => setStep(step + 1)}
              disabled={step === 2 && (!config || cartons <= 0)}
              className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-50 dark:text-neutral-950 hover:opacity-90 transition-opacity disabled:opacity-50"
            >
              Next
            </button>
          ) : (
            <button onClick={handleConfirm} className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-50 dark:text-neutral-950 hover:opacity-90 transition-opacity">
              Confirm Packing
            </button>
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
        <button onClick={() => setDialogOpen(true)} className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-50 dark:text-neutral-950 hover:opacity-90 transition-opacity">
          + New Packing Run
        </button>
      </div>

      <div className="flex gap-2 border-b border-[var(--surface-border)]">
        <button onClick={() => setTab("ready")} className={`px-4 py-2 text-sm font-medium border-b-2 ${tab === "ready" ? "border-neutral-900 dark:border-neutral-50 text-[var(--foreground)]" : "border-transparent text-[var(--text-muted)]"}`}>
          Ready for Sale
        </button>
        <button onClick={() => setTab("leftover")} className={`px-4 py-2 text-sm font-medium border-b-2 ${tab === "leftover" ? "border-neutral-900 dark:border-neutral-50 text-[var(--foreground)]" : "border-transparent text-[var(--text-muted)]"}`}>
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
                <th className="px-4 py-3 font-medium">Cartons Produced</th>
                <th className="px-4 py-3 font-medium">Packets/Carton</th>
                <th className="px-4 py-3 font-medium">Cost/Packet</th>
                <th className="px-4 py-3 font-medium">Cost/Box</th>
                <th className="px-4 py-3 font-medium">Cost/Carton</th>
                <th className="px-4 py-3 font-medium">Stock Qty</th>
              </tr>
            </thead>
            <tbody>
              {cartons.map((c) => (
                <tr key={c.id} className="border-b border-[var(--surface-border)] last:border-0 hover:bg-[var(--surface)]/60">
                  <td className="px-4 py-3 text-[var(--foreground)]">{c.name}</td>
                  <td className="px-4 py-3 text-[var(--text-secondary)]">{c.sourceBatchId}</td>
                  <td className="px-4 py-3 text-[var(--text-secondary)]">{c.cartonsProduced}</td>
                  <td className="px-4 py-3 text-[var(--text-secondary)]">{c.packetsPerCarton}</td>
                  <td className="px-4 py-3 text-[var(--text-secondary)]">Rs. {c.costPerPacket.toLocaleString()}</td>
                  <td className="px-4 py-3 text-[var(--text-secondary)]">Rs. {c.costPerBox.toLocaleString()}</td>
                  <td className="px-4 py-3 text-[var(--text-secondary)]">Rs. {c.costPerCarton.toLocaleString()}</td>
                  <td className="px-4 py-3 text-[var(--text-secondary)]">{c.stockQty}</td>
                </tr>
              ))}
              {cartons.length === 0 && (
                <tr><td colSpan={8} className="px-4 py-8 text-center text-[var(--text-faint)]">No finished cartons yet.</td></tr>
              )}
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
                <tr><td colSpan={3} className="px-4 py-8 text-center text-[var(--text-faint)]">No leftover bulk product.</td></tr>
              )}
            </tbody>
          </table>
        </div>
      )}

      <NewPackingRunDialog open={dialogOpen} onClose={() => setDialogOpen(false)} />
    </div>
  );
}