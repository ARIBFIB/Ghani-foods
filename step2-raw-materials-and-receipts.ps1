# step2-raw-materials-and-receipts.ps1
# Run from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods
# Usage: .\step2-raw-materials-and-receipts.ps1
#
# STEP 2 of the v1.2/v2.2 gap-closure plan.
# Overwrites / creates:
#   apps\frontend\components\ui\purchase-receipt-dialog.tsx   (new, shared multi-item dialog)
#   apps\frontend\app\(dashboard)\raw-materials\page.tsx       (rewrite - expandable rows)
#   apps\frontend\app\(dashboard)\raw-materials\[id]\page.tsx  (rewrite - receipt-based history)
#   apps\frontend\app\(dashboard)\suppliers\[id]\page.tsx      (rewrite - grouped by receipt)
#   apps\frontend\app\(dashboard)\receipts\page.tsx            (new - Receipts register)
#   apps\frontend\components\ui\sidebar-component.tsx          (adds "Receipts" nav entry)
#
# Same encoding-safe write pattern as step1 (single-quoted here-strings, UTF8 no BOM).

$ErrorActionPreference = "Stop"
$ProjectRoot = Get-Location
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Write-FileSmart($relativePath, $content) {
    $fullPath = Join-Path $ProjectRoot $relativePath
    $dir = Split-Path $fullPath -Parent
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    [System.IO.File]::WriteAllText($fullPath, $content, $Utf8NoBom)
    Write-Host "  Wrote: $relativePath" -ForegroundColor Green
}

Write-Host "=== Step 2: Raw Materials + Receipts flow (BRS v1.2 / Spec v2.2) ===" -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# apps/frontend/components/ui/purchase-receipt-dialog.tsx
# ---------------------------------------------------------------------------
$purchaseReceiptDialogContent = @'
"use client";

import { useState } from "react";
import { toast } from "sonner";
import { useStore } from "@/lib/store";

type ItemRow = {
  id: string;
  mode: "existing" | "new";
  rawMaterialId: string;
  newName: string;
  newUnit: string;
  newThreshold: string;
  qty: string;
  cost: string;
};

function emptyRow(defaultRawMaterialId: string): ItemRow {
  return {
    id: crypto.randomUUID(),
    mode: "existing",
    rawMaterialId: defaultRawMaterialId,
    newName: "",
    newUnit: "kg",
    newThreshold: "50",
    qty: "",
    cost: "",
  };
}

// Shared Purchase Receipt dialog (FR-5/FR-6/FR-7): one Supplier + one
// Purchase Date, one or more line items. Used unscoped from /receipts,
// locked-to-supplier from /suppliers/[id], and locked-to-material from
// /raw-materials/[id] and /raw-materials (row action).
export function PurchaseReceiptDialog({
  open,
  onClose,
  lockSupplierId,
  lockRawMaterialId,
}: {
  open: boolean;
  onClose: () => void;
  lockSupplierId?: string;
  lockRawMaterialId?: string;
}) {
  const suppliers = useStore((s) => s.suppliers);
  const rawMaterials = useStore((s) => s.rawMaterials);
  const addSupplier = useStore((s) => s.addSupplier);
  const addRawMaterial = useStore((s) => s.addRawMaterial);
  const createPurchaseReceipt = useStore((s) => s.createPurchaseReceipt);

  const today = new Date().toISOString().slice(0, 10);

  const [supplierId, setSupplierId] = useState(lockSupplierId ?? suppliers[0]?.id ?? "");
  const [purchaseDate, setPurchaseDate] = useState(today);
  const [rows, setRows] = useState<ItemRow[]>([
    emptyRow(lockRawMaterialId ?? rawMaterials[0]?.id ?? ""),
  ]);
  const [showAddSupplier, setShowAddSupplier] = useState(false);
  const [newSupplierName, setNewSupplierName] = useState("");
  const [newSupplierPhone, setNewSupplierPhone] = useState("");
  const [formError, setFormError] = useState("");
  const [submitting, setSubmitting] = useState(false);

  if (!open) return null;

  const resetAndClose = () => {
    setSupplierId(lockSupplierId ?? suppliers[0]?.id ?? "");
    setPurchaseDate(today);
    setRows([emptyRow(lockRawMaterialId ?? rawMaterials[0]?.id ?? "")]);
    setShowAddSupplier(false);
    setNewSupplierName("");
    setNewSupplierPhone("");
    setFormError("");
    onClose();
  };

  const addRow = () => setRows((prev) => [...prev, emptyRow(rawMaterials[0]?.id ?? "")]);
  const removeRow = (id: string) =>
    setRows((prev) => (prev.length > 1 ? prev.filter((r) => r.id !== id) : prev));
  const updateRow = (id: string, patch: Partial<ItemRow>) =>
    setRows((prev) => prev.map((r) => (r.id === id ? { ...r, ...patch } : r)));

  const handleInlineAddSupplier = () => {
    if (!newSupplierName.trim() || !newSupplierPhone.trim()) return;
    const id = addSupplier({ name: newSupplierName.trim(), phone: newSupplierPhone.trim() });
    setSupplierId(id);
    setNewSupplierName("");
    setNewSupplierPhone("");
    setShowAddSupplier(false);
    toast.success(`Supplier "${newSupplierName.trim()}" added`);
  };

  const runningTotal = rows.reduce((sum, r) => sum + (Number(r.qty) || 0) * (Number(r.cost) || 0), 0);

  const handleSubmit = async () => {
    setFormError("");

    if (!supplierId) {
      setFormError("Select or add a supplier");
      return;
    }
    if (!purchaseDate) {
      setFormError("Purchase date is required");
      return;
    }

    const parsedItems: { rawMaterialId: string; qty: number; cost: number }[] = [];

    for (const row of rows) {
      const qty = Number(row.qty);
      const cost = Number(row.cost);
      if (!qty || qty <= 0) {
        setFormError("Every line needs a quantity greater than 0");
        return;
      }
      if (!cost || cost <= 0) {
        setFormError("Every line needs a cost greater than 0");
        return;
      }

      if (row.mode === "new") {
        if (!row.newName.trim()) {
          setFormError("Enter a name for the new raw material");
          return;
        }
        if (!row.newUnit.trim()) {
          setFormError("Enter a unit for the new raw material");
          return;
        }
        const existing = rawMaterials.find(
          (m) => m.name.toLowerCase() === row.newName.trim().toLowerCase()
        );
        let newId = existing?.id;
        if (!newId) {
          addRawMaterial({
            name: row.newName.trim(),
            unit: row.newUnit.trim(),
            lowStockThreshold: Number(row.newThreshold) || 0,
          });
          newId = useStore
            .getState()
            .rawMaterials.find((m) => m.name.toLowerCase() === row.newName.trim().toLowerCase())?.id;
        }
        if (!newId) {
          setFormError("Could not create the new raw material");
          return;
        }
        parsedItems.push({ rawMaterialId: newId, qty, cost });
      } else {
        if (!row.rawMaterialId) {
          setFormError("Select a raw material for every line");
          return;
        }
        parsedItems.push({ rawMaterialId: row.rawMaterialId, qty, cost });
      }
    }

    setSubmitting(true);
    createPurchaseReceipt({ supplierId, purchaseDate, items: parsedItems });
    const supplierName = suppliers.find((s) => s.id === supplierId)?.name ?? "supplier";
    toast.success(
      `Purchase receipt saved - ${parsedItems.length} item${parsedItems.length > 1 ? "s" : ""} from ${supplierName}`
    );
    setSubmitting(false);
    resetAndClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-3 sm:p-4">
      <div className="w-full max-w-lg rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-5 space-y-4 max-h-[90vh] overflow-y-auto">
        <h2 className="text-lg font-semibold text-[var(--foreground)]">New Purchase Receipt</h2>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <div>
            <label className="text-sm text-[var(--text-muted)]">Supplier</label>
            <select
              value={supplierId}
              onChange={(e) => setSupplierId(e.target.value)}
              disabled={!!lockSupplierId}
              className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)] disabled:opacity-60"
            >
              <option value="">Select supplier...</option>
              {suppliers.map((s) => (
                <option key={s.id} value={s.id}>{s.name}</option>
              ))}
            </select>
            {!lockSupplierId && (
              <button
                type="button"
                onClick={() => setShowAddSupplier((v) => !v)}
                className="text-xs text-[var(--text-muted)] hover:text-[var(--foreground)] hover:underline mt-1"
              >
                + Add Supplier
              </button>
            )}
          </div>

          <div>
            <label className="text-sm text-[var(--text-muted)]">Purchase Date</label>
            <input
              value={purchaseDate}
              onChange={(e) => setPurchaseDate(e.target.value)}
              type="date"
              className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]"
            />
          </div>
        </div>

        {showAddSupplier && !lockSupplierId && (
          <div className="space-y-2 rounded-lg border border-[var(--surface-border)] p-3">
            <input
              value={newSupplierName}
              onChange={(e) => setNewSupplierName(e.target.value)}
              placeholder="Supplier name"
              className="w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]"
            />
            <input
              value={newSupplierPhone}
              onChange={(e) => setNewSupplierPhone(e.target.value)}
              placeholder="Phone"
              className="w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]"
            />
            <button
              type="button"
              onClick={handleInlineAddSupplier}
              className="rounded-lg border border-neutral-400 dark:border-neutral-600 px-3 py-1.5 text-xs text-[var(--foreground)] hover:bg-[var(--surface-hover)]"
            >
              Save Supplier
            </button>
          </div>
        )}

        <div className="space-y-3">
          <div className="flex items-center justify-between">
            <h3 className="text-sm font-semibold text-[var(--foreground)]">Items</h3>
            <button
              type="button"
              onClick={addRow}
              className="rounded-lg border border-neutral-400 dark:border-neutral-600 px-3 py-1.5 text-xs text-[var(--foreground)] hover:bg-[var(--surface-hover)]"
            >
              + Add Item
            </button>
          </div>

          {rows.map((row) => (
            <div key={row.id} className="rounded-lg border border-[var(--surface-border)] p-3 space-y-2">
              <div className="flex items-center justify-between">
                <div className="flex gap-2 text-xs">
                  <button
                    type="button"
                    onClick={() => updateRow(row.id, { mode: "existing" })}
                    className={`rounded-full px-2.5 py-1 ${row.mode === "existing" ? "bg-[var(--surface-hover)] text-[var(--foreground)]" : "text-[var(--text-muted)]"}`}
                  >
                    Existing Material
                  </button>
                  <button
                    type="button"
                    onClick={() => updateRow(row.id, { mode: "new" })}
                    className={`rounded-full px-2.5 py-1 ${row.mode === "new" ? "bg-[var(--surface-hover)] text-[var(--foreground)]" : "text-[var(--text-muted)]"}`}
                  >
                    + New Material
                  </button>
                </div>
                <button
                  type="button"
                  onClick={() => removeRow(row.id)}
                  className="rounded-lg border border-[var(--surface-border)] px-2 py-1 text-xs text-[var(--text-muted)] hover:bg-[var(--surface-hover)]"
                >
                  Remove
                </button>
              </div>

              {row.mode === "existing" ? (
                <select
                  value={row.rawMaterialId}
                  onChange={(e) => updateRow(row.id, { rawMaterialId: e.target.value })}
                  disabled={!!lockRawMaterialId}
                  className="w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)] disabled:opacity-60"
                >
                  <option value="">Select raw material...</option>
                  {rawMaterials.map((m) => (
                    <option key={m.id} value={m.id}>{m.name} ({m.unit})</option>
                  ))}
                </select>
              ) : (
                <div className="grid grid-cols-2 gap-2">
                  <input
                    value={row.newName}
                    onChange={(e) => updateRow(row.id, { newName: e.target.value })}
                    placeholder="New material name"
                    className="col-span-2 rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]"
                  />
                  <input
                    value={row.newUnit}
                    onChange={(e) => updateRow(row.id, { newUnit: e.target.value })}
                    placeholder="Unit (kg, g...)"
                    className="rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]"
                  />
                  <input
                    value={row.newThreshold}
                    onChange={(e) => updateRow(row.id, { newThreshold: e.target.value })}
                    type="number"
                    placeholder="Low stock threshold"
                    className="rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]"
                  />
                </div>
              )}

              <div className="grid grid-cols-2 gap-2">
                <input
                  value={row.qty}
                  onChange={(e) => updateRow(row.id, { qty: e.target.value })}
                  type="number"
                  step="any"
                  placeholder="Quantity"
                  className="rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]"
                />
                <input
                  value={row.cost}
                  onChange={(e) => updateRow(row.id, { cost: e.target.value })}
                  type="number"
                  step="any"
                  placeholder="Cost per unit"
                  className="rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]"
                />
              </div>
            </div>
          ))}

          {formError && <p className="text-xs text-red-400">{formError}</p>}
        </div>

        <div className="rounded-lg border border-[var(--surface-border)] bg-[var(--background)] p-3 flex items-center justify-between">
          <span className="text-sm text-[var(--text-muted)]">Running Total</span>
          <span className="text-lg font-semibold text-[var(--foreground)]">
            Rs. {runningTotal.toLocaleString(undefined, { maximumFractionDigits: 2 })}
          </span>
        </div>

        <div className="flex justify-end gap-2 pt-2">
          <button
            type="button"
            onClick={resetAndClose}
            className="rounded-lg px-4 py-2 text-sm text-[var(--text-secondary)] hover:bg-[var(--surface-hover)]"
          >
            Cancel
          </button>
          <button
            type="button"
            onClick={handleSubmit}
            disabled={submitting}
            className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-50 dark:text-neutral-950 hover:opacity-90 transition-opacity disabled:opacity-50"
          >
            {submitting ? "Saving..." : "Save Receipt"}
          </button>
        </div>
      </div>
    </div>
  );
}

export default PurchaseReceiptDialog;
'@

Write-FileSmart "apps\frontend\components\ui\purchase-receipt-dialog.tsx" $purchaseReceiptDialogContent

# ---------------------------------------------------------------------------
# apps/frontend/app/(dashboard)/raw-materials/page.tsx
# ---------------------------------------------------------------------------
$rawMaterialsPageContent = @'
"use client";

import { Fragment, useMemo, useState } from "react";
import { NavLink } from "@/components/ui/nav-link";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { toast } from "sonner";
import { ChevronDown, ChevronRight } from "lucide-react";
import { useStore } from "@/lib/store";
import { rawMaterialMasterSchema, type RawMaterialMasterFormValues } from "@/lib/schemas";
import { PurchaseReceiptDialog } from "@/components/ui/purchase-receipt-dialog";

function StatusBadge({ isLow }: { isLow: boolean }) {
  return (
    <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ${
      isLow ? "bg-red-950 text-red-400 border border-red-900" : "bg-green-950 text-green-400 border border-green-900"
    }`}>
      {isLow ? "Low Stock" : "OK"}
    </span>
  );
}

function AddRawMaterialMasterDialog({ open, onClose }: { open: boolean; onClose: () => void }) {
  const addRawMaterial = useStore((s) => s.addRawMaterial);
  const { register, handleSubmit, reset, formState: { errors, isSubmitting } } = useForm<RawMaterialMasterFormValues>({
    resolver: zodResolver(rawMaterialMasterSchema),
    defaultValues: { name: "", unit: "kg", lowStockThreshold: 50 },
  });

  if (!open) return null;

  const onSubmit = async (values: RawMaterialMasterFormValues) => {
    addRawMaterial(values);
    toast.success(`Raw material "${values.name}" added - record a purchase to add stock`);
    reset();
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-3 sm:p-4">
      <form onSubmit={handleSubmit(onSubmit)} className="w-full max-w-sm rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-5 space-y-4 max-h-[90vh] overflow-y-auto">
        <h2 className="text-lg font-semibold text-[var(--foreground)]">Add Raw Material</h2>
        <p className="text-xs text-[var(--text-faint)]">
          Creates the master record only (name, unit, threshold). Stock and cost come from
          purchase receipts - use "Record Purchase" to add stock.
        </p>
        <div className="space-y-3">
          <div>
            <label className="text-sm text-[var(--text-muted)]">Name</label>
            <input {...register("name")} placeholder="e.g. Atta (Flour)"
              className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
            {errors.name && <p className="text-xs text-red-400 mt-1">{errors.name.message}</p>}
          </div>
          <div>
            <label className="text-sm text-[var(--text-muted)]">Unit</label>
            <input {...register("unit")} placeholder="kg, g, litre..."
              className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
            {errors.unit && <p className="text-xs text-red-400 mt-1">{errors.unit.message}</p>}
          </div>
          <div>
            <label className="text-sm text-[var(--text-muted)]">Low Stock Threshold</label>
            <input {...register("lowStockThreshold")} type="number"
              className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
            {errors.lowStockThreshold && <p className="text-xs text-red-400 mt-1">{errors.lowStockThreshold.message}</p>}
          </div>
        </div>
        <div className="flex justify-end gap-2 pt-2">
          <button type="button" onClick={() => { reset(); onClose(); }} className="rounded-lg px-4 py-2 text-sm text-[var(--text-secondary)] hover:bg-[var(--surface-hover)]">Cancel</button>
          <button type="submit" disabled={isSubmitting} className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-50 dark:text-neutral-950 hover:opacity-90 transition-opacity disabled:opacity-50">
            {isSubmitting ? "Saving..." : "Save"}
          </button>
        </div>
      </form>
    </div>
  );
}

export default function RawMaterialsPage() {
  const rawMaterials = useStore((s) => s.rawMaterials);
  const receipts = useStore((s) => s.receipts);
  const receiptLines = useStore((s) => s.receiptLines);
  const suppliers = useStore((s) => s.suppliers);

  const [search, setSearch] = useState("");
  const [expandedId, setExpandedId] = useState<string | null>(null);
  const [addOpen, setAddOpen] = useState(false);
  const [receiptOpen, setReceiptOpen] = useState(false);

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    if (!q) return rawMaterials;
    return rawMaterials.filter((m) => m.name.toLowerCase().includes(q) || m.unit.toLowerCase().includes(q));
  }, [rawMaterials, search]);

  const historyFor = (materialId: string) => {
    return receiptLines
      .filter((rl) => rl.rawMaterialId === materialId)
      .map((rl) => {
        const receipt = receipts.find((r) => r.id === rl.receiptId);
        const supplier = receipt ? suppliers.find((s) => s.id === receipt.supplierId) : undefined;
        return {
          id: rl.id,
          date: receipt?.purchaseDate ?? "-",
          supplierName: supplier?.name ?? "-",
          supplierId: supplier?.id,
          qty: rl.qty,
          cost: rl.cost,
        };
      })
      .sort((a, b) => b.date.localeCompare(a.date));
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between flex-wrap gap-2">
        <h1 className="text-xl font-semibold text-[var(--foreground)]">Raw Materials</h1>
        <div className="flex items-center gap-2">
          <button onClick={() => setAddOpen(true)} className="rounded-lg border border-neutral-400 dark:border-neutral-600 px-4 py-2 text-sm text-[var(--foreground)] hover:bg-[var(--surface-hover)]">
            + Add Raw Material
          </button>
          <button onClick={() => setReceiptOpen(true)} className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-50 dark:text-neutral-950 hover:opacity-90 transition-opacity">
            + Record Purchase
          </button>
        </div>
      </div>

      <input
        value={search}
        onChange={(e) => setSearch(e.target.value)}
        placeholder="Search raw materials..."
        className="w-full max-w-sm rounded-lg border border-[var(--surface-border)] bg-[var(--surface)] px-3 py-2 text-sm text-[var(--foreground)] placeholder:text-[var(--text-faint)] outline-none focus:border-[var(--surface-border-strong)]"
      />

      <div className="overflow-x-auto rounded-xl border border-[var(--surface-border)]">
        <table className="w-full min-w-[720px] text-sm">
          <thead>
            <tr className="border-b border-[var(--surface-border)] bg-[var(--surface)] text-left text-[var(--text-muted)]">
              <th className="px-4 py-3 font-medium w-8"></th>
              <th className="px-4 py-3 font-medium">Name</th>
              <th className="px-4 py-3 font-medium">Unit</th>
              <th className="px-4 py-3 font-medium">Qty in Stock</th>
              <th className="px-4 py-3 font-medium">Avg Unit Cost</th>
              <th className="px-4 py-3 font-medium">Threshold</th>
              <th className="px-4 py-3 font-medium">Status</th>
            </tr>
          </thead>
          <tbody>
            {filtered.length === 0 && (
              <tr><td colSpan={7} className="px-4 py-8 text-center text-[var(--text-faint)]">No raw materials found.</td></tr>
            )}
            {filtered.map((m) => {
              const isLow = m.quantityInStock < m.lowStockThreshold;
              const isExpanded = expandedId === m.id;
              const history = isExpanded ? historyFor(m.id) : [];
              return (
                <Fragment key={m.id}>
                  <tr className="border-b border-[var(--surface-border)] last:border-0 hover:bg-[var(--surface)]/60">
                    <td className="px-4 py-3">
                      <button
                        type="button"
                        onClick={() => setExpandedId(isExpanded ? null : m.id)}
                        className="text-[var(--text-muted)] hover:text-[var(--foreground)]"
                        aria-label={isExpanded ? "Collapse" : "Expand"}
                      >
                        {isExpanded ? <ChevronDown size={16} /> : <ChevronRight size={16} />}
                      </button>
                    </td>
                    <td className="px-4 py-3">
                      <NavLink href={`/raw-materials/${m.id}`} className="text-[var(--foreground)] hover:underline">
                        {m.name}
                      </NavLink>
                    </td>
                    <td className="px-4 py-3 text-[var(--text-secondary)]">{m.unit}</td>
                    <td className="px-4 py-3 text-[var(--text-secondary)]">{m.quantityInStock}</td>
                    <td className="px-4 py-3 text-[var(--text-secondary)]">Rs. {m.avgUnitCost.toLocaleString()}</td>
                    <td className="px-4 py-3 text-[var(--text-secondary)]">{m.lowStockThreshold}</td>
                    <td className="px-4 py-3"><StatusBadge isLow={isLow} /></td>
                  </tr>
                  {isExpanded && (
                    <tr className="border-b border-[var(--surface-border)] last:border-0 bg-[var(--background)]">
                      <td></td>
                      <td colSpan={6} className="px-4 py-3">
                        {history.length === 0 ? (
                          <p className="text-xs text-[var(--text-faint)] py-2">No purchase history yet for this material.</p>
                        ) : (
                          <table className="w-full text-xs">
                            <thead>
                              <tr className="text-left text-[var(--text-muted)]">
                                <th className="pb-2 font-medium">Date</th>
                                <th className="pb-2 font-medium">Supplier</th>
                                <th className="pb-2 font-medium">Quantity</th>
                                <th className="pb-2 font-medium">Cost/Unit</th>
                                <th className="pb-2 font-medium">Total</th>
                              </tr>
                            </thead>
                            <tbody>
                              {history.map((h) => (
                                <tr key={h.id} className="border-t border-[var(--surface-border)]">
                                  <td className="py-2 text-[var(--text-secondary)]">{h.date}</td>
                                  <td className="py-2 text-[var(--text-secondary)]">
                                    {h.supplierId ? (
                                      <NavLink href={`/suppliers/${h.supplierId}`} className="hover:underline text-[var(--foreground)]">{h.supplierName}</NavLink>
                                    ) : h.supplierName}
                                  </td>
                                  <td className="py-2 text-[var(--text-secondary)]">{h.qty} {m.unit}</td>
                                  <td className="py-2 text-[var(--text-secondary)]">Rs. {h.cost.toLocaleString()}</td>
                                  <td className="py-2 text-[var(--text-secondary)]">Rs. {(h.qty * h.cost).toLocaleString()}</td>
                                </tr>
                              ))}
                            </tbody>
                          </table>
                        )}
                      </td>
                    </tr>
                  )}
                </Fragment>
              );
            })}
          </tbody>
        </table>
      </div>

      <AddRawMaterialMasterDialog open={addOpen} onClose={() => setAddOpen(false)} />
      <PurchaseReceiptDialog open={receiptOpen} onClose={() => setReceiptOpen(false)} />
    </div>
  );
}
'@

Write-FileSmart "apps\frontend\app\(dashboard)\raw-materials\page.tsx" $rawMaterialsPageContent

# ---------------------------------------------------------------------------
# apps/frontend/app/(dashboard)/raw-materials/[id]/page.tsx
# ---------------------------------------------------------------------------
$rawMaterialDetailContent = @'
"use client";

import { use, useMemo, useState } from "react";
import { NavLink } from "@/components/ui/nav-link";
import { useStore } from "@/lib/store";
import { PurchaseReceiptDialog } from "@/components/ui/purchase-receipt-dialog";

export default function RawMaterialDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const material = useStore((s) => s.rawMaterials.find((m) => m.id === id));
  const receipts = useStore((s) => s.receipts);
  const receiptLines = useStore((s) => s.receiptLines);
  const suppliers = useStore((s) => s.suppliers);
  const [dialogOpen, setDialogOpen] = useState(false);

  const history = useMemo(() => {
    return receiptLines
      .filter((rl) => rl.rawMaterialId === id)
      .map((rl) => {
        const receipt = receipts.find((r) => r.id === rl.receiptId);
        const supplier = receipt ? suppliers.find((s) => s.id === receipt.supplierId) : undefined;
        return {
          id: rl.id,
          date: receipt?.purchaseDate ?? "-",
          supplier,
          receiptId: rl.receiptId,
          qty: rl.qty,
          cost: rl.cost,
        };
      })
      .sort((a, b) => b.date.localeCompare(a.date));
  }, [receiptLines, receipts, suppliers, id]);

  if (!material) {
    return (
      <div className="space-y-4">
        <NavLink href="/raw-materials" className="text-sm text-[var(--text-muted)] hover:underline">&larr; Back to Raw Materials</NavLink>
        <p className="text-[var(--text-muted)]">Raw material not found.</p>
      </div>
    );
  }

  const isLow = material.quantityInStock < material.lowStockThreshold;

  return (
    <div className="space-y-6">
      <div className="text-sm text-[var(--text-muted)]">
        <NavLink href="/raw-materials" className="hover:underline text-[var(--text-secondary)]">Raw Materials</NavLink>{" "}
        / <span className="text-[var(--foreground)]">{material.name}</span>
      </div>

      <div className="rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-5">
        <div className="flex items-start justify-between">
          <div>
            <h1 className="text-xl font-semibold text-[var(--foreground)]">{material.name}</h1>
            <p className="text-sm text-[var(--text-muted)] mt-1">Unit: {material.unit}</p>
          </div>
          <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ${
            isLow ? "bg-red-950 text-red-400 border border-red-900" : "bg-green-950 text-green-400 border border-green-900"
          }`}>
            {isLow ? "Low Stock" : "OK"}
          </span>
        </div>

        <div className="mt-5 grid grid-cols-2 sm:grid-cols-4 gap-4">
          <div>
            <div className="text-[var(--text-muted)] text-xs">Current Stock</div>
            <div className="text-lg font-semibold text-[var(--foreground)] mt-1">{material.quantityInStock} {material.unit}</div>
          </div>
          <div>
            <div className="text-[var(--text-muted)] text-xs flex items-center gap-1">
              Avg Unit Cost
              <span title="Weighted average: (Existing Qty x Existing Avg Cost + New Qty x New Cost) / (Existing Qty + New Qty)" className="cursor-help text-[var(--text-faint)]">(i)</span>
            </div>
            <div className="text-lg font-semibold text-[var(--foreground)] mt-1">Rs. {material.avgUnitCost.toLocaleString()}</div>
          </div>
          <div>
            <div className="text-[var(--text-muted)] text-xs">Low Stock Threshold</div>
            <div className="text-lg font-semibold text-[var(--foreground)] mt-1">{material.lowStockThreshold}</div>
          </div>
          <div>
            <div className="text-[var(--text-muted)] text-xs">Stock Value</div>
            <div className="text-lg font-semibold text-[var(--foreground)] mt-1">Rs. {(material.quantityInStock * material.avgUnitCost).toLocaleString()}</div>
          </div>
        </div>
      </div>

      <div className="flex items-center justify-between">
        <h2 className="text-lg font-semibold text-[var(--foreground)]">Purchase History</h2>
        <button onClick={() => setDialogOpen(true)} className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-50 dark:text-neutral-950 hover:opacity-90 transition-opacity">
          + Record Purchase
        </button>
      </div>

      <div className="overflow-x-auto rounded-xl border border-[var(--surface-border)]">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-[var(--surface-border)] bg-[var(--surface)] text-left text-[var(--text-muted)]">
              <th className="px-4 py-3 font-medium">Date</th>
              <th className="px-4 py-3 font-medium">Supplier</th>
              <th className="px-4 py-3 font-medium">Quantity</th>
              <th className="px-4 py-3 font-medium">Cost / Unit</th>
              <th className="px-4 py-3 font-medium">Total</th>
              <th className="px-4 py-3 font-medium">Receipt</th>
            </tr>
          </thead>
          <tbody>
            {history.map((h) => (
              <tr key={h.id} className="border-b border-[var(--surface-border)] last:border-0 hover:bg-[var(--surface)]/60">
                <td className="px-4 py-3 text-[var(--text-secondary)]">{h.date}</td>
                <td className="px-4 py-3 text-[var(--text-secondary)]">
                  {h.supplier ? (
                    <NavLink href={`/suppliers/${h.supplier.id}`} className="hover:underline text-[var(--foreground)]">{h.supplier.name}</NavLink>
                  ) : "-"}
                </td>
                <td className="px-4 py-3 text-[var(--text-secondary)]">{h.qty} {material.unit}</td>
                <td className="px-4 py-3 text-[var(--text-secondary)]">Rs. {h.cost.toLocaleString()}</td>
                <td className="px-4 py-3 text-[var(--text-secondary)]">Rs. {(h.qty * h.cost).toLocaleString()}</td>
                <td className="px-4 py-3 text-[var(--text-secondary)]">
                  <NavLink href={`/receipts`} className="hover:underline text-[var(--foreground)]">{h.receiptId}</NavLink>
                </td>
              </tr>
            ))}
            {history.length === 0 && (
              <tr><td colSpan={6} className="px-4 py-8 text-center text-[var(--text-faint)]">No purchases recorded yet.</td></tr>
            )}
          </tbody>
        </table>
      </div>

      <PurchaseReceiptDialog open={dialogOpen} onClose={() => setDialogOpen(false)} lockRawMaterialId={material.id} />
    </div>
  );
}
'@

Write-FileSmart "apps\frontend\app\(dashboard)\raw-materials\[id]\page.tsx" $rawMaterialDetailContent

# ---------------------------------------------------------------------------
# apps/frontend/app/(dashboard)/suppliers/[id]/page.tsx
# ---------------------------------------------------------------------------
$supplierDetailContent = @'
"use client";

import { Fragment, use, useMemo, useState } from "react";
import { NavLink } from "@/components/ui/nav-link";
import { ChevronDown, ChevronRight } from "lucide-react";
import { useStore } from "@/lib/store";
import { PurchaseReceiptDialog } from "@/components/ui/purchase-receipt-dialog";

export default function SupplierDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const supplier = useStore((s) => s.suppliers.find((sup) => sup.id === id));
  const allReceipts = useStore((s) => s.receipts);
  const receiptLines = useStore((s) => s.receiptLines);
  const rawMaterials = useStore((s) => s.rawMaterials);
  const [expandedReceiptId, setExpandedReceiptId] = useState<string | null>(null);
  const [dialogOpen, setDialogOpen] = useState(false);

  const receipts = useMemo(
    () => allReceipts.filter((r) => r.supplierId === id).sort((a, b) => b.purchaseDate.localeCompare(a.purchaseDate)),
    [allReceipts, id]
  );

  const receiptSummaries = useMemo(() => {
    return receipts.map((r) => {
      const lines = receiptLines.filter((l) => l.receiptId === r.id);
      const totalValue = lines.reduce((sum, l) => sum + l.qty * l.cost, 0);
      return { receipt: r, lines, itemCount: lines.length, totalValue };
    });
  }, [receipts, receiptLines]);

  const totalLifetimeValue = useMemo(
    () => receiptSummaries.reduce((sum, r) => sum + r.totalValue, 0),
    [receiptSummaries]
  );

  if (!supplier) {
    return (
      <div className="space-y-4">
        <NavLink href="/suppliers" className="text-sm text-[var(--text-muted)] hover:underline">&larr; Back to Suppliers</NavLink>
        <p className="text-[var(--text-muted)]">Supplier not found.</p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="text-sm text-[var(--text-muted)]">
        <NavLink href="/suppliers" className="hover:underline text-[var(--text-secondary)]">Suppliers</NavLink>{" "}
        / <span className="text-[var(--foreground)]">{supplier.name}</span>
      </div>

      <div className="rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-5">
        <h1 className="text-xl font-semibold text-[var(--foreground)]">{supplier.name}</h1>
        <p className="text-sm text-[var(--text-muted)] mt-1">{supplier.phone}</p>
        {supplier.address && <p className="text-sm text-[var(--text-muted)]">{supplier.address}</p>}

        <div className="mt-5 grid grid-cols-2 sm:grid-cols-3 gap-4">
          <div>
            <div className="text-[var(--text-muted)] text-xs">Total Receipts</div>
            <div className="text-lg font-semibold text-[var(--foreground)] mt-1">{receipts.length}</div>
          </div>
          <div>
            <div className="text-[var(--text-muted)] text-xs">Total Lifetime Value</div>
            <div className="text-lg font-semibold text-[var(--foreground)] mt-1">Rs. {totalLifetimeValue.toLocaleString()}</div>
          </div>
        </div>
      </div>

      <div className="flex items-center justify-between">
        <h2 className="text-lg font-semibold text-[var(--foreground)]">Purchase History</h2>
        <button onClick={() => setDialogOpen(true)} className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-50 dark:text-neutral-950 hover:opacity-90 transition-opacity">
          + Record Purchase
        </button>
      </div>

      <div className="overflow-x-auto rounded-xl border border-[var(--surface-border)]">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-[var(--surface-border)] bg-[var(--surface)] text-left text-[var(--text-muted)]">
              <th className="px-4 py-3 font-medium w-8"></th>
              <th className="px-4 py-3 font-medium">Receipt Date</th>
              <th className="px-4 py-3 font-medium">Items</th>
              <th className="px-4 py-3 font-medium">Total Value</th>
            </tr>
          </thead>
          <tbody>
            {receiptSummaries.map(({ receipt, lines, itemCount, totalValue }) => {
              const isExpanded = expandedReceiptId === receipt.id;
              return (
                <Fragment key={receipt.id}>
                  <tr className="border-b border-[var(--surface-border)] last:border-0 hover:bg-[var(--surface)]/60">
                    <td className="px-4 py-3">
                      <button
                        type="button"
                        onClick={() => setExpandedReceiptId(isExpanded ? null : receipt.id)}
                        className="text-[var(--text-muted)] hover:text-[var(--foreground)]"
                      >
                        {isExpanded ? <ChevronDown size={16} /> : <ChevronRight size={16} />}
                      </button>
                    </td>
                    <td className="px-4 py-3 text-[var(--text-secondary)]">{receipt.purchaseDate}</td>
                    <td className="px-4 py-3 text-[var(--text-secondary)]">{itemCount} item{itemCount !== 1 ? "s" : ""}</td>
                    <td className="px-4 py-3 text-[var(--text-secondary)]">Rs. {totalValue.toLocaleString()}</td>
                  </tr>
                  {isExpanded && (
                    <tr className="border-b border-[var(--surface-border)] last:border-0 bg-[var(--background)]">
                      <td></td>
                      <td colSpan={3} className="px-4 py-3">
                        <table className="w-full text-xs">
                          <thead>
                            <tr className="text-left text-[var(--text-muted)]">
                              <th className="pb-2 font-medium">Raw Material</th>
                              <th className="pb-2 font-medium">Quantity</th>
                              <th className="pb-2 font-medium">Cost/Unit</th>
                              <th className="pb-2 font-medium">Total</th>
                            </tr>
                          </thead>
                          <tbody>
                            {lines.map((l) => {
                              const material = rawMaterials.find((m) => m.id === l.rawMaterialId);
                              return (
                                <tr key={l.id} className="border-t border-[var(--surface-border)]">
                                  <td className="py-2 text-[var(--text-secondary)]">
                                    {material ? (
                                      <NavLink href={`/raw-materials/${material.id}`} className="hover:underline text-[var(--foreground)]">{material.name}</NavLink>
                                    ) : "-"}
                                  </td>
                                  <td className="py-2 text-[var(--text-secondary)]">{l.qty} {material?.unit ?? ""}</td>
                                  <td className="py-2 text-[var(--text-secondary)]">Rs. {l.cost.toLocaleString()}</td>
                                  <td className="py-2 text-[var(--text-secondary)]">Rs. {(l.qty * l.cost).toLocaleString()}</td>
                                </tr>
                              );
                            })}
                          </tbody>
                        </table>
                      </td>
                    </tr>
                  )}
                </Fragment>
              );
            })}
            {receiptSummaries.length === 0 && (
              <tr><td colSpan={4} className="px-4 py-8 text-center text-[var(--text-faint)]">No purchases recorded yet for this supplier.</td></tr>
            )}
          </tbody>
        </table>
      </div>

      <PurchaseReceiptDialog open={dialogOpen} onClose={() => setDialogOpen(false)} lockSupplierId={supplier.id} />
    </div>
  );
}
'@

Write-FileSmart "apps\frontend\app\(dashboard)\suppliers\[id]\page.tsx" $supplierDetailContent

# ---------------------------------------------------------------------------
# apps/frontend/app/(dashboard)/receipts/page.tsx (New - FR-9/FR-10)
# ---------------------------------------------------------------------------
$receiptsPageContent = @'
"use client";

import { Fragment, useMemo, useState } from "react";
import { NavLink } from "@/components/ui/nav-link";
import { ChevronDown, ChevronRight } from "lucide-react";
import { useStore } from "@/lib/store";
import { PurchaseReceiptDialog } from "@/components/ui/purchase-receipt-dialog";

export default function ReceiptsPage() {
  const receipts = useStore((s) => s.receipts);
  const receiptLines = useStore((s) => s.receiptLines);
  const suppliers = useStore((s) => s.suppliers);
  const rawMaterials = useStore((s) => s.rawMaterials);

  const [supplierFilter, setSupplierFilter] = useState("");
  const [materialFilter, setMaterialFilter] = useState("");
  const [fromDate, setFromDate] = useState("");
  const [toDate, setToDate] = useState("");
  const [expandedId, setExpandedId] = useState<string | null>(null);
  const [dialogOpen, setDialogOpen] = useState(false);

  const rows = useMemo(() => {
    return receipts
      .map((r) => {
        const lines = receiptLines.filter((l) => l.receiptId === r.id);
        const supplier = suppliers.find((s) => s.id === r.supplierId);
        const totalValue = lines.reduce((sum, l) => sum + l.qty * l.cost, 0);
        const itemNames = lines.map((l) => rawMaterials.find((m) => m.id === l.rawMaterialId)?.name ?? "?");
        return { receipt: r, lines, supplier, totalValue, itemNames };
      })
      .filter(({ receipt, lines }) => {
        if (supplierFilter && receipt.supplierId !== supplierFilter) return false;
        if (materialFilter && !lines.some((l) => l.rawMaterialId === materialFilter)) return false;
        if (fromDate && receipt.purchaseDate < fromDate) return false;
        if (toDate && receipt.purchaseDate > toDate) return false;
        return true;
      })
      .sort((a, b) => b.receipt.purchaseDate.localeCompare(a.receipt.purchaseDate));
  }, [receipts, receiptLines, suppliers, rawMaterials, supplierFilter, materialFilter, fromDate, toDate]);

  const hasFilters = !!(supplierFilter || materialFilter || fromDate || toDate);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between flex-wrap gap-2">
        <h1 className="text-xl font-semibold text-[var(--foreground)]">Receipts</h1>
        <button onClick={() => setDialogOpen(true)} className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-50 dark:text-neutral-950 hover:opacity-90 transition-opacity">
          + Record Purchase
        </button>
      </div>

      <div className="flex flex-col sm:flex-row flex-wrap items-stretch sm:items-end gap-3 rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-4">
        <div>
          <label className="text-xs text-[var(--text-muted)]">Supplier</label>
          <select value={supplierFilter} onChange={(e) => setSupplierFilter(e.target.value)}
            className="mt-1 block rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]">
            <option value="">All suppliers</option>
            {suppliers.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
          </select>
        </div>
        <div>
          <label className="text-xs text-[var(--text-muted)]">Raw Material</label>
          <select value={materialFilter} onChange={(e) => setMaterialFilter(e.target.value)}
            className="mt-1 block rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]">
            <option value="">All materials</option>
            {rawMaterials.map((m) => <option key={m.id} value={m.id}>{m.name}</option>)}
          </select>
        </div>
        <div>
          <label className="text-xs text-[var(--text-muted)]">From</label>
          <input value={fromDate} onChange={(e) => setFromDate(e.target.value)} type="date"
            className="mt-1 block rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
        </div>
        <div>
          <label className="text-xs text-[var(--text-muted)]">To</label>
          <input value={toDate} onChange={(e) => setToDate(e.target.value)} type="date"
            className="mt-1 block rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
        </div>
        {hasFilters && (
          <button
            type="button"
            onClick={() => { setSupplierFilter(""); setMaterialFilter(""); setFromDate(""); setToDate(""); }}
            className="rounded-lg px-3 py-2 text-xs text-[var(--text-muted)] hover:bg-[var(--surface-hover)]"
          >
            Clear filters
          </button>
        )}
      </div>

      <div className="overflow-x-auto rounded-xl border border-[var(--surface-border)]">
        <table className="w-full min-w-[640px] text-sm">
          <thead>
            <tr className="border-b border-[var(--surface-border)] bg-[var(--surface)] text-left text-[var(--text-muted)]">
              <th className="px-4 py-3 font-medium w-8"></th>
              <th className="px-4 py-3 font-medium">Receipt Date</th>
              <th className="px-4 py-3 font-medium">Supplier</th>
              <th className="px-4 py-3 font-medium">Items</th>
              <th className="px-4 py-3 font-medium">Total Value</th>
            </tr>
          </thead>
          <tbody>
            {rows.length === 0 && (
              <tr><td colSpan={5} className="px-4 py-8 text-center text-[var(--text-faint)]">No receipts match these filters.</td></tr>
            )}
            {rows.map(({ receipt, lines, supplier, totalValue, itemNames }) => {
              const isExpanded = expandedId === receipt.id;
              const summary = itemNames.length > 2
                ? `${itemNames.length} items: ${itemNames.slice(0, 2).join(", ")}, +${itemNames.length - 2}`
                : `${itemNames.length} item${itemNames.length !== 1 ? "s" : ""}: ${itemNames.join(", ")}`;
              return (
                <Fragment key={receipt.id}>
                  <tr className="border-b border-[var(--surface-border)] last:border-0 hover:bg-[var(--surface)]/60">
                    <td className="px-4 py-3">
                      <button type="button" onClick={() => setExpandedId(isExpanded ? null : receipt.id)} className="text-[var(--text-muted)] hover:text-[var(--foreground)]">
                        {isExpanded ? <ChevronDown size={16} /> : <ChevronRight size={16} />}
                      </button>
                    </td>
                    <td className="px-4 py-3 text-[var(--text-secondary)]">{receipt.purchaseDate}</td>
                    <td className="px-4 py-3 text-[var(--text-secondary)]">
                      {supplier ? (
                        <NavLink href={`/suppliers/${supplier.id}`} className="hover:underline text-[var(--foreground)]">{supplier.name}</NavLink>
                      ) : "-"}
                    </td>
                    <td className="px-4 py-3 text-[var(--text-secondary)]">{summary}</td>
                    <td className="px-4 py-3 text-[var(--text-secondary)]">Rs. {totalValue.toLocaleString()}</td>
                  </tr>
                  {isExpanded && (
                    <tr className="border-b border-[var(--surface-border)] last:border-0 bg-[var(--background)]">
                      <td></td>
                      <td colSpan={4} className="px-4 py-3">
                        <table className="w-full text-xs">
                          <thead>
                            <tr className="text-left text-[var(--text-muted)]">
                              <th className="pb-2 font-medium">Raw Material</th>
                              <th className="pb-2 font-medium">Quantity</th>
                              <th className="pb-2 font-medium">Cost/Unit</th>
                              <th className="pb-2 font-medium">Total</th>
                            </tr>
                          </thead>
                          <tbody>
                            {lines.map((l) => {
                              const material = rawMaterials.find((m) => m.id === l.rawMaterialId);
                              return (
                                <tr key={l.id} className="border-t border-[var(--surface-border)]">
                                  <td className="py-2 text-[var(--text-secondary)]">
                                    {material ? (
                                      <NavLink href={`/raw-materials/${material.id}`} className="hover:underline text-[var(--foreground)]">{material.name}</NavLink>
                                    ) : "-"}
                                  </td>
                                  <td className="py-2 text-[var(--text-secondary)]">{l.qty} {material?.unit ?? ""}</td>
                                  <td className="py-2 text-[var(--text-secondary)]">Rs. {l.cost.toLocaleString()}</td>
                                  <td className="py-2 text-[var(--text-secondary)]">Rs. {(l.qty * l.cost).toLocaleString()}</td>
                                </tr>
                              );
                            })}
                          </tbody>
                        </table>
                      </td>
                    </tr>
                  )}
                </Fragment>
              );
            })}
          </tbody>
        </table>
      </div>

      <PurchaseReceiptDialog open={dialogOpen} onClose={() => setDialogOpen(false)} />
    </div>
  );
}
'@

Write-FileSmart "apps\frontend\app\(dashboard)\receipts\page.tsx" $receiptsPageContent

# ---------------------------------------------------------------------------
# apps/frontend/components/ui/sidebar-component.tsx (adds "Receipts" nav item)
# ---------------------------------------------------------------------------
$sidebarComponentContent = @'
"use client";

import React, { useState } from "react";
import { usePathname } from "next/navigation";
import {
  Search as SearchIcon,
  Dashboard,
  Task,
  Folder,
  UserMultiple,
  Analytics,
  DocumentAdd,
  Settings as SettingsIcon,
  User as UserIcon,
  ChevronDown as ChevronDownIcon,
  AddLarge,
  Archive,
  View,
  Report,
  StarFilled,
  ChartBar,
  FolderOpen,
  Security,
  Notification,
  Close as CloseIcon,
} from "@carbon/icons-react";
import { GhaniLogo } from "./ghani-logo";
import { useSidebar } from "@/lib/sidebar-context";
import { useNavigationLoading } from "@/lib/navigation-loading-context";

const softSpringEasing = "cubic-bezier(0.25, 1.1, 0.4, 1)";

type SectionId =
  | "dashboard"
  | "suppliers"
  | "raw-materials"
  | "receipts"
  | "batches"
  | "finished-cartons"
  | "customers"
  | "invoices"
  | "payments"
  | "reports"
  | "settings";

const SECTION_DEFAULT_ROUTE: Record<SectionId, string> = {
  dashboard: "/",
  suppliers: "/suppliers",
  "raw-materials": "/raw-materials",
  receipts: "/receipts",
  batches: "/batches",
  "finished-cartons": "/finished-cartons",
  customers: "/customers",
  invoices: "/invoices",
  payments: "/payments",
  reports: "/reports",
  settings: "/settings",
};

const ROUTE_PREFIXES: Array<[string, SectionId]> = [
  ["/suppliers", "suppliers"],
  ["/raw-materials", "raw-materials"],
  ["/receipts", "receipts"],
  ["/packaging", "raw-materials"],
  ["/packaging/carton-config", "raw-materials"],
  ["/batches", "batches"],
  ["/finished-cartons", "finished-cartons"],
  ["/customers", "customers"],
  ["/invoices", "invoices"],
  ["/payments", "payments"],
  ["/reports", "reports"],
  ["/settings", "settings"],
];

function getSectionFromPathname(pathname: string): SectionId {
  for (const [prefix, section] of ROUTE_PREFIXES) {
    if (pathname === prefix || pathname.startsWith(prefix + "/")) return section;
  }
  return "dashboard";
}

function BrandBadge() {
  return (
    <div className="relative shrink-0 w-full">
      <div className="flex items-center p-1 w-full">
        <div className="h-10 w-8 flex items-center justify-center pl-2 text-[var(--foreground)]">
          <GhaniLogo className="size-5" />
        </div>
        <div className="px-2 py-1">
          <div className="font-semibold text-[16px] text-[var(--foreground)]">GhaniFoods</div>
        </div>
      </div>
    </div>
  );
}

function AvatarCircle() {
  return (
    <div className="relative rounded-full shrink-0 size-8 bg-[var(--surface-hover)]">
      <div className="flex items-center justify-center size-8">
        <UserIcon size={16} className="text-[var(--foreground)]" />
      </div>
      <div aria-hidden="true" className="absolute inset-0 rounded-full border border-[var(--surface-border)] pointer-events-none" />
    </div>
  );
}

function SearchContainer({ isCollapsed = false }: { isCollapsed?: boolean }) {
  const [searchValue, setSearchValue] = useState("");

  return (
    <div
      className={`relative shrink-0 transition-all duration-500 ${isCollapsed ? "w-full flex justify-center" : "w-full"}`}
      style={{ transitionTimingFunction: softSpringEasing }}
    >
      <div
        className={`bg-[var(--background)] h-10 relative rounded-lg flex items-center transition-all duration-500 ${
          isCollapsed ? "w-10 min-w-10 justify-center" : "w-full"
        }`}
        style={{ transitionTimingFunction: softSpringEasing }}
      >
        <div
          className={`flex items-center justify-center shrink-0 transition-all duration-500 ${isCollapsed ? "p-1" : "px-1"}`}
          style={{ transitionTimingFunction: softSpringEasing }}
        >
          <div className="size-8 flex items-center justify-center">
            <SearchIcon size={16} className="text-[var(--foreground)]" />
          </div>
        </div>

        <div
          className={`flex-1 relative transition-opacity duration-500 overflow-hidden ${isCollapsed ? "opacity-0 w-0" : "opacity-100"}`}
          style={{ transitionTimingFunction: softSpringEasing }}
        >
          <div className="flex flex-col justify-center size-full">
            <div className="flex flex-col gap-2 items-start justify-center pr-2 py-1 w-full">
              <input
                type="text"
                placeholder="Search..."
                value={searchValue}
                onChange={(e) => setSearchValue(e.target.value)}
                className="w-full bg-transparent border-none outline-none text-[14px] text-[var(--foreground)] placeholder:text-[var(--text-muted)] leading-[20px]"
                tabIndex={isCollapsed ? -1 : 0}
              />
            </div>
          </div>
        </div>

        <div aria-hidden="true" className="absolute inset-0 rounded-lg border border-[var(--surface-border)] pointer-events-none" />
      </div>
    </div>
  );
}

interface MenuItemT {
  icon?: React.ReactNode;
  label: string;
  href?: string;
}
interface MenuSectionT {
  title: string;
  items: MenuItemT[];
}
interface SidebarContent {
  title: string;
  sections: MenuSectionT[];
}

function getSidebarContent(activeSection: SectionId): SidebarContent {
  const contentMap: Record<SectionId, SidebarContent> = {
    dashboard: {
      title: "Dashboard",
      sections: [
        { title: "Overview", items: [{ icon: <View size={16} className="text-[var(--foreground)]" />, label: "Dashboard", href: "/" }] },
      ],
    },
    "raw-materials": {
      title: "Raw Materials",
      sections: [
        {
          title: "Inventory",
          items: [
            { icon: <Folder size={16} className="text-[var(--foreground)]" />, label: "All Raw Materials", href: "/raw-materials" },
            { icon: <FolderOpen size={16} className="text-[var(--foreground)]" />, label: "Packaging Materials", href: "/packaging" },
            { icon: <Archive size={16} className="text-[var(--foreground)]" />, label: "Carton Configurations", href: "/packaging/carton-config" },
          ],
        },
      ],
    },
    receipts: {
      title: "Receipts",
      sections: [
        { title: "Purchase Receipts", items: [{ icon: <FolderOpen size={16} className="text-[var(--foreground)]" />, label: "All Receipts", href: "/receipts" }] },
      ],
    },
    suppliers: {
      title: "Suppliers",
      sections: [
        { title: "Suppliers", items: [{ icon: <UserMultiple size={16} className="text-[var(--foreground)]" />, label: "All Suppliers", href: "/suppliers" }] },
      ],
    },
    batches: {
      title: "Production Batches",
      sections: [
        {
          title: "Batches",
          items: [
            { icon: <Task size={16} className="text-[var(--foreground)]" />, label: "All Batches", href: "/batches" },
            { icon: <AddLarge size={16} className="text-[var(--foreground)]" />, label: "New Batch", href: "/batches/new" },
          ],
        },
      ],
    },
    "finished-cartons": {
      title: "Finished Cartons",
      sections: [
        { title: "Stock", items: [{ icon: <Archive size={16} className="text-[var(--foreground)]" />, label: "Ready Stock", href: "/finished-cartons" }] },
      ],
    },
    customers: {
      title: "Customers",
      sections: [
        { title: "Customers", items: [{ icon: <UserMultiple size={16} className="text-[var(--foreground)]" />, label: "All Customers", href: "/customers" }] },
      ],
    },
    invoices: {
      title: "Invoices",
      sections: [
        {
          title: "Invoices",
          items: [
            { icon: <DocumentAdd size={16} className="text-[var(--foreground)]" />, label: "All Invoices", href: "/invoices" },
            { icon: <AddLarge size={16} className="text-[var(--foreground)]" />, label: "New Invoice", href: "/invoices/new" },
          ],
        },
      ],
    },
    payments: {
      title: "Payments",
      sections: [
        { title: "Payments", items: [{ icon: <ChartBar size={16} className="text-[var(--foreground)]" />, label: "All Payments", href: "/payments" }] },
      ],
    },
    reports: {
      title: "Reports",
      sections: [
        {
          title: "Analytics",
          items: [
            { icon: <Report size={16} className="text-[var(--foreground)]" />, label: "Inventory Movement", href: "/reports" },
            { icon: <Analytics size={16} className="text-[var(--foreground)]" />, label: "Production Yield", href: "/reports" },
            { icon: <StarFilled size={16} className="text-[var(--foreground)]" />, label: "P&L", href: "/reports" },
          ],
        },
      ],
    },
    settings: {
      title: "Settings",
      sections: [
        {
          title: "Workspace",
          items: [
            { icon: <SettingsIcon size={16} className="text-[var(--foreground)]" />, label: "Business Profile", href: "/settings" },
            { icon: <Security size={16} className="text-[var(--foreground)]" />, label: "Security" },
            { icon: <Notification size={16} className="text-[var(--foreground)]" />, label: "Notifications" },
          ],
        },
      ],
    },
  };

  return contentMap[activeSection];
}

function IconNavButton({
  children,
  isActive = false,
  onClick,
  label,
}: {
  children: React.ReactNode;
  isActive?: boolean;
  onClick: () => void;
  label: string;
}) {
  return (
    <button
      type="button"
      title={label}
      aria-label={label}
      className={`flex flex-col items-center justify-center gap-0.5 rounded-lg w-14 min-w-14 h-12 transition-colors duration-500
        ${isActive ? "bg-[var(--surface-hover)] text-[var(--foreground)]" : "hover:bg-[var(--surface-hover)] text-[var(--text-muted)] hover:text-[var(--text-secondary)]"}`}
      style={{ transitionTimingFunction: softSpringEasing }}
      onClick={onClick}
    >
      {children}
      <span className="text-[8px] leading-none text-center px-0.5">{label}</span>
    </button>
  );
}

function IconNavigation({ activeSection }: { activeSection: SectionId }) {
  const { navigate } = useNavigationLoading();

  const navItems: Array<{ id: SectionId; icon: React.ReactNode; label: string }> = [
    { id: "dashboard", icon: <Dashboard size={16} />, label: "Dashboard" },
    { id: "raw-materials", icon: <Folder size={16} />, label: "Raw Materials" },
    { id: "receipts", icon: <FolderOpen size={16} />, label: "Receipts" },
    { id: "suppliers", icon: <UserMultiple size={16} />, label: "Suppliers" },
    { id: "batches", icon: <Task size={16} />, label: "Batches" },
    { id: "finished-cartons", icon: <Archive size={16} />, label: "Cartons" },
    { id: "customers", icon: <UserMultiple size={16} />, label: "Customers" },
    { id: "invoices", icon: <DocumentAdd size={16} />, label: "Invoices" },
    { id: "payments", icon: <ChartBar size={16} />, label: "Payments" },
    { id: "reports", icon: <Analytics size={16} />, label: "Reports" },
  ];

  const goTo = (section: SectionId) => navigate(SECTION_DEFAULT_ROUTE[section]);

  return (
    <aside className="hidden lg:flex bg-[var(--background)] flex-col gap-2 items-center p-3 w-[76px] h-screen border-r border-[var(--surface-border)] overflow-y-auto">
      <div className="mb-2 size-10 flex items-center justify-center text-[var(--foreground)] shrink-0">
        <GhaniLogo className="size-6" />
      </div>

      <div className="flex flex-col gap-1 w-full items-center">
        {navItems.map((item) => (
          <IconNavButton key={item.id} isActive={activeSection === item.id} onClick={() => goTo(item.id)} label={item.label}>
            {item.icon}
          </IconNavButton>
        ))}
      </div>

      <div className="flex-1" />

      <div className="flex flex-col gap-1 w-full items-center shrink-0">
        <IconNavButton isActive={activeSection === "settings"} onClick={() => goTo("settings")} label="Settings">
          <SettingsIcon size={16} />
        </IconNavButton>
        <div className="size-8 mt-1">
          <AvatarCircle />
        </div>
      </div>
    </aside>
  );
}


function MobileSectionNav({ activeSection }: { activeSection: SectionId }) {
  const { navigate } = useNavigationLoading();

  const navItems: Array<{ id: SectionId; icon: React.ReactNode; label: string }> = [
    { id: "dashboard", icon: <Dashboard size={18} />, label: "Dashboard" },
    { id: "raw-materials", icon: <Folder size={18} />, label: "Raw Materials" },
    { id: "receipts", icon: <FolderOpen size={18} />, label: "Receipts" },
    { id: "suppliers", icon: <UserMultiple size={18} />, label: "Suppliers" },
    { id: "batches", icon: <Task size={18} />, label: "Batches" },
    { id: "finished-cartons", icon: <Archive size={18} />, label: "Finished Cartons" },
    { id: "customers", icon: <UserMultiple size={18} />, label: "Customers" },
    { id: "invoices", icon: <DocumentAdd size={18} />, label: "Invoices" },
    { id: "payments", icon: <ChartBar size={18} />, label: "Payments" },
    { id: "reports", icon: <Analytics size={18} />, label: "Reports" },
    { id: "settings", icon: <SettingsIcon size={18} />, label: "Settings" },
  ];

  const goTo = (section: SectionId) => navigate(SECTION_DEFAULT_ROUTE[section]);

  return (
    <div className="w-full lg:hidden flex flex-col gap-1">
      <div className="px-2 py-1 text-[14px] text-[var(--text-muted)]">Sections</div>
      <div className="grid grid-cols-1 gap-1">
        {navItems.map((item) => (
          <button
            key={item.id}
            type="button"
            onClick={() => goTo(item.id)}
            className={`flex items-center gap-3 rounded-lg px-4 py-2.5 text-left transition-colors duration-300 ${
              activeSection === item.id
                ? "bg-[var(--surface-hover)] text-[var(--foreground)]"
                : "text-[var(--text-secondary)] hover:bg-[var(--surface-hover)]"
            }`}
          >
            <span className="shrink-0">{item.icon}</span>
            <span className="text-[14px]">{item.label}</span>
          </button>
        ))}
      </div>
      <div className="h-px w-full bg-[var(--surface-border)] my-2" />
    </div>
  );
}
function SectionTitle({
  title,
  onToggleCollapse,
  isCollapsed,
}: {
  title: string;
  onToggleCollapse: () => void;
  isCollapsed: boolean;
}) {
  if (isCollapsed) {
    return (
      <div className="w-full hidden lg:flex justify-center transition-all duration-500" style={{ transitionTimingFunction: softSpringEasing }}>
        <button
          type="button"
          onClick={onToggleCollapse}
          className="flex items-center justify-center rounded-lg size-10 min-w-10 transition-all duration-500 hover:bg-[var(--surface-hover)] text-[var(--text-muted)] hover:text-[var(--text-secondary)]"
          style={{ transitionTimingFunction: softSpringEasing }}
          aria-label="Expand sidebar"
        >
          <span className="inline-block rotate-180">
            <ChevronDownIcon size={16} />
          </span>
        </button>
      </div>
    );
  }

  return (
    <div className="w-full overflow-hidden transition-all duration-500" style={{ transitionTimingFunction: softSpringEasing }}>
      <div className="flex items-center justify-between">
        <div className="flex items-center h-10">
          <div className="px-2 py-1">
            <div className="font-semibold text-[18px] text-[var(--foreground)] leading-[27px]">{title}</div>
          </div>
        </div>
        <div className="pr-1 hidden lg:block">
          <button
            type="button"
            onClick={onToggleCollapse}
            className="flex items-center justify-center rounded-lg size-10 min-w-10 transition-all duration-500 hover:bg-[var(--surface-hover)] text-[var(--text-muted)] hover:text-[var(--text-secondary)]"
            style={{ transitionTimingFunction: softSpringEasing }}
            aria-label="Collapse sidebar"
          >
            <ChevronDownIcon size={16} className="-rotate-90" />
          </button>
        </div>
      </div>
    </div>
  );
}

function MenuItem({ item, isCollapsed, isActive }: { item: MenuItemT; isCollapsed?: boolean; isActive: boolean }) {
  const { navigate } = useNavigationLoading();

  const content = (
    <div
      className={`rounded-lg cursor-pointer transition-all duration-500 flex items-center relative ${
        isActive ? "bg-[var(--surface-hover)]" : "hover:bg-[var(--surface-hover)]"
      } ${isCollapsed ? "w-10 min-w-10 h-10 justify-center p-4" : "w-full h-10 px-4 py-2"}`}
      style={{ transitionTimingFunction: softSpringEasing }}
      title={isCollapsed ? item.label : undefined}
    >
      <div className="flex items-center justify-center shrink-0">{item.icon}</div>
      <div
        className={`flex-1 relative transition-opacity duration-500 overflow-hidden ${isCollapsed ? "opacity-0 w-0" : "opacity-100 ml-3"}`}
        style={{ transitionTimingFunction: softSpringEasing }}
      >
        <div className="text-[14px] text-[var(--foreground)] leading-[20px] truncate">{item.label}</div>
      </div>
    </div>
  );

  return (
    <div
      className={`relative shrink-0 transition-all duration-500 ${isCollapsed ? "w-full flex justify-center" : "w-full"}`}
      style={{ transitionTimingFunction: softSpringEasing }}
    >
      {item.href ? (
        <button type="button" onClick={() => navigate(item.href!)} className="block w-full text-left">
          {content}
        </button>
      ) : (
        content
      )}
    </div>
  );
}

function MenuSection({
  section,
  isCollapsed,
  pathname,
}: {
  section: MenuSectionT;
  isCollapsed?: boolean;
  pathname: string;
}) {
  return (
    <div className="flex flex-col w-full">
      <div
        className={`relative shrink-0 w-full transition-all duration-500 overflow-hidden ${isCollapsed ? "h-0 opacity-0" : "h-10 opacity-100"}`}
        style={{ transitionTimingFunction: softSpringEasing }}
      >
        <div className="flex items-center h-10 px-4">
          <div className="text-[14px] text-[var(--text-muted)]">{section.title}</div>
        </div>
      </div>

      {section.items.map((item, index) => {
        const isActive = !!item.href && (pathname === item.href || pathname.startsWith(item.href + "/"));
        return <MenuItem key={`${section.title}-${index}`} item={item} isCollapsed={isCollapsed} isActive={isActive} />;
      })}
    </div>
  );
}

function DetailSidebar({ activeSection, pathname }: { activeSection: SectionId; pathname: string }) {
  const [isCollapsed, setIsCollapsed] = useState(false);
  const { isOpen, close } = useSidebar();
  const content = getSidebarContent(activeSection);

  const toggleCollapse = () => setIsCollapsed((s) => !s);

  return (
    <>
      {/* Mobile backdrop - only rendered when the drawer is open */}
      {isOpen && (
        <div
          className="fixed inset-0 z-40 bg-black/60 lg:hidden"
          onClick={close}
          aria-hidden="true"
        />
      )}

      <aside
        className={`bg-[var(--background)] flex flex-col gap-4 items-start p-4 transition-all duration-300 h-screen border-r border-[var(--surface-border)]
          fixed inset-y-0 left-0 z-50 w-72 max-w-[85vw] overflow-y-auto
          ${isOpen ? "translate-x-0" : "-translate-x-full"}
          lg:static lg:z-auto lg:translate-x-0 lg:transition-[width] lg:duration-500 lg:h-screen
          ${isCollapsed ? "lg:w-16 lg:min-w-16 lg:!px-0 lg:justify-center" : "lg:w-72"}
        `}
        style={{ transitionTimingFunction: softSpringEasing }}
      >
        <button
          type="button"
          onClick={close}
          aria-label="Close menu"
          className="lg:hidden absolute top-4 right-4 flex items-center justify-center size-8 rounded-lg hover:bg-[var(--surface-hover)] text-[var(--text-muted)]"
        >
          <CloseIcon size={18} />
        </button>

        {!isCollapsed && <BrandBadge />}
        {!isCollapsed && <MobileSectionNav activeSection={activeSection} />}
        <SectionTitle title={content.title} onToggleCollapse={toggleCollapse} isCollapsed={isCollapsed} />
        <div className="w-full lg:hidden">
          <SearchContainer isCollapsed={false} />
        </div>
        <div className="w-full hidden lg:block">
          <SearchContainer isCollapsed={isCollapsed} />
        </div>

        <div
          className={`flex flex-col w-full overflow-y-auto transition-all duration-500 gap-4 items-start ${isCollapsed ? "lg:gap-2 lg:items-center" : ""}`}
          style={{ transitionTimingFunction: softSpringEasing }}
        >
          {content.sections.map((section, index) => (
            <MenuSection key={`${activeSection}-${index}`} section={section} isCollapsed={isCollapsed} pathname={pathname} />
          ))}
        </div>

        <div className="w-full mt-auto pt-2 border-t border-[var(--surface-border)]">
          <div className="flex items-center gap-2 px-2 py-2">
            <AvatarCircle />
            <div className="text-[14px] text-[var(--foreground)]">Owner / Admin</div>
          </div>
        </div>
      </aside>
    </>
  );
}

export function AppSidebar() {
  const pathname = usePathname();
  const activeSection = getSectionFromPathname(pathname);

  return (
    <div className="flex flex-row">
      <IconNavigation activeSection={activeSection} />
      <DetailSidebar activeSection={activeSection} pathname={pathname} />
    </div>
  );
}

export default AppSidebar;
'@

Write-FileSmart "apps\frontend\components\ui\sidebar-component.tsx" $sidebarComponentContent

Write-Host "`n=== Step 2 complete ===" -ForegroundColor Cyan
Write-Host "New: PurchaseReceiptDialog (shared), /receipts register page, Receipts sidebar link." -ForegroundColor Yellow
Write-Host "Rewritten: /raw-materials (expandable rows), /raw-materials/[id], /suppliers/[id]." -ForegroundColor Yellow
Write-Host "Run 'npm run dev' and check these pages. Packaging/Invoices/Payments still use the" -ForegroundColor Yellow
Write-Host "old store API and will keep showing TS errors until Steps 3/6/7 update them." -ForegroundColor Yellow