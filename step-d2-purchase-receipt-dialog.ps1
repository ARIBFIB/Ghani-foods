<#
Step D2 - Purchase Receipt Dialog -> PO-driven
Rewrites apps\frontend\components\ui\purchase-receipt-dialog.tsx so a
receipt can only be created against a selected, still-open Purchase Order
(matches store.ts's createPurchaseReceipt({ poId, supplierId, purchaseDate,
items }) and the purchaseOrders / purchaseOrderLines state shape).

Flow:
  1. User picks a PO (filtered to status draft/sent/partially_received,
     optionally pre-filtered by lockSupplierId).
  2. Dialog shows that PO's lines with remaining-to-receive qty
     (qtyOrdered - qtyReceived) and the expected unit cost as a default.
  3. User edits qty received / actual cost per line, sets purchase date,
     and submits -> store.createPurchaseReceipt({ poId, supplierId,
     purchaseDate, items }).

The old "Existing Material / + New Material" free-entry mode is removed:
migration 0009 requires every receipt to trace back to a PO line, so
inventing a brand-new raw material mid-receipt is no longer a supported
path here (that still happens via Purchase Order creation + raw-materials
page, not this dialog).

Run from repo root:
  .\step-d2-purchase-receipt-dialog.ps1
#>

$ErrorActionPreference = "Stop"

$target = "apps\frontend\components\ui\purchase-receipt-dialog.tsx"

if (-not (Test-Path $target)) {
    Write-Host "ERROR: $target not found. Run this script from the GhaniFoods repo root." -ForegroundColor Red
    exit 1
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backup = "$target.bak-$timestamp"
Copy-Item $target $backup
Write-Host "Backed up existing file -> $backup"

$content = @'
"use client";

import { useMemo, useState, useEffect } from "react";
import { toast } from "@/components/ui/toast";
import { useStore } from "@/lib/store";

type LineRow = {
  poLineId: string;
  rawMaterialId: string;
  rawMaterialName: string;
  unit: string;
  remainingQty: number;
  qty: string;
  cost: string;
};

// Purchase Receipt dialog (migration 0009: receipts are now PO-only).
// Step 1: pick an open Purchase Order (draft / sent / partially_received).
// Step 2: the PO's lines load with remaining-to-receive qty and the
// expected unit cost pre-filled; edit qty received / actual cost per line.
// Submits via store.createPurchaseReceipt({ poId, supplierId, purchaseDate, items }).
export function PurchaseReceiptDialog({
  open,
  onClose,
  lockSupplierId,
}: {
  open: boolean;
  onClose: () => void;
  lockSupplierId?: string;
}) {
  const suppliers = useStore((s) => s.suppliers);
  const rawMaterials = useStore((s) => s.rawMaterials);
  const purchaseOrders = useStore((s) => s.purchaseOrders);
  const purchaseOrderLines = useStore((s) => s.purchaseOrderLines);
  const createPurchaseReceipt = useStore((s) => s.createPurchaseReceipt);

  const today = new Date().toISOString().slice(0, 10);

  const openPOs = useMemo(
    () =>
      purchaseOrders
        .filter((po) => po.status === "draft" || po.status === "sent" || po.status === "partially_received")
        .filter((po) => !lockSupplierId || po.supplierId === lockSupplierId),
    [purchaseOrders, lockSupplierId]
  );

  const [poId, setPoId] = useState(openPOs[0]?.id ?? "");
  const [purchaseDate, setPurchaseDate] = useState(today);
  const [rows, setRows] = useState<LineRow[]>([]);
  const [formError, setFormError] = useState("");
  const [submitting, setSubmitting] = useState(false);

  const selectedPO = purchaseOrders.find((po) => po.id === poId);
  const supplierName = suppliers.find((s) => s.id === selectedPO?.supplierId)?.name ?? "";

  const rawMaterialById = useMemo(() => new Map(rawMaterials.map((m) => [m.id, m])), [rawMaterials]);

  // Rebuild the line rows whenever the selected PO changes.
  useEffect(() => {
    if (!poId) {
      setRows([]);
      return;
    }
    const lines = purchaseOrderLines.filter((l) => l.poId === poId);
    setRows(
      lines.map((l) => {
        const material = rawMaterialById.get(l.rawMaterialId);
        const remaining = Math.max(l.qtyOrdered - l.qtyReceived, 0);
        return {
          poLineId: l.id,
          rawMaterialId: l.rawMaterialId,
          rawMaterialName: material?.name ?? "Unknown material",
          unit: material?.unit ?? "",
          remainingQty: remaining,
          qty: remaining > 0 ? String(remaining) : "",
          cost: String(l.expectedUnitCost),
        };
      })
    );
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [poId, purchaseOrderLines, rawMaterialById]);

  if (!open) return null;

  const resetAndClose = () => {
    setPoId(openPOs[0]?.id ?? "");
    setPurchaseDate(today);
    setFormError("");
    onClose();
  };

  const updateRow = (poLineId: string, patch: Partial<LineRow>) =>
    setRows((prev) => prev.map((r) => (r.poLineId === poLineId ? { ...r, ...patch } : r)));

  const runningTotal = rows.reduce((sum, r) => sum + (Number(r.qty) || 0) * (Number(r.cost) || 0), 0);

  const handleSubmit = async () => {
    setFormError("");

    if (!selectedPO) {
      setFormError("Select a Purchase Order");
      return;
    }
    if (!purchaseDate) {
      setFormError("Purchase date is required");
      return;
    }
    if (rows.length === 0) {
      setFormError("This Purchase Order has no lines to receive");
      return;
    }

    const parsedItems: { rawMaterialId: string; qty: number; cost: number }[] = [];
    for (const row of rows) {
      const qty = Number(row.qty);
      const cost = Number(row.cost);
      if (!qty || qty <= 0) continue; // allow partial receipt: skip lines left blank/0
      if (qty > row.remainingQty) {
        setFormError(`${row.rawMaterialName}: cannot receive more than the remaining ${row.remainingQty} ${row.unit}`);
        return;
      }
      if (!cost || cost <= 0) {
        setFormError(`${row.rawMaterialName}: cost must be greater than 0`);
        return;
      }
      parsedItems.push({ rawMaterialId: row.rawMaterialId, qty, cost });
    }

    if (parsedItems.length === 0) {
      setFormError("Enter a quantity for at least one line");
      return;
    }

    setSubmitting(true);
    try {
      await createPurchaseReceipt({
        poId: selectedPO.id,
        supplierId: selectedPO.supplierId,
        purchaseDate,
        items: parsedItems,
      });
      toast.success(
        `Purchase receipt saved - ${parsedItems.length} item${parsedItems.length > 1 ? "s" : ""} from ${supplierName || "supplier"} (PO ${selectedPO.poNumber})`
      );
      resetAndClose();
    } catch (err) {
      setFormError(err instanceof Error ? err.message : "Failed to save purchase receipt");
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-3 sm:p-4">
      <div className="w-full max-w-lg rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-5 space-y-4 max-h-[90vh] overflow-y-auto">
        <h2 className="text-lg font-semibold text-[var(--foreground)]">New Purchase Receipt</h2>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <div>
            <label className="text-sm text-[var(--text-muted)]">Purchase Order</label>
            <select
              value={poId}
              onChange={(e) => setPoId(e.target.value)}
              className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]"
            >
              <option value="">Select an open PO...</option>
              {openPOs.map((po) => {
                const name = suppliers.find((s) => s.id === po.supplierId)?.name ?? "Unknown supplier";
                return (
                  <option key={po.id} value={po.id}>
                    {po.poNumber} - {name} ({po.status.replace("_", " ")})
                  </option>
                );
              })}
            </select>
            {openPOs.length === 0 && (
              <p className="text-xs text-[var(--text-muted)] mt-1">
                No open Purchase Orders{lockSupplierId ? " for this supplier" : ""}. Create one first.
              </p>
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

        {selectedPO && (
          <div className="rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-xs text-[var(--text-muted)]">
            Supplier: <span className="text-[var(--foreground)]">{supplierName}</span>
            {selectedPO.notes ? <> &middot; Notes: <span className="text-[var(--foreground)]">{selectedPO.notes}</span></> : null}
          </div>
        )}

        <div className="space-y-3">
          <h3 className="text-sm font-semibold text-[var(--foreground)]">Items to Receive</h3>

          {rows.length === 0 && (
            <p className="text-xs text-[var(--text-muted)]">Select a Purchase Order to load its line items.</p>
          )}

          {rows.map((row) => (
            <div key={row.poLineId} className="rounded-lg border border-[var(--surface-border)] p-3 space-y-2">
              <div className="flex items-center justify-between">
                <span className="text-sm font-medium text-[var(--foreground)]">{row.rawMaterialName}</span>
                <span className="text-xs text-[var(--text-muted)]">
                  Remaining: {row.remainingQty} {row.unit}
                </span>
              </div>
              <div className="grid grid-cols-2 gap-2">
                <input
                  value={row.qty}
                  onChange={(e) => updateRow(row.poLineId, { qty: e.target.value })}
                  type="number"
                  step="any"
                  placeholder={`Qty received (${row.unit})`}
                  className="rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]"
                />
                <input
                  value={row.cost}
                  onChange={(e) => updateRow(row.poLineId, { cost: e.target.value })}
                  type="number"
                  step="any"
                  placeholder="Actual cost per unit"
                  className="rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]"
                />
              </div>
              {row.remainingQty <= 0 && (
                <p className="text-xs text-amber-500">Already fully received - leave blank to skip this line.</p>
              )}
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
            disabled={submitting || !selectedPO}
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

Set-Content -Path $target -Value $content -NoNewline
Write-Host "Wrote: $target"

Write-Host ""
Write-Host "====================================================================" -ForegroundColor Cyan
Write-Host "STEP D2 COMPLETE (purchase-receipt-dialog.tsx)" -ForegroundColor Cyan
Write-Host "====================================================================" -ForegroundColor Cyan
Write-Host "Changed:"
Write-Host "  - Dialog now requires selecting an open Purchase Order first"
Write-Host "  - Line items auto-load from that PO (remaining qty + expected cost)"
Write-Host "  - Removed 'Existing Material / + New Material' free-entry mode"
Write-Host "    (no longer valid - every receipt must trace back to a PO line)"
Write-Host "  - Removed inline '+ Add Supplier' (supplier now comes from the PO)"
Write-Host "  - Calls store.createPurchaseReceipt({ poId, supplierId, purchaseDate, items })"
Write-Host ""
Write-Host "CHECK: any page that renders <PurchaseReceiptDialog lockRawMaterialId=... />" -ForegroundColor Yellow
Write-Host "(e.g. raw-materials/[id], raw-materials list row action) will now get a" -ForegroundColor Yellow
Write-Host "TS error since lockRawMaterialId was removed - that prop no longer makes" -ForegroundColor Yellow
Write-Host "sense when items come from a PO. Search usages:" -ForegroundColor Yellow
Write-Host "  git grep -n lockRawMaterialId" -ForegroundColor Yellow
Write-Host ""
Write-Host "NEXT (Step D3): build the Supplier Payment dialog (calls" -ForegroundColor Green
Write-Host "store.recordSupplierPayment) and wire it into the Suppliers detail page." -ForegroundColor Green
Write-Host "Say 'next' to generate that .ps1." -ForegroundColor Green