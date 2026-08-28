"use client";

import { useState } from "react";
import { toast } from "@/components/ui/toast";
import { useStore } from "@/lib/store";

export function ContraTransferDialog({ open, onClose }: { open: boolean; onClose: () => void }) {
  const treasuryAccounts = useStore((s) => s.treasuryAccounts);
  const createContraTransfer = useStore((s) => s.createContraTransfer);
  const [fromAccount, setFromAccount] = useState<"Bank" | "Cash">("Cash");
  const [amount, setAmount] = useState("");
  const [note, setNote] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [formError, setFormError] = useState("");

  if (!open) return null;

  const toAccount: "Bank" | "Cash" = fromAccount === "Bank" ? "Cash" : "Bank";
  const fromBalance = treasuryAccounts.find((a) => a.name === fromAccount)?.balance ?? 0;

  const resetAndClose = () => {
    setAmount("");
    setNote("");
    setFormError("");
    onClose();
  };

  const handleSubmit = async () => {
    setFormError("");
    const amt = Number(amount);
    if (!amt || amt <= 0) {
      setFormError("Enter a valid amount");
      return;
    }
    if (amt > fromBalance) {
      setFormError(`Cannot transfer more than the ${fromAccount} balance (Rs. ${fromBalance.toLocaleString()})`);
      return;
    }
    setSubmitting(true);
    try {
      await createContraTransfer({ fromAccount, toAccount, amount: amt, note: note.trim() || undefined });
      toast.success(`Rs. ${amt.toLocaleString()} moved from ${fromAccount} to ${toAccount}`);
      resetAndClose();
    } catch (err) {
      setFormError(err instanceof Error ? err.message : "Failed to create contra transfer");
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-3 sm:p-4">
      <div className="w-full max-w-sm rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-5 space-y-4 max-h-[90vh] overflow-y-auto">
        <h2 className="text-lg font-semibold text-[var(--foreground)]">Contra Transfer (Bank &harr; Cash)</h2>

        <div>
          <label className="text-sm text-[var(--text-muted)]">From</label>
          <div className="mt-1 grid grid-cols-2 gap-2">
            <button
              type="button"
              onClick={() => setFromAccount("Cash")}
              className={`rounded-lg border px-3 py-2 text-xs font-medium transition-colors ${
                fromAccount === "Cash"
                  ? "border-[var(--surface-border-strong)] bg-[var(--surface-hover)] text-[var(--foreground)]"
                  : "border-[var(--surface-border)] text-[var(--text-secondary)] hover:bg-[var(--surface-hover)]"
              }`}
            >
              Cash
            </button>
            <button
              type="button"
              onClick={() => setFromAccount("Bank")}
              className={`rounded-lg border px-3 py-2 text-xs font-medium transition-colors ${
                fromAccount === "Bank"
                  ? "border-[var(--surface-border-strong)] bg-[var(--surface-hover)] text-[var(--foreground)]"
                  : "border-[var(--surface-border)] text-[var(--text-secondary)] hover:bg-[var(--surface-hover)]"
              }`}
            >
              Bank
            </button>
          </div>
          <p className="text-xs text-[var(--text-muted)] mt-1">Available: Rs. {fromBalance.toLocaleString()}</p>
        </div>

        <div className="text-sm text-[var(--text-muted)]">
          To: <span className="text-[var(--foreground)] font-medium">{toAccount}</span>
        </div>

        <div>
          <label className="text-sm text-[var(--text-muted)]">Amount</label>
          <input
            type="number"
            min={0}
            step="any"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]"
          />
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
            {submitting ? "Saving..." : "Transfer"}
          </button>
        </div>
      </div>
    </div>
  );
}