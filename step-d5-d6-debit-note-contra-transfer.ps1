<#
step-d5-d6-debit-note-contra-transfer.ps1

Purpose: Complete Step D5 (Debit Note / Purchase Return dialog) and
Step D6 (Contra Transfer / Bank <-> Cash dialog).

Also fixes a real bug found while building D6: store.ts's
createContraTransfer was posting { fromAccount, toAccount } with values
"Bank"/"Cash" to the contra-vouchers edge function, but that function
(and fn_create_contra_transfer) reads { fromMethod, toMethod } with
values "bank"/"cash" (lowercase). Every contra transfer would have
failed with a 400 until this is fixed. Same class of bug as the D4
itemId -> invoiceItemId mismatch.

Fixes applied to apps/frontend/lib/store.ts:
  1. createContraTransfer implementation: send fromMethod/toMethod
     (lowercased) instead of fromAccount/toAccount, matching what
     contra-vouchers/index.ts and fn_create_contra_transfer expect.
     Public function signature (fromAccount/toAccount as 'Bank'|'Cash')
     is unchanged, so nothing else needs to change.

New files created:
  apps/frontend/components/ui/debit-note-dialog.tsx
  apps/frontend/components/ui/contra-transfer-dialog.tsx

Edited:
  apps/frontend/app/(dashboard)/suppliers/[id]/page.tsx
    - imports DebitNoteDialog
    - adds "Debit Note (Return)" button inside each expanded receipt row
    - renders the dialog wired to that receipt's lines

  apps/frontend/app/(dashboard)/payments/page.tsx
    - imports ContraTransferDialog
    - adds "Contra Transfer" button next to "+ Record Payment"
    - renders the dialog

NOTE ON LINE ENDINGS: the edited/created files are normalized to LF
(\n) line endings by this script, regardless of the original file's
CRLF/LF mix, so the exact-match logic below is reliable no matter how
your editor last saved the file. This does not affect how the code
runs; if your diff tool shows "whole file changed" because of this,
that's just the line-ending normalization, not a functional change.

Run this from the repo root:
  D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods
#>

$ErrorActionPreference = "Stop"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

function Backup-File($path) {
    if (Test-Path -LiteralPath $path) {
        Copy-Item -LiteralPath $path -Destination "$path.bak-$timestamp" -Force
        Write-Host "Backed up: $path.bak-$timestamp" -ForegroundColor DarkGray
    }
}

function Read-Normalized($path) {
    $raw = [System.IO.File]::ReadAllText($path)
    return $raw -replace "`r`n", "`n"
}

function Replace-Exact($path, $old, $new, $label) {
    $content = Read-Normalized $path
    $oldN = $old -replace "`r`n", "`n"
    $newN = $new -replace "`r`n", "`n"
    if ($content.IndexOf($oldN) -lt 0) {
        throw "COULD NOT FIND expected block ($label) in $path. File may have changed since export - aborting so nothing is half-applied."
    }
    $count = ([regex]::Matches($content, [regex]::Escape($oldN))).Count
    if ($count -ne 1) {
        throw "Expected exactly 1 match for ($label) in $path but found $count. Aborting."
    }
    $content = $content.Replace($oldN, $newN)
    [System.IO.File]::WriteAllText($path, $content)
    Write-Host "Applied: $label" -ForegroundColor Green
}

$repoRoot = (Get-Location).Path
[System.IO.Directory]::SetCurrentDirectory($repoRoot)

$storePath = Join-Path $repoRoot "apps\frontend\lib\store.ts"
$supplierPagePath = Join-Path $repoRoot "apps\frontend\app\(dashboard)\suppliers\[id]\page.tsx"
$paymentsPagePath = Join-Path $repoRoot "apps\frontend\app\(dashboard)\payments\page.tsx"
$debitDialogPath = Join-Path $repoRoot "apps\frontend\components\ui\debit-note-dialog.tsx"
$contraDialogPath = Join-Path $repoRoot "apps\frontend\components\ui\contra-transfer-dialog.tsx"

foreach ($p in @($storePath, $supplierPagePath, $paymentsPagePath)) {
    if (-not (Test-Path -LiteralPath $p)) { throw "Not found: $p - run this from the repo root (GhaniFoods)." }
}

Backup-File $storePath
Backup-File $supplierPagePath
Backup-File $paymentsPagePath

# =====================================================================
# 1. store.ts - fix createContraTransfer field-name/casing mismatch
# =====================================================================
Replace-Exact $storePath @'
  createContraTransfer: async (input) => {
    const { error } = await supabase.functions.invoke("contra-vouchers", {
      body: {
        fromAccount: input.fromAccount,
        toAccount: input.toAccount,
        amount: input.amount,
        note: input.note ?? null,
      },
    });
'@ @'
  createContraTransfer: async (input) => {
    const { error } = await supabase.functions.invoke("contra-vouchers", {
      body: {
        fromMethod: input.fromAccount.toLowerCase(),
        toMethod: input.toAccount.toLowerCase(),
        amount: input.amount,
        note: input.note ?? null,
      },
    });
'@ "createContraTransfer: fromAccount/toAccount -> fromMethod/toMethod (lowercased)"

Write-Host ""
Write-Host "store.ts: contra transfer fix applied." -ForegroundColor Cyan

# =====================================================================
# 2. Create DebitNoteDialog component (D5)
# =====================================================================
$debitDialogContent = @'
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
'@

if (Test-Path -LiteralPath $debitDialogPath) { Backup-File $debitDialogPath }
$debitDialogDir = Split-Path -Parent $debitDialogPath
if (-not (Test-Path -LiteralPath $debitDialogDir)) { New-Item -ItemType Directory -Path $debitDialogDir -Force | Out-Null }
[System.IO.File]::WriteAllText($debitDialogPath, ($debitDialogContent -replace "`r`n", "`n"))
Write-Host "Created: $debitDialogPath" -ForegroundColor Green

# =====================================================================
# 3. Create ContraTransferDialog component (D6)
# =====================================================================
$contraDialogContent = @'
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
'@

if (Test-Path -LiteralPath $contraDialogPath) { Backup-File $contraDialogPath }
$contraDialogDir = Split-Path -Parent $contraDialogPath
if (-not (Test-Path -LiteralPath $contraDialogDir)) { New-Item -ItemType Directory -Path $contraDialogDir -Force | Out-Null }
[System.IO.File]::WriteAllText($contraDialogPath, ($contraDialogContent -replace "`r`n", "`n"))
Write-Host "Created: $contraDialogPath" -ForegroundColor Green

# =====================================================================
# 4. Wire DebitNoteDialog into supplier detail page (D5)
# =====================================================================

# 4a. import
Replace-Exact $supplierPagePath @'
import { PurchaseReceiptDialog } from "@/components/ui/purchase-receipt-dialog";
import { SupplierPaymentDialog } from "@/components/ui/supplier-payment-dialog";
'@ @'
import { PurchaseReceiptDialog } from "@/components/ui/purchase-receipt-dialog";
import { SupplierPaymentDialog } from "@/components/ui/supplier-payment-dialog";
import { DebitNoteDialog, type DebitNoteLineItem } from "@/components/ui/debit-note-dialog";
'@ "supplier page: import DebitNoteDialog"

# 4b. state
Replace-Exact $supplierPagePath @'
  const [expandedReceiptId, setExpandedReceiptId] = useState<string | null>(null);
  const [dialogOpen, setDialogOpen] = useState(false);
  const [paymentDialogOpen, setPaymentDialogOpen] = useState(false);
'@ @'
  const [expandedReceiptId, setExpandedReceiptId] = useState<string | null>(null);
  const [dialogOpen, setDialogOpen] = useState(false);
  const [paymentDialogOpen, setPaymentDialogOpen] = useState(false);
  const [debitNoteReceiptId, setDebitNoteReceiptId] = useState<string | null>(null);
'@ "supplier page: add debitNoteReceiptId state"

# 4c. derive debit-note line items for whichever receipt is active
Replace-Exact $supplierPagePath @'
  const ledgerEntries = useMemo(
    () =>
      allSupplierLedgerEntries
        .filter((e) => e.supplierId === id)
        .sort((a, b) => b.date.localeCompare(a.date)),
    [allSupplierLedgerEntries, id]
  );

  if (!supplier) {
'@ @'
  const ledgerEntries = useMemo(
    () =>
      allSupplierLedgerEntries
        .filter((e) => e.supplierId === id)
        .sort((a, b) => b.date.localeCompare(a.date)),
    [allSupplierLedgerEntries, id]
  );

  const debitNoteItems = useMemo<DebitNoteLineItem[]>(() => {
    if (!debitNoteReceiptId) return [];
    return receiptLines
      .filter((l) => l.receiptId === debitNoteReceiptId)
      .map((l) => {
        const material = rawMaterials.find((m) => m.id === l.rawMaterialId);
        return {
          id: l.id,
          rawMaterialId: l.rawMaterialId,
          materialName: material?.name ?? "Unknown material",
          unit: material?.unit ?? "",
          qty: l.qty,
          cost: l.cost,
        };
      });
  }, [debitNoteReceiptId, receiptLines, rawMaterials]);

  if (!supplier) {
'@ "supplier page: derive debitNoteItems"

# 4d. button inside each expanded receipt row
Replace-Exact $supplierPagePath @'
                    </tbody>
                        </table>
                      </td>
                    </tr>
                  )}
'@ @'
                    </tbody>
                        </table>
                        <div className="mt-2 flex justify-end">
                          <button
                            type="button"
                            onClick={() => setDebitNoteReceiptId(receipt.id)}
                            className="rounded-lg border border-neutral-400 dark:border-neutral-600 px-3 py-1.5 text-xs text-[var(--foreground)] hover:bg-[var(--surface-hover)]"
                          >
                            Debit Note (Return)
                          </button>
                        </div>
                      </td>
                    </tr>
                  )}
'@ "supplier page: add Debit Note button inside expanded receipt row"

# 4e. render the dialog
Replace-Exact $supplierPagePath @'
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
'@ @'
      <PurchaseReceiptDialog open={dialogOpen} onClose={() => setDialogOpen(false)} lockSupplierId={supplier.id} />
      <SupplierPaymentDialog
        open={paymentDialogOpen}
        onClose={() => setPaymentDialogOpen(false)}
        supplierId={supplier.id}
        supplierName={supplier.name}
        currentBalance={supplier.currentBalance}
      />
      <DebitNoteDialog
        open={debitNoteReceiptId !== null}
        onClose={() => setDebitNoteReceiptId(null)}
        supplierId={supplier.id}
        receiptId={debitNoteReceiptId ?? undefined}
        items={debitNoteItems}
      />
    </div>
  );
}
'@ "supplier page: render DebitNoteDialog"

Write-Host ""
Write-Host "suppliers/[id]/page.tsx: D5 wiring applied." -ForegroundColor Cyan

# =====================================================================
# 5. Wire ContraTransferDialog into payments page (D6)
# =====================================================================

# 5a. import
Replace-Exact $paymentsPagePath @'
import { useStore, type Payment } from "@/lib/store";
import { paymentSchema, type PaymentFormValues } from "@/lib/schemas";
import { SortableTable } from "@/components/ui/sortable-table";
'@ @'
import { useStore, type Payment } from "@/lib/store";
import { paymentSchema, type PaymentFormValues } from "@/lib/schemas";
import { SortableTable } from "@/components/ui/sortable-table";
import { ContraTransferDialog } from "@/components/ui/contra-transfer-dialog";
'@ "payments page: import ContraTransferDialog"

# 5b. state
Replace-Exact $paymentsPagePath @'
  const items = useStore((s) => s.payments);
  const loadCustomersModule = useStore((s) => s.loadCustomersModule);
  const [dialogOpen, setDialogOpen] = useState(false);
'@ @'
  const items = useStore((s) => s.payments);
  const loadCustomersModule = useStore((s) => s.loadCustomersModule);
  const [dialogOpen, setDialogOpen] = useState(false);
  const [contraDialogOpen, setContraDialogOpen] = useState(false);
'@ "payments page: add contraDialogOpen state"

# 5c. header button
Replace-Exact $paymentsPagePath @'
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-semibold text-[var(--foreground)]">Payments</h1>
        <button onClick={() => setDialogOpen(true)} className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-50 dark:text-neutral-50 dark:text-neutral-950 hover:opacity-90 transition-opacity">
          + Record Payment
        </button>
      </div>
'@ @'
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-semibold text-[var(--foreground)]">Payments</h1>
        <div className="flex items-center gap-2">
          <button onClick={() => setContraDialogOpen(true)} className="rounded-lg border border-neutral-400 dark:border-neutral-600 px-4 py-2 text-sm text-[var(--foreground)] hover:bg-[var(--surface-hover)]">
            Contra Transfer
          </button>
          <button onClick={() => setDialogOpen(true)} className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-50 dark:text-neutral-50 dark:text-neutral-950 hover:opacity-90 transition-opacity">
            + Record Payment
          </button>
        </div>
      </div>
'@ "payments page: add Contra Transfer button"

# 5d. render dialog
Replace-Exact $paymentsPagePath @'
      <RecordPaymentDialog open={dialogOpen} onClose={() => setDialogOpen(false)} />
    </div>
  );
}
'@ @'
      <RecordPaymentDialog open={dialogOpen} onClose={() => setDialogOpen(false)} />
      <ContraTransferDialog open={contraDialogOpen} onClose={() => setContraDialogOpen(false)} />
    </div>
  );
}
'@ "payments page: render ContraTransferDialog"

Write-Host ""
Write-Host "payments/page.tsx: D6 wiring applied." -ForegroundColor Cyan

Write-Host ""
Write-Host "=== STEPS D5 + D6 COMPLETE ===" -ForegroundColor Green
Write-Host "Files changed:"
Write-Host "  - $storePath (1 edit: contra transfer field-name/casing bug fix)"
Write-Host "  - $supplierPagePath (import, state, Debit Note button + dialog)"
Write-Host "  - $paymentsPagePath (import, state, Contra Transfer button + dialog)"
Write-Host "  - $debitDialogPath (new file)"
Write-Host "  - $contraDialogPath (new file)"
Write-Host ""
Write-Host "Next: test in the browser ->" -ForegroundColor Cyan
Write-Host "  1) Open a supplier -> expand a receipt -> Debit Note (Return)" -ForegroundColor Cyan
Write-Host "     -> enter a return qty -> confirm raw material stock goes" -ForegroundColor Cyan
Write-Host "     down and supplier balance goes down." -ForegroundColor Cyan
Write-Host "  2) Open Payments -> Contra Transfer -> move an amount between" -ForegroundColor Cyan
Write-Host "     Cash and Bank -> confirm both treasury balances update." -ForegroundColor Cyan
Write-Host "Then tell me the result. After that the remaining work is:" -ForegroundColor Yellow
Write-Host "  - Phase 3: invoice PDF format (PO No, Dispatch, Billed/Shipped" -ForegroundColor Yellow
Write-Host "    To, Paid/Balance/Previous Balance/Outstanding, amount in" -ForegroundColor Yellow
Write-Host "    words, signature) + faster voucher-entry screen" -ForegroundColor Yellow
Write-Host "  - Phase 4: Reports Hub (Ledger, Aged Payable/Receivable, Day" -ForegroundColor Yellow
Write-Host "    Book, Cash Flow, Purchase/Sales Register, Best Customer," -ForegroundColor Yellow
Write-Host "    Top Supplier) + Overdue-by-days on account pages" -ForegroundColor Yellow
Write-Host "  - Phase 5: inline + New Customer/Supplier, keyboard shortcuts" -ForegroundColor Yellow