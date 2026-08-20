"use client";

import { useState } from "react";
import { toast } from "@/components/ui/toast";
import { createClient } from "@/lib/supabase/client";

const CONFIRMATION_PHRASE = "DELETE ALL DATA";

export function DangerZonePanel() {
  const [modalOpen, setModalOpen] = useState(false);
  const [confirmText, setConfirmText] = useState("");
  const [acknowledged, setAcknowledged] = useState(false);
  const [isDeleting, setIsDeleting] = useState(false);

  const canConfirm = confirmText === CONFIRMATION_PHRASE && acknowledged && !isDeleting;

  const closeModal = () => {
    setModalOpen(false);
    setConfirmText("");
    setAcknowledged(false);
  };

  const handleDelete = async () => {
    if (!canConfirm) return;
    setIsDeleting(true);
    try {
      const supabase = createClient();
      const { data: sessionData } = await supabase.auth.getSession();
      const accessToken = sessionData.session?.access_token;

      const res = await fetch(
        `${process.env.NEXT_PUBLIC_SUPABASE_URL}/functions/v1/data-delete`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${accessToken}`,
          },
          body: JSON.stringify({ confirmationText: confirmText }),
        },
      );

      const json = await res.json();
      if (!res.ok) throw new Error(json.error ?? "Delete failed");

      // Offer the backup download
      const a = document.createElement("a");
      a.href = json.backupUrl;
      a.download = "";
      document.body.appendChild(a);
      a.click();
      a.remove();

      const totalDeleted = Object.values(json.deleted as Record<string, number>).reduce(
        (sum, n) => sum + n,
        0,
      );
      toast.success(`Deleted ${totalDeleted} records. A backup was downloaded.`);
      closeModal();
      // Reload so the app reflects the now-empty state
      window.location.reload();
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Failed to delete data");
    } finally {
      setIsDeleting(false);
    }
  };

  return (
    <div className="rounded-xl border border-red-900 bg-red-950/20 p-5 space-y-3">
      <div>
        <h2 className="text-lg font-semibold text-red-400">Danger Zone</h2>
        <p className="text-xs text-red-300/80 mt-1">
          Permanently deletes all business data (raw materials, receipts, batches, customers,
          invoices, payments, packaging, cartons). Your admin login is never affected. A backup
          file is generated and downloaded automatically before deletion.
        </p>
      </div>
      <button
        type="button"
        onClick={() => setModalOpen(true)}
        className="rounded-lg border border-red-800 bg-red-950/40 px-4 py-2 text-sm font-medium text-red-400 hover:bg-red-950/70 transition-colors"
      >
        Delete All Data
      </button>

      {modalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4">
          <div className="w-full max-w-sm rounded-xl border border-red-900 bg-[var(--surface)] p-5 space-y-4">
            <h3 className="text-base font-semibold text-red-400">Confirm permanent deletion</h3>
            <p className="text-xs text-[var(--text-secondary)]">
              This cannot be undone. Type <span className="font-mono font-semibold">{CONFIRMATION_PHRASE}</span> to
              confirm.
            </p>
            <input
              value={confirmText}
              onChange={(e) => setConfirmText(e.target.value)}
              placeholder={CONFIRMATION_PHRASE}
              className="w-full rounded-lg border border-red-900 bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-red-700"
            />
            <label className="flex items-start gap-2 text-xs text-[var(--text-secondary)]">
              <input
                type="checkbox"
                checked={acknowledged}
                onChange={(e) => setAcknowledged(e.target.checked)}
                className="mt-0.5"
              />
              I understand this permanently deletes all business data and cannot be undone.
            </label>
            <div className="flex justify-end gap-2 pt-2">
              <button
                type="button"
                onClick={closeModal}
                className="rounded-lg px-4 py-2 text-sm text-[var(--text-secondary)] hover:bg-[var(--surface-hover)]"
              >
                Cancel
              </button>
              <button
                type="button"
                disabled={!canConfirm}
                onClick={handleDelete}
                className="rounded-lg bg-red-800 px-4 py-2 text-sm font-medium text-white hover:bg-red-700 transition-colors disabled:opacity-50"
              >
                {isDeleting ? "Deleting..." : "Delete Everything"}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export default DangerZonePanel;
