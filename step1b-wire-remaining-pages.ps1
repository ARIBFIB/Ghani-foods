# step1b-wire-remaining-pages.ps1
# Run from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods
# Usage: .\step1b-wire-remaining-pages.ps1
#
# Run AFTER step1-wire-dummy-data-store.ps1 (that script creates lib/store.ts
# and installs zustand + sonner — this one just needs it to already exist).
#
# Wires: Raw Materials (list+detail), Packaging, Batches (list+new+detail),
# Finished Cartons, Customers (list+detail), Invoices (list+new+detail),
# Payments — all to lib/store.ts, with real mutations + toast feedback.

$ErrorActionPreference = "Stop"
$Root = Get-Location
$Frontend = Join-Path $Root "apps\frontend"

function Write-CodeFile {
    param([string]$RelativePath, [string]$Content)
    $fullPath = Join-Path $Frontend $RelativePath
    $dir = Split-Path $fullPath -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($fullPath, $Content, $utf8NoBom)
    Write-Host "  wrote $RelativePath" -ForegroundColor Green
}

$storePath = Join-Path $Frontend "lib\store.ts"
if (-not (Test-Path $storePath)) {
    Write-Host "ERROR: lib\store.ts not found. Run step1-wire-dummy-data-store.ps1 first." -ForegroundColor Red
    exit 1
}

Write-Host "=== Step 1b: Wiring remaining pages to the store ===" -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# Raw Materials — list
# ---------------------------------------------------------------------------
Write-CodeFile "app\(dashboard)\raw-materials\page.tsx" @'
"use client";

import { useMemo, useState } from "react";
import Link from "next/link";
import { toast } from "sonner";
import { useStore } from "@/lib/store";

function StatusBadge({ isLow }: { isLow: boolean }) {
  return (
    <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ${
      isLow ? "bg-red-950 text-red-400 border border-red-900" : "bg-green-950 text-green-400 border border-green-900"
    }`}>
      {isLow ? "Low Stock" : "OK"}
    </span>
  );
}

function AddRawMaterialDialog({ open, onClose }: { open: boolean; onClose: () => void }) {
  const addRawMaterial = useStore((s) => s.addRawMaterial);
  const [name, setName] = useState("");
  const [unit, setUnit] = useState("kg");
  const [threshold, setThreshold] = useState("50");

  if (!open) return null;

  const handleSave = () => {
    if (!name.trim()) return;
    addRawMaterial({ name: name.trim(), unit, lowStockThreshold: Number(threshold) || 0 });
    toast.success(`Raw material "${name.trim()}" added`);
    setName("");
    setUnit("kg");
    setThreshold("50");
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4">
      <div className="w-full max-w-sm rounded-xl border border-neutral-800 bg-neutral-900 p-5 space-y-4">
        <h2 className="text-lg font-semibold text-neutral-50">Add Raw Material</h2>
        <div className="space-y-3">
          <div>
            <label className="text-sm text-neutral-400">Name</label>
            <input value={name} onChange={(e) => setName(e.target.value)} placeholder="e.g. Atta (Flour)"
              className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
          </div>
          <div>
            <label className="text-sm text-neutral-400">Unit of Purchase</label>
            <input value={unit} onChange={(e) => setUnit(e.target.value)} placeholder="kg, litre, etc."
              className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
          </div>
          <div>
            <label className="text-sm text-neutral-400">Low Stock Threshold</label>
            <input value={threshold} onChange={(e) => setThreshold(e.target.value)} type="number"
              className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
          </div>
        </div>
        <div className="flex justify-end gap-2 pt-2">
          <button onClick={onClose} className="rounded-lg px-4 py-2 text-sm text-neutral-300 hover:bg-neutral-800">Cancel</button>
          <button onClick={handleSave} className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200">Save</button>
        </div>
      </div>
    </div>
  );
}

export default function RawMaterialsPage() {
  const items = useStore((s) => s.rawMaterials);
  const [search, setSearch] = useState("");
  const [dialogOpen, setDialogOpen] = useState(false);

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    if (!q) return items;
    return items.filter((m) => m.name.toLowerCase().includes(q));
  }, [items, search]);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-semibold text-neutral-50">Raw Materials</h1>
        <button onClick={() => setDialogOpen(true)} className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200">
          + Add Raw Material
        </button>
      </div>

      <input value={search} onChange={(e) => setSearch(e.target.value)} placeholder="Search raw materials..."
        className="w-full max-w-sm rounded-lg border border-neutral-800 bg-neutral-900 px-3 py-2 text-sm text-neutral-50 placeholder:text-neutral-500 outline-none focus:border-neutral-600" />

      <div className="overflow-hidden rounded-xl border border-neutral-800">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-neutral-800 bg-neutral-900 text-left text-neutral-400">
              <th className="px-4 py-3 font-medium">Name</th>
              <th className="px-4 py-3 font-medium">Unit</th>
              <th className="px-4 py-3 font-medium">Qty in Stock</th>
              <th className="px-4 py-3 font-medium">Avg Unit Cost</th>
              <th className="px-4 py-3 font-medium">Threshold</th>
              <th className="px-4 py-3 font-medium">Status</th>
            </tr>
          </thead>
          <tbody>
            {filtered.map((m) => {
              const isLow = m.quantityInStock < m.lowStockThreshold;
              return (
                <tr key={m.id} className="border-b border-neutral-900 last:border-0 hover:bg-neutral-900/60">
                  <td className="px-4 py-3">
                    <Link href={`/raw-materials/${m.id}`} className="text-neutral-50 hover:underline">{m.name}</Link>
                  </td>
                  <td className="px-4 py-3 text-neutral-300">{m.unit}</td>
                  <td className="px-4 py-3 text-neutral-300">{m.quantityInStock}</td>
                  <td className="px-4 py-3 text-neutral-300">Rs. {m.avgUnitCost.toLocaleString()}</td>
                  <td className="px-4 py-3 text-neutral-300">{m.lowStockThreshold}</td>
                  <td className="px-4 py-3"><StatusBadge isLow={isLow} /></td>
                </tr>
              );
            })}
            {filtered.length === 0 && (
              <tr><td colSpan={6} className="px-4 py-8 text-center text-neutral-500">No raw materials found.</td></tr>
            )}
          </tbody>
        </table>
      </div>

      <AddRawMaterialDialog open={dialogOpen} onClose={() => setDialogOpen(false)} />
    </div>
  );
}
'@

# ---------------------------------------------------------------------------
# Raw Materials — detail
# ---------------------------------------------------------------------------
Write-CodeFile "app\(dashboard)\raw-materials\[id]\page.tsx" @'
"use client";

import { use, useMemo, useState } from "react";
import Link from "next/link";
import { toast } from "sonner";
import { useStore } from "@/lib/store";

function RecordPurchaseDialog({ open, onClose, materialId }: { open: boolean; onClose: () => void; materialId: string }) {
  const recordPurchase = useStore((s) => s.recordPurchase);
  const [qty, setQty] = useState("");
  const [cost, setCost] = useState("");

  if (!open) return null;

  const handleSave = () => {
    const q = Number(qty);
    const c = Number(cost);
    if (!q || !c) return;
    recordPurchase(materialId, q, c);
    toast.success("Purchase recorded — average cost updated");
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
            <input value={qty} onChange={(e) => setQty(e.target.value)} type="number"
              className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
          </div>
          <div>
            <label className="text-sm text-neutral-400">Purchase Cost (per unit)</label>
            <input value={cost} onChange={(e) => setCost(e.target.value)} type="number"
              className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
          </div>
        </div>
        <div className="flex justify-end gap-2 pt-2">
          <button onClick={onClose} className="rounded-lg px-4 py-2 text-sm text-neutral-300 hover:bg-neutral-800">Cancel</button>
          <button onClick={handleSave} className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200">Save</button>
        </div>
      </div>
    </div>
  );
}

export default function RawMaterialDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const material = useStore((s) => s.rawMaterials.find((m) => m.id === id));
  const allReceipts = useStore((s) => s.receipts);
  const [dialogOpen, setDialogOpen] = useState(false);

  const receipts = useMemo(
    () => allReceipts.filter((r) => r.rawMaterialId === id),
    [allReceipts, id]
  );

  if (!material) {
    return (
      <div className="space-y-4">
        <Link href="/raw-materials" className="text-sm text-neutral-400 hover:underline">&larr; Back to Raw Materials</Link>
        <p className="text-neutral-400">Raw material not found.</p>
      </div>
    );
  }

  const isLow = material.quantityInStock < material.lowStockThreshold;

  return (
    <div className="space-y-6">
      <div className="text-sm text-neutral-400">
        <Link href="/raw-materials" className="hover:underline text-neutral-300">Raw Materials</Link>{" "}
        / <span className="text-neutral-50">{material.name}</span>
      </div>

      <div className="rounded-xl border border-neutral-800 bg-neutral-900 p-5">
        <div className="flex items-start justify-between">
          <div>
            <h1 className="text-xl font-semibold text-neutral-50">{material.name}</h1>
            <p className="text-sm text-neutral-400 mt-1">Unit: {material.unit}</p>
          </div>
          <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ${
            isLow ? "bg-red-950 text-red-400 border border-red-900" : "bg-green-950 text-green-400 border border-green-900"
          }`}>
            {isLow ? "Low Stock" : "OK"}
          </span>
        </div>

        <div className="mt-5 grid grid-cols-2 sm:grid-cols-4 gap-4">
          <div>
            <div className="text-neutral-400 text-xs">Current Stock</div>
            <div className="text-lg font-semibold text-neutral-50 mt-1">{material.quantityInStock} {material.unit}</div>
          </div>
          <div>
            <div className="text-neutral-400 text-xs">Avg Unit Cost</div>
            <div className="text-lg font-semibold text-neutral-50 mt-1">Rs. {material.avgUnitCost.toLocaleString()}</div>
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
        <button onClick={() => setDialogOpen(true)} className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200">
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
                <td className="px-4 py-3 text-neutral-300">{r.qty} {material.unit}</td>
                <td className="px-4 py-3 text-neutral-300">Rs. {r.cost.toLocaleString()}</td>
                <td className="px-4 py-3 text-neutral-300">Rs. {(r.qty * r.cost).toLocaleString()}</td>
              </tr>
            ))}
            {receipts.length === 0 && (
              <tr><td colSpan={4} className="px-4 py-8 text-center text-neutral-500">No purchases recorded yet.</td></tr>
            )}
          </tbody>
        </table>
      </div>

      <RecordPurchaseDialog open={dialogOpen} onClose={() => setDialogOpen(false)} materialId={material.id} />
    </div>
  );
}
'@

# ---------------------------------------------------------------------------
# Packaging
# ---------------------------------------------------------------------------
Write-CodeFile "app\(dashboard)\packaging\page.tsx" @'
"use client";

import { useMemo, useState } from "react";
import { toast } from "sonner";
import { useStore, type PackagingMaterial } from "@/lib/store";

function StatusBadge({ isLow }: { isLow: boolean }) {
  return (
    <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ${
      isLow ? "bg-red-950 text-red-400 border border-red-900" : "bg-green-950 text-green-400 border border-green-900"
    }`}>
      {isLow ? "Low Stock" : "OK"}
    </span>
  );
}

function AddPackagingDialog({ open, onClose }: { open: boolean; onClose: () => void }) {
  const addPackagingMaterial = useStore((s) => s.addPackagingMaterial);
  const [name, setName] = useState("");
  const [unitCost, setUnitCost] = useState("");
  const [threshold, setThreshold] = useState("50");

  if (!open) return null;

  const handleSave = () => {
    if (!name.trim()) return;
    addPackagingMaterial({ name: name.trim(), unitCost: Number(unitCost) || 0, lowStockThreshold: Number(threshold) || 0 });
    toast.success(`Packaging material "${name.trim()}" added`);
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
            <input value={name} onChange={(e) => setName(e.target.value)} placeholder="e.g. Carton Box (Large)"
              className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
          </div>
          <div>
            <label className="text-sm text-neutral-400">Unit Cost</label>
            <input value={unitCost} onChange={(e) => setUnitCost(e.target.value)} type="number"
              className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
          </div>
          <div>
            <label className="text-sm text-neutral-400">Low Stock Threshold</label>
            <input value={threshold} onChange={(e) => setThreshold(e.target.value)} type="number"
              className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
          </div>
        </div>
        <div className="flex justify-end gap-2 pt-2">
          <button onClick={onClose} className="rounded-lg px-4 py-2 text-sm text-neutral-300 hover:bg-neutral-800">Cancel</button>
          <button onClick={handleSave} className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200">Save</button>
        </div>
      </div>
    </div>
  );
}

function RestockDialog({ open, onClose, item }: { open: boolean; onClose: () => void; item: PackagingMaterial | null }) {
  const restockPackaging = useStore((s) => s.restockPackaging);
  const [qty, setQty] = useState("");
  const [cost, setCost] = useState("");

  if (!open || !item) return null;

  const handleSave = () => {
    const q = Number(qty);
    if (!q) return;
    restockPackaging(item.id, q, Number(cost) || 0);
    toast.success(`Restocked ${item.name}`);
    setQty("");
    setCost("");
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4">
      <div className="w-full max-w-sm rounded-xl border border-neutral-800 bg-neutral-900 p-5 space-y-4">
        <h2 className="text-lg font-semibold text-neutral-50">Restock: {item.name}</h2>
        <div className="space-y-3">
          <div>
            <label className="text-sm text-neutral-400">Quantity to Add</label>
            <input value={qty} onChange={(e) => setQty(e.target.value)} type="number"
              className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
          </div>
          <div>
            <label className="text-sm text-neutral-400">Cost (per unit, optional)</label>
            <input value={cost} onChange={(e) => setCost(e.target.value)} type="number"
              className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
          </div>
        </div>
        <div className="flex justify-end gap-2 pt-2">
          <button onClick={onClose} className="rounded-lg px-4 py-2 text-sm text-neutral-300 hover:bg-neutral-800">Cancel</button>
          <button onClick={handleSave} className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200">Save</button>
        </div>
      </div>
    </div>
  );
}

export default function PackagingPage() {
  const items = useStore((s) => s.packagingMaterials);
  const [search, setSearch] = useState("");
  const [addOpen, setAddOpen] = useState(false);
  const [restockTarget, setRestockTarget] = useState<PackagingMaterial | null>(null);

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    if (!q) return items;
    return items.filter((m) => m.name.toLowerCase().includes(q));
  }, [items, search]);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-semibold text-neutral-50">Packaging Materials</h1>
        <button onClick={() => setAddOpen(true)} className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200">
          + Add Packaging Material
        </button>
      </div>

      <input value={search} onChange={(e) => setSearch(e.target.value)} placeholder="Search packaging materials..."
        className="w-full max-w-sm rounded-lg border border-neutral-800 bg-neutral-900 px-3 py-2 text-sm text-neutral-50 placeholder:text-neutral-500 outline-none focus:border-neutral-600" />

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
                  <td className="px-4 py-3"><StatusBadge isLow={isLow} /></td>
                  <td className="px-4 py-3 text-right">
                    <button onClick={() => setRestockTarget(m)} className="rounded-lg border border-neutral-700 px-3 py-1.5 text-xs text-neutral-200 hover:bg-neutral-800">
                      Restock
                    </button>
                  </td>
                </tr>
              );
            })}
            {filtered.length === 0 && (
              <tr><td colSpan={6} className="px-4 py-8 text-center text-neutral-500">No packaging materials found.</td></tr>
            )}
          </tbody>
        </table>
      </div>

      <AddPackagingDialog open={addOpen} onClose={() => setAddOpen(false)} />
      <RestockDialog open={!!restockTarget} onClose={() => setRestockTarget(null)} item={restockTarget} />
    </div>
  );
}
'@

# ---------------------------------------------------------------------------
# Batches — list
# ---------------------------------------------------------------------------
Write-CodeFile "app\(dashboard)\batches\page.tsx" @'
"use client";

import Link from "next/link";
import { useStore } from "@/lib/store";

function StatusBadge({ status }: { status: "in_progress" | "completed" }) {
  const isDone = status === "completed";
  return (
    <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ${
      isDone ? "bg-green-950 text-green-400 border border-green-900" : "bg-amber-950 text-amber-400 border border-amber-900"
    }`}>
      {isDone ? "Completed" : "In Progress"}
    </span>
  );
}

export default function BatchesPage() {
  const productionBatches = useStore((s) => s.productionBatches);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-semibold text-neutral-50">Production Batches</h1>
        <Link href="/batches/new" className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200">
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
                  <Link href={`/batches/${b.id}`} className="text-neutral-50 hover:underline">{b.id}</Link>
                </td>
                <td className="px-4 py-3 text-neutral-300">{b.batchDate}</td>
                <td className="px-4 py-3 text-neutral-300">{b.outputYieldKg}</td>
                <td className="px-4 py-3 text-neutral-300">{b.wastageKg}</td>
                <td className="px-4 py-3 text-neutral-300">{b.leftoverQtyKg}</td>
                <td className="px-4 py-3 text-neutral-300">{b.bulkCostPerKg > 0 ? `Rs. ${b.bulkCostPerKg.toLocaleString()}` : "-"}</td>
                <td className="px-4 py-3"><StatusBadge status={b.status} /></td>
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
# Batches — new
# ---------------------------------------------------------------------------
Write-CodeFile "app\(dashboard)\batches\new\page.tsx" @'
"use client";

import { useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { useStore } from "@/lib/store";

type ConsumptionRow = { id: string; rawMaterialId: string; qty: string };

export default function NewBatchPage() {
  const router = useRouter();
  const rawMaterials = useStore((s) => s.rawMaterials);
  const productionBatches = useStore((s) => s.productionBatches);
  const createBatch = useStore((s) => s.createBatch);

  const [rows, setRows] = useState<ConsumptionRow[]>([
    { id: crypto.randomUUID(), rawMaterialId: rawMaterials[0]?.id ?? "", qty: "" },
  ]);
  const [outputYield, setOutputYield] = useState("");
  const [wastage, setWastage] = useState("");
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

  const handleSave = () => {
    const yieldKg = Number(outputYield) || 0;
    if (yieldKg <= 0) {
      toast.error("Enter an output yield greater than 0");
      return;
    }
    const consumptions = rows
      .filter((r) => r.rawMaterialId && Number(r.qty) > 0)
      .map((r) => ({ rawMaterialId: r.rawMaterialId, qty: Number(r.qty) }));

    if (consumptions.length === 0) {
      toast.error("Add at least one raw material row with a quantity");
      return;
    }

    const insufficient = consumptions.find((c) => {
      const m = rawMaterials.find((rm) => rm.id === c.rawMaterialId);
      return m && c.qty > m.quantityInStock;
    });
    if (insufficient) {
      toast.error("Not enough stock for one of the selected raw materials");
      return;
    }

    const newId = createBatch({ consumptions, outputYieldKg: yieldKg, wastageKg: Number(wastage) || 0 });
    toast.success(`Batch ${newId} created — raw material stock deducted`);
    router.push(`/batches/${newId}`);
  };

  return (
    <div className="space-y-6 max-w-3xl">
      <h1 className="text-xl font-semibold text-neutral-50">New Production Batch</h1>

      <div className="rounded-xl border border-neutral-800 bg-neutral-900 p-5 space-y-4">
        <div className="flex items-center justify-between">
          <h2 className="text-sm font-semibold text-neutral-200">Raw Material Consumption</h2>
          <button onClick={addRow} className="rounded-lg border border-neutral-700 px-3 py-1.5 text-xs text-neutral-200 hover:bg-neutral-800">
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
                      <option key={m.id} value={m.id}>{m.name} ({m.unit}) — {m.quantityInStock} in stock</option>
                    ))}
                  </select>
                  <input value={row.qty} onChange={(e) => updateRow(row.id, { qty: e.target.value })} type="number" placeholder="Qty"
                    className="w-28 rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
                  <button onClick={() => removeRow(row.id)} className="rounded-lg border border-neutral-800 px-3 py-2 text-sm text-neutral-400 hover:bg-neutral-800">-</button>
                </div>
                {material && Number(row.qty) > material.quantityInStock && (
                  <p className="text-xs text-red-400">Only {material.quantityInStock} {material.unit} available</p>
                )}
              </div>
            );
          })}
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
          <input value={outputYield} onChange={(e) => setOutputYield(e.target.value)} type="number"
            className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
        </div>
        <div>
          <label className="text-sm text-neutral-400">Wastage (kg)</label>
          <input value={wastage} onChange={(e) => setWastage(e.target.value)} type="number"
            className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
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
              <option key={b.id} value={b.id}>{b.id} — {b.leftoverQtyKg} kg leftover</option>
            ))}
          </select>
        )}
      </div>

      <div className="flex justify-end gap-2">
        <button onClick={() => router.push("/batches")} className="rounded-lg px-4 py-2 text-sm text-neutral-300 hover:bg-neutral-800">Cancel</button>
        <button onClick={handleSave} className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200">Save Batch</button>
      </div>
    </div>
  );
}
'@

# ---------------------------------------------------------------------------
# Batches — detail
# ---------------------------------------------------------------------------
Write-CodeFile "app\(dashboard)\batches\[id]\page.tsx" @'
"use client";

import { use, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { useStore } from "@/lib/store";

function OverheadDialog({ open, onClose, batchId }: { open: boolean; onClose: () => void; batchId: string }) {
  const allocateOverhead = useStore((s) => s.allocateOverhead);
  const [electricity, setElectricity] = useState("");
  const [gas, setGas] = useState("");
  const [rent, setRent] = useState("");

  if (!open) return null;

  const handleSave = () => {
    const e = Number(electricity) || 0;
    const g = Number(gas) || 0;
    const r = Number(rent) || 0;
    allocateOverhead(batchId, e, g, r);
    toast.success(`Overhead of Rs. ${(e + g + r).toLocaleString()} allocated to ${batchId}`);
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
            <input value={electricity} onChange={(e) => setElectricity(e.target.value)} type="number"
              className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
          </div>
          <div>
            <label className="text-sm text-neutral-400">Gas</label>
            <input value={gas} onChange={(e) => setGas(e.target.value)} type="number"
              className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
          </div>
          <div>
            <label className="text-sm text-neutral-400">Rent</label>
            <input value={rent} onChange={(e) => setRent(e.target.value)} type="number"
              className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
          </div>
        </div>
        <div className="flex justify-end gap-2 pt-2">
          <button onClick={onClose} className="rounded-lg px-4 py-2 text-sm text-neutral-300 hover:bg-neutral-800">Cancel</button>
          <button onClick={handleSave} className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200">Save</button>
        </div>
      </div>
    </div>
  );
}

export default function BatchDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const router = useRouter();
  const batch = useStore((s) => s.productionBatches.find((b) => b.id === id));
  const [dialogOpen, setDialogOpen] = useState(false);

  if (!batch) {
    return (
      <div className="space-y-4">
        <Link href="/batches" className="text-sm text-neutral-400 hover:underline">&larr; Back to Batches</Link>
        <p className="text-neutral-400">Batch not found.</p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="text-sm text-neutral-400">
        <Link href="/batches" className="hover:underline text-neutral-300">Batches</Link>{" "}
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
              Rs. {batch.bulkCostPerKg.toLocaleString(undefined, { maximumFractionDigits: 2 })}
            </div>
          </div>
        </div>

        {batch.overheadTotal > 0 && (
          <div className="mt-4 text-xs text-amber-400">
            Overhead of Rs. {batch.overheadTotal.toLocaleString()} allocated across this batch's output.
          </div>
        )}
      </div>

      <div className="flex gap-2">
        <button onClick={() => setDialogOpen(true)} className="rounded-lg border border-neutral-700 px-4 py-2 text-sm text-neutral-200 hover:bg-neutral-800">
          Allocate Month-End Overhead
        </button>
        <button onClick={() => router.push(`/finished-cartons?batchId=${batch.id}`)} className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200">
          Send to Packaging
        </button>
      </div>

      <OverheadDialog open={dialogOpen} onClose={() => setDialogOpen(false)} batchId={batch.id} />
    </div>
  );
}
'@

# ---------------------------------------------------------------------------
# Finished Cartons
# ---------------------------------------------------------------------------
Write-CodeFile "app\(dashboard)\finished-cartons\page.tsx" @'
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
    toast.success(`Packing run confirmed — ${cartons} cartons added to ready stock`);
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
            <select value={batchId} onChange={(e) => setBatchId(e.target.value)}
              className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600">
              {productionBatches.map((b) => (
                <option key={b.id} value={b.id}>{b.id} — {b.leftoverQtyKg} kg available</option>
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
                  <option key={p.id} value={p.id}>{p.name} — {p.stockQty} in stock</option>
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
'@

# ---------------------------------------------------------------------------
# Customers — list
# ---------------------------------------------------------------------------
Write-CodeFile "app\(dashboard)\customers\page.tsx" @'
"use client";

import { useMemo, useState } from "react";
import Link from "next/link";
import { toast } from "sonner";
import { useStore } from "@/lib/store";

function BalanceCell({ balance }: { balance: number }) {
  const owes = balance > 0;
  const isZero = balance === 0;
  return (
    <span className={isZero ? "text-neutral-400" : owes ? "text-red-400" : "text-green-400"}>
      Rs. {Math.abs(balance).toLocaleString()} {!isZero && (owes ? "(owes)" : "(credit)")}
    </span>
  );
}

function AddCustomerDialog({ open, onClose }: { open: boolean; onClose: () => void }) {
  const addCustomer = useStore((s) => s.addCustomer);
  const [name, setName] = useState("");
  const [phone, setPhone] = useState("");
  const [opening, setOpening] = useState("0");

  if (!open) return null;

  const handleSave = () => {
    if (!name.trim()) return;
    addCustomer({ name: name.trim(), phone, openingBalance: Number(opening) || 0 });
    toast.success(`Customer "${name.trim()}" added`);
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
            <input value={name} onChange={(e) => setName(e.target.value)}
              className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
          </div>
          <div>
            <label className="text-sm text-neutral-400">Phone</label>
            <input value={phone} onChange={(e) => setPhone(e.target.value)}
              className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
          </div>
          <div>
            <label className="text-sm text-neutral-400">Opening Balance</label>
            <input value={opening} onChange={(e) => setOpening(e.target.value)} type="number"
              className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
          </div>
        </div>
        <div className="flex justify-end gap-2 pt-2">
          <button onClick={onClose} className="rounded-lg px-4 py-2 text-sm text-neutral-300 hover:bg-neutral-800">Cancel</button>
          <button onClick={handleSave} className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200">Save</button>
        </div>
      </div>
    </div>
  );
}

export default function CustomersPage() {
  const items = useStore((s) => s.customers);
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
        <button onClick={() => setDialogOpen(true)} className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200">
          + Add Customer
        </button>
      </div>

      <input value={search} onChange={(e) => setSearch(e.target.value)} placeholder="Search customers..."
        className="w-full max-w-sm rounded-lg border border-neutral-800 bg-neutral-900 px-3 py-2 text-sm text-neutral-50 placeholder:text-neutral-500 outline-none focus:border-neutral-600" />

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
                  <Link href={`/customers/${c.id}`} className="text-neutral-50 hover:underline">{c.name}</Link>
                </td>
                <td className="px-4 py-3 text-neutral-300">{c.phone}</td>
                <td className="px-4 py-3"><BalanceCell balance={c.currentBalance} /></td>
              </tr>
            ))}
            {filtered.length === 0 && (
              <tr><td colSpan={3} className="px-4 py-8 text-center text-neutral-500">No customers found.</td></tr>
            )}
          </tbody>
        </table>
      </div>

      <AddCustomerDialog open={dialogOpen} onClose={() => setDialogOpen(false)} />
    </div>
  );
}
'@

# ---------------------------------------------------------------------------
# Customers — detail
# ---------------------------------------------------------------------------
Write-CodeFile "app\(dashboard)\customers\[id]\page.tsx" @'
"use client";

import { use, useMemo, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { useStore } from "@/lib/store";

function RecordPaymentDialog({ open, onClose, customerId }: { open: boolean; onClose: () => void; customerId: string }) {
  const recordPayment = useStore((s) => s.recordPayment);
  const [amount, setAmount] = useState("");
  const [note, setNote] = useState("");

  if (!open) return null;

  const handleSave = () => {
    const a = Number(amount);
    if (!a) return;
    recordPayment(customerId, a, note);
    toast.success(`Payment of Rs. ${a.toLocaleString()} recorded`);
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
            <input value={amount} onChange={(e) => setAmount(e.target.value)} type="number"
              className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
          </div>
          <div>
            <label className="text-sm text-neutral-400">Note</label>
            <input value={note} onChange={(e) => setNote(e.target.value)}
              className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
          </div>
        </div>
        <div className="flex justify-end gap-2 pt-2">
          <button onClick={onClose} className="rounded-lg px-4 py-2 text-sm text-neutral-300 hover:bg-neutral-800">Cancel</button>
          <button onClick={handleSave} className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200">Save</button>
        </div>
      </div>
    </div>
  );
}

export default function CustomerDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const router = useRouter();
  const customer = useStore((s) => s.customers.find((c) => c.id === id));
  const allLedger = useStore((s) => s.ledgerEntries);
  const [dialogOpen, setDialogOpen] = useState(false);

  const ledger = useMemo(() => allLedger.filter((l) => l.customerId === id), [allLedger, id]);

  if (!customer) {
    return (
      <div className="space-y-4">
        <Link href="/customers" className="text-sm text-neutral-400 hover:underline">&larr; Back to Customers</Link>
        <p className="text-neutral-400">Customer not found.</p>
      </div>
    );
  }

  const totalInvoiced = ledger.filter((l) => l.type === "invoice").reduce((sum, l) => sum + l.amount, 0);
  const totalPaid = ledger.filter((l) => l.type === "payment").reduce((sum, l) => sum + Math.abs(l.amount), 0);

  return (
    <div className="space-y-6">
      <div className="text-sm text-neutral-400">
        <Link href="/customers" className="hover:underline text-neutral-300">Customers</Link>{" "}
        / <span className="text-neutral-50">{customer.name}</span>
      </div>

      <div className="rounded-xl border border-neutral-800 bg-neutral-900 p-5">
        <h1 className="text-xl font-semibold text-neutral-50">{customer.name}</h1>
        <p className="text-sm text-neutral-400 mt-1">{customer.phone}</p>

        <div className="mt-5 grid grid-cols-1 sm:grid-cols-3 gap-4">
          <div>
            <div className="text-neutral-400 text-xs">Current Balance</div>
            <div className={`text-lg font-semibold mt-1 ${customer.currentBalance > 0 ? "text-red-400" : "text-green-400"}`}>
              Rs. {Math.abs(customer.currentBalance).toLocaleString()}
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
        <button onClick={() => setDialogOpen(true)} className="rounded-lg border border-neutral-700 px-4 py-2 text-sm text-neutral-200 hover:bg-neutral-800">
          + Record Payment
        </button>
        <button onClick={() => router.push(`/invoices/new?customerId=${customer.id}`)} className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200">
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
                  {l.amount >= 0 ? "+" : ""}Rs. {l.amount.toLocaleString()}
                </td>
                <td className="px-4 py-3 text-neutral-300">Rs. {l.runningBalance.toLocaleString()}</td>
              </tr>
            ))}
            {ledger.length === 0 && (
              <tr><td colSpan={5} className="px-4 py-8 text-center text-neutral-500">No ledger entries yet.</td></tr>
            )}
          </tbody>
        </table>
      </div>

      <RecordPaymentDialog open={dialogOpen} onClose={() => setDialogOpen(false)} customerId={customer.id} />
    </div>
  );
}
'@

# ---------------------------------------------------------------------------
# Invoices — list
# ---------------------------------------------------------------------------
Write-CodeFile "app\(dashboard)\invoices\page.tsx" @'
"use client";

import Link from "next/link";
import { useStore } from "@/lib/store";

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
  const invoices = useStore((s) => s.invoices);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-semibold text-neutral-50">Invoices</h1>
        <Link href="/invoices/new" className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200">
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
                  <Link href={`/invoices/${inv.id}`} className="text-neutral-50 hover:underline">{inv.id}</Link>
                </td>
                <td className="px-4 py-3 text-neutral-300">{inv.customerName}</td>
                <td className="px-4 py-3 text-neutral-300">{inv.invoiceDate}</td>
                <td className="px-4 py-3 text-neutral-300">Rs. {inv.totalAmount.toLocaleString()}</td>
                <td className="px-4 py-3"><StatusBadge status={inv.status} /></td>
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
# Invoices — new
# ---------------------------------------------------------------------------
Write-CodeFile "app\(dashboard)\invoices\new\page.tsx" @'
"use client";

import { Suspense, useMemo, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { toast } from "sonner";
import { useStore } from "@/lib/store";

type InvoiceLine = { id: string; itemId: string; qty: string; unitPrice: string };

function NewInvoiceForm() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const preselectedCustomerId = searchParams.get("customerId") ?? "";

  const customers = useStore((s) => s.customers);
  const finishedCartons = useStore((s) => s.finishedCartons);
  const lastSoldPrice = useStore((s) => s.lastSoldPrice);
  const createInvoice = useStore((s) => s.createInvoice);

  const [customerId, setCustomerId] = useState(preselectedCustomerId || customers[0]?.id || "");
  const [margin, setMargin] = useState("20");
  const [lines, setLines] = useState<InvoiceLine[]>([
    { id: crypto.randomUUID(), itemId: finishedCartons[0]?.id ?? "", qty: "1", unitPrice: "" },
  ]);

  const addLine = () => setLines((prev) => [...prev, { id: crypto.randomUUID(), itemId: finishedCartons[0]?.id ?? "", qty: "1", unitPrice: "" }]);
  const removeLine = (id: string) => setLines((prev) => (prev.length > 1 ? prev.filter((l) => l.id !== id) : prev));
  const updateLine = (id: string, patch: Partial<InvoiceLine>) =>
    setLines((prev) => prev.map((l) => (l.id === id ? { ...l, ...patch } : l)));

  const handleItemChange = (id: string, itemId: string) => {
    const carton = finishedCartons.find((c) => c.id === itemId);
    const memorized = lastSoldPrice(customerId, itemId);
    const marginMultiplier = 1 + (Number(margin) || 0) / 100;
    const fallback = carton ? Math.round(carton.costPerCarton * marginMultiplier) : 0;
    updateLine(id, { itemId, unitPrice: String(memorized ?? fallback) });
  };

  const total = useMemo(() => lines.reduce((sum, l) => sum + (Number(l.qty) || 0) * (Number(l.unitPrice) || 0), 0), [lines]);

  const handleSave = () => {
    if (!customerId) {
      toast.error("Select a customer first");
      return;
    }
    const parsedLines = lines
      .filter((l) => l.itemId && Number(l.qty) > 0)
      .map((l) => ({ itemId: l.itemId, qty: Number(l.qty), unitPrice: Number(l.unitPrice) || 0 }));

    if (parsedLines.length === 0) {
      toast.error("Add at least one invoice item");
      return;
    }

    const insufficient = parsedLines.find((l) => {
      const c = finishedCartons.find((fc) => fc.id === l.itemId);
      return c && l.qty > c.stockQty;
    });
    if (insufficient) {
      toast.error("Not enough finished carton stock for one of the items");
      return;
    }

    const newId = createInvoice({ customerId, lines: parsedLines });
    toast.success(`Invoice ${newId} created — stock deducted, ledger updated`);
    router.push(`/invoices/${newId}`);
  };

  const selectedCustomer = customers.find((c) => c.id === customerId);

  return (
    <div className="space-y-6 max-w-3xl">
      <h1 className="text-xl font-semibold text-neutral-50">New Invoice</h1>

      <div className="rounded-xl border border-neutral-800 bg-neutral-900 p-5 space-y-4">
        <div>
          <label className="text-sm text-neutral-400">Customer</label>
          <select value={customerId} onChange={(e) => setCustomerId(e.target.value)}
            className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600">
            {customers.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
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
          <input value={margin} onChange={(e) => setMargin(e.target.value)} type="number"
            className="mt-1 w-40 rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
        </div>
      </div>

      <div className="rounded-xl border border-neutral-800 bg-neutral-900 p-5 space-y-4">
        <div className="flex items-center justify-between">
          <h2 className="text-sm font-semibold text-neutral-200">Invoice Items</h2>
          <button onClick={addLine} className="rounded-lg border border-neutral-700 px-3 py-1.5 text-xs text-neutral-200 hover:bg-neutral-800">+ Add Item</button>
        </div>

        <div className="space-y-3">
          {lines.map((line) => {
            const memorized = lastSoldPrice(customerId, line.itemId);
            const carton = finishedCartons.find((c) => c.id === line.itemId);
            return (
              <div key={line.id} className="space-y-1">
                <div className="flex items-center gap-2">
                  <select value={line.itemId} onChange={(e) => handleItemChange(line.id, e.target.value)}
                    className="flex-1 rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600">
                    {finishedCartons.map((c) => <option key={c.id} value={c.id}>{c.name} — {c.stockQty} in stock</option>)}
                  </select>
                  <input value={line.qty} onChange={(e) => updateLine(line.id, { qty: e.target.value })} type="number" placeholder="Qty"
                    className="w-20 rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
                  <input value={line.unitPrice} onChange={(e) => updateLine(line.id, { unitPrice: e.target.value })} type="number" placeholder="Unit Price"
                    className="w-28 rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
                  <button onClick={() => removeLine(line.id)} className="rounded-lg border border-neutral-800 px-3 py-2 text-sm text-neutral-400 hover:bg-neutral-800">-</button>
                </div>
                <div className="flex gap-2">
                  {memorized !== undefined && (
                    <span className="inline-block rounded-full bg-neutral-800 px-2.5 py-0.5 text-xs text-neutral-300">
                      Last price: Rs. {memorized.toLocaleString()}
                    </span>
                  )}
                  {carton && Number(line.qty) > carton.stockQty && (
                    <span className="inline-block rounded-full bg-red-950 border border-red-900 px-2.5 py-0.5 text-xs text-red-400">
                      Only {carton.stockQty} in stock
                    </span>
                  )}
                </div>
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
        <button onClick={() => router.push("/invoices")} className="rounded-lg px-4 py-2 text-sm text-neutral-300 hover:bg-neutral-800">Cancel</button>
        <button onClick={handleSave} className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200">Save & Generate Invoice</button>
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
# Invoices — detail
# ---------------------------------------------------------------------------
Write-CodeFile "app\(dashboard)\invoices\[id]\page.tsx" @'
"use client";

import { use, useState } from "react";
import Link from "next/link";
import { toast } from "sonner";
import { useStore } from "@/lib/store";

function RecordPaymentDialog({ open, onClose, customerId, customerName }: { open: boolean; onClose: () => void; customerId: string; customerName: string }) {
  const recordPayment = useStore((s) => s.recordPayment);
  const [amount, setAmount] = useState("");

  if (!open) return null;

  const handleSave = () => {
    const a = Number(amount);
    if (!a) return;
    recordPayment(customerId, a, "Payment against invoice");
    toast.success(`Payment of Rs. ${a.toLocaleString()} recorded for ${customerName}`);
    setAmount("");
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4">
      <div className="w-full max-w-sm rounded-xl border border-neutral-800 bg-neutral-900 p-5 space-y-4">
        <h2 className="text-lg font-semibold text-neutral-50">Record Payment — {customerName}</h2>
        <div>
          <label className="text-sm text-neutral-400">Amount</label>
          <input value={amount} onChange={(e) => setAmount(e.target.value)} type="number"
            className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
        </div>
        <div className="flex justify-end gap-2 pt-2">
          <button onClick={onClose} className="rounded-lg px-4 py-2 text-sm text-neutral-300 hover:bg-neutral-800">Cancel</button>
          <button onClick={handleSave} className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200">Save</button>
        </div>
      </div>
    </div>
  );
}

export default function InvoiceDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const invoice = useStore((s) => s.invoices.find((i) => i.id === id));
  const [dialogOpen, setDialogOpen] = useState(false);

  if (!invoice) {
    return (
      <div className="space-y-4">
        <Link href="/invoices" className="text-sm text-neutral-400 hover:underline">&larr; Back to Invoices</Link>
        <p className="text-neutral-400">Invoice not found.</p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="text-sm text-neutral-400">
        <Link href="/invoices" className="hover:underline text-neutral-300">Invoices</Link>{" "}
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
              {invoice.items.length > 0 ? (
                invoice.items.map((line, idx) => (
                  <tr key={idx}>
                    <td className="px-4 py-2 text-neutral-300">{line.itemName}</td>
                    <td className="px-4 py-2 text-neutral-300">{line.qty}</td>
                    <td className="px-4 py-2 text-neutral-300">Rs. {line.unitPrice.toLocaleString()}</td>
                    <td className="px-4 py-2 text-neutral-300">Rs. {line.subtotal.toLocaleString()}</td>
                  </tr>
                ))
              ) : (
                <tr>
                  <td className="px-4 py-2 text-neutral-300">Nimko Carton (legacy record)</td>
                  <td className="px-4 py-2 text-neutral-300">-</td>
                  <td className="px-4 py-2 text-neutral-300">-</td>
                  <td className="px-4 py-2 text-neutral-300">Rs. {invoice.totalAmount.toLocaleString()}</td>
                </tr>
              )}
            </tbody>
          </table>
        </div>

        <div className="mt-4 flex justify-end">
          <div className="text-lg font-semibold text-neutral-50">Total: Rs. {invoice.totalAmount.toLocaleString()}</div>
        </div>
      </div>

      <div className="flex gap-2 print:hidden">
        <button onClick={() => window.print()} className="rounded-lg border border-neutral-700 px-4 py-2 text-sm text-neutral-200 hover:bg-neutral-800">Print</button>
        <button onClick={() => toast.info("PDF generation is planned for a later step (needs backend rendering).")}
          className="rounded-lg border border-neutral-700 px-4 py-2 text-sm text-neutral-200 hover:bg-neutral-800">
          Download PDF
        </button>
        <button onClick={() => setDialogOpen(true)} className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200">
          Record Payment
        </button>
      </div>

      <RecordPaymentDialog open={dialogOpen} onClose={() => setDialogOpen(false)} customerId={invoice.customerId} customerName={invoice.customerName} />
    </div>
  );
}
'@

# ---------------------------------------------------------------------------
# Payments
# ---------------------------------------------------------------------------
Write-CodeFile "app\(dashboard)\payments\page.tsx" @'
"use client";

import { useState } from "react";
import { toast } from "sonner";
import { useStore } from "@/lib/store";

function RecordPaymentDialog({ open, onClose }: { open: boolean; onClose: () => void }) {
  const customers = useStore((s) => s.customers);
  const recordPayment = useStore((s) => s.recordPayment);
  const [customerId, setCustomerId] = useState(customers[0]?.id ?? "");
  const [amount, setAmount] = useState("");
  const [note, setNote] = useState("");

  if (!open) return null;

  const handleSave = () => {
    const a = Number(amount);
    if (!a || !customerId) return;
    recordPayment(customerId, a, note);
    toast.success(`Payment of Rs. ${a.toLocaleString()} recorded`);
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
            <select value={customerId} onChange={(e) => setCustomerId(e.target.value)}
              className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600">
              {customers.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
            </select>
          </div>
          <div>
            <label className="text-sm text-neutral-400">Amount</label>
            <input value={amount} onChange={(e) => setAmount(e.target.value)} type="number"
              className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
          </div>
          <div>
            <label className="text-sm text-neutral-400">Note</label>
            <input value={note} onChange={(e) => setNote(e.target.value)}
              className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
          </div>
        </div>
        <div className="flex justify-end gap-2 pt-2">
          <button onClick={onClose} className="rounded-lg px-4 py-2 text-sm text-neutral-300 hover:bg-neutral-800">Cancel</button>
          <button onClick={handleSave} className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200">Save</button>
        </div>
      </div>
    </div>
  );
}

export default function PaymentsPage() {
  const items = useStore((s) => s.payments);
  const [dialogOpen, setDialogOpen] = useState(false);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-semibold text-neutral-50">Payments</h1>
        <button onClick={() => setDialogOpen(true)} className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200">
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

      <RecordPaymentDialog open={dialogOpen} onClose={() => setDialogOpen(false)} />
    </div>
  );
}
'@

Write-Host "`n=== Step 1b complete ===" -ForegroundColor Cyan
Write-Host "All core pages now read/write the shared dummy-data store." -ForegroundColor Green
Write-Host "Data persists in the browser (localStorage) across refreshes." -ForegroundColor Green
Write-Host "`nRun the app: npm run dev:frontend" -ForegroundColor Yellow
Write-Host "Then try: New Batch -> watch raw material stock drop." -ForegroundColor Yellow
Write-Host "          New Invoice -> watch carton stock drop, customer balance & ledger update, price memory save." -ForegroundColor Yellow