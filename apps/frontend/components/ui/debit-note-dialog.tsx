"use client";

import { useState } from "react";
import { toast } from "@/components/ui/toast";
import { useStore } from "@/lib/store";

export type DebitNoteLineItem = {
  id: string;
  rawMaterialId: string;
  materialName: string;
  unit: string;
  qty: number;
  cost: number;
};

export function DebitNoteDialog({
  open,
  onClose,
  supplierId,
  receiptId,
  items,
}: {
  open: boolean;
  onClose: () => void;
  supplierId: string;
  receiptId?: string;
  items: DebitNoteLineItem[];
}) {
  const createDebitNote = useStore((s) => s.createDebitNote);
  const [qtyById, setQtyById] = useState<Record<string, string>>({});
  const [note, setNote] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [formError, setFormError] = useState("");

  if (!open) return null;

  const resetAndClose = () => {
    setQtyById({});
    setNote("");
    setFormError("");
    onClose();
  };

  const handleSubmit = async () => {
    setFormError("");

    const lines = items
      .map((it) => ({
        rawMaterialId: it.rawMaterialId,
        qty: Number(qtyById[it.id] || 0),
        cost: it.cost,
      }))
      .filter((l) => l.qty > 0);

    if (lines.length === 0) {
      setFormError("Enter a return quantity for at least one item");
      return;
    }
    for (const it of items) {
      const q = Number(qtyById[it.id] || 0);
      if (q > it.qty) {
        setFormError(`Cannot return more than ${it.qty} ${it.unit} of "${it.materialName}"`);
        return;
      }
    }

    setSubmitting(true);
    try {
      await createDebitNote({
        supplierId,
        receiptId,
        lines,
        note: note.trim() || undefined,
      });
      toast.success("Debit note created");
      resetAndClose();
    } catch (err) {
      setFormError(err instanceof Error ? err.message : "Failed to create debit note");
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-3 sm:p-4">
      <div className="w-full max-w-lg rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-5 space-y-4 max-h-[90vh] overflow-y-auto">
        <h2 className="text-lg font-semibold text-[var(--foreground)]">Debit Note (Purchase Return)</h2>

        <div className="space-y-2">
          {items.map((it) => (
            <div key={it.id} className="flex items-center gap-3 rounded-lg border border-[var(--surface-border)] p-3">
              <div className="flex-1">
                <div className="text-sm text-[var(--foreground)]">{it.materialName}</div>
                <div className="text-xs text-[var(--text-muted)]">
                  Received: {it.qty} {it.unit} @ Rs. {it.cost.toLocaleString()}
                </div>
              </div>
              <div className="w-24">
                <label className="text-xs text-[var(--text-muted)]">Return qty</label>
                <input
                  type="number"
                  min={0}
                  max={it.qty}
                  value={qtyById[it.id] ?? ""}
                  onChange={(e) => setQtyById((prev) => ({ ...prev, [it.id]: e.target.value }))}
                  className="mt-1 block w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-2 py-1.5 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]"
                />
              </div>
            </div>
          ))}
          {items.length === 0 && (
            <p className="text-sm text-[var(--text-faint)]">This receipt has no line items to return.</p>
          )}
        </div>

        <div>
          <label className="text-sm text-[var(--text-muted)]">Note (optional)</label>
          <input
            value={note}
            onChange={(e) => setNote(e.target.value)}
            className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]"
          />
        </div>

        {formError && <div className="text-sm text-red-500">{formError}</div>}

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
            disabled={submitting}
            onClick={handleSubmit}
            className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-50 dark:text-neutral-950 hover:opacity-90 disabled:opacity-50"
          >
            {submitting ? "Saving..." : "Create Debit Note"}
          </button>
        </div>
      </div>
    </div>
  );
}