"use client";

import { useEffect, useState } from "react";
import { toast } from "@/components/ui/toast";
import { useStore } from "@/lib/store";

// Supplier Payment dialog (Step D3). Locked to a single supplier (no
// supplier picker - opened from the supplier detail page). Records a
// payment OUT to the supplier via store.recordSupplierPayment, which
// reduces supplier.currentBalance and moves money out of the chosen
// treasury account (Bank or Cash). See supplier-payments edge function.
export function SupplierPaymentDialog({
  open,
  onClose,
  supplierId,
  supplierName,
  currentBalance,
}: {
  open: boolean;
  onClose: () => void;
  supplierId: string;
  supplierName: string;
  currentBalance: number;
}) {
  const recordSupplierPayment = useStore((s) => s.recordSupplierPayment);

  const [amount, setAmount] = useState("");
  const [method, setMethod] = useState<"bank" | "cash">("cash");
  const [note, setNote] = useState("");
  const [formError, setFormError] = useState("");
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    if (open) {
      setAmount("");
      setMethod("cash");
      setNote("");
      setFormError("");
    }
  }, [open]);

  if (!open) return null;

  const resetAndClose = () => {
    setAmount("");
    setMethod("cash");
    setNote("");
    setFormError("");
    onClose();
  };

  const handleSubmit = async () => {
    setFormError("");

    const parsedAmount = Number(amount);
    if (!parsedAmount || parsedAmount <= 0) {
      setFormError("Enter an amount greater than 0");
      return;
    }

    setSubmitting(true);
    try {
      await recordSupplierPayment(supplierId, parsedAmount, method, note.trim());
      toast.success(`Payment of Rs. ${parsedAmount.toLocaleString()} recorded for ${supplierName}`);
      resetAndClose();
    } catch (err) {
      setFormError(err instanceof Error ? err.message : "Failed to record payment");
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
      <div className="w-full max-w-md rounded-2xl border border-[var(--surface-border)] bg-[var(--background)] p-6 max-h-[90vh] overflow-y-auto">
        <div className="flex items-center justify-between">
          <h2 className="text-lg font-semibold text-[var(--foreground)]">Record Supplier Payment</h2>
          <button
            type="button"
            onClick={resetAndClose}
            className="rounded-lg px-2 py-1 text-sm text-[var(--text-muted)] hover:bg-[var(--surface-hover)]"
          >
            Close
          </button>
        </div>

        <div className="mt-3 rounded-lg border border-[var(--surface-border)] bg-[var(--surface)] px-3 py-2">
          <div className="text-xs text-[var(--text-muted)]">Paying</div>
          <div className="text-sm font-medium text-[var(--foreground)]">{supplierName}</div>
          <div className="text-xs text-[var(--text-muted)] mt-1">
            Current outstanding balance: <span className="text-[var(--text-secondary)]">Rs. {currentBalance.toLocaleString()}</span>
          </div>
        </div>

        <div className="mt-4 grid grid-cols-1 gap-4 sm:grid-cols-2">
          <div>
            <label className="text-xs text-[var(--text-muted)]">Amount</label>
            <input
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              type="number"
              placeholder="0"
              className="mt-1 block w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]"
            />
          </div>
          <div>
            <label className="text-xs text-[var(--text-muted)]">Method</label>
            <select
              value={method}
              onChange={(e) => setMethod(e.target.value as "bank" | "cash")}
              className="mt-1 block w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]"
            >
              <option value="cash">Cash</option>
              <option value="bank">Bank</option>
            </select>
          </div>
        </div>

        <div className="mt-4">
          <label className="text-xs text-[var(--text-muted)]">Note (optional)</label>
          <input
            value={note}
            onChange={(e) => setNote(e.target.value)}
            placeholder="e.g. partial payment against August receipts"
            className="mt-1 block w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]"
          />
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
            {submitting ? "Recording..." : "Record Payment"}
          </button>
        </div>
      </div>
    </div>
  );
}