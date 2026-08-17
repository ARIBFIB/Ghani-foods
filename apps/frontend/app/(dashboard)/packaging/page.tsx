"use client";

import { useMemo, useState } from "react";
import { packagingMaterials as initialPackaging, type PackagingMaterial } from "@/lib/mock-data/packaging";

function StatusBadge({ isLow }: { isLow: boolean }) {
  return (
    <span
      className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ${
        isLow ? "bg-red-950 text-red-400 border border-red-900" : "bg-green-950 text-green-400 border border-green-900"
      }`}
    >
      {isLow ? "Low Stock" : "OK"}
    </span>
  );
}

function AddPackagingDialog({
  open,
  onClose,
  onAdd,
}: {
  open: boolean;
  onClose: () => void;
  onAdd: (item: PackagingMaterial) => void;
}) {
  const [name, setName] = useState("");
  const [unitCost, setUnitCost] = useState("");
  const [threshold, setThreshold] = useState("50");

  if (!open) return null;

  const handleSave = () => {
    if (!name.trim()) return;
    onAdd({
      id: `pm-${Date.now()}`,
      name: name.trim(),
      unitCost: Number(unitCost) || 0,
      stockQty: 0,
      lowStockThreshold: Number(threshold) || 0,
    });
    setName("");
    setUnitCost("");
    setThreshold("50");
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4">
      <div className="w-full max-w-sm rounded-xl border border-neutral-800 bg-neutral-900 p-5 space-y-4">
        <h2 className="text-lg font-semibold text-neutral-50">Add Packaging Material</h2>

        <div className="space-y-3">
          <div>
            <label className="text-sm text-neutral-400">Name</label>
            <input
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="e.g. Carton Box (Large)"
              className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600"
            />
          </div>
          <div>
            <label className="text-sm text-neutral-400">Unit Cost</label>
            <input
              value={unitCost}
              onChange={(e) => setUnitCost(e.target.value)}
              type="number"
              className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600"
            />
          </div>
          <div>
            <label className="text-sm text-neutral-400">Low Stock Threshold</label>
            <input
              value={threshold}
              onChange={(e) => setThreshold(e.target.value)}
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

function RestockDialog({
  open,
  onClose,
  onSave,
  itemName,
}: {
  open: boolean;
  onClose: () => void;
  onSave: (qty: number, cost: number) => void;
  itemName: string;
}) {
  const [qty, setQty] = useState("");
  const [cost, setCost] = useState("");

  if (!open) return null;

  const handleSave = () => {
    const q = Number(qty);
    if (!q) return;
    onSave(q, Number(cost) || 0);
    setQty("");
    setCost("");
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4">
      <div className="w-full max-w-sm rounded-xl border border-neutral-800 bg-neutral-900 p-5 space-y-4">
        <h2 className="text-lg font-semibold text-neutral-50">Restock: {itemName}</h2>
        <div className="space-y-3">
          <div>
            <label className="text-sm text-neutral-400">Quantity to Add</label>
            <input
              value={qty}
              onChange={(e) => setQty(e.target.value)}
              type="number"
              className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600"
            />
          </div>
          <div>
            <label className="text-sm text-neutral-400">Cost (per unit, optional)</label>
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

export default function PackagingPage() {
  const [items, setItems] = useState<PackagingMaterial[]>(initialPackaging);
  const [search, setSearch] = useState("");
  const [addOpen, setAddOpen] = useState(false);
  const [restockTarget, setRestockTarget] = useState<PackagingMaterial | null>(null);

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    if (!q) return items;
    return items.filter((m) => m.name.toLowerCase().includes(q));
  }, [items, search]);

  const handleRestock = (qty: number, cost: number) => {
    if (!restockTarget) return;
    setItems((prev) =>
      prev.map((m) => {
        if (m.id !== restockTarget.id) return m;
        const newStock = m.stockQty + qty;
        const newCost = cost > 0 ? (m.stockQty * m.unitCost + qty * cost) / newStock : m.unitCost;
        return { ...m, stockQty: newStock, unitCost: Number(newCost.toFixed(2)) };
      })
    );
    setRestockTarget(null);
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-semibold text-neutral-50">Packaging Materials</h1>
        <button
          onClick={() => setAddOpen(true)}
          className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200"
        >
          + Add Packaging Material
        </button>
      </div>

      <input
        value={search}
        onChange={(e) => setSearch(e.target.value)}
        placeholder="Search packaging materials..."
        className="w-full max-w-sm rounded-lg border border-neutral-800 bg-neutral-900 px-3 py-2 text-sm text-neutral-50 placeholder:text-neutral-500 outline-none focus:border-neutral-600"
      />

      <div className="overflow-hidden rounded-xl border border-neutral-800">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-neutral-800 bg-neutral-900 text-left text-neutral-400">
              <th className="px-4 py-3 font-medium">Name</th>
              <th className="px-4 py-3 font-medium">Unit Cost</th>
              <th className="px-4 py-3 font-medium">Stock Qty</th>
              <th className="px-4 py-3 font-medium">Threshold</th>
              <th className="px-4 py-3 font-medium">Status</th>
              <th className="px-4 py-3 font-medium text-right">Action</th>
            </tr>
          </thead>
          <tbody>
            {filtered.map((m) => {
              const isLow = m.stockQty < m.lowStockThreshold;
              return (
                <tr key={m.id} className="border-b border-neutral-900 last:border-0 hover:bg-neutral-900/60">
                  <td className="px-4 py-3 text-neutral-50">{m.name}</td>
                  <td className="px-4 py-3 text-neutral-300">Rs. {m.unitCost.toLocaleString()}</td>
                  <td className="px-4 py-3 text-neutral-300">{m.stockQty.toLocaleString()}</td>
                  <td className="px-4 py-3 text-neutral-300">{m.lowStockThreshold.toLocaleString()}</td>
                  <td className="px-4 py-3">
                    <StatusBadge isLow={isLow} />
                  </td>
                  <td className="px-4 py-3 text-right">
                    <button
                      onClick={() => setRestockTarget(m)}
                      className="rounded-lg border border-neutral-700 px-3 py-1.5 text-xs text-neutral-200 hover:bg-neutral-800"
                    >
                      Restock
                    </button>
                  </td>
                </tr>
              );
            })}
            {filtered.length === 0 && (
              <tr>
                <td colSpan={6} className="px-4 py-8 text-center text-neutral-500">
                  No packaging materials found.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>

      <AddPackagingDialog open={addOpen} onClose={() => setAddOpen(false)} onAdd={(item) => setItems((prev) => [...prev, item])} />
      <RestockDialog
        open={!!restockTarget}
        onClose={() => setRestockTarget(null)}
        onSave={handleRestock}
        itemName={restockTarget?.name ?? ""}
      />
    </div>
  );
}
