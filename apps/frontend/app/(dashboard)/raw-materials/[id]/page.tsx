"use client";

import { use, useState } from "react";
import Link from "next/link";
import { rawMaterials } from "@/lib/mock-data/raw-materials";

type PurchaseReceipt = {
  id: string;
  date: string;
  qty: number;
  cost: number;
};

const dummyReceipts: PurchaseReceipt[] = [
  { id: "r-1", date: "2026-08-12", qty: 200, cost: 142.0 },
  { id: "r-2", date: "2026-08-01", qty: 150, cost: 148.5 },
  { id: "r-3", date: "2026-07-20", qty: 100, cost: 146.0 },
];

function RecordPurchaseDialog({
  open,
  onClose,
  onSave,
}: {
  open: boolean;
  onClose: () => void;
  onSave: (qty: number, cost: number) => void;
}) {
  const [qty, setQty] = useState("");
  const [cost, setCost] = useState("");

  if (!open) return null;

  const handleSave = () => {
    const q = Number(qty);
    const c = Number(cost);
    if (!q || !c) return;
    onSave(q, c);
    setQty("");
    setCost("");
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4">
      <div className="w-full max-w-sm rounded-xl border border-neutral-800 bg-neutral-900 p-5 space-y-4">
        <h2 className="text-lg font-semibold text-neutral-50">Record Purchase</h2>
        <div className="space-y-3">
          <div>
            <label className="text-sm text-neutral-400">Quantity</label>
            <input
              value={qty}
              onChange={(e) => setQty(e.target.value)}
              type="number"
              className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600"
            />
          </div>
          <div>
            <label className="text-sm text-neutral-400">Purchase Cost (per unit)</label>
            <input
              value={cost}
              onChange={(e) => setCost(e.target.value)}
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

export default function RawMaterialDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const material = rawMaterials.find((m) => m.id === id);

  const [receipts, setReceipts] = useState<PurchaseReceipt[]>(dummyReceipts);
  const [dialogOpen, setDialogOpen] = useState(false);

  if (!material) {
    return (
      <div className="space-y-4">
        <Link href="/raw-materials" className="text-sm text-neutral-400 hover:underline">
          &larr; Back to Raw Materials
        </Link>
        <p className="text-neutral-400">Raw material not found.</p>
      </div>
    );
  }

  const isLow = material.quantityInStock < material.lowStockThreshold;

  const handleAddReceipt = (qty: number, cost: number) => {
    setReceipts((prev) => [
      { id: `r-${Date.now()}`, date: new Date().toISOString().slice(0, 10), qty, cost },
      ...prev,
    ]);
  };

  return (
    <div className="space-y-6">
      <div className="text-sm text-neutral-400">
        <Link href="/raw-materials" className="hover:underline text-neutral-300">
          Raw Materials
        </Link>{" "}
        / <span className="text-neutral-50">{material.name}</span>
      </div>

      <div className="rounded-xl border border-neutral-800 bg-neutral-900 p-5">
        <div className="flex items-start justify-between">
          <div>
            <h1 className="text-xl font-semibold text-neutral-50">{material.name}</h1>
            <p className="text-sm text-neutral-400 mt-1">Unit: {material.unit}</p>
          </div>
          <span
            className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ${
              isLow ? "bg-red-950 text-red-400 border border-red-900" : "bg-green-950 text-green-400 border border-green-900"
            }`}
          >
            {isLow ? "Low Stock" : "OK"}
          </span>
        </div>

        <div className="mt-5 grid grid-cols-2 sm:grid-cols-4 gap-4">
          <div>
            <div className="text-neutral-400 text-xs">Current Stock</div>
            <div className="text-lg font-semibold text-neutral-50 mt-1">
              {material.quantityInStock} {material.unit}
            </div>
          </div>
          <div>
            <div className="text-neutral-400 text-xs">Avg Unit Cost</div>
            <div className="text-lg font-semibold text-neutral-50 mt-1">
              Rs. {material.avgUnitCost.toLocaleString()}
            </div>
          </div>
          <div>
            <div className="text-neutral-400 text-xs">Low Stock Threshold</div>
            <div className="text-lg font-semibold text-neutral-50 mt-1">{material.lowStockThreshold}</div>
          </div>
          <div>
            <div className="text-neutral-400 text-xs">Stock Value</div>
            <div className="text-lg font-semibold text-neutral-50 mt-1">
              Rs. {(material.quantityInStock * material.avgUnitCost).toLocaleString()}
            </div>
          </div>
        </div>
      </div>

      <div className="flex items-center justify-between">
        <h2 className="text-lg font-semibold text-neutral-50">Purchase History</h2>
        <button
          onClick={() => setDialogOpen(true)}
          className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200"
        >
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
                <td className="px-4 py-3 text-neutral-300">
                  {r.qty} {material.unit}
                </td>
                <td className="px-4 py-3 text-neutral-300">Rs. {r.cost.toLocaleString()}</td>
                <td className="px-4 py-3 text-neutral-300">Rs. {(r.qty * r.cost).toLocaleString()}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <RecordPurchaseDialog open={dialogOpen} onClose={() => setDialogOpen(false)} onSave={handleAddReceipt} />
    </div>
  );
}
