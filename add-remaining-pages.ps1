# add-remaining-pages.ps1
# Run from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods
# Usage: .\add-remaining-pages.ps1
#
# Creates/overwrites all remaining frontend pages:
#   customers, customers/[id], batches, batches/new, batches/[id],
#   finished-cartons, invoices, invoices/new, invoices/[id],
#   payments, reports, settings
# Plus lib/mock-data/customer-item-prices.ts (needed for invoice price memory).
#
# Safe to re-run any time - it overwrites these specific files only.

$ErrorActionPreference = "Stop"
$Root = Get-Location
$Frontend = Join-Path $Root "apps\frontend"

function Write-CodeFile {
    param(
        [string]$RelativePath,
        [string]$Content
    )
    $fullPath = Join-Path $Frontend $RelativePath
    $dir = Split-Path $fullPath -Parent
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($fullPath, $Content, $utf8NoBom)
    Write-Host "  wrote $RelativePath" -ForegroundColor Green
}

Write-Host "=== Adding remaining GhaniFoods frontend pages ===" -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# lib/mock-data/customer-item-prices.ts
# ---------------------------------------------------------------------------
Write-CodeFile "lib\mock-data\customer-item-prices.ts" @'
// lib/mock-data/customer-item-prices.ts
export type CustomerItemPrice = {
  customerId: string;
  itemId: string;
  lastSoldPrice: number;
};

export const customerItemPrices: CustomerItemPrice[] = [
  { customerId: "cust-1", itemId: "fc-1", lastSoldPrice: 640 },
  { customerId: "cust-2", itemId: "fc-2", lastSoldPrice: 1180 },
];
'@

# ---------------------------------------------------------------------------
# lib/mock-data/ledger.ts
# ---------------------------------------------------------------------------
Write-CodeFile "lib\mock-data\ledger.ts" @'
// lib/mock-data/ledger.ts
export type LedgerEntry = {
  id: string;
  customerId: string;
  type: "invoice" | "payment" | "adjustment";
  amount: number;
  runningBalance: number;
  date: string;
  note?: string;
};

export const ledgerEntries: LedgerEntry[] = [
  { id: "led-1", customerId: "cust-1", type: "adjustment", amount: 4000, runningBalance: 4000, date: "2026-07-01", note: "Opening balance" },
  { id: "led-2", customerId: "cust-1", type: "invoice", amount: 8700, runningBalance: 12700, date: "2026-08-05", note: "inv-1000" },
  { id: "led-3", customerId: "cust-1", type: "payment", amount: -5800, runningBalance: 6900, date: "2026-08-10", note: "Partial payment" },
  { id: "led-4", customerId: "cust-1", type: "invoice", amount: 18300, runningBalance: 25200, date: "2026-08-15", note: "inv-1001" },
  { id: "led-5", customerId: "cust-1", type: "payment", amount: -12700, runningBalance: 12500, date: "2026-08-16", note: "Partial payment" },
  { id: "led-6", customerId: "cust-2", type: "invoice", amount: 9200, runningBalance: 9200, date: "2026-08-14", note: "inv-1002" },
  { id: "led-7", customerId: "cust-2", type: "payment", amount: -9200, runningBalance: 0, date: "2026-08-15", note: "Full settlement" },
  { id: "led-8", customerId: "cust-2", type: "adjustment", amount: -2000, runningBalance: -2000, date: "2026-08-16", note: "Credit note" },
  { id: "led-9", customerId: "cust-3", type: "invoice", amount: 4600, runningBalance: 4600, date: "2026-08-12", note: "inv-1003" },
];
'@

# ---------------------------------------------------------------------------
# app/(dashboard)/batches/page.tsx
# ---------------------------------------------------------------------------
Write-CodeFile "app\(dashboard)\batches\page.tsx" @'
"use client";

import Link from "next/link";
import { productionBatches } from "@/lib/mock-data/batches";

function StatusBadge({ status }: { status: "in_progress" | "completed" }) {
  const isDone = status === "completed";
  return (
    <span
      className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ${
        isDone
          ? "bg-green-950 text-green-400 border border-green-900"
          : "bg-amber-950 text-amber-400 border border-amber-900"
      }`}
    >
      {isDone ? "Completed" : "In Progress"}
    </span>
  );
}

export default function BatchesPage() {
  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-semibold text-neutral-50">Production Batches</h1>
        <Link
          href="/batches/new"
          className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200"
        >
          + New Batch
        </Link>
      </div>

      <div className="overflow-hidden rounded-xl border border-neutral-800">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-neutral-800 bg-neutral-900 text-left text-neutral-400">
              <th className="px-4 py-3 font-medium">Batch ID</th>
              <th className="px-4 py-3 font-medium">Date</th>
              <th className="px-4 py-3 font-medium">Output Yield (kg)</th>
              <th className="px-4 py-3 font-medium">Wastage (kg)</th>
              <th className="px-4 py-3 font-medium">Leftover (kg)</th>
              <th className="px-4 py-3 font-medium">Bulk Cost/Kg</th>
              <th className="px-4 py-3 font-medium">Status</th>
            </tr>
          </thead>
          <tbody>
            {productionBatches.map((b) => (
              <tr key={b.id} className="border-b border-neutral-900 last:border-0 hover:bg-neutral-900/60">
                <td className="px-4 py-3">
                  <Link href={`/batches/${b.id}`} className="text-neutral-50 hover:underline">
                    {b.id}
                  </Link>
                </td>
                <td className="px-4 py-3 text-neutral-300">{b.batchDate}</td>
                <td className="px-4 py-3 text-neutral-300">{b.outputYieldKg}</td>
                <td className="px-4 py-3 text-neutral-300">{b.wastageKg}</td>
                <td className="px-4 py-3 text-neutral-300">{b.leftoverQtyKg}</td>
                <td className="px-4 py-3 text-neutral-300">
                  {b.bulkCostPerKg > 0 ? `Rs. ${b.bulkCostPerKg.toLocaleString()}` : "—"}
                </td>
                <td className="px-4 py-3">
                  <StatusBadge status={b.status} />
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
'@

# ---------------------------------------------------------------------------
# app/(dashboard)/batches/new/page.tsx
# ---------------------------------------------------------------------------
Write-CodeFile "app\(dashboard)\batches\new\page.tsx" @'
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
                –
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
                {b.id} — {b.leftoverQtyKg} kg leftover
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
'@

# ---------------------------------------------------------------------------
# app/(dashboard)/batches/[id]/page.tsx
# ---------------------------------------------------------------------------
Write-CodeFile "app\(dashboard)\batches\[id]\page.tsx" @'
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
'@

# ---------------------------------------------------------------------------
# app/(dashboard)/finished-cartons/page.tsx
# ---------------------------------------------------------------------------
Write-CodeFile "app\(dashboard)\finished-cartons\page.tsx" @'
"use client";

import { useMemo, useState } from "react";
import { finishedCartons as initialCartons, type FinishedCarton } from "@/lib/mock-data/finished-cartons";
import { productionBatches } from "@/lib/mock-data/batches";
import { packagingMaterials } from "@/lib/mock-data/packaging";

function NewPackingRunDialog({
  open,
  onClose,
  onConfirm,
}: {
  open: boolean;
  onClose: () => void;
  onConfirm: (carton: FinishedCarton) => void;
}) {
  const [step, setStep] = useState(1);
  const [batchId, setBatchId] = useState(productionBatches[0]?.id ?? "");
  const [packagingId, setPackagingId] = useState(packagingMaterials[0]?.id ?? "");
  const [packetsPerCarton, setPacketsPerCarton] = useState("24");
  const [cartons, setCartons] = useState("10");

  if (!open) return null;

  const batch = productionBatches.find((b) => b.id === batchId);
  const packaging = packagingMaterials.find((p) => p.id === packagingId);

  const costPerCarton = useMemo(() => {
    const bulkCost = (batch?.bulkCostPerKg ?? 0) * (Number(packetsPerCarton) || 0) * 0.05; // rough demo estimate
    const packagingCost = packaging?.unitCost ?? 0;
    return bulkCost + packagingCost;
  }, [batch, packaging, packetsPerCarton]);

  const reset = () => {
    setStep(1);
    setPacketsPerCarton("24");
    setCartons("10");
  };

  const handleConfirm = () => {
    onConfirm({
      id: `fc-${Date.now()}`,
      name: `${batch?.id ?? "Batch"} Carton - ${packetsPerCarton}pk`,
      sourceBatchId: batchId,
      packetsPerCarton: Number(packetsPerCarton) || 0,
      costPerCarton: Number(costPerCarton.toFixed(2)),
      stockQty: Number(cartons) || 0,
    });
    reset();
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4">
      <div className="w-full max-w-md rounded-xl border border-neutral-800 bg-neutral-900 p-5 space-y-4">
        <h2 className="text-lg font-semibold text-neutral-50">New Packing Run — Step {step} of 3</h2>

        {step === 1 && (
          <div>
            <label className="text-sm text-neutral-400">Select Batch</label>
            <select
              value={batchId}
              onChange={(e) => setBatchId(e.target.value)}
              className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600"
            >
              {productionBatches.map((b) => (
                <option key={b.id} value={b.id}>
                  {b.id} — {b.leftoverQtyKg} kg available
                </option>
              ))}
            </select>
          </div>
        )}

        {step === 2 && (
          <div className="space-y-3">
            <div>
              <label className="text-sm text-neutral-400">Packaging Material</label>
              <select
                value={packagingId}
                onChange={(e) => setPackagingId(e.target.value)}
                className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600"
              >
                {packagingMaterials.map((p) => (
                  <option key={p.id} value={p.id}>
                    {p.name}
                  </option>
                ))}
              </select>
            </div>
            <div>
              <label className="text-sm text-neutral-400">Packets per Carton</label>
              <input
                value={packetsPerCarton}
                onChange={(e) => setPacketsPerCarton(e.target.value)}
                type="number"
                className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600"
              />
            </div>
            <div>
              <label className="text-sm text-neutral-400">Number of Cartons</label>
              <input
                value={cartons}
                onChange={(e) => setCartons(e.target.value)}
                type="number"
                className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600"
              />
            </div>
          </div>
        )}

        {step === 3 && (
          <div className="rounded-lg border border-neutral-800 bg-neutral-950 p-4 space-y-2">
            <div className="flex justify-between text-sm">
              <span className="text-neutral-400">Source Batch</span>
              <span className="text-neutral-50">{batchId}</span>
            </div>
            <div className="flex justify-between text-sm">
              <span className="text-neutral-400">Packaging</span>
              <span className="text-neutral-50">{packaging?.name}</span>
            </div>
            <div className="flex justify-between text-sm">
              <span className="text-neutral-400">Cartons</span>
              <span className="text-neutral-50">{cartons}</span>
            </div>
            <div className="flex justify-between text-sm pt-2 border-t border-neutral-800">
              <span className="text-neutral-400">Est. Cost / Carton</span>
              <span className="text-neutral-50 font-semibold">Rs. {costPerCarton.toFixed(2)}</span>
            </div>
          </div>
        )}

        <div className="flex justify-between pt-2">
          <button
            onClick={() => (step === 1 ? onClose() : setStep(step - 1))}
            className="rounded-lg px-4 py-2 text-sm text-neutral-300 hover:bg-neutral-800"
          >
            {step === 1 ? "Cancel" : "Back"}
          </button>
          {step < 3 ? (
            <button
              onClick={() => setStep(step + 1)}
              className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200"
            >
              Next
            </button>
          ) : (
            <button
              onClick={handleConfirm}
              className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200"
            >
              Confirm Packing
            </button>
          )}
        </div>
      </div>
    </div>
  );
}

export default function FinishedCartonsPage() {
  const [cartons, setCartons] = useState<FinishedCarton[]>(initialCartons);
  const [tab, setTab] = useState<"ready" | "leftover">("ready");
  const [dialogOpen, setDialogOpen] = useState(false);

  const leftoverBatches = productionBatches.filter((b) => b.leftoverQtyKg > 0);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-semibold text-neutral-50">Finished Cartons</h1>
        <button
          onClick={() => setDialogOpen(true)}
          className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200"
        >
          + New Packing Run
        </button>
      </div>

      <div className="flex gap-2 border-b border-neutral-800">
        <button
          onClick={() => setTab("ready")}
          className={`px-4 py-2 text-sm font-medium border-b-2 ${
            tab === "ready" ? "border-neutral-50 text-neutral-50" : "border-transparent text-neutral-400"
          }`}
        >
          Ready for Sale
        </button>
        <button
          onClick={() => setTab("leftover")}
          className={`px-4 py-2 text-sm font-medium border-b-2 ${
            tab === "leftover" ? "border-neutral-50 text-neutral-50" : "border-transparent text-neutral-400"
          }`}
        >
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
                <tr>
                  <td colSpan={3} className="px-4 py-8 text-center text-neutral-500">
                    No leftover bulk product.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      )}

      <NewPackingRunDialog
        open={dialogOpen}
        onClose={() => setDialogOpen(false)}
        onConfirm={(c) => setCartons((prev) => [...prev, c])}
      />
    </div>
  );
}
'@

# ---------------------------------------------------------------------------
# app/(dashboard)/customers/page.tsx
# ---------------------------------------------------------------------------
Write-CodeFile "app\(dashboard)\customers\page.tsx" @'
"use client";

import { useMemo, useState } from "react";
import Link from "next/link";
import { customers as initialCustomers, type Customer } from "@/lib/mock-data/customers";

function BalanceCell({ balance }: { balance: number }) {
  const owes = balance > 0;
  const isZero = balance === 0;
  return (
    <span className={isZero ? "text-neutral-400" : owes ? "text-red-400" : "text-green-400"}>
      Rs. {Math.abs(balance).toLocaleString()} {!isZero && (owes ? "(owes)" : "(credit)")}
    </span>
  );
}

function AddCustomerDialog({
  open,
  onClose,
  onAdd,
}: {
  open: boolean;
  onClose: () => void;
  onAdd: (c: Customer) => void;
}) {
  const [name, setName] = useState("");
  const [phone, setPhone] = useState("");
  const [opening, setOpening] = useState("0");

  if (!open) return null;

  const handleSave = () => {
    if (!name.trim()) return;
    onAdd({ id: `cust-${Date.now()}`, name: name.trim(), phone, currentBalance: Number(opening) || 0 });
    setName("");
    setPhone("");
    setOpening("0");
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4">
      <div className="w-full max-w-sm rounded-xl border border-neutral-800 bg-neutral-900 p-5 space-y-4">
        <h2 className="text-lg font-semibold text-neutral-50">Add Customer</h2>
        <div className="space-y-3">
          <div>
            <label className="text-sm text-neutral-400">Name</label>
            <input
              value={name}
              onChange={(e) => setName(e.target.value)}
              className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600"
            />
          </div>
          <div>
            <label className="text-sm text-neutral-400">Phone</label>
            <input
              value={phone}
              onChange={(e) => setPhone(e.target.value)}
              className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600"
            />
          </div>
          <div>
            <label className="text-sm text-neutral-400">Opening Balance</label>
            <input
              value={opening}
              onChange={(e) => setOpening(e.target.value)}
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

export default function CustomersPage() {
  const [items, setItems] = useState<Customer[]>(initialCustomers);
  const [search, setSearch] = useState("");
  const [dialogOpen, setDialogOpen] = useState(false);

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    if (!q) return items;
    return items.filter((c) => c.name.toLowerCase().includes(q));
  }, [items, search]);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-semibold text-neutral-50">Customers</h1>
        <button
          onClick={() => setDialogOpen(true)}
          className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200"
        >
          + Add Customer
        </button>
      </div>

      <input
        value={search}
        onChange={(e) => setSearch(e.target.value)}
        placeholder="Search customers..."
        className="w-full max-w-sm rounded-lg border border-neutral-800 bg-neutral-900 px-3 py-2 text-sm text-neutral-50 placeholder:text-neutral-500 outline-none focus:border-neutral-600"
      />

      <div className="overflow-hidden rounded-xl border border-neutral-800">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-neutral-800 bg-neutral-900 text-left text-neutral-400">
              <th className="px-4 py-3 font-medium">Name</th>
              <th className="px-4 py-3 font-medium">Phone</th>
              <th className="px-4 py-3 font-medium">Current Balance</th>
            </tr>
          </thead>
          <tbody>
            {filtered.map((c) => (
              <tr key={c.id} className="border-b border-neutral-900 last:border-0 hover:bg-neutral-900/60">
                <td className="px-4 py-3">
                  <Link href={`/customers/${c.id}`} className="text-neutral-50 hover:underline">
                    {c.name}
                  </Link>
                </td>
                <td className="px-4 py-3 text-neutral-300">{c.phone}</td>
                <td className="px-4 py-3">
                  <BalanceCell balance={c.currentBalance} />
                </td>
              </tr>
            ))}
            {filtered.length === 0 && (
              <tr>
                <td colSpan={3} className="px-4 py-8 text-center text-neutral-500">
                  No customers found.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>

      <AddCustomerDialog open={dialogOpen} onClose={() => setDialogOpen(false)} onAdd={(c) => setItems((prev) => [...prev, c])} />
    </div>
  );
}
'@

# ---------------------------------------------------------------------------
# app/(dashboard)/customers/[id]/page.tsx
# ---------------------------------------------------------------------------
Write-CodeFile "app\(dashboard)\customers\[id]\page.tsx" @'
"use client";

import { use, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { customers } from "@/lib/mock-data/customers";
import { ledgerEntries as initialLedger, type LedgerEntry } from "@/lib/mock-data/ledger";

function RecordPaymentDialog({
  open,
  onClose,
  onSave,
}: {
  open: boolean;
  onClose: () => void;
  onSave: (amount: number, note: string) => void;
}) {
  const [amount, setAmount] = useState("");
  const [note, setNote] = useState("");

  if (!open) return null;

  const handleSave = () => {
    const a = Number(amount);
    if (!a) return;
    onSave(a, note);
    setAmount("");
    setNote("");
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4">
      <div className="w-full max-w-sm rounded-xl border border-neutral-800 bg-neutral-900 p-5 space-y-4">
        <h2 className="text-lg font-semibold text-neutral-50">Record Payment</h2>
        <div className="space-y-3">
          <div>
            <label className="text-sm text-neutral-400">Amount</label>
            <input
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              type="number"
              className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600"
            />
          </div>
          <div>
            <label className="text-sm text-neutral-400">Note</label>
            <input
              value={note}
              onChange={(e) => setNote(e.target.value)}
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

export default function CustomerDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const router = useRouter();
  const customer = customers.find((c) => c.id === id);
  const [ledger, setLedger] = useState<LedgerEntry[]>(initialLedger.filter((l) => l.customerId === id));
  const [dialogOpen, setDialogOpen] = useState(false);

  if (!customer) {
    return (
      <div className="space-y-4">
        <Link href="/customers" className="text-sm text-neutral-400 hover:underline">
          &larr; Back to Customers
        </Link>
        <p className="text-neutral-400">Customer not found.</p>
      </div>
    );
  }

  const totalInvoiced = ledger.filter((l) => l.type === "invoice").reduce((sum, l) => sum + l.amount, 0);
  const totalPaid = ledger.filter((l) => l.type === "payment").reduce((sum, l) => sum + Math.abs(l.amount), 0);
  const currentBalance = ledger.length > 0 ? ledger[ledger.length - 1].runningBalance : customer.currentBalance;

  const handlePayment = (amount: number, note: string) => {
    const newBalance = currentBalance - amount;
    setLedger((prev) => [
      ...prev,
      {
        id: `led-${Date.now()}`,
        customerId: customer.id,
        type: "payment",
        amount: -amount,
        runningBalance: newBalance,
        date: new Date().toISOString().slice(0, 10),
        note: note || "Payment received",
      },
    ]);
  };

  return (
    <div className="space-y-6">
      <div className="text-sm text-neutral-400">
        <Link href="/customers" className="hover:underline text-neutral-300">
          Customers
        </Link>{" "}
        / <span className="text-neutral-50">{customer.name}</span>
      </div>

      <div className="rounded-xl border border-neutral-800 bg-neutral-900 p-5">
        <h1 className="text-xl font-semibold text-neutral-50">{customer.name}</h1>
        <p className="text-sm text-neutral-400 mt-1">{customer.phone}</p>

        <div className="mt-5 grid grid-cols-1 sm:grid-cols-3 gap-4">
          <div>
            <div className="text-neutral-400 text-xs">Current Balance</div>
            <div className={`text-lg font-semibold mt-1 ${currentBalance > 0 ? "text-red-400" : "text-green-400"}`}>
              Rs. {Math.abs(currentBalance).toLocaleString()}
            </div>
          </div>
          <div>
            <div className="text-neutral-400 text-xs">Total Invoiced</div>
            <div className="text-lg font-semibold text-neutral-50 mt-1">Rs. {totalInvoiced.toLocaleString()}</div>
          </div>
          <div>
            <div className="text-neutral-400 text-xs">Total Paid</div>
            <div className="text-lg font-semibold text-neutral-50 mt-1">Rs. {totalPaid.toLocaleString()}</div>
          </div>
        </div>
      </div>

      <div className="flex gap-2">
        <button
          onClick={() => setDialogOpen(true)}
          className="rounded-lg border border-neutral-700 px-4 py-2 text-sm text-neutral-200 hover:bg-neutral-800"
        >
          + Record Payment
        </button>
        <button
          onClick={() => router.push(`/invoices/new?customerId=${customer.id}`)}
          className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200"
        >
          New Invoice for this Customer
        </button>
      </div>

      <h2 className="text-lg font-semibold text-neutral-50">Ledger History</h2>
      <div className="overflow-hidden rounded-xl border border-neutral-800">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-neutral-800 bg-neutral-900 text-left text-neutral-400">
              <th className="px-4 py-3 font-medium">Date</th>
              <th className="px-4 py-3 font-medium">Type</th>
              <th className="px-4 py-3 font-medium">Note</th>
              <th className="px-4 py-3 font-medium">Amount</th>
              <th className="px-4 py-3 font-medium">Running Balance</th>
            </tr>
          </thead>
          <tbody>
            {ledger.map((l) => (
              <tr key={l.id} className="border-b border-neutral-900 last:border-0 hover:bg-neutral-900/60">
                <td className="px-4 py-3 text-neutral-300">{l.date}</td>
                <td className="px-4 py-3 text-neutral-300 capitalize">{l.type}</td>
                <td className="px-4 py-3 text-neutral-300">{l.note}</td>
                <td className={`px-4 py-3 ${l.amount >= 0 ? "text-red-400" : "text-green-400"}`}>
                  {l.amount >= 0 ? "+" : ""}
                  Rs. {l.amount.toLocaleString()}
                </td>
                <td className="px-4 py-3 text-neutral-300">Rs. {l.runningBalance.toLocaleString()}</td>
              </tr>
            ))}
            {ledger.length === 0 && (
              <tr>
                <td colSpan={5} className="px-4 py-8 text-center text-neutral-500">
                  No ledger entries yet.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>

      <RecordPaymentDialog open={dialogOpen} onClose={() => setDialogOpen(false)} onSave={handlePayment} />
    </div>
  );
}
'@

# ---------------------------------------------------------------------------
# app/(dashboard)/invoices/page.tsx
# ---------------------------------------------------------------------------
Write-CodeFile "app\(dashboard)\invoices\page.tsx" @'
"use client";

import Link from "next/link";
import { invoices } from "@/lib/mock-data/invoices";

function StatusBadge({ status }: { status: "unpaid" | "partial" | "paid" }) {
  const styles: Record<string, string> = {
    paid: "bg-green-950 text-green-400 border border-green-900",
    partial: "bg-amber-950 text-amber-400 border border-amber-900",
    unpaid: "bg-red-950 text-red-400 border border-red-900",
  };
  return (
    <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ${styles[status]}`}>
      {status[0].toUpperCase() + status.slice(1)}
    </span>
  );
}

export default function InvoicesPage() {
  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-semibold text-neutral-50">Invoices</h1>
        <Link
          href="/invoices/new"
          className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200"
        >
          + New Invoice
        </Link>
      </div>

      <div className="overflow-hidden rounded-xl border border-neutral-800">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-neutral-800 bg-neutral-900 text-left text-neutral-400">
              <th className="px-4 py-3 font-medium">Invoice #</th>
              <th className="px-4 py-3 font-medium">Customer</th>
              <th className="px-4 py-3 font-medium">Date</th>
              <th className="px-4 py-3 font-medium">Total</th>
              <th className="px-4 py-3 font-medium">Status</th>
            </tr>
          </thead>
          <tbody>
            {invoices.map((inv) => (
              <tr key={inv.id} className="border-b border-neutral-900 last:border-0 hover:bg-neutral-900/60">
                <td className="px-4 py-3">
                  <Link href={`/invoices/${inv.id}`} className="text-neutral-50 hover:underline">
                    {inv.id}
                  </Link>
                </td>
                <td className="px-4 py-3 text-neutral-300">{inv.customerName}</td>
                <td className="px-4 py-3 text-neutral-300">{inv.invoiceDate}</td>
                <td className="px-4 py-3 text-neutral-300">Rs. {inv.totalAmount.toLocaleString()}</td>
                <td className="px-4 py-3">
                  <StatusBadge status={inv.status} />
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
'@

# ---------------------------------------------------------------------------
# app/(dashboard)/invoices/new/page.tsx
# ---------------------------------------------------------------------------
Write-CodeFile "app\(dashboard)\invoices\new\page.tsx" @'
"use client";

import { Suspense, useMemo, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { customers } from "@/lib/mock-data/customers";
import { finishedCartons } from "@/lib/mock-data/finished-cartons";
import { customerItemPrices } from "@/lib/mock-data/customer-item-prices";
import { invoices } from "@/lib/mock-data/invoices";

type InvoiceLine = { id: string; itemId: string; qty: string; unitPrice: string };

function lastSoldPrice(customerId: string, itemId: string) {
  return customerItemPrices.find((p) => p.customerId === customerId && p.itemId === itemId)?.lastSoldPrice;
}

function NewInvoiceForm() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const preselectedCustomerId = searchParams.get("customerId") ?? "";

  const [customerId, setCustomerId] = useState(preselectedCustomerId || customers[0]?.id || "");
  const [margin, setMargin] = useState("20");
  const [lines, setLines] = useState<InvoiceLine[]>([
    { id: crypto.randomUUID(), itemId: finishedCartons[0]?.id ?? "", qty: "1", unitPrice: "" },
  ]);

  const addLine = () => {
    setLines((prev) => [...prev, { id: crypto.randomUUID(), itemId: finishedCartons[0]?.id ?? "", qty: "1", unitPrice: "" }]);
  };

  const removeLine = (id: string) => {
    setLines((prev) => (prev.length > 1 ? prev.filter((l) => l.id !== id) : prev));
  };

  const updateLine = (id: string, patch: Partial<InvoiceLine>) => {
    setLines((prev) => prev.map((l) => (l.id === id ? { ...l, ...patch } : l)));
  };

  const handleItemChange = (id: string, itemId: string) => {
    const carton = finishedCartons.find((c) => c.id === itemId);
    const memorized = lastSoldPrice(customerId, itemId);
    const marginMultiplier = 1 + (Number(margin) || 0) / 100;
    const fallback = carton ? Math.round(carton.costPerCarton * marginMultiplier) : 0;
    updateLine(id, { itemId, unitPrice: String(memorized ?? fallback) });
  };

  const total = useMemo(() => {
    return lines.reduce((sum, l) => sum + (Number(l.qty) || 0) * (Number(l.unitPrice) || 0), 0);
  }, [lines]);

  const handleSave = () => {
    // Demo build: no real persistence, navigate to an existing invoice detail.
    router.push(`/invoices/${invoices[0]?.id ?? ""}`);
  };

  const selectedCustomer = customers.find((c) => c.id === customerId);

  return (
    <div className="space-y-6 max-w-3xl">
      <h1 className="text-xl font-semibold text-neutral-50">New Invoice</h1>

      <div className="rounded-xl border border-neutral-800 bg-neutral-900 p-5 space-y-4">
        <div>
          <label className="text-sm text-neutral-400">Customer</label>
          <select
            value={customerId}
            onChange={(e) => setCustomerId(e.target.value)}
            className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600"
          >
            {customers.map((c) => (
              <option key={c.id} value={c.id}>
                {c.name}
              </option>
            ))}
          </select>
          {selectedCustomer && (
            <p className="text-xs text-neutral-500 mt-1">
              Current balance: Rs. {Math.abs(selectedCustomer.currentBalance).toLocaleString()}{" "}
              {selectedCustomer.currentBalance > 0 ? "(owes)" : "(credit)"}
            </p>
          )}
        </div>

        <div>
          <label className="text-sm text-neutral-400">Margin % (used for items with no price history)</label>
          <input
            value={margin}
            onChange={(e) => setMargin(e.target.value)}
            type="number"
            className="mt-1 w-40 rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600"
          />
        </div>
      </div>

      <div className="rounded-xl border border-neutral-800 bg-neutral-900 p-5 space-y-4">
        <div className="flex items-center justify-between">
          <h2 className="text-sm font-semibold text-neutral-200">Invoice Items</h2>
          <button
            onClick={addLine}
            className="rounded-lg border border-neutral-700 px-3 py-1.5 text-xs text-neutral-200 hover:bg-neutral-800"
          >
            + Add Item
          </button>
        </div>

        <div className="space-y-3">
          {lines.map((line) => {
            const memorized = lastSoldPrice(customerId, line.itemId);
            return (
              <div key={line.id} className="space-y-1">
                <div className="flex items-center gap-2">
                  <select
                    value={line.itemId}
                    onChange={(e) => handleItemChange(line.id, e.target.value)}
                    className="flex-1 rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600"
                  >
                    {finishedCartons.map((c) => (
                      <option key={c.id} value={c.id}>
                        {c.name}
                      </option>
                    ))}
                  </select>
                  <input
                    value={line.qty}
                    onChange={(e) => updateLine(line.id, { qty: e.target.value })}
                    type="number"
                    placeholder="Qty"
                    className="w-20 rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600"
                  />
                  <input
                    value={line.unitPrice}
                    onChange={(e) => updateLine(line.id, { unitPrice: e.target.value })}
                    type="number"
                    placeholder="Unit Price"
                    className="w-28 rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600"
                  />
                  <button
                    onClick={() => removeLine(line.id)}
                    className="rounded-lg border border-neutral-800 px-3 py-2 text-sm text-neutral-400 hover:bg-neutral-800"
                  >
                    –
                  </button>
                </div>
                {memorized !== undefined && (
                  <span className="inline-block rounded-full bg-neutral-800 px-2.5 py-0.5 text-xs text-neutral-300">
                    Last price: Rs. {memorized.toLocaleString()}
                  </span>
                )}
              </div>
            );
          })}
        </div>
      </div>

      <div className="rounded-xl border border-neutral-800 bg-neutral-900 p-5 flex items-center justify-between">
        <span className="text-sm text-neutral-400">Total</span>
        <span className="text-2xl font-semibold text-neutral-50">Rs. {total.toLocaleString()}</span>
      </div>

      <div className="flex justify-end gap-2">
        <button
          onClick={() => router.push("/invoices")}
          className="rounded-lg px-4 py-2 text-sm text-neutral-300 hover:bg-neutral-800"
        >
          Cancel
        </button>
        <button
          onClick={handleSave}
          className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200"
        >
          Save & Generate Invoice
        </button>
      </div>
    </div>
  );
}

export default function NewInvoicePage() {
  return (
    <Suspense fallback={<div className="text-neutral-400 text-sm">Loading...</div>}>
      <NewInvoiceForm />
    </Suspense>
  );
}
'@

# ---------------------------------------------------------------------------
# app/(dashboard)/invoices/[id]/page.tsx
# ---------------------------------------------------------------------------
Write-CodeFile "app\(dashboard)\invoices\[id]\page.tsx" @'
"use client";

import { use, useState } from "react";
import Link from "next/link";
import { invoices } from "@/lib/mock-data/invoices";

function RecordPaymentDialog({
  open,
  onClose,
  customerName,
}: {
  open: boolean;
  onClose: () => void;
  customerName: string;
}) {
  const [amount, setAmount] = useState("");

  if (!open) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4">
      <div className="w-full max-w-sm rounded-xl border border-neutral-800 bg-neutral-900 p-5 space-y-4">
        <h2 className="text-lg font-semibold text-neutral-50">Record Payment — {customerName}</h2>
        <div>
          <label className="text-sm text-neutral-400">Amount</label>
          <input
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            type="number"
            className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600"
          />
        </div>
        <div className="flex justify-end gap-2 pt-2">
          <button onClick={onClose} className="rounded-lg px-4 py-2 text-sm text-neutral-300 hover:bg-neutral-800">
            Cancel
          </button>
          <button
            onClick={onClose}
            className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200"
          >
            Save
          </button>
        </div>
      </div>
    </div>
  );
}

export default function InvoiceDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const invoice = invoices.find((i) => i.id === id);
  const [dialogOpen, setDialogOpen] = useState(false);

  if (!invoice) {
    return (
      <div className="space-y-4">
        <Link href="/invoices" className="text-sm text-neutral-400 hover:underline">
          &larr; Back to Invoices
        </Link>
        <p className="text-neutral-400">Invoice not found.</p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="text-sm text-neutral-400">
        <Link href="/invoices" className="hover:underline text-neutral-300">
          Invoices
        </Link>{" "}
        / <span className="text-neutral-50">{invoice.id}</span>
      </div>

      <div className="rounded-xl border border-neutral-800 bg-neutral-900 p-6 print:border-0">
        <div className="flex items-start justify-between">
          <div>
            <h1 className="text-xl font-semibold text-neutral-50">Invoice {invoice.id}</h1>
            <p className="text-sm text-neutral-400 mt-1">{invoice.invoiceDate}</p>
          </div>
          <div className="text-right">
            <div className="text-neutral-400 text-xs">Billed To</div>
            <div className="text-neutral-50 font-medium">{invoice.customerName}</div>
          </div>
        </div>

        <div className="mt-6 rounded-lg border border-neutral-800 overflow-hidden">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-neutral-800 bg-neutral-950 text-left text-neutral-400">
                <th className="px-4 py-2 font-medium">Item</th>
                <th className="px-4 py-2 font-medium">Qty</th>
                <th className="px-4 py-2 font-medium">Unit Price</th>
                <th className="px-4 py-2 font-medium">Subtotal</th>
              </tr>
            </thead>
            <tbody>
              <tr>
                <td className="px-4 py-2 text-neutral-300">Nimko Carton (demo line)</td>
                <td className="px-4 py-2 text-neutral-300">—</td>
                <td className="px-4 py-2 text-neutral-300">—</td>
                <td className="px-4 py-2 text-neutral-300">Rs. {invoice.totalAmount.toLocaleString()}</td>
              </tr>
            </tbody>
          </table>
        </div>

        <div className="mt-4 flex justify-end">
          <div className="text-lg font-semibold text-neutral-50">Total: Rs. {invoice.totalAmount.toLocaleString()}</div>
        </div>
      </div>

      <div className="flex gap-2 print:hidden">
        <button
          onClick={() => window.print()}
          className="rounded-lg border border-neutral-700 px-4 py-2 text-sm text-neutral-200 hover:bg-neutral-800"
        >
          Print
        </button>
        <button
          onClick={() => alert("PDF generation not implemented yet (demo build).")}
          className="rounded-lg border border-neutral-700 px-4 py-2 text-sm text-neutral-200 hover:bg-neutral-800"
        >
          Download PDF
        </button>
        <button
          onClick={() => setDialogOpen(true)}
          className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200"
        >
          Record Payment
        </button>
      </div>

      <RecordPaymentDialog open={dialogOpen} onClose={() => setDialogOpen(false)} customerName={invoice.customerName} />
    </div>
  );
}
'@

# ---------------------------------------------------------------------------
# app/(dashboard)/payments/page.tsx
# ---------------------------------------------------------------------------
Write-CodeFile "app\(dashboard)\payments\page.tsx" @'
"use client";

import { useState } from "react";
import { payments as initialPayments, type Payment } from "@/lib/mock-data/payments";
import { customers } from "@/lib/mock-data/customers";

function RecordPaymentDialog({
  open,
  onClose,
  onSave,
}: {
  open: boolean;
  onClose: () => void;
  onSave: (payment: Payment) => void;
}) {
  const [customerId, setCustomerId] = useState(customers[0]?.id ?? "");
  const [amount, setAmount] = useState("");
  const [note, setNote] = useState("");

  if (!open) return null;

  const handleSave = () => {
    const a = Number(amount);
    if (!a) return;
    const customer = customers.find((c) => c.id === customerId);
    onSave({
      id: `pay-${Date.now()}`,
      customerId,
      customerName: customer?.name ?? "Unknown",
      amount: a,
      note,
      paidAt: new Date().toISOString().slice(0, 10),
    });
    setAmount("");
    setNote("");
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4">
      <div className="w-full max-w-sm rounded-xl border border-neutral-800 bg-neutral-900 p-5 space-y-4">
        <h2 className="text-lg font-semibold text-neutral-50">Record Payment</h2>
        <div className="space-y-3">
          <div>
            <label className="text-sm text-neutral-400">Customer</label>
            <select
              value={customerId}
              onChange={(e) => setCustomerId(e.target.value)}
              className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600"
            >
              {customers.map((c) => (
                <option key={c.id} value={c.id}>
                  {c.name}
                </option>
              ))}
            </select>
          </div>
          <div>
            <label className="text-sm text-neutral-400">Amount</label>
            <input
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              type="number"
              className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600"
            />
          </div>
          <div>
            <label className="text-sm text-neutral-400">Note</label>
            <input
              value={note}
              onChange={(e) => setNote(e.target.value)}
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

export default function PaymentsPage() {
  const [items, setItems] = useState<Payment[]>(initialPayments);
  const [dialogOpen, setDialogOpen] = useState(false);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-semibold text-neutral-50">Payments</h1>
        <button
          onClick={() => setDialogOpen(true)}
          className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200"
        >
          + Record Payment
        </button>
      </div>

      <div className="overflow-hidden rounded-xl border border-neutral-800">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-neutral-800 bg-neutral-900 text-left text-neutral-400">
              <th className="px-4 py-3 font-medium">Date</th>
              <th className="px-4 py-3 font-medium">Customer</th>
              <th className="px-4 py-3 font-medium">Amount</th>
              <th className="px-4 py-3 font-medium">Note</th>
            </tr>
          </thead>
          <tbody>
            {items.map((p) => (
              <tr key={p.id} className="border-b border-neutral-900 last:border-0 hover:bg-neutral-900/60">
                <td className="px-4 py-3 text-neutral-300">{p.paidAt}</td>
                <td className="px-4 py-3 text-neutral-50">{p.customerName}</td>
                <td className="px-4 py-3 text-green-400">Rs. {p.amount.toLocaleString()}</td>
                <td className="px-4 py-3 text-neutral-300">{p.note}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <RecordPaymentDialog open={dialogOpen} onClose={() => setDialogOpen(false)} onSave={(p) => setItems((prev) => [p, ...prev])} />
    </div>
  );
}
'@

# ---------------------------------------------------------------------------
# app/(dashboard)/reports/page.tsx
# ---------------------------------------------------------------------------
Write-CodeFile "app\(dashboard)\reports\page.tsx" @'
"use client";

import { useState } from "react";
import { rawMaterials } from "@/lib/mock-data/raw-materials";
import { productionBatches } from "@/lib/mock-data/batches";
import { invoices } from "@/lib/mock-data/invoices";

function SimpleBar({ label, value, max, colorClass }: { label: string; value: number; max: number; colorClass: string }) {
  const pct = max > 0 ? Math.min(100, (value / max) * 100) : 0;
  return (
    <div className="space-y-1">
      <div className="flex justify-between text-xs text-neutral-400">
        <span>{label}</span>
        <span>{value.toLocaleString()}</span>
      </div>
      <div className="h-2 w-full rounded-full bg-neutral-800 overflow-hidden">
        <div className={`h-full rounded-full ${colorClass}`} style={{ width: `${pct}%` }} />
      </div>
    </div>
  );
}

export default function ReportsPage() {
  const [tab, setTab] = useState<"inventory" | "yield" | "pnl">("inventory");
  const [from, setFrom] = useState("2026-08-01");
  const [to, setTo] = useState("2026-08-18");

  const maxStock = Math.max(...rawMaterials.map((m) => m.quantityInStock), 1);
  const maxYield = Math.max(...productionBatches.map((b) => b.outputYieldKg), 1);
  const totalRevenue = invoices.reduce((sum, i) => sum + i.totalAmount, 0);
  const totalCostEstimate = productionBatches.reduce((sum, b) => sum + b.outputYieldKg * b.bulkCostPerKg, 0);

  return (
    <div className="space-y-6">
      <h1 className="text-xl font-semibold text-neutral-50">Reports & Analytics</h1>

      <div className="flex flex-wrap items-end gap-3 rounded-xl border border-neutral-800 bg-neutral-900 p-4">
        <div>
          <label className="text-xs text-neutral-400">From</label>
          <input
            value={from}
            onChange={(e) => setFrom(e.target.value)}
            type="date"
            className="mt-1 block rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600"
          />
        </div>
        <div>
          <label className="text-xs text-neutral-400">To</label>
          <input
            value={to}
            onChange={(e) => setTo(e.target.value)}
            type="date"
            className="mt-1 block rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600"
          />
        </div>
        <button className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200">
          Apply
        </button>
        <button className="ml-auto rounded-lg border border-neutral-700 px-4 py-2 text-sm text-neutral-200 hover:bg-neutral-800">
          Export CSV
        </button>
      </div>

      <div className="flex gap-2 border-b border-neutral-800">
        {(
          [
            ["inventory", "Inventory Movement"],
            ["yield", "Production Yield"],
            ["pnl", "P&L"],
          ] as const
        ).map(([key, label]) => (
          <button
            key={key}
            onClick={() => setTab(key)}
            className={`px-4 py-2 text-sm font-medium border-b-2 ${
              tab === key ? "border-neutral-50 text-neutral-50" : "border-transparent text-neutral-400"
            }`}
          >
            {label}
          </button>
        ))}
      </div>

      {tab === "inventory" && (
        <div className="rounded-xl border border-neutral-800 bg-neutral-900 p-5 space-y-4">
          <h2 className="text-sm font-semibold text-neutral-200">Raw Material Stock Levels</h2>
          {rawMaterials.map((m) => (
            <SimpleBar key={m.id} label={m.name} value={m.quantityInStock} max={maxStock} colorClass="bg-blue-500" />
          ))}
        </div>
      )}

      {tab === "yield" && (
        <div className="rounded-xl border border-neutral-800 bg-neutral-900 p-5 space-y-4">
          <h2 className="text-sm font-semibold text-neutral-200">Output Yield per Batch</h2>
          {productionBatches.map((b) => (
            <SimpleBar key={b.id} label={b.id} value={b.outputYieldKg} max={maxYield} colorClass="bg-green-500" />
          ))}
        </div>
      )}

      {tab === "pnl" && (
        <div className="rounded-xl border border-neutral-800 bg-neutral-900 p-5 grid grid-cols-1 sm:grid-cols-3 gap-4">
          <div>
            <div className="text-neutral-400 text-xs">Total Revenue (Invoices)</div>
            <div className="text-lg font-semibold text-neutral-50 mt-1">Rs. {totalRevenue.toLocaleString()}</div>
          </div>
          <div>
            <div className="text-neutral-400 text-xs">Est. Production Cost</div>
            <div className="text-lg font-semibold text-neutral-50 mt-1">
              Rs. {totalCostEstimate.toLocaleString(undefined, { maximumFractionDigits: 0 })}
            </div>
          </div>
          <div>
            <div className="text-neutral-400 text-xs">Est. Gross Profit</div>
            <div className="text-lg font-semibold text-green-400 mt-1">
              Rs. {(totalRevenue - totalCostEstimate).toLocaleString(undefined, { maximumFractionDigits: 0 })}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
'@

# ---------------------------------------------------------------------------
# app/(dashboard)/settings/page.tsx
# ---------------------------------------------------------------------------
Write-CodeFile "app\(dashboard)\settings\page.tsx" @'
"use client";

import { useState } from "react";

export default function SettingsPage() {
  const [businessName, setBusinessName] = useState("GhaniFoods");
  const [address, setAddress] = useState("Mansehra, Khyber Pakhtunkhwa, Pakistan");
  const [footerText, setFooterText] = useState("Thank you for your business!");
  const [margin, setMargin] = useState("20");
  const [threshold, setThreshold] = useState("50");
  const [saved, setSaved] = useState(false);

  const handleSave = () => {
    setSaved(true);
    setTimeout(() => setSaved(false), 2000);
  };

  return (
    <div className="space-y-6 max-w-2xl">
      <h1 className="text-xl font-semibold text-neutral-50">Settings</h1>

      <div className="rounded-xl border border-neutral-800 bg-neutral-900 p-5 space-y-4">
        <h2 className="text-sm font-semibold text-neutral-200">Business Profile</h2>

        <div>
          <label className="text-sm text-neutral-400">Business Name</label>
          <input
            value={businessName}
            onChange={(e) => setBusinessName(e.target.value)}
            className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600"
          />
        </div>

        <div>
          <label className="text-sm text-neutral-400">Address</label>
          <input
            value={address}
            onChange={(e) => setAddress(e.target.value)}
            className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600"
          />
        </div>

        <div>
          <label className="text-sm text-neutral-400">Invoice Footer Text</label>
          <input
            value={footerText}
            onChange={(e) => setFooterText(e.target.value)}
            className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600"
          />
        </div>
      </div>

      <div className="rounded-xl border border-neutral-800 bg-neutral-900 p-5 space-y-4">
        <h2 className="text-sm font-semibold text-neutral-200">Defaults</h2>

        <div>
          <label className="text-sm text-neutral-400">Default Profit Margin %</label>
          <input
            value={margin}
            onChange={(e) => setMargin(e.target.value)}
            type="number"
            className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600"
          />
        </div>

        <div>
          <label className="text-sm text-neutral-400">Low-Stock Threshold Default</label>
          <input
            value={threshold}
            onChange={(e) => setThreshold(e.target.value)}
            type="number"
            className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600"
          />
        </div>
      </div>

      <div className="flex items-center gap-3">
        <button
          onClick={handleSave}
          className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200"
        >
          Save Settings
        </button>
        {saved && <span className="text-sm text-green-400">Saved.</span>}
      </div>
    </div>
  );
}
'@

Write-Host "`n=== Done ===" -ForegroundColor Cyan
Write-Host "12 pages + 2 mock-data files created/updated." -ForegroundColor Green
Write-Host "Run 'npm run dev:frontend' (or 'npm run dev') and check:" -ForegroundColor Yellow
Write-Host "  /batches  /batches/new  /batches/[id]" -ForegroundColor Yellow
Write-Host "  /finished-cartons" -ForegroundColor Yellow
Write-Host "  /customers  /customers/[id]" -ForegroundColor Yellow
Write-Host "  /invoices  /invoices/new  /invoices/[id]" -ForegroundColor Yellow
Write-Host "  /payments  /reports  /settings" -ForegroundColor Yellow