<#
  fix-danger-zone-theme-and-loading.ps1
  ------------------------------------------------------------------
  Run this from the project ROOT:
    D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods

  ISSUES FIXED:
    1. The "Danger Zone" panel on Settings -> Export & Data used
       colors (red-900, red-950/20, text-red-300/80, etc.) that were
       only tuned for dark theme. In LIGHT theme this produced very
       low-contrast pale-pink-on-pale-pink text that's hard to read.
       Fix adds proper light-mode red shades alongside dark: variants
       so it looks correct in both themes.

    2. While deleting all data, the UI only showed a plain
       "Deleting..." label on the button - no loading animation.
       Fix adds a full-screen overlay using the existing
       LottieLoader component (public/loading/loading.json), matching
       the same loader already used elsewhere in the app (e.g.
       NavigationLoadingOverlay), while the delete request is in
       flight.

  SAFETY:
    The file is backed up to <file>.bak-<timestamp> before being
    fully replaced with a corrected version.
------------------------------------------------------------------#>

$ErrorActionPreference = "Stop"
$root = Get-Location
$ts = Get-Date -Format "yyyyMMdd-HHmmss"

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  Fix: Danger Zone light-theme contrast + delete loader" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Root: $root`n"

function Backup-File($path) {
    if (Test-Path -LiteralPath $path) {
        $bak = "$path.bak-$ts"
        Copy-Item -LiteralPath $path -Destination $bak -Force
        Write-Host "  Backed up -> $bak" -ForegroundColor DarkGray
    }
}

$dangerZonePath = Join-Path $root "apps\frontend\components\ui\danger-zone-panel.tsx"

Write-Host "`n[1/1] apps/frontend/components/ui/danger-zone-panel.tsx"

if (-not (Test-Path -LiteralPath $dangerZonePath)) {
    Write-Warning "SKIP: file not found -> $dangerZonePath"
} else {
    Backup-File $dangerZonePath

    $newContent = @'
"use client";

import { useState } from "react";
import { toast } from "@/components/ui/toast";
import { createClient } from "@/lib/supabase/client";
import { LottieLoader } from "@/components/ui/lottie-loader";

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
    <>
      <div className="rounded-xl border border-red-300 dark:border-red-900 bg-red-50 dark:bg-red-950/20 p-5 space-y-3">
        <div>
          <h2 className="text-lg font-semibold text-red-700 dark:text-red-400">Danger Zone</h2>
          <p className="text-xs text-red-700/80 dark:text-red-300/80 mt-1">
            Permanently deletes all business data (raw materials, receipts, batches, customers,
            invoices, payments, packaging, cartons). Your admin login is never affected. A backup
            file is generated and downloaded automatically before deletion.
          </p>
        </div>
        <button
          type="button"
          onClick={() => setModalOpen(true)}
          className="rounded-lg border border-red-300 bg-red-100 text-red-700 hover:bg-red-200 dark:border-red-800 dark:bg-red-950/40 dark:text-red-400 dark:hover:bg-red-950/70 px-4 py-2 text-sm font-medium transition-colors"
        >
          Delete All Data
        </button>

        {modalOpen && (
          <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4">
            <div className="w-full max-w-sm rounded-xl border border-red-300 dark:border-red-900 bg-[var(--surface)] p-5 space-y-4">
              <h3 className="text-base font-semibold text-red-700 dark:text-red-400">Confirm permanent deletion</h3>
              <p className="text-xs text-[var(--text-secondary)]">
                This cannot be undone. Type <span className="font-mono font-semibold">{CONFIRMATION_PHRASE}</span> to
                confirm.
              </p>
              <input
                value={confirmText}
                onChange={(e) => setConfirmText(e.target.value)}
                placeholder={CONFIRMATION_PHRASE}
                className="w-full rounded-lg border border-red-300 dark:border-red-900 bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-red-500 dark:focus:border-red-700"
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
                  disabled={isDeleting}
                  className="rounded-lg px-4 py-2 text-sm text-[var(--text-secondary)] hover:bg-[var(--surface-hover)] disabled:opacity-50"
                >
                  Cancel
                </button>
                <button
                  type="button"
                  disabled={!canConfirm}
                  onClick={handleDelete}
                  className="rounded-lg bg-red-600 dark:bg-red-800 px-4 py-2 text-sm font-medium text-white hover:bg-red-700 transition-colors disabled:opacity-50"
                >
                  {isDeleting ? "Deleting..." : "Delete Everything"}
                </button>
              </div>
            </div>
          </div>
        )}
      </div>

      {isDeleting && (
        <div className="fixed inset-0 z-[100] flex flex-col items-center justify-center bg-[var(--background)]/80 backdrop-blur-sm">
          <LottieLoader src="/loading/loading.json" size={140} />
          <p className="text-sm text-[var(--text-muted)] mt-2">
            Backing up and deleting all data - please wait...
          </p>
        </div>
      )}
    </>
  );
}

export default DangerZonePanel;
'@

    Set-Content -LiteralPath $dangerZonePath -Value $newContent -NoNewline -Encoding UTF8
    Write-Host "  OK   [danger-zone-panel.tsx: light/dark contrast fixed + Lottie loader added]" -ForegroundColor Green
}

Write-Host "`n==================================================" -ForegroundColor Cyan
Write-Host "  DONE" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host @"

Next steps:
  1. cd apps\frontend
  2. npm run build   (or just refresh dev server)
  3. Visit /settings?tab=export in LIGHT theme and confirm the
     "Danger Zone" panel now has clearly readable red text on a
     light red background (not washed-out pink-on-pink).
  4. Confirm it still looks correct in DARK theme too (unchanged).
  5. Trigger a delete (on a test dataset!) and confirm the Lottie
     loading animation (loading.json) now shows full-screen while
     the backup + delete request is in progress.

If anything looks off, the original file is backed up right next to
it as danger-zone-panel.tsx.bak-$ts
"@ -ForegroundColor Yellow