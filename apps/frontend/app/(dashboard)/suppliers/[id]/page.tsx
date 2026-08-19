"use client";

import { Fragment, use, useMemo, useState } from "react";
import { NavLink } from "@/components/ui/nav-link";
import { ChevronDown, ChevronRight } from "lucide-react";
import { useStore } from "@/lib/store";
import { PurchaseReceiptDialog } from "@/components/ui/purchase-receipt-dialog";

export default function SupplierDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const supplier = useStore((s) => s.suppliers.find((sup) => sup.id === id));
  const allReceipts = useStore((s) => s.receipts);
  const receiptLines = useStore((s) => s.receiptLines);
  const rawMaterials = useStore((s) => s.rawMaterials);
  const [expandedReceiptId, setExpandedReceiptId] = useState<string | null>(null);
  const [dialogOpen, setDialogOpen] = useState(false);

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
        </div>
      </div>

      <div className="flex items-center justify-between">
        <h2 className="text-lg font-semibold text-[var(--foreground)]">Purchase History</h2>
        <button onClick={() => setDialogOpen(true)} className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-50 dark:text-neutral-950 hover:opacity-90 transition-opacity">
          + Record Purchase
        </button>
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

      <PurchaseReceiptDialog open={dialogOpen} onClose={() => setDialogOpen(false)} lockSupplierId={supplier.id} />
    </div>
  );
}