"use client";

import { useState } from "react";
import { toast } from "@/components/ui/toast";
import { useStore } from "@/lib/store";

type ItemRow = {
  id: string;
  rawMaterialId: string;
  qty: string;
  expectedUnitCost: string;
};

function emptyRow(defaultRawMaterialId: string): ItemRow {
  return {
    id: crypto.randomUUID(),
    rawMaterialId: defaultRawMaterialId,
    qty: "",
    expectedUnitCost: "",
  };
}

// Purchase Order create dialog (Phase 2 / Batch B2a): one Supplier + one
// PO Date + optional notes, one or more line items (raw material, qty
// ordered, expected unit cost). Creating a PO does NOT touch stock - it
// only reserves what's expected to arrive. Batch B2b will make this PO
// the only way to record an actual goods-received Purchase Receipt.
export function PurchaseOrderDialog({
  open,
  onClose,
}: {
  open: boolean;
  onClose: () => void;
}) {
  const suppliers = useStore((s) => s.suppliers);
  const rawMaterials = useStore((s) => s.rawMaterials);
  const addSupplier = useStore((s) => s.addSupplier);
  const createPurchaseOrder = useStore((s) => s.createPurchaseOrder);

  const today = new Date().toISOString().slice(0, 10);

  const [supplierId, setSupplierId] = useState(suppliers[0]?.id ?? "");
  const [poDate, setPoDate] = useState(today);
  const [notes, setNotes] = useState("");
  const [rows, setRows] = useState<ItemRow[]>([emptyRow(rawMaterials[0]?.id ?? "")]);
  const [showAddSupplier, setShowAddSupplier] = useState(false);
  const [newSupplierName, setNewSupplierName] = useState("");
  const [newSupplierPhone, setNewSupplierPhone] = useState("");
  const [formError, setFormError] = useState("");
  const [submitting, setSubmitting] = useState(false);

  if (!open) return null;

  const resetAndClose = () => {
    setSupplierId(suppliers[0]?.id ?? "");
    setPoDate(today);
    setNotes("");
    setRows([emptyRow(rawMaterials[0]?.id ?? "")]);
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

  const handleInlineAddSupplier = async () => {
    if (!newSupplierName.trim() || !newSupplierPhone.trim()) return;
    try {
      const id = await addSupplier({ name: newSupplierName.trim(), phone: newSupplierPhone.trim() });
      setSupplierId(id);
      setNewSupplierName("");
      setNewSupplierPhone("");
      setShowAddSupplier(false);
      toast.success(`Supplier "${newSupplierName.trim()}" added`);
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Failed to add supplier");
    }
  };

  const runningTotal = rows.reduce(
    (sum, r) => sum + (Number(r.qty) || 0) * (Number(r.expectedUnitCost) || 0),
    0
  );

  const handleSubmit = async () => {
    setFormError("");

    if (!supplierId) {
      setFormError("Select or add a supplier");
      return;
    }
    if (!poDate) {
      setFormError("PO date is required");
      return;
    }

    const parsedItems: { rawMaterialId: string; qty: number; expectedUnitCost: number }[] = [];
    for (const row of rows) {
      const qty = Number(row.qty);
      const expectedUnitCost = Number(row.expectedUnitCost);
      if (!row.rawMaterialId) {
        setFormError("Select a raw material for every line");
        return;
      }
      if (!qty || qty <= 0) {
        setFormError("Every line needs a quantity greater than 0");
        return;
      }
      if (!expectedUnitCost || expectedUnitCost <= 0) {
        setFormError("Every line needs an expected unit cost greater than 0");
        return;
      }
      parsedItems.push({ rawMaterialId: row.rawMaterialId, qty, expectedUnitCost });
    }

    setSubmitting(true);
    try {
      const poNumber = await createPurchaseOrder({
        supplierId,
        poDate,
        notes: notes.trim() || undefined,
        items: parsedItems,
      });
      toast.success(`Purchase Order ${poNumber} created`);
      resetAndClose();
    } catch (err) {
      setFormError(err instanceof Error ? err.message : "Failed to create purchase order");
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
      <div className="w-full max-w-2xl rounded-2xl border border-[var(--surface-border)] bg-[var(--background)] p-6 max-h-[90vh] overflow-y-auto">
        <div className="flex items-center justify-between">
          <h2 className="text-lg font-semibold text-[var(--foreground)]">New Purchase Order</h2>
          <button
            type="button"
            onClick={resetAndClose}
            className="rounded-lg px-2 py-1 text-sm text-[var(--text-muted)] hover:bg-[var(--surface-hover)]"
          >
            Close
          </button>
        </div>

        <div className="mt-4 grid grid-cols-1 gap-4 sm:grid-cols-2">
          <div>
            <label className="text-xs text-[var(--text-muted)]">Supplier</label>
            <div className="mt-1 flex gap-2">
              <select
                value={supplierId}
                onChange={(e) => setSupplierId(e.target.value)}
                className="block w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]"
              >
                <option value="">Select supplier</option>
                {suppliers.map((s) => (
                  <option key={s.id} value={s.id}>{s.name}</option>
                ))}
              </select>
              <button
                type="button"
                onClick={() => setShowAddSupplier((v) => !v)}
                className="shrink-0 rounded-lg border border-[var(--surface-border)] px-3 py-2 text-xs text-[var(--text-secondary)] hover:bg-[var(--surface-hover)]"
              >
                + New
              </button>
            </div>
          </div>
          <div>
            <label className="text-xs text-[var(--text-muted)]">PO Date</label>
            <input
              value={poDate}
              onChange={(e) => setPoDate(e.target.value)}
              type="date"
              className="mt-1 block w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]"
            />
          </div>
        </div>

        {showAddSupplier && (
          <div className="mt-3 flex flex-wrap items-end gap-2 rounded-lg border border-[var(--surface-border)] p-3">
            <div>
              <label className="text-xs text-[var(--text-muted)]">New supplier name</label>
              <input
                value={newSupplierName}
                onChange={(e) => setNewSupplierName(e.target.value)}
                className="mt-1 block rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]"
              />
            </div>
            <div>
              <label className="text-xs text-[var(--text-muted)]">Phone</label>
              <input
                value={newSupplierPhone}
                onChange={(e) => setNewSupplierPhone(e.target.value)}
                className="mt-1 block rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]"
              />
            </div>
            <button
              type="button"
              onClick={handleInlineAddSupplier}
              className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-3 py-2 text-xs font-medium text-neutral-50 dark:text-neutral-950 hover:opacity-90"
            >
              Add supplier
            </button>
          </div>
        )}

        <div className="mt-4">
          <label className="text-xs text-[var(--text-muted)]">Notes (optional)</label>
          <input
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
            placeholder="e.g. urgent, deliver by Friday"
            className="mt-1 block w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]"
          />
        </div>

        <div className="mt-5">
          <div className="flex items-center justify-between">
            <label className="text-xs text-[var(--text-muted)]">Items</label>
            <button
              type="button"
              onClick={addRow}
              className="rounded-lg px-2 py-1 text-xs text-[var(--text-secondary)] hover:bg-[var(--surface-hover)]"
            >
              + Add line
            </button>
          </div>

          <div className="mt-2 space-y-2">
            {rows.map((row) => (
              <div key={row.id} className="flex flex-wrap items-end gap-2 rounded-lg border border-[var(--surface-border)] p-3">
                <div className="min-w-[180px] flex-1">
                  <label className="text-xs text-[var(--text-muted)]">Raw material</label>
                  <select
                    value={row.rawMaterialId}
                    onChange={(e) => updateRow(row.id, { rawMaterialId: e.target.value })}
                    className="mt-1 block w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]"
                  >
                    <option value="">Select material</option>
                    {rawMaterials.map((m) => (
                      <option key={m.id} value={m.id}>{m.name} ({m.unit})</option>
                    ))}
                  </select>
                </div>
                <div className="w-28">
                  <label className="text-xs text-[var(--text-muted)]">Qty ordered</label>
                  <input
                    value={row.qty}
                    onChange={(e) => updateRow(row.id, { qty: e.target.value })}
                    type="number"
                    className="mt-1 block w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]"
                  />
                </div>
                <div className="w-32">
                  <label className="text-xs text-[var(--text-muted)]">Expected cost/unit</label>
                  <input
                    value={row.expectedUnitCost}
                    onChange={(e) => updateRow(row.id, { expectedUnitCost: e.target.value })}
                    type="number"
                    className="mt-1 block w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]"
                  />
                </div>
                <button
                  type="button"
                  onClick={() => removeRow(row.id)}
                  disabled={rows.length === 1}
                  className="rounded-lg px-2.5 py-2 text-xs text-red-500 hover:bg-red-500/10 disabled:opacity-40"
                >
                  Remove
                </button>
              </div>
            ))}
          </div>

          <div className="mt-2 text-right text-sm text-[var(--text-secondary)]">
            Estimated total: Rs. {runningTotal.toLocaleString()}
          </div>
        </div>

        {formError && <div className="mt-3 text-sm text-red-500">{formError}</div>}

        <div className="mt-5 flex justify-end gap-2">
          <button
            type="button"
            onClick={resetAndClose}
            className="rounded-lg px-3 py-2 text-sm text-[var(--text-secondary)] hover:bg-[var(--surface-hover)]"
          >
            Cancel
          </button>
          <button
            type="button"
            disabled={submitting}
            onClick={handleSubmit}
            className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-50 dark:text-neutral-950 hover:opacity-90 disabled:opacity-50"
          >
            {submitting ? "Creating..." : "Create Purchase Order"}
          </button>
        </div>
      </div>
    </div>
  );
}