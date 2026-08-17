"use client";

import { use, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { productionBatches } from "@/lib/mock-data/batches";

function OverheadDialog({
  open,
  onClose,
  onSave,
}: {
  open: boolean;
  onClose: () => void;
  onSave: (electricity: number, gas: number, rent: number) => void;
}) {
  const [electricity, setElectricity] = useState("");
  const [gas, setGas] = useState("");
  const [rent, setRent] = useState("");

  if (!open) return null;

  const handleSave = () => {
    onSave(Number(electricity) || 0, Number(gas) || 0, Number(rent) || 0);
    setElectricity("");
    setGas("");
    setRent("");
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4">
      <div className="w-full max-w-sm rounded-xl border border-neutral-800 bg-neutral-900 p-5 space-y-4">
        <h2 className="text-lg font-semibold text-neutral-50">Allocate Month-End Overhead</h2>
        <div className="space-y-3">
          <div>
            <label className="text-sm text-neutral-400">Electricity</label>
            <input
              value={electricity}
              onChange={(e) => setElectricity(e.target.value)}
              type="number"
              className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600"
            />
          </div>
          <div>
            <label className="text-sm text-neutral-400">Gas</label>
            <input
              value={gas}
              onChange={(e) => setGas(e.target.value)}
              type="number"
              className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600"
            />
          </div>
          <div>
            <label className="text-sm text-neutral-400">Rent</label>
            <input
              value={rent}
              onChange={(e) => setRent(e.target.value)}
              type="number"
              className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600"
            />
          </div>
        </div>
        <div className="flex justify-end gap-2 pt-2">
          <button onClick={onClose} className="rounded-lg px-4 py-2 text-sm text-neutral-300 hover:bg-neutral-800">
            Cancel
          </button>
          <button
            onClick={handleSave}
            className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200"
          >
            Save
          </button>
        </div>
      </div>
    </div>
  );
}

export default function BatchDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const router = useRouter();
  const batch = productionBatches.find((b) => b.id === id);
  const [dialogOpen, setDialogOpen] = useState(false);
  const [overheadTotal, setOverheadTotal] = useState(0);

  if (!batch) {
    return (
      <div className="space-y-4">
        <Link href="/batches" className="text-sm text-neutral-400 hover:underline">
          &larr; Back to Batches
        </Link>
        <p className="text-neutral-400">Batch not found.</p>
      </div>
    );
  }

  const adjustedCostPerKg =
    overheadTotal > 0 && batch.outputYieldKg > 0
      ? batch.bulkCostPerKg + overheadTotal / batch.outputYieldKg
      : batch.bulkCostPerKg;

  return (
    <div className="space-y-6">
      <div className="text-sm text-neutral-400">
        <Link href="/batches" className="hover:underline text-neutral-300">
          Batches
        </Link>{" "}
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
              Rs. {adjustedCostPerKg.toLocaleString(undefined, { maximumFractionDigits: 2 })}
            </div>
          </div>
        </div>

        {overheadTotal > 0 && (
          <div className="mt-4 text-xs text-amber-400">
            Overhead of Rs. {overheadTotal.toLocaleString()} allocated across this batch's output.
          </div>
        )}
      </div>

      <div className="flex gap-2">
        <button
          onClick={() => setDialogOpen(true)}
          className="rounded-lg border border-neutral-700 px-4 py-2 text-sm text-neutral-200 hover:bg-neutral-800"
        >
          Allocate Month-End Overhead
        </button>
        <button
          onClick={() => router.push(`/finished-cartons?batchId=${batch.id}`)}
          className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200"
        >
          Send to Packaging
        </button>
      </div>

      <OverheadDialog
        open={dialogOpen}
        onClose={() => setDialogOpen(false)}
        onSave={(electricity, gas, rent) => setOverheadTotal(electricity + gas + rent)}
      />
    </div>
  );
}