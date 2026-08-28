<#
step-d3-supplier-payment-dialog.ps1

Step D3: Supplier Payment dialog.

What this does:
  1. Creates apps\frontend\components\ui\supplier-payment-dialog.tsx
     (new file - a locked-supplier payment dialog, same visual pattern as
     purchase-order-dialog.tsx: Bank/Cash method, amount, optional note,
     calls store.recordSupplierPayment).
  2. Overwrites apps\frontend\app\(dashboard)\suppliers\[id]\page.tsx to:
       - add a "Record Payment" button next to "Record Purchase"
       - add an "Outstanding Balance" stat (supplier.currentBalance)
       - add an "Account Ledger" table (supplierLedgerEntries for this
         supplier) - date / type / direction / amount / running balance / note
       - render <SupplierPaymentDialog />

Backs up any file it overwrites as <file>.bak-<timestamp>.
Run this from the repo root:
  D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods
#>

$ErrorActionPreference = "Stop"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

function Backup-IfExists($relPath) {
    if (Test-Path -LiteralPath $relPath) {
        $full = (Resolve-Path -LiteralPath $relPath).Path
        $backupFull = "$full.bak-$timestamp"
        Copy-Item -LiteralPath $full -Destination $backupFull -Force
        Write-Host "  Backed up: $relPath -> $(Split-Path -Leaf $backupFull)"
        return $true
    }
    return $false
}

function Write-TextFile($relPath, [string]$content) {
    $dir = Split-Path -Parent $relPath
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    if (-not (Test-Path -LiteralPath $relPath)) {
        New-Item -ItemType File -Path $relPath -Force | Out-Null
    }
    $fullPath = (Resolve-Path -LiteralPath $relPath).Path
    [System.IO.File]::WriteAllText($fullPath, $content)
}

Write-Host ""
Write-Host "=== STEP D3: Supplier Payment Dialog ===" -ForegroundColor Cyan
Write-Host ""

# -----------------------------------------------------------------------
# 1. New file: supplier-payment-dialog.tsx
# -----------------------------------------------------------------------

$dialogPath = "apps\frontend\components\ui\supplier-payment-dialog.tsx"
Write-Host "Step 1: Creating $dialogPath"
Backup-IfExists $dialogPath | Out-Null

$dialogContent = @'
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
'@

Write-TextFile $dialogPath $dialogContent
Write-Host "  Created: $dialogPath" -ForegroundColor Green
Write-Host ""

# -----------------------------------------------------------------------
# 2. Overwrite suppliers/[id]/page.tsx
# -----------------------------------------------------------------------

$pagePath = "apps\frontend\app\(dashboard)\suppliers\[id]\page.tsx"
Write-Host "Step 2: Updating $pagePath"
Backup-IfExists $pagePath | Out-Null

$pageContent = @'
"use client";

import { Fragment, use, useEffect, useMemo, useState } from "react";
import { NavLink } from "@/components/ui/nav-link";
import { ChevronDown, ChevronRight } from "lucide-react";
import { useStore } from "@/lib/store";
import { PurchaseReceiptDialog } from "@/components/ui/purchase-receipt-dialog";
import { SupplierPaymentDialog } from "@/components/ui/supplier-payment-dialog";

export default function SupplierDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const supplier = useStore((s) => s.suppliers.find((sup) => sup.id === id));
  const allReceipts = useStore((s) => s.receipts);
  const receiptLines = useStore((s) => s.receiptLines);
  const rawMaterials = useStore((s) => s.rawMaterials);
  const allSupplierLedgerEntries = useStore((s) => s.supplierLedgerEntries);
  const loadRawMaterialsModule = useStore((s) => s.loadRawMaterialsModule);
  const [expandedReceiptId, setExpandedReceiptId] = useState<string | null>(null);
  const [dialogOpen, setDialogOpen] = useState(false);
  const [paymentDialogOpen, setPaymentDialogOpen] = useState(false);

  useEffect(() => {
    loadRawMaterialsModule();
  }, [loadRawMaterialsModule]);

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

  const ledgerEntries = useMemo(
    () =>
      allSupplierLedgerEntries
        .filter((e) => e.supplierId === id)
        .sort((a, b) => b.date.localeCompare(a.date)),
    [allSupplierLedgerEntries, id]
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
          <div>
            <div className="text-[var(--text-muted)] text-xs">Outstanding Balance</div>
            <div className="text-lg font-semibold text-[var(--foreground)] mt-1">Rs. {supplier.currentBalance.toLocaleString()}</div>
          </div>
        </div>
      </div>

      <div className="flex items-center justify-between">
        <h2 className="text-lg font-semibold text-[var(--foreground)]">Purchase History</h2>
        <div className="flex items-center gap-2">
          <button onClick={() => setPaymentDialogOpen(true)} className="rounded-lg border border-[var(--surface-border)] px-4 py-2 text-sm font-medium text-[var(--text-secondary)] hover:bg-[var(--surface-hover)] transition-colors">
            Record Payment
          </button>
          <button onClick={() => setDialogOpen(true)} className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-50 dark:text-neutral-950 hover:opacity-90 transition-opacity">
            + Record Purchase
          </button>
        </div>
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

      <h2 className="text-lg font-semibold text-[var(--foreground)]">Account Ledger</h2>

      <div className="overflow-x-auto rounded-xl border border-[var(--surface-border)]">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-[var(--surface-border)] bg-[var(--surface)] text-left text-[var(--text-muted)]">
              <th className="px-4 py-3 font-medium">Date</th>
              <th className="px-4 py-3 font-medium">Type</th>
              <th className="px-4 py-3 font-medium">Direction</th>
              <th className="px-4 py-3 font-medium">Amount</th>
              <th className="px-4 py-3 font-medium">Running Balance</th>
              <th className="px-4 py-3 font-medium">Note</th>
            </tr>
          </thead>
          <tbody>
            {ledgerEntries.map((entry) => (
              <tr key={entry.id} className="border-b border-[var(--surface-border)] last:border-0 hover:bg-[var(--surface)]/60">
                <td className="px-4 py-3 text-[var(--text-secondary)]">{entry.date}</td>
                <td className="px-4 py-3 text-[var(--text-secondary)] capitalize">{entry.type.replace("_", " ")}</td>
                <td className="px-4 py-3 text-[var(--text-secondary)] capitalize">{entry.direction ?? "-"}</td>
                <td className="px-4 py-3 text-[var(--text-secondary)]">Rs. {entry.amount.toLocaleString()}</td>
                <td className="px-4 py-3 text-[var(--text-secondary)]">Rs. {entry.runningBalance.toLocaleString()}</td>
                <td className="px-4 py-3 text-[var(--text-muted)]">{entry.note ?? "-"}</td>
              </tr>
            ))}
            {ledgerEntries.length === 0 && (
              <tr><td colSpan={6} className="px-4 py-8 text-center text-[var(--text-faint)]">No ledger entries yet for this supplier.</td></tr>
            )}
          </tbody>
        </table>
      </div>

      <PurchaseReceiptDialog open={dialogOpen} onClose={() => setDialogOpen(false)} lockSupplierId={supplier.id} />
      <SupplierPaymentDialog
        open={paymentDialogOpen}
        onClose={() => setPaymentDialogOpen(false)}
        supplierId={supplier.id}
        supplierName={supplier.name}
        currentBalance={supplier.currentBalance}
      />
    </div>
  );
}
'@

Write-TextFile $pagePath $pageContent
Write-Host "  Updated: $pagePath" -ForegroundColor Green
Write-Host ""

Write-Host "=== STEP D3 COMPLETE ===" -ForegroundColor Green
Write-Host "Created:"
Write-Host "  - $dialogPath"
Write-Host "Updated:"
Write-Host "  - $pagePath  (Record Payment button, Outstanding Balance stat, Account Ledger table)"
Write-Host ""
Write-Host "NEXT: Run the frontend (npm run dev), open a supplier detail page," -ForegroundColor Cyan
Write-Host "click 'Record Payment', and confirm a payment posts correctly and" -ForegroundColor Cyan
Write-Host "the Outstanding Balance + Account Ledger update. Once confirmed," -ForegroundColor Cyan
Write-Host "say 'next' to move to Step D4 (Credit Note / Sales Return dialog)." -ForegroundColor Cyan