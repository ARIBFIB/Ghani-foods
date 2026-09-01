"use client";

import { Fragment, use, useEffect, useMemo, useState } from "react";
import { NavLink } from "@/components/ui/nav-link";
import { ChevronDown, ChevronRight } from "lucide-react";
import { useStore } from "@/lib/store";
import { PurchaseReceiptDialog } from "@/components/ui/purchase-receipt-dialog";
import { SupplierPaymentDialog } from "@/components/ui/supplier-payment-dialog";
import { DebitNoteDialog, type DebitNoteLineItem } from "@/components/ui/debit-note-dialog";

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
  const [debitNoteReceiptId, setDebitNoteReceiptId] = useState<string | null>(null);

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
            <div className={`text-lg font-semibold mt-1 ${supplier.currentBalance > 0 ? "text-red-400" : "text-green-400"}`}>Rs. {Math.abs(supplier.currentBalance).toLocaleString()}</div>
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










