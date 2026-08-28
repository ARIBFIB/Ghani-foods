<#
step-d4-credit-note-dialog.ps1

Purpose: Complete Step D4 - Credit Note (Sales Return) dialog on the
Invoice Detail page.

Fixes applied to apps/frontend/lib/store.ts:
  1. Invoice type was missing the real DB uuid (frontend `id` is actually
     invoice_number, e.g. "inv-1001"). fn_create_credit_note needs the real
     uuid for p_invoice_id. Added `dbId` field + populated in mapInvoiceRow.
  2. InvoiceLineRecord type/mapper was missing invoice_items.id (needed as
     `invoiceItemId` when calling fn_create_credit_note). Added `id` field.
  3. createCreditNote was sending `itemId` in the lines payload, but
     fn_create_credit_note (0009_contra_returns_supplier_ledger.sql) reads
     `invoiceItemId`. Renamed the field end-to-end (type + implementation).

New file created:
  apps/frontend/components/ui/credit-note-dialog.tsx

Edited:
  apps/frontend/app/(dashboard)/invoices/[id]/page.tsx
    - imports CreditNoteDialog
    - adds "Credit Note (Return)" button next to "Record Payment"
    - renders the dialog wired to invoice.dbId / invoice.customerId / invoice.items

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

function Replace-Exact($path, $old, $new, $label) {
    $content = [System.IO.File]::ReadAllText($path)
    if ($content.IndexOf($old) -lt 0) {
        throw "COULD NOT FIND expected block ($label) in $path. File may have changed since export - aborting so nothing is half-applied."
    }
    $count = ([regex]::Matches($content, [regex]::Escape($old))).Count
    if ($count -ne 1) {
        throw "Expected exactly 1 match for ($label) in $path but found $count. Aborting."
    }
    $content = $content.Replace($old, $new)
    [System.IO.File]::WriteAllText($path, $content)
    Write-Host "Applied: $label" -ForegroundColor Green
}

$repoRoot = (Get-Location).Path
[System.IO.Directory]::SetCurrentDirectory($repoRoot)

$storePath = Join-Path $repoRoot "apps\frontend\lib\store.ts"
$invoicePagePath = Join-Path $repoRoot "apps\frontend\app\(dashboard)\invoices\[id]\page.tsx"
$dialogPath = Join-Path $repoRoot "apps\frontend\components\ui\credit-note-dialog.tsx"

if (-not (Test-Path -LiteralPath $storePath)) { throw "Not found: $storePath - run this from the repo root (GhaniFoods)." }
if (-not (Test-Path -LiteralPath $invoicePagePath)) { throw "Not found: $invoicePagePath" }

Backup-File $storePath
Backup-File $invoicePagePath

# =====================================================================
# 1. store.ts - Invoice type: add dbId (real uuid)
# =====================================================================
Replace-Exact $storePath @'
export type Invoice = {
  id: string;
  customerId: string;
  customerName: string;
  invoiceDate: string;
  totalAmount: number;
  items: InvoiceLineRecord[];
};
'@ @'
export type Invoice = {
  id: string;
  dbId: string;
  customerId: string;
  customerName: string;
  invoiceDate: string;
  totalAmount: number;
  items: InvoiceLineRecord[];
};
'@ "Invoice type: add dbId"

# =====================================================================
# 2. store.ts - mapInvoiceRow: populate dbId
# =====================================================================
Replace-Exact $storePath @'
function mapInvoiceRow(row: Record<string, any>, customerName: string, items: InvoiceLineRecord[]): Invoice {
  return {
    id: row.invoice_number ?? row.id,
    customerId: row.customer_id,
    customerName,
    invoiceDate: row.invoice_date,
    totalAmount: Number(row.total_amount),
    items,
  };
}
'@ @'
function mapInvoiceRow(row: Record<string, any>, customerName: string, items: InvoiceLineRecord[]): Invoice {
  return {
    id: row.invoice_number ?? row.id,
    dbId: row.id,
    customerId: row.customer_id,
    customerName,
    invoiceDate: row.invoice_date,
    totalAmount: Number(row.total_amount),
    items,
  };
}
'@ "mapInvoiceRow: populate dbId"

# =====================================================================
# 3. store.ts - InvoiceLineRecord type: add id (invoice_items.id)
# =====================================================================
Replace-Exact $storePath @'
export type InvoiceLineRecord = {
  itemId: string;
  itemName: string;
  qty: number;
  unitPrice: number;
  subtotal: number;
  priceSourceNote?: string;
};
'@ @'
export type InvoiceLineRecord = {
  id: string;
  itemId: string;
  itemName: string;
  qty: number;
  unitPrice: number;
  subtotal: number;
  priceSourceNote?: string;
};
'@ "InvoiceLineRecord type: add id"

# =====================================================================
# 4. store.ts - mapInvoiceItemRow: populate id
# =====================================================================
Replace-Exact $storePath @'
function mapInvoiceItemRow(row: Record<string, any>): InvoiceLineRecord {
  return {
    itemId: row.finished_carton_id,
    itemName: row.item_name,
    qty: Number(row.qty),
    unitPrice: Number(row.unit_price),
    subtotal: Number(row.subtotal),
    priceSourceNote: row.price_source_note ?? undefined,
  };
}
'@ @'
function mapInvoiceItemRow(row: Record<string, any>): InvoiceLineRecord {
  return {
    id: row.id,
    itemId: row.finished_carton_id,
    itemName: row.item_name,
    qty: Number(row.qty),
    unitPrice: Number(row.unit_price),
    subtotal: Number(row.subtotal),
    priceSourceNote: row.price_source_note ?? undefined,
  };
}
'@ "mapInvoiceItemRow: populate id"

# =====================================================================
# 5. store.ts - createCreditNote type: itemId -> invoiceItemId
# =====================================================================
Replace-Exact $storePath @'
  createCreditNote: (input: {
    customerId: string;
    invoiceId?: string;
    lines: { itemId: string; qty: number; unitPrice: number }[];
    note?: string;
  }) => Promise<string>;
'@ @'
  createCreditNote: (input: {
    customerId: string;
    invoiceId?: string;
    lines: { invoiceItemId: string; qty: number; unitPrice: number }[];
    note?: string;
  }) => Promise<string>;
'@ "createCreditNote type: itemId -> invoiceItemId"

# =====================================================================
# 6. store.ts - createCreditNote implementation: fix body-shape mismatch
#    (this is the actual bug: SQL fn_create_credit_note reads
#    v_line->>'invoiceItemId', not v_line->>'itemId')
# =====================================================================
Replace-Exact $storePath @'
  createCreditNote: async (input) => {
    const { data, error } = await supabase.functions.invoke("credit-notes", {
      body: {
        customerId: input.customerId,
        invoiceId: input.invoiceId ?? null,
        lines: input.lines.map((l) => ({ itemId: l.itemId, qty: l.qty, unitPrice: l.unitPrice })),
        note: input.note ?? null,
      },
    });
'@ @'
  createCreditNote: async (input) => {
    const { data, error } = await supabase.functions.invoke("credit-notes", {
      body: {
        customerId: input.customerId,
        invoiceId: input.invoiceId ?? null,
        lines: input.lines.map((l) => ({ invoiceItemId: l.invoiceItemId, qty: l.qty, unitPrice: l.unitPrice })),
        note: input.note ?? null,
      },
    });
'@ "createCreditNote implementation: itemId -> invoiceItemId"

Write-Host ""
Write-Host "store.ts: all 6 edits applied." -ForegroundColor Cyan

# =====================================================================
# 7. Create new CreditNoteDialog component
# =====================================================================
$dialogContent = @'
"use client";

import { useState } from "react";
import { toast } from "@/components/ui/toast";
import { useStore, type InvoiceLineRecord } from "@/lib/store";

export function CreditNoteDialog({
  open,
  onClose,
  invoiceId,
  customerId,
  items,
}: {
  open: boolean;
  onClose: () => void;
  invoiceId: string;
  customerId: string;
  items: InvoiceLineRecord[];
}) {
  const createCreditNote = useStore((s) => s.createCreditNote);
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
        invoiceItemId: it.id,
        qty: Number(qtyById[it.id] || 0),
        unitPrice: it.unitPrice,
      }))
      .filter((l) => l.qty > 0);

    if (lines.length === 0) {
      setFormError("Enter a return quantity for at least one item");
      return;
    }
    for (const l of lines) {
      const original = items.find((it) => it.id === l.invoiceItemId);
      if (original && l.qty > original.qty) {
        setFormError(`Cannot return more than ${original.qty} of "${original.itemName}"`);
        return;
      }
    }

    setSubmitting(true);
    try {
      await createCreditNote({
        customerId,
        invoiceId,
        lines,
        note: note.trim() || undefined,
      });
      toast.success("Credit note created");
      resetAndClose();
    } catch (err) {
      setFormError(err instanceof Error ? err.message : "Failed to create credit note");
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-3 sm:p-4">
      <div className="w-full max-w-lg rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-5 space-y-4 max-h-[90vh] overflow-y-auto">
        <h2 className="text-lg font-semibold text-[var(--foreground)]">Credit Note (Sales Return)</h2>

        <div className="space-y-2">
          {items.map((it) => (
            <div key={it.id} className="flex items-center gap-3 rounded-lg border border-[var(--surface-border)] p-3">
              <div className="flex-1">
                <div className="text-sm text-[var(--foreground)]">{it.itemName}</div>
                <div className="text-xs text-[var(--text-muted)]">
                  Sold qty: {it.qty} @ Rs. {it.unitPrice.toLocaleString()}
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
            <p className="text-sm text-[var(--text-faint)]">This invoice has no line items to return.</p>
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
            {submitting ? "Saving..." : "Create Credit Note"}
          </button>
        </div>
      </div>
    </div>
  );
}
'@

if (Test-Path -LiteralPath $dialogPath) {
    Backup-File $dialogPath
}
$dialogDir = Split-Path -Parent $dialogPath
if (-not (Test-Path -LiteralPath $dialogDir)) { New-Item -ItemType Directory -Path $dialogDir -Force | Out-Null }
[System.IO.File]::WriteAllText($dialogPath, $dialogContent)
Write-Host "Created: $dialogPath" -ForegroundColor Green

# =====================================================================
# 8. Wire CreditNoteDialog into invoice detail page
# =====================================================================

# 8a. import
Replace-Exact $invoicePagePath @'
import { useStore } from "@/lib/store";
import { z } from "zod";
'@ @'
import { useStore } from "@/lib/store";
import { CreditNoteDialog } from "@/components/ui/credit-note-dialog";
import { z } from "zod";
'@ "invoice page: import CreditNoteDialog"

# 8b. state
Replace-Exact $invoicePagePath @'
  const [dialogOpen, setDialogOpen] = useState(false);
  const [generatingPdf, setGeneratingPdf] = useState(false);
'@ @'
  const [dialogOpen, setDialogOpen] = useState(false);
  const [creditNoteOpen, setCreditNoteOpen] = useState(false);
  const [generatingPdf, setGeneratingPdf] = useState(false);
'@ "invoice page: add creditNoteOpen state"

# 8c. button + dialog render
Replace-Exact $invoicePagePath @'
        <button onClick={() => setDialogOpen(true)} className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-50 dark:text-neutral-50 dark:text-neutral-950 hover:opacity-90 transition-opacity">
          Record Payment
        </button>
      </div>

      <RecordPaymentDialog open={dialogOpen} onClose={() => setDialogOpen(false)} customerId={invoice.customerId} customerName={invoice.customerName} />
    </div>
  );
}
'@ @'
        <button onClick={() => setDialogOpen(true)} className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-50 dark:text-neutral-50 dark:text-neutral-950 hover:opacity-90 transition-opacity">
          Record Payment
        </button>
        <button onClick={() => setCreditNoteOpen(true)} className="rounded-lg border border-neutral-400 dark:border-neutral-600 px-4 py-2 text-sm text-[var(--foreground)] hover:bg-[var(--surface-hover)]">
          Credit Note (Return)
        </button>
      </div>

      <RecordPaymentDialog open={dialogOpen} onClose={() => setDialogOpen(false)} customerId={invoice.customerId} customerName={invoice.customerName} />
      <CreditNoteDialog open={creditNoteOpen} onClose={() => setCreditNoteOpen(false)} invoiceId={invoice.dbId} customerId={invoice.customerId} items={invoice.items} />
    </div>
  );
}
'@ "invoice page: add button + render CreditNoteDialog"

Write-Host ""
Write-Host "=== STEP D4 COMPLETE ===" -ForegroundColor Green
Write-Host "Files changed:"
Write-Host "  - $storePath (6 edits: dbId, invoiceItemId mismatch fix)"
Write-Host "  - $invoicePagePath (button + dialog wired)"
Write-Host "  - $dialogPath (new file)"
Write-Host ""
Write-Host "NOTE: The backend/SQL side was already correct - no migration or" -ForegroundColor Yellow
Write-Host "edge function changes were needed for D4." -ForegroundColor Yellow
Write-Host ""
Write-Host "Next: test in the browser -> open an invoice -> Credit Note (Return)" -ForegroundColor Cyan
Write-Host "-> enter a return qty -> confirm stock goes back up and customer" -ForegroundColor Cyan
Write-Host "balance goes down. Then tell me the result so we move to D5" -ForegroundColor Cyan
Write-Host "(Debit Note / Purchase Return dialog)." -ForegroundColor Cyan